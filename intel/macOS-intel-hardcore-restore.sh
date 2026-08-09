#!/bin/zsh
# Blue Ridge Systems Consulting
# Roll back the macOS Intel Hardcore tuning profile.
#
# Usage:
#   chmod +x macOS-intel-hardcore-restore.sh
#   ./macOS-intel-hardcore-restore.sh ~/Desktop/macos-intel-hardcore-backup-YYYYMMDD-HHMMSS

emulate -L zsh
set -u
set -o pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 "This script is for macOS only."
  exit 1
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
  print -u2 "This script is for Intel Macs only."
  exit 1
fi

if (( $# != 1 )); then
  print -u2 "Usage: $0 /path/to/macos-intel-hardcore-backup-YYYYMMDD-HHMMSS"
  exit 1
fi

BACKUP_DIR="${1:A}"
if [[ ! -d "$BACKUP_DIR" ]]; then
  print -u2 "Backup directory not found: $BACKUP_DIR"
  exit 1
fi

sudo -v || exit 1
integer ERRORS=0

print "============================================================"
print " Blue Ridge macOS Intel HARDCORE Rollback"
print "============================================================"
print ""
print "Restoring saved preferences and power values from:"
print "  $BACKUP_DIR"
print ""

restore_domain() {
  local domain="$1"
  local file="$2"
  if [[ -s "$file" ]]; then
    if defaults import "$domain" "$file" >/dev/null 2>&1; then
      print "  [restored] $domain"
    else
      print -u2 "  [warning] Could not restore $domain"
      (( ERRORS++ ))
    fi
  else
    print "  [info] No saved plist for $domain"
  fi
}

restore_domain NSGlobalDomain "$BACKUP_DIR/NSGlobalDomain.plist"
restore_domain com.apple.dock "$BACKUP_DIR/com.apple.dock.plist"
restore_domain com.apple.finder "$BACKUP_DIR/com.apple.finder.plist"

PMSET_REPORT="$BACKUP_DIR/pmset-before.txt"
pm_value() {
  local section="$1"
  local key="$2"
  awk -v section="$section" -v key="$key" '
    $0 ~ "^[[:space:]]*" section ":[[:space:]]*$" { active=1; next }
    /^[[:space:]]*[^[:space:]].*:[[:space:]]*$/ { active=0 }
    active && $1 == key { print $2; exit }
  ' "$PMSET_REPORT"
}

restore_pm_key() {
  local mode="$1"
  local section="$2"
  local key="$3"
  local value
  value="$(pm_value "$section" "$key")"
  if [[ -n "$value" ]]; then
    if sudo pmset "$mode" "$key" "$value" >/dev/null 2>&1; then
      print "  [restored] $mode $key=$value"
    else
      print -u2 "  [warning] Could not restore $mode $key=$value"
      (( ERRORS++ ))
    fi
  fi
}

if [[ -s "$PMSET_REPORT" ]]; then
  print ""
  print "Restoring saved power settings..."
  for key in powernap tcpkeepalive standby autopoweroff hibernatemode sleep displaysleep lidwake womp; do
    restore_pm_key -b "Battery Power" "$key"
    restore_pm_key -c "AC Power" "$key"
    restore_pm_key -u "UPS Power" "$key"
  done
else
  print -u2 "Warning: pmset-before.txt is missing; power settings cannot be restored automatically."
  (( ERRORS++ ))
fi

print ""
print "Re-enabling Spotlight indexing for known paths if present..."
for path in \
  "$HOME/Library/Caches" \
  "$HOME/.cache" \
  "$HOME/.Trash" \
  "$HOME/Library/Containers/com.docker.docker" \
  "$HOME/.local/share/containers" \
  "$HOME/Virtual Machines.localized" \
  "$HOME/Parallels" \
  "$HOME/VMware"; do
  if [[ -e "$path" ]]; then
    sudo mdutil -i on "$path" >/dev/null 2>&1 || true
  fi
done

killall cfprefsd 2>/dev/null || true
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

print ""
if (( ERRORS > 0 )); then
  print -u2 "Rollback finished with $ERRORS warning/error(s)."
  print -u2 "Review the messages above, then restart the Mac."
  exit 1
fi

print "Rollback complete. Restart the Mac to finish."
