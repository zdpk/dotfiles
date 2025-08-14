# Nix Dotfiles Test Makefile
# Usage: make <target>

.PHONY: help test test-all test-ubuntu test-alpine test-nixos test-interactive
.PHONY: build build-all build-ubuntu build-alpine build-nixos
.PHONY: clean clean-containers clean-images clean-all
.PHONY: check lint validate install dry-run
.PHONY: ci performance security

# Default target
.DEFAULT_GOAL := help

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

# Variables
TEST_DIR := tests
TEST_RUNNER := $(TEST_DIR)/run-tests.sh
CONFIG_TEST := $(TEST_DIR)/scripts/test-config.sh
INTEGRATION_TEST := $(TEST_DIR)/scripts/integration-test.sh

help: ## Show this help message
	@echo "$(BLUE)Nix Dotfiles Test Commands$(NC)"
	@echo "=============================="
	@echo ""
	@echo "$(GREEN)Quick Tests:$(NC)"
	@echo "  make test              - Run tests on all platforms"
	@echo "  make test-ubuntu       - Test on Ubuntu only"
	@echo "  make test-alpine       - Test on Alpine only" 
	@echo "  make test-nixos        - Test on NixOS only"
	@echo "  make test-interactive  - Start interactive test environment"
	@echo ""
	@echo "$(GREEN)Build Commands:$(NC)"
	@echo "  make build             - Build all Docker images"
	@echo "  make build-ubuntu      - Build Ubuntu image only"
	@echo "  make build-alpine      - Build Alpine image only"
	@echo "  make build-nixos       - Build NixOS image only"
	@echo ""
	@echo "$(GREEN)Validation:$(NC)"
	@echo "  make check             - Quick configuration check"
	@echo "  make lint              - Lint and validate syntax"
	@echo "  make validate          - Full validation suite"
	@echo "  make dry-run           - Test installation (dry-run)"
	@echo ""
	@echo "$(GREEN)CI/Performance:$(NC)"
	@echo "  make ci                - Run full CI test suite"
	@echo "  make performance       - Run performance benchmarks"
	@echo "  make security          - Run security scans"
	@echo ""
	@echo "$(GREEN)Maintenance:$(NC)"
	@echo "  make clean             - Clean up test containers"
	@echo "  make clean-images      - Remove Docker images"
	@echo "  make clean-all         - Full cleanup"
	@echo "  make install           - Install dotfiles (interactive)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  $(GREEN)%-18s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Quick test commands
test: ## Run tests on all platforms
	@echo "$(BLUE)[INFO]$(NC) Running tests on all platforms..."
	@cd $(TEST_DIR) && ./run-tests.sh --clean all

test-all: test ## Alias for test

test-ubuntu: ## Test on Ubuntu environment only
	@echo "$(BLUE)[INFO]$(NC) Running tests on Ubuntu..."
	@cd $(TEST_DIR) && ./run-tests.sh --clean ubuntu

test-alpine: ## Test on Alpine environment only
	@echo "$(BLUE)[INFO]$(NC) Running tests on Alpine..."
	@cd $(TEST_DIR) && ./run-tests.sh --clean alpine

test-nixos: ## Test on NixOS environment only
	@echo "$(BLUE)[INFO]$(NC) Running tests on NixOS..."
	@cd $(TEST_DIR) && ./run-tests.sh --clean nixos

test-interactive: ## Start interactive test environment
	@echo "$(BLUE)[INFO]$(NC) Starting interactive test environment..."
	@echo "$(YELLOW)[TIP]$(NC) Use 'exit' to quit the container"
	@cd $(TEST_DIR) && ./run-tests.sh --interactive

# Build commands
build: build-all ## Build all Docker images

build-all: ## Build all Docker test images
	@echo "$(BLUE)[INFO]$(NC) Building all Docker images..."
	@cd $(TEST_DIR) && ./run-tests.sh --build ubuntu alpine nixos

build-ubuntu: ## Build Ubuntu Docker image
	@echo "$(BLUE)[INFO]$(NC) Building Ubuntu Docker image..."
	@cd $(TEST_DIR) && ./run-tests.sh --build ubuntu

build-alpine: ## Build Alpine Docker image  
	@echo "$(BLUE)[INFO]$(NC) Building Alpine Docker image..."
	@cd $(TEST_DIR) && ./run-tests.sh --build alpine

build-nixos: ## Build NixOS Docker image
	@echo "$(BLUE)[INFO]$(NC) Building NixOS Docker image..."
	@cd $(TEST_DIR) && ./run-tests.sh --build nixos

