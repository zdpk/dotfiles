# Dotfiles Project Makefile
# Root makefile for both legacy and Nix configurations

.PHONY: help setup setup-legacy setup-nix test test-nix clean status

# Default target
.DEFAULT_GOAL := help

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

help: ## Show available commands
	@echo "$(BLUE)Dotfiles Project$(NC)"
	@echo "================="
	@echo ""
	@echo "$(GREEN)Setup Commands:$(NC)"
	@echo "  make setup        - Interactive setup (choose legacy or Nix)"
	@echo "  make setup-legacy - Setup legacy dotfiles (./setup.sh)"
	@echo "  make setup-nix    - Setup Nix dotfiles (nix/install.sh)"
	@echo ""
	@echo "$(GREEN)Testing:$(NC)"
	@echo "  make test         - Test Nix configuration"
	@echo "  make test-nix     - Detailed Nix testing menu"
	@echo ""
	@echo "$(GREEN)Maintenance:$(NC)"
	@echo "  make clean        - Clean up test environments"
	@echo "  make status       - Show project status"
	@echo ""

setup: ## Interactive setup - choose between legacy and Nix
	@echo "$(BLUE)[SETUP]$(NC) Dotfiles Installation"
	@echo "==============================="
	@echo ""
	@echo "Choose your installation method:"
	@echo "  1) Legacy dotfiles (traditional shell scripts)"
	@echo "  2) Nix dotfiles (declarative, reproducible)"
	@echo "  3) Show differences"
	@echo ""
	@printf "Enter your choice [1-3]: "; \
	read choice; \
	case $$choice in \
		1) make setup-legacy ;; \
		2) make setup-nix ;; \
		3) make show-differences ;; \
		*) echo "$(YELLOW)[INFO]$(NC) Invalid choice. Run 'make setup' again." ;; \
	esac

setup-legacy: ## Setup legacy dotfiles using setup.sh
	@echo "$(BLUE)[LEGACY]$(NC) Setting up legacy dotfiles..."
	@if [ -f setup.sh ]; then \
		chmod +x setup.sh; \
		./setup.sh; \
	else \
		echo "$(YELLOW)[ERROR]$(NC) setup.sh not found"; \
		exit 1; \
	fi

setup-nix: ## Setup Nix dotfiles
	@echo "$(BLUE)[NIX]$(NC) Setting up Nix dotfiles..."
	@if [ -f nix/install.sh ]; then \
		cd nix && ./install.sh; \
	else \
		echo "$(YELLOW)[ERROR]$(NC) nix/install.sh not found"; \
		exit 1; \
	fi

show-differences: ## Show differences between legacy and Nix approaches
	@echo "$(BLUE)[INFO]$(NC) Legacy vs Nix Dotfiles Comparison"
	@echo "==========================================="
	@echo ""
	@echo "$(GREEN)Legacy Dotfiles:$(NC)"
	@echo "  ✓ Simple shell scripts and symlinks"
	@echo "  ✓ Quick setup and familiar approach"  
	@echo "  ✓ Direct file management"
	@echo "  ✗ Manual dependency management"
	@echo "  ✗ No atomic updates or easy rollback"
	@echo "  ✗ Environment inconsistencies possible"
	@echo ""
	@echo "$(GREEN)Nix Dotfiles:$(NC)"
	@echo "  ✓ Declarative and reproducible"
	@echo "  ✓ Atomic updates with easy rollback"
	@echo "  ✓ Automatic dependency management"
	@echo "  ✓ Cross-platform consistency"
	@echo "  ✗ Learning curve for Nix"
	@echo "  ✗ More complex setup initially"
	@echo ""
	@echo "$(YELLOW)[RECOMMENDATION]$(NC) Use Nix for new setups, Legacy for quick testing"

test: test-nix ## Run Nix configuration tests

