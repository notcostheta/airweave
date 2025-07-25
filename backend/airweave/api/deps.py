"""Dependencies that are used in the API endpoints."""

from typing import Optional, Tuple

from fastapi import Depends, Header, HTTPException
from fastapi_auth0 import Auth0User
from sqlalchemy.ext.asyncio import AsyncSession

from airweave import crud, schemas
from airweave.api.auth import auth0
from airweave.core.config import settings
from airweave.core.exceptions import NotFoundException
from airweave.core.logging import ContextualLogger, logger
from airweave.db.session import get_db
from airweave.schemas.auth import AuthContext


async def _authenticate_system_user(db: AsyncSession) -> Tuple[Optional[schemas.User], str, dict]:
    """Authenticate system user when auth is disabled."""
    user = await crud.user.get_by_email(db, email=settings.FIRST_SUPERUSER)
    if user:
        user_context = schemas.User.model_validate(user)
        return user_context, "system", {"disabled_auth": True}
    return None, "", {}


async def _authenticate_auth0_user(
    db: AsyncSession, auth0_user: Auth0User
) -> Tuple[Optional[schemas.User], str, dict]:
    """Authenticate Auth0 user."""
    try:
        user = await crud.user.get_by_email(db, email=auth0_user.email)
    except NotFoundException:
        logger.error(f"User {auth0_user.email} not found in database")
        return None, "", {}
    user_context = schemas.User.model_validate(user)
    return user_context, "auth0", {"auth0_id": auth0_user.id}


async def _authenticate_api_key(db: AsyncSession, api_key: str) -> Tuple[None, str, dict]:
    """Authenticate API key."""
    try:
        api_key_obj = await crud.api_key.get_by_key(db, key=api_key)
        auth_metadata = {
            "api_key_id": str(api_key_obj.id),
            "created_by": api_key_obj.created_by_email,
            "organization_id": str(api_key_obj.organization_id),
        }
        return None, "api_key", auth_metadata
    except (ValueError, NotFoundException) as e:
        logger.error(f"API key validation failed: {e}")
        if "expired" in str(e):
            raise HTTPException(status_code=403, detail="API key has expired") from e
        raise HTTPException(status_code=403, detail="Invalid or expired API key") from e


def _resolve_organization_id(
    x_organization_id: Optional[str],
    user_context: Optional[schemas.User],
    auth_method: str,
    auth_metadata: dict,
) -> str:
    """Resolve the organization ID from header or fallback to defaults."""
    if x_organization_id:
        return x_organization_id

    # Fallback logic based on auth method
    if auth_method in ["system", "auth0"] and user_context:
        if user_context.primary_organization_id:
            return str(user_context.primary_organization_id)
    elif auth_method == "api_key":
        return auth_metadata.get("organization_id")

    raise HTTPException(
        status_code=400,
        detail="Organization context required (X-Organization-ID header missing)",
    )


async def _validate_organization_access(
    db: AsyncSession,
    organization_id: str,
    user_context: Optional[schemas.User],
    auth_method: str,
    x_api_key: Optional[str],
) -> None:
    """Validate that the user/API key has access to the requested organization."""
    # For user-based auth, verify the user has access to the requested organization
    if user_context and auth_method in ["auth0", "system"]:
        user_org_ids = [str(org.organization.id) for org in user_context.user_organizations]
        if organization_id not in user_org_ids:
            raise HTTPException(
                status_code=403,
                detail=f"User does not have access to organization {organization_id}",
            )

    # For API key auth, verify the API key belongs to the requested organization
    elif auth_method == "api_key" and x_api_key:
        api_key_obj = await crud.api_key.get_by_key(db, key=x_api_key)
        if str(api_key_obj.organization_id) != organization_id:
            raise HTTPException(
                status_code=403,
                detail=f"API key does not have access to organization {organization_id}",
            )


