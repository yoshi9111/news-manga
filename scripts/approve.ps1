# Usage: .\approve.ps1 2026-11-01   -> mark episode as approved (published) and rebuild
param([Parameter(Mandatory = $true)][string]$Date)
$base = Split-Path -Parent $PSScriptRoot
$f = "$base\episodes\$Date.json"
if (-not (Test-Path $f)) { Write-Error "not found: $f"; exit 1 }
$txt = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8)
$new = [regex]::Replace($txt, '"status"\s*:\s*"draft"', '"status": "approved"')
[IO.File]::WriteAllText($f, $new, (New-Object Text.UTF8Encoding $false))
& "$PSScriptRoot\build.ps1"
Write-Output "approved: $Date"