test-nix: ## Show Nix testing options
	@echo "$(BLUE)[TEST]$(NC) Nix Dotfiles Testing"
	@echo "============================="
	@echo ""
	@echo "Available test commands:"
	@echo "  1) make -C nix test           - Quick test on all platforms"
	@echo "  2) make -C nix test-ubuntu    - Test on Ubuntu only"
	@echo "  3) make -C nix test-alpine    - Test on Alpine only"
	@echo "  4) make -C nix test-nixos     - Test on NixOS only"
	@echo "  5) make -C nix test-interactive - Interactive test environment"
	@echo "  6) make -C nix ci             - Full CI test suite"
	@echo "  7) make -C nix check          - Quick syntax check"
	@echo ""
	@printf "Enter your choice [1-7] or press Enter for quick test: "; \
	read choice; \
	case $$choice in \
		1|"") make -C nix test ;; \
		2) make -C nix test-ubuntu ;; \
		3) make -C nix test-alpine ;; \
		4) make -C nix test-nixos ;; \
		5) make -C nix test-interactive ;; \
		6) make -C nix ci ;; \
		7) make -C nix check ;; \
		*) echo "$(YELLOW)[INFO]$(NC) Invalid choice. Try again." ;; \
	esac

clean: ## Clean up test environments
	@echo "$(BLUE)[CLEAN]$(NC) Cleaning up test environments..."
	@if [ -f nix/Makefile ]; then \
		make -C nix clean-all; \
	fi
	@echo "$(GREEN)[CLEAN]$(NC) Cleanup completed"

status: ## Show project status
	@echo "$(BLUE)[STATUS]$(NC) Dotfiles Project Status"
	@echo "==============================="
	@echo ""
	@echo "$(GREEN)Available Configurations:$(NC)"
	@if [ -f setup.sh ]; then \
		echo "  ✓ Legacy dotfiles (setup.sh)"; \
	else \
		echo "  ✗ Legacy dotfiles (setup.sh not found)"; \
	fi
	@if [ -f nix/flake.nix ]; then \
		echo "  ✓ Nix dotfiles (nix/flake.nix)"; \
	else \
		echo "  ✗ Nix dotfiles (nix/flake.nix not found)"; \
	fi
	@echo ""
	@echo "$(GREEN)System Information:$(NC)"
	@echo "  OS: $$(uname -s)"
	@echo "  Architecture: $$(uname -m)"
	@if command -v nix >/dev/null 2>&1; then \
		echo "  Nix: $$(nix --version | head -1)"; \
	else \
		echo "  Nix: Not installed"; \
	fi
	@if command -v docker >/dev/null 2>&1; then \
		echo "  Docker: $$(docker --version | cut -d',' -f1)"; \
	else \
		echo "  Docker: Not installed"; \
	fi
	@echo ""
	@echo "$(GREEN)Configuration Files:$(NC)"
	@find config -name "*.fish" -o -name "*.sh" -o -name "*.toml" -o -name "*.lua" -o -name "*.kdl" 2>/dev/null | head -10 | sed 's/^/  /' || echo "  No config files found"
	@if [ -d nix ]; then \
		echo ""; \
		echo "$(GREEN)Nix Configuration Files:$(NC)"; \
		find nix -name "*.nix" | head -10 | sed 's/^/  /' || echo "  No Nix files found"; \
	fi

# Development helpers
dev-nix: ## Start Nix development environment  
	@make -C nix test-interactive

update-nix: ## Update Nix configuration
	@if [ -f nix/switch.sh ]; then \
		cd nix && ./switch.sh; \
	else \
		echo "$(YELLOW)[ERROR]$(NC) nix/switch.sh not found"; \
	fi

rollback-nix: ## Rollback Nix configuration
	@if [ -f nix/rollback.sh ]; then \
		cd nix && ./rollback.sh; \
	else \
		echo "$(YELLOW)[ERROR]$(NC) nix/rollback.sh not found"; \
	fi

# Documentation
docs: ## Show documentation locations
	@echo "$(BLUE)[DOCS]$(NC) Documentation Locations"
	@echo "=============================="
	@echo ""
	@if [ -f README.md ]; then \
		echo "  ✓ Main README: ./README.md"; \
	fi
	@if [ -f nix/README.md ]; then \
		echo "  ✓ Nix README: ./nix/README.md"; \
	fi
	@if [ -f nix/tests/README.md ]; then \
		echo "  ✓ Testing Guide: ./nix/tests/README.md"; \
	fi
	@echo ""
	@echo "$(GREEN)Quick Commands:$(NC)"
	@echo "  View main README: less README.md"
	@echo "  View Nix guide: less nix/README.md"
	@echo "  View test guide: less nix/tests/README.md"

# Aliases for convenience
install: setup ## Alias for setup
build: test ## Alias for test  
check: status ## Alias for status