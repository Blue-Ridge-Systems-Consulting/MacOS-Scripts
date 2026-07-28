#!/bin/zsh
# Blue Ridge Systems Consulting
# macOS Intel tuning script
#
# Run directly with:
#   chmod +x macOS-intel-tuning.sh
#   ./macOS-intel-tuning.sh

emulate -L zsh
set -u
set -o pipefail

###############################################################################
# Validation
###############################################################################

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
  print -u2 "For Apple Silicon, use the script in the apple-silicon folder."
  exit 1
fi

print "== Blue Ridge macOS tune for older Intel Macs =="
print ""
print "This reduces visual overhead and adjusts older Intel power settings."
print "It does not hide or rearrange the Dock, delete files, or install software."
print ""

###############################################################################
# Administrator access and before-state backup
###############################################################################

sudo -v || exit 1
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
 done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT INT TERM

BACKUP_DIR="$HOME/Desktop/macos-intel-tune-backup-$(date +%Y%m%d-%H%M%S)"
PREF_DIR="$BACKUP_DIR/preferences"
mkdir -p "$PREF_DIR"

print "Saving current settings to:"
print "  $BACKUP_DIR"

{
  print "### Date"
  date
  print ""
  print "### macOS"
  sw_vers
  print ""
  print "### Hardware"
  system_profiler SPHardwareDataType 2>/dev/null | sed -n '1,24p'
  print ""
  print "### Architecture"
  uname -m
  print ""
  print "### Dock visibility before tuning"
  defaults read com.apple.dock autohide 2>/dev/null || print "Not explicitly set"
  print ""
  print "### Power settings before tuning"
  pmset -g custom 2>/dev/null || true
  print ""
  print "### Disk free"
  df -h /
} > "$BACKUP_DIR/before-report.txt"

backup_domain() {
  local domain="$1"
  local filename="$2"
  defaults export "$domain" "$PREF_DIR/$filename.plist" >/dev/null 2>&1 || true
}

backup_current_host_domain() {
  local domain="$1"
  local filename="$2"
  defaults -currentHost export "$domain" "$PREF_DIR/$filename.plist" >/dev/null 2>&1 || true
}

backup_domain NSGlobalDomain NSGlobalDomain
backup_domain com.apple.universalaccess com.apple.universalaccess
backup_domain com.apple.dock com.apple.dock
backup_domain com.apple.finder com.apple.finder
backup_domain com.apple.desktopservices com.apple.desktopservices
backup_domain com.apple.Safari com.apple.Safari
backup_domain com.apple.print.PrintingPrefs com.apple.print.PrintingPrefs
backup_current_host_domain com.apple.ImageCapture com.apple.ImageCapture-currentHost

###############################################################################
# Capture the exact power values changed by this script
###############################################################################

PMSET_REPORT="$BACKUP_DIR/pmset-before.txt"
pmset -g custom > "$PMSET_REPORT" 2>/dev/null || true

pm_value() {
  local section="$1"
  local key="$2"

  awk -v section="$section" -v key="$key" '
    $0 ~ "^" section ":" { active=1; next }
    /^[^[:space:]].*:$/ { active=0 }
    active && $1 == key { print $2; exit }
  ' "$PMSET_REPORT"
}

write_pm_restore() {
  local mode="$1"
  local section="$2"
  local key value
  local -a keys=(powernap tcpkeepalive standby autopoweroff hibernatemode)

  for key in "${keys[@]}"; do
    value="$(pm_value "$section" "$key")"
    if [[ -n "$value" ]]; then
      print "sudo pmset $mode $key $value" >> "$BACKUP_DIR/restore-power-settings.sh"
    fi
  done
}

cat > "$BACKUP_DIR/restore-power-settings.sh" <<'POWERRESTORE'
#!/bin/zsh
emulate -L zsh
set -u

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 "This restore script is for macOS only."
  exit 1
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
  print -u2 "This restore script is for Intel Macs only."
  exit 1
fi

sudo -v || exit 1
print "Restoring the Intel Mac power settings saved before tuning..."
POWERRESTORE

write_pm_restore -b "Battery Power"
write_pm_restore -c "AC Power"
write_pm_restore -u "UPS Power"

cat >> "$BACKUP_DIR/restore-power-settings.sh" <<'POWERRESTORE'
print "Power settings restored."
pmset -g custom || true
POWERRESTORE
chmod +x "$BACKUP_DIR/restore-power-settings.sh"

###############################################################################
# Generate the complete restore script
###############################################################################

cat > "$BACKUP_DIR/restore-settings.sh" <<'RESTORE'
#!/bin/zsh
emulate -L zsh
set -u
set -o pipefail

SCRIPT_DIR="${0:A:h}"
PREF_DIR="$SCRIPT_DIR/preferences"

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 "This restore script is for macOS only."
  exit 1
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
  print -u2 "This restore script is for Intel Macs only."
  exit 1
fi

restore_domain() {
  local domain="$1"
  local filename="$2"
  local source="$PREF_DIR/$filename.plist"

  if [[ -f "$source" ]]; then
    if defaults import "$domain" "$source" >/dev/null 2>&1; then
      print "  [restored] $domain"
    else
      print -u2 "  [warning] Could not restore $domain"
    fi
  fi
}

