<#
.SYNOPSIS
    User-session evidence: Cloud Kerberos Trust, Windows Hello, PRT, UPN, file share access.
.NOTES
    Run on: client02, in a NORMAL PowerShell window (NOT "Run as administrator"),
    signed in as a synced test user WITH THE WINDOWS HELLO PIN.
    klist only sees your own logon session; an elevated window gives error 0xc000005f.
#>
. "$PSScriptRoot\Common.ps1"
if (Test-IsAdmin) { Write-Warning "Open a normal (non-administrator) window for this one."; return }
$out = New-EvidenceFolder -Role "USER"

Save-Evidence "01-whoami"         { whoami; whoami /upn }
Save-Evidence "02-klist-cloud"    { klist cloud_debug }
Save-Evidence "03-klist-tickets"  { klist }
Save-Evidence "04-dsregcmd-user"  { dsregcmd /status | Select-String -Pattern 'AzureAdPrt|CloudTgt|OnPremTgt|NgcSet|WorkplaceJoined|AzureAdJoined|DomainJoined|TenantName' }
Save-Evidence "05-share-access"   { Get-ChildItem "\\FS01\Shared" -ErrorAction Stop | Select -First 10 Name; "Opened \\FS01\Shared without a credential prompt." }
Save-Evidence "06-mapped-drives"  { Get-PSDrive -PSProvider FileSystem | Select Name, Root, DisplayRoot | Format-Table -AutoSize }
Save-Evidence "07-known-folders"  { [Environment]::GetFolderPath('MyDocuments'); [Environment]::GetFolderPath('Desktop') }

Complete-Evidence