# Force rebuild (no cache)
rebuild: ## Force rebuild all images without cache
	@echo "$(BLUE)[INFO]$(NC) Force rebuilding all images without cache..."
	@cd $(TEST_DIR) && ./run-tests.sh --no-cache --build all

rebuild-ubuntu: ## Force rebuild Ubuntu image
	@cd $(TEST_DIR) && ./run-tests.sh --no-cache --build ubuntu

rebuild-alpine: ## Force rebuild Alpine image  
	@cd $(TEST_DIR) && ./run-tests.sh --no-cache --build alpine

rebuild-nixos: ## Force rebuild NixOS image
	@cd $(TEST_DIR) && ./run-tests.sh --no-cache --build nixos

# Validation commands
check: ## Quick configuration syntax check
	@echo "$(BLUE)[INFO]$(NC) Running quick configuration check..."
	@if command -v nix >/dev/null 2>&1; then \
		echo "$(GREEN)[CHECK]$(NC) Nix is available, running quick test..."; \
		$(TEST_DIR)/quick-test.sh; \
	else \
		echo "$(YELLOW)[SKIP]$(NC) Nix not available, using Docker for check..."; \
		cd $(TEST_DIR) && ./run-tests.sh --build nixos; \
	fi

lint: check ## Lint configuration files

validate: ## Run full validation suite
	@echo "$(BLUE)[INFO]$(NC) Running full validation suite..."
	@if [ -x "$(CONFIG_TEST)" ]; then \
		echo "$(GREEN)[VALIDATE]$(NC) Running configuration tests..."; \
		$(CONFIG_TEST); \
	else \
		echo "$(RED)[ERROR]$(NC) Test script not found or not executable"; \
		exit 1; \
	fi

dry-run: ## Test installation with dry-run
	@echo "$(BLUE)[INFO]$(NC) Testing installation (dry-run)..."
	@if command -v nix >/dev/null 2>&1; then \
		echo "$(GREEN)[DRY-RUN]$(NC) Testing Home Manager activation..."; \
		if [ "$$(uname)" = "Darwin" ]; then \
			nix run home-manager -- switch --flake '.#x@macos' --dry-run; \
		else \
			nix run home-manager -- switch --flake '.#x@linux' --dry-run; \
		fi \
	else \
		echo "$(YELLOW)[SKIP]$(NC) Nix not available, use 'make test' instead"; \
	fi

# CI and performance commands
ci: ## Run full CI test suite (matches GitHub Actions)
	@echo "$(BLUE)[INFO]$(NC) Running full CI test suite..."
	@echo "$(BLUE)[CI]$(NC) Step 1: Configuration validation"
	@make validate
	@echo "$(BLUE)[CI]$(NC) Step 2: Multi-platform testing"
	@make test-all
	@echo "$(BLUE)[CI]$(NC) Step 3: Performance testing"
	@make performance
	@echo "$(BLUE)[CI]$(NC) Step 4: Security scanning"
	@make security
	@echo "$(GREEN)[SUCCESS]$(NC) CI test suite completed!"

performance: ## Run performance benchmarks
	@echo "$(BLUE)[INFO]$(NC) Running performance benchmarks..."
	@if [ -x "$(INTEGRATION_TEST)" ]; then \
		echo "$(GREEN)[PERF]$(NC) Running integration tests with performance metrics..."; \
		$(INTEGRATION_TEST); \
	else \
		echo "$(YELLOW)[FALLBACK]$(NC) Running basic performance test..."; \
		if command -v nix >/dev/null 2>&1; then \
			echo "Testing flake evaluation time..."; \
			time nix flake show . >/dev/null; \
			echo "Testing build performance..."; \
			time nix build '.#homeConfigurations."x@linux".activationPackage' --no-link >/dev/null; \
		else \
			echo "$(YELLOW)[SKIP]$(NC) Nix not available"; \
		fi \
	fi

security: ## Run security scans
	@echo "$(BLUE)[INFO]$(NC) Running security scans..."
	@echo "$(GREEN)[SECURITY]$(NC) Checking for hardcoded secrets..."
	@if grep -r "password\|secret\|token" --include="*.nix" . | grep -v "programs.git"; then \
		echo "$(RED)[SECURITY]$(NC) Potential secrets found!"; \
		exit 1; \
	else \
		echo "$(GREEN)[OK]$(NC) No hardcoded secrets found"; \
	fi
	@echo "$(GREEN)[SECURITY]$(NC) Checking for suspicious patterns..."
	@if grep -r "eval\|exec" --include="*.nix" .; then \
		echo "$(RED)[SECURITY]$(NC) Potential code execution found!"; \
		exit 1; \
	else \
		echo "$(GREEN)[OK]$(NC) No suspicious patterns found"; \
	fi
	@echo "$(GREEN)[SECURITY]$(NC) Security scan completed"

