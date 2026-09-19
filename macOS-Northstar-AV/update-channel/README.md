# Northstar Guard update channel

This directory defines the lightweight, rollback-safe release channel for the Mac, Fedora COSMIC, and headless Linux Northstar Guard packages.

The release process builds a versioned source bundle and SHA-256 manifest, verifies the bundle, and then invokes the platform installer's existing `--upgrade` action. Those installers preserve reports, findings, trusted items, and prior configuration under dated backups. Automatic fleet deployment is deliberately not enabled.
