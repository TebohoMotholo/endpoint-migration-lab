# 09. Windows Autopilot

## Goal

Show the cloud-native "after" state: a new device goes from first boot to a managed, Entra joined desktop with apps installed, with no imaging and no domain join.

## Test device

client04: a linked clone of the Windows 11 template, kept out of the domain.

## Build steps

1. Register the hardware hash from OOBE (Shift+F10):
   ```powershell
   powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   Install-Script Get-WindowsAutopilotInfo -Force
   Get-WindowsAutopilotInfo -Online -GroupTag LabPilot
   ```
2. Dynamic device group `Autopilot-Devices`:
   ```
   (device.devicePhysicalIds -any (_ -eq "[OrderID]:LabPilot"))
   ```
3. Deployment profile: user-driven, Microsoft Entra joined, standard user, name template `LAB-%RAND:5%`.
4. Enrollment Status Page: block use until required apps install.
5. Win32 apps from [08-app-migration.md](08-app-migration.md) assigned Required to `Autopilot-Devices`.
6. Reset client04 and sign in with a synced, licensed user at the Autopilot screen.

## Verify

- Devices, Enrollment, Windows Autopilot, Devices: client04 with group tag `LabPilot`, profile status Assigned
- OOBE shows the organisation name and the ESP progress
- Device appears in Intune as Entra joined and compliant

## Lab limits

- User-driven mode works on a VM with a virtual TPM.
- Self-deploying and pre-provisioning modes need real TPM attestation, so they are out of scope here.
- Hybrid-join Autopilot needs the Intune Connector for Active Directory (stretch goal).

## Problems hit

| Symptom | Cause | Fix |
|---|---|---|
| WinRM / TrustedHosts error, `CimSession` null | Typed `online` without the hyphen, so it was treated as a computer name | `Get-WindowsAutopilotInfo -Online -GroupTag LabPilot` |
