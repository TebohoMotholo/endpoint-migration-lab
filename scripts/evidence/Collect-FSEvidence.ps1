<#
.SYNOPSIS
    Collects file server and Entra Connect Sync evidence.
.NOTES
    Run on: FS01, Windows PowerShell as administrator. Read-only.
#>
. "$PSScriptRoot\Common.ps1"
if (-not (Test-IsAdmin)) { Write-Warning "Run this as administrator."; return }
$out = New-EvidenceFolder -Role "FS"

# File services
Save-Evidence "01-volumes"        { Get-Volume | Where-Object DriveLetter | Select DriveLetter, FileSystemLabel, FileSystem, @{n='SizeGB';e={[math]::Round($_.Size/1GB,1)}}, @{n='FreeGB';e={[math]::Round($_.SizeRemaining/1GB,1)}} | Format-Table -AutoSize }
Save-Evidence "02-shares"         { Get-SmbShare | Select Name, Path, FolderEnumerationMode, Description | Format-Table -AutoSize }
Save-Evidence "03-share-access"   { Get-SmbShare | Where-Object { $_.Name -notmatch '^\w\$$|ADMIN\$|IPC\$' } | ForEach-Object { Get-SmbShareAccess -Name $_.Name } | Format-Table -AutoSize }
Save-Evidence "04-ntfs-acls"      { Get-SmbShare | Where-Object { $_.Path -like '*Shares*' } | ForEach-Object { "== $($_.Path)"; icacls $_.Path } }
Save-Evidence "05-fsrm-quotas"    { Get-FsrmQuota | Select Path, @{n='LimitMB';e={$_.Size/1MB}}, @{n='UsedMB';e={[math]::Round($_.Usage/1MB,1)}}, SoftLimit, Template | Format-Table -AutoSize }
Save-Evidence "06-fsrm-autoquota" { Get-FsrmAutoQuota | Format-Table -AutoSize }
Save-Evidence "07-fsrm-screens"   { Get-FsrmFileScreen | Select Path, Active, IncludeGroup | Format-Table -AutoSize }
Save-Evidence "08-shadow-copies"  { vssadmin list shadows; vssadmin list shadowstorage }

# Entra Connect Sync
Import-Module ADSync -ErrorAction SilentlyContinue
Save-Evidence "20-adsync-version"   { (Get-Item "C:\Program Files\Microsoft Azure AD Sync\Bin\miiserver.exe").VersionInfo | Select ProductVersion | Format-List }
Save-Evidence "21-adsync-scheduler" { Get-ADSyncScheduler }
Save-Evidence "22-adsync-connectors"{ Get-ADSyncConnector | Select Name, Type | Format-Table -AutoSize }
Save-Evidence "23-adsync-features"  { (Get-ADSyncGlobalSettings).Parameters | Where-Object { $_.Name -match 'Password|SSO|Writeback|SynchronizationOption|DeviceWriteBack' } | Select Name, Value | Format-Table -AutoSize -Wrap }
Save-Evidence "24-adsync-ou-filter" { (Get-ADSyncConnector | Where-Object Type -eq 'AD').Partitions | ForEach-Object { "Partition: $($_.Name)"; "Included:"; $_.ConnectorPartitionScope.ContainerInclusionList; "Excluded:"; $_.ConnectorPartitionScope.ContainerExclusionList } }
Save-Evidence "25-adsync-last-runs" { Get-ADSyncRunProfileResult -NumberRequested 10 | Select ConnectorName, RunProfileName, Result, StartDate, EndDate | Format-Table -AutoSize }
Save-Evidence "26-adsync-autoupgrade" { Get-ADSyncAutoUpgrade }
Save-Evidence "27-sync-errors"      { Get-ADSyncRunProfileResult -NumberRequested 10 | Where-Object Result -ne 'success' | Format-List }

Save-Evidence "50-time"             { Get-TimeZone; "UTC: $([DateTime]::UtcNow.ToString('s'))"; w32tm /query /source }

Complete-Evidence
