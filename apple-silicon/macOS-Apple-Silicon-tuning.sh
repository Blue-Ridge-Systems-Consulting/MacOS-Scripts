#!/bin/zsh
# Blue Ridge Systems Consulting
# Apple Silicon macOS tuning script
# Turns down unnecessary visual effects while preserving the user's layout,
# Dock visibility, battery behavior, sleep behavior, and personal files.

emulate -L zsh
set -u
set -o pipefail

if [[ ! -t 0 || ! -t 1 ]]; then
  print -u2 "Please run this script from the macOS Terminal app."
  exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 "This script is for macOS only."
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  print -u2 "This script is for Apple Silicon Macs only."
  print -u2 "For an Intel Mac, use the script in the intel folder."
  exit 1
fi

print "== Blue Ridge Apple Silicon macOS tuning =="
print ""
print "This removes unnecessary visual effects and delays."
print "It does NOT hide or rearrange the Dock, alter power management,"
print "delete files, clear caches, or install software."
print ""

BACKUP_DIR="$HOME/Desktop/macos-apple-silicon-tune-backup-$(date +%Y%m%d-%H%M%S)"
PREF_DIR="$BACKUP_DIR/preferences"

if ! mkdir -m 700 "$BACKUP_DIR" || ! mkdir -m 700 "$PREF_DIR"; then
  print -u2 "Could not create a new backup folder. No settings were changed."
  exit 1
fi

print "Saving current settings to:"
print "  $BACKUP_DIR"

if ! {
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
  print "### Power settings (recorded only; not changed)"
  pmset -g custom 2>/dev/null || true
  print ""
  print "### Disk free"
  df -h /
} > "$BACKUP_DIR/before-report.txt"; then
  print -u2 "Could not save the before-state report. No settings were changed."
  exit 1
fi

domain_exists() {
  local domain="$1"
  local domains

  domains="$(defaults domains 2>/dev/null)" || return 2
  awk -v wanted="$domain" '
    BEGIN { RS="," }
    {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      if ($0 == wanted) {
        found=1
        exit
      }
    }
    END { exit(found ? 0 : 1) }
  ' <<< "$domains"
}

backup_domain() {
  local domain="$1"
  local filename="$2"
  local plist="$PREF_DIR/$filename.plist"
  local absent="$PREF_DIR/$filename.absent"

  if defaults export "$domain" "$plist" >/dev/null 2>&1; then
    return 0
  fi

  domain_exists "$domain"
  local domain_status=$?

  if (( domain_status == 1 )); then
    if : > "$absent"; then
      return 0
    fi
  fi

  print -u2 "Could not back up $domain. No settings were changed."
  return 1
}

integer BACKUP_ERRORS=0
backup_domain NSGlobalDomain NSGlobalDomain || (( BACKUP_ERRORS++ ))
backup_domain com.apple.universalaccess com.apple.universalaccess || (( BACKUP_ERRORS++ ))
backup_domain com.apple.dock com.apple.dock || (( BACKUP_ERRORS++ ))
backup_domain com.apple.finder com.apple.finder || (( BACKUP_ERRORS++ ))
backup_domain com.apple.desktopservices com.apple.desktopservices || (( BACKUP_ERRORS++ ))
backup_domain com.apple.Safari com.apple.Safari || (( BACKUP_ERRORS++ ))
backup_domain com.apple.print.PrintingPrefs com.apple.print.PrintingPrefs || (( BACKUP_ERRORS++ ))

if (( BACKUP_ERRORS > 0 )); then
  print -u2 "Backup failed for $BACKUP_ERRORS preference domain(s)."
  print -u2 "No tuning settings were applied. The diagnostic folder is:"
  print -u2 "  $BACKUP_DIR"
  exit 1
fi

cat > "$BACKUP_DIR/restore-settings.sh" <<'RESTORE'
#!/bin/zsh
emulate -L zsh
set -u

SCRIPT_DIR="${0:A:h}"
PREF_DIR="$SCRIPT_DIR/preferences"
integer RESTORE_ERRORS=0

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 "This restore script is for macOS only."
  exit 1
fi

restore_domain() {
  local domain="$1"
  local filename="$2"
  local source="$PREF_DIR/$filename.plist"
  local absent="$PREF_DIR/$filename.absent"

  if [[ -f "$source" ]]; then
    if defaults import "$domain" "$source" >/dev/null 2>&1; then
      print "Restored $domain"
    else
      print -u2 "Could not restore $domain"
      (( RESTORE_ERRORS++ ))
    fi
  elif [[ -f "$absent" ]]; then
    if ! defaults read "$domain" >/dev/null 2>&1 ||
        defaults delete "$domain" >/dev/null 2>&1; then
      print "Restored $domain (absent before tuning)"
    else
      print -u2 "Could not remove $domain"
      (( RESTORE_ERRORS++ ))
    fi
  else
    print -u2 "Missing backup data for $domain"
    (( RESTORE_ERRORS++ ))
  fi
}

