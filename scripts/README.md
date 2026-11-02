# Scripts

Scripts used while building the lab, cleaned up and commented. Each one says at the top where to run it and what to change first.

They are written for this lab's names (`lab.teboho.co.za`, `OU=Lab`, `CM01`, `FS01`). Read them before running them anywhere else.

| Folder | Script | Purpose |
|---|---|---|
| `ad` | `New-LabStructure.ps1` | OUs, department groups, test users, usage location |
| `ad` | `New-ServiceAccounts.ps1` | ConfigMgr and SQL service accounts |
| `ad` | `Set-DomainTime.ps1` | Time zone and NTP fix (the AADSTS700027 root cause) |
| `ad` | `Set-CloudUpnSuffix.ps1` | Tenant UPN suffix for synced users |
| `ad` | `Set-PasswordWritebackPermissions.ps1` | AD rights for Entra password writeback |
| `file-server` | `New-LabShares.ps1` | Department, home and software shares with NTFS rights |
| `gpo` | `Export-AllGpos.ps1` | XML, HTML, CSV and backup of every GPO |
| `gpo` | `New-PilotGpoBlock.ps1` | Deny migrated GPOs on pilot devices |
| `configmgr` | `Set-SystemManagementContainer.ps1` | System Management container and `CM01$` rights |
| `configmgr` | `Test-SqlForConfigMgr.ps1` | SQL readiness checks the way Setup connects |
| `configmgr` | `Invoke-ClientPolicyRefresh.ps1` | Trigger client policy and app evaluation |
| `intune` | `New-IntuneWinPackages.ps1` | Batch IntuneWinAppUtil packaging |
| `intune` | `Register-AutopilotDevice.ps1` | Hardware hash upload with a group tag |
| `intune` | `Get-NonCompliantDevices.ps1` | Graph compliance report |
| `proxmox` | `setup-backup-storage.sh` | External backup storage with retention and mount check |
| `proxmox` | `move-old-backups.sh` | Move backups off the system disk |

No passwords, keys or tenant IDs are stored in any script. Credentials are prompted for at runtime.
