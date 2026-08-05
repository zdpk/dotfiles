#!/usr/bin/env bash

set -euo pipefail

: "${DOTFILES_ROOT:?DOTFILES_ROOT must be set by bootstrap.sh}"

# shellcheck source=../../lib/common.sh
source "$DOTFILES_ROOT/lib/common.sh"

ACTIVATE_SETTINGS="${DOTFILES_ACTIVATE_SETTINGS:-/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings}"
DEFAULTS="${DOTFILES_DEFAULTS:-/usr/bin/defaults}"
HIDUTIL="${DOTFILES_HIDUTIL:-/usr/bin/hidutil}"
ID="${DOTFILES_ID:-/usr/bin/id}"
LAUNCHCTL="${DOTFILES_LAUNCHCTL:-/bin/launchctl}"
PLIST_BUDDY="${DOTFILES_PLIST_BUDDY:-/usr/libexec/PlistBuddy}"
PLUTIL="${DOTFILES_PLUTIL:-/usr/bin/plutil}"
PGREP="${DOTFILES_PGREP:-/usr/bin/pgrep}"
XCRUN="${DOTFILES_XCRUN:-/usr/bin/xcrun}"
HOME_DIR="${DOTFILES_HOME:-$HOME}"

INPUT_MODE="$(resolve_input_mode)"

KEYS_LABEL=dev.undervars.dotfiles.input-source-keys
SWITCHER_LABEL=dev.undervars.dotfiles.input-source-switcher
LEGACY_CYCLE_LABEL=dev.undervars.dotfiles.input-source-cycle
KEYS_PLIST_SOURCE="$DOTFILES_ROOT/config/macos/LaunchAgents/$KEYS_LABEL.$INPUT_MODE.plist"
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

# Set by resolve_tool_binary; ko-en runs it in place, ko-en-ja installs it.
TOOL_BINARY=""

# "Select the previous input source" in System Settings > Keyboard Shortcuts.
# In ko-en mode this native shortcut replaces the Swift helper: hidutil turns
# right Command into F18 and macOS performs the switch itself.
SYMBOLIC_HOTKEYS_DOMAIN=com.apple.symbolichotkeys
PREVIOUS_SOURCE_HOTKEY_ID=60
F18_KEY_CODE=79
SPACE_KEY_CODE=49
NO_MODIFIER=0
CONTROL_MODIFIER=262144
HOTKEY_F18_VALUE='{enabled=1;value={type=standard;parameters=(65535,79,0);};}'
HOTKEY_STOCK_VALUE='{enabled=0;value={type=standard;parameters=(32,49,262144);};}'

case "$INPUT_MODE" in
  ko-en)
    MAPPING_DESCRIPTION='right Command -> F18'
    EXPECTED_MAPPING_ENTRIES=1
    ;;
  ko-en-ja)
    MAPPING_DESCRIPTION='right Command -> F18, right Option -> F19'
    EXPECTED_MAPPING_ENTRIES=2
    ;;
esac

require_command "$ACTIVATE_SETTINGS"
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

# Both modes drive the input-source list through the same Swift tool. ko-en runs
# it straight from the build directory and never installs it, so that mode still
# leaves no resident process behind.
resolve_tool_binary() {
  local bin_dir

  if [ -n "${DOTFILES_SWITCHER_BINARY_SOURCE:-}" ]; then
    TOOL_BINARY="$DOTFILES_SWITCHER_BINARY_SOURCE"
    return 0
  fi

  require_command "$XCRUN"
  "$XCRUN" swift build \
    --package-path "$PACKAGE_DIR" \
    --configuration release \
    --product input-source-switcher
  bin_dir="$("$XCRUN" swift build \
    --package-path "$PACKAGE_DIR" \
    --configuration release \
    --show-bin-path)"
  TOOL_BINARY="$bin_dir/input-source-switcher"
}

