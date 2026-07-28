#!/bin/zsh
# Blue Ridge Systems Consulting
# Intel macOS restore helper
#
# This helper locates a backup created by macOS-intel-tuning.sh and runs the
# complete restore-settings.sh stored inside it.
#
# Usage:
#   ./macOS-intel-restore.sh
#   ./macOS-intel-restore.sh /path/to/macos-intel-tune-backup-YYYYMMDD-HHMMSS

emulate -L zsh
set -u
set -o pipefail

if [[ ! -t 0 || ! -t 1 ]]; then
  print -u2 "Please run this from the macOS Terminal app."
  exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 "This restore helper is for macOS only."
  exit 1
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
  print -u2 "This restore helper is for Intel Macs only."
  exit 1
fi

BACKUP_DIR="${1:-}"

if [[ -z "$BACKUP_DIR" ]]; then
  typeset -a backups
  backups=("$HOME"/Desktop/macos-intel-tune-backup-*(N.om))

  if (( ${#backups[@]} == 0 )); then
    print -u2 "No Intel tuning backup folders were found on the Desktop."
    print -u2 "Pass a backup folder explicitly if it was moved:"
    print -u2 "  /bin/zsh macOS-intel-restore.sh /path/to/backup-folder"
    exit 1
  fi

  BACKUP_DIR="${backups[1]}"
fi

BACKUP_DIR="${BACKUP_DIR:A}"
RESTORE_SCRIPT="$BACKUP_DIR/restore-settings.sh"

if [[ ! -d "$BACKUP_DIR" ]]; then
  print -u2 "Backup folder not found:"
  print -u2 "  $BACKUP_DIR"
  exit 1
fi

if [[ ! -f "$RESTORE_SCRIPT" ]]; then
  print -u2 "This folder does not contain restore-settings.sh:"
  print -u2 "  $BACKUP_DIR"
  print -u2 "Only backups created by the updated Intel tuning script can be restored automatically."
  exit 1
fi

print "Intel tuning backup selected:"
print "  $BACKUP_DIR"
print ""
print "This will restore the saved preferences and the exact battery/AC power settings."
print -n "Continue? [y/N] "
read -r answer

case "$answer" in
  y|Y|yes|YES|Yes)
    /bin/zsh "$RESTORE_SCRIPT"
    ;;
  *)
    print "Restore cancelled."
    exit 0
    ;;
esac
