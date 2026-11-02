# Lessons learned

Real problems hit while building this lab. Each one is written as: what I saw, how I worked it out, the root cause, the fix, and what I now check first.

---

## 1. Lab clients got addresses from the wrong network

**Symptom.** A Windows 11 client got an address, gateway and DNS from the upstream network instead of a lab address.

**Diagnosis.** That subnet belonged to the network the Proxmox host was plugged into, so the client was not behind pfSense at all. The VM's network device was on `vmbr0`, and `vmbr1` did not exist on the host.

**Root cause.** The internal bridge was never created, so every VM could only attach to the bridge connected to the physical network. A lab DHCP server in that position could hand out addresses on a real network.

**Fix.** Created `vmbr1` with no physical port, moved every lab NIC to it, kept only pfSense WAN on `vmbr0`. Rebuilt the lab on my own network at home.

**Check first next time.** Bridge list and every VM's NIC bridge, before starting any DHCP server.

---

## 2. pfSense had no internet ("No route to host")

**Symptom.** Packages would not install, `ping 1.1.1.1` from pfSense returned "No route to host", DNS returned SERVFAIL.

**Diagnosis.** `ifconfig vtnet0` showed a valid WAN address, so the interface was fine. The routing table had no default route.

**Root cause.** The WAN was changed to a static address for port forwarding, and a static address does not bring a gateway with it.

**Fix.** Added the upstream gateway under Interfaces, WAN, and selected it.

**Check first next time.** `netstat -rn` for a default route whenever an interface goes static.

---

## 3. Web server returned 403 Forbidden

**Symptom.** Nginx answered 403 for the site root.

**Diagnosis.** The Nginx error log said "directory index of /var/www/mysite/ is forbidden". `ls -la` showed the files were there with readable permissions.

**Root cause.** The home page was `Index.html`. Linux file names are case sensitive and Nginx looks for `index.html`.

**Fix.** Renamed the file, set files to 644 and folders to 755, removed `README.md` and `.gitignore` from the web root.

**Check first next time.** The error log, before changing permissions.

---

## 4. Proxmox system disk at 94%

**Symptom.** Root partition at 94% with 4 GB free.

**Diagnosis.** `du -xh /var/lib/vz` showed 40 GB in `dump` (backups) and 17 GB of ISOs.

**Root cause.** Early backups were saved to the `local` storage, which sits on the system disk.

**Fix.** Moved backups to the external drive, repointed jobs, set retention, removed backup content from `local`, and set `is_mountpoint` so a missing drive cannot silently fill the system disk again.

**Check first next time.** Where a new backup job writes to.

---

## 5. Sysprep failed on the Windows 11 template

**Symptom.** Sysprep stopped during validation.

**Diagnosis.** `C:\Windows\System32\Sysprep\Panther\setuperr.log`: "BitLocker is on for the OS volume. Turn BitLocker off to run Sysprep."

**Root cause.** Windows 11 turned on device encryption automatically because the VM has a virtual TPM.

**Fix.** `manage-bde -off C:`, waited for full decryption, set `PreventDeviceEncryption` in the image, ran sysprep again.

**Check first next time.** `manage-bde -status C:` before sysprep, and take a backup first because sysprep is one-way.

---

## 6. ConfigMgr prerequisite check failed on SQL

**Symptom.** Failures for SQL service account, dedicated instance, collation and sysadmin rights.

**Diagnosis.** Locally, SQL reported the right collation, sysadmin rights and only system databases. Only the service account was actually wrong.

**Root cause.** Two things: SQL ran as `NT Service\MSSQLSERVER`, which ConfigMgr rejects, and TCP/IP was disabled. Setup connects by server FQDN over TCP, could not reach the instance, and reported every SQL check as failed.

**Fix.** Domain service account set in SQL Server Configuration Manager, TCP/IP enabled on 1433, firewall rule, Setup rerun as a domain admin.

**Check first next time.** Connect the way the app does (`sqlcmd -S <fqdn>`), not just `localhost`.

---

## 7. Apps missing from Software Center

**Symptom.** Deployments existed but nothing showed on the client.

**Diagnosis.** Distribute Content had no destinations to pick. After adding a distribution point, one app still did not appear; its Distribution Settings showed "Manually copy the content in this package to the distribution point".

**Root cause.** No distribution point role at first, then content set to prestaged on a copied app.

**Fix.** Added the DP role with the boundary group, set content to automatic download, redistributed.

**Check first next time.** Content Status for the app before looking at the client.

---

## 8. Entra Connect failed with AADSTS700027

**Symptom.** "Microsoft Entra Connect could not configure application-based authentication for this server."

**Diagnosis.** The trace log showed `AADSTS700027` saying the certificate was expired. The certificate start time was 12:12 UTC, but Entra received the request at 03:13 UTC. The certificate was not expired, it was not valid yet.

**Root cause.** The Windows Servers were installed with the default US Pacific time zone while the Proxmox hardware clock ran in South African local time. Local clocks looked right, but UTC was 9 hours ahead on every server. Nothing on-premises noticed because all servers were wrong together.

**Fix.** Set `South Africa Standard Time` on every machine, pointed the PDC emulator at external NTP, resynced the domain, deleted the half-made app registration, reran the wizard.

**Check first next time.** `[DateTime]::UtcNow` against real UTC before any cloud integration.

---

## 9. Windows Hello cloud trust not applying

**Symptom.** `klist cloud_debug` showed "Cloud Kerberos enabled by policy: 0".

**Diagnosis.** The Intune policy existed and was assigned, but the device is co-managed.

**Root cause.** The Device Configuration workload was still owned by Configuration Manager, so Intune configuration did not apply. Also tested from an elevated window and with a password sign-in, which both hide the real result.

**Fix.** Moved Device Configuration to Pilot Intune for the pilot collection, signed in with the Hello PIN, ran `klist` from a normal window.

**Check first next time.** Co-management workload ownership for any Intune policy that does not land on a co-managed device.

---

## Smaller ones

| Problem | Cause |
|---|---|
| `dsacls` "parameter is incorrect" | `$` in `CM01$` expanded inside PowerShell double quotes |
| `Set-ADForest` could not find forest `teboholab` | Needs the forest DNS name |
| Wizard showed `tenantname.onmicrosoft.com` | A placeholder from instructions was used as a real value |
| `Get-WindowsAutopilotInfo online` tried WinRM | Missing hyphen, so `online` was read as a computer name |
| `IntuneWinAppUtil.exe.` not recognised | Trailing full stop, then the tool was not in the folder |
| Client would not enroll in Intune | Signed in as an unsynced, unlicensed admin |
| DC promotion blocked | Pending restart after rename |
