# Paste everything below into Terminal
/bin/zsh <<'RAYTUNE'
set -euo pipefail

# Make sure this is being run in a real Terminal session
if [[ ! -t 0 || ! -t 1 ]]; then
  echo "Please run this from the macOS Terminal app."
  exit 1
fi

# Make sure this is macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script is for macOS only."
  exit 1
fi

# Optional: warn if this is not an Intel Mac
if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "Warning: this script was tuned for Intel Macs."
  echo "It may still run, but it was written with older Intel Macs in mind."
fi

echo "== macOS tune for older Intel Macs =="

# Keep sudo alive during the run
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

BACKUP_DIR="$HOME/Desktop/macos-intel-tune-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Saving a small before-state report to: $BACKUP_DIR"
{
  echo "### sw_vers"
  sw_vers
  echo
  echo "### model"
  system_profiler SPHardwareDataType | sed -n '1,20p'
  echo
  echo "### pmset -g custom"
  pmset -g custom || true
  echo
  echo "### disk free"
  df -h /
} > "$BACKUP_DIR/before-report.txt"

###############################################################################
# 1) UI / animation / visual overhead
###############################################################################

defaults write com.apple.universalaccess reduceMotion -bool true
defaults write com.apple.universalaccess reduceTransparency -bool true
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain KeyRepeat -int 2

defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

###############################################################################
# 2) Dock / Mission Control / app switching feel
###############################################################################

# Keep Dock visible and leave magnification behavior alone
defaults write com.apple.dock launchanim -bool false
defaults write com.apple.dock expose-animation-duration -float 0.10
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock mineffect -string scale
defaults write com.apple.dock minimize-to-application -bool true
defaults write com.apple.dock mru-spaces -bool false

###############################################################################
# 3) Finder / filesystem niceties
###############################################################################

defaults write com.apple.finder DisableAllAnimations -bool true
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

###############################################################################
# 4) Reopen / restore behavior
###############################################################################

defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool false
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

###############################################################################
# 5) Power management
###############################################################################

sudo pmset -a powernap 0
sudo pmset -a tcpkeepalive 0
sudo pmset -a standby 0
sudo pmset -a autopoweroff 0

###############################################################################
# 6) Faster sleep / wake
###############################################################################

sudo pmset -a hibernatemode 0

###############################################################################
# 7) Gentle maintenance
###############################################################################

killall cfprefsd 2>/dev/null || true
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

###############################################################################
# 8) Friendly report
###############################################################################

echo
echo "Done."
echo
echo "A reboot is recommended."
echo
echo "Before-report saved to:"
echo "  $BACKUP_DIR/before-report.txt"
echo
echo "Current power settings:"
pmset -g custom || true
echo
echo "Disk free:"
df -h /
RAYTUNE