#!/bin/bash

# Shared constants and helpers for the ziouf.dsh plugin scripts. Source it:
#   . "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PLUGIN_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[1]}")")/.." && pwd)"
APP_NAME="DeepSeek Harness"
DESKTOP_FILE="$HOME/.local/share/applications/$APP_NAME.desktop"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/dsh"
WEB_URL_FILE="$STATE_DIR/web-url"
DEFAULT_URL="http://127.0.0.1:3080"

# Pinned upstream dsh release. Bump deliberately and re-run scripts/upgrade-dsh
# afterwards; never install a moving tag from here.
DSH_VERSION="0.1.1-rc.2"
DSH_MISE_SPEC="npm:@deepseek-ai/dsh@$DSH_VERSION"
DSH_NPM_SPEC="${DSH_MISE_SPEC#npm:}"
# Lifecycle scripts kept to the two packages with native bindings dsh needs at
# runtime. Everything else installs without running its postinstall.
DSH_ALLOW_SCRIPTS="--allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty"

# Install or reinstall dsh at exactly $DSH_VERSION. Tries mise first, falls
# back to a pinned global npm install under the mise-managed node (mise cannot
# resolve prerelease npm packages non-interactively).
install_dsh() {
  echo "Installing DeepSeek Harness ($DSH_MISE_SPEC)..."
  mise use -g "$DSH_MISE_SPEC" && return 0
  npm install -g $DSH_ALLOW_SCRIPTS "$DSH_NPM_SPEC"
}

notify() {
  command -v omarchy-notification-send >/dev/null &&
    omarchy-notification-send -g 󰚩 "$APP_NAME" "$1" || true
}
