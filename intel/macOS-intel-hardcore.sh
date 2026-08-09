#!/bin/zsh
# Blue Ridge Systems Consulting
# macOS Intel Hardcore tuning profile
#
# Designed for older Intel MacBook Pro systems running their natively supported macOS.
# This is an additive performance layer intended to be used after macOS-intel-tuning.sh.
# It does NOT disable SIP, Gatekeeper, FileVault, swap, memory compression, or Apple security services.

emulate -L zsh
set -u
set -o pipefail

if [[ ! -t 0 || ! -t 1 ]]; then
  print -u2 "Please run this from the macOS Terminal app."
  exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 "This script is for macOS only."
  exit 1
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
  print -u2 "This script is for Intel Macs only."
  exit 1
fi

print "============================================================"
print " Blue Ridge macOS Intel HARDCORE Tune"
print "============================================================"
print ""
print "This profile pushes an older Intel Mac harder while keeping"
print "Apple security protections and system integrity intact."
print ""

sudo -v || exit 1
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
 done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
cleanup_sudo_keepalive() {
  kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}
trap cleanup_sudo_keepalive EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

BACKUP_DIR="$HOME/Desktop/macos-intel-hardcore-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -m 700 "$BACKUP_DIR" || exit 1

print "Saving before-state to:"
print "  $BACKUP_DIR"
print ""

{
  print "### Date"
  date
  print ""
  print "### macOS"
  sw_vers
  print ""
  print "### Hardware"
  system_profiler SPHardwareDataType 2>/dev/null | sed -n '1,30p'
  print ""
  print "### Storage"
  df -h /
  print ""
  print "### Power"
  pmset -g custom 2>/dev/null || true
  print ""
  print "### Thermal"
  pmset -g therm 2>/dev/null || true
  print ""
  print "### Memory pressure"
  memory_pressure 2>/dev/null || true
  print ""
  print "### SIP"
  csrutil status 2>/dev/null || true
  print ""
  print "### Gatekeeper"
  spctl --status 2>/dev/null || true
  print ""
  print "### FileVault"
  fdesetup status 2>/dev/null || true
  print ""
  print "### Spotlight root status"
  mdutil -s / 2>/dev/null || true
  print ""
  print "### Login/background launch agents"
  find "$HOME/Library/LaunchAgents" /Library/LaunchAgents /Library/LaunchDaemons \
    -maxdepth 1 -type f -name '*.plist' -print 2>/dev/null | sort || true
} > "$BACKUP_DIR/before-report.txt"

# Save preference domains touched by this profile.
defaults export NSGlobalDomain "$BACKUP_DIR/NSGlobalDomain.plist" >/dev/null 2>&1 || true
defaults export com.apple.dock "$BACKUP_DIR/com.apple.dock.plist" >/dev/null 2>&1 || true
defaults export com.apple.finder "$BACKUP_DIR/com.apple.finder.plist" >/dev/null 2>&1 || true

# Save power settings exactly as they were.
pmset -g custom > "$BACKUP_DIR/pmset-before.txt" 2>/dev/null || true

integer APPLIED=0
integer SKIPPED=0

apply_pref() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    print "  [done] $description"
    (( APPLIED++ ))
  else
    print "  [skip] $description"
    (( SKIPPED++ ))
  fi
}

apply_pm() {
  local description="$1"
  shift
  if sudo pmset "$@" >/dev/null 2>&1; then
    print "  [done] $description"
    (( APPLIED++ ))
  else
    print "  [skip] $description"
    (( SKIPPED++ ))
  fi
}

print "== UI responsiveness =="
apply_pref "Eliminate window resize animation" defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
apply_pref "Disable automatic window animations" defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
apply_pref "Disable Quick Look panel animation" defaults write NSGlobalDomain QLPanelAnimationDuration -float 0
apply_pref "Make sheet dialogs nearly instant" defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
apply_pref "Disable Dock launch animation" defaults write com.apple.dock launchanim -bool false
apply_pref "Make Mission Control nearly instant" defaults write com.apple.dock expose-animation-duration -float 0.05
apply_pref "Disable Finder animations" defaults write com.apple.finder DisableAllAnimations -bool true

print ""
print "== Desktop/workstation power profile =="
# AC power is tuned aggressively. Battery remains much closer to normal laptop behavior.
apply_pm "Disable Power Nap on AC" -c powernap 0
apply_pm "Disable TCP keepalive during sleep on AC" -c tcpkeepalive 0
apply_pm "Disable standby transition on AC" -c standby 0
apply_pm "Disable automatic hibernation power-off on AC" -c autopoweroff 0
apply_pm "Use RAM-only sleep on AC" -c hibernatemode 0
apply_pm "Prevent system sleep while plugged in" -c sleep 0
apply_pm "Keep display sleep at 20 minutes on AC" -c displaysleep 20
apply_pm "Wake when lid is opened" -a lidwake 1
apply_pm "Wake for network access on AC" -c womp 1

