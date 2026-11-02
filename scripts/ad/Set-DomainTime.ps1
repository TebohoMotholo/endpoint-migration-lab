<#
.SYNOPSIS
    Fixes time zone and time sync across the domain.
.DESCRIPTION
    Windows Server defaults to US Pacific time. With a hardware clock in local time
    (the Proxmox default for Windows VMs) that puts UTC hours out, which breaks
    certificate-based sign-in to Entra ID (AADSTS700027).

    Part 1: run on EVERY Windows machine.
    Part 2: run on the PDC emulator only.
    Part 3: run on every other machine.
#>

# ---- Part 1: every machine
Set-TimeZone -Id "South Africa Standard Time"

# ---- Part 2: PDC emulator only
$pdc = (Get-ADDomain).PDCEmulator
Write-Host "PDC emulator is $pdc"
if ($env:COMPUTERNAME -ieq $pdc.Split('.')[0]) {
    w32tm /config /manualpeerlist:"0.za.pool.ntp.org 1.za.pool.ntp.org time.windows.com" /syncfromflags:manual /reliable:yes /update
    Restart-Service w32time
    w32tm /resync /force
}

# ---- Part 3: every other machine
else {
    w32tm /resync /rediscover
}

# ---- Check: compare UtcNow with real UTC
Get-TimeZone | Select-Object Id
Get-Date
[DateTime]::UtcNow
w32tm /query /source
