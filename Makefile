.PHONY: help setup dry-run test

.DEFAULT_GOAL := help

help:
	@printf '%s\n' \
	  'make setup    Apply common and platform-specific Bash modules' \
	  'make dry-run  Inspect changes without writing' \
	  'make test     Run the test suite for this platform'

setup:
	./bootstrap.sh

dry-run:
	./bootstrap.sh --dry-run

test:
	./tests/test.sh