print "Restoring the preferences saved before Apple Silicon tuning..."
restore_domain NSGlobalDomain NSGlobalDomain
restore_domain com.apple.universalaccess com.apple.universalaccess
restore_domain com.apple.dock com.apple.dock
restore_domain com.apple.finder com.apple.finder
restore_domain com.apple.desktopservices com.apple.desktopservices
restore_domain com.apple.Safari com.apple.Safari
restore_domain com.apple.print.PrintingPrefs com.apple.print.PrintingPrefs

killall cfprefsd 2>/dev/null || true
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

print ""
if (( RESTORE_ERRORS > 0 )); then
  print -u2 "Restore finished with $RESTORE_ERRORS error(s). Review the messages above."
  exit 1
fi

print "Restore complete. Log out and back in, or restart the Mac, to finish."
RESTORE
if [[ ! -s "$BACKUP_DIR/restore-settings.sh" ]] ||
    ! /bin/zsh -n "$BACKUP_DIR/restore-settings.sh" ||
    ! chmod +x "$BACKUP_DIR/restore-settings.sh"; then
  print -u2 "Could not create a valid restore script. No settings were changed."
  exit 1
fi

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

print ""
print "Turning off the Hollywood glimmer..."

# Accessibility and global animation overhead
apply_pref "Reduce motion" defaults write com.apple.universalaccess reduceMotion -bool true
apply_pref "Reduce transparency" defaults write com.apple.universalaccess reduceTransparency -bool true
apply_pref "Disable automatic window animations" defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
apply_pref "Disable smooth scrolling animation" defaults write NSGlobalDomain NSScrollAnimationEnabled -bool false
apply_pref "Shorten window resize animation" defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
apply_pref "Disable animated focus rings" defaults write NSGlobalDomain NSUseAnimatedFocusRing -bool false
apply_pref "Disable document revision animation" defaults write NSGlobalDomain NSDocumentRevisionsWindowTransformAnimation -bool false

# Keyboard responsiveness
apply_pref "Use key repeat instead of press-and-hold accents" defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
apply_pref "Shorten initial key-repeat delay" defaults write NSGlobalDomain InitialKeyRepeat -int 15
apply_pref "Speed up key repeat" defaults write NSGlobalDomain KeyRepeat -int 2

# Dock and Mission Control feel
# Deliberately do not touch autohide, orientation, size, magnification, or pinned items.
apply_pref "Disable Dock app-launch animation" defaults write com.apple.dock launchanim -bool false
apply_pref "Shorten Mission Control animation" defaults write com.apple.dock expose-animation-duration -float 0.10
apply_pref "Use the simpler scale minimize effect" defaults write com.apple.dock mineffect -string scale
apply_pref "Minimize windows into their application icon" defaults write com.apple.dock minimize-to-application -bool true
apply_pref "Keep Spaces in a stable order" defaults write com.apple.dock mru-spaces -bool false
apply_pref "Remove suggested and recent apps from the Dock" defaults write com.apple.dock show-recents -bool false

# Finder and filesystem behavior
apply_pref "Disable Finder animations" defaults write com.apple.finder DisableAllAnimations -bool true
apply_pref "Show all filename extensions" defaults write NSGlobalDomain AppleShowAllExtensions -bool true
apply_pref "Stop warning when changing a filename extension" defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
apply_pref "Avoid .DS_Store files on network shares" defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
apply_pref "Avoid .DS_Store files on USB drives" defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Practical behavior without redesigning the Mac
apply_pref "Do not reopen every window when quitting an app" defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool false
apply_pref "Do not auto-open downloaded safe files in Safari" defaults write com.apple.Safari AutoOpenSafeDownloads -bool false
apply_pref "Quit the printer app after jobs finish" defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

killall cfprefsd 2>/dev/null || true
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

print ""
print "Done. Applied: $APPLIED   Skipped: $SKIPPED"
print ""
print "The Dock's visibility, position, size, magnification, and pinned items were left alone."
print "Apple Silicon power, battery, standby, and sleep settings were left alone."
print ""
print "Your before-state report and restore script are here:"
print "  $BACKUP_DIR"
print ""
print "Log out and back in, or restart the Mac, so every application reloads its settings."
