#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ "$(uname -s)" = Darwin ] || { printf '%s\n' 'Native input setup requires macOS.' >&2; exit 1; }
action="${1:-status}"
case "$action" in
  apply | dry-run | status | restore) ;;
  *) printf '%s\n' 'Usage: script/native-input.sh [apply|dry-run|status|restore]' >&2; exit 2 ;;
esac
[ "$#" -le 1 ] || exit 2
export DOTFILES_NATIVE_SCRIPT="$ROOT/scripts/macos/native-input.js"
exec /usr/bin/osascript -l JavaScript "$ROOT/scripts/macos/native-input.js" "$action"
