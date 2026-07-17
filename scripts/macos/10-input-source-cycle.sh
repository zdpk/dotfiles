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
HOME_DIR="${DOTFILES_HOME:-$HOME}"

LABEL=dev.undervars.dotfiles.input-source-cycle
PLIST_SOURCE="$DOTFILES_ROOT/config/macos/LaunchAgents/$LABEL.plist"
PLIST_TARGET="$HOME_DIR/Library/LaunchAgents/$LABEL.plist"
LEGACY_PLIST="$HOME_DIR/Library/LaunchAgents/org.nixos.UserKeyMapping.plist"

RIGHT_COMMAND_DECIMAL=30064771303
FN_GLOBE_DECIMAL=1095216660483

require_command "$DEFAULTS"
require_command "$HIDUTIL"
require_command "$ID"
require_command "$LAUNCHCTL"
require_command "$PLIST_BUDDY"
require_command "$PLUTIL"
require_command "$PGREP"

[ "$(uname -s)" = "Darwin" ] || die "the input-source cycle module requires macOS"
"$PLUTIL" -lint "$PLIST_SOURCE" >/dev/null

check_remapper_conflicts() {
  local conflict=0

  if [ -e "$LEGACY_PLIST" ]; then
    warn "legacy hidutil LaunchAgent exists: $LEGACY_PLIST"
    conflict=1
  fi

  if "$PGREP" -f 'karabiner_(grabber|observer)|Karabiner-Elements' >/dev/null 2>&1; then
    warn "Karabiner is running; it must be disabled before this module owns right Command"
    conflict=1
  fi

  if [ "$conflict" -eq 1 ] && ! is_dry_run; then
    die "another key remapper is active"
  fi
}

check_input_sources() {
  local sources
  local abc_line
  local korean_line
  local japanese_line

  sources="$("$DEFAULTS" read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null || true)"
  abc_line="$(printf '%s\n' "$sources" | grep -n -m 1 'KeyboardLayout Name.*ABC' | cut -d: -f1 || true)"
  korean_line="$(printf '%s\n' "$sources" | grep -n -m 1 'com.apple.inputmethod.Korean.2SetKorean' | cut -d: -f1 || true)"
  japanese_line="$(printf '%s\n' "$sources" | grep -n -m 1 'com.apple.inputmethod.Japanese' | cut -d: -f1 || true)"

  if [ -z "$abc_line" ] || [ -z "$korean_line" ] || [ -z "$japanese_line" ]; then
    warn "add ABC, Korean 2-Set, and Japanese in System Settings before relying on the three-step cycle"
    return 0
  fi

  if [ "$abc_line" -lt "$korean_line" ] && [ "$korean_line" -lt "$japanese_line" ]; then
    log "input-source order verified: ABC -> Korean 2-Set -> Japanese"
  else
    warn "input sources are enabled but their order is not ABC -> Korean 2-Set -> Japanese"
  fi
}

mapping_matches() {
  local mapping
  local source_count
  local destination_count
  local entry_count

  mapping="$("$HIDUTIL" property --get UserKeyMapping 2>/dev/null || true)"
  source_count="$(printf '%s\n' "$mapping" | grep -c "HIDKeyboardModifierMappingSrc = $RIGHT_COMMAND_DECIMAL;" || true)"
  destination_count="$(printf '%s\n' "$mapping" | grep -c "HIDKeyboardModifierMappingDst = $FN_GLOBE_DECIMAL;" || true)"
  entry_count="$(printf '%s\n' "$mapping" | grep -c 'HIDKeyboardModifierMappingSrc =' || true)"

  [ "$source_count" -eq 1 ] && [ "$destination_count" -eq 1 ] && [ "$entry_count" -eq 1 ]
}

configure_fn_action() {
  local current_value

  current_value="$("$DEFAULTS" read com.apple.HIToolbox AppleFnUsageType 2>/dev/null || true)"
  if [ "$current_value" = "1" ]; then
    log "unchanged: Fn/Globe changes the input source"
    return 0
  fi

  run "$DEFAULTS" write com.apple.HIToolbox AppleFnUsageType -int 1
  if is_dry_run; then
    log "would configure Fn/Globe to change the input source"
  else
    log "configured Fn/Globe to change the input source"
  fi
}

install_launch_agent() {
  local domain
  local plist_changed

  install_file_if_changed "$PLIST_SOURCE" "$PLIST_TARGET" 0644
  plist_changed="$DOTFILES_FILE_CHANGED"
  domain="gui/$("$ID" -u)"

  if is_dry_run; then
    if [ "$plist_changed" -eq 1 ]; then
      log "would reload LaunchAgent: $LABEL"
    else
      log "would ensure LaunchAgent is loaded: $LABEL"
    fi
    return 0
  fi

  if "$LAUNCHCTL" print "$domain/$LABEL" >/dev/null 2>&1; then
    if [ "$plist_changed" -eq 1 ]; then
      "$LAUNCHCTL" bootout "$domain/$LABEL"
      "$LAUNCHCTL" bootstrap "$domain" "$PLIST_TARGET"
      log "reloaded LaunchAgent: $LABEL"
    else
      log "unchanged: LaunchAgent is loaded"
    fi
  else
    "$LAUNCHCTL" bootstrap "$domain" "$PLIST_TARGET"
    log "loaded LaunchAgent: $LABEL"
  fi
}

apply_mapping() {
  local mapping_json

  if mapping_matches; then
    log "unchanged: right Command maps to Fn/Globe"
    return 0
  fi

  mapping_json="$("$PLIST_BUDDY" -c 'Print :ProgramArguments:3' "$PLIST_SOURCE")"
  run "$HIDUTIL" property --set "$mapping_json"

  if ! is_dry_run && ! mapping_matches; then
    die "hidutil did not report the declared key mapping"
  fi

  if is_dry_run; then
    log "would apply right Command -> Fn/Globe"
  else
    log "applied right Command -> Fn/Globe"
  fi
}

check_remapper_conflicts
check_input_sources
configure_fn_action
install_launch_agent
apply_mapping
