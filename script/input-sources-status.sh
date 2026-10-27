#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/lib/common.sh"
if [ "$(resolve_input_backend)" = native ]; then
  exec bash "$ROOT/script/native-input.sh" status
fi
mode="$(resolve_input_mode)"
switcher="${DOTFILES_HOME:-$HOME}/Library/Application Support/dev.undervars.dotfiles/bin/input-source-switcher"
printf '%s\n' 'backend=helper'
"$switcher" --check "$mode"
printf 'globeInputSource=%s\n' "$(/usr/bin/defaults read com.apple.HIToolbox AppleFnUsageType)"
service="gui/$(id -u)/dev.undervars.dotfiles.input-source-switcher"
/bin/launchctl print "$service" | awk '/^\t(state|pid|last exit code) =/'
