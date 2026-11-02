<#
.SYNOPSIS
    Packages every app folder under C:\Pkg into .intunewin files.
.NOTES
    Layout expected:
      C:\Pkg\IntuneWinAppUtil.exe
      C:\Pkg\<App>\src\<installer>   (one installer per src folder, nothing else)
      C:\Pkg\out\
    Get IntuneWinAppUtil.exe from Microsoft's Win32 Content Prep Tool on GitHub.
#>

$root = "C:\Pkg"
$tool = Join-Path $root "IntuneWinAppUtil.exe"
$out  = Join-Path $root "out"

if (-not (Test-Path $tool)) { throw "IntuneWinAppUtil.exe not found in $root" }
Unblock-File $tool
New-Item -ItemType Directory -Path $out -Force | Out-Null

Get-ChildItem $root -Directory | Where-Object { Test-Path (Join-Path $_.FullName "src") } | ForEach-Object {
    $src = Join-Path $_.FullName "src"
    $setup = Get-ChildItem $src -File | Where-Object Extension -in ".msi",".exe",".ps1" | Select-Object -First 1
    if (-not $setup) { Write-Warning "No installer in $src"; return }
    Write-Host "Packaging $($_.Name): $($setup.Name)"
    & $tool -c $src -s $setup.Name -o $out -q
}

Get-ChildItem $out -Filter *.intunewin | Select-Object Name, @{n='MB';e={[math]::Round($_.Length/1MB,1)}}
