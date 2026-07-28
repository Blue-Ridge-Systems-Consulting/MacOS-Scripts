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

- Dock visibility, position, size, magnification, and contents
- Battery charging behavior
- Standby, hibernation, and sleep behavior
- Personal files and installed applications
- Wallpaper, accent color, Stage Manager, and desktop layout

Before changing preferences, it saves a before-state report, exports the affected preference domains, and creates a restore script on the Desktop.

### Older Intel Macs

For Intel-based Macs, use the files in [`intel/`](intel/).

- [`macOS-intel-tuning-paste.txt`](intel/macOS-intel-tuning-paste.txt)  
  Easiest method for everyday users.

- [`macOS-intel-tuning.sh`](intel/macOS-intel-tuning.sh)  
  Traditional script version.

The Intel setup was inspired by the difference it made on a 2015 Intel MacBook Pro, where it helped the machine feel dramatically more responsive in everyday use.

## Apple Silicon Quick Start

1. Open [`apple-silicon/macOS-Apple-Silicon-tuning.txt`](apple-silicon/macOS-Apple-Silicon-tuning.txt)
2. Copy the Terminal command
3. Open the Terminal app on the Mac
4. Paste the command and press Return
5. Review the completion report
6. Log out and back in, or restart the Mac

## Intel Quick Start

1. Open [`intel/macOS-intel-tuning-paste.txt`](intel/macOS-intel-tuning-paste.txt)
2. Copy the entire contents
3. Open the Terminal app on the Mac
4. Paste the contents and press Return
5. Restart the Mac when the script finishes

## Before You Begin

Creating a Time Machine backup before making system changes is always recommended.

The Apple Silicon script also creates its own preference backup and restore script before tuning begins. The Intel script saves a smaller before-state report.

## What These Scripts Do

Depending on the Mac, the scripts adjust a conservative collection of settings related to responsiveness and everyday usability:

- Reduce motion, transparency, and animation overhead
- Tighten Dock, Mission Control, Finder, and keyboard behavior
- Show filename extensions and simplify common Finder behavior
- Reduce unnecessary reopen and auto-launch behavior
- Save a before-state report before making changes

The Apple Silicon version does not alter power-management settings.

## What These Scripts Do Not Do

They do not:

- Delete personal files
- Uninstall applications
- Install third-party software
- Clear caches as a fake performance cure
- Scrape personal data
- Hide or rearrange the Dock
- Replace normal maintenance or hardware repair when those are actually needed

## Important Note

These scripts change macOS preferences. Review the script intended for your Mac before running it, and use it only if you are comfortable making those changes.

## Why I Am Sharing It

A good machine does not always need to be replaced. Sometimes it just needs the unnecessary pageantry turned down so it can get back to being a computer.

## Branding

This repository includes Blue Ridge Systems Consulting branding assets. See [`BRANDING.md`](BRANDING.md) for logo and brand usage guidance.

## Security

<a href="https://app.aikido.dev/audit-report/external/WUuAYeTGe5MdKOz7TJTyBMJl/request" target="_blank">
    <img src="https://app.aikido.dev/assets/badges/full-light-theme.svg" alt="Aikido Security Audit Report" height="40" />    
</a>

This repository is scanned with Aikido Security as part of a basic code safety check. As with any script, you should still review the contents yourself before running it.
