# 07. Group Policy to Intune

## Goal

Move every active GPO for workstations into Intune, validate each one on a pilot device, then retire the GPO. Nothing counts as migrated until the old policy is gone.

## Method

1. Export every GPO to XML ([`scripts/gpo/Export-AllGpos.ps1`](../scripts/gpo/Export-AllGpos.ps1)). Each file must stay under 4 MB.
2. Intune admin center, Devices, Group Policy analytics, Import. Record the MDM support % for each GPO.
3. Migrate supported settings to a Settings catalog profile. Rebuild unsupported ones by hand.
4. Assign to the `Pilot-Devices` group (client02).
5. Stop the old GPO applying to the pilot: security group `GPO-Retired-Pilot`, Deny "Apply group policy" on each migrated GPO.
6. Validate on client02, then widen, then unlink the GPO.

Device configuration from Intune only takes effect on co-managed devices once the Device Configuration workload is moved to Intune (Pilot Intune first).

## Mapping

| GPO | Intune destination | Status |
|---|---|---|
| Block USB Storage | Settings catalog, Removable Storage Access (or Defender device control) | In progress |
| Edge Baseline | Settings catalog, Microsoft Edge | In progress |
| Firewall Baseline | Endpoint security, Firewall | In progress |
| Logon Banner | Settings catalog, Local Policies Security Options | In progress |
| Workstation Security | Settings catalog, Interactive logon machine inactivity limit | In progress |
| Local Admins | Endpoint security, Account protection, Local user group membership; later LAPS and EPM | In progress |
| Map Drives | Platform script (`New-PSDrive -Persist`) or move content to SharePoint and OneDrive | Planned |
| Folder Redirection | Settings catalog, OneDrive Known Folder Move | Planned |
| Password policy | Stays at domain level for hybrid users; Entra password protection added | Planned |

Update the status column as each one is validated and retired.

## Validate

- client02: Settings, Accounts, Access work or school, Info, Sync
- Intune: device, Device configuration, every profile "Succeeded"
- `gpresult /r` no longer lists the retired GPOs
- Behaviour test: USB blocked, Edge home page set, banner shows, firewall on
- Diagnostics: `mdmdiagnosticstool.exe -area DeviceEnrollment;DeviceProvisioning -zip C:\mdm.zip`

## Risks and how they are handled

| Risk | Control |
|---|---|
| Same setting from GPO and Intune | Analytics shows overlap; GPO denied for the pilot before Intune policy is assigned |
| Pilot Intune does not remove policies on unassignment | Clean up by hand during testing |
| Domain groups in local group membership on hybrid devices | Tested separately before rollout |