print ""
print "== Battery sanity profile =="
# Keep battery use portable rather than applying the desktop profile everywhere.
apply_pm "Allow normal battery system sleep" -b sleep 10
apply_pm "Allow display sleep after 5 minutes on battery" -b displaysleep 5
apply_pm "Disable Power Nap on battery" -b powernap 0
apply_pm "Disable network keepalive during battery sleep" -b tcpkeepalive 0

print ""
print "== Spotlight strategy =="
# Keep Spotlight itself working, but exclude high-churn directories if they exist.
integer SPOTLIGHT_EXCLUDES=0
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
    if sudo mdutil -i off "$path" >/dev/null 2>&1; then
      print "  [done] Excluded indexing for $path"
      (( SPOTLIGHT_EXCLUDES++ ))
      (( APPLIED++ ))
    else
      print "  [skip] Could not change Spotlight indexing for $path"
      (( SKIPPED++ ))
    fi
  fi
done
if (( SPOTLIGHT_EXCLUDES == 0 )); then
  print "  [info] No known high-churn VM/container/cache volumes required exclusion"
fi

print ""
print "== Maintenance =="
# Remove user cache contents only. Do not touch system caches or application data.
if [[ -d "$HOME/Library/Caches" ]]; then
  find "$HOME/Library/Caches" -mindepth 1 -maxdepth 1 -type d -mtime +14 -exec rm -rf {} + 2>/dev/null || true
  print "  [done] Removed stale top-level user cache directories older than 14 days where permitted"
  (( APPLIED++ ))
fi

# Thin local Time Machine snapshots only when they exist and disk pressure is meaningful.
FREE_PCT=$(df -k / | awk 'NR==2 {gsub(/%/,"",$5); print 100-$5}')
if [[ -n "$FREE_PCT" && "$FREE_PCT" -lt 15 ]]; then
  if tmutil listlocalsnapshots / 2>/dev/null | grep -q 'com.apple.TimeMachine'; then
    if sudo tmutil thinlocalsnapshots / 20000000000 4 >/dev/null 2>&1; then
      print "  [done] Thinned local Time Machine snapshots because free space is below 15%"
      (( APPLIED++ ))
    else
      print "  [skip] Could not thin local Time Machine snapshots"
      (( SKIPPED++ ))
    fi
  fi
else
  print "  [info] Disk free space is healthy; local snapshots left alone"
fi

print ""
print "== Background workload inventory =="
{
  print "### User LaunchAgents"
  ls -1 "$HOME/Library/LaunchAgents" 2>/dev/null || true
  print ""
  print "### System LaunchAgents"
  ls -1 /Library/LaunchAgents 2>/dev/null || true
  print ""
  print "### System LaunchDaemons"
  ls -1 /Library/LaunchDaemons 2>/dev/null || true
  print ""
  print "### Top CPU processes"
  ps -Ao pid,ppid,%cpu,%mem,comm -r | head -20
  print ""
  print "### Top memory processes"
  ps -Ao pid,ppid,%cpu,%mem,comm -m | head -20
} > "$BACKUP_DIR/background-audit.txt"
print "  [done] Background workload audit saved"
(( APPLIED++ ))

print ""
print "== Thermal and storage diagnostics =="
{
  print "### Thermal status"
  pmset -g therm 2>/dev/null || true
  print ""
  print "### Disk"
  diskutil info / 2>/dev/null || true
  print ""
  print "### APFS snapshots"
  diskutil apfs listSnapshots / 2>/dev/null || true
  print ""
  print "### Memory pressure"
  memory_pressure 2>/dev/null || true
} > "$BACKUP_DIR/hardcore-diagnostics.txt"
print "  [done] Thermal/storage/memory diagnostics saved"
(( APPLIED++ ))

killall cfprefsd 2>/dev/null || true
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

print ""
print "============================================================"
print " HARDCORE tune complete"
print "============================================================"
print "Applied: $APPLIED   Skipped: $SKIPPED"
print ""
print "Backups and diagnostics:"
print "  $BACKUP_DIR"
print ""
print "This profile deliberately left SIP, Gatekeeper, FileVault, swap,"
print "memory compression, and Apple security services enabled."
print ""
print "A restart is recommended."
