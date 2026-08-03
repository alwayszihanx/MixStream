#!/usr/bin/env bash
# MixStream one-command uninstaller
# Usage: curl -fsSL https://raw.githubusercontent.com/alwayszihanx/MixStream/main/uninstaller.sh | sudo bash

set -euo pipefail

APP_ID="io.alwayszihan.mixstream"
INSTALL_DIR="/opt/mixstream"
BIN_LINK="/usr/local/bin/mixstream"

log() { printf '\033[1;34m[MixStream]\033[0m %s\n' "$*"; }

main() {
  log "Removing MixStream..."
  rm -rf "${INSTALL_DIR}"
  rm -f "${BIN_LINK}"

  local user_home plugins_root
  user_home="${SUDO_USER:-$HOME}"
  plugins_root="${XDG_DATA_HOME:-${user_home}/.local/share}/${APP_ID}/extensions/plugin"

  log "Removing MixPlug plugins (${plugins_root})..."
  rm -rf "$plugins_root"

  log "MixStream and its plugins have been uninstalled."
}

main "$@"
