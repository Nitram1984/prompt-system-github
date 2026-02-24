#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$BASE_DIR/systemd"
USER_UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

mkdir -p "$USER_UNIT_DIR"

render() {
  local src="$1"
  local dst="$2"
  sed "s#{{BASE_DIR}}#$BASE_DIR#g" "$src" > "$dst"
}

render "$TEMPLATE_DIR/prompt-system-analyze.service" "$USER_UNIT_DIR/prompt-system-analyze.service"
render "$TEMPLATE_DIR/prompt-system-analyze.timer" "$USER_UNIT_DIR/prompt-system-analyze.timer"

systemctl --user daemon-reload
systemctl --user enable --now prompt-system-analyze.timer
systemctl --user start prompt-system-analyze.service

echo "Installed and started prompt-system-analyze.timer"
systemctl --user status prompt-system-analyze.timer --no-pager
