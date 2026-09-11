.PHONY: help setup input-sources input-sources-dry-run dry-run test

.DEFAULT_GOAL := help

# Override per machine: make setup MODE=ko-en-ja FONT=geist
MODE ?=
FONT ?= firacode

help:
	@printf '%s\n' \
	  'make setup    Apply common and platform-specific Bash modules' \
	  'make input-sources  Apply only native macOS input-source keys' \
	  'make input-sources-dry-run  Inspect input-source-only changes' \
	  'make dry-run  Inspect changes without writing' \
	  'make test     Run the test suite for this platform' \
	  '' \
	  'MODE=ko-en     right Command switches English/Korean (default)' \
	  'MODE=ko-en-ja  adds Option+1 for Japanese' \
	  '' \
	  'FONT=firacode  Ghostty uses FiraCode Nerd Font (default)' \
	  'FONT=geist     Ghostty uses GeistMono Nerd Font'

setup:
	./bootstrap.sh $(if $(MODE),--mode $(MODE)) --font $(FONT)

input-sources:
	./setup-input-sources.sh $(if $(MODE),--mode $(MODE))

input-sources-dry-run:
	./setup-input-sources.sh $(if $(MODE),--mode $(MODE)) --dry-run

dry-run:
	./bootstrap.sh $(if $(MODE),--mode $(MODE)) --font $(FONT) --dry-run

test:
	./tests/test.sh
