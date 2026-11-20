<#
  Shared helpers for the evidence scripts. Dot-sourced by each Collect-*.ps1.
  Every command's output is saved to a text file; failures are logged, never fatal.
#>

function New-EvidenceFolder {
    param([string]$Role)
    $root = Join-Path $PSScriptRoot "output\$Role-$env:COMPUTERNAME-$(Get-Date -Format yyyyMMdd-HHmm)"
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $script:EvidenceRoot = $root
    $script:EvidenceLog  = Join-Path $root "_run-log.txt"
    "Evidence run: $Role on $env:COMPUTERNAME at $(Get-Date -Format s)" | Out-File $script:EvidenceLog -Encoding utf8
    "Run as: $(whoami)" | Out-File $script:EvidenceLog -Append -Encoding utf8
    return $root
}

# Run a script block, save its output as text. Name becomes the file name.
function Save-Evidence {
    param([string]$Name, [scriptblock]$Command)
    $file = Join-Path $script:EvidenceRoot "$Name.txt"
    try {
        $header = "# $Name`r`n# Command: $($Command.ToString().Trim())`r`n# Collected: $(Get-Date -Format s) on $env:COMPUTERNAME`r`n"
        $body = & $Command 2>&1 | Out-String -Width 250
        ($header + "`r`n" + $body) | Out-File $file -Encoding utf8
        "OK    $Name" | Out-File $script:EvidenceLog -Append -Encoding utf8
        Write-Host "OK    $Name" -ForegroundColor Green
    } catch {
        "FAIL  $Name : $($_.Exception.Message)" | Out-File $script:EvidenceLog -Append -Encoding utf8
        Write-Host "FAIL  $Name : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Save objects as CSV
function Save-Csv {
    param([string]$Name, [scriptblock]$Command)
    $file = Join-Path $script:EvidenceRoot "$Name.csv"
    try {
        & $Command | Export-Csv $file -NoTypeInformation -Encoding utf8
        "OK    $Name.csv" | Out-File $script:EvidenceLog -Append -Encoding utf8
        Write-Host "OK    $Name.csv" -ForegroundColor Green
    } catch {
        "FAIL  $Name.csv : $($_.Exception.Message)" | Out-File $script:EvidenceLog -Append -Encoding utf8
        Write-Host "FAIL  $Name.csv : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Replace GUIDs (tenant, object, correlation IDs) and recovery keys in all text output
function Protect-EvidenceFolder {
    $guid = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
    $bitlockerKey = '\b\d{6}(-\d{6}){7}\b'
    Get-ChildItem $script:EvidenceRoot -Recurse -Include *.txt,*.csv,*.json,*.html,*.xml | ForEach-Object {
        $t = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
        if ($t) {
            $t = [regex]::Replace($t, $guid, '<guid>')
            $t = [regex]::Replace($t, $bitlockerKey, '<recovery-key>')
            Set-Content -Path $_.FullName -Value $t -Encoding utf8
        }
    }
}

function Complete-Evidence {
    param([switch]$NoRedact)
    if (-not $NoRedact) { Protect-EvidenceFolder }
    $zip = "$script:EvidenceRoot.zip"
    Compress-Archive -Path "$script:EvidenceRoot\*" -DestinationPath $zip -Force
    Write-Host ""
    Write-Host "Done. Send this file: $zip" -ForegroundColor Cyan
}

function Test-IsAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
