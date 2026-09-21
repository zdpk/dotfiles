#!/usr/bin/env bash

set -euo pipefail

: "${DOTFILES_ROOT:?DOTFILES_ROOT must be set by bootstrap.sh}"

# shellcheck source=../../lib/common.sh
source "$DOTFILES_ROOT/lib/common.sh"

[ "$(uname -s)" = "Darwin" ] || die "the antigravity module requires macOS"

ANTIGRAVITY_CASK="antigravity"
THEME_NAME="openai"

BREW="${DOTFILES_BREW:-}"

if [ -z "$BREW" ]; then
  BREW="$(command -v brew 2>/dev/null || true)"
fi

if [ -z "$BREW" ] && [ -x /opt/homebrew/bin/brew ]; then
  BREW="/opt/homebrew/bin/brew"
fi

# Homebrew is not a prerequisite of the rest of the setup, so a machine without
# it is reported and left alone rather than failed.
if [ -z "$BREW" ] || [ ! -x "$BREW" ]; then
  warn "Homebrew is unavailable, so Antigravity was not installed"
else
  if "$BREW" list --cask "$ANTIGRAVITY_CASK" >/dev/null 2>&1; then
    log "unchanged: antigravity cask $ANTIGRAVITY_CASK"
  elif is_dry_run; then
    log "would install antigravity cask: $ANTIGRAVITY_CASK"
  else
    "$BREW" install --cask --adopt "$ANTIGRAVITY_CASK"
    log "installed antigravity cask: $ANTIGRAVITY_CASK"
  fi
fi

apply_theme() {
  local theme_file="$DOTFILES_ROOT/config/antigravity/themes/$THEME_NAME.json"
  local home_dir="${DOTFILES_HOME:-$HOME}"
  local config_file="$home_dir/.gemini/config/config.json"

  [ -f "$theme_file" ] || die "antigravity theme file does not exist: $theme_file"

  if is_dry_run; then
    log "would apply antigravity theme: $THEME_NAME"
    return 0
  fi

  mkdir -p "$(dirname "$config_file")"
  if [ ! -f "$config_file" ]; then
    printf '{\n  "userSettings": {}\n}\n' > "$config_file"
  fi

  local status
  status="$(python3 -c '
import json, sys

config_path, theme_path = sys.argv[1], sys.argv[2]
try:
    with open(config_path, "r", encoding="utf-8") as f:
        config = json.load(f)
except Exception:
    config = {}

try:
    with open(theme_path, "r", encoding="utf-8") as f:
        theme = json.load(f)
except Exception:
    theme = {}

user_settings = config.setdefault("userSettings", {})
target_seeds = theme.get("customThemeSeedsDark")
current_seeds = user_settings.get("customThemeSeedsDark")

if target_seeds and current_seeds != target_seeds:
    user_settings["customThemeSeedsDark"] = target_seeds
    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2)
        f.write("\n")
    print("applied")
else:
    print("unchanged")
' "$config_file" "$theme_file")"

  if [ "$status" = "applied" ]; then
    log "applied antigravity theme: $THEME_NAME"
  else
    log "unchanged: antigravity theme $THEME_NAME"
  fi
}

apply_theme
