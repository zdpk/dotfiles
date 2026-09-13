#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_ROOT

# shellcheck source=lib/common.sh
source "$DOTFILES_ROOT/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./setup-input-sources.sh [--dry-run] [--backend <backend>] [--mode <input-mode>]

Configures right Command as a dedicated Korean/English key, using macOS's
native F18 input-source shortcut, and applies the related typing defaults. No
shell, editor, terminal, or multiplexer configuration is linked.

Options:
  --dry-run       Report changes without writing them.
  --backend <b>   native (default): no helper app, Caps Lock, or Japanese shortcut.
                  helper: retain the legacy Swift implementation.
  --mode <mode>   ko-en    right Command switches English/Korean (default)
                  ko-en-ja right Command switches English/Korean and
                           Option+1 switches to Japanese
                  DOTFILES_INPUT_MODE overrides the saved per-machine mode.
  -h, --help      Show this help.
EOF
}

DOTFILES_DRY_RUN=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DOTFILES_DRY_RUN=1
      ;;
    --backend=*) DOTFILES_INPUT_BACKEND="${1#*=}" ;;
    --backend)
      shift
      [ "$#" -gt 0 ] || die "--backend requires a value"
      DOTFILES_INPUT_BACKEND="$1"
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

DOTFILES_INPUT_BACKEND="$(resolve_input_backend)"
export DOTFILES_INPUT_BACKEND
DOTFILES_INPUT_MODE="$(resolve_input_mode)"

export DOTFILES_DRY_RUN
export DOTFILES_INPUT_MODE

[ "$(uname -s)" = "Darwin" ] || die "input-source setup requires macOS"

if [ "$DOTFILES_INPUT_BACKEND" = helper ]; then
  if [ -f "${DOTFILES_STATE_HOME:-${DOTFILES_HOME:-$HOME}/.local/state}/dotfiles/native-input/backup.json" ]; then
    die "restore the native configuration with make input-sources-restore before selecting the legacy helper"
  fi
  bash "$DOTFILES_ROOT/scripts/macos/remove-hammerspoon.sh"
fi
bash "$DOTFILES_ROOT/scripts/macos/10-input-source-switcher.sh"
bash "$DOTFILES_ROOT/scripts/macos/20-text-input.sh"
log "input-source-only setup complete"
