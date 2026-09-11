#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADC_ACCOUNT="$ROOT/bin/gcloud-adc-account"
LAUNCH_AGENTS="$ROOT/config/macos/LaunchAgents"
KEYS_KO_EN_PLIST="$LAUNCH_AGENTS/dev.undervars.dotfiles.input-source-keys.ko-en.plist"
KEYS_KO_EN_JA_PLIST="$LAUNCH_AGENTS/dev.undervars.dotfiles.input-source-keys.ko-en-ja.plist"
SWITCHER_PLIST="$LAUNCH_AGENTS/dev.undervars.dotfiles.input-source-switcher.plist"
PACKAGE="$ROOT/config/macos/InputSourceSwitcher"
FIXTURE_BIN="$ROOT/tests/fixtures/bin"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tests.XXXXXX")"

trap 'rm -rf "$TEST_ROOT"' EXIT

mkdir -p \
  "$TEST_ROOT/home/Library/LaunchAgents" \
  "$TEST_ROOT/state" \
  "$TEST_ROOT/state-home"

while IFS= read -r script; do
  bash -n "$script"
done < <(find "$ROOT" -type f -name '*.sh' -print | sort)
bash -n "$ADC_ACCOUNT"

test "$(
  PATH="$FIXTURE_BIN:$PATH" "$ADC_ACCOUNT"
)" = 'adc@example.com'

/usr/bin/plutil -lint "$KEYS_KO_EN_PLIST" >/dev/null
/usr/bin/plutil -lint "$KEYS_KO_EN_JA_PLIST" >/dev/null
/usr/bin/plutil -lint "$SWITCHER_PLIST" >/dev/null

# Both mapping plists carry the same Label so they install to one LaunchAgent.
/usr/libexec/PlistBuddy -c 'Print :Label' "$KEYS_KO_EN_PLIST" \
  | grep -qx 'dev.undervars.dotfiles.input-source-keys'
/usr/libexec/PlistBuddy -c 'Print :Label' "$KEYS_KO_EN_JA_PLIST" \
  | grep -qx 'dev.undervars.dotfiles.input-source-keys'

count_mapping_entries() {
  printf '%s' "$1" | grep -o 'HIDKeyboardModifierMappingSrc' | wc -l | tr -d ' '
}

ko_en_mapping="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:3' "$KEYS_KO_EN_PLIST")"
printf '%s\n' "$ko_en_mapping" | grep -q '0x7000000E7'
printf '%s\n' "$ko_en_mapping" | grep -q '0x70000006D'
! printf '%s\n' "$ko_en_mapping" | grep -q '0x7000000E6'
[ "$(count_mapping_entries "$ko_en_mapping")" -eq 1 ]

ko_en_ja_mapping="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:3' "$KEYS_KO_EN_JA_PLIST")"
printf '%s\n' "$ko_en_ja_mapping" | grep -q '0x7000000E7'
printf '%s\n' "$ko_en_ja_mapping" | grep -q '0x70000006D'
! printf '%s\n' "$ko_en_ja_mapping" | grep -q '0x7000000E6'
! printf '%s\n' "$ko_en_ja_mapping" | grep -q '0x70000006E'
[ "$(count_mapping_entries "$ko_en_ja_mapping")" -eq 1 ]

if /usr/bin/xcrun swift -e 'import Testing' >/dev/null 2>&1; then
  /usr/bin/xcrun swift test --package-path "$PACKAGE"
else
  /usr/bin/xcrun swiftc \
    "$PACKAGE/Sources/InputSourcePolicy/InputSourcePolicy.swift" \
    "$ROOT/tests/InputSourcePolicySmokeTests.swift" \
    -o "$TEST_ROOT/input-source-policy-smoke-tests"
  "$TEST_ROOT/input-source-policy-smoke-tests"
fi
/usr/bin/xcrun swift build \
  --package-path "$PACKAGE" \
  --configuration release \
  --product input-source-switcher

release_bin_dir="$(/usr/bin/xcrun swift build \
  --package-path "$PACKAGE" \
  --configuration release \
  --show-bin-path)"
# --check is read-only, so it can run against the real machine when the sources
# it needs happen to be enabled. --apply-sources is never exercised here.
enabled_sources="$(/usr/bin/defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null || true)"
if printf '%s\n' "$enabled_sources" | grep -q 'com.apple.inputmethod.Korean.2SetKorean'; then
  "$release_bin_dir/input-source-switcher" --check ko-en | grep -qx 'mode=ko-en'
  ! "$release_bin_dir/input-source-switcher" --check ko-en \
    | grep -q 'japanese='

  if printf '%s\n' "$enabled_sources" | grep -q 'com.apple.inputmethod.Japanese'; then
    "$release_bin_dir/input-source-switcher" --check ko-en-ja \
      | grep -q 'japanese=com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese'
  fi
