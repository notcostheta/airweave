#!/bin/bash

# stop-airweave.sh
# Simple script to stop all Airweave services
# Created: July 13, 2025

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo "🛑 Stopping Airweave services..."
echo ""

# Change to script directory
cd "$(dirname "$0")"

# Try to stop each compose configuration
compose_files=(
    "docker/docker-compose.alt-ports.yml"
    "docker/docker-compose.alt-ports.dev.yml"
    "docker/docker-compose.yml"
    "docker/docker-compose.dev.yml"
    "docker/docker-compose.test.yml"
)

for compose_file in "${compose_files[@]}"; do
    if [ -f "$compose_file" ]; then
        print_status "Stopping services from $compose_file"
        if docker compose -f "$compose_file" down 2>/dev/null; then
            print_success "Stopped services from $compose_file"
        else
            print_warning "No running services found for $compose_file"
        fi
    fi
done

echo ""
print_success "✅ All Airweave services stopped!"
echo ""
print_status "To start again, use:"
echo "  ./start.sh                    # Regular setup"
echo "  ./start-alt-ports.sh         # Alternative ports setup"
