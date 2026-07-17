#!/usr/bin/env bash

set -euo pipefail

: "${DOTFILES_ROOT:?DOTFILES_ROOT must be set by bootstrap.sh}"

# shellcheck source=../../lib/common.sh
source "$DOTFILES_ROOT/lib/common.sh"

DEFAULTS="${DOTFILES_DEFAULTS:-/usr/bin/defaults}"
HIDUTIL="${DOTFILES_HIDUTIL:-/usr/bin/hidutil}"
ID="${DOTFILES_ID:-/usr/bin/id}"
LAUNCHCTL="${DOTFILES_LAUNCHCTL:-/bin/launchctl}"
PLIST_BUDDY="${DOTFILES_PLIST_BUDDY:-/usr/libexec/PlistBuddy}"
PLUTIL="${DOTFILES_PLUTIL:-/usr/bin/plutil}"
PGREP="${DOTFILES_PGREP:-/usr/bin/pgrep}"
XCRUN="${DOTFILES_XCRUN:-/usr/bin/xcrun}"
HOME_DIR="${DOTFILES_HOME:-$HOME}"

KEYS_LABEL=dev.undervars.dotfiles.input-source-keys
SWITCHER_LABEL=dev.undervars.dotfiles.input-source-switcher
LEGACY_CYCLE_LABEL=dev.undervars.dotfiles.input-source-cycle
KEYS_PLIST_SOURCE="$DOTFILES_ROOT/config/macos/LaunchAgents/$KEYS_LABEL.plist"
SWITCHER_PLIST_SOURCE="$DOTFILES_ROOT/config/macos/LaunchAgents/$SWITCHER_LABEL.plist"
KEYS_PLIST_TARGET="$HOME_DIR/Library/LaunchAgents/$KEYS_LABEL.plist"
SWITCHER_PLIST_TARGET="$HOME_DIR/Library/LaunchAgents/$SWITCHER_LABEL.plist"
LEGACY_CYCLE_PLIST="$HOME_DIR/Library/LaunchAgents/$LEGACY_CYCLE_LABEL.plist"
LEGACY_NIX_PLIST="$HOME_DIR/Library/LaunchAgents/org.nixos.UserKeyMapping.plist"
PACKAGE_DIR="$DOTFILES_ROOT/config/macos/InputSourceSwitcher"
SWITCHER_BINARY="$HOME_DIR/Library/Application Support/dev.undervars.dotfiles/bin/input-source-switcher"

RIGHT_COMMAND_DECIMAL=30064771303
RIGHT_OPTION_DECIMAL=30064771302
F18_DECIMAL=30064771181
F19_DECIMAL=30064771182

require_command "$DEFAULTS"
require_command "$HIDUTIL"
require_command "$ID"
require_command "$LAUNCHCTL"
require_command "$PLIST_BUDDY"
require_command "$PLUTIL"
require_command "$PGREP"

[ "$(uname -s)" = "Darwin" ] || die "the input-source switcher module requires macOS"
"$PLUTIL" -lint "$KEYS_PLIST_SOURCE" >/dev/null
"$PLUTIL" -lint "$SWITCHER_PLIST_SOURCE" >/dev/null

check_remapper_conflicts() {
  local conflict=0

  if [ -e "$LEGACY_NIX_PLIST" ]; then
    warn "legacy Nix hidutil LaunchAgent exists: $LEGACY_NIX_PLIST"
    conflict=1
  fi

  if "$PGREP" -f '/Contents/MacOS/(Karabiner-Elements|Karabiner-Core-Service|Karabiner-Menu|Karabiner-NotificationWindow)$|/(karabiner_grabber|karabiner_observer|karabiner_console_user_server)$' >/dev/null 2>&1; then
    warn "Karabiner is running; disable it before dotfiles owns the right-side modifier keys"
    conflict=1
  fi

  if "$PGREP" -x Hammerspoon >/dev/null 2>&1; then
    warn "Hammerspoon is running; stop it before enabling the native switcher"
    conflict=1
  fi

  if [ "$conflict" -eq 1 ] && ! is_dry_run; then
    die "another keyboard remapper is active"
  fi
}

check_input_sources() {
  local sources
  local missing=0

  sources="$("$DEFAULTS" read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null || true)"
  for source_id in \
    'KeyboardLayout Name.*ABC' \
    'com.apple.inputmethod.Korean.2SetKorean' \
    'com.apple.inputmethod.Japanese'; do
    if ! printf '%s\n' "$sources" | grep -q "$source_id"; then
      warn "required input source is not enabled: $source_id"
      missing=1
    fi
  done

  if [ "$missing" -eq 1 ] && ! is_dry_run; then
    die "enable ABC, Korean 2-Set, and Japanese before applying this module"
  fi
  if [ "$missing" -eq 0 ]; then
    log "input sources verified: ABC, Korean 2-Set, Japanese"
  fi
}

remove_legacy_cycle_agent() {
  local domain="gui/$("$ID" -u)"

  if is_dry_run; then
    if [ -e "$LEGACY_CYCLE_PLIST" ] || "$LAUNCHCTL" print "$domain/$LEGACY_CYCLE_LABEL" >/dev/null 2>&1; then
      log "would remove legacy input-source cycle LaunchAgent"
    fi
    return 0
  fi

  if "$LAUNCHCTL" print "$domain/$LEGACY_CYCLE_LABEL" >/dev/null 2>&1; then
    "$LAUNCHCTL" bootout "$domain/$LEGACY_CYCLE_LABEL"
    log "unloaded legacy LaunchAgent: $LEGACY_CYCLE_LABEL"
  fi
  if [ -e "$LEGACY_CYCLE_PLIST" ]; then
    rm -f "$LEGACY_CYCLE_PLIST"
    log "removed: $LEGACY_CYCLE_PLIST"
  fi
}