fi

! "$release_bin_dir/input-source-switcher" --apply-sources ko-jp >/dev/null 2>&1
! "$release_bin_dir/input-source-switcher" --bogus >/dev/null 2>&1

"$ROOT/bootstrap.sh" --help >/dev/null
! "$ROOT/bootstrap.sh" --mode ko-jp --dry-run >/dev/null 2>&1
! "$ROOT/setup-input-sources.sh" --mode '' --dry-run >/dev/null 2>&1

run_dry_run() {
  DOTFILES_BREW="$FIXTURE_BIN/brew" \
    DOTFILES_HOME="$TEST_ROOT/home" \
    DOTFILES_STATE_HOME="$TEST_ROOT/state-home" \
    DOTFILES_TEST_STATE="$TEST_ROOT/state" \
    "$ROOT/bootstrap.sh" --dry-run "$@" 2>&1
}

# Both modes use the helper and map only right Command.
default_dry_run_output="$(run_dry_run)"
printf '%s\n' "$default_dry_run_output" | grep -q 'platform: macos'
printf '%s\n' "$default_dry_run_output" | grep -q 'running scripts/common/10-config-links.sh'
printf '%s\n' "$default_dry_run_output" | grep -q 'running scripts/macos/20-text-input.sh'
printf '%s\n' "$default_dry_run_output" | grep -q 'input mode: ko-en'
printf '%s\n' "$default_dry_run_output" | grep -q 'ghostty font: firacode'
printf '%s\n' "$default_dry_run_output" | grep -q 'would install font cask: font-fira-code-nerd-font'
printf '%s\n' "$default_dry_run_output" | grep -q 'would install font cask: font-geist-mono-nerd-font'
printf '%s\n' "$default_dry_run_output" | grep -q 'would apply input sources for mode: ko-en'
printf '%s\n' "$default_dry_run_output" | grep -Eq 'right Command -> F18$|would apply right Command -> F18$'
! printf '%s\n' "$default_dry_run_output" | grep -q 'right Option -> F19'
printf '%s\n' "$default_dry_run_output" | grep -q 'would install:.*input-source-switcher'

# The font is a separate axis from the input mode, so it is selectable on its
# own and rejected by name rather than silently ignored.
geist_dry_run_output="$(run_dry_run --font geist)"
printf '%s\n' "$geist_dry_run_output" | grep -q 'ghostty font: geist'
printf '%s\n' "$geist_dry_run_output" | grep -q 'would link:.*ghostty/font.conf -> .*fonts/geist.conf'
geist_equals_output="$(run_dry_run --font=geist)"
printf '%s\n' "$geist_equals_output" | grep -q 'ghostty font: geist'
geist_env_output="$(DOTFILES_GHOSTTY_FONT=geist run_dry_run)"
printf '%s\n' "$geist_env_output" | grep -q 'ghostty font: geist'
! "$ROOT/bootstrap.sh" --font comic-sans --dry-run >/dev/null 2>&1

ja_dry_run_output="$(run_dry_run --mode ko-en-ja)"
printf '%s\n' "$ja_dry_run_output" | grep -q 'input mode: ko-en-ja'
printf '%s\n' "$ja_dry_run_output" | grep -q 'would apply input sources for mode: ko-en-ja'
printf '%s\n' "$ja_dry_run_output" | grep -q 'would install:.*input-source-switcher'
printf '%s\n' "$ja_dry_run_output" | grep -Eq 'right Command -> F18$'

cp "$ROOT/tests/fixtures/legacy-cycle.plist" \
  "$TEST_ROOT/home/Library/LaunchAgents/dev.undervars.dotfiles.input-source-cycle.plist"
: >"$TEST_ROOT/state/launch-agent-dev.undervars.dotfiles.input-source-cycle"
printf '%s\n' 'original bashrc' >"$TEST_ROOT/home/.bashrc"

