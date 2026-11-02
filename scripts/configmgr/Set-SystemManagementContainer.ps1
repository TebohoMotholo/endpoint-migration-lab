<#
.SYNOPSIS
    Creates the System Management container and gives the site server full control.
.NOTES
    Run on: DC01, elevated, after extending the schema with extadsch.exe.
    Single quotes around 'LAB\CM01$:GA' matter. In double quotes PowerShell
    expands $ and dsacls fails with "The parameter is incorrect".
#>

$sysDN = "CN=System,DC=lab,DC=teboho,DC=co,DC=za"
$smDN  = "CN=System Management,$sysDN"

if (-not (Get-ADObject -Filter "distinguishedName -eq '$smDN'")) {
    New-ADObject -Name "System Management" -Type container -Path $sysDN
}

dsacls $smDN /G 'LAB\CM01$:GA' /I:T

# Confirm
dsacls $smDN | Select-String 'CM01'

# Schema extension check (objects named MS-SMS-* should exist)
Get-ADObject -SearchBase (Get-ADRootDSE).schemaNamingContext -Filter "name -like 'MS-SMS-*'" |
    Select-Object -First 5 Name
