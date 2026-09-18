#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin"
DATA="$HOME/.local/share/northstar-guard"
SERVICE_DIR="$HOME/.config/systemd/user"
APP_DIR="$HOME/.local/share/applications"

command -v gcc >/dev/null || { echo "gcc is required" >&2; exit 1; }
pkg-config --exists gtk4 || { echo "gtk4-devel is required" >&2; exit 1; }
command -v yara >/dev/null || { echo "yara is required" >&2; exit 1; }
command -v clamscan >/dev/null || { echo "ClamAV (clamscan) is required" >&2; exit 1; }

mkdir -p "$BIN" "$DATA/rules" "$DATA/reports" "$SERVICE_DIR" "$APP_DIR"
gcc -O2 -Wall -Wextra -Wpedantic "$ROOT/northstar-guard.c" -o "$BIN/northstar-guard"
gcc -O2 -Wall -Wextra -Wpedantic "$ROOT/northstar-guard-ui.c" -o "$BIN/northstar-guard-ui" $(pkg-config --cflags --libs gtk4)
install -m 0644 "$ROOT/rules/northstar.yar" "$DATA/rules/northstar.yar"
install -m 0644 "$ROOT/northstar-guard.service" "$SERVICE_DIR/northstar-guard.service"
install -m 0644 "$ROOT/com.owensreo.NorthstarGuard.desktop" "$APP_DIR/com.owensreo.NorthstarGuard.desktop"

systemctl --user daemon-reload
systemctl --user enable --now northstar-guard.service
command -v update-desktop-database >/dev/null && update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true

echo "Northstar Guard installed."
echo "  GUI: northstar-guard-ui"
echo "  CLI: northstar-guard status | scan quick | scan full | findings"
echo "  Reports: $DATA/reports"
