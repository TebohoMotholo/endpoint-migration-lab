<#
.SYNOPSIS
    Exports Entra ID and Intune configuration and status through Microsoft Graph.
.DESCRIPTION
    Read-only. Exports policies, apps, Autopilot, Conditional Access, Endpoint analytics,
    roles and audit events to JSON and CSV, then replaces GUIDs (tenant, object, correlation IDs)
    with <guid> before zipping.
.NOTES
    Run on: any Windows PC with internet (client01 or your own PC), normal PowerShell.
    Sign in with the cloud Global Administrator when the browser opens and accept the
    read-only permissions. First run installs the Microsoft.Graph.Authentication module.
#>
. "$PSScriptRoot\Common.ps1"
$out = New-EvidenceFolder -Role "CLOUD"

if (-not (Get-Module -ListAvailable Microsoft.Graph.Authentication)) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
}
Import-Module Microsoft.Graph.Authentication
$scopes = @(
  "Directory.Read.All","User.Read.All","Group.Read.All","Organization.Read.All","Policy.Read.All",
  "DeviceManagementConfiguration.Read.All","DeviceManagementManagedDevices.Read.All",
  "DeviceManagementApps.Read.All","DeviceManagementServiceConfig.Read.All","DeviceManagementRBAC.Read.All")
Connect-MgGraph -Scopes $scopes -NoWelcome

# GET with paging
function Get-Graph {
    param([string]$Uri)
    $items = @()
    $next = $Uri
    while ($next) {
        $r = Invoke-MgGraphRequest -Method GET -Uri $next -OutputType PSObject
        if ($r.PSObject.Properties.Name -contains 'value') { $items += $r.value } else { return $r }
        $next = $r.'@odata.nextLink'
    }
    return $items
}

