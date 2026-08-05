.PHONY: help setup input-sources input-sources-dry-run dry-run test

.DEFAULT_GOAL := help

# Override per machine: make setup MODE=ko-en-ja
MODE ?= ko-en

help:
	@printf '%s\n' \
	  'make setup    Apply common and platform-specific Bash modules' \
	  'make input-sources  Apply only native macOS input-source keys' \
	  'make input-sources-dry-run  Inspect input-source-only changes' \
	  'make dry-run  Inspect changes without writing' \
	  'make test     Run the test suite for this platform' \
	  '' \
	  'MODE=ko-en     right Command switches English/Korean (default)' \
	  'MODE=ko-en-ja  adds right Option for Japanese'

setup:
	./bootstrap.sh --mode $(MODE)

input-sources:
	./setup-input-sources.sh --mode $(MODE)

input-sources-dry-run:
	./setup-input-sources.sh --mode $(MODE) --dry-run

dry-run:
	./bootstrap.sh --mode $(MODE) --dry-run

test:
	./tests/test.sh
