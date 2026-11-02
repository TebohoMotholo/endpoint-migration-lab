<#
.SYNOPSIS
    Adds the tenant's onmicrosoft.com suffix and moves lab users onto it.
.NOTES
    Run on: DC01, elevated, as a Domain Admin.
    Change first: $Tenant to your REAL tenant name (Microsoft 365 admin center,
    Settings, Domains). Do not leave the placeholder in.
    Not needed if you verified your own domain in the tenant instead.
#>

$Tenant = "<yourtenant>.onmicrosoft.com"
$UsersOU = "OU=Users,OU=Lab,DC=lab,DC=teboho,DC=co,DC=za"

if ($Tenant -like "<*") { throw "Set `$Tenant to your real tenant name first." }

$forest = (Get-ADForest).Name
Set-ADForest -Identity $forest -UPNSuffixes @{Add = $Tenant}
Get-ADForest | Select-Object -ExpandProperty UPNSuffixes

Get-ADUser -Filter * -SearchBase $UsersOU | ForEach-Object {
    Set-ADUser $_ -UserPrincipalName "$($_.SamAccountName)@$Tenant"
}

Get-ADUser -Filter * -SearchBase $UsersOU | Select-Object SamAccountName, UserPrincipalName

# Remove a wrong suffix added earlier, for example a placeholder:
# Set-ADForest -Identity $forest -UPNSuffixes @{Remove = "tenantname.onmicrosoft.com"}
