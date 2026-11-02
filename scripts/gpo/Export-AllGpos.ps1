<#
.SYNOPSIS
    Exports every GPO as XML (for Intune Group Policy analytics), an HTML report,
    a CSV list and a full GPO backup.
.NOTES
    Run on: DC01, elevated.
    Intune Group Policy analytics rejects XML files over 4 MB.
#>

$out = "C:\GPOExport"
New-Item -ItemType Directory -Path "$out\xml","$out\backup" -Force | Out-Null

Get-GPO -All | Select-Object DisplayName, GpoStatus, CreationTime, ModificationTime |
    Export-Csv "$out\gpo-list.csv" -NoTypeInformation

Get-GPOReport -All -ReportType Html -Path "$out\all-gpos.html"

Get-GPO -All | ForEach-Object {
    $safe = ($_.DisplayName -replace '[\\/:*?"<>|]', '_')
    Get-GPOReport -Guid $_.Id -ReportType Xml -Path "$out\xml\$safe.xml"
}

Backup-GPO -All -Path "$out\backup" | Out-Null

Get-ChildItem "$out\xml" | Select-Object Name, @{n='KB';e={[math]::Round($_.Length/1KB,1)}}