# dotfiles owns the keyboard input-source list the way it owns UserKeyMapping:
# the mode declares the set, and anything else enabled is removed. Palette
# sources such as the character viewer are a different category and survive.
apply_input_sources() {
  local disabled

  if is_dry_run; then
    log "would build release input-source-switcher"
    log "would apply input sources for mode: $INPUT_MODE"
    return 0
  fi

  resolve_tool_binary
  disabled="$("$TOOL_BINARY" --apply-sources "$INPUT_MODE" | grep '^disabled=' || true)"

  if [ -n "$disabled" ]; then
    printf '%s\n' "$disabled" | while IFS= read -r line; do
      log "disabled input source: ${line#disabled=}"
    done
  fi

  log "input sources applied for mode: $INPUT_MODE"
}

remove_launch_agent() {
  local label="$1"
  local plist_path="$2"
  local domain

  domain="gui/$("$ID" -u)"

  if is_dry_run; then
    if [ -e "$plist_path" ] || "$LAUNCHCTL" print "$domain/$label" >/dev/null 2>&1; then
      log "would remove LaunchAgent: $label"
    fi
    return 0
  fi

  if "$LAUNCHCTL" print "$domain/$label" >/dev/null 2>&1; then
    "$LAUNCHCTL" bootout "$domain/$label"
    log "unloaded LaunchAgent: $label"
  fi
  if [ -e "$plist_path" ]; then
    rm -f "$plist_path"
    log "removed: $plist_path"
  fi
}

remove_legacy_cycle_agent() {
  remove_launch_agent "$LEGACY_CYCLE_LABEL" "$LEGACY_CYCLE_PLIST"
}

# Leaving the helper resident in ko-en mode would double-handle F18, so the
# three-language artifacts are removed rather than merely left unloaded.
remove_switcher_artifacts() {
  remove_launch_agent "$SWITCHER_LABEL" "$SWITCHER_PLIST_TARGET"

  if [ ! -e "$SWITCHER_BINARY" ]; then
    return 0
  fi

  if is_dry_run; then
    log "would remove: $SWITCHER_BINARY"
    return 0
  fi

  rm -f "$SWITCHER_BINARY"
  log "removed: $SWITCHER_BINARY"
}

install_switcher_binary() {
  if is_dry_run; then
    log "would install: $SWITCHER_BINARY"
    DOTFILES_FILE_CHANGED=1
    return 0
  fi

  install_file_if_changed "$TOOL_BINARY" "$SWITCHER_BINARY" 0755
  "$SWITCHER_BINARY" --check "$INPUT_MODE" >/dev/null
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

normalize_boolean() {
  case "$1" in
    1 | true)
      printf '%s\n' 'true'
      ;;
    0 | false)
      printf '%s\n' 'false'
      ;;
    *)
      printf '%s\n' 'unset'
      ;;
  esac
}

symbolic_hotkey_field() {
  local export_path="$1"
  local field="$2"

  "$PLIST_BUDDY" \
    -c "Print :AppleSymbolicHotKeys:$PREVIOUS_SOURCE_HOTKEY_ID:$field" \
    "$export_path" 2>/dev/null || true
}

# The modifier mask is compared too. Without it an entry left over from an
# earlier revision, bound to the right key but the wrong mask, would read as
# already correct and never be repaired.
symbolic_hotkey_matches() {
  local want_enabled="$1"
  local want_key_code="$2"
  local want_modifiers="$3"
  local export_path
  local status=1

  export_path="$(mktemp "${TMPDIR:-/tmp}/dotfiles-symbolichotkeys.XXXXXX")"
  if "$DEFAULTS" export "$SYMBOLIC_HOTKEYS_DOMAIN" - >"$export_path" 2>/dev/null; then
    if [ "$(normalize_boolean "$(symbolic_hotkey_field "$export_path" enabled)")" = "$want_enabled" ] \
      && [ "$(symbolic_hotkey_field "$export_path" 'value:parameters:1')" = "$want_key_code" ] \
      && [ "$(symbolic_hotkey_field "$export_path" 'value:parameters:2')" = "$want_modifiers" ]; then
      status=0
    fi
  fi

  rm -f "$export_path"
  return "$status"
}

