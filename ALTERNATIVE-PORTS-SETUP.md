# Airweave Alternative Ports Setup Documentation

## Overview

This document provides a complete reference for the alternative ports configuration created to avoid conflicts with existing services running on the system. The alternative setup allows Airweave to run alongside other Docker containers without port conflicts.

## Files Created and Modified

### New Files Created

#### 1. Docker Compose Files

**File:** `docker/docker-compose.alt-ports.yml`
- **Purpose:** Production docker-compose configuration with alternative ports
- **Usage:** Used by `start-alt-ports.sh` for full deployment
- **Location:** `/home/ubuntu/Desktop/airweave/docker/docker-compose.alt-ports.yml`

**File:** `docker/docker-compose.alt-ports.dev.yml`
- **Purpose:** Development docker-compose configuration with alternative ports
- **Usage:** Used for local development via VS Code tasks
- **Location:** `/home/ubuntu/Desktop/airweave/docker/docker-compose.alt-ports.dev.yml`

#### 2. Start Script

**File:** `start-alt-ports.sh`
- **Purpose:** Main startup script using alternative ports
- **Features:**
  - Uses `.env.example.alt-ports` template for correct port configuration
  - Automatic .env file creation and configuration
  - Port configuration updates (ensures all ports are set to alternative values)
  - Encryption key generation
  - API key setup (OpenAI, Mistral)
  - Container conflict detection and resolution
  - Health checks with new port configurations
- **Location:** `/home/ubuntu/Desktop/airweave/start-alt-ports.sh`
- **Permissions:** Executable (`chmod +x`)

#### 3. Environment Configuration

**File:** `.env.example.alt-ports`
- **Purpose:** Environment variable template with alternative ports
- **Features:**
  - Pre-configured with all alternative port values
  - Used as template by `start-alt-ports.sh`
  - Includes helpful comments about port changes
- **Location:** `/home/ubuntu/Desktop/airweave/.env.example.alt-ports`

### Modified Files

#### 1. VS Code Tasks

**File:** `.vscode/tasks.json`
- **Changes:** Added new tasks for alternative ports
- **New Tasks:**
  - `start-docker-services-alt-ports`
  - `stop-docker-services-alt-ports`
- **Location:** `/home/ubuntu/Desktop/airweave/.vscode/tasks.json`

## Port Mapping Configuration

### Original vs Alternative Ports

| Service | Component | Original Port | Alternative Port | Protocol |
|---------|-----------|---------------|------------------|----------|
| PostgreSQL | Database | 5432 | **5435** | TCP |
| Redis | Cache | 6379 | **6381** | TCP |
| Backend | API Server | 8001 | **8002** | HTTP |
| Frontend | Web UI | 8080 | **8081** | HTTP |
| Qdrant | Vector Database | 6333 | **6335** | HTTP |
| Text2Vec | Embeddings Service | 9878 | **9880** | HTTP |
| Temporal | Workflow Engine | 7233 | **7235** | gRPC |
| Temporal | RPC Interface | 8233 | **8235** | TCP |
| Temporal UI | Web Interface | 8088 | **8090** | HTTP |

### Container Name Changes

All containers have been renamed with an `-alt` suffix to prevent conflicts:

| Original Container Name | Alternative Container Name |
|------------------------|----------------------------|
| `airweave-db` | `airweave-db-alt` |
| `airweave-redis` | `airweave-redis-alt` |
| `airweave-backend` | `airweave-backend-alt` |
| `airweave-frontend` | `airweave-frontend-alt` |
| `airweave-embeddings` | `airweave-embeddings-alt` |
| `airweave-qdrant` | `airweave-qdrant-alt` |
| `airweave-temporal` | `airweave-temporal-alt` |
| `airweave-temporal-ui` | `airweave-temporal-ui-alt` |
| `airweave-temporal-worker` | `airweave-temporal-worker-alt` |

### Volume Name Changes

All Docker volumes have been renamed with an `_alt` suffix:

