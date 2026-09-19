#!/bin/zsh
# Install Northstar Guard from this checked-out repository.
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
SUPPORT_DIR="$HOME/Library/Application Support/NorthstarGuard"
APP_DIR="$HOME/Applications/Northstar Guard.app"
LAUNCH_DIR="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_DIR/com.rowens.northstar-guard.plist"
REPORTS_DIR="${NORTHSTAR_GUARD_REPORT_DIR:-$HOME/NorthstarGuardReports}"
ACTION="install"
PACKAGE_VERSION="1.0.0"

case "${1:-}" in
  "") ;;
  --upgrade) ACTION="upgrade" ;;
  --repair) ACTION="repair" ;;
  --status) ACTION="status" ;;
  --uninstall) ACTION="uninstall" ;;
  --reports-dir)
    [[ -n "${2:-}" ]] || { print -u2 "Usage: $0 --reports-dir DIRECTORY"; exit 64; }
    REPORTS_DIR="$2" ;;
  *) print -u2 "Usage: $0 [--upgrade|--repair|--status|--uninstall|--reports-dir DIRECTORY]"; exit 64 ;;
esac

UID_VALUE="$(id -u)"
if [[ "$ACTION" == "status" ]]; then
  launchctl print "gui/${UID_VALUE}/com.rowens.northstar-guard" 2>/dev/null || print "Northstar Guard service is not loaded."
  [[ -f "$SUPPORT_DIR/status.json" ]] && cat "$SUPPORT_DIR/status.json" || print "No status snapshot yet."
  exit 0
fi
if [[ "$ACTION" == "uninstall" ]]; then
  launchctl bootout "gui/${UID_VALUE}/com.rowens.northstar-guard" 2>/dev/null || true
  rm -f "$PLIST"
  print "Northstar Guard service removed; reports, findings, trusted items, and configuration were retained at $SUPPORT_DIR."
  exit 0
fi
if [[ "$ACTION" == "repair" ]]; then
  [[ -f "$PLIST" ]] || { print -u2 "Northstar Guard is not installed."; exit 1; }
  launchctl bootout "gui/${UID_VALUE}/com.rowens.northstar-guard" 2>/dev/null || true
  launchctl bootstrap "gui/${UID_VALUE}" "$PLIST"
  print "Northstar Guard service repaired and reloaded."
  exit 0
fi

command -v clang >/dev/null || {
  print -u2 "clang is required. Install Apple Command Line Tools first: xcode-select --install"
  exit 1
}

install -d "$SUPPORT_DIR" "$REPORTS_DIR" "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$LAUNCH_DIR"

if [[ "$ACTION" == "upgrade" ]]; then
  BACKUP_DIR="$SUPPORT_DIR/backups/$(date +%Y%m%d-%H%M%S)"
  install -d "$BACKUP_DIR"
  for preserved in config.json control.json trusted-known-good.json; do
    [[ -f "$SUPPORT_DIR/$preserved" ]] && cp -p "$SUPPORT_DIR/$preserved" "$BACKUP_DIR/$preserved"
  done
fi

clang -fobjc-arc -O2 -Wall -Wextra -framework Foundation -framework Security \
  "$SCRIPT_DIR/Sources/NorthstarGuard/main.m" \
  -o "$SUPPORT_DIR/northstar-guard"
clang -fobjc-arc -O2 -Wall -Wextra -framework AppKit \
  "$SCRIPT_DIR/Tools/dashboard_launcher.m" \
  -o "$APP_DIR/Contents/MacOS/NorthstarGuardLauncher"

install -m 644 "$SCRIPT_DIR/Assets/NorthstarGuardIcon.icns" "$APP_DIR/Contents/Resources/NorthstarGuardIcon.icns"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleDisplayName</key><string>Northstar Guard</string>
  <key>CFBundleExecutable</key><string>NorthstarGuardLauncher</string>
  <key>CFBundleIconFile</key><string>NorthstarGuardIcon</string>
  <key>CFBundleIdentifier</key><string>com.rowens.northstar-guard.launcher</string>
  <key>CFBundleName</key><string>Northstar Guard</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST

if [[ ! -f "$SUPPORT_DIR/config.json" ]]; then cat > "$SUPPORT_DIR/config.json" <<EOF
{
  "reportsDirectory": "${REPORTS_DIR}"
}
EOF
fi
if [[ ! -f "$SUPPORT_DIR/control.json" ]]; then cat > "$SUPPORT_DIR/control.json" <<'EOF'
{
  "monitoringEnabled": true
}
EOF
fi
print -r -- "$PACKAGE_VERSION" > "$SUPPORT_DIR/agent-version"
if [[ ! -f "$SUPPORT_DIR/agent-id" ]]; then print -r -- "mac-$(scutil --get ComputerName 2>/dev/null | tr '[:upper:] ' '[:lower:]-')-$(uuidgen | tr -d '-' | cut -c1-12)" > "$SUPPORT_DIR/agent-id"; fi
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.rowens.northstar-guard</string>
  <key>ProgramArguments</key><array><string>${SUPPORT_DIR}/northstar-guard</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Background</string>
  <key>Nice</key><integer>10</integer>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>StandardOutPath</key><string>${SUPPORT_DIR}/agent.log</string>
  <key>StandardErrorPath</key><string>${SUPPORT_DIR}/agent-error.log</string>
</dict></plist>
EOF

UID_VALUE="$(id -u)"
launchctl bootout "gui/${UID_VALUE}/com.rowens.northstar-guard" 2>/dev/null || true
launchctl bootstrap "gui/${UID_VALUE}" "$PLIST"
open "$APP_DIR"

print "Northstar Guard ${ACTION} complete (v${PACKAGE_VERSION})."
print "Reports: $REPORTS_DIR"
print "Use the dashboard to pause, start, or request focused/full-scope scans."
