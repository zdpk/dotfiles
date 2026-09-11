#!/usr/bin/env bash

set -euo pipefail

: "${DOTFILES_ROOT:?DOTFILES_ROOT must be set by bootstrap.sh}"

# shellcheck source=../../lib/common.sh
source "$DOTFILES_ROOT/lib/common.sh"

[ "$(uname -s)" = "Darwin" ] || die "the fonts module requires macOS"

# Both casks are installed regardless of which one Ghostty is pointed at, so
# switching config/ghostty/font.conf never needs a download first.
FONT_CASKS=(
  font-fira-code-nerd-font
  font-geist-mono-nerd-font
)

BREW="${DOTFILES_BREW:-}"

if [ -z "$BREW" ]; then
  BREW="$(command -v brew 2>/dev/null || true)"
fi

# Homebrew is not a prerequisite of the rest of the setup, so a machine without
# it is reported and left alone rather than failed.
if [ -z "$BREW" ] || [ ! -x "$BREW" ]; then
  warn "Homebrew is unavailable, so the terminal fonts were not installed"
  exit 0
fi

for cask in "${FONT_CASKS[@]}"; do
  if "$BREW" list --cask "$cask" >/dev/null 2>&1; then
    log "unchanged: font cask $cask"
    continue
  fi

  if is_dry_run; then
    log "would install font cask: $cask"
    continue
  fi

  "$BREW" install --cask "$cask"
  log "installed font cask: $cask"
done
