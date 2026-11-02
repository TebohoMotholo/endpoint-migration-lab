<#
.SYNOPSIS
    Operational report: non-compliant Intune devices to CSV, plus a short summary.
.NOTES
    Run on: any admin workstation with internet access.
    Needs the Microsoft.Graph.DeviceManagement module and read consent.
#>

param([string]$OutFile = ".\noncompliant-devices.csv")

if (-not (Get-Module -ListAvailable Microsoft.Graph.DeviceManagement)) {
    Install-Module Microsoft.Graph.DeviceManagement -Scope CurrentUser -Force
}
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All" -NoWelcome

$all = Get-MgDeviceManagementManagedDevice -All
$bad = $all | Where-Object ComplianceState -eq "noncompliant"

$bad | Select-Object DeviceName, UserPrincipalName, OperatingSystem, OsVersion,
    ComplianceState, ManagementAgent, LastSyncDateTime |
    Export-Csv $OutFile -NoTypeInformation

# Executive one-liner
$total = $all.Count
$pct = if ($total) { [math]::Round((($total - $bad.Count) / $total) * 100, 1) } else { 0 }
"Managed devices: $total  |  Compliant: $pct%  |  Non-compliant: $($bad.Count)"
"Detail written to $OutFile"

$all | Group-Object ManagementAgent | Select-Object Name, Count