# Maintenance commands  
clean: clean-containers ## Clean up test containers

clean-containers: ## Remove test containers
	@echo "$(BLUE)[INFO]$(NC) Cleaning up test containers..."
	@cd $(TEST_DIR) && docker-compose down --remove-orphans >/dev/null 2>&1 || true
	@docker container prune -f --filter label=com.docker.compose.project=nix >/dev/null 2>&1 || true
	@echo "$(GREEN)[CLEAN]$(NC) Test containers cleaned"

clean-images: ## Remove Docker images
	@echo "$(BLUE)[INFO]$(NC) Removing Docker images..."
	@docker image ls --format "table {{.Repository}}:{{.Tag}}" | grep "nix.*test" | awk '{print $$1}' | xargs -r docker image rm -f >/dev/null 2>&1 || true
	@echo "$(GREEN)[CLEAN]$(NC) Docker images removed"

clean-all: clean-containers clean-images ## Full cleanup (containers + images)
	@echo "$(BLUE)[INFO]$(NC) Running full cleanup..."
	@docker system prune -f >/dev/null 2>&1 || true
	@echo "$(GREEN)[CLEAN]$(NC) Full cleanup completed"

# Installation commands
install: ## Install dotfiles (interactive)
	@echo "$(BLUE)[INFO]$(NC) Starting dotfiles installation..."
	@echo "$(YELLOW)[WARNING]$(NC) This will modify your system configuration"
	@echo "Continue? [y/N] " && read ans && [ $${ans:-N} = y ]
	@./install.sh

switch: ## Apply configuration changes
	@echo "$(BLUE)[INFO]$(NC) Applying configuration changes..."
	@./switch.sh

rollback: ## Rollback to previous configuration
	@echo "$(BLUE)[INFO]$(NC) Rolling back configuration..."
	@./rollback.sh --interactive

# Development helpers
dev: test-interactive ## Alias for interactive development

debug: ## Debug test environment
	@echo "$(BLUE)[INFO]$(NC) Starting debug session..."
	@echo "$(YELLOW)[DEBUG]$(NC) Available debug commands:"
	@echo "  - make test-interactive  (interactive container)"
	@echo "  - make validate         (run validation tests)"
	@echo "  - make check           (quick syntax check)"
	@echo "  - docker logs <container>  (view container logs)"
	@cd $(TEST_DIR) && ./run-tests.sh --interactive

watch: ## Watch for changes and run tests
	@echo "$(BLUE)[INFO]$(NC) Watching for changes..."
	@echo "$(YELLOW)[TIP]$(NC) Install 'entr' for file watching"
	@if command -v entr >/dev/null 2>&1; then \
		find . -name "*.nix" | entr -c make check; \
	else \
		echo "$(RED)[ERROR]$(NC) 'entr' not found. Install with: brew install entr"; \
		exit 1; \
	fi

# Status and info commands
status: ## Show test environment status
	@echo "$(BLUE)[STATUS]$(NC) Test Environment Status"
	@echo "=============================="
	@echo "$(GREEN)Docker:$(NC)"
	@docker --version 2>/dev/null || echo "  Not available"
	@docker-compose --version 2>/dev/null || docker compose version 2>/dev/null || echo "  Compose not available"
	@echo ""
	@echo "$(GREEN)Nix:$(NC)"
	@if command -v nix >/dev/null 2>&1; then \
		nix --version; \
		echo "  Flakes: $$(nix --extra-experimental-features 'nix-command flakes' --version >/dev/null 2>&1 && echo 'Available' || echo 'Not available')"; \
	else \
		echo "  Not available"; \
	fi
	@echo ""
	@echo "$(GREEN)Test Files:$(NC)"
	@echo "  Configuration test: $$([ -x '$(CONFIG_TEST)' ] && echo 'Ready' || echo 'Missing')"
	@echo "  Integration test: $$([ -x '$(INTEGRATION_TEST)' ] && echo 'Ready' || echo 'Missing')"
	@echo "  Test runner: $$([ -x '$(TEST_RUNNER)' ] && echo 'Ready' || echo 'Missing')"
	@echo ""
	@echo "$(GREEN)Docker Images:$(NC)"
	@docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" | grep -E "(REPOSITORY|nix.*test)" || echo "  No test images found"

info: status ## Alias for status

# Quick shortcuts
t: test ## Quick alias for test
b: build ## Quick alias for build  
c: clean ## Quick alias for clean
i: test-interactive ## Quick alias for interactive
v: validate ## Quick alias for validate