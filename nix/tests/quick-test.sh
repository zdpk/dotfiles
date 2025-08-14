#!/usr/bin/env bash
set -euo pipefail

# Quick test script for immediate feedback
# Usage: ./quick-test.sh [platform]

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Quick syntax check
quick_check() {
    log_info "Running quick syntax check..."
    
    if ! command -v nix >/dev/null 2>&1; then
        log_error "Nix not available for quick check"
        return 1
    fi
    
    if nix flake check --show-trace; then
        log_success "✓ Flake syntax is valid"
        return 0
    else
        log_error "✗ Flake syntax errors found"
        return 1
    fi
}

# Quick build test
quick_build() {
    local platform="${1:-linux}"
    
    log_info "Testing quick build for $platform..."
    
    local config="x@$platform"
    if [[ "$platform" == "darwin" ]]; then
        config="x@macos"
    fi
    
    if nix build ".#homeConfigurations.\"$config\".activationPackage" --no-link; then
        log_success "✓ Configuration builds successfully"
        return 0
    else
        log_error "✗ Build failed"
        return 1
    fi
}

# Main function
main() {
    local platform="linux"
    
    if [[ $# -gt 0 ]]; then
        platform="$1"
    fi
    
    echo "$(tput bold)Quick Test - Nix Dotfiles$(tput sgr0)"
    echo "==============================="
    echo ""
    
    # Run checks
    if quick_check && quick_build "$platform"; then
        log_success "Quick test passed! ✨"
        echo ""
        echo "To run full tests:"
        echo "  make test              (all platforms)"
        echo "  make test-ubuntu       (Ubuntu only)"
        echo "  make test-interactive  (interactive mode)"
        exit 0
    else
        log_error "Quick test failed! ❌"
        echo ""
        echo "Debug commands:"
        echo "  nix flake check --show-trace"
        echo "  make test-interactive"
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi