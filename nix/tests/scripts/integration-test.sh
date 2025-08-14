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

# Test environment setup
setup_test_env() {
    log_info "Setting up test environment..."
    
    # Create temporary directories for testing
    export TEST_HOME="/tmp/nixtest-$$"
    export HOME="$TEST_HOME"
    
    mkdir -p "$TEST_HOME"
    cd "$TEST_HOME"
    
    # Copy dotfiles to test location
    cp -r "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")" ./dotfiles
    cd dotfiles
    
    log_success "Test environment created at $TEST_HOME"
}

# Cleanup test environment
cleanup_test_env() {
    if [[ -n "${TEST_HOME:-}" ]] && [[ -d "$TEST_HOME" ]]; then
        log_info "Cleaning up test environment..."
        rm -rf "$TEST_HOME"
        log_success "Test environment cleaned up"
    fi
}

# Test full installation process
test_full_installation() {
    log_info "Testing full installation process..."
    
    # Source Nix environment
    if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    elif [[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
        source "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi
    
    # Test Home Manager configuration build
    local os_config
    if [[ "$OSTYPE" == "darwin"* ]]; then
        os_config="x@macos"
    else
        os_config="x@linux"
    fi
    
    log_info "Building Home Manager configuration for $os_config..."
    
    if nix build ".#homeConfigurations.\"$os_config\".activationPackage" --no-link; then
        log_success "✓ Home Manager configuration builds successfully"
    else
        log_error "✗ Home Manager configuration build failed"
        return 1
    fi
    
    # Test dry-run activation
    log_info "Testing dry-run activation..."
    
    if nix run home-manager -- switch --flake ".#$os_config" --dry-run; then
        log_success "✓ Dry-run activation successful"
    else
        log_error "✗ Dry-run activation failed"
        return 1
    fi
}

# Test configuration validation
test_configuration_validation() {
    log_info "Running configuration validation tests..."
    
    local script_dir="$(dirname "${BASH_SOURCE[0]}")"
    
    if [[ -f "$script_dir/test-config.sh" ]]; then
        bash "$script_dir/test-config.sh"
    else
        log_error "test-config.sh not found"
        return 1
    fi
}

# Test program-specific functionality
test_program_functionality() {
    log_info "Testing program-specific functionality..."
    
    # Test Helix configuration syntax
    log_info "Validating Helix configuration..."
    if grep -q "github_dark_dimmed" common/programs/helix.nix; then
        log_success "✓ Helix theme configuration found"
    else
        log_warning "⚠ Helix theme configuration not found"
    fi
    
    # Test Fish configuration
    log_info "Validating Fish configuration..."
    if grep -q "bass" common/programs/fish.nix; then
        log_success "✓ Fish bass plugin configuration found"
    else
        log_warning "⚠ Fish bass plugin configuration not found"
    fi
    
    # Test WezTerm configuration
    log_info "Validating WezTerm configuration..."
    if grep -q "GitHub Dark" common/programs/wezterm.nix; then
        log_success "✓ WezTerm color scheme configuration found"
    else
        log_warning "⚠ WezTerm color scheme configuration not found"
    fi
    
    # Test Git configuration
    log_info "Validating Git configuration..."
    if grep -q "programs.git" common/programs/git.nix; then
        log_success "✓ Git program configuration found"
    else
        log_error "✗ Git program configuration not found"
        return 1
    fi
}

# Test cross-platform compatibility
test_cross_platform() {
    log_info "Testing cross-platform compatibility..."
    
    # Test that both platform configurations exist
    if [[ -f "systems/darwin.nix" ]] && [[ -f "systems/linux.nix" ]]; then
        log_success "✓ Both platform configurations exist"
    else
        log_error "✗ Missing platform configurations"
        return 1
    fi
    
    # Test that user configurations exist
    if [[ -f "users/darwin-user.nix" ]] && [[ -f "users/linux-user.nix" ]]; then
        log_success "✓ Both user configurations exist"
    else
        log_error "✗ Missing user configurations"
        return 1
    fi
    
    # Test that flake outputs are defined for both platforms
    if grep -q "darwinConfigurations" flake.nix && grep -q "homeConfigurations" flake.nix; then
        log_success "✓ Flake outputs defined for both platforms"
    else
        log_error "✗ Missing platform outputs in flake.nix"
        return 1
    fi
}

# Test management scripts
test_management_scripts() {
    log_info "Testing management scripts..."
    
    # Test script help functions
    if ./install.sh --help > /dev/null 2>&1; then
        log_success "✓ install.sh help works"
    else
        log_warning "⚠ install.sh help not available"
    fi
    
    if ./switch.sh --help > /dev/null 2>&1; then
        log_success "✓ switch.sh help works"
    else
        log_warning "⚠ switch.sh help not available"
    fi
    
    if ./rollback.sh --help > /dev/null 2>&1; then
        log_success "✓ rollback.sh help works"
    else
        log_warning "⚠ rollback.sh help not available"
    fi
}

# Performance test
test_performance() {
    log_info "Running performance tests..."
    
    local start_time=$(date +%s)
    
    # Test flake evaluation time
    log_info "Measuring flake evaluation time..."
    local eval_start=$(date +%s.%N)
    nix flake show . > /dev/null 2>&1
    local eval_end=$(date +%s.%N)
    local eval_time=$(echo "$eval_end - $eval_start" | bc -l 2>/dev/null || echo "unknown")
    
    if [[ "$eval_time" != "unknown" ]] && (( $(echo "$eval_time < 10" | bc -l) )); then
        log_success "✓ Flake evaluation completed in ${eval_time}s (< 10s)"
    else
        log_warning "⚠ Flake evaluation took ${eval_time}s (might be slow)"
    fi
    
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    
    log_info "Total performance test time: ${total_time}s"
}

# Main integration test
main() {
    local cleanup=true
    local run_installation=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-cleanup)
                cleanup=false
                shift
                ;;
            --with-installation)
                run_installation=true
                shift
                ;;
            --help)
                cat << EOF
Integration test for Nix dotfiles

Usage: $0 [OPTIONS]

Options:
    --no-cleanup        Don't cleanup test environment after running
    --with-installation Run full installation test (requires privileges)
    --help             Show this help message

EOF
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Trap to ensure cleanup
    if [[ "$cleanup" == "true" ]]; then
        trap cleanup_test_env EXIT
    fi
    
    log_info "Starting Nix dotfiles integration tests..."
    echo "=============================================="
    
    # Setup test environment
    setup_test_env
    
    # Run tests
    test_configuration_validation
    test_program_functionality
    test_cross_platform
    test_management_scripts
    test_performance
    
    # Run installation test if requested
    if [[ "$run_installation" == "true" ]]; then
        test_full_installation
    fi
    
    log_success "Integration tests completed! 🎉"
    echo "=============================================="
    
    if [[ "$cleanup" == "false" ]]; then
        log_info "Test environment preserved at: $TEST_HOME"
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi