#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEYS_PLIST="$ROOT/config/macos/LaunchAgents/dev.undervars.dotfiles.input-source-keys.plist"
SWITCHER_PLIST="$ROOT/config/macos/LaunchAgents/dev.undervars.dotfiles.input-source-switcher.plist"
PACKAGE="$ROOT/config/macos/InputSourceSwitcher"
FIXTURE_BIN="$ROOT/tests/fixtures/bin"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tests.XXXXXX")"

trap 'rm -rf "$TEST_ROOT"' EXIT

while IFS= read -r script; do
  bash -n "$script"
done < <(find "$ROOT" -type f -name '*.sh' -print | sort)

/usr/bin/plutil -lint "$KEYS_PLIST" >/dev/null
/usr/bin/plutil -lint "$SWITCHER_PLIST" >/dev/null

mapping_json="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:3' "$KEYS_PLIST")"
printf '%s\n' "$mapping_json" | grep -q '0x7000000E7'
printf '%s\n' "$mapping_json" | grep -q '0x70000006D'
printf '%s\n' "$mapping_json" | grep -q '0x7000000E6'
printf '%s\n' "$mapping_json" | grep -q '0x70000006E'

/usr/bin/xcrun swift test --package-path "$PACKAGE"
/usr/bin/xcrun swift build \
  --package-path "$PACKAGE" \
  --configuration release \
  --product input-source-switcher

release_bin_dir="$(/usr/bin/xcrun swift build \
  --package-path "$PACKAGE" \
  --configuration release \
  --show-bin-path)"
"$release_bin_dir/input-source-switcher" --check | grep -q 'japanese=com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese'

dry_run_output="$("$ROOT/bootstrap.sh" --dry-run 2>&1)"
printf '%s\n' "$dry_run_output" | grep -q 'platform: macos'
printf '%s\n' "$dry_run_output" | grep -q 'input sources verified'
printf '%s\n' "$dry_run_output" | grep -Eq 'right Command -> F18, right Option -> F19|would apply right Command -> F18, right Option -> F19'

"$ROOT/bootstrap.sh" --help >/dev/null

mkdir -p \
  "$TEST_ROOT/home/Library/LaunchAgents" \
  "$TEST_ROOT/state"
cp "$ROOT/tests/fixtures/legacy-cycle.plist" \
  "$TEST_ROOT/home/Library/LaunchAgents/dev.undervars.dotfiles.input-source-cycle.plist"
: >"$TEST_ROOT/state/launch-agent-dev.undervars.dotfiles.input-source-cycle"

run_isolated_bootstrap() {
  DOTFILES_DEFAULTS="$FIXTURE_BIN/defaults" \
    DOTFILES_HIDUTIL="$FIXTURE_BIN/hidutil" \
    DOTFILES_HOME="$TEST_ROOT/home" \
    DOTFILES_ID="$FIXTURE_BIN/id" \
    DOTFILES_LAUNCHCTL="$FIXTURE_BIN/launchctl" \
    DOTFILES_PGREP="$FIXTURE_BIN/pgrep" \
    DOTFILES_SWITCHER_BINARY_SOURCE="$FIXTURE_BIN/input-source-switcher" \
    DOTFILES_TEST_STATE="$TEST_ROOT/state" \
    "$ROOT/bootstrap.sh" 2>&1
}

first_run_output="$(run_isolated_bootstrap)"
printf '%s\n' "$first_run_output" | grep -q 'unloaded legacy LaunchAgent'
printf '%s\n' "$first_run_output" | grep -q 'removed:.*input-source-cycle.plist'
printf '%s\n' "$first_run_output" | grep -q 'installed:.*input-source-switcher'
printf '%s\n' "$first_run_output" | grep -q 'loaded LaunchAgent: dev.undervars.dotfiles.input-source-switcher'
printf '%s\n' "$first_run_output" | grep -q 'loaded LaunchAgent: dev.undervars.dotfiles.input-source-keys'
printf '%s\n' "$first_run_output" | grep -q 'applied right Command -> F18, right Option -> F19'

second_run_output="$(run_isolated_bootstrap)"
printf '%s\n' "$second_run_output" | grep -q 'unchanged:.*input-source-switcher'
printf '%s\n' "$second_run_output" | grep -q 'unchanged: LaunchAgent is loaded: dev.undervars.dotfiles.input-source-switcher'
printf '%s\n' "$second_run_output" | grep -q 'unchanged: LaunchAgent is loaded: dev.undervars.dotfiles.input-source-keys'
printf '%s\n' "$second_run_output" | grep -q 'unchanged: right Command -> F18, right Option -> F19'

test ! -e "$TEST_ROOT/home/Library/LaunchAgents/dev.undervars.dotfiles.input-source-cycle.plist"
cmp -s "$KEYS_PLIST" "$TEST_ROOT/home/Library/LaunchAgents/dev.undervars.dotfiles.input-source-keys.plist"
cmp -s "$SWITCHER_PLIST" "$TEST_ROOT/home/Library/LaunchAgents/dev.undervars.dotfiles.input-source-switcher.plist"

if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r script; do
    shellcheck -x "$script"
  done < <(find "$ROOT" -type f -name '*.sh' -print | sort)
fi

printf '%s\n' 'tests passed'