apply_symbolic_hotkey() {
  local want_enabled="$1"
  local want_key_code="$2"
  local want_modifiers="$3"
  local value="$4"
  local description="$5"

  if symbolic_hotkey_matches "$want_enabled" "$want_key_code" "$want_modifiers"; then
    log "unchanged: $description"
    return 0
  fi

  run "$DEFAULTS" write "$SYMBOLIC_HOTKEYS_DOMAIN" AppleSymbolicHotKeys \
    -dict-add "$PREVIOUS_SOURCE_HOTKEY_ID" "$value"
  run "$ACTIVATE_SETTINGS" -u

  if is_dry_run; then
    log "would apply $description"
    return 0
  fi

  if ! symbolic_hotkey_matches "$want_enabled" "$want_key_code" "$want_modifiers"; then
    die "the input-source hotkey did not persist"
  fi
  log "applied $description"
}

mapping_matches() {
  local mapping
  local entry_count

  mapping="$("$HIDUTIL" property --get UserKeyMapping 2>/dev/null || true)"
  entry_count="$(printf '%s\n' "$mapping" | grep -c 'HIDKeyboardModifierMappingSrc =' || true)"

  [ "$entry_count" -eq "$EXPECTED_MAPPING_ENTRIES" ] || return 1
  printf '%s\n' "$mapping" \
    | grep -q "HIDKeyboardModifierMappingSrc = $RIGHT_COMMAND_DECIMAL;" || return 1
  printf '%s\n' "$mapping" \
    | grep -q "HIDKeyboardModifierMappingDst = $F18_DECIMAL;" || return 1

  if [ "$INPUT_MODE" = "ko-en-ja" ]; then
    printf '%s\n' "$mapping" \
      | grep -q "HIDKeyboardModifierMappingSrc = $RIGHT_OPTION_DECIMAL;" || return 1
    printf '%s\n' "$mapping" \
      | grep -q "HIDKeyboardModifierMappingDst = $F19_DECIMAL;" || return 1
  fi

  return 0
}

apply_mapping() {
  local mapping_json

  if mapping_matches; then
    log "unchanged: $MAPPING_DESCRIPTION"
    return 0
  fi

  mapping_json="$("$PLIST_BUDDY" -c 'Print :ProgramArguments:3' "$KEYS_PLIST_SOURCE")"
  run "$HIDUTIL" property --set "$mapping_json"

  if ! is_dry_run && ! mapping_matches; then
    die "hidutil did not report the declared key mappings"
  fi

  if is_dry_run; then
    log "would apply $MAPPING_DESCRIPTION"
  else
    log "applied $MAPPING_DESCRIPTION"
  fi
}

log "input mode: $INPUT_MODE"
check_remapper_conflicts
remove_legacy_cycle_agent

case "$INPUT_MODE" in
  ko-en)
    # Reduce the source list first: with only two sources left, the native
    # shortcut is an exact Korean/English toggle.
    apply_input_sources
    remove_switcher_artifacts
    apply_symbolic_hotkey true "$F18_KEY_CODE" "$NO_MODIFIER" \
      "$HOTKEY_F18_VALUE" \
      "native previous-input-source hotkey bound to F18"
    install_launch_agent "$KEYS_LABEL" "$KEYS_PLIST_SOURCE" "$KEYS_PLIST_TARGET"
    apply_mapping
    ;;
  ko-en-ja)
    apply_symbolic_hotkey false "$SPACE_KEY_CODE" "$CONTROL_MODIFIER" \
      "$HOTKEY_STOCK_VALUE" \
      "native previous-input-source hotkey disabled"
    apply_input_sources
    install_switcher_binary
    install_launch_agent \
      "$SWITCHER_LABEL" \
      "$SWITCHER_PLIST_SOURCE" \
      "$SWITCHER_PLIST_TARGET" \
      "$DOTFILES_FILE_CHANGED"
    install_launch_agent "$KEYS_LABEL" "$KEYS_PLIST_SOURCE" "$KEYS_PLIST_TARGET"
    apply_mapping
    ;;
esac