run_isolated_bootstrap() {
  DOTFILES_ACTIVATE_SETTINGS="$FIXTURE_BIN/activateSettings" \
    DOTFILES_BREW="$FIXTURE_BIN/brew" \
    DOTFILES_DEFAULTS="$FIXTURE_BIN/defaults" \
    DOTFILES_HIDUTIL="$FIXTURE_BIN/hidutil" \
    DOTFILES_HOME="$TEST_ROOT/home" \
    DOTFILES_ID="$FIXTURE_BIN/id" \
    DOTFILES_LAUNCHCTL="$FIXTURE_BIN/launchctl" \
    DOTFILES_PGREP="$FIXTURE_BIN/pgrep" \
    DOTFILES_STATE_HOME="$TEST_ROOT/state-home" \
    DOTFILES_SWITCHER_BINARY_SOURCE="$FIXTURE_BIN/input-source-switcher" \
    DOTFILES_TEST_STATE="$TEST_ROOT/state" \
    "$ROOT/bootstrap.sh" "$@" 2>&1
}

text_input_keys=(
  NSAutomaticPeriodSubstitutionEnabled
  NSAutomaticCapitalizationEnabled
  NSAutomaticQuoteSubstitutionEnabled
  NSAutomaticDashSubstitutionEnabled
  NSAutomaticSpellingCorrectionEnabled
  WebAutomaticSpellingCorrectionEnabled
)

assert_text_input_defaults_off() {
  local key

  for key in "${text_input_keys[@]}"; do
    grep -qx '0' "$TEST_ROOT/state/global-$key"
  done
}

switcher_target="$TEST_ROOT/home/Library/LaunchAgents/dev.undervars.dotfiles.input-source-switcher.plist"
keys_target="$TEST_ROOT/home/Library/LaunchAgents/dev.undervars.dotfiles.input-source-keys.plist"
switcher_binary="$TEST_ROOT/home/Library/Application Support/dev.undervars.dotfiles/bin/input-source-switcher"

# A leftover keyboard layout must be reported as removed by the shared tool.
: >"$TEST_ROOT/state/extra-source"
printf '%s\n' 'true 79 8388608' >"$TEST_ROOT/state/hotkey-60"
first_run_output="$(run_isolated_bootstrap)"
printf '%s\n' "$first_run_output" | grep -q 'input mode: ko-en'
printf '%s\n' "$first_run_output" | grep -q 'backed up:.*\.bashrc'
printf '%s\n' "$first_run_output" | grep -q 'linked:.*\.local/bin/gcloud-adc-account'
printf '%s\n' "$first_run_output" | grep -q 'linked:.*\.config/helix'
printf '%s\n' "$first_run_output" | grep -q 'linked:.*\.config/ghostty/config'
printf '%s\n' "$first_run_output" | grep -q 'linked:.*\.config/ghostty/font.conf'
printf '%s\n' "$first_run_output" | grep -q 'installed font cask: font-fira-code-nerd-font'
printf '%s\n' "$first_run_output" | grep -q 'installed font cask: font-geist-mono-nerd-font'
printf '%s\n' "$first_run_output" | grep -q 'unloaded LaunchAgent: dev.undervars.dotfiles.input-source-cycle'
printf '%s\n' "$first_run_output" | grep -q 'removed:.*input-source-cycle.plist'
printf '%s\n' "$first_run_output" | grep -q 'disabled input source: com.apple.keylayout.Dvorak'
printf '%s\n' "$first_run_output" | grep -q 'input sources applied for mode: ko-en'
printf '%s\n' "$first_run_output" | grep -q 'applied native previous-input-source hotkey disabled'
printf '%s\n' "$first_run_output" | grep -q 'loaded LaunchAgent: dev.undervars.dotfiles.input-source-keys'
printf '%s\n' "$first_run_output" | grep -q 'applied right Command -> F18$'
grep -qx 'ko-en' "$TEST_ROOT/state/applied-sources"
# Both modes install the helper; its arguments encode the local mode.
test -f "$switcher_target"
test -x "$switcher_binary"
grep -q -- '--run ko-en</string>' "$switcher_target"
cmp -s "$KEYS_KO_EN_PLIST" "$keys_target"
grep -qx 'false 49 262144' "$TEST_ROOT/state/hotkey-60"
grep -qx 'ko-en' "$TEST_ROOT/home/.config/dotfiles/input-mode"
# Text substitutions rewrite what was typed, so the setup turns each one off
# explicitly rather than inheriting the machine default.
printf '%s\n' "$first_run_output" | grep -q 'set double-space period substitution off'
printf '%s\n' "$first_run_output" | grep -q 'set automatic capitalization off'
printf '%s\n' "$first_run_output" | grep -q 'set smart quote substitution off'
printf '%s\n' "$first_run_output" | grep -q 'set smart dash substitution off'
printf '%s\n' "$first_run_output" | grep -q 'set automatic spelling correction off'
printf '%s\n' "$first_run_output" | grep -q 'set web view spelling correction off'
assert_text_input_defaults_off

