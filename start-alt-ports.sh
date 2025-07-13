#!/bin/bash

set -x # Enable debug mode to see what's happening

echo "🚀 Airweave Alternative Ports Setup"
echo "====================================="
echo "This script uses alternative ports to avoid conflicts with existing services:"
echo "  • PostgreSQL: 5435 (instead of 5432)"
echo "  • Redis: 6381 (instead of 6379)"
echo "  • Backend API: 8002 (instead of 8001)"
echo "  • Frontend UI: 8081 (instead of 8080)"
echo "  • Qdrant: 6335 (instead of 6333)"
echo "  • Text2Vec: 9880 (instead of 9878)"
echo "  • Temporal: 7235 (instead of 7233)"
echo "  • Temporal RPC: 8235 (instead of 8233)"
echo "  • Temporal UI: 8090 (instead of 8088)"
echo ""

# Check if .env exists, if not create it from alternative ports example
if [ ! -f .env ]; then
    echo "Creating .env file from alternative ports example..."
    if [ -f .env.example.alt-ports ]; then
        cp .env.example.alt-ports .env
        echo ".env file created from alternative ports template"
    else
        echo "Warning: .env.example.alt-ports not found, using regular .env.example"
        cp .env.example .env
        echo ".env file created from regular template (ports will be updated below)"
    fi
fi

# Generate new encryption key regardless of existing value
echo "Generating new encryption key..."
NEW_KEY=$(openssl rand -base64 32)
echo "Generated key: $NEW_KEY"

# Remove any existing ENCRYPTION_KEY line and create clean .env
grep -v "^ENCRYPTION_KEY=" .env >.env.tmp
mv .env.tmp .env

# Add the new encryption key at the end of the file
echo "ENCRYPTION_KEY=\"$NEW_KEY\"" >>.env

# Add SKIP_AZURE_STORAGE for faster local startup
if ! grep -q "^SKIP_AZURE_STORAGE=" .env; then
    echo "SKIP_AZURE_STORAGE=true" >>.env
    echo "Added SKIP_AZURE_STORAGE=true for faster startup"
fi

# Update port configurations for alternative ports setup
echo "Updating port configurations for alternative ports..."

# Update PostgreSQL port
if grep -q "^POSTGRES_PORT=" .env; then
    sed -i 's/^POSTGRES_PORT=.*/POSTGRES_PORT=5435/' .env
else
    echo "POSTGRES_PORT=5435" >>.env
fi

# Update Redis port
if grep -q "^REDIS_PORT=" .env; then
    sed -i 's/^REDIS_PORT=.*/REDIS_PORT=6381/' .env
else
    echo "REDIS_PORT=6381" >>.env
fi

# Update Qdrant port
if grep -q "^QDRANT_PORT=" .env; then
    sed -i 's/^QDRANT_PORT=.*/QDRANT_PORT=6335/' .env
else
    echo "QDRANT_PORT=6335" >>.env
fi

# Update Text2Vec URL
if grep -q "^TEXT2VEC_INFERENCE_URL=" .env; then
    sed -i 's|^TEXT2VEC_INFERENCE_URL=.*|TEXT2VEC_INFERENCE_URL=http://localhost:9880|' .env
else
    echo "TEXT2VEC_INFERENCE_URL=http://localhost:9880" >>.env
fi

# Update Temporal port
if grep -q "^TEMPORAL_PORT=" .env; then
    sed -i 's/^TEMPORAL_PORT=.*/TEMPORAL_PORT=7235/' .env
else
    echo "TEMPORAL_PORT=7235" >>.env
fi

# Set alternative port configuration
if ! grep -q "^FRONTEND_LOCAL_DEVELOPMENT_PORT=" .env; then
    echo "FRONTEND_LOCAL_DEVELOPMENT_PORT=8081" >>.env
    echo "Added FRONTEND_LOCAL_DEVELOPMENT_PORT=8081"
fi

echo "Updated .env file. Current ENCRYPTION_KEY value:"
grep "^ENCRYPTION_KEY=" .env

