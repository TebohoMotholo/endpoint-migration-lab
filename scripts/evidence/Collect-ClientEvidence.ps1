<#
.SYNOPSIS
    Collects device-side evidence: join state, policies, apps, security, co-management.
.NOTES
    Run on: each Windows 11 client (client02 is the most important), in Windows PowerShell
    AS ADMINISTRATOR, while a synced test user is signed in to the machine.
    Then run Collect-ClientUserEvidence.ps1 in a NORMAL (not elevated) window as that user.
    Read-only.
#>
. "$PSScriptRoot\Common.ps1"
if (-not (Test-IsAdmin)) { Write-Warning "Run this as administrator."; return }
$out = New-EvidenceFolder -Role "CLIENT"

Save-Evidence "01-system"        { Get-ComputerInfo -Property CsName, OsName, OsVersion, OsBuildNumber, CsDomain, WindowsRegisteredOrganization | Format-List }
Save-Evidence "02-dsregcmd"      { dsregcmd /status }
Save-Evidence "03-network"       { ipconfig /all }
Save-Evidence "04-time"          { Get-TimeZone; "UTC: $([DateTime]::UtcNow.ToString('s'))"; w32tm /query /source }

# Group Policy (before / after migration)
Save-Evidence "10-gpresult"      { gpresult /r /scope computer }
try { gpresult /h (Join-Path $out "11-gpresult.html") /f | Out-Null; Write-Host "OK    11-gpresult.html" -ForegroundColor Green } catch {}

# Intune / MDM
Save-Evidence "20-mdm-enrollments" { Get-ChildItem HKLM:\SOFTWARE\Microsoft\Enrollments | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.ProviderID } | Select ProviderID, UPN, EnrollmentType, EnrollmentState | Format-Table -AutoSize }
Save-Evidence "21-policy-manager"  { Get-ChildItem HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device | Select -Expand PSChildName }
Save-Evidence "22-update-policy"   { Get-ItemProperty HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update -ErrorAction Stop | Format-List }
Save-Evidence "23-whfb-policy"     { Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Policies\PassportForWork" -Recurse -ErrorAction SilentlyContinue | Get-ItemProperty | Select PSPath, Enabled, UsePassportForWork, UseCloudTrustForOnPremAuth | Format-List }
Save-Evidence "24-ime-apps"        { Get-ChildItem "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Property -contains 'ComplianceStateMessage' } | ForEach-Object { (Get-ItemProperty $_.PSPath).ComplianceStateMessage } }
try {
    $diag = Join-Path $out "25-mdm-diagnostics.zip"
    Start-Process mdmdiagnosticstool.exe -ArgumentList "-area DeviceEnrollment;DeviceProvisioning;Autopilot -zip `"$diag`"" -Wait -NoNewWindow
    Write-Host "OK    25-mdm-diagnostics.zip" -ForegroundColor Green
} catch { Write-Host "FAIL  mdm diagnostics" -ForegroundColor Yellow }

# Configuration Manager client and co-management
Save-Evidence "30-ccm-client"    { Get-CimInstance -Namespace root\ccm -ClassName SMS_Client | Select ClientVersion | Format-List; Get-CimInstance -Namespace root\ccm -ClassName SMS_Authority | Select Name, CurrentManagementPoint | Format-List }
Save-Evidence "31-comanagement"  { Get-Content "C:\Windows\CCM\Logs\CoManagementHandler.log" -Tail 60 -ErrorAction Stop }
Save-Evidence "32-ccm-apps"      { Get-CimInstance -Namespace root\ccm\ClientSDK -ClassName CCM_Application | Select Name, InstallState, ApplicabilityState | Format-Table -AutoSize }

# Software
Save-Csv "40-installed-software" {
    Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
      Where-Object DisplayName | Select DisplayName, DisplayVersion, Publisher, InstallDate | Sort DisplayName }

# Security
Save-Evidence "50-local-admins"  { Get-LocalGroupMember -Group Administrators | Select Name, PrincipalSource, ObjectClass | Format-Table -AutoSize }
Save-Evidence "51-bitlocker"     { manage-bde -status C: }
Save-Evidence "52-bitlocker-protectors" { (Get-BitLockerVolume -MountPoint C:).KeyProtector | Select KeyProtectorType | Format-Table }
Save-Evidence "53-defender"      { Get-MpComputerStatus | Select AMRunningMode, AntivirusEnabled, RealTimeProtectionEnabled, AMProductVersion, AntivirusSignatureLastUpdated, IsTamperProtected | Format-List }
Save-Evidence "54-mde-onboarding"{ Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows Advanced Threat Protection\Status" -ErrorAction Stop | Select OnboardingState, LastConnected | Format-List }
Save-Evidence "55-asr-rules"     { $p = Get-MpPreference; for ($i=0; $i -lt $p.AttackSurfaceReductionRules_Ids.Count; $i++) { "{0}  action={1}" -f $p.AttackSurfaceReductionRules_Ids[$i], $p.AttackSurfaceReductionRules_Actions[$i] } }
Save-Evidence "56-firewall"      { Get-NetFirewallProfile | Select Name, Enabled, DefaultInboundAction, DefaultOutboundAction | Format-Table -AutoSize }
Save-Evidence "57-laps"          { Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\LAPS\State" -ErrorAction Stop | Format-List }
Save-Evidence "58-epm"           { Get-Service -Name "EPMAgent*","Microsoft EPM*" -ErrorAction SilentlyContinue | Select Name, Status; Get-ChildItem "C:\Program Files\Microsoft EPM Agent" -ErrorAction SilentlyContinue | Select Name }
Save-Evidence "59-secure-boot"   { Confirm-SecureBootUEFI; Get-Tpm | Select TpmPresent, TpmReady | Format-List }

Complete-Evidence