async def get_auth_context(
    db: AsyncSession = Depends(get_db),
    x_api_key: Optional[str] = Header(None, alias="X-API-Key"),
    x_organization_id: Optional[str] = Header(None, alias="X-Organization-ID"),
    auth0_user: Optional[Auth0User] = Depends(auth0.get_user),
) -> AuthContext:
    """Retrieve authentication context for the request.

    Creates a unified AuthContext that works for both Auth0 users and API key authentication.
    Uses X-Organization-ID header to determine the current organization context.

    Args:
    ----
        db (AsyncSession): Database session.
        x_api_key (Optional[str]): API key provided in the request header.
        x_organization_id (Optional[str]): Organization ID provided in the X-Organization-ID header.
        auth0_user (Optional[Auth0User]): User details from Auth0.

    Returns:
    -------
        AuthContext: Unified authentication context.

    Raises:
    ------
        HTTPException: If no valid auth method is provided or org access is denied.
    """
    user_context = None
    auth_method = ""
    auth_metadata = {}

    # Determine authentication method and context
    if not settings.AUTH_ENABLED:
        user_context, auth_method, auth_metadata = await _authenticate_system_user(db)
    elif auth0_user:
        user_context, auth_method, auth_metadata = await _authenticate_auth0_user(db, auth0_user)
    elif x_api_key:
        user_context, auth_method, auth_metadata = await _authenticate_api_key(db, x_api_key)

    if not auth_method:
        raise HTTPException(status_code=401, detail="No valid authentication provided")

    # Resolve organization ID
    organization_id = _resolve_organization_id(
        x_organization_id, user_context, auth_method, auth_metadata
    )

    # Validate organization access
    await _validate_organization_access(db, organization_id, user_context, auth_method, x_api_key)

    return AuthContext(
        organization_id=organization_id,
        user=user_context,
        auth_method=auth_method,
        auth_metadata=auth_metadata,
    )


async def get_logger(
    auth_context: AuthContext = Depends(get_auth_context),
) -> ContextualLogger:
    """Get a logger with the current authentication context."""
    return logger.from_auth_context(auth_context)


async def get_user(
    db: AsyncSession = Depends(get_db),
    auth0_user: Optional[Auth0User] = Depends(auth0.get_user),
) -> schemas.User:
    """Retrieve user from super user from database.

    Legacy dependency for endpoints that expect User.
    Will fail for API key authentication since API keys don't have user context.

    Args:
    ----
        db (AsyncSession): Database session.
        x_api_key (Optional[str]): API key provided in the request header.
        x_organization_id (Optional[str]): Organization ID provided in the X-Organization-ID header.
        auth0_user (Optional[Auth0User]): User details from Auth0.

    Returns:
    -------
        schemas.User: User details from the database with organizations.

    Raises:
    ------
        HTTPException: If the user is not found in the database or if
            no authentication method is provided.

    """
    # Get auth context and extract user
    if not settings.AUTH_ENABLED:
        user, _, _ = await _authenticate_system_user(db)
    # Auth0 auth
    else:
        user, _, _ = await _authenticate_auth0_user(db, auth0_user)

    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return user


# Add this function to authenticate users with a token directly
async def get_user_from_token(token: str, db: AsyncSession) -> Optional[schemas.User]:
    """Verify the token and return the corresponding user.

    Args:
        token: The authentication token.
        db: The database session.

    Returns:
        The user with organizations if authentication succeeds, None otherwise.
    """
    try:
        # Remove 'Bearer ' prefix if present
        if token.startswith("Bearer "):
            token = token[7:]

        # If auth is disabled, just use the first superuser
        if not settings.AUTH_ENABLED:
            user = await crud.user.get_by_email(db, email=settings.FIRST_SUPERUSER)
            if user:
                return schemas.User.model_validate(user)
            return None

        # Get user ID from the token using the auth module
        from airweave.api.auth import get_user_from_token as auth_get_user

        auth0_user = await auth_get_user(token)
        if not auth0_user:
            return None

        # Get the internal user representation with organizations
        user = await crud.user.get_by_email(db=db, email=auth0_user.email)
        if not user:
            raise HTTPException(status_code=401, detail="User not found")

        return schemas.User.model_validate(user)
    except Exception as e:
        logger.error(f"Error in get_user_from_token: {e}")
        return None
