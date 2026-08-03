#!/usr/bin/env bash
# MixStream one-command installer
# Usage: curl -fsSL https://raw.githubusercontent.com/alwayszihanx/MixStream/main/installer.sh | sudo bash
#
# Installs:
#   1. MixStream itself (latest release for this architecture)
#   2. ALL MixPlug plugins (downloaded from the MixPlug plugin repository)
#      -> installed into the app's plugin directory so they appear
#         pre-installed on first launch.

set -euo pipefail

REPO_OWNER="alwayszihanx"
REPO_NAME="MixStream"
GITHUB_BASE="https://github.com/${REPO_OWNER}/${REPO_NAME}"
RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main"
MIXPLUG_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/Mixplug/main/plugins"

APP_ID="io.alwayszihan.mixstream"
INSTALL_DIR="/opt/mixstream"
BIN_LINK="/usr/local/bin/mixstream"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { printf '\033[1;34m[MixStream]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[MixStream]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[MixStream]\033[0m %s\n' "$*" >&2; exit 1; }

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  echo "x64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) fail "Unsupported architecture: $(uname -m)" ;;
  esac
}

fetch_latest_version() {
  curl -fsSL "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest" \
    | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/'
}

# ---------------------------------------------------------------------------
# 1. Install MixStream
# ---------------------------------------------------------------------------
install_app() {
  local arch version tarball_url
  arch=$(detect_arch)
  version=$(fetch_latest_version)
  tarball_url="${GITHUB_BASE}/releases/download/${version}/MixStream-Linux-${arch}-${version}.tar.gz"

  log "Downloading MixStream ${version} (${arch})..."
  curl -fL "$tarball_url" -o /tmp/mixstream.tar.gz || fail "Failed to download ${tarball_url}"

  log "Installing to ${INSTALL_DIR}..."
  rm -rf "${INSTALL_DIR}"
  mkdir -p "${INSTALL_DIR}"
  tar -xzf /tmp/mixstream.tar.gz -C "${INSTALL_DIR}"
  chmod +x "${INSTALL_DIR}/mixstream"
  rm -f /tmp/mixstream.tar.gz

  if [ -d "${INSTALL_DIR}/data" ] && [ -f "${INSTALL_DIR}/lib/libflutter_linux_gtk.so" ]; then
    : # bundle layout looks correct
  else
    warn "Unexpected bundle layout — app may not launch."
  fi

  ln -sf "${INSTALL_DIR}/mixstream" "${BIN_LINK}"
  log "MixStream installed. Run with: mixstream"
}

# ---------------------------------------------------------------------------
# 2. Install MixPlug plugins (inline, from the MixPlug plugin repository)
# ---------------------------------------------------------------------------
install_plugins() {
  local repo_json plugins_json plugin_dir target_dir
  plugin_dir="${HOME}/.local/share/${APP_ID}/extensions/plugin"

  log "Fetching MixPlug plugin list..."
  repo_json="$(curl -fsSL "${MIXPLUG_BASE}/repo.json")" || {
    warn "Failed to fetch MixPlug repo.json — skipping plugin install."
    return 0
  }

  # repo.json points at a plugin list (pluginLists[0]); fetch that JSON array.
  plugins_json_url="$(printf '%s' "$repo_json" | grep -o 'https://[^"]*' | head -1)"

  if [ -z "$plugins_json_url" ]; then
    warn "No plugin list found in MixPlug repo.json — skipping plugin install."
    return 0
  fi

  local plugins_json
  plugins_json="$(curl -fsSL "$plugins_json_url")" || {
    warn "Failed to fetch MixPlug plugin list — skipping plugin install."
    return 0
  }

  # Each entry has a "url" (a .mix zip) and a "packageName".
  # Parse with grep/sed (no jq dependency).
  local urls package_names i
  urls="$(printf '%s' "$plugins_json" | grep -o 'https://[^"]*\.mix' )"
  package_names="$(printf '%s' "$plugins_json" | grep -o '"packageName": *"[^"]*"' | sed 's/.*"packageName": *"\([^"]*\)".*/\1/')"

  if [ -z "$urls" ]; then
    warn "No plugins found in MixPlug — skipping plugin install."
    return 0
  fi

  mkdir -p "$plugin_dir"
  i=1
  while read -r url; do
    pkg_name="$(printf '%s\n' "$package_names" | sed -n "${i}p")"
    i=$((i + 1))

    [ -n "$url" ] || continue
    if [ -z "$pkg_name" ]; then
      pkg_name="$(basename "$url" .mix)"
    fi

    target_dir="${plugin_dir}/${pkg_name}"
    log "Installing plugin: ${pkg_name}"
    curl -fsSL "$url" -o /tmp/mixplug-plugin.mix || {
      warn "Failed to download ${pkg_name} — skipping."
      continue
    }

    rm -rf "$target_dir"
    mkdir -p "$target_dir"
    if command -v unzip >/dev/null 2>&1; then
      unzip -o -q /tmp/mixplug-plugin.mix -d "$target_dir" || {
        warn "Failed to extract ${pkg_name} — skipping."
        continue
      }
    elif command -v python3 >/dev/null 2>&1; then
      python3 -c "import sys,zipfile; zipfile.ZipFile('/tmp/mixplug-plugin.mix').extractall('$target_dir')" || {
        warn "Failed to extract ${pkg_name} — skipping."
        continue
      }
    else
      warn "No unzip or python3 available — skipping ${pkg_name}."
      continue
    fi

    # Write meta.json so the app recognizes the plugin as installed
    # (repositoryId + install-time SHA-256 of plugin.js for integrity).
    local js_sha
    if [ -f "${target_dir}/plugin.js" ]; then
      js_sha="$(sha256sum "${target_dir}/plugin.js" | awk '{print $1}')"
    fi
    {
      printf '{\n'
      printf '  "repositoryId": "io.alwayszihan.mixstream",\n'
      printf '  "packageName": "%s",\n' "$pkg_name"
      if [ -n "$js_sha" ]; then
        printf '  "installSha256": "%s",\n' "$js_sha"
      fi
      printf '  "installedBy": "installer.sh"\n'
      printf '}\n'
    } > "${target_dir}/meta.json"

    rm -f /tmp/mixplug-plugin.mix
  done <<< "$urls"

  log "All MixPlug plugins installed to ${plugin_dir}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  [ "$(id -u)" -eq 0 ] || warn "Running without root — the app will install to ${INSTALL_DIR} but may lack permissions."

  install_app
  install_plugins

  log "Done! MixStream + MixPlug plugins installed."
  log "Run the app: mixstream"
  log "Uninstall: curl -fsSL ${RAW_BASE}/uninstaller.sh | sudo bash"
}

main "$@"