# Ask for OpenAI API key
echo ""
echo "OpenAI API key is required for files and natural language search functionality."
read -p "Would you like to add your OPENAI_API_KEY now? You can also do this later by editing the .env file manually. (y/n): " ADD_OPENAI_KEY

if [ "$ADD_OPENAI_KEY" = "y" ] || [ "$ADD_OPENAI_KEY" = "Y" ]; then
    read -p "Enter your OpenAI API key: " OPENAI_KEY

    # Remove any existing OPENAI_API_KEY line
    grep -v "^OPENAI_API_KEY=" .env >.env.tmp
    mv .env.tmp .env

    # Add the new OpenAI API key
    echo "OPENAI_API_KEY=\"$OPENAI_KEY\"" >>.env
    echo "OpenAI API key added to .env file."
else
    echo "You can add your OPENAI_API_KEY later by editing the .env file manually."
    echo "Add the following line to your .env file:"
    echo "OPENAI_API_KEY=\"your-api-key-here\""
fi

# Ask for Mistral API key
echo ""
echo "Mistral API key is required for certain AI functionality."
read -p "Would you like to add your MISTRAL_API_KEY now? You can also do this later by editing the .env file manually. (y/n): " ADD_MISTRAL_KEY

if [ "$ADD_MISTRAL_KEY" = "y" ] || [ "$ADD_MISTRAL_KEY" = "Y" ]; then
    read -p "Enter your Mistral API key: " MISTRAL_KEY

    # Remove any existing MISTRAL_API_KEY line
    grep -v "^MISTRAL_API_KEY=" .env >.env.tmp
    mv .env.tmp .env

    # Add the new Mistral API key
    echo "MISTRAL_API_KEY=\"$MISTRAL_KEY\"" >>.env
    echo "Mistral API key added to .env file."
else
    echo "You can add your MISTRAL_API_KEY later by editing the .env file manually."
    echo "Add the following line to your .env file:"
    echo "MISTRAL_API_KEY=\"your-api-key-here\""
fi

# Check if "docker compose" is available (Docker Compose v2)
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
# Else, fall back to "docker-compose" (Docker Compose v1)
elif docker-compose --version >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
elif podman-compose --version >/dev/null 2>&1; then
    COMPOSE_CMD="podman-compose"
else
    echo "Neither 'docker compose', 'docker-compose', nor 'podman-compose' found. Please install Docker Compose."
    exit 1
fi

# Add this block: Check if Docker daemon is running
if docker info >/dev/null 2>&1; then
    CONTAINER_CMD="docker"
elif podman info >/dev/null 2>&1; then
    CONTAINER_CMD="podman"
else
    echo "Error: Docker daemon is not running. Please start Docker and try again."
    exit 1
fi

echo "Using commands: ${CONTAINER_CMD} and ${COMPOSE_CMD}"

# Check for existing airweave containers (including alt versions)
EXISTING_CONTAINERS=$(${CONTAINER_CMD} ps -a --filter "name=airweave" --format "{{.Names}}" | tr '\n' ' ')

if [ -n "$EXISTING_CONTAINERS" ]; then
    echo "Found existing airweave containers: $EXISTING_CONTAINERS"
    read -p "Would you like to remove them before starting? (y/n): " REMOVE_CONTAINERS

    if [ "$REMOVE_CONTAINERS" = "y" ] || [ "$REMOVE_CONTAINERS" = "Y" ]; then
        echo "Removing existing containers..."
        ${CONTAINER_CMD} rm -f $EXISTING_CONTAINERS

        # Also remove the database volumes (both regular and alt)
        echo "Removing database volumes..."
        ${CONTAINER_CMD} volume rm airweave_postgres_data 2>/dev/null || true
        ${CONTAINER_CMD} volume rm airweave_postgres_data_alt 2>/dev/null || true
        ${CONTAINER_CMD} volume rm airweave_redis_data 2>/dev/null || true
        ${CONTAINER_CMD} volume rm airweave_redis_data_alt 2>/dev/null || true
        ${CONTAINER_CMD} volume rm airweave_qdrant_data 2>/dev/null || true
        ${CONTAINER_CMD} volume rm airweave_qdrant_data_alt 2>/dev/null || true

        echo "Containers and volumes removed."
    else
        echo "Warning: Starting with existing containers may cause conflicts."
    fi
