<#
.SYNOPSIS
    Grants the Entra Connect AD connector account the rights password writeback needs.
.NOTES
    Run on: FS01 (the Entra Connect server), elevated.
    You will be asked for Domain Admin credentials.
    Grants Reset password, Change password, Write lockoutTime and Write pwdLastSet
    on descendant user objects.
#>

$domain = "lab.teboho.co.za"

# Find the connector account Entra Connect created (starts with MSOL_)
$acct = Get-ADUser -Filter "Name -like 'MSOL_*'" | Select-Object -First 1
if (-not $acct) { throw "No MSOL_ account found. Has Entra Connect been configured?" }
Write-Host "Connector account: $($acct.SamAccountName)"

Import-Module "C:\Program Files\Microsoft Azure Active Directory Connect\AdPrep\AdSyncConfig.psm1"
Set-ADSyncPasswordWritebackPermissions -ADConnectorAccountName $acct.SamAccountName -ADConnectorAccountDomain $domain
