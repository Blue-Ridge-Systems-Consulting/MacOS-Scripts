rule Northstar_Suspicious_Shell_Download_And_Execute {
    meta:
        description = "Common download-and-execute shell pattern; review, not automatic malware proof"
        severity = "review"
    strings:
        $curl = "curl" nocase
        $wget = "wget" nocase
        $pipe = "| sh" nocase
        $bash = "bash -c" nocase
    condition:
        1 of ($curl, $wget) and 1 of ($pipe, $bash)
}

rule Northstar_Suspicious_Persistence_Command {
    meta:
        description = "Shell content that modifies autostart or cron persistence"
        severity = "review"
    strings:
        $cron = "crontab" nocase
        $systemctl = "systemctl enable" nocase
        $autostart = ".config/autostart" nocase
        $launch = "nohup" nocase
    condition:
        2 of them
}