# Save a Graph call to JSON (and optional CSV of selected columns)
function Export-Graph {
    param([string]$Name, [string]$Uri, [object[]]$Csv)
    try {
        $data = Get-Graph $Uri
        $data | ConvertTo-Json -Depth 30 | Out-File (Join-Path $out "$Name.json") -Encoding utf8
        if ($Csv) { $data | Select-Object $Csv | Export-Csv (Join-Path $out "$Name.csv") -NoTypeInformation -Encoding utf8 }
        $count = @($data).Count
        "OK    $Name ($count)" | Out-File $script:EvidenceLog -Append -Encoding utf8
        Write-Host "OK    $Name ($count)" -ForegroundColor Green
        return $data
    } catch {
        "FAIL  $Name : $($_.Exception.Message)" | Out-File $script:EvidenceLog -Append -Encoding utf8
        Write-Host "FAIL  $Name : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# --- Tenant and identity
$org = Get-Graph "v1.0/organization"
@($org) | Select displayName, @{n='verifiedDomains';e={($_.verifiedDomains.name) -join ', '}}, onPremisesSyncEnabled, onPremisesLastSyncDateTime |
  Format-List | Out-File (Join-Path $out "00-tenant.txt") -Encoding utf8
Export-Graph "01-users"   "v1.0/users?`$select=displayName,userPrincipalName,accountEnabled,onPremisesSyncEnabled,usageLocation,assignedLicenses&`$top=999" -Csv displayName,userPrincipalName,accountEnabled,onPremisesSyncEnabled,usageLocation | Out-Null
Export-Graph "02-groups"  "v1.0/groups?`$select=displayName,groupTypes,membershipRule,securityEnabled&`$top=999" -Csv displayName,membershipRule,securityEnabled | Out-Null
Export-Graph "03-devices" "v1.0/devices?`$select=displayName,trustType,operatingSystem,operatingSystemVersion,isCompliant,isManaged,approximateLastSignInDateTime&`$top=999" -Csv displayName,trustType,operatingSystem,operatingSystemVersion,isCompliant,isManaged,approximateLastSignInDateTime | Out-Null
Export-Graph "04-conditional-access" "v1.0/identity/conditionalAccess/policies" -Csv displayName,state,createdDateTime,modifiedDateTime | Out-Null

# --- Devices
Export-Graph "10-managed-devices" "v1.0/deviceManagement/managedDevices?`$select=deviceName,operatingSystem,osVersion,complianceState,managementAgent,joinType,userPrincipalName,lastSyncDateTime,isEncrypted,ownerType" -Csv deviceName,operatingSystem,osVersion,complianceState,managementAgent,joinType,userPrincipalName,lastSyncDateTime,isEncrypted | Out-Null
Export-Graph "11-compliance-summary" "v1.0/deviceManagement/deviceCompliancePolicyDeviceStateSummary" | Out-Null

# --- Policies
Export-Graph "20-compliance-policies" "beta/deviceManagement/deviceCompliancePolicies?`$expand=assignments" -Csv displayName,'@odata.type',lastModifiedDateTime | Out-Null
Export-Graph "21-device-configurations" "beta/deviceManagement/deviceConfigurations?`$expand=assignments" -Csv displayName,'@odata.type',lastModifiedDateTime | Out-Null
$cp = Export-Graph "22-settings-catalog-and-endpoint-security" "beta/deviceManagement/configurationPolicies?`$expand=assignments,settings" -Csv name,platforms,technologies,lastModifiedDateTime,settingCount
if ($cp) {
    $cp | Select name, platforms, settingCount, lastModifiedDateTime, @{n='family';e={$_.templateReference.templateFamily}}, @{n='template';e={$_.templateReference.templateDisplayName}} |
      Export-Csv (Join-Path $out "22b-policies-by-family.csv") -NoTypeInformation -Encoding utf8
    $cp | Where-Object { $_.templateReference.templateFamily -like '*PrivilegeManagement*' } |
      ConvertTo-Json -Depth 30 | Out-File (Join-Path $out "23-epm-policies.json") -Encoding utf8
}
Export-Graph "24-endpoint-security-intents" "beta/deviceManagement/intents" -Csv displayName,templateId,lastModifiedDateTime | Out-Null
Export-Graph "25-gp-analytics" "beta/deviceManagement/groupPolicyMigrationReports" -Csv displayName,migrationReadiness,supportedSettingsPercent,supportedSettingsCount,totalSettingsCount | Out-Null
Export-Graph "26-feature-update-profiles" "beta/deviceManagement/windowsFeatureUpdateProfiles" -Csv displayName,featureUpdateVersion,lastModifiedDateTime | Out-Null
Export-Graph "27-quality-update-policies" "beta/deviceManagement/windowsQualityUpdatePolicies" -Csv displayName,lastModifiedDateTime | Out-Null
Export-Graph "28-driver-update-profiles" "beta/deviceManagement/windowsDriverUpdateProfiles" -Csv displayName,approvalType | Out-Null

# --- Apps
$apps = Export-Graph "30-apps" "beta/deviceAppManagement/mobileApps" -Csv displayName,'@odata.type',publisher,lastModifiedDateTime
if ($apps) {
    $win32 = $apps | Where-Object { $_.'@odata.type' -match 'win32' }
    $detail = foreach ($a in $win32) { Get-Graph "beta/deviceAppManagement/mobileApps/$($a.id)?`$expand=assignments" }
    $detail | ConvertTo-Json -Depth 30 | Out-File (Join-Path $out "31-win32-apps-detail.json") -Encoding utf8
    $detail | Select displayName, installCommandLine, uninstallCommandLine, setupFilePath,
        @{n='detection';e={($_.rules + $_.detectionRules | Where-Object { $_ } | ForEach-Object { "$($_.'@odata.type' -replace '#microsoft.graph.','') $($_.path)$($_.fileOrFolderName)$($_.productCode)" }) -join ' | '}},
        @{n='assignments';e={($_.assignments | ForEach-Object { $_.intent }) -join ', '}} |
      Export-Csv (Join-Path $out "31b-win32-apps.csv") -NoTypeInformation -Encoding utf8
    Write-Host "OK    31-win32-apps-detail" -ForegroundColor Green
}
Export-Graph "32-app-protection" "beta/deviceAppManagement/managedAppPolicies" -Csv displayName,'@odata.type',lastModifiedDateTime | Out-Null

# --- Enrollment and Autopilot
Export-Graph "40-autopilot-devices" "beta/deviceManagement/windowsAutopilotDeviceIdentities" -Csv serialNumber,groupTag,enrollmentState,deploymentProfileAssignmentStatus,lastContactedDateTime | Out-Null
Export-Graph "41-autopilot-profiles" "beta/deviceManagement/windowsAutopilotDeploymentProfiles?`$expand=assignments" -Csv displayName,deviceNameTemplate,'@odata.type' | Out-Null
Export-Graph "42-enrollment-configurations" "beta/deviceManagement/deviceEnrollmentConfigurations" -Csv displayName,'@odata.type',priority | Out-Null

# --- Intune Suite and tools
Export-Graph "50-remote-help-settings" "beta/deviceManagement/remoteAssistanceSettings" | Out-Null
Export-Graph "51-role-definitions" "beta/deviceManagement/roleDefinitions" -Csv displayName,isBuiltIn,description | Out-Null
Export-Graph "52-role-assignments" "beta/deviceManagement/roleAssignments" -Csv displayName,description | Out-Null
Export-Graph "53-epm-elevations" "beta/deviceManagement/privilegeManagementElevations?`$top=200" -Csv deviceName,upn,fileName,elevationType,result,eventDateTime | Out-Null
Export-Graph "54-tunnel-sites" "beta/deviceManagement/microsoftTunnelSites" -Csv displayName,publicAddress | Out-Null
Export-Graph "55-tunnel-configs" "beta/deviceManagement/microsoftTunnelConfigurations" -Csv displayName,network,dnsServers | Out-Null

# --- Endpoint analytics
Export-Graph "60-ea-overview" "beta/deviceManagement/userExperienceAnalyticsOverview" | Out-Null
Export-Graph "61-ea-device-scores" "beta/deviceManagement/userExperienceAnalyticsDeviceScores" -Csv deviceName,endpointAnalyticsScore,startupPerformanceScore,appReliabilityScore,workFromAnywhereScore,healthStatus | Out-Null
Export-Graph "62-ea-startup" "beta/deviceManagement/userExperienceAnalyticsDevicePerformance" -Csv deviceName,coreBootTimeInMs,coreLoginTimeInMs,averageBlueScreens,startupPerformanceScore | Out-Null
Export-Graph "63-ea-app-health" "beta/deviceManagement/userExperienceAnalyticsAppHealthApplicationPerformance" -Csv appDisplayName,appCrashCount,appHangCount,activeDeviceCount,appHealthScore | Out-Null

# --- Audit trail (who changed what)
Export-Graph "70-intune-audit" "beta/deviceManagement/auditEvents?`$top=200" -Csv activityDateTime,activity,activityResult,componentName,@{n='actor';e={$_.actor.userPrincipalName}} | Out-Null

Disconnect-MgGraph | Out-Null
Complete-Evidence
