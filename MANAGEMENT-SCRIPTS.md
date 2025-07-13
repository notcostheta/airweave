# Airweave Management Scripts

This directory contains several scripts for managing your Airweave installation:

## Startup Scripts

### `start.sh`
- **Purpose:** Start Airweave with default ports
- **Usage:** `./start.sh`
- **Ports:** PostgreSQL: 5432, Redis: 6379, Frontend: 8080, Backend: 8001

### `start-alt-ports.sh` 
- **Purpose:** Start Airweave with alternative ports (to avoid conflicts)
- **Usage:** `./start-alt-ports.sh`
- **Ports:** PostgreSQL: 5435, Redis: 6381, Frontend: 8081, Backend: 8002
- **Documentation:** See `ALTERNATIVE-PORTS-SETUP.md` for detailed information

## Management Scripts

### `stop-airweave.sh` ⭐ NEW
- **Purpose:** Stop all Airweave containers and processes
- **Usage:** `./stop-airweave.sh`
- **Features:**
  - Stops all docker-compose services (regular and alternative ports)
  - Removes all Airweave containers
  - Kills background processes
  - Cleans up Docker networks
  - Provides detailed status reporting
  - Safe to run multiple times

### `cleanup-airweave.sh` ⚠️ DESTRUCTIVE ⚠️
- **Purpose:** Complete cleanup of all Airweave data and resources
- **Usage:** `./cleanup-airweave.sh`
- **⚠️ WARNING:** This permanently deletes ALL data!
- **Features:**
  - Removes all Airweave containers
  - **Deletes all Docker volumes (DATABASE DATA LOST!)**
  - Removes all Airweave Docker images
  - Cleans up Docker networks
  - Removes local storage directories
  - Requires double confirmation before proceeding
  - Shows detailed cleanup summary

## Quick Reference

### Normal Workflow
```bash
# Start Airweave
./start.sh

# Stop Airweave (keeps data)
./stop-airweave.sh

# Start again (data preserved)
./start.sh
```

### Alternative Ports Workflow
```bash
# Start with alternative ports
./start-alt-ports.sh

# Stop alternative ports setup
./stop-airweave.sh

# Start again
./start-alt-ports.sh
```

### Complete Reset Workflow
```bash
# Stop everything
./stop-airweave.sh

# Clean up everything (DELETES ALL DATA!)
./cleanup-airweave.sh

# Start fresh
./start.sh  # or ./start-alt-ports.sh
```

## Script Features

### Error Handling
- All scripts include proper error handling
- Check for Docker availability
- Provide clear status messages
- Safe to interrupt with Ctrl+C

### Safety Features
- `stop-airweave.sh` is non-destructive (preserves data)
- `cleanup-airweave.sh` requires explicit confirmation
- Scripts detect and report what they find
- Color-coded output for easy reading

### Compatibility
- Works with both regular and alternative port setups
- Handles multiple docker-compose configurations
- Gracefully handles missing files or containers
- Provides helpful suggestions for next steps

## Container and Volume Names

### Regular Setup
- **Containers:** `airweave-db`, `airweave-redis`, `airweave-backend`, `airweave-frontend`, etc.
- **Volumes:** `postgres_data`, `redis_data`, `qdrant_data`

### Alternative Ports Setup  
- **Containers:** `airweave-db-alt`, `airweave-redis-alt`, `airweave-backend-alt`, `airweave-frontend-alt`, etc.
- **Volumes:** `postgres_data_alt`, `redis_data_alt`, `qdrant_data_alt`

## Troubleshooting

### If containers won't stop:
```bash
# Force stop all Airweave containers
docker stop $(docker ps -aq --filter "name=airweave")
docker rm $(docker ps -aq --filter "name=airweave")
```

### If volumes won't delete:
```bash
# List volumes
docker volume ls | grep airweave

# Force remove volumes (DELETES DATA!)
docker volume rm $(docker volume ls --filter "name=airweave" -q)
```

### If ports are still in use:
```bash
# Check what's using a port
sudo netstat -tulpn | grep :8080

# Kill process using port
sudo kill -9 <PID>
```

---

**Created:** July 13, 2025  
**Last Updated:** July 13, 2025
