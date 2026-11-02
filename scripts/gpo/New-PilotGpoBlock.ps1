<#
.SYNOPSIS
    Stops migrated GPOs from applying to pilot devices, so only Intune controls them.
.NOTES
    Run on: DC01, elevated.
    Adds a Deny "Apply group policy" for the GPO-Retired-Pilot group on each GPO listed.
    Undo: remove the group from the GPO's delegation, or remove the computer from the group.
#>

$GroupName = "GPO-Retired-Pilot"
$GroupsOU  = "OU=Groups,OU=Lab,DC=lab,DC=teboho,DC=co,DC=za"
$PilotPCs  = @("client02")
$Migrated  = @("Block USB Storage","Edge Baseline","Logon Banner","Workstation Security")

if (-not (Get-ADGroup -Filter "Name -eq '$GroupName'")) {
    New-ADGroup -Name $GroupName -GroupScope Global -Path $GroupsOU
}
foreach ($pc in $PilotPCs) {
    Add-ADGroupMember -Identity $GroupName -Members (Get-ADComputer $pc)
}

foreach ($gpo in $Migrated) {
    # Deny the "Apply group policy" extended right to the group
    $g = Get-GPO -Name $gpo
    $adGpo = [ADSI]"LDAP://$($g.Path)"
    $sid = (Get-ADGroup $GroupName).SID
    $applyGuid = [Guid]"edacfd8f-ffb3-11d1-b41d-00a0c968f939"
    $rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
        $sid, "ExtendedRight", "Deny", $applyGuid)
    $adGpo.ObjectSecurity.AddAccessRule($rule)
    $adGpo.CommitChanges()
    Write-Host "Denied apply on '$gpo' for $GroupName"
}

Write-Host "Restart the pilot computers so the new group membership takes effect, then run gpresult /r."
