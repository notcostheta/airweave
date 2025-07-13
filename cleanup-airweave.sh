#!/bin/bash

# cleanup-airweave.sh
# Clean up all Airweave storage, volumes, images, and data
# Created: July 13, 2025
# WARNING: This will permanently delete all Airweave data!

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
    echo -e "\n${CYAN}=== $1 ===${NC}"
}

print_danger() {
    echo -e "${RED}[DANGER]${NC} $1"
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

# Function to confirm destructive action
confirm_cleanup() {
    echo ""
    print_danger "⚠️  WARNING: DESTRUCTIVE ACTION ⚠️"
    print_danger "This script will permanently delete:"
    echo "  • All Airweave Docker containers"
    echo "  • All Airweave Docker volumes (DATABASE DATA WILL BE LOST)"
    echo "  • All Airweave Docker images"
    echo "  • All Airweave Docker networks"
    echo "  • Local storage directories"
    echo "  • Cached data and processed files"
    echo ""
    print_danger "This action CANNOT be undone!"
    echo ""

    # Interactive confirmation
    read -p "Are you sure you want to proceed? Type 'yes' to continue: " confirm
    if [ "$confirm" != "yes" ]; then
        print_status "Cleanup cancelled by user"
        exit 0
    fi

    echo ""
    read -p "Please type 'DELETE ALL DATA' to confirm: " confirm2
    if [ "$confirm2" != "DELETE ALL DATA" ]; then
        print_status "Cleanup cancelled by user"
        exit 0
    fi

    print_warning "Proceeding with cleanup in 5 seconds... (Ctrl+C to cancel)"
    for i in {5..1}; do
        echo -n "$i... "
        sleep 1
    done
    echo ""
    print_status "Starting cleanup process"
}

# Function to stop all containers first
stop_all_containers() {
    print_status "Ensuring all Airweave containers are stopped..."

    local containers=$(docker ps -aq --filter "name=airweave" 2>/dev/null || true)

    if [ -n "$containers" ]; then
        print_status "Stopping running containers..."
        docker stop $containers 2>/dev/null || true
        print_success "Containers stopped"
    else
        print_status "No running Airweave containers found"
    fi
}

# Function to remove containers
remove_containers() {
    print_status "Removing all Airweave containers..."

    local containers=$(docker ps -aq --filter "name=airweave" 2>/dev/null || true)

    if [ -n "$containers" ]; then
        print_status "Found containers to remove:"
        docker ps -a --filter "name=airweave" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
        echo ""

        if docker rm -f $containers 2>/dev/null; then
            print_success "All Airweave containers removed"
        else
            print_warning "Some containers could not be removed"
        fi
    else
        print_status "No Airweave containers found"
    fi
}

# Function to remove volumes
remove_volumes() {
    print_status "Removing all Airweave volumes..."

    # List of known Airweave volumes
    local volume_patterns=(
        "postgres_data"
        "postgres_data_alt"
        "redis_data"
        "redis_data_alt"
        "qdrant_data"
        "qdrant_data_alt"
        "airweave_postgres_data"
        "airweave_redis_data"
        "airweave_qdrant_data"
    )

    # Also find volumes with airweave in the name
    local airweave_volumes=$(docker volume ls --filter "name=airweave" --format "{{.Name}}" 2>/dev/null || true)

    # Combine all volume patterns
    local all_volumes=""

    # Check for pattern-based volumes
    for pattern in "${volume_patterns[@]}"; do
        local volumes=$(docker volume ls --filter "name=$pattern" --format "{{.Name}}" 2>/dev/null || true)
        if [ -n "$volumes" ]; then
            all_volumes="$all_volumes $volumes"
        fi
    done

    # Add airweave-named volumes
    if [ -n "$airweave_volumes" ]; then
        all_volumes="$all_volumes $airweave_volumes"
    fi

    # Remove duplicates and process
    local unique_volumes=$(echo "$all_volumes" | tr ' ' '\n' | sort -u | tr '\n' ' ')

    if [ -n "$unique_volumes" ]; then
        print_status "Found volumes to remove:"
        for volume in $unique_volumes; do
            echo "  • $volume"
        done
        echo ""

        for volume in $unique_volumes; do
            print_status "Removing volume: $volume"
            if docker volume rm "$volume" 2>/dev/null; then
                print_success "Removed: $volume"
            else
                print_warning "Failed to remove: $volume (may not exist or be in use)"
            fi
        done
    else
        print_status "No Airweave volumes found"
    fi
}

# Function to remove images
remove_images() {
    print_status "Removing Airweave Docker images..."

    # Find Airweave-related images
    local images=$(docker images --filter "reference=*airweave*" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || true)

    # Also look for images that might be built from Airweave
    local backend_images=$(docker images --filter "reference=*backend*" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -i airweave || true)
    local frontend_images=$(docker images --filter "reference=*frontend*" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | grep -i airweave || true)

    local all_images="$images $backend_images $frontend_images"

    if [ -n "$all_images" ]; then
        print_status "Found images to remove:"
        for image in $all_images; do
            if [ -n "$image" ]; then
                echo "  • $image"
            fi
        done
        echo ""

        for image in $all_images; do
            if [ -n "$image" ]; then
                print_status "Removing image: $image"
                if docker rmi "$image" 2>/dev/null; then
                    print_success "Removed: $image"
                else
                    print_warning "Failed to remove: $image (may not exist or be in use)"
                fi
            fi
        done
    else
        print_status "No Airweave images found"
    fi

    # Clean up dangling images
    print_status "Cleaning up dangling images..."
    if docker image prune -f &>/dev/null; then
        print_success "Dangling images cleaned up"
    fi
}

# Function to remove networks
remove_networks() {
    print_status "Removing Airweave Docker networks..."

    local networks=$(docker network ls --filter "name=airweave" --format "{{.Name}}" 2>/dev/null || true)

    if [ -n "$networks" ]; then
        print_status "Found networks to remove:"
        for network in $networks; do
            echo "  • $network"
        done
        echo ""

        for network in $networks; do
            print_status "Removing network: $network"
            if docker network rm "$network" 2>/dev/null; then
                print_success "Removed: $network"
            else
                print_warning "Failed to remove: $network (may not exist or be in use)"
            fi
        done
    else
        print_status "No Airweave networks found"
    fi
}

# Function to clean up local storage
cleanup_local_storage() {
    print_status "Cleaning up local storage directories..."

    # Change to script directory
    cd "$(dirname "$0")"

    # List of local storage directories to clean
    local storage_dirs=(
        "backend/local_storage"
        "backend/local_storage/backup"
        "backend/local_storage/processed-files"
        "backend/local_storage/sync-data"
        "backend/local_storage/sync-metadata"
        ".env"
        ".env.local"
        ".env.development"
    )

    for dir in "${storage_dirs[@]}"; do
        if [ -e "$dir" ]; then
            print_status "Removing: $dir"
            if rm -rf "$dir" 2>/dev/null; then
                print_success "Removed: $dir"
            else
                print_warning "Failed to remove: $dir"
            fi
        fi
    done

    # Clean up any generated files
    local generated_files=(
        ".env"
        ".env.backup"
        "*.log"
        "*.pid"
    )

    for pattern in "${generated_files[@]}"; do
        local files=$(find . -maxdepth 1 -name "$pattern" 2>/dev/null || true)
        if [ -n "$files" ]; then
            print_status "Removing generated files: $pattern"
            rm -f $files 2>/dev/null || true
        fi
    done
}

# Function to show cleanup summary
show_cleanup_summary() {
    print_header "Cleanup Summary"

    # Check what's left
    local remaining_containers=$(docker ps -aq --filter "name=airweave" 2>/dev/null | wc -l)
    local remaining_volumes=$(docker volume ls --filter "name=airweave" --format "{{.Name}}" 2>/dev/null | wc -l)
    local remaining_images=$(docker images --filter "reference=*airweave*" --format "{{.Repository}}" 2>/dev/null | wc -l)
    local remaining_networks=$(docker network ls --filter "name=airweave" --format "{{.Name}}" 2>/dev/null | wc -l)

    echo "Cleanup Results:"
    echo "  • Containers remaining: $remaining_containers"
    echo "  • Volumes remaining: $remaining_volumes"
    echo "  • Images remaining: $remaining_images"
    echo "  • Networks remaining: $remaining_networks"
    echo ""

    if [ "$remaining_containers" -eq 0 ] && [ "$remaining_volumes" -eq 0 ] && [ "$remaining_images" -eq 0 ] && [ "$remaining_networks" -eq 0 ]; then
        print_success "✅ Complete cleanup successful!"
        echo "All Airweave resources have been removed."
    else
        print_warning "⚠️ Some resources may still remain"
        echo "You may need to manually remove them or check for permission issues."
    fi

    echo ""
    print_status "To start fresh, use:"
    echo "  ./start.sh                    # Regular setup"
    echo "  ./start-alt-ports.sh         # Alternative ports setup"
}

# Function to perform additional system cleanup
additional_cleanup() {
    print_status "Performing additional Docker cleanup..."

    # Clean up build cache
    print_status "Cleaning Docker build cache..."
    if docker builder prune -f &>/dev/null; then
        print_success "Build cache cleaned"
    fi

    # Clean up unused networks
    print_status "Cleaning unused networks..."
    if docker network prune -f &>/dev/null; then
        print_success "Unused networks cleaned"
    fi

    # Clean up unused volumes (be careful with this)
    print_status "Note: Not cleaning all unused volumes to preserve other projects"
    print_status "If you want to clean ALL unused volumes, run: docker volume prune"
}

# Main execution
main() {
    print_header "Airweave Complete Cleanup Script"
    echo "This script will completely remove all Airweave data and resources"
    echo "Date: $(date)"
    echo ""

    # Check prerequisites
    check_docker

    # Get user confirmation
    confirm_cleanup

    # Execute cleanup steps
    print_header "Step 1: Stopping Containers"
    stop_all_containers

    print_header "Step 2: Removing Containers"
    remove_containers

    print_header "Step 3: Removing Volumes"
    remove_volumes

    print_header "Step 4: Removing Images"
    remove_images

    print_header "Step 5: Removing Networks"
    remove_networks

    print_header "Step 6: Cleaning Local Storage"
    cleanup_local_storage

    print_header "Step 7: Additional Cleanup"
    additional_cleanup

    # Show final summary
    show_cleanup_summary

    print_header "Cleanup Complete"
    print_success "Airweave cleanup script completed successfully"
    echo ""
    print_warning "Remember: All data has been permanently deleted!"
}

# Safety check - make sure we're in the right directory
if [ ! -f "package.json" ] && [ ! -f "README.md" ]; then
    print_error "This doesn't appear to be the Airweave project directory"
    print_error "Please run this script from the Airweave root directory"
    exit 1
fi

# Run the main function
main "$@"
