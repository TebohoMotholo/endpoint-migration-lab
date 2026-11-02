<#
.SYNOPSIS
    Creates the ConfigMgr and SQL service accounts in the lab Service Accounts OU.
.NOTES
    Run on: DC01, elevated, as a Domain Admin.
    The Service Accounts OU is excluded from Entra Connect sync.
#>

$ou = "OU=Service Accounts,OU=Lab,DC=lab,DC=teboho,DC=co,DC=za"
$pw = Read-Host -AsSecureString "Password for service accounts"

$accounts = @{
    "svc-cmpush" = "ConfigMgr client push installation"
    "svc-cmnaa"  = "ConfigMgr network access account"
    "svc-cmrpt"  = "ConfigMgr reporting services point"
    "svc-cmsql"  = "SQL Server service account for CM01"
}

foreach ($name in $accounts.Keys) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$name'")) {
        New-ADUser -Name $name -SamAccountName $name -Description $accounts[$name] `
            -Path $ou -AccountPassword $pw -Enabled $true -PasswordNeverExpires $true
    }
}

Get-ADUser -Filter * -SearchBase $ou -Properties Description | Select-Object Name, Description
