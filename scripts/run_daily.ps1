# Daily: RSS -> Claude writes draft -> second Claude verifies -> approve + build + publish (git push)
# Failed verification keeps it as a draft and opens the log in Notepad.
param([string]$Date = (Get-Date -Format 'yyyy-MM-dd'), [switch]$NoOpen, [switch]$NoPublish)
$ErrorActionPreference = 'Continue'
$base = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding $false
New-Item -ItemType Directory -Force "$base\logs" | Out-Null
$log = "$base\logs\$Date.log"
function Log($m) { Add-Content -Path $log -Value ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m) -Encoding UTF8 }
function Fail($m) { Log "FAILED: $m"; if (-not $NoOpen) { Start-Process notepad.exe $log }; exit 1 }
$claude = "$env:USERPROFILE\.local\bin\claude.exe"
# Long-lived token (scripts\save_token.ps1) so the job survives normal login expiry
$tokFile = "$env:USERPROFILE\.news_manga\claude_token.dat"
if (Test-Path $tokFile) {
  try {
    $sec = Get-Content $tokFile | ConvertTo-SecureString
    $env:CLAUDE_CODE_OAUTH_TOKEN = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
  } catch { Log "token load failed: $_" }
}
$pdfTool = "Bash(powershell -NoProfile -ExecutionPolicy Bypass -File scripts/fetch_pdf.ps1:*)"
Set-Location $base

$ep = "$base\episodes\$Date.json"
if (-not (Test-Path $ep)) {
  # 1. RSS (decode as UTF-8 explicitly; PS5.1 guesses wrong)
  try {
    $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 30 'https://www.mhlw.go.jp/stf/news.rdf'
    $raw = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())
  } catch { Fail "RSS fetch: $_" }

  $seen = @()
  if (Test-Path "$base\seen.txt") { $seen = [IO.File]::ReadAllLines("$base\seen.txt", [Text.Encoding]::UTF8) }
  $exclude = ([IO.File]::ReadAllLines("$PSScriptRoot\exclude_words.txt", [Text.Encoding]::UTF8) |
    Where-Object { $_.Trim() -and -not $_.StartsWith('#') }) -join '|'
  $since = (Get-Date $Date).AddDays(-7).ToString('yyyy-MM-dd')
  $cands = @()
  foreach ($m in [regex]::Matches($raw, '(?s)<item rdf:about="([^"]+)">.*?CDATA\[(.*?)\]\]>.*?<dc:date>(\d{4}-\d{2}-\d{2})')) {
    $url = $m.Groups[1].Value; $title = $m.Groups[2].Value.Trim(); $d = $m.Groups[3].Value
    if ($d -lt $since -or $d -gt $Date) { continue }
    if ($seen -contains $url) { continue }
    if ($exclude -and $title -match $exclude) { continue }
    $cands += "- [$d] $title | $url"
  }
  Log ("candidates: {0}" -f $cands.Count)
  if ($cands.Count -eq 0) { Log 'no candidates'; exit 0 }

  # 2. Write
  $tpl = [IO.File]::ReadAllText("$PSScriptRoot\prompt_template.md", [Text.Encoding]::UTF8)
  $prompt = $tpl.Replace('{{DATE}}', $Date).Replace('{{CANDIDATES}}', ($cands | Select-Object -First 40) -join "`n")
  [IO.File]::WriteAllText("$base\logs\prompt_$Date.md", $prompt, $utf8)
  Log 'writing (claude)'
  & $claude -p "Read the file logs/prompt_$Date.md and follow its instructions exactly." `
    --permission-mode acceptEdits --allowedTools "WebFetch" "Read" "Write" $pdfTool `
    --max-turns 40 *>&1 | Out-File -Append -Encoding utf8 $log
  if (-not (Test-Path $ep)) { Fail 'no episode written' }
}

# 3. Validate JSON, remember source
try {
  $obj = [IO.File]::ReadAllText($ep, [Text.Encoding]::UTF8) | ConvertFrom-Json
  if (@($obj.panels).Count -ne 4) { throw ("panels = {0}" -f @($obj.panels).Count) }
} catch { Fail "invalid episode: $_" }
if ($obj.source.url -and -not ((Get-Content "$base\seen.txt" -Encoding UTF8 -ErrorAction SilentlyContinue) -contains $obj.source.url)) {
  [IO.File]::AppendAllText("$base\seen.txt", $obj.source.url + "`n", $utf8)
}
if ($obj.status -eq 'approved') { Log 'already approved' }
else {
  # 4. Verify with a separate Claude run; the episode file must not change
  $hash = (Get-FileHash $ep).Hash
  $vfile = "$base\logs\verify_$Date.json"
  Remove-Item $vfile -ErrorAction SilentlyContinue
  $vtpl = [IO.File]::ReadAllText("$PSScriptRoot\verify_template.md", [Text.Encoding]::UTF8)
  [IO.File]::WriteAllText("$base\logs\verifyprompt_$Date.md", $vtpl.Replace('{{DATE}}', $Date), $utf8)
  Log 'verifying (claude)'
  & $claude -p "Read the file logs/verifyprompt_$Date.md and follow its instructions exactly." `
    --permission-mode acceptEdits --allowedTools "WebFetch" "Read" "Write" $pdfTool `
    --max-turns 40 *>&1 | Out-File -Append -Encoding utf8 $log
  if ((Get-FileHash $ep).Hash -ne $hash) { Fail 'episode was modified during verification' }
  if (-not (Test-Path $vfile)) { Fail 'no verification result' }
  try { $v = [IO.File]::ReadAllText($vfile, [Text.Encoding]::UTF8) | ConvertFrom-Json } catch { Fail "bad verify json: $_" }
  Log ("verify: pass={0} checked={1} issues={2}" -f $v.pass, $v.checked, (@($v.issues) -join ' / '))
  if ($v.pass -ne $true) {
    & "$PSScriptRoot\build.ps1" *>&1 | Out-File -Append -Encoding utf8 $log
    Fail 'verification failed - kept as draft'
  }
  & "$PSScriptRoot\approve.ps1" $Date *>&1 | Out-File -Append -Encoding utf8 $log
}

# 5. Publish
& "$PSScriptRoot\build.ps1" *>&1 | Out-File -Append -Encoding utf8 $log
if (-not $NoPublish) {
  & "$PSScriptRoot\publish.ps1" "Add episode $Date" *>&1 | Out-File -Append -Encoding utf8 $log
  if ($LASTEXITCODE -ne 0) { Fail 'publish failed' }
}
Log 'done'
