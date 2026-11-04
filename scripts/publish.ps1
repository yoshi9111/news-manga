# Commit site + approved episodes and push to GitHub (GitHub Actions deploys site/ to Pages)
param([string]$Message = "Update site")
$base = Split-Path -Parent $PSScriptRoot
Set-Location $base
if (-not (Test-Path "$base\.git")) { Write-Output 'not a git repo yet - run scripts\setup_publish.ps1 first'; exit 1 }

Get-ChildItem "$base\episodes\*.json" | ForEach-Object {
  $o = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8) | ConvertFrom-Json
  if ($o.status -eq 'approved') { git add -f -- "episodes/$($_.Name)" }
}
git add -- site scripts README.md .gitignore .github seen.txt
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) { Write-Output 'nothing to publish'; exit 0 }
git commit -q -m $Message
if ($LASTEXITCODE -ne 0) { exit 1 }
git push -q origin main
if ($LASTEXITCODE -ne 0) { Write-Output 'git push failed'; exit 1 }
Write-Output "published: $Message"
exit 0
