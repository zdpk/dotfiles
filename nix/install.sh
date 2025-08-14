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

# Check if Nix is installed
check_nix_installed() {
    if command -v nix &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Install Nix
install_nix() {
    log_info "Installing Nix package manager..."
    
    if check_nix_installed; then
        log_warning "Nix is already installed"
        return 0
    fi
    
    # Install Nix with flakes enabled
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
    
    # Source Nix
    if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi
    
    log_success "Nix installed successfully"
}

# Install Home Manager
install_home_manager() {
    local os="$1"
    
    log_info "Installing Home Manager..."
    
    if [[ "$os" == "darwin" ]]; then
        # For macOS, we'll use nix-darwin which includes Home Manager
        log_info "On macOS, Home Manager will be managed by nix-darwin"
    else
        # For Linux, install Home Manager standalone
        nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
        nix-channel --update
        nix-shell '<home-manager>' -A install
    fi
    
    log_success "Home Manager setup completed"
}

# Install nix-darwin (macOS only)
install_nix_darwin() {
    log_info "Installing nix-darwin..."
    
    # Create a temporary configuration for nix-darwin installation
    nix run nix-darwin -- switch --flake .#default
    
    log_success "nix-darwin installed successfully"
}

# Apply dotfiles configuration
apply_dotfiles() {
    local os="$1"
    local current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    log_info "Applying dotfiles configuration..."
    
    cd "$current_dir"
    
    if [[ "$os" == "darwin" ]]; then
        # Apply using nix-darwin
        if command -v darwin-rebuild &> /dev/null; then
            darwin-rebuild switch --flake .#default
        else
            # First time installation
            nix run nix-darwin -- switch --flake .#default
        fi
        
        # Apply Home Manager configuration
        nix run home-manager -- switch --flake .#"x@macos"
        
        # Manual steps for macOS
        log_warning "Manual step required: Link fish global config with sudo:"
        log_warning "sudo ln -sf ~/.config/fish/global_config_darwin.fish /etc/fish/config.fish"
        
    else
        # Apply using Home Manager for Linux
        nix run home-manager -- switch --flake .#"x@linux"
    fi
    
    log_success "Dotfiles configuration applied successfully"
}

# Main installation function
main() {
    log_info "Starting Nix dotfiles installation..."
    
    local os
    os=$(detect_os)
    log_info "Detected OS: $os"
    
    # Install Nix if not present
    if ! check_nix_installed; then
        install_nix
    else
        log_success "Nix is already installed"
    fi
    
    # Install platform-specific tools
    case "$os" in
        "darwin")
            install_nix_darwin
            ;;
        "linux")
            install_home_manager "$os"
            ;;
    esac
    
    # Apply dotfiles configuration
    apply_dotfiles "$os"
    
    log_success "Installation completed successfully!"
    log_info "You may need to restart your shell or source your shell configuration."
    
    if [[ "$os" == "darwin" ]]; then
        log_info "Don't forget to run the manual fish config linking command mentioned above."
    fi
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi