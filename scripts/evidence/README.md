# Lab evidence collection scripts

These scripts read the lab's configuration and status and save it as text, CSV, HTML and JSON. They change nothing. Each one ends by redacting GUIDs (tenant, object and correlation IDs) and BitLocker recovery keys, then zips its output.

## Where to run what

| Script | Run on | How |
|---|---|---|
| `Collect-DCEvidence.ps1` | DC01 | Windows PowerShell, **as administrator** |
| `Collect-FSEvidence.ps1` | FS01 | Windows PowerShell, **as administrator** |
| `Collect-CMEvidence.ps1` | CM01 | Windows PowerShell, **as administrator**, as LAB\Administrator |
| `Collect-ClientEvidence.ps1` | client02 (then client01, client04) | Windows PowerShell, **as administrator**, with a synced user signed in |
| `Collect-ClientUserEvidence.ps1` | client02 | **Normal** PowerShell (not admin), signed in as a synced user **with the PIN** |
| `Collect-CloudEvidence.ps1` | Any Windows PC with internet | Normal PowerShell; sign in as the cloud Global Administrator |
| `collect-proxmox-evidence.sh` | Proxmox host | Node, Shell: `bash collect-proxmox-evidence.sh` |

## Steps

1. Copy this whole folder to `\\FS01\IT\Evidence` so every lab machine can reach it (or to `C:\Evidence` on each machine).
2. On each machine, open PowerShell as shown above and run:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   cd \\FS01\IT\Evidence        # or wherever you copied it
   .\Collect-DCEvidence.ps1     # use the script for that machine
   ```
3. Green `OK` lines are saved. Yellow `FAIL` lines are fine to ignore if that feature is not set up yet; they are listed in `_run-log.txt`.
4. Each script prints the path of a `.zip` file. Send me all the zips.

## What is not collected

- pfSense: its config backup contains password hashes and VPN keys, so it is covered by screenshots instead.
- Autopatch groups and release status: no stable Graph API, so covered by screenshots.
- Passwords, LAPS passwords, client secrets: never read.

Check the zips before sharing. The redaction catches GUIDs and recovery keys, not everything.