second_run_output="$(run_isolated_bootstrap)"
printf '%s\n' "$second_run_output" | grep -q 'unchanged:.*\.bashrc'
printf '%s\n' "$second_run_output" | grep -q 'unchanged:.*\.local/bin/gcloud-adc-account'
printf '%s\n' "$second_run_output" | grep -q 'unchanged:.*\.config/helix'
printf '%s\n' "$second_run_output" | grep -q 'unchanged:.*\.config/ghostty/font.conf'
printf '%s\n' "$second_run_output" | grep -q 'unchanged: font cask font-fira-code-nerd-font'
printf '%s\n' "$second_run_output" | grep -q 'unchanged: font cask font-geist-mono-nerd-font'
printf '%s\n' "$second_run_output" | grep -q 'unchanged: native previous-input-source hotkey disabled'
printf '%s\n' "$second_run_output" | grep -q 'unchanged: LaunchAgent is loaded: dev.undervars.dotfiles.input-source-keys'
printf '%s\n' "$second_run_output" | grep -q 'unchanged: right Command -> F18$'
printf '%s\n' "$second_run_output" | grep -q 'unchanged: double-space period substitution off'
printf '%s\n' "$second_run_output" | grep -q 'unchanged: automatic capitalization off'
printf '%s\n' "$second_run_output" | grep -q 'unchanged: smart quote substitution off'
printf '%s\n' "$second_run_output" | grep -q 'unchanged: smart dash substitution off'
printf '%s\n' "$second_run_output" | grep -q 'unchanged: automatic spelling correction off'

# Mode changes reload the same helper and preserve Option as a modifier.
ja_run_output="$(run_isolated_bootstrap --mode ko-en-ja)"
printf '%s\n' "$ja_run_output" | grep -q 'input mode: ko-en-ja'
printf '%s\n' "$ja_run_output" | grep -q 'reloaded LaunchAgent: dev.undervars.dotfiles.input-source-switcher'
grep -qx 'ko-en-ja' "$TEST_ROOT/state/applied-sources"
grep -q -- '--run ko-en-ja</string>' "$switcher_target"
grep -qx 'ko-en-ja' "$TEST_ROOT/home/.config/dotfiles/input-mode"
cmp -s "$KEYS_KO_EN_JA_PLIST" "$keys_target"
# A later invocation without --mode keeps this node's Japanese setting.
saved_run_output="$(run_isolated_bootstrap)"
printf '%s\n' "$saved_run_output" | grep -q 'input mode: ko-en-ja'
grep -qx 'ko-en-ja' "$TEST_ROOT/state/applied-sources"
# Dry runs never replace the saved mode.
run_dry_run --mode ko-en >/dev/null
grep -qx 'ko-en-ja' "$TEST_ROOT/home/.config/dotfiles/input-mode"
# Environment overrides the saved mode; command-line selection overrides both.
env_run_output="$(DOTFILES_INPUT_MODE=ko-en run_isolated_bootstrap --mode ko-en-ja)"
printf '%s\n' "$env_run_output" | grep -q 'input mode: ko-en-ja'
back_run_output="$(DOTFILES_INPUT_MODE=ko-en run_isolated_bootstrap)"
printf '%s\n' "$back_run_output" | grep -q 'input mode: ko-en'
printf '%s\n' "$back_run_output" | grep -q 'reloaded LaunchAgent: dev.undervars.dotfiles.input-source-switcher'
grep -q -- '--run ko-en</string>' "$switcher_target"
grep -qx 'ko-en' "$TEST_ROOT/state/applied-sources"
test -x "$switcher_binary"
cmp -s "$KEYS_KO_EN_PLIST" "$keys_target"
# A failed source application must abort rather than silently claim success.
! DOTFILES_SWITCHER_BINARY_SOURCE=/usr/bin/false \
  DOTFILES_ROOT="$ROOT" DOTFILES_INPUT_MODE=ko-en \
  DOTFILES_HOME="$TEST_ROOT/home" DOTFILES_TEST_STATE="$TEST_ROOT/state" \
  DOTFILES_DEFAULTS="$FIXTURE_BIN/defaults" \
  DOTFILES_PGREP="$FIXTURE_BIN/pgrep" \
  bash "$ROOT/scripts/macos/10-input-source-switcher.sh" >/dev/null 2>&1

# Switching the Ghostty font repoints the profile link. It has to survive being
# switched back too: the link belongs to this repository, so it is replaced
# rather than backed up, and a second switch would otherwise collide with the
# backup the first one left behind.
ghostty_font_link="$TEST_ROOT/home/.config/ghostty/font.conf"
test "$(readlink "$ghostty_font_link")" = "$ROOT/config/ghostty/fonts/firacode.conf"

