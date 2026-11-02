<#
.SYNOPSIS
    Forces the ConfigMgr client to fetch policy and evaluate app deployments.
.NOTES
    Run on: a ConfigMgr client, elevated.
    Same as Control Panel, Configuration Manager, Actions.
#>

$schedules = @{
    "Machine Policy Retrieval & Evaluation" = "{00000000-0000-0000-0000-000000000021}"
    "Machine Policy Evaluation"             = "{00000000-0000-0000-0000-000000000022}"
    "Application Deployment Evaluation"     = "{00000000-0000-0000-0000-000000000121}"
}

foreach ($name in $schedules.Keys) {
    Invoke-CimMethod -Namespace root\ccm -ClassName SMS_Client -MethodName TriggerSchedule `
        -Arguments @{ sScheduleID = $schedules[$name] } | Out-Null
    Write-Host "Triggered: $name"
}

"--- Client health"
Get-Service ccmexec | Select-Object Status, Name
Get-CimInstance -Namespace root\ccm -ClassName SMS_Authority | Select-Object Name, CurrentManagementPoint
