# 04. File services and Group Policy

## Goal

Give the domain the kind of file shares and policies a real company has, so there is something meaningful to migrate later.

## File server (FS01)

| Share | Path | NTFS access |
|---|---|---|
| Shared | `F:\Shares\Shared` | Domain Users: Modify |
| Finance | `F:\Shares\Finance` | Finance-Staff: Modify |
| HR | `F:\Shares\HR` | HR-Staff: Modify |
| IT | `F:\Shares\IT` | IT-Staff: Modify |
| Home | `F:\Shares\Home` | Users create their own folder, Creator Owner full control |
| Software$ | `F:\Shares\Software` | Domain Users and Domain Computers: Read (ConfigMgr content source) |

- Share permission is open, NTFS does the restricting.
- Access-based enumeration hides folders a user cannot open.
- FSRM quota of 500 MB on each home folder (auto-apply template).
- File screen blocking audio, video and executables on `Shared`.
- Shadow copies on the data volume for Previous Versions.

Script: [`scripts/file-server/New-LabShares.ps1`](../scripts/file-server/New-LabShares.ps1)

## Group Policy

| GPO | Linked to | Settings |
|---|---|---|
| Default Domain Policy | Domain | Password length 12, complexity, history 10, lockout 5 attempts / 15 min |
| Map Drives | Users | S: Shared for everyone; F:, H:, I: by group with item-level targeting |
| Folder Redirection | Users | Documents and Desktop to `\\FS01\Home` |
| Restrict Control Panel | Users | Control Panel blocked, IT-Staff denied "Apply group policy" |
| Workstation Security | Computers | Machine inactivity limit 600 s |
| Block USB Storage | Computers | All removable storage classes: deny all access |
| Edge Baseline | Computers | Home page, InPrivate disabled (Edge ADMX in the central store) |
| Firewall Baseline | Computers | Domain profile on, inbound blocked by default |
| Local Admins | Computers | IT-Staff added to local Administrators (Preferences, Update) |
| Logon Banner | Computers | Interactive logon message title and text |
| Server Baseline | Servers | RDP allowed, ICMP allowed in the domain profile |
| ConfigMgr Client Prereqs | Computers | File and printer sharing and ICMP inbound for client push |

These GPOs are the migration inventory for [07-gpo-migration.md](07-gpo-migration.md).

## Verify

```powershell
gpupdate /force
gpresult /r
gpresult /h C:\gp.html
```

Test as a Finance user: `\\FS01\Finance` opens, `\\FS01\HR` is denied or hidden, S: and F: map, Control Panel is blocked. As an IT user, Control Panel opens and I: maps.

## Problems hit

| Symptom | Cause | Fix |
|---|---|---|
| Share script failed on `D:` | `D:` was a CD drive; the data disk was `F:` | Checked with `Get-Volume`, removed the half-made shares, reran on `F:` |
| User policies did not apply on first logon | Drive maps and folder redirection need a fresh logon | Logged off and on (sometimes twice) after `gpupdate` |

## Rollback

GPO backup with `Backup-GPO -All` before every change, and a Proxmox backup of FS01.
