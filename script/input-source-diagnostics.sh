#!/usr/bin/env bash

set -euo pipefail

[ "$(uname -s)" = Darwin ] || { printf '%s\n' 'Input diagnostics require macOS.' >&2; exit 1; }

case "${1:-}" in
  --follow | '') ;;
  -h | --help)
    printf '%s\n' 'Usage: ./script/input-source-diagnostics.sh [--follow]' \
      'Shows installed state and recent switching logs without restarting the helper.'
    exit 0
    ;;
  *) printf '%s\n' 'Expected --follow or no arguments.' >&2; exit 64 ;;
esac

switcher="$HOME/Library/Application Support/dev.undervars.dotfiles/bin/input-source-switcher"
service="gui/$(id -u)/dev.undervars.dotfiles.input-source-switcher"
predicate='subsystem == "dev.undervars.dotfiles.input-source-switcher" AND category == "Switching"'

printf '%s\n' '--- Installed input mode and current source ---'
if [ -x "$switcher" ]; then
  "$switcher" --check
else
  printf '%s\n' 'No installed input-source-switcher.'
fi

printf '%s\n' '--- LaunchAgent ---'
if service_info="$(/bin/launchctl print "$service" 2>/dev/null)"; then
  printf '%s\n' "$service_info" | awk '/^\t(state|pid|runs|last exit code) =/'
else
  printf '%s\n' 'LaunchAgent is not loaded.'
fi

printf '%s\n' '--- Hardware mapping ---'
/usr/bin/hidutil property --get UserKeyMapping

if [ "${1:-}" = --follow ]; then
  printf '%s\n' '--- Live switching events (Control+C stops viewing only) ---'
  exec /usr/bin/log stream --style compact --predicate "$predicate"
fi

printf '%s\n' '--- Switching events from the last 30 minutes ---'
/usr/bin/log show --last 30m --style compact --predicate "$predicate"
