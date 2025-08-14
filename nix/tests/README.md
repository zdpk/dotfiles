# Nix Dotfiles Testing

Comprehensive testing suite for the Nix dotfiles configuration, supporting multiple Linux distributions and automated CI/CD testing.

## 🎯 Overview

This testing framework provides:

- **Multi-platform testing**: Ubuntu, Alpine, NixOS
- **Docker-based isolation**: Clean test environments
- **Configuration validation**: Syntax and build verification
- **Integration testing**: End-to-end functionality tests
- **Performance monitoring**: Build and evaluation benchmarks
- **Security scanning**: Secret detection and pattern analysis
- **CI/CD integration**: GitHub Actions automated testing

## 📁 Test Structure

```
tests/
├── docker/
│   ├── Dockerfile.ubuntu       # Ubuntu test environment
│   ├── Dockerfile.alpine       # Alpine Linux test environment
│   └── Dockerfile.nixos        # NixOS test environment
├── scripts/
│   ├── test-config.sh          # Configuration validation tests
│   └── integration-test.sh     # Integration test suite
├── docker-compose.yml          # Multi-container orchestration
├── run-tests.sh               # Main test runner script
└── README.md                  # This documentation
```

## 🚀 Quick Start

### Prerequisites

- Docker (20.10+)
- Docker Compose (2.0+) or Docker with compose plugin

### Running Tests

**Run all tests on all platforms:**
```bash
cd nix/tests
./run-tests.sh
```

**Run tests on specific platform:**
```bash
./run-tests.sh ubuntu          # Ubuntu only
./run-tests.sh alpine          # Alpine only
./run-tests.sh nixos           # NixOS only
```

**Interactive testing environment:**
```bash
./run-tests.sh --interactive
```

## 🔧 Test Commands

### Basic Commands

| Command | Description |
|---------|-------------|
| `./run-tests.sh` | Run all tests on all platforms |
| `./run-tests.sh --help` | Show help and usage |
| `./run-tests.sh --interactive` | Start interactive test shell |
| `./run-tests.sh --clean all` | Run tests and cleanup containers |

### Advanced Options

| Option | Description |
|--------|-------------|
| `--verbose` | Enable detailed output |
| `--build` | Force rebuild Docker images |
| `--no-cache` | Build images without Docker cache |
| `--clean` | Cleanup containers after testing |

## 🧪 Test Categories

### 1. Configuration Tests (`test-config.sh`)

Validates the Nix configuration syntax and structure:

- **Nix Installation**: Verify Nix is properly installed
- **Flake Syntax**: Check flake.nix syntax validity
- **Home Manager Build**: Test configuration compilation
- **Program Configurations**: Validate individual program settings
- **System Configurations**: Check platform-specific configs
- **Script Permissions**: Verify management scripts are executable

**Run separately:**
```bash
cd nix
tests/scripts/test-config.sh
```

### 2. Integration Tests (`integration-test.sh`)

End-to-end functionality testing:

- **Full Installation**: Test complete setup process
- **Program Functionality**: Validate program-specific features
- **Cross-platform Compatibility**: Test platform differences
- **Management Scripts**: Verify install/switch/rollback scripts
- **Performance Benchmarks**: Measure evaluation and build times

**Run separately:**
```bash
cd nix
tests/scripts/integration-test.sh
```

### 3. Docker Environment Tests

Multi-platform testing in isolated containers:

- **Ubuntu 22.04**: Standard Linux distribution testing
- **Alpine 3.18**: Lightweight Linux testing
- **NixOS Latest**: Native Nix environment testing

## 🐳 Docker Environments

### Ubuntu Environment (`Dockerfile.ubuntu`)
- **Base**: ubuntu:22.04
- **Features**: Multi-user Nix installation, systemd support
- **Use case**: Standard Linux distribution testing

### Alpine Environment (`Dockerfile.alpine`)
- **Base**: alpine:3.18
- **Features**: Single-user Nix installation, minimal footprint
- **Use case**: Lightweight environment testing

### NixOS Environment (`Dockerfile.nixos`)
- **Base**: nixos/nix:latest
- **Features**: Native Nix support, pure environment
- **Use case**: Nix-native environment testing

## 🔄 CI/CD Integration

### GitHub Actions Workflow

The test suite integrates with GitHub Actions for automated testing:

