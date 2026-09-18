#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DATA=/var/lib/northstar-guard
BIN=/usr/local/bin/northstar-guard
SERVICE=/etc/systemd/system/northstar-guard.service

sudo -n true 2>/dev/null || { echo "Passwordless sudo is required for installation" >&2; exit 1; }

command -v yara >/dev/null || { echo "YARA is required" >&2; exit 1; }
if ! command -v clamscan >/dev/null; then
    echo "Warning: ClamAV is not installed; live checks will use YARA until clamscan is added." >&2
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

# Stop and disable legacy Maldet/LMD hooks. ClamAV definition updates are left intact.
for unit in maldet.service maldet.timer br-lite-malware-scan.timer ray-lmd-weekly-scan.timer; do
    sudo systemctl disable --now "$unit" >/dev/null 2>&1 || true
done
# Quarantine legacy Maldet/LMD files instead of deleting them, so rollback remains possible.
removed="$DATA/removed-maldet-$(date +%Y%m%d-%H%M%S)"
sudo install -d -m 0700 "$removed"
for item in \
    /usr/local/maldetect \
    /usr/local/sbin/maldet \
    /etc/cron.daily/maldet \
    /etc/cron.d/maldet \
    /etc/sysconfig/maldet \
    /etc/systemd/system/maldet.service \
    /etc/systemd/system/maldet.timer \
    /etc/systemd/system/br-lite-malware-scan.timer \
    /etc/systemd/system/ray-lmd-weekly-scan.timer; do
    if [ -e "$item" ] || [ -L "$item" ]; then
        name="${item#/}"; name="${name//\//-}"
        sudo mv "$item" "$removed/$name"
    fi
done
# Keep definitions current without starting a scan daemon when ClamAV is present.
if command -v clamscan >/dev/null; then sudo systemctl enable --now clamav-freshclam.service >/dev/null 2>&1 || true; fi
sudo systemctl daemon-reload
for unit in maldet.service maldet.timer br-lite-malware-scan.timer ray-lmd-weekly-scan.timer; do
    sudo systemctl reset-failed "$unit" >/dev/null 2>&1 || true
done
sudo systemctl enable --now northstar-guard.service

echo "Northstar Guard lightweight server agent installed."
echo "  Service: $SERVICE"
echo "  Reports: $DATA/reports"
echo "  Check:   sudo $BIN status"
