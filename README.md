<p align="center">
  <img src="assets/blue-ridge-systems-consulting-logo.svg" alt="Blue Ridge Systems Consulting Logo" width="160" />
</p>

# Blue Ridge macOS Scripts

[![macOS](https://img.shields.io/badge/Optimized%20for-macOS-000000?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos/)

## Turn Off the Hollywood Glimmer and Turn Your Mac Back Into a Computer

This repository contains separate, conservative tuning setups for Apple Silicon Macs and older Intel Macs.

The goal is simple: reduce unnecessary animation, transparency, visual delay, and distracting behavior without redesigning the Mac, deleting personal files, installing cleanup software, or pretending macOS needs magic optimization.

## Choose Your Mac

### Apple Silicon Macs

For Macs with an M-series processor, use the files in [`apple-silicon/`](apple-silicon/).

- [`macOS-Apple-Silicon-tuning.txt`](apple-silicon/macOS-Apple-Silicon-tuning.txt)  
  Easiest method. Copy the command, paste it into Terminal, and press Return.

- [`macOS-Apple-Silicon-tuning.sh`](apple-silicon/macOS-Apple-Silicon-tuning.sh)  
  Traditional script for users who prefer to download, inspect, and run it directly.

The Apple Silicon version deliberately leaves the following alone:

- Dock visibility, position, size, magnification, and pinned items
- Battery charging behavior
- Standby, hibernation, and sleep behavior
- Personal files and installed applications
- Wallpaper, accent color, Stage Manager, and desktop layout

Before changing preferences, it saves a before-state report, exports the affected preference domains, and creates a restore script inside a dated backup folder on the Desktop.

### Older Intel Macs

For Intel-based Macs, use the files in [`intel/`](intel/).

- [`macOS-intel-tuning-paste.txt`](intel/macOS-intel-tuning-paste.txt)  
  Easiest method. Copy the command, paste it into Terminal, and press Return.

- [`macOS-intel-tuning.sh`](intel/macOS-intel-tuning.sh)  
  Traditional script for users who prefer to download, inspect, and run it directly.

- [`macOS-intel-restore.sh`](intel/macOS-intel-restore.sh)  
  Restore helper that locates the newest compatible Intel tuning backup and runs its saved restore process.

The Intel setup was inspired by the difference it made on a 2015 Intel MacBook Pro, where it helped the machine feel dramatically more responsive in everyday use.

Unlike the Apple Silicon version, the Intel script also adjusts a small set of older Intel-oriented power settings. Before doing so, the revised script now saves the exact Battery and AC values so they can be restored later.

The Intel script intentionally uses memory-only sleep. On a notebook, an empty battery or other loss of power while the Mac is asleep can therefore lose the open session. This is the responsiveness-versus-protection tradeoff behind the aggressive Intel setup.

## Apple Silicon Quick Start

1. Open [`apple-silicon/macOS-Apple-Silicon-tuning.txt`](apple-silicon/macOS-Apple-Silicon-tuning.txt)
2. Copy the Terminal command
3. Open the Terminal app on the Mac
4. Paste the command and press Return
5. Review the completion report
6. Log out and back in, or restart the Mac

## Intel Quick Start

1. Open [`intel/macOS-intel-tuning-paste.txt`](intel/macOS-intel-tuning-paste.txt)
2. Copy the Terminal command
3. Open the Terminal app on the Mac
4. Paste the command and press Return
5. Review the completion report
6. Restart the Mac

## Before You Begin

Create a Time Machine backup before making system changes.

The built-in restore packages are useful for reversing the settings changed by these scripts, but they are not substitutes for a full backup. Time Machine protects personal files, applications, system state, and other settings outside the scope of these tuning scripts.

Each tuning run creates a dated backup folder on the Desktop before applying changes.

Typical folder names are:

```text
macos-apple-silicon-tune-backup-YYYYMMDD-HHMMSS
macos-intel-tune-backup-YYYYMMDD-HHMMSS
```

Keep that folder until you are satisfied with the results.

## What These Scripts Do

Depending on the Mac, the scripts adjust a conservative collection of settings related to responsiveness and everyday usability:

- Reduce motion, transparency, and animation overhead
- Tighten Dock, Mission Control, Finder, and keyboard behavior
- Show filename extensions and simplify common Finder behavior
- Reduce unnecessary reopen and auto-launch behavior
- Save a before-state report before making changes
- Export affected preferences for later restoration

The Apple Silicon version does not alter power-management settings.

The Intel version also adjusts these older Intel-oriented power settings:

- Power Nap
- TCP keepalive during sleep
- Standby
- Automatic power-off sleep behavior
- Hibernation mode

The exact pre-tuning Battery and AC values are saved before those changes are applied.

## Restoring Apple Silicon Settings

The Apple Silicon tuning script creates this file inside its Desktop backup folder:

```text
restore-settings.sh
```

To restore the saved preferences:

```zsh
/bin/zsh "$HOME/Desktop/macos-apple-silicon-tune-backup-YYYYMMDD-HHMMSS/restore-settings.sh"
```

Replace the example folder name with the actual backup folder created during the tuning run.

The restore script imports the saved preference domains and restarts the affected macOS preference services. Log out and back in, or restart the Mac, after restoring.

Restoration returns each affected preference domain to its saved before-state. Any changes made later in those same domains are also rolled back.

## Restoring Intel Settings

The revised Intel tuning script creates a complete restore package containing:

```text
before-report.txt
pmset-before.txt
preferences/
restore-settings.sh
restore-power-settings.sh
```

The easiest restore method is:

```zsh
chmod +x intel/macOS-intel-restore.sh
./intel/macOS-intel-restore.sh
```

The helper selects the newest compatible Intel backup folder on the Desktop and asks for confirmation before restoring it.

You can also select a specific backup folder:

```zsh
./intel/macOS-intel-restore.sh \
  "$HOME/Desktop/macos-intel-tune-backup-YYYYMMDD-HHMMSS"
```

The Intel restore process puts back the saved preference domains and the exact Battery and AC power settings recorded before tuning.

### Older Intel Backups

Backups created by earlier revisions of the Intel script only contain a text before-state report. Those older folders do not contain the exported preferences or generated restore scripts required for a complete automatic restore.

That is one reason a Time Machine backup remains strongly recommended.

## What These Scripts Do Not Do

They do not:

- Delete personal files
- Uninstall applications
- Install third-party software
- Clear caches as a fake performance cure
- Scrape personal data
- Hide or rearrange the Dock
- Change the Dock position, size, magnification, or pinned items
- Replace normal maintenance, hardware repair, or a full backup when those are actually needed

## Important Note

These scripts change macOS preferences. The Intel version also changes selected power-management values.

Review the script intended for your Mac before running it, keep the generated backup folder, and use the scripts only if you are comfortable making those changes.

## Why I Am Sharing It

A good machine does not always need to be replaced. Sometimes it just needs the unnecessary pageantry turned down so it can get back to being a computer.

## Branding

This repository includes Blue Ridge Systems Consulting branding assets. See [`BRANDING.md`](BRANDING.md) for logo and brand usage guidance.

## Security

<a href="https://app.aikido.dev/audit-report/external/WUuAYeTGe5MdKOz7TJTyBMJl/request" target="_blank">
    <img src="https://app.aikido.dev/assets/badges/full-light-theme.svg" alt="Aikido Security Audit Report" height="40" />    
</a>

This repository is scanned with Aikido Security as part of a basic code safety check. As with any script, you should still review the contents yourself before running it.
