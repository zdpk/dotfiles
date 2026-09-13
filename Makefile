.PHONY: help setup input-sources input-sources-dry-run input-diagnostics dry-run test

.DEFAULT_GOAL := help

# Override per machine: make setup FONT=geist (legacy input: BACKEND=helper MODE=ko-en-ja)
MODE ?=
BACKEND ?=
FONT ?= firacode

help:
	@printf '%s\n' \
	  'make setup    Apply common and platform-specific Bash modules' \
	  'make input-sources  Apply right Cmd -> F18 -> macOS Korean/English switching' \
	  'make input-sources-dry-run  Inspect input-source-only changes' \
	  'make input-sources-status  Check native configuration without changing it' \
	  'make input-sources-restore  Restore the configuration before native setup' \
	  'make input-diagnostics  Inspect input switching state and recent logs' \
	  'make dry-run  Inspect changes without writing' \
	  'make test     Run the test suite for this platform' \
	  '' \
	  'MODE=ko-en     right Command switches English/Korean (default)' \
	  'BACKEND=helper MODE=ko-en-ja  legacy Swift Japanese configuration' \
	  '' \
	  'FONT=firacode  Ghostty uses FiraCode Nerd Font (default)' \
	  'FONT=geist     Ghostty uses GeistMono Nerd Font'

setup:
	./bootstrap.sh $(if $(BACKEND),--backend $(BACKEND)) $(if $(MODE),--mode $(MODE)) --font $(FONT)

input-sources:
	./setup-input-sources.sh $(if $(BACKEND),--backend $(BACKEND)) $(if $(MODE),--mode $(MODE))

input-sources-dry-run:
	./setup-input-sources.sh $(if $(BACKEND),--backend $(BACKEND)) $(if $(MODE),--mode $(MODE)) --dry-run

.PHONY: input-sources-status input-sources-restore input-native-test
input-sources-status:
	./script/native-input.sh status

input-sources-restore:
	./script/native-input.sh restore

input-native-test:
	node --test tests/native-input.test.cjs

input-diagnostics:
	./script/input-source-diagnostics.sh

dry-run:
	./bootstrap.sh $(if $(BACKEND),--backend $(BACKEND)) $(if $(MODE),--mode $(MODE)) --font $(FONT) --dry-run

test:
	./tests/test.sh
