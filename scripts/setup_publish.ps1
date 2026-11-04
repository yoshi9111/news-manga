# One-time setup: connect this folder to your GitHub repo and push.
# Usage: .\setup_publish.ps1 -GitHubUser yourname [-Repo news-manga] [-GaId G-XXXXXXX]
param([Parameter(Mandatory = $true)][string]$GitHubUser, [string]$Repo = 'news-manga', [string]$GaId = '')
$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $PSScriptRoot
Set-Location $base

if ($GaId) {
  if ($GaId -notmatch '^G-[A-Z0-9]+$') { throw "GA ID must look like G-XXXXXXX" }
  $cfg = "$base\site\config.js"
  $t = [IO.File]::ReadAllText($cfg, [Text.Encoding]::UTF8) -replace "gaMeasurementId: '[^']*'", "gaMeasurementId: '$GaId'"
  [IO.File]::WriteAllText($cfg, $t, (New-Object Text.UTF8Encoding $false))
  Write-Output "GA ID set: $GaId"
}

if (-not (Test-Path "$base\.git")) { git init -q -b main }
# noreply address keeps your personal email out of the public history
git config user.name $GitHubUser
git config user.email "$GitHubUser@users.noreply.github.com"
$remote = "https://github.com/$GitHubUser/$Repo.git"
if (git remote) { git remote set-url origin $remote } else { git remote add origin $remote }

& "$PSScriptRoot\build.ps1"
& "$PSScriptRoot\publish.ps1" "Initial site"
Write-Output ""
Write-Output "Next: GitHub > $Repo > Settings > Pages > Source = 'GitHub Actions'"
Write-Output "Site URL: https://$GitHubUser.github.io/$Repo/"
