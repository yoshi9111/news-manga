# View counts per episode from Google Analytics (GA4 Data API, service account).
# Needs (outside the repo):
#   %USERPROFILE%\.news_manga\ga_key.json      service account JSON key (GA property: 閲覧者)
#   %USERPROFILE%\.news_manga\ga_property.txt  numeric GA4 property ID
param([string]$Since = '2026-11-01')
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$base = Split-Path -Parent $PSScriptRoot
$cfg = "$env:USERPROFILE\.news_manga"
if (-not (Test-Path "$cfg\ga_key.json") -or -not (Test-Path "$cfg\ga_property.txt")) {
  Write-Host "未設定です: $cfg に ga_key.json と ga_property.txt が必要です。" -ForegroundColor Red; exit 1
}
$key = [IO.File]::ReadAllText("$cfg\ga_key.json") | ConvertFrom-Json
$prop = ([IO.File]::ReadAllText("$cfg\ga_property.txt")).Trim()

function B64Url([byte[]]$b) { [Convert]::ToBase64String($b).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
function Utf8([string]$s) { [Text.Encoding]::UTF8.GetBytes($s) }

# 1. Access token (JWT bearer, RS256)
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$hdr = B64Url (Utf8 '{"alg":"RS256","typ":"JWT"}')
$clm = B64Url (Utf8 (@{ iss = $key.client_email; scope = 'https://www.googleapis.com/auth/analytics.readonly'
      aud = $key.token_uri; iat = $now; exp = $now + 3600 } | ConvertTo-Json -Compress))
$pem = $key.private_key -replace '-----[A-Z ]+-----', '' -replace '\s', ''
$cng = [Security.Cryptography.CngKey]::Import([Convert]::FromBase64String($pem), [Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob)
$rsa = New-Object Security.Cryptography.RSACng $cng
$sig = $rsa.SignData((Utf8 "$hdr.$clm"), [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
$tok = (Invoke-RestMethod -Method Post -Uri $key.token_uri -ContentType 'application/x-www-form-urlencoded' `
  -Body @{ grant_type = 'urn:ietf:params:oauth:grant-type:jwt-bearer'; assertion = "$hdr.$clm.$(B64Url $sig)" }).access_token
$auth = @{ Authorization = "Bearer $tok" }

function Report($body, $kind = 'runReport') {
  Invoke-RestMethod -Method Post -Headers $auth -ContentType 'application/json; charset=utf-8' `
    -Uri "https://analyticsdata.googleapis.com/v1beta/properties/${prop}:$kind" -Body (Utf8 ($body | ConvertTo-Json -Depth 10 -Compress))
}
function EpOf($path) { if ($path -match 'ep=(\d{4}-\d{2}-\d{2})') { $Matches[1] } else { 'その他' } }

# 2. Views/users per page, image saves per page, realtime users
$range = @(@{ startDate = $Since; endDate = 'today' })
$pv = Report @{ dateRanges = $range; dimensions = @(@{ name = 'pagePathPlusQueryString' })
  metrics = @(@{ name = 'screenPageViews' }, @{ name = 'totalUsers' }); limit = 1000 }
$sv = Report @{ dateRanges = $range; dimensions = @(@{ name = 'pagePathPlusQueryString' }); metrics = @(@{ name = 'eventCount' })
  dimensionFilter = @{ filter = @{ fieldName = 'eventName'; stringFilter = @{ value = 'save_image' } } }; limit = 1000 }
$rt = Report @{ metrics = @(@{ name = 'activeUsers' }) } 'runRealtimeReport'

$stat = @{}
function Slot($ep) { if (-not $stat.ContainsKey($ep)) { $stat[$ep] = @{ v = 0; u = 0; s = 0 } }; $stat[$ep] }
foreach ($r in @($pv.rows)) { if ($r) { $x = Slot (EpOf $r.dimensionValues[0].value); $x.v += [int]$r.metricValues[0].value; $x.u += [int]$r.metricValues[1].value } }
foreach ($r in @($sv.rows)) { if ($r) { $x = Slot (EpOf $r.dimensionValues[0].value); $x.s += [int]$r.metricValues[0].value } }

$titles = @{}
Get-ChildItem "$base\episodes\*.json" | ForEach-Object {
  $e = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8) | ConvertFrom-Json
  if ($e.status -eq 'approved') { $titles[$e.date] = $e.title; [void](Slot $e.date) }
}
$rows = $stat.Keys | Sort-Object -Descending | ForEach-Object {
  [pscustomobject]@{ 日付 = $_; view = $stat[$_].v; 人数 = $stat[$_].u; 保存 = $stat[$_].s; タイトル = $titles[$_] }
}
$tv = ($rows | Measure-Object view -Sum).Sum
$rtUsers = if ($rt.rows) { $rt.rows[0].metricValues[0].value } else { 0 }
$out = @("集計: $Since 〜 今日（GAの通常集計は反映に最大1〜2日かかります）",
  "合計 view: $tv ／ いま見ている人(直近30分): $rtUsers", '') + ($rows | Format-Table -AutoSize | Out-String -Width 200).TrimEnd()
$out | Write-Output
New-Item -ItemType Directory -Force "$base\logs" | Out-Null
[IO.File]::WriteAllText("$base\logs\views.txt", ($out -join "`r`n"), (New-Object Text.UTF8Encoding $true))