| Original Volume Name | Alternative Volume Name |
|---------------------|-------------------------|
| `postgres_data` | `postgres_data_alt` |
| `redis_data` | `redis_data_alt` |
| `qdrant_data` | `qdrant_data_alt` |

## Usage Instructions

### Method 1: Using the Start Script (Recommended)

```bash
# Navigate to the project directory
cd /home/ubuntu/Desktop/airweave

# Run the alternative ports start script
./start-alt-ports.sh
```

**Features:**
- Interactive setup for API keys
- Automatic environment configuration
- Container conflict resolution
- Health check monitoring
- Comprehensive status reporting

### Method 2: Using VS Code Tasks

1. Open VS Code in the project directory
2. Open Command Palette (`Ctrl+Shift+P`)
3. Run task: `Tasks: Run Task`
4. Select: `start-docker-services-alt-ports`

**To Stop:**
- Run task: `stop-docker-services-alt-ports`

### Method 3: Manual Docker Compose

#### Production Setup
```bash
# Start services
docker compose -f docker/docker-compose.alt-ports.yml up -d

# Stop services
docker compose -f docker/docker-compose.alt-ports.yml down
```

#### Development Setup
```bash
# Start services
docker compose -f docker/docker-compose.alt-ports.dev.yml up -d

# Stop services
docker compose -f docker/docker-compose.alt-ports.dev.yml down
```

## Access URLs

### Primary Services
- **Frontend Application:** http://localhost:8081
- **Backend API:** http://localhost:8002
- **API Documentation:** http://localhost:8002/docs

### Administrative Interfaces
- **Temporal UI:** http://localhost:8090
- **Qdrant Dashboard:** http://localhost:6335/dashboard

### Database Connections
- **PostgreSQL:** `localhost:5435`
  - Database: `airweave`
  - Username: `airweave`
  - Password: `airweave1234!` (or from .env)
- **Redis:** `localhost:6381`

## Environment Configuration

### Environment Template Files

The alternative ports setup includes a dedicated environment template:

**`.env.example.alt-ports`** - Pre-configured with alternative ports:
- PostgreSQL: 5435
- Redis: 6381  
- Qdrant: 6335
- Text2Vec: 9880
- Frontend: 8081
- Temporal: 7235

**Automatic Configuration:**
The `start-alt-ports.sh` script automatically:
1. Uses `.env.example.alt-ports` as the template (if available)
2. Falls back to `.env.example` and updates ports automatically
3. Ensures all port configurations are set to alternative values
4. Updates any existing .env file with correct ports

### Required Environment Variables

The `.env` file will be automatically created with the following variables:

```env
# Encryption
ENCRYPTION_KEY="<auto-generated-32-byte-key>"

# Performance
SKIP_AZURE_STORAGE=true

# Alternative Port Configuration
POSTGRES_PORT=5435
REDIS_PORT=6381
QDRANT_PORT=6335
TEXT2VEC_INFERENCE_URL=http://localhost:9880
TEMPORAL_PORT=7235
FRONTEND_LOCAL_DEVELOPMENT_PORT=8081

# API Keys (optional, prompted during setup)
OPENAI_API_KEY="<your-openai-key>"
MISTRAL_API_KEY="<your-mistral-key>"
```

### Database Configuration

The alternative setup uses the same database configuration as the original, but on port 5433:

```env
POSTGRES_HOST=localhost  # External access
POSTGRES_PORT=5433       # Alternative port
POSTGRES_DB=airweave
POSTGRES_USER=airweave
POSTGRES_PASSWORD=airweave1234!
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Port Conflicts
**Symptom:** Services fail to start with "port already in use" errors
**Solution:** 
- Check for conflicts: `netstat -tulpn | grep <port>`
- Stop conflicting services or use different ports

#### 2. Container Name Conflicts
**Symptom:** "Container name already exists" errors
**Solution:**
- Remove existing containers: `docker rm -f $(docker ps -aq --filter "name=airweave")`
- Use the script's automatic cleanup option

#### 3. Volume Conflicts
**Symptom:** Database data issues or conflicts
**Solution:**
- Remove old volumes: `docker volume rm airweave_postgres_data`
- The alternative setup uses separate volumes with `_alt` suffix

#### 4. Health Check Failures
**Symptom:** Services show as unhealthy
**Solution:**
- Check logs: `docker logs airweave-backend-alt`
- Verify environment variables are set correctly
- Ensure all dependencies are running

### Monitoring and Logs

#### View Container Status
```bash
# Check all airweave containers
docker ps --filter "name=airweave"

