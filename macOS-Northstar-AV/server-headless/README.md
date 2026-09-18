# Northstar Guard — lightweight server agent

This headless build is intended for servers, exit-node VMs, and other machines without a desktop session. It installs one systemd service with no GUI, watches only high-value user, temporary, persistence, and local executable paths, and keeps resource limits low (`CPUQuota=5%`, `MemoryMax=128M`).

![Northstar Guard lightweight server agent](northstar-server-terminal.png)

The live monitor checks files as they are created or changed with the bundled YARA rules and ClamAV when `clamscan` is installed. On-demand scans are available for the same focused areas:

```bash
sudo northstar-guard status
sudo northstar-guard start
sudo northstar-guard stop
sudo northstar-guard scan quick
sudo northstar-guard scan full
sudo northstar-guard scan path /path/to/file
sudo northstar-guard findings
```

Reports and the executive summary are written as timestamped Markdown files under `/var/lib/northstar-guard/reports`. The agent does not scan an entire filesystem by default. It watches `/home/ray/Downloads`, `/home/ray/.config/autostart`, `/tmp`, `/var/tmp`, `/etc/systemd/system`, `/etc/cron.d`, `/etc/cron.daily`, `/usr/local/bin`, and `/usr/local/sbin`; missing paths are skipped.

The installer disables legacy Maldet/LMD service and timer hooks while leaving ClamAV definition updates available where ClamAV is installed. It does not add or modify any GitHub Actions workflow.
