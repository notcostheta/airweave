#!/bin/bash

# stop-airweave.sh
# Stop all Airweave containers and processes
# Created: July 13, 2025

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Function to check if docker is available
check_docker() {
    if ! command -v docker &>/dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! docker info &>/dev/null; then
        print_error "Docker daemon is not running"
        exit 1
    fi
}

# Function to stop docker compose services
stop_compose_services() {
    local compose_file=$1
    local description=$2

    if [ -f "$compose_file" ]; then
        print_status "Stopping $description using $compose_file"
        if docker compose -f "$compose_file" down 2>/dev/null; then
            print_success "$description stopped successfully"
        else
            print_warning "Failed to stop $description or services were not running"
        fi
    else
        print_warning "$compose_file not found, skipping $description"
    fi
}

# Function to stop individual containers
stop_individual_containers() {
    local pattern=$1
    local description=$2

    print_status "Looking for $description containers..."

    # Get container IDs matching the pattern
    local containers=$(docker ps -aq --filter "name=$pattern" 2>/dev/null || true)

    if [ -n "$containers" ]; then
        print_status "Found $description containers, stopping them..."
        for container in $containers; do
            local container_name=$(docker inspect --format='{{.Name}}' "$container" 2>/dev/null | sed 's/^\//' || echo "unknown")
            print_status "Stopping container: $container_name"

            if docker stop "$container" &>/dev/null; then
                print_success "Stopped: $container_name"
            else
                print_warning "Failed to stop: $container_name"
            fi
        done

        # Remove stopped containers
        print_status "Removing stopped $description containers..."
        if docker rm $containers &>/dev/null; then
            print_success "Removed $description containers"
        else
            print_warning "Some containers could not be removed"
        fi
    else
        print_status "No $description containers found"
    fi
}

# Function to stop background processes
stop_background_processes() {
    print_status "Looking for background processes..."

    # Look for any running scripts
    local airweave_processes=$(pgrep -f "start.*airweave\|airweave.*start" 2>/dev/null || true)

    if [ -n "$airweave_processes" ]; then
        print_status "Found Airweave-related processes, stopping them..."
        for pid in $airweave_processes; do
            local process_info=$(ps -p "$pid" -o args --no-headers 2>/dev/null || echo "unknown process")
            print_status "Stopping process $pid: $process_info"

            if kill "$pid" 2>/dev/null; then
                print_success "Stopped process $pid"
            else
                print_warning "Failed to stop process $pid (may have already stopped)"
            fi
        done
    else
        print_status "No Airweave-related background processes found"
    fi
}

# Function to clean up networks
cleanup_networks() {
    print_status "Cleaning up Docker networks..."

    # Get Airweave-related networks
    local networks=$(docker network ls --filter "name=airweave" --format "{{.Name}}" 2>/dev/null || true)

    if [ -n "$networks" ]; then
        for network in $networks; do
            print_status "Removing network: $network"
            if docker network rm "$network" &>/dev/null; then
                print_success "Removed network: $network"
            else
                print_warning "Failed to remove network: $network (may be in use)"
            fi
        done
    else
        print_status "No Airweave networks found"
    fi
}

# Main execution
main() {
    print_header "Airweave Stop Script"
    echo "This script will stop all Airweave containers and processes"
    echo "Date: $(date)"
    echo ""

    # Check prerequisites
    check_docker

    # Change to script directory
    cd "$(dirname "$0")"
    print_status "Working directory: $(pwd)"

    # Stop using docker-compose files (in order of preference)
    print_header "Stopping Docker Compose Services"

    # Stop alternative ports services first
    stop_compose_services "docker/docker-compose.alt-ports.yml" "Alternative Ports Production Services"
    stop_compose_services "docker/docker-compose.alt-ports.dev.yml" "Alternative Ports Development Services"

    # Stop regular services
    stop_compose_services "docker/docker-compose.yml" "Production Services"
    stop_compose_services "docker/docker-compose.dev.yml" "Development Services"
    stop_compose_services "docker/docker-compose.test.yml" "Test Services"

    # Stop any remaining containers individually
    print_header "Stopping Individual Containers"
    stop_individual_containers "airweave*" "Airweave"

    # Stop background processes
    print_header "Stopping Background Processes"
    stop_background_processes

    # Clean up networks
    print_header "Cleaning Up Networks"
    cleanup_networks

    # Final status check
    print_header "Final Status Check"
    local remaining_containers=$(docker ps --filter "name=airweave" --format "{{.Names}}" 2>/dev/null || true)

    if [ -n "$remaining_containers" ]; then
        print_warning "Some Airweave containers are still running:"
        echo "$remaining_containers"
        echo ""
        print_status "You may need to stop them manually with:"
        echo "  docker stop $remaining_containers"
        echo "  docker rm $remaining_containers"
    else
        print_success "All Airweave containers have been stopped"
    fi

    print_header "Stop Operation Complete"
    print_success "Airweave stop script completed successfully"
    echo ""
    print_status "To start Airweave again, use:"
    echo "  ./start.sh                    # Regular setup"
    echo "  ./start-alt-ports.sh         # Alternative ports setup"
    echo ""
    print_status "To clean up volumes and data, use:"
    echo "  ./cleanup-airweave.sh"
}

# Run the main function
main "$@"
