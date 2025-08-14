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
Usage: $0 [OPTIONS] [GENERATION_NUMBER]

Rollback dotfiles configuration to a previous generation.

OPTIONS:
    -h, --help          Show this help message
    -l, --list          List available generations
    -i, --interactive   Interactive selection of generation
    
ARGUMENTS:
    GENERATION_NUMBER   Specific generation number to rollback to
    
EXAMPLES:
    $0                  Rollback to previous generation
    $0 --list          List all available generations
    $0 --interactive   Interactively select generation to rollback to
    $0 42              Rollback to generation 42
EOF
}

# List generations
list_generations() {
    local os="$1"
    
    log_info "Available generations:"
    
    if [[ "$os" == "darwin" ]]; then
        echo "=== System Generations (nix-darwin) ==="
        if command -v darwin-rebuild &> /dev/null; then
            sudo nix-env --list-generations -p /nix/var/nix/profiles/system | tail -10
        fi
        echo
    fi
    
    echo "=== User Generations (Home Manager) ==="
    home-manager generations | head -10
}

# Interactive generation selection
interactive_selection() {
    local os="$1"
    
    log_info "Select a generation to rollback to:"
    
    # Show recent generations
    list_generations "$os"
    
    echo
    read -p "Enter the generation number to rollback to (or 'q' to quit): " selection
    
    if [[ "$selection" == "q" || "$selection" == "quit" ]]; then
        log_info "Rollback cancelled"
        exit 0
    fi
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
        log_error "Invalid generation number: $selection"
        exit 1
    fi
    
    rollback_to_generation "$os" "$selection"
}

# Rollback to specific generation
rollback_to_generation() {
    local os="$1"
    local generation="$2"
    
    log_info "Rolling back to generation $generation..."
    
    if [[ "$os" == "darwin" ]]; then
        # Rollback nix-darwin system
        if command -v darwin-rebuild &> /dev/null; then
            log_info "Rolling back system configuration..."
            if [[ -n "$generation" ]]; then
                sudo nix-env -p /nix/var/nix/profiles/system --switch-generation "$generation"
                darwin-rebuild switch
            else
                darwin-rebuild --rollback switch
            fi
        fi
    fi
    
    # Rollback Home Manager
    log_info "Rolling back user configuration..."
    if [[ -n "$generation" ]]; then
        # Find the path for the specific generation
        local generation_path
        generation_path=$(home-manager generations | awk -v gen="$generation" '$7 == gen {print $1}' | head -1)
        
        if [[ -n "$generation_path" ]]; then
            "$generation_path/activate"
        else
            log_error "Generation $generation not found in Home Manager"
            exit 1
        fi
    else
        # Rollback to previous generation
        local prev_generation
        prev_generation=$(home-manager generations | head -2 | tail -1 | awk '{print $1}')
        
        if [[ -n "$prev_generation" ]]; then
            "$prev_generation/activate"
        else
            log_error "No previous generation found"
            exit 1
        fi
    fi
    
    log_success "Rollback completed successfully!"
}

# Rollback to previous generation
rollback_previous() {
    local os="$1"
    rollback_to_generation "$os" ""
}

# Main function
main() {
    local list="false"
    local interactive="false"
    local generation=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -l|--list)
                list="true"
                shift
                ;;
            -i|--interactive)
                interactive="true"
                shift
                ;;
            *)
                # Assume it's a generation number
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    generation="$1"
                else
                    log_error "Unknown option or invalid generation number: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    local os
    os=$(detect_os)
    
    # Handle different actions
    if [[ "$list" == "true" ]]; then
        list_generations "$os"
    elif [[ "$interactive" == "true" ]]; then
        interactive_selection "$os"
    elif [[ -n "$generation" ]]; then
        rollback_to_generation "$os" "$generation"
    else
        rollback_previous "$os"
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi