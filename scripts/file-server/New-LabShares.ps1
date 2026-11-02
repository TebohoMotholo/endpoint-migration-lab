<#
.SYNOPSIS
    Creates the department shares on FS01 with NTFS permissions.
.NOTES
    Run on: FS01, elevated.
    Change first: $Drive. Check it with Get-Volume. In this lab D: was a CD drive
    and the data disk was F:.
    Share permission is Everyone Full; NTFS does the real restricting.
#>

$Drive = "F:"
$Root  = "$Drive\Shares"

if (-not (Test-Path "$Drive\")) { throw "$Drive does not exist. Check Get-Volume." }

$shares = [ordered]@{
    "Shared"  = "LAB\Domain Users"
    "Finance" = "LAB\Finance-Staff"
    "HR"      = "LAB\HR-Staff"
    "IT"      = "LAB\IT-Staff"
}

foreach ($name in $shares.Keys) {
    $path = "$Root\$name"
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    if (-not (Get-SmbShare -Name $name -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name $name -Path $path -FullAccess Everyone -FolderEnumerationMode AccessBased | Out-Null
    }
    icacls $path /inheritance:r /grant "SYSTEM:(OI)(CI)F" /grant "BUILTIN\Administrators:(OI)(CI)F" /grant "$($shares[$name]):(OI)(CI)M" | Out-Null
}

# Home folders: users can create their own folder, Creator Owner gets full control of it
$homeDir = "$Root\Home"
New-Item -ItemType Directory -Path $homeDir -Force | Out-Null
if (-not (Get-SmbShare -Name "Home" -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name "Home" -Path $homeDir -FullAccess Everyone -FolderEnumerationMode AccessBased | Out-Null
}
icacls $homeDir /inheritance:r /grant "SYSTEM:(OI)(CI)F" /grant "BUILTIN\Administrators:(OI)(CI)F" /grant "CREATOR OWNER:(OI)(CI)(IO)F" /grant "LAB\Domain Users:(RD,AD,X,RA)" | Out-Null

# Hidden software share, readable by computer accounts (ConfigMgr content source)
$sw = "$Root\Software"
New-Item -ItemType Directory -Path $sw -Force | Out-Null
if (-not (Get-SmbShare -Name "Software$" -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name "Software$" -Path $sw -FullAccess Everyone | Out-Null
}
icacls $sw /inheritance:r /grant "SYSTEM:(OI)(CI)F" /grant "BUILTIN\Administrators:(OI)(CI)F" /grant "LAB\Domain Users:(OI)(CI)RX" /grant "LAB\Domain Computers:(OI)(CI)RX" | Out-Null

Get-SmbShare | Where-Object Path -like "$Root*" | Select-Object Name, Path

# To remove the shares again (folders and files are kept):
# "Shared","Finance","HR","IT","Home","Software$" | ForEach-Object { Remove-SmbShare -Name $_ -Force }
