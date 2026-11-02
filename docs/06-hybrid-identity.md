# 06. Hybrid identity and co-management

## Goal

Connect the lab to a Microsoft 365 tenant: sync users and devices, hybrid join the clients, and link ConfigMgr to Intune.

## Design decisions

- **Password hash sync** with seamless SSO. Simplest and most resilient sign-in method.
- **Sync server on FS01**, not a domain controller.
- **OU filtering**: only `OU=Lab` and children, never `Service Accounts`.
- **UPN suffix**: the tenant's `onmicrosoft.com` domain (Option B). Verifying `lab.teboho.co.za` with a TXT record at the public DNS host is the alternative.
- **Pilot first**: co-management enrollment and workloads use a pilot collection before anything goes wide.

## Build steps

1. Prepare users: usage location `ZA`, UPN suffix, IdFix check ([`scripts/ad/Set-CloudUpnSuffix.ps1`](../scripts/ad/Set-CloudUpnSuffix.ps1)).
2. Start the trial tenant, turn off recurring billing, set up MFA on two cloud-only admin accounts.
3. Install Entra Connect Sync on FS01 (Customize): password hash sync, SSO, OU filtering, password writeback.
4. Run Entra Connect again: Configure device options, Hybrid Microsoft Entra join, Windows 10 and later.
5. Group-based licensing: `LIC-BusinessPremium`.
6. Mobility (MDM and MAM): MDM user scope set to the licensed group.
7. ConfigMgr, Cloud Services, **Cloud Attach** (the newer name for co-management): automatic enrollment in Intune for the `Pilot` collection, all workloads left on Configuration Manager.

## Verify

```powershell
# On FS01
Start-ADSyncSyncCycle -PolicyType Delta

# On a client, signed in as a synced, licensed user (not Administrator)
dsregcmd /status   # AzureAdJoined YES, DomainJoined YES, AzureAdPrt YES
```

- Entra admin center: users show "On-premises sync enabled", devices show "Microsoft Entra hybrid joined"
- Intune admin center: client02 shows "Managed by: Co-managed"
- `C:\Windows\CCM\Logs\CoManagementHandler.log` on the client

## Problems hit

| Symptom | Cause | Fix |
|---|---|---|
| `Set-ADForest` asked for Identity and failed on `teboholab` | It needs the forest DNS name | `Set-ADForest -Identity (Get-ADForest).Name ...` |
| Wizard listed `tenantname.onmicrosoft.com` as "Not Added" | Placeholder value from the instructions was used as the real suffix | Added the real tenant suffix, updated UPNs, removed the placeholder, re-added the directory in the wizard |
| "Could not configure application-based authentication", `AADSTS700027` | Newer Entra Connect signs in with an app certificate. FS01's UTC was 9 hours ahead (Pacific time zone with a local-time hardware clock), so the new certificate was "not yet valid" to Entra | Fixed time zone and NTP across the domain, deleted the half-made app registration, reran the wizard as administrator |
| Client would not enroll | Signed in as `LAB\Administrator`, which is not synced or licensed | Signed in as a synced, licensed user |

## Rollback

Entra Connect can be uninstalled and the tenant objects removed. Co-management can be turned off in Cloud Attach properties; workloads return to ConfigMgr.