geist_run_output="$(run_isolated_bootstrap --font geist)"
printf '%s\n' "$geist_run_output" | grep -q 'ghostty font: geist'
printf '%s\n' "$geist_run_output" | grep -q 'relinked:.*ghostty/font.conf'
test "$(readlink "$ghostty_font_link")" = "$ROOT/config/ghostty/fonts/geist.conf"

back_to_firacode_output="$(run_isolated_bootstrap)"
printf '%s\n' "$back_to_firacode_output" | grep -q 'relinked:.*ghostty/font.conf'
test "$(readlink "$ghostty_font_link")" = "$ROOT/config/ghostty/fonts/firacode.conf"
test ! -e "$TEST_ROOT/state-home/dotfiles/backups/.config/ghostty/font.conf"

# The included profile is resolved relative to the link, not to the file in the
# repository, so the base config must ask for it by a bare relative name.
grep -qx 'config-file = ?font.conf' "$TEST_ROOT/home/.config/ghostty/config"

# Every apply re-asserts the typing defaults, so a machine where someone turned
# one back on in System Settings is repaired rather than left alone.
for text_input_key in "${text_input_keys[@]}"; do
  printf '%s\n' '1' >"$TEST_ROOT/state/global-$text_input_key"
done
drift_run_output="$(run_isolated_bootstrap)"
printf '%s\n' "$drift_run_output" | grep -q 'set double-space period substitution off'
printf '%s\n' "$drift_run_output" | grep -q 'set automatic capitalization off'
printf '%s\n' "$drift_run_output" | grep -q 'set smart quote substitution off'
printf '%s\n' "$drift_run_output" | grep -q 'set smart dash substitution off'
printf '%s\n' "$drift_run_output" | grep -q 'set automatic spelling correction off'
assert_text_input_defaults_off

# A machine where the keys were never set at all — a fresh VM — must get all of
# them written rather than skipped for lack of a current value.
for text_input_key in "${text_input_keys[@]}"; do
  rm -f "$TEST_ROOT/state/global-$text_input_key"
done
fresh_run_output="$(run_isolated_bootstrap)"
printf '%s\n' "$fresh_run_output" | grep -q 'set automatic spelling correction off'
assert_text_input_defaults_off

# An entry left bound to the right key but the wrong modifier mask must be
# repaired rather than read as already correct.
printf '%s\n' 'true 79 0' >"$TEST_ROOT/state/hotkey-60"
stale_run_output="$(run_isolated_bootstrap)"
printf '%s\n' "$stale_run_output" | grep -q 'applied native previous-input-source hotkey disabled'
grep -qx 'false 49 262144' "$TEST_ROOT/state/hotkey-60"

test ! -e "$TEST_ROOT/home/Library/LaunchAgents/dev.undervars.dotfiles.input-source-cycle.plist"
test -L "$TEST_ROOT/home/.bashrc"
test -L "$TEST_ROOT/home/.local/bin/gcloud-adc-account"
test -L "$TEST_ROOT/home/.config/bash/alias.sh"
test -L "$TEST_ROOT/home/.config/helix"
grep -q 'original bashrc' "$TEST_ROOT/state-home/dotfiles/backups/.bashrc"

input_only_dry_run_output="$(
  DOTFILES_BREW=/nonexistent/brew \
    DOTFILES_HOME="$TEST_ROOT/home" \
    DOTFILES_HAMMERSPOON_APP="$TEST_ROOT/Hammerspoon.app" \
    DOTFILES_HS_CLI="$TEST_ROOT/bin/hs" \
    DOTFILES_OSASCRIPT=/nonexistent/osascript \
    DOTFILES_PGREP="$FIXTURE_BIN/pgrep" \
    "$ROOT/setup-input-sources.sh" --dry-run 2>&1
)"
printf '%s\n' "$input_only_dry_run_output" | grep -q 'input-source-only setup complete'
printf '%s\n' "$input_only_dry_run_output" | grep -q 'input mode: ko-en'
# The dedicated entrypoint must cover the typing defaults too, otherwise a
# machine set up without the full bootstrap keeps the substitution.
printf '%s\n' "$input_only_dry_run_output" | grep -Eq 'double-space period substitution off'
printf '%s\n' "$input_only_dry_run_output" | grep -q 'would apply input sources for mode: ko-en'
! printf '%s\n' "$input_only_dry_run_output" | grep -q 'right Option -> F19'

if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r script; do
    shellcheck -x "$script"
  done < <(find "$ROOT" -type f -name '*.sh' -print | sort)
fi

printf '%s\n' 'tests passed'
