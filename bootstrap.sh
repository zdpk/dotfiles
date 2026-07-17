#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_ROOT

# shellcheck source=lib/common.sh
source "$DOTFILES_ROOT/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [--dry-run]

Options:
  --dry-run  Report changes without writing them.
  -h, --help Show this help.
EOF
}

DOTFILES_DRY_RUN=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DOTFILES_DRY_RUN=1
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

export DOTFILES_DRY_RUN

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
