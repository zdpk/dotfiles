#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST="$ROOT/config/macos/LaunchAgents/dev.undervars.dotfiles.input-source-cycle.plist"
FIXTURE_BIN="$ROOT/tests/fixtures/bin"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tests.XXXXXX")"

trap 'rm -rf "$TEST_ROOT"' EXIT

while IFS= read -r script; do
  bash -n "$script"
done < <(find "$ROOT" -type f -name '*.sh' -print | sort)

/usr/bin/plutil -lint "$PLIST" >/dev/null

mapping_json="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:3' "$PLIST")"
printf '%s\n' "$mapping_json" | grep -q '0x7000000E7'
printf '%s\n' "$mapping_json" | grep -q '0xFF00000003'

dry_run_output="$("$ROOT/bootstrap.sh" --dry-run 2>&1)"
printf '%s\n' "$dry_run_output" | grep -q 'platform: macos'
printf '%s\n' "$dry_run_output" | grep -q 'input-source order verified'
printf '%s\n' "$dry_run_output" | grep -Eq 'right Command maps to Fn/Globe|would apply right Command -> Fn/Globe'

"$ROOT/bootstrap.sh" --help >/dev/null

mkdir -p "$TEST_ROOT/home" "$TEST_ROOT/state"

run_isolated_bootstrap() {
  DOTFILES_DEFAULTS="$FIXTURE_BIN/defaults" \
    DOTFILES_HIDUTIL="$FIXTURE_BIN/hidutil" \
    DOTFILES_HOME="$TEST_ROOT/home" \
    DOTFILES_ID="$FIXTURE_BIN/id" \
    DOTFILES_LAUNCHCTL="$FIXTURE_BIN/launchctl" \
    DOTFILES_PGREP="$FIXTURE_BIN/pgrep" \
    DOTFILES_TEST_STATE="$TEST_ROOT/state" \
    "$ROOT/bootstrap.sh" 2>&1
}

first_run_output="$(run_isolated_bootstrap)"
printf '%s\n' "$first_run_output" | grep -q 'configured Fn/Globe'
printf '%s\n' "$first_run_output" | grep -q 'installed:.*input-source-cycle.plist'
printf '%s\n' "$first_run_output" | grep -q 'loaded LaunchAgent'
printf '%s\n' "$first_run_output" | grep -q 'applied right Command -> Fn/Globe'

second_run_output="$(run_isolated_bootstrap)"
printf '%s\n' "$second_run_output" | grep -q 'unchanged: Fn/Globe'
printf '%s\n' "$second_run_output" | grep -q 'unchanged:.*input-source-cycle.plist'
printf '%s\n' "$second_run_output" | grep -q 'unchanged: LaunchAgent is loaded'
printf '%s\n' "$second_run_output" | grep -q 'unchanged: right Command maps to Fn/Globe'

cmp -s "$PLIST" "$TEST_ROOT/home/Library/LaunchAgents/dev.undervars.dotfiles.input-source-cycle.plist"

if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r script; do
    shellcheck -x "$script"
  done < <(find "$ROOT" -type f -name '*.sh' -print | sort)
fi

printf '%s\n' 'tests passed'
