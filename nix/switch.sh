#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "darwin"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        log_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
}

# Show help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Switch to the latest dotfiles configuration.

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    --dry-run          Show what would be done without making changes
    --rollback         Rollback to previous generation
    
EXAMPLES:
    $0                  Apply latest configuration
    $0 --dry-run       Preview changes without applying
    $0 --rollback      Rollback to previous generation
EOF
}

# Apply configuration
apply_configuration() {
    local os="$1"
    local dry_run="$2"
    local verbose="$3"
    local current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    cd "$current_dir"
    
    local flags=()
    [[ "$verbose" == "true" ]] && flags+=(--verbose)
    [[ "$dry_run" == "true" ]] && flags+=(--dry-run)
    
    log_info "Applying dotfiles configuration for $os..."
    
    if [[ "$os" == "darwin" ]]; then
        # Update nix-darwin system configuration
        if command -v darwin-rebuild &> /dev/null; then
            log_info "Updating system configuration with nix-darwin..."
            darwin-rebuild switch --flake .#default "${flags[@]}"
        else
            log_warning "darwin-rebuild not found, using nix run..."
            nix run nix-darwin -- switch --flake .#default "${flags[@]}"
        fi
        
        # Update Home Manager configuration
        log_info "Updating user configuration with Home Manager..."
        nix run home-manager -- switch --flake .#"x@macos" "${flags[@]}"
        
    else
        # Update Home Manager configuration for Linux
        log_info "Updating user configuration with Home Manager..."
        nix run home-manager -- switch --flake .#"x@linux" "${flags[@]}"
    fi
    
    if [[ "$dry_run" != "true" ]]; then
        log_success "Configuration applied successfully!"
    else
        log_info "Dry run completed. No changes were made."
    fi
}

# Rollback configuration
rollback_configuration() {
    local os="$1"
    local current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    cd "$current_dir"
    
    log_info "Rolling back to previous generation..."
    
    if [[ "$os" == "darwin" ]]; then
        # Rollback nix-darwin
        if command -v darwin-rebuild &> /dev/null; then
            darwin-rebuild --rollback switch
        else
            log_error "Cannot rollback: darwin-rebuild not found"
            exit 1
        fi
        
        # Rollback Home Manager
        home-manager generations | head -2 | tail -1 | awk '{print $7}' | xargs home-manager switch -b backup
        
    else
        # Rollback Home Manager for Linux
        home-manager generations | head -2 | tail -1 | awk '{print $7}' | xargs home-manager switch -b backup
    fi
    
    log_success "Rollback completed successfully!"
}

# Update flake inputs
update_flake() {
    local current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    cd "$current_dir"
    
    log_info "Updating flake inputs..."
    nix flake update
    
    log_success "Flake inputs updated!"
}

# List generations
list_generations() {
    local os="$1"
    
    log_info "Available generations:"
    
    if [[ "$os" == "darwin" ]]; then
        echo "=== System Generations (nix-darwin) ==="
        if command -v darwin-rebuild &> /dev/null; then
            sudo nix-env --list-generations -p /nix/var/nix/profiles/system
        fi
        echo
    fi
    
    echo "=== User Generations (Home Manager) ==="
    home-manager generations
}

# Main function
main() {
    local dry_run="false"
    local verbose="false"
    local rollback="false"
    local update="false"
    local list="false"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                verbose="true"
                shift
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --rollback)
                rollback="true"
                shift
                ;;
            --update)
                update="true"
                shift
                ;;
            --list)
                list="true"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    local os
    os=$(detect_os)
    
    # Handle different actions
    if [[ "$list" == "true" ]]; then
        list_generations "$os"
    elif [[ "$update" == "true" ]]; then
        update_flake
    elif [[ "$rollback" == "true" ]]; then
        rollback_configuration "$os"
    else
        apply_configuration "$os" "$dry_run" "$verbose"
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi