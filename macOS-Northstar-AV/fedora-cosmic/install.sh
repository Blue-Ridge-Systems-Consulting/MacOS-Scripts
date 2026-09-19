#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin"
DATA="$HOME/.local/share/northstar-guard"
SERVICE_DIR="$HOME/.config/systemd/user"
APP_DIR="$HOME/.local/share/applications"
ACTION="install"
case "${1:-}" in
  "") ;;
  --upgrade) ACTION="upgrade" ;;
  --repair) ACTION="repair" ;;
  --status) ACTION="status" ;;
  --uninstall) ACTION="uninstall" ;;
  *) echo "Usage: $0 [--upgrade|--repair|--status|--uninstall]" >&2; exit 64 ;;
esac
if [[ "$ACTION" == "status" ]]; then systemctl --user status northstar-guard.service --no-pager || true; [[ -f "$DATA/status" ]] && cat "$DATA/status" || true; exit 0; fi
if [[ "$ACTION" == "repair" ]]; then systemctl --user daemon-reload; systemctl --user enable --now northstar-guard.service; echo "Northstar Guard service repaired."; exit 0; fi
if [[ "$ACTION" == "uninstall" ]]; then systemctl --user disable --now northstar-guard.service 2>/dev/null || true; rm -f "$SERVICE_DIR/northstar-guard.service" "$APP_DIR/com.owensreo.NorthstarGuard.desktop" "$BIN/northstar-guard" "$BIN/northstar-guard-ui"; echo "Service and binaries removed; $DATA was retained."; exit 0; fi

command -v gcc >/dev/null || { echo "gcc is required" >&2; exit 1; }
pkg-config --exists gtk4 || { echo "gtk4-devel is required" >&2; exit 1; }
command -v yara >/dev/null || { echo "yara is required" >&2; exit 1; }
command -v clamscan >/dev/null || { echo "ClamAV (clamscan) is required" >&2; exit 1; }

mkdir -p "$BIN" "$DATA/rules" "$DATA/reports" "$SERVICE_DIR" "$APP_DIR"
if [[ "$ACTION" == "upgrade" ]]; then
  BACKUP="$DATA/backups/$(date +%Y%m%d-%H%M%S)"; mkdir -p "$BACKUP"
  for preserved in trusted.tsv config.json; do [[ -f "$DATA/$preserved" ]] && cp -p "$DATA/$preserved" "$BACKUP/$preserved"; done
fi
printf '%s\n' '1.0.0' > "$DATA/agent-version"
if [[ ! -f "$DATA/agent-id" ]]; then printf 'linux-%s-%s\n' "$(hostname -s)" "$(cat /etc/machine-id | cut -c1-12)" > "$DATA/agent-id"; fi
gcc -O2 -Wall -Wextra -Wpedantic "$ROOT/northstar-guard.c" -o "$BIN/northstar-guard"
gcc -O2 -Wall -Wextra -Wpedantic "$ROOT/northstar-guard-ui.c" -o "$BIN/northstar-guard-ui" $(pkg-config --cflags --libs gtk4)
install -m 0644 "$ROOT/rules/northstar.yar" "$DATA/rules/northstar.yar"
install -m 0644 "$ROOT/northstar-guard.service" "$SERVICE_DIR/northstar-guard.service"
install -m 0644 "$ROOT/com.owensreo.NorthstarGuard.desktop" "$APP_DIR/com.owensreo.NorthstarGuard.desktop"

systemctl --user daemon-reload
systemctl --user enable --now northstar-guard.service
command -v update-desktop-database >/dev/null && update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true

echo "Northstar Guard $ACTION complete (v1.0.0)."
echo "  GUI: northstar-guard-ui"
echo "  CLI: northstar-guard status | scan quick | scan full | findings"
echo "  Reports: $DATA/reports"
