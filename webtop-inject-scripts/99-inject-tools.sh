#!/bin/bash
# Optional container-init updater/installer for joshyorko/actions (action-server) and joshyorko/rcc (rcc).
set -euo pipefail

update_tools="${UPDATE_ACTIONS_TOOLS:-false}"

if [[ "${update_tools,,}" != "true" ]] && command -v action-server >/dev/null 2>&1 && command -v rcc >/dev/null 2>&1; then
  exit 0
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ "${update_tools,,}" == "true" ]] || ! command -v action-server >/dev/null 2>&1; then
  echo "[init] Installing latest action-server from joshyorko/actions..."
  ACTION_SERVER_URL=$(
    curl -fsSL "https://api.github.com/repos/joshyorko/actions/releases?per_page=20" 2>/dev/null \
      | jq -r '[.[] | select(.prerelease == false and (.tag_name | startswith("action-server-")))] | .[0].assets[] | select(.name == "action-server-linux64") | .browser_download_url' \
      | head -n 1 || true
  )
  ACTION_SERVER_URL="${ACTION_SERVER_URL:-https://github.com/joshyorko/actions/releases/download/action-server-v1.2.6/action-server-linux64}"
  curl -fsSL "$ACTION_SERVER_URL" -o "$TMP_DIR/action-server"
  install -m 0755 -o root -g root "$TMP_DIR/action-server" /usr/local/bin/action-server
fi

if [[ "${update_tools,,}" == "true" ]] || ! command -v rcc >/dev/null 2>&1; then
  echo "[init] Installing latest rcc from joshyorko/rcc..."
  curl -fsSL "https://github.com/joshyorko/rcc/releases/latest/download/rcc-linux64" -o "$TMP_DIR/rcc"
  install -m 0755 -o root -g root "$TMP_DIR/rcc" /usr/local/bin/rcc
fi

echo "[init] action-server and rcc ready."