restore_current_host_domain() {
  local domain="$1"
  local filename="$2"
  local source="$PREF_DIR/$filename.plist"

  if [[ -f "$source" ]]; then
    if defaults -currentHost import "$domain" "$source" >/dev/null 2>&1; then
      print "  [restored] $domain (current host)"
    else
      print -u2 "  [warning] Could not restore $domain (current host)"
    fi
  fi
}

print "Restoring the preferences saved before Intel tuning..."
restore_domain NSGlobalDomain NSGlobalDomain
restore_domain com.apple.universalaccess com.apple.universalaccess
restore_domain com.apple.dock com.apple.dock
restore_domain com.apple.finder com.apple.finder
restore_domain com.apple.desktopservices com.apple.desktopservices
restore_domain com.apple.Safari com.apple.Safari
restore_domain com.apple.print.PrintingPrefs com.apple.print.PrintingPrefs
restore_current_host_domain com.apple.ImageCapture com.apple.ImageCapture-currentHost

if [[ -x "$SCRIPT_DIR/restore-power-settings.sh" ]]; then
  "$SCRIPT_DIR/restore-power-settings.sh"
else
  print -u2 "Warning: restore-power-settings.sh was not found."
fi

killall cfprefsd 2>/dev/null || true
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

print ""
print "Restore complete. Log out and back in, or restart the Mac, to finish."
RESTORE
chmod +x "$BACKUP_DIR/restore-settings.sh"

###############################################################################
# Apply tuning
###############################################################################

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

apply_power() {
  local description="$1"
  shift

  if sudo "$@" >/dev/null 2>&1; then
    print "  [done] $description"
    (( APPLIED++ ))
  else
    print "  [skip] $description"
    (( SKIPPED++ ))
  fi
}

print ""
print "Turning off unnecessary visual overhead..."

apply_pref "Reduce motion" defaults write com.apple.universalaccess reduceMotion -bool true
apply_pref "Reduce transparency" defaults write com.apple.universalaccess reduceTransparency -bool true
apply_pref "Shorten window resize animation" defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

apply_pref "Use key repeat instead of press-and-hold accents" defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
apply_pref "Shorten initial key-repeat delay" defaults write NSGlobalDomain InitialKeyRepeat -int 15
apply_pref "Speed up key repeat" defaults write NSGlobalDomain KeyRepeat -int 2

apply_pref "Disable automatic spelling correction" defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
apply_pref "Disable automatic capitalization" defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
apply_pref "Disable smart quote substitution" defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
apply_pref "Disable smart dash substitution" defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
apply_pref "Disable automatic period substitution" defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Deliberately do not touch Dock autohide, orientation, size, magnification, or contents.
apply_pref "Disable Dock app-launch animation" defaults write com.apple.dock launchanim -bool false
apply_pref "Shorten Mission Control animation" defaults write com.apple.dock expose-animation-duration -float 0.10
apply_pref "Remove suggested and recent apps from the Dock" defaults write com.apple.dock show-recents -bool false
apply_pref "Use the simpler scale minimize effect" defaults write com.apple.dock mineffect -string scale
apply_pref "Minimize windows into their application icon" defaults write com.apple.dock minimize-to-application -bool true
apply_pref "Keep Spaces in a stable order" defaults write com.apple.dock mru-spaces -bool false

apply_pref "Disable Finder animations" defaults write com.apple.finder DisableAllAnimations -bool true
apply_pref "Stop warning when changing a filename extension" defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
apply_pref "Show all filename extensions" defaults write NSGlobalDomain AppleShowAllExtensions -bool true
apply_pref "Avoid .DS_Store files on network shares" defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
apply_pref "Avoid .DS_Store files on USB drives" defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

apply_pref "Do not reopen every window when quitting an app" defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool false
apply_pref "Do not auto-open downloaded safe files in Safari" defaults write com.apple.Safari AutoOpenSafeDownloads -bool false
apply_pref "Quit the printer app after jobs finish" defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true
apply_pref "Do not open Image Capture automatically" defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

print ""
print "Adjusting older Intel Mac power behavior..."
apply_power "Disable Power Nap" pmset -a powernap 0
apply_power "Disable sleep TCP keepalive" pmset -a tcpkeepalive 0
apply_power "Disable standby transition" pmset -a standby 0
apply_power "Disable automatic hibernation power-off" pmset -a autopoweroff 0
apply_power "Use memory-only sleep" pmset -a hibernatemode 0

killall cfprefsd 2>/dev/null || true
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

print ""
print "Done. Applied: $APPLIED   Skipped: $SKIPPED"
print ""
print "The Dock's visibility, position, size, magnification, and contents were left alone."
print ""
print "Your before-state report and complete restore scripts are here:"
print "  $BACKUP_DIR"
print ""
print "To undo every saved change later, run:"
print "  /bin/zsh \"$BACKUP_DIR/restore-settings.sh\""
print ""
print "A restart is recommended."
