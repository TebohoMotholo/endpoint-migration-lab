# 05. Configuration Manager (the "before" estate)

## Goal

A working ConfigMgr primary site that deploys apps and a compliance baseline, so the migration to Intune starts from a realistic place.

## Server (CM01)

| Setting | Value |
|---|---|
| CPU / RAM | 4 cores, 8 GB |
| Disks | 80 GB OS, 100 GB data (SQL, content library, install) |
| Site code | `LAB` |
| SQL Server | Default instance, collation `SQL_Latin1_General_CP1_CI_AS`, TCP 1433, domain service account |

## Build steps

1. **Prepare AD** on DC01:
   - Extend the schema with `extadsch.exe`, check `C:\ExtADSch.log`
   - Create `CN=System Management,CN=System` and give `CM01$` full control ([`scripts/configmgr/Set-SystemManagementContainer.ps1`](../scripts/configmgr/Set-SystemManagementContainer.ps1))
   - Service accounts for client push, network access, reporting and SQL
2. **Prerequisites** on CM01: IIS, BITS, RDC, .NET features; Windows ADK and the WinPE add-on.
3. **SQL Server**: database engine only, the required collation, Windows authentication, domain admins as sysadmin, memory capped at 4 GB, TCP/IP enabled.
4. **Install** the primary site with the evaluation edition. Watch `C:\ConfigMgrSetup.log` with CMTrace.
5. **Configure**:
   - Boundary `10.10.10.1` to `.254`, boundary group `Lab LAN` with site assignment and CM01 as content location
   - AD system, user and group discovery on `OU=Lab`
   - Distribution point role on CM01 (content on the data drive), linked to the boundary group
   - Client push account, network access account
   - Default client policy polling every 5 minutes (lab only)
6. **Collections**: `Lab Workstations` (query) and `Pilot` (client02).
7. **Deploy**: 7-Zip and Chrome (MSI), Notepad++ and VLC (EXE with detection rules) as Available.
8. **Compliance baseline**: a registry configuration item for `InactivityTimeoutSecs = 600`, mirroring the lock screen GPO.

## Verify

- Monitoring, Site Status all green
- Distribution Point Configuration Status: CM01 green
- Content Status per app: Success
- Devices show Client: Yes, Active
- Software Center on client02 lists the apps and installs them

Client-side logs: `C:\Windows\CCM\Logs\PolicyAgent.log`, `AppDiscovery.log`, `AppEnforce.log`, `CAS.log`, `ContentTransferManager.log`.

## Problems hit

| Symptom | Cause | Fix |
|---|---|---|
| `dsacls ... "LAB\CM01$:GA"` returned "The parameter is incorrect" | PowerShell expanded `$` inside double quotes | Used single quotes |
| Prereq check failed: SQL service account, dedicated instance, collation, sysadmin | SQL ran as `NT Service\MSSQLSERVER` and TCP/IP was off, so Setup could not connect by FQDN | Domain service account `svc-cmsql`, TCP/IP on 1433, firewall rule ([`scripts/configmgr/Test-SqlForConfigMgr.ps1`](../scripts/configmgr/Test-SqlForConfigMgr.ps1)) |
| Second SQL install wizard set "Domain Users" as sysadmin and unlimited memory | Wizard defaults | Cancelled it and fixed the default instance instead |
| Distribute Content: destination list empty | No distribution point role installed | Added the DP role and linked it to the boundary group |
| Apps still missing from Software Center | App content set to "Manually copy the content" (prestaged) | Changed to automatic download, redistributed |

## Rollback

Proxmox backup of CM01 before SQL install, before site install, and after the site is healthy. ConfigMgr site maintenance backup to the data drive.
