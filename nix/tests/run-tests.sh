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

# Show help
show_help() {
    cat << EOF
Nix Dotfiles Test Runner

Usage: $0 [OPTIONS] [TARGETS]

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -i, --interactive   Run interactive test environment
    -c, --clean         Clean up test containers after running
    --build             Force rebuild Docker images
    --no-cache          Build Docker images without cache

TARGETS:
    ubuntu              Run tests on Ubuntu
    alpine              Run tests on Alpine Linux
    nixos               Run tests on NixOS
    all                 Run tests on all platforms (default)

EXAMPLES:
    $0                  Run tests on all platforms
    $0 ubuntu           Run tests only on Ubuntu
    $0 --interactive    Start interactive test environment
    $0 --clean all      Run all tests and cleanup containers

EOF
}

# Check requirements
check_requirements() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is required but not installed"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! command -v docker compose &> /dev/null; then
        log_error "Docker Compose is required but not installed"
        exit 1
    fi
    
    # Determine docker-compose command
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
    else
        DOCKER_COMPOSE="docker compose"
    fi
    
    export DOCKER_COMPOSE
}

# Build test images
build_images() {
    local no_cache="$1"
    local targets=("${@:2}")
    
    log_info "Building Docker test images..."
    
    local build_args=()
    [[ "$no_cache" == "true" ]] && build_args+=(--no-cache)
    
    cd "$(dirname "${BASH_SOURCE[0]}")"
    
    if [[ "${#targets[@]}" -eq 0 ]] || [[ " ${targets[*]} " =~ " ubuntu " ]] || [[ " ${targets[*]} " =~ " all " ]]; then
        log_info "Building Ubuntu test image..."
        $DOCKER_COMPOSE build "${build_args[@]}" test-ubuntu
    fi
    
    if [[ "${#targets[@]}" -eq 0 ]] || [[ " ${targets[*]} " =~ " alpine " ]] || [[ " ${targets[*]} " =~ " all " ]]; then
        log_info "Building Alpine test image..."
        $DOCKER_COMPOSE build "${build_args[@]}" test-alpine
    fi
    
    if [[ "${#targets[@]}" -eq 0 ]] || [[ " ${targets[*]} " =~ " nixos " ]] || [[ " ${targets[*]} " =~ " all " ]]; then
        log_info "Building NixOS test image..."
        $DOCKER_COMPOSE build "${build_args[@]}" test-nixos
    fi
    
    log_success "Docker images built successfully"
}

# Run tests on specific target
run_test_target() {
    local target="$1"
    local verbose="$2"
    
    log_info "Running tests on $target..."
    
    local run_args=()
    [[ "$verbose" == "true" ]] && run_args+=(--verbose)
    
    cd "$(dirname "${BASH_SOURCE[0]}")"
    
    case "$target" in
        ubuntu)
            if $DOCKER_COMPOSE run --rm test-ubuntu; then
                log_success "✓ Ubuntu tests passed"
                return 0
            else
                log_error "✗ Ubuntu tests failed"
                return 1
            fi
            ;;
        alpine)
            if $DOCKER_COMPOSE run --rm test-alpine; then
                log_success "✓ Alpine tests passed"
                return 0
            else
                log_error "✗ Alpine tests failed"
                return 1
            fi
            ;;
        nixos)
            if $DOCKER_COMPOSE run --rm test-nixos; then
                log_success "✓ NixOS tests passed"
                return 0
            else
                log_error "✗ NixOS tests failed"
                return 1
            fi
            ;;
        *)
            log_error "Unknown target: $target"
            return 1
            ;;
    esac
}

# Run interactive environment
run_interactive() {
    log_info "Starting interactive test environment..."
    
    cd "$(dirname "${BASH_SOURCE[0]}")"
    
    log_info "Building interactive environment..."
    $DOCKER_COMPOSE build test-interactive
    
    log_info "Starting container... (type 'exit' to quit)"
    log_info "Available commands in container:"
    log_info "  - tests/scripts/test-config.sh       (run configuration tests)"
    log_info "  - tests/scripts/integration-test.sh  (run integration tests)"
    log_info "  - ./install.sh                       (test installation)"
    log_info "  - nix flake check                     (check flake syntax)"
    
    $DOCKER_COMPOSE run --rm test-interactive
}

# Cleanup containers
cleanup_containers() {
    log_info "Cleaning up test containers..."
    
    cd "$(dirname "${BASH_SOURCE[0]}")"
    
    $DOCKER_COMPOSE down --remove-orphans
    docker system prune -f --filter label=com.docker.compose.project=nix_tests
    
    log_success "Cleanup completed"
}

# Main test runner
main() {
    local verbose=false
    local interactive=false
    local clean=false
    local build_images_flag=false
    local no_cache=false
    local targets=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -i|--interactive)
                interactive=true
                shift
                ;;
            -c|--clean)
                clean=true
                shift
                ;;
            --build)
                build_images_flag=true
                shift
                ;;
            --no-cache)
                no_cache=true
                build_images_flag=true
                shift
                ;;
            ubuntu|alpine|nixos|all)
                targets+=("$1")
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Default to all targets if none specified
    if [[ ${#targets[@]} -eq 0 ]] && [[ "$interactive" != "true" ]]; then
        targets=("all")
    fi
    
    # Check requirements
    check_requirements
    
    # Handle interactive mode
    if [[ "$interactive" == "true" ]]; then
        run_interactive
        return 0
    fi
    
    # Build images if requested or if they don't exist
    if [[ "$build_images_flag" == "true" ]]; then
        build_images "$no_cache" "${targets[@]}"
    fi
    
    # Run tests
    local failed_tests=()
    local test_targets=()
    
    # Expand 'all' target
    for target in "${targets[@]}"; do
        if [[ "$target" == "all" ]]; then
            test_targets+=(ubuntu alpine nixos)
        else
            test_targets+=("$target")
        fi
    done
    
    # Remove duplicates
    IFS=" " read -r -a test_targets <<< "$(printf "%s\n" "${test_targets[@]}" | sort -u | tr '\n' ' ')"
    
    log_info "Running tests on: ${test_targets[*]}"
    
    for target in "${test_targets[@]}"; do
        if ! run_test_target "$target" "$verbose"; then
            failed_tests+=("$target")
        fi
    done
    
    # Cleanup if requested
    if [[ "$clean" == "true" ]]; then
        cleanup_containers
    fi
    
    # Report results
    echo
    echo "=============================================="
    echo "                TEST RESULTS"
    echo "=============================================="
    
    if [[ ${#failed_tests[@]} -eq 0 ]]; then
        log_success "All tests passed! 🎉"
        echo "Platforms tested: ${test_targets[*]}"
        exit 0
    else
        log_error "Some tests failed! ❌"
        echo "Failed platforms: ${failed_tests[*]}"
        echo "Successful platforms: $(printf '%s\n' "${test_targets[@]}" "${failed_tests[@]}" | sort | uniq -u | tr '\n' ' ')"
        exit 1
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi