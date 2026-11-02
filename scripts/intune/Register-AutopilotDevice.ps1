<#
.SYNOPSIS
    Uploads this device's hardware hash to Windows Autopilot with a group tag.
.NOTES
    Run on: the device itself, from OOBE (Shift+F10, then "powershell") or an admin prompt.
    Signs in interactively with an Intune admin account.
    Note the hyphen: -Online. Without it, "online" is read as a computer name
    and the script tries WinRM.
#>

param([string]$GroupTag = "LabPilot")

Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-Script -Name Get-WindowsAutopilotInfo -Force
Get-WindowsAutopilotInfo -Online -GroupTag $GroupTag

<# Dynamic device group rule for this tag:
   (device.devicePhysicalIds -any (_ -eq "[OrderID]:LabPilot"))
#>
