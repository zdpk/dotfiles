#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_ROOT

# shellcheck source=lib/common.sh
source "$DOTFILES_ROOT/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./setup-input-sources.sh [--dry-run] [--mode <input-mode>]

Removes Hammerspoon, configures the right-side modifier keys as dedicated
input-source keys, and applies the typing defaults that belong with them. No
shell, editor, terminal, or multiplexer configuration is linked.

Options:
  --dry-run       Report changes without writing them.
  --mode <mode>   ko-en    right Command switches English/Korean (default)
                  ko-en-ja right Command switches English/Korean and
                           right Option switches to Japanese
                  DOTFILES_INPUT_MODE sets the same value.
  -h, --help      Show this help.
EOF
}

DOTFILES_DRY_RUN=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DOTFILES_DRY_RUN=1
      ;;
    --mode=*)
      DOTFILES_INPUT_MODE="${1#*=}"
      ;;
    --mode)
      shift
      [ "$#" -gt 0 ] || die "--mode requires a value"
      DOTFILES_INPUT_MODE="$1"
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
  shift
done

DOTFILES_INPUT_MODE="$(resolve_input_mode)"

export DOTFILES_DRY_RUN
export DOTFILES_INPUT_MODE

[ "$(uname -s)" = "Darwin" ] || die "input-source setup requires macOS"

bash "$DOTFILES_ROOT/scripts/macos/remove-hammerspoon.sh"
bash "$DOTFILES_ROOT/scripts/macos/10-input-source-switcher.sh"
bash "$DOTFILES_ROOT/scripts/macos/20-text-input.sh"
log "input-source-only setup complete"
