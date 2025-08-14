#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

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

# Test assertion functions
assert_command_exists() {
    local cmd="$1"
    local desc="${2:-$cmd}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if command -v "$cmd" &> /dev/null; then
        log_success "✓ $desc command exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "✗ $desc command not found"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local desc="${2:-$file}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ -f "$file" ]]; then
        log_success "✓ $desc file exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "✗ $desc file not found"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    local desc="${3:-$pattern in $file}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ -f "$file" ]] && grep -q "$pattern" "$file"; then
        log_success "✓ $desc found"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "✗ $desc not found"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_directory_exists() {
    local dir="$1"
    local desc="${2:-$dir}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [[ -d "$dir" ]]; then
        log_success "✓ $desc directory exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "✗ $desc directory not found"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test functions
test_nix_installation() {
    log_info "Testing Nix installation..."
    
    assert_command_exists "nix" "Nix"
    
    # Test flakes support
    TESTS_RUN=$((TESTS_RUN + 1))
    if nix --version &> /dev/null && nix flake --help &> /dev/null; then
        log_success "✓ Nix flakes support enabled"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "✗ Nix flakes support not available"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_flake_syntax() {
    log_info "Testing flake syntax..."
    
    TESTS_RUN=$((TESTS_RUN + 1))
    if nix flake check . &> /dev/null; then
        log_success "✓ Flake syntax is valid"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "✗ Flake syntax errors found"
        nix flake check . || true
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_home_manager_build() {
    log_info "Testing Home Manager build..."
    
    local os_config
    if [[ "$OSTYPE" == "darwin"* ]]; then
        os_config="x@macos"
    else
        os_config="x@linux"
    fi
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Create a temporary build output to capture errors
    local build_output
    if build_output=$(nix build ".#homeConfigurations.\"$os_config\".activationPackage" --no-link --show-trace 2>&1); then
        log_success "✓ Home Manager configuration builds successfully"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "✗ Home Manager configuration build failed"
        
        # Show relevant error information without full trace
        if [[ "$build_output" =~ "error:" ]]; then
            echo "$build_output" | grep -A5 "error:" | head -10
        fi
        
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_program_configurations() {
    log_info "Testing individual program configurations..."
    
    # Test that program files exist
    assert_file_exists "common/programs/helix.nix" "Helix configuration"
    assert_file_exists "common/programs/fish.nix" "Fish configuration"
    assert_file_exists "common/programs/bash.nix" "Bash configuration"
    assert_file_exists "common/programs/wezterm.nix" "WezTerm configuration"
    assert_file_exists "common/programs/ghostty.nix" "Ghostty configuration"
    assert_file_exists "common/programs/zellij.nix" "Zellij configuration"
    assert_file_exists "common/programs/git.nix" "Git configuration"
    
    # Test that programs are properly configured
    assert_file_contains "common/programs/helix.nix" "programs.helix" "Helix program configuration"
    assert_file_contains "common/programs/fish.nix" "programs.fish" "Fish program configuration"
    assert_file_contains "common/programs/wezterm.nix" "programs.wezterm" "WezTerm program configuration"
    assert_file_contains "common/programs/git.nix" "programs.git" "Git program configuration"
}

test_system_configurations() {
    log_info "Testing system-specific configurations..."
    
    assert_file_exists "systems/darwin.nix" "macOS system configuration"
    assert_file_exists "systems/linux.nix" "Linux system configuration"
    assert_file_exists "users/darwin-user.nix" "macOS user configuration"
    assert_file_exists "users/linux-user.nix" "Linux user configuration"
}

test_scripts() {
    log_info "Testing management scripts..."
    
    assert_file_exists "install.sh" "Installation script"
    assert_file_exists "switch.sh" "Switch script"
    assert_file_exists "rollback.sh" "Rollback script"
    
    # Test script permissions
    TESTS_RUN=$((TESTS_RUN + 3))
    
    if [[ -x "install.sh" ]]; then
        log_success "✓ install.sh is executable"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "✗ install.sh is not executable"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    if [[ -x "switch.sh" ]]; then
        log_success "✓ switch.sh is executable"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "✗ switch.sh is not executable"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    if [[ -x "rollback.sh" ]]; then
        log_success "✓ rollback.sh is executable"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "✗ rollback.sh is not executable"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_after_installation() {
    log_info "Testing post-installation state..."
    
    # Test that Home Manager is available (may not be installed yet in fresh environment)
    if command -v home-manager &> /dev/null; then
        assert_command_exists "home-manager" "Home Manager"
    else
        log_warning "⚠ Home Manager not installed yet (normal for fresh environment)"
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
    
    # Test configuration directories
    assert_directory_exists "$HOME/.config" ".config directory"
    
    # Test that programs are available after installation
    local expected_programs=("hx" "fish" "bash" "git")
    
    for program in "${expected_programs[@]}"; do
        assert_command_exists "$program" "$program"
    done
    
    # Test configuration files were created
    if [[ -f "$HOME/.config/helix/config.toml" ]]; then
        log_success "✓ Helix configuration file created"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_warning "⚠ Helix configuration file not found (may not be activated yet)"
    fi
    
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Test summary
print_summary() {
    echo
    echo "==============================================="
    echo "               TEST SUMMARY"
    echo "==============================================="
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo "==============================================="
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed! 🎉"
        return 0
    else
        log_error "Some tests failed! ❌"
        return 1
    fi
}

# Main test execution
main() {
    log_info "Starting Nix dotfiles configuration tests..."
    echo
    
    # Pre-installation tests
    test_nix_installation
    test_flake_syntax
    test_home_manager_build
    test_program_configurations
    test_system_configurations
    test_scripts
    
    # Check if this is post-installation testing
    if [[ "${1:-}" == "--post-install" ]]; then
        test_after_installation
    fi
    
    print_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi