#!/bin/zsh
# Install Northstar Guard from this checked-out repository.
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
SUPPORT_DIR="$HOME/Library/Application Support/NorthstarGuard"
APP_DIR="$HOME/Applications/Northstar Guard.app"
LAUNCH_DIR="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_DIR/com.rowens.northstar-guard.plist"
REPORTS_DIR="${NORTHSTAR_GUARD_REPORT_DIR:-$HOME/NorthstarGuardReports}"

if [[ "${1:-}" == "--reports-dir" ]]; then
  [[ -n "${2:-}" ]] || { print -u2 "Usage: $0 [--reports-dir DIRECTORY]"; exit 64; }
  REPORTS_DIR="$2"
elif [[ -n "${1:-}" ]]; then
  print -u2 "Usage: $0 [--reports-dir DIRECTORY]"
  exit 64
fi

command -v clang >/dev/null || {
  print -u2 "clang is required. Install Apple Command Line Tools first: xcode-select --install"
  exit 1
}

install -d "$SUPPORT_DIR" "$REPORTS_DIR" "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$LAUNCH_DIR"

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

cat > "$SUPPORT_DIR/config.json" <<EOF
{
  "reportsDirectory": "${REPORTS_DIR}"
}
EOF
cat > "$SUPPORT_DIR/control.json" <<'EOF'
{
  "monitoringEnabled": true
}
EOF
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

print "Northstar Guard installed."
print "Reports: $REPORTS_DIR"
print "Use the dashboard to pause, start, or request focused/full-scope scans."
