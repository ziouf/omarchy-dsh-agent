#!/bin/bash

# Shared constants and helpers for the ziouf.dsh plugin scripts. Source it:
#   . "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PLUGIN_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[1]}")")/.." && pwd)"
APP_NAME="DeepSeek Harness"
DESKTOP_FILE="$HOME/.local/share/applications/$APP_NAME.desktop"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/dsh"
WEB_URL_FILE="$STATE_DIR/web-url"
DEFAULT_URL="http://127.0.0.1:3080"

notify() {
  command -v omarchy-notification-send >/dev/null &&
    omarchy-notification-send -g 󰚩 "$APP_NAME" "$1" || true
}