**Workflow triggers:**
- Push to main/develop branches (nix/** changes)
- Pull requests to main branch
- Manual workflow dispatch

**Test matrix:**
- Lint and syntax checking
- Multi-platform Docker testing
- Integration testing
- Performance benchmarking
- Security scanning

**View workflow:**
```yaml
# .github/workflows/test.yml
name: Test Nix Dotfiles
on: [push, pull_request]
jobs:
  test-linux: # Tests on Ubuntu, Alpine, NixOS
  test-integration: # Integration and functionality tests
  test-performance: # Performance benchmarks
  security-scan: # Security analysis
```

### Running CI Tests Locally

Simulate GitHub Actions locally:

```bash
# Run the same tests as CI
./run-tests.sh --build --clean all

# Test specific environment
./run-tests.sh ubuntu

# Performance testing
cd nix
tests/scripts/integration-test.sh
```

## 🛠️ Manual Testing

### Interactive Development

Start an interactive environment for manual testing:

```bash
./run-tests.sh --interactive
```

**Inside the container:**
```bash
# Test configuration syntax
nix flake check

# Build configuration
nix build '.#homeConfigurations."x@linux".activationPackage' --no-link

# Dry-run installation
nix run home-manager -- switch --flake '.#x@linux' --dry-run

# Run individual tests
tests/scripts/test-config.sh
tests/scripts/integration-test.sh
```

### Custom Testing

Create custom test scenarios:

```bash
# Test specific program configuration
nix build '.#homeConfigurations."x@linux".config.programs.helix.package'

# Test flake evaluation time
time nix flake show .

# Test with different Nix versions
docker run --rm -v $(pwd):/dotfiles nixos/nix:2.18 bash -c "cd /dotfiles/nix && nix flake check"
```

## 📊 Performance Testing

### Benchmarks Tracked

- **Flake Evaluation Time**: < 10 seconds
- **Configuration Build Time**: < 120 seconds  
- **Memory Usage**: Monitored during builds
- **Cache Effectiveness**: Build speed with/without cache

### Running Performance Tests

```bash
# Full performance suite
tests/scripts/integration-test.sh

# Quick evaluation test  
time nix flake show .

# Build performance
time nix build '.#homeConfigurations."x@linux".activationPackage' --no-link
```

## 🔒 Security Testing

### Security Checks

- **Secret Detection**: Scan for hardcoded credentials
- **Suspicious Patterns**: Check for eval/exec usage
- **Dependency Analysis**: Verify package integrity
- **Configuration Safety**: Validate secure defaults

### Running Security Scans

```bash
# Check for secrets
grep -r "password\|secret\|token" --include="*.nix" nix/

# Pattern analysis
grep -r "eval\|exec" --include="*.nix" nix/

# Full security scan (requires trufflehog)
trufflehog filesystem nix/ --only-verified
```

## 🐛 Troubleshooting

### Common Issues

#### Docker Build Failures
```bash
# Clear Docker cache and rebuild
docker system prune -f
./run-tests.sh --no-cache ubuntu
```

#### Nix Evaluation Errors
```bash
# Check flake syntax
cd nix
nix flake check --show-trace

# Test specific configuration
nix build '.#homeConfigurations."x@linux".activationPackage' --show-trace
```

#### Container Permission Issues
```bash
# Ensure proper file permissions
find nix/tests -name "*.sh" -exec chmod +x {} \;
```

#### Test Script Failures
```bash
# Run with verbose output
./run-tests.sh --verbose ubuntu

# Check individual test components
cd nix
tests/scripts/test-config.sh
```

### Debug Mode

Enable detailed debugging:

```bash
# Verbose test execution
./run-tests.sh --verbose all

# Interactive debugging
./run-tests.sh --interactive
# Then inside container:
bash -x tests/scripts/test-config.sh
```

## 📈 Test Results

### Success Criteria

Tests pass when:
- ✅ All configuration files have valid syntax
- ✅ Home Manager builds successfully on target platform
- ✅ All expected programs are configured
- ✅ Management scripts are executable and functional
- ✅ No security issues detected
- ✅ Performance benchmarks met

### Failure Analysis

When tests fail:
1. **Check logs**: Use `--verbose` for detailed output
2. **Isolate issue**: Run specific test categories
3. **Validate syntax**: Use `nix flake check --show-trace`
4. **Test interactively**: Use `--interactive` mode
5. **Check permissions**: Verify script executability

## 🤝 Contributing

### Adding New Tests

1. **Configuration tests**: Add to `test-config.sh`
2. **Integration tests**: Add to `integration-test.sh`  
3. **Platform tests**: Create new Dockerfile
4. **CI tests**: Update `.github/workflows/test.yml`

### Test Guidelines

- All tests should be idempotent
- Use descriptive test names and error messages
- Include both positive and negative test cases
- Document expected behavior and failure modes
- Test on multiple platforms when possible

### Example Test Addition

```bash
# In test-config.sh
test_new_feature() {
    log_info "Testing new feature..."
    
    assert_file_contains "common/programs/new-program.nix" "programs.new-program" "New program configuration"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    if nix build '.#homeConfigurations."x@linux".config.programs.new-program.package' --no-link; then
        log_success "✓ New program builds successfully"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "✗ New program build failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}
```

## 📚 Resources

- [Docker Documentation](https://docs.docker.com/)
- [Nix Manual](https://nixos.org/manual/nix/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## 📄 License

This testing framework is part of the dotfiles project and follows the same license terms.