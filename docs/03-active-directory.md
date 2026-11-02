# 03. Active Directory

## Goal

A healthy two-DC domain that looks like a small company, ready to be synced to Entra ID later.

## Design decisions

- **Two domain controllers.** DC02 gives redundancy and lets me practise replication, failover and FSMO role moves.
- **A routable-style domain name** (`lab.teboho.co.za`) instead of `.local`, to make cloud sync easier later.
- **One OU tree** (`OU=Lab`) so Entra Connect can sync only what it should.
- **Each DC points to the other for DNS first, itself second.**

## Build steps

1. DC01: static `10.10.10.10`, gateway `10.10.10.1`, rename, Windows Update, **restart**, then add AD DS and promote to a new forest.
2. DNS forwarder on DC01 to pfSense (`10.10.10.1`).
3. DHCP role on DC01. Scope `10.10.10.100` to `.200`, router `.1`, DNS `.10` and `.11`.
4. DC02: static `10.10.10.11`, join the domain, add AD DS, promote as an additional DC with DNS and GC.
5. OUs, groups and users with [`scripts/ad/New-LabStructure.ps1`](../scripts/ad/New-LabStructure.ps1).
6. Redirect new computers into the lab OU: `redircmp "OU=Computers,OU=Lab,..."`.
7. Time: PDC emulator syncs from external NTP, everything else syncs from the domain ([`scripts/ad/Set-DomainTime.ps1`](../scripts/ad/Set-DomainTime.ps1)).

## OU structure

```
lab.teboho.co.za
└── Lab
    ├── Users
    ├── Groups            Finance-Staff, HR-Staff, IT-Staff, Sales-Staff, Operations-Staff
    ├── Computers         client01 to 03
    ├── Servers           FS01, CM01
    ├── IT
    └── Service Accounts  svc-cmpush, svc-cmnaa, svc-cmrpt, svc-cmsql (not synced)
```

## Verify

```powershell
dcdiag /q
repadmin /replsummary
repadmin /showrepl
net share                       # NETLOGON and SYSVOL on both DCs
netdom query fsmo
nltest /dsgetdc:lab.teboho.co.za
```

Failover test: shut down DC01, then on a client `nltest /dsgetdc` returns DC02, domain logon and `gpupdate` still work.

## Problems hit

| Symptom | Cause | Fix |
|---|---|---|
| DC promotion failed: "role change is in progress or this computer needs to be restarted" | Pending restart after rename and role install | Restarted, reran the wizard |
| Entra Connect failed months later with a certificate "expired" error | Servers installed with the default US Pacific time zone; hardware clock in local time, so UTC was 9 hours ahead | Set `South Africa Standard Time` everywhere, PDC syncs from external NTP, resynced all machines |

## Rollback

Proxmox backups of both DCs, restored **together**. Never roll back one DC from an old snapshot while the other keeps running (USN rollback).