fi

# Now run the appropriate Docker Compose command with the alternative ports file
echo ""
echo "Starting Docker services with alternative ports..."
if ! $COMPOSE_CMD -f docker/docker-compose.alt-ports.yml up -d; then
    echo "❌ Failed to start Docker services"
    echo "Check the error messages above and try running:"
    echo "  docker logs airweave-backend-alt"
    echo "  docker logs airweave-frontend-alt"
    exit 1
fi

# Wait a moment for services to initialize
echo ""
echo "Waiting for services to initialize..."
sleep 10

# Check if backend is healthy (with retries) - using the new port
echo "Checking backend health..."
MAX_RETRIES=30
RETRY_COUNT=0
BACKEND_HEALTHY=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if ${CONTAINER_CMD} exec airweave-backend-alt curl -f http://localhost:8001/health >/dev/null 2>&1; then
        echo "✅ Backend is healthy!"
        BACKEND_HEALTHY=true
        break
    else
        echo "⏳ Backend is still starting... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)"
        RETRY_COUNT=$((RETRY_COUNT + 1))
        sleep 5
    fi
done

if [ "$BACKEND_HEALTHY" = false ]; then
    echo "❌ Backend failed to start after $MAX_RETRIES attempts"
    echo "Check backend logs with: docker logs airweave-backend-alt"
    echo "Common issues:"
    echo "  - Database connection problems"
    echo "  - Missing environment variables"
    echo "  - Platform sync errors"
fi

# Check if frontend needs to be started manually
FRONTEND_STATUS=$(${CONTAINER_CMD} inspect airweave-frontend-alt --format='{{.State.Status}}' 2>/dev/null)
if [ "$FRONTEND_STATUS" = "created" ] || [ "$FRONTEND_STATUS" = "exited" ]; then
    echo "Starting frontend container..."
    ${CONTAINER_CMD} start airweave-frontend-alt
    sleep 5
fi

# Final status check
echo ""
echo "🚀 Airweave Status (Alternative Ports):"
echo "======================================="

SERVICES_HEALTHY=true

# Check each service with the new ports
if ${CONTAINER_CMD} exec airweave-backend-alt curl -f http://localhost:8001/health >/dev/null 2>&1; then
    echo "✅ Backend API:    http://localhost:8002"
else
    echo "❌ Backend API:    Not responding (check logs with: docker logs airweave-backend-alt)"
    SERVICES_HEALTHY=false
fi

if curl -f http://localhost:8081 >/dev/null 2>&1; then
    echo "✅ Frontend UI:    http://localhost:8081"
else
    echo "❌ Frontend UI:    Not responding (check logs with: docker logs airweave-frontend-alt)"
    SERVICES_HEALTHY=false
fi

echo ""
echo "Other services (alternative ports):"
echo "📊 Temporal UI:    http://localhost:8090"
echo "🗄️  PostgreSQL:    localhost:5435"
echo "🔍 Qdrant:        http://localhost:6335"
echo "⚡ Redis:         localhost:6381"
echo "🤖 Text2Vec:      http://localhost:9880"
echo ""
echo "To view logs: docker logs <container-name>-alt"
echo "To stop all services: docker compose -f docker/docker-compose.alt-ports.yml down"
echo ""

if [ "$SERVICES_HEALTHY" = true ]; then
    echo "🎉 All services started successfully with alternative ports!"
    echo ""
    echo "📝 Important Notes:"
    echo "   • All services are using alternative ports to avoid conflicts"
    echo "   • Container names have '-alt' suffix"
    echo "   • Volume names have '_alt' suffix"
    echo "   • To connect to the database externally, use port 5435"
    echo "   • Frontend is available at http://localhost:8081"
    echo "   • Backend API is available at http://localhost:8002"
    echo "   • Volume names have '_alt' suffix"
    echo "   • To connect to the database externally, use port 5433"
    echo "   • Frontend is available at http://localhost:8081"
    echo "   • Backend API is available at http://localhost:8002"
else
    echo "⚠️  Some services failed to start properly. Check the logs above for details."
    exit 1
fi
