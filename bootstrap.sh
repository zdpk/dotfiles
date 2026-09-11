#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_ROOT

# shellcheck source=lib/common.sh
source "$DOTFILES_ROOT/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [--dry-run] [--mode <input-mode>] [--font <font>]

Options:
  --dry-run       Report changes without writing them.
  --mode <mode>   macOS input mode: ko-en (default) or ko-en-ja.
                  DOTFILES_INPUT_MODE overrides the saved per-machine mode.
  --font <font>   Ghostty font: firacode (default) or geist.
                  DOTFILES_GHOSTTY_FONT sets the same value.
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
    --font=*)
      DOTFILES_GHOSTTY_FONT="${1#*=}"
      ;;
    --font)
      shift
      [ "$#" -gt 0 ] || die "--font requires a value"
      DOTFILES_GHOSTTY_FONT="$1"
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
DOTFILES_GHOSTTY_FONT="$(resolve_ghostty_font)"

export DOTFILES_DRY_RUN
export DOTFILES_INPUT_MODE
export DOTFILES_GHOSTTY_FONT

detect_platform() {
  case "$(uname -s)" in
    Darwin)
      printf '%s\n' "macos"
      ;;
    Linux)
      if [ ! -r /etc/os-release ]; then
        die "cannot identify this Linux distribution"
      fi

      # shellcheck disable=SC1091
      . /etc/os-release
      if [ "${ID:-}" != "ubuntu" ]; then
        die "unsupported Linux distribution: ${ID:-unknown}"
      fi
      printf '%s\n' "ubuntu"
      ;;
    *)
      die "unsupported operating system: $(uname -s)"
      ;;
  esac
}

run_modules() {
  local group="$1"
  local module_dir="$DOTFILES_ROOT/scripts/$group"
  local module
  local module_count=0

  if [ ! -d "$module_dir" ]; then
    die "missing platform directory: $module_dir"
  fi

  for module in "$module_dir"/[0-9][0-9]-*.sh; do
    if [ ! -e "$module" ]; then
      continue
    fi
    module_count=$((module_count + 1))
    log "running ${module#"$DOTFILES_ROOT/"}"
    bash "$module"
  done

  if [ "$module_count" -eq 0 ]; then
    log "no modules configured for $group"
  fi
}

platform="$(detect_platform)"
log "platform: $platform"
run_modules common
run_modules "$platform"
log "bootstrap complete"