# Check specific alternative containers
docker ps --filter "name=airweave-.*-alt"
```

#### View Service Logs
```bash
# Backend logs
docker logs airweave-backend-alt

# Frontend logs
docker logs airweave-frontend-alt

# Database logs
docker logs airweave-db-alt

# Follow logs in real-time
docker logs -f airweave-backend-alt
```

#### Health Checks
```bash
# Backend health
curl http://localhost:8002/health

# Frontend availability
curl http://localhost:8081

# Qdrant health
curl http://localhost:6334/healthz
```

## Development Workflow

### Local Development with Alternative Ports

1. **Start Services:**
   ```bash
   ./start-alt-ports.sh
   ```

2. **Verify Services:**
   - Frontend: http://localhost:8081
   - Backend: http://localhost:8002/docs
   - Database: Connect to `localhost:5433`

3. **Development:**
   - Backend code changes are auto-reloaded
   - Frontend changes require rebuild
   - Database persists between restarts

4. **Stop Services:**
   ```bash
   docker compose -f docker/docker-compose.alt-ports.yml down
   ```

### Integration with Existing Services

The alternative ports setup is designed to coexist with your existing services:

**Existing Services (from docker-ps.txt):**
- Coolify: ports 8000, 8080
- PostgreSQL: port 5432
- Various web services: ports 80, 443, etc.

**Airweave Alternative:**
- All services use different ports
- No conflicts with existing infrastructure
- Separate container names and volumes

## Maintenance

### Regular Maintenance Tasks

1. **Update Images:**
   ```bash
   docker compose -f docker/docker-compose.alt-ports.yml pull
   docker compose -f docker/docker-compose.alt-ports.yml up -d
   ```

2. **Clean Up Old Data:**
   ```bash
   # Remove unused volumes
   docker volume prune

   # Remove unused images
   docker image prune
   ```

3. **Backup Database:**
   ```bash
   docker exec airweave-db-alt pg_dump -U airweave airweave > backup.sql
   ```

4. **Restore Database:**
   ```bash
   docker exec -i airweave-db-alt psql -U airweave airweave < backup.sql
   ```

## Security Considerations

1. **Encryption Key:** Automatically generated 32-byte key stored in `.env`
2. **Database Access:** Limited to localhost by default
3. **API Keys:** Stored securely in `.env` file
4. **Container Isolation:** Each service runs in isolated containers
5. **Network Security:** Services communicate via Docker internal networks

## File Structure Summary

```
/home/ubuntu/Desktop/airweave/
├── start-alt-ports.sh                           # New alternative ports start script
├── .env.example                                 # Original environment template
├── .env.example.alt-ports                       # New alternative ports environment template
├── docker/
│   ├── docker-compose.yml                       # Original production config
│   ├── docker-compose.dev.yml                   # Original development config
│   ├── docker-compose.alt-ports.yml             # New production config (alt ports)
│   └── docker-compose.alt-ports.dev.yml         # New development config (alt ports)
├── .vscode/
│   └── tasks.json                                # Updated with new tasks
└── .env                                          # Auto-generated environment config
```

---

## Quick Reference

### Start Services
```bash
./start-alt-ports.sh
```

### Access Applications
- **Frontend:** http://localhost:8081
- **Backend:** http://localhost:8002
- **Temporal UI:** http://localhost:8090

### Stop Services
```bash
docker compose -f docker/docker-compose.alt-ports.yml down
```

### View Logs
```bash
docker logs airweave-backend-alt
```

---

*Created: July 13, 2025*
*Purpose: Document alternative ports setup for Airweave to avoid conflicts with existing services*
