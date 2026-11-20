<#
.SYNOPSIS
    Collects Configuration Manager and SQL Server evidence.
.NOTES
    Run on: CM01, Windows PowerShell as administrator, as LAB\Administrator
    (a ConfigMgr Full Administrator). Read-only. Site code assumed LAB.
#>
param([string]$SiteCode = "LAB")
. "$PSScriptRoot\Common.ps1"
if (-not (Test-IsAdmin)) { Write-Warning "Run this as administrator."; return }
$out = New-EvidenceFolder -Role "CM"
$fqdn = "$env:COMPUTERNAME.$env:USERDNSDOMAIN"

# SQL Server
Save-Evidence "01-sql-service"   { Get-CimInstance Win32_Service -Filter "Name like 'MSSQL%' or Name like 'SQLAgent%'" | Select Name, StartName, State, StartMode | Format-Table -AutoSize }
Save-Evidence "02-sql-tcp"       { Test-NetConnection $fqdn -Port 1433 | Select ComputerName, RemotePort, TcpTestSucceeded | Format-List }
Save-Evidence "03-sql-props"     { sqlcmd -S $fqdn -E -W -Q "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('ProductVersion') AS varchar(30)) AS Version, CAST(SERVERPROPERTY('Edition') AS varchar(60)) AS Edition, CAST(SERVERPROPERTY('Collation') AS varchar(60)) AS Collation, IS_SRVROLEMEMBER('sysadmin') AS IsSysadmin" }
Save-Evidence "04-sql-databases" { sqlcmd -S $fqdn -E -W -Q "SET NOCOUNT ON; SELECT name, collation_name FROM sys.databases" }
Save-Evidence "05-sql-memory"    { sqlcmd -S $fqdn -E -W -Q "SET NOCOUNT ON; SELECT name, value_in_use FROM sys.configurations WHERE name IN ('max server memory (MB)','min server memory (MB)')" }

# ConfigMgr
$psd = Join-Path (Split-Path $env:SMS_ADMIN_UI_PATH -Parent) "ConfigurationManager.psd1"
try {
    Import-Module $psd -ErrorAction Stop
    if (-not (Get-PSDrive -Name $SiteCode -ErrorAction SilentlyContinue)) {
        New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $fqdn | Out-Null
    }
    # Run each ConfigMgr command inside the site drive, then return to the file system to save
    function InSite([scriptblock]$sb) { Push-Location "$($SiteCode):"; try { & $sb } finally { Pop-Location } }

    Save-Evidence "10-site"            { InSite { Get-CMSite | Select SiteCode, SiteName, ServerName, Version, BuildNumber | Format-List } }
    Save-Evidence "11-site-roles"      { InSite { Get-CMSiteRole | Select NetworkOSPath, RoleName | Sort NetworkOSPath | Format-Table -AutoSize } }
    Save-Evidence "12-site-status"     { InSite { Get-CMSiteStatusMessage -ViewingPeriod (Get-Date).AddDays(-1) -Severity Error -ErrorAction SilentlyContinue | Select -First 30 Component, MessageID, Time | Format-Table -AutoSize } }
    Save-Evidence "13-boundaries"      { InSite { Get-CMBoundary | Select DisplayName, BoundaryType, Value | Format-Table -AutoSize } }
    Save-Evidence "14-boundary-groups" { InSite { Get-CMBoundaryGroup | Select Name, MemberCount, SiteSystemCount, DefaultSiteCode | Format-Table -AutoSize } }
    Save-Evidence "15-discovery"       { InSite { Get-CMDiscoveryMethod | Select ComponentName, SiteCode | Format-Table -AutoSize } }
    Save-Evidence "16-dp"              { InSite { Get-CMDistributionPoint | Select NetworkOSPath | Format-Table -AutoSize } }
    Save-Csv      "20-devices"         { InSite { Get-CMDevice | Select Name, IsClient, IsActive, ClientVersion, CoManaged, LastActiveTime, ADSiteName } }
    Save-Evidence "21-collections"     { InSite { Get-CMDeviceCollection | Where-Object { $_.CollectionID -notlike 'SMS*' } | Select Name, MemberCount, LimitToCollectionName | Format-Table -AutoSize } }
    Save-Csv      "22-applications"    { InSite { Get-CMApplication -Fast | Select LocalizedDisplayName, SoftwareVersion, NumberOfDeploymentTypes, NumberOfDeployments, IsDeployed, IsSuperseded } }
    Save-Evidence "23-deployment-types" { InSite { Get-CMApplication -Fast | ForEach-Object { $a = $_.LocalizedDisplayName; Get-CMDeploymentType -ApplicationName $a | Select @{n='App';e={$a}}, LocalizedDisplayName, Technology } | Format-Table -AutoSize } }
    Save-Evidence "24-deployments"     { InSite { Get-CMApplicationDeployment | Select ApplicationName, CollectionName, @{n='Purpose';e={if($_.OfferTypeID -eq 0){'Required'}else{'Available'}}}, DeploymentTime | Format-Table -AutoSize } }
    Save-Evidence "25-content-status"  { InSite { Get-CMDistributionStatus | Select SoftwareName, Targeted, NumberSuccess, NumberInProgress, NumberErrors | Format-Table -AutoSize } }
    Save-Evidence "26-baselines"       { InSite { Get-CMBaseline -Fast | Select LocalizedDisplayName, IsDeployed, IsEnabled | Format-Table -AutoSize } }
    Save-Evidence "30-comanagement"    { InSite { Get-CMCoManagementPolicy -ErrorAction Stop | Select Name, Description | Format-List } }
    Save-Evidence "31-comanagement-db" { sqlcmd -S $fqdn -E -W -d "CM_$SiteCode" -Q "SET NOCOUNT ON; SELECT TOP 50 Name0 AS Device, CoManaged, ComgmtPolicyPresent, MDMEnrolled FROM v_ClientCoManagementState s JOIN v_R_System r ON r.ResourceID = s.ResourceID" }

} catch {
    Set-Location $PSScriptRoot
    "FAIL  ConfigMgr section: $($_.Exception.Message)" | Out-File $script:EvidenceLog -Append
    Write-Host "ConfigMgr section stopped: $($_.Exception.Message)" -ForegroundColor Yellow
}

Save-Evidence "50-time" { Get-TimeZone; "UTC: $([DateTime]::UtcNow.ToString('s'))" }
Complete-Evidence
