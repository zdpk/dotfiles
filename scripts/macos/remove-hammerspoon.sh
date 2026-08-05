#!/usr/bin/env bash

set -euo pipefail

: "${DOTFILES_ROOT:?DOTFILES_ROOT must be set}"

# shellcheck source=../../lib/common.sh
source "$DOTFILES_ROOT/lib/common.sh"

HOME_DIR="${DOTFILES_HOME:-$HOME}"
STATE_HOME="${DOTFILES_STATE_HOME:-$HOME_DIR/.local/state}"
BACKUP_DIR="$STATE_HOME/dotfiles/backups/hammerspoon"
HAMMERSPOON_CONFIG="$HOME_DIR/.hammerspoon"
HAMMERSPOON_PREFERENCES="$HOME_DIR/Library/Preferences/org.hammerspoon.Hammerspoon.plist"
HAMMERSPOON_APP="${DOTFILES_HAMMERSPOON_APP:-/Applications/Hammerspoon.app}"
HS_CLI="${DOTFILES_HS_CLI:-/opt/homebrew/bin/hs}"
PGREP="${DOTFILES_PGREP:-/usr/bin/pgrep}"
PKILL="${DOTFILES_PKILL:-/usr/bin/pkill}"
OSASCRIPT="${DOTFILES_OSASCRIPT:-/usr/bin/osascript}"
BREW="${DOTFILES_BREW:-}"

if [ -z "$BREW" ]; then
  BREW="$(command -v brew 2>/dev/null || true)"
fi

backup_path() {
  local source_path="$1"
  local name="$2"
  local target_path="$BACKUP_DIR/$name"

  [ -e "$source_path" ] || [ -L "$source_path" ] || return 0

  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    die "backup already exists for Hammerspoon path: $target_path"
  fi

  if is_dry_run; then
    log "would back up Hammerspoon path: $source_path -> $target_path"
    return 0
  fi

  mkdir -p "$BACKUP_DIR"
  mv "$source_path" "$target_path"
  log "backed up Hammerspoon path: $source_path -> $target_path"
}

if "$PGREP" -x Hammerspoon >/dev/null 2>&1; then
  if is_dry_run; then
    log "would stop Hammerspoon"
  else
    "$PKILL" -x Hammerspoon
    log "stopped Hammerspoon"
  fi
fi

if [ -x "$OSASCRIPT" ]; then
  if is_dry_run; then
    log "would remove Hammerspoon login item if present"
  else
    "$OSASCRIPT" -e 'tell application "System Events" to delete login item "Hammerspoon"' \
      >/dev/null 2>&1 || true
    log "removed Hammerspoon login item if present"
  fi
fi

brew_manages_hammerspoon=0
if [ -n "$BREW" ] && [ -x "$BREW" ] \
  && "$BREW" list --cask hammerspoon >/dev/null 2>&1; then
  brew_manages_hammerspoon=1
  if is_dry_run; then
    log "would uninstall Homebrew cask: hammerspoon"
  else
    "$BREW" uninstall --cask hammerspoon
    log "uninstalled Homebrew cask: hammerspoon"
  fi
fi

if [ "$brew_manages_hammerspoon" -eq 0 ]; then
  backup_path "$HAMMERSPOON_APP" "Hammerspoon.app"
fi
backup_path "$HAMMERSPOON_CONFIG" ".hammerspoon"
backup_path "$HAMMERSPOON_PREFERENCES" "org.hammerspoon.Hammerspoon.plist"

if [ -L "$HS_CLI" ]; then
  hs_target="$(readlink "$HS_CLI")"
  case "$hs_target" in
    *Hammerspoon.app/Contents/Frameworks/hs/hs)
      if is_dry_run; then
        log "would remove Hammerspoon CLI symlink: $HS_CLI"
      else
        rm -f "$HS_CLI"
        log "removed Hammerspoon CLI symlink: $HS_CLI"
      fi
      ;;
  esac
fi

log "Hammerspoon removal complete"
