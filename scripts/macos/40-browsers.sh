#!/usr/bin/env bash

set -euo pipefail

: "${DOTFILES_ROOT:?DOTFILES_ROOT must be set by bootstrap.sh}"

# shellcheck source=../../lib/common.sh
source "$DOTFILES_ROOT/lib/common.sh"

[ "$(uname -s)" = "Darwin" ] || die "the browsers module requires macOS"

# Each channel is a separate app bundle, so all three install side by side.
BROWSER_CASKS=(
  google-chrome
  google-chrome@beta
  google-chrome@dev
)

BREW="${DOTFILES_BREW:-}"

if [ -z "$BREW" ]; then
  BREW="$(command -v brew 2>/dev/null || true)"
fi

# Homebrew is not a prerequisite of the rest of the setup, so a machine without
# it is reported and left alone rather than failed.
if [ -z "$BREW" ] || [ ! -x "$BREW" ]; then
  warn "Homebrew is unavailable, so the browsers were not installed"
  exit 0
fi

for cask in "${BROWSER_CASKS[@]}"; do
  if "$BREW" list --cask "$cask" >/dev/null 2>&1; then
    log "unchanged: browser cask $cask"
    continue
  fi

  if is_dry_run; then
    log "would install browser cask: $cask"
    continue
  fi

  # Chrome is often installed from Google's DMG before this runs. Without
  # --adopt the cask refuses the occupied /Applications path and aborts the
  # bootstrap; Chrome casks are auto_updates, so Homebrew adopts the existing
  # bundle as is instead of comparing versions.
  "$BREW" install --cask --adopt "$cask"
  log "installed browser cask: $cask"
done
