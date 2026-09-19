#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DATA=/var/lib/northstar-guard
BIN=/usr/local/bin/northstar-guard
SERVICE=/etc/systemd/system/northstar-guard.service
VERSION=1.0.0

usage() {
    cat <<'EOF'
Usage: install.sh [--upgrade|--repair|--status|--uninstall]

Install or safely manage the Northstar Guard lightweight Linux agent.
EOF
}

ACTION=install
case "${1:-}" in
    "") ;;
    --upgrade) ACTION=upgrade ;;
    --repair) ACTION=repair ;;
    --status) ACTION=status ;;
    --uninstall) ACTION=uninstall ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac

sudo -n true 2>/dev/null || { echo "Passwordless sudo is required" >&2; exit 1; }

if [ "$ACTION" = status ]; then
    sudo systemctl --no-pager --full status northstar-guard.service || true
    if [ -x "$BIN" ]; then sudo "$BIN" status || true; fi
    if [ -f "$DATA/agent-version" ]; then printf 'Version: '; sudo cat "$DATA/agent-version"; fi
    if [ -f "$DATA/agent-id" ]; then printf 'Agent ID: '; sudo cat "$DATA/agent-id"; fi
    exit 0
fi

if [ "$ACTION" = repair ]; then
    sudo systemctl daemon-reload
    sudo systemctl enable --now northstar-guard.service
    echo "Northstar Guard repair complete."
    exit 0
fi

if [ "$ACTION" = uninstall ]; then
    sudo systemctl disable --now northstar-guard.service >/dev/null 2>&1 || true
    sudo rm -f "$SERVICE" "$BIN" /usr/sbin/northstar-guard
    sudo systemctl daemon-reload
    echo "Northstar Guard removed; reports, findings, trusted data, and legacy quarantine remain in $DATA."
    exit 0
fi

command -v yara >/dev/null || { echo "YARA is required" >&2; exit 1; }
if ! command -v clamscan >/dev/null; then
    echo "Warning: ClamAV is not installed; live checks will use YARA until clamscan is added." >&2
fi

if [ "$ACTION" = upgrade ] && sudo test -d "$DATA"; then
    backup="$DATA/backups/$(date +%Y%m%d-%H%M%S)"
    sudo install -d -m 0700 "$backup"
    for item in config.json control.json trusted.tsv trusted-known-good.json; do
        if sudo test -e "$DATA/$item"; then sudo cp -p "$DATA/$item" "$backup/$item"; fi
    done
fi

tmpbin="$(mktemp /tmp/northstar-guard.XXXXXX)"
trap 'rm -f "$tmpbin"' EXIT
if command -v gcc >/dev/null; then
    gcc -O2 -Wall -Wextra -Wpedantic "$ROOT/northstar-guard.c" -o "$tmpbin"
else
    case "$(uname -m)" in
        x86_64) prebuilt="$ROOT/prebuilt/northstar-guard.x86_64" ;;
        aarch64|arm64) prebuilt="$ROOT/prebuilt/northstar-guard.aarch64" ;;
        *) prebuilt="" ;;
    esac
    [ -n "$prebuilt" ] && [ -x "$prebuilt" ] || { echo "gcc is required (no compatible prebuilt binary)" >&2; exit 1; }
    install -m 0755 "$prebuilt" "$tmpbin"
fi

sudo install -d -m 0755 "$DATA" "$DATA/rules" "$DATA/reports"
sudo install -m 0755 "$tmpbin" "$BIN"
sudo ln -sfn "$BIN" /usr/sbin/northstar-guard
sudo install -m 0644 "$ROOT/rules/northstar.yar" "$DATA/rules/northstar.yar"
sudo install -m 0644 "$ROOT/northstar-guard.service" "$SERVICE"

if ! sudo test -s "$DATA/agent-version"; then printf '%s\n' "$VERSION" | sudo tee "$DATA/agent-version" >/dev/null; fi
if ! sudo test -s "$DATA/agent-id"; then
    host="$(hostname -s 2>/dev/null || hostname)"
    machine="$(cat /etc/machine-id 2>/dev/null || true)"
    printf 'linux-%s-%s\n' "$host" "${machine:0:12}" | sudo tee "$DATA/agent-id" >/dev/null
fi
sudo chmod 0644 "$DATA/agent-version" "$DATA/agent-id"

# Stop and quarantine legacy Maldet/LMD hooks. Files are moved, never deleted.
for unit in maldet.service maldet.timer br-lite-malware-scan.timer ray-lmd-weekly-scan.timer; do
    sudo systemctl disable --now "$unit" >/dev/null 2>&1 || true
done
removed="$DATA/removed-maldet-$(date +%Y%m%d-%H%M%S)"
sudo install -d -m 0700 "$removed"
for item in \
    /usr/local/maldetect /usr/local/sbin/maldet /etc/cron.daily/maldet /etc/cron.d/maldet \
    /etc/sysconfig/maldet /etc/systemd/system/maldet.service /etc/systemd/system/maldet.timer \
    /etc/systemd/system/br-lite-malware-scan.timer /etc/systemd/system/ray-lmd-weekly-scan.timer; do
    if sudo test -e "$item" || sudo test -L "$item"; then
        name="${item#/}"; name="${name//\//-}"
        sudo mv "$item" "$removed/$name"
    fi
done
if command -v clamscan >/dev/null; then sudo systemctl enable --now clamav-freshclam.service >/dev/null 2>&1 || true; fi
sudo systemctl daemon-reload
for unit in maldet.service maldet.timer br-lite-malware-scan.timer ray-lmd-weekly-scan.timer; do
    sudo systemctl reset-failed "$unit" >/dev/null 2>&1 || true
done
sudo systemctl enable --now northstar-guard.service

echo "Northstar Guard $ACTION complete (v$VERSION)."
echo "  Service: $SERVICE"
echo "  Reports: $DATA/reports"
echo "  Check:   sudo $BIN status"