package_needs_build() {
  [ ! -x "$SWITCHER_BINARY" ] && return 0
  find "$PACKAGE_DIR" -type f \
    \( -name '*.swift' -o -name 'Package.swift' \) \
    -newer "$SWITCHER_BINARY" -print -quit | grep -q .
}

install_switcher_binary() {
  local binary_source="${DOTFILES_SWITCHER_BINARY_SOURCE:-}"
  local bin_dir

  if [ -z "$binary_source" ] && package_needs_build; then
    require_command "$XCRUN"
    if is_dry_run; then
      log "would build release input-source-switcher"
      log "would install: $SWITCHER_BINARY"
      DOTFILES_FILE_CHANGED=1
      return 0
    fi
    "$XCRUN" swift build \
      --package-path "$PACKAGE_DIR" \
      --configuration release \
      --product input-source-switcher
    bin_dir="$("$XCRUN" swift build \
      --package-path "$PACKAGE_DIR" \
      --configuration release \
      --show-bin-path)"
    binary_source="$bin_dir/input-source-switcher"
  elif [ -z "$binary_source" ]; then
    DOTFILES_FILE_CHANGED=0
    log "unchanged: $SWITCHER_BINARY"
    return 0
  fi

  install_file_if_changed "$binary_source" "$SWITCHER_BINARY" 0755
  if ! is_dry_run; then
    "$SWITCHER_BINARY" --check >/dev/null
  fi
}

install_launch_agent() {
  local label="$1"
  local source_path="$2"
  local target_path="$3"
  local force_reload="${4:-0}"
  local domain
  local plist_changed

  install_file_if_changed "$source_path" "$target_path" 0644
  plist_changed="$DOTFILES_FILE_CHANGED"
  domain="gui/$("$ID" -u)"

  if is_dry_run; then
    if [ "$plist_changed" -eq 1 ] || [ "$force_reload" -eq 1 ]; then
      log "would reload LaunchAgent: $label"
    else
      log "would ensure LaunchAgent is loaded: $label"
    fi
    return 0
  fi

  if "$LAUNCHCTL" print "$domain/$label" >/dev/null 2>&1; then
    if [ "$plist_changed" -eq 1 ] || [ "$force_reload" -eq 1 ]; then
      "$LAUNCHCTL" bootout "$domain/$label"
      "$LAUNCHCTL" bootstrap "$domain" "$target_path"
      log "reloaded LaunchAgent: $label"
    else
      log "unchanged: LaunchAgent is loaded: $label"
    fi
  else
    "$LAUNCHCTL" bootstrap "$domain" "$target_path"
    log "loaded LaunchAgent: $label"
  fi
}

mapping_matches() {
  local mapping
  local entry_count

  mapping="$("$HIDUTIL" property --get UserKeyMapping 2>/dev/null || true)"
  entry_count="$(printf '%s\n' "$mapping" | grep -c 'HIDKeyboardModifierMappingSrc =' || true)"

  [ "$entry_count" -eq 2 ] \
    && [ "$(printf '%s\n' "$mapping" | grep -c "HIDKeyboardModifierMappingSrc = $RIGHT_COMMAND_DECIMAL;" || true)" -eq 1 ] \
    && [ "$(printf '%s\n' "$mapping" | grep -c "HIDKeyboardModifierMappingDst = $F18_DECIMAL;" || true)" -eq 1 ] \
    && [ "$(printf '%s\n' "$mapping" | grep -c "HIDKeyboardModifierMappingSrc = $RIGHT_OPTION_DECIMAL;" || true)" -eq 1 ] \
    && [ "$(printf '%s\n' "$mapping" | grep -c "HIDKeyboardModifierMappingDst = $F19_DECIMAL;" || true)" -eq 1 ]
}

apply_mapping() {
  local mapping_json

  if mapping_matches; then
    log "unchanged: right Command -> F18, right Option -> F19"
    return 0
  fi

  mapping_json="$("$PLIST_BUDDY" -c 'Print :ProgramArguments:3' "$KEYS_PLIST_SOURCE")"
  run "$HIDUTIL" property --set "$mapping_json"

  if ! is_dry_run && ! mapping_matches; then
    die "hidutil did not report the declared key mappings"
  fi

  if is_dry_run; then
    log "would apply right Command -> F18, right Option -> F19"
  else
    log "applied right Command -> F18, right Option -> F19"
  fi
}

check_remapper_conflicts
check_input_sources
remove_legacy_cycle_agent
install_switcher_binary
switcher_binary_changed="$DOTFILES_FILE_CHANGED"
install_launch_agent \
  "$SWITCHER_LABEL" \
  "$SWITCHER_PLIST_SOURCE" \
  "$SWITCHER_PLIST_TARGET" \
  "$switcher_binary_changed"
install_launch_agent "$KEYS_LABEL" "$KEYS_PLIST_SOURCE" "$KEYS_PLIST_TARGET"
apply_mapping
