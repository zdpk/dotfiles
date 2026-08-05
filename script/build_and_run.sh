#!/usr/bin/env bash

set -euo pipefail

MODE="${1:-run}"
APP_NAME="input-source-switcher"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/config/macos/InputSourceSwitcher"
AGENT_LABEL="dev.undervars.dotfiles.input-source-switcher"
AGENT_PLIST="$HOME/Library/LaunchAgents/$AGENT_LABEL.plist"
AGENT_DOMAIN="gui/$(id -u)"
RESTORE_AGENT=0
APP_PID=""

cleanup() {
  if [ -n "$APP_PID" ]; then
    kill "$APP_PID" >/dev/null 2>&1 || true
    wait "$APP_PID" 2>/dev/null || true
  fi
  if [ "$RESTORE_AGENT" -eq 1 ] && [ -f "$AGENT_PLIST" ]; then
    launchctl bootstrap "$AGENT_DOMAIN" "$AGENT_PLIST"
  fi
}
trap cleanup EXIT INT TERM

if launchctl print "$AGENT_DOMAIN/$AGENT_LABEL" >/dev/null 2>&1; then
  launchctl bootout "$AGENT_DOMAIN/$AGENT_LABEL"
  RESTORE_AGENT=1
fi
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcrun swift build \
  --package-path "$PACKAGE_DIR" \
  --configuration debug \
  --product "$APP_NAME"
BIN_DIR="$(xcrun swift build \
  --package-path "$PACKAGE_DIR" \
  --configuration debug \
  --show-bin-path)"
APP_BINARY="$BIN_DIR/$APP_NAME"

case "$MODE" in
  run)
    "$APP_BINARY"
    ;;
  --debug | debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs | logs | --telemetry | telemetry)
    "$APP_BINARY" &
    APP_PID="$!"
    /usr/bin/log stream --info --style compact \
      --predicate "process == \"$APP_NAME\""
    ;;
  --verify | verify)
    "$APP_BINARY" &
    APP_PID="$!"
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    printf 'usage: %s [run|--debug|--logs|--telemetry|--verify]\n' "$0" >&2
    exit 2
    ;;
esac
