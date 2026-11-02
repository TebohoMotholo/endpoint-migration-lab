<#
.SYNOPSIS
    Creates the lab OU tree, department groups and test users.
.NOTES
    Run on: DC01, elevated PowerShell, as a Domain Admin.
    Change first: $DomainDN, and you will be prompted for the initial user password.
    Lab use only. Users are created enabled with the same initial password.
#>

$DomainDN = "DC=lab,DC=teboho,DC=co,DC=za"
$LabOU    = "OU=Lab,$DomainDN"

# OU tree
New-ADOrganizationalUnit -Name "Lab" -Path $DomainDN -ErrorAction SilentlyContinue
foreach ($ou in "Users","Groups","Computers","Servers","IT","Service Accounts") {
    New-ADOrganizationalUnit -Name $ou -Path $LabOU -ErrorAction SilentlyContinue
}

$GroupsOU = "OU=Groups,$LabOU"
$UsersOU  = "OU=Users,$LabOU"

# Department groups
"Finance-Staff","HR-Staff","IT-Staff","Sales-Staff","Operations-Staff" | ForEach-Object {
    if (-not (Get-ADGroup -Filter "Name -eq '$_'")) {
        New-ADGroup -Name $_ -GroupScope Global -GroupCategory Security -Path $GroupsOU
    }
}

# Test users: GivenName, Surname, SamAccountName, Group
$people = @(
    @("Thandi","Finance","tfinance","Finance-Staff"),
    @("Nomsa","Dlamini","ndlamini","Finance-Staff"),
    @("Pieter","Botha","pbotha","Finance-Staff"),
    @("Sipho","HR","shr","HR-Staff"),
    @("Palesa","Mokoena","pmokoena","HR-Staff"),
    @("Zanele","Khumalo","zkhumalo","Sales-Staff"),
    @("Johan","Naidoo","jnaidoo","Sales-Staff"),
    @("Anele","Mthembu","amthembu","Operations-Staff"),
    @("Lerato","IT","lit","IT-Staff"),
    @("Lindiwe","Nkosi","lnkosi","IT-Staff")
)

$pw = Read-Host -AsSecureString "Initial password for test users"
$suffix = ($DomainDN -replace 'DC=','' -replace ',','.')

foreach ($x in $people) {
    $sam = $x[2]
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$sam'")) {
        New-ADUser -Name "$($x[0]) $($x[1])" -GivenName $x[0] -Surname $x[1] `
            -SamAccountName $sam -UserPrincipalName "$sam@$suffix" `
            -Path $UsersOU -AccountPassword $pw -Enabled $true
    }
    Add-ADGroupMember -Identity $x[3] -Members $sam -ErrorAction SilentlyContinue
}

# Usage location for cloud licensing
Get-ADUser -Filter * -SearchBase $UsersOU | Set-ADUser -Replace @{c="ZA"}

# New computers land in the lab OU
redircmp "OU=Computers,$LabOU"

Get-ADUser -Filter * -SearchBase $UsersOU | Select-Object SamAccountName, UserPrincipalName
