# Post one approved episode's comic image to X (API v2, OAuth 1.0a user context).
# Usage: post_x.ps1 [-Date yyyy-MM-dd] [-DryRun]
# Text has no URL on purpose (posts with URLs cost more on pay-per-use).
param([string]$Date = (Get-Date -Format 'yyyy-MM-dd'), [switch]$DryRun)
$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding $false
$posted = "$base\logs\x_posted.txt"

$ep = "$base\episodes\$Date.json"
if (-not (Test-Path $ep)) { Write-Output "no episode for $Date"; exit 0 }
$obj = [IO.File]::ReadAllText($ep, [Text.Encoding]::UTF8) | ConvertFrom-Json
if ($obj.status -ne 'approved') { Write-Output "not approved: $Date"; exit 0 }
if ((Test-Path $posted) -and ((Get-Content $posted) -contains $Date)) { Write-Output "already posted: $Date"; exit 0 }

# 1. Render the comic to PNG with headless Chrome, then crop the white margin
$dir = "$base\logs\x"; New-Item -ItemType Directory -Force $dir | Out-Null
$raw = "$dir\$Date.raw.png"; $png = "$dir\$Date.png"
$chrome = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe", "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $chrome) { throw 'Chrome not found' }
$url = 'file:///' + ("$PSScriptRoot\shot.html" -replace '\\', '/') + "?ep=$Date&preview"
Remove-Item $raw -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $chrome -PassThru -WindowStyle Hidden -ArgumentList @('--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files',
  '--force-device-scale-factor=2', '--window-size=460,2000', '--virtual-time-budget=8000', "--screenshot=$raw", $url)
$p.WaitForExit(60000) | Out-Null
if (-not (Test-Path $raw)) { throw 'screenshot failed' }
Add-Type -AssemblyName System.Drawing
$bmp = [Drawing.Bitmap]::FromFile($raw)
$h = $bmp.Height
for ($y = $bmp.Height - 1; $y -ge 0; $y--) {
  $blank = $true
  for ($x = 0; $x -lt $bmp.Width; $x += 4) { $c = $bmp.GetPixel($x, $y); if ($c.R -lt 250 -or $c.G -lt 250 -or $c.B -lt 250) { $blank = $false; break } }
  if (-not $blank) { $h = [Math]::Min($bmp.Height, $y + 24); break }
}
$crop = $bmp.Clone((New-Object Drawing.Rectangle 0, 0, $bmp.Width, $h), $bmp.PixelFormat)
$crop.Save($png, [Drawing.Imaging.ImageFormat]::Png); $crop.Dispose(); $bmp.Dispose()
Remove-Item $raw

# 2. Post text
$tag = ($obj.tag -replace '[\s・/]', '')
$text = "【4コマ厚労ニュース】$($obj.title)`n`n薬剤師のヤク先生が、厚労省の発表を4コマで解説。`n#厚労省 #$tag #薬剤師"
if ($DryRun) { Write-Output "DRY RUN`n$text`nimage: $png"; exit 0 }

# 3. OAuth 1.0a
$keyFile = "$env:USERPROFILE\.news_manga\x_keys.dat"
if (-not (Test-Path $keyFile)) { throw 'X keys not saved (run scripts\save_x_keys.ps1)' }
$sec = Get-Content $keyFile | ConvertTo-SecureString
$k = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)) | ConvertFrom-Json
function Enc([string]$s) { [Uri]::EscapeDataString($s) }
function AuthHeader([string]$method, [string]$u) {
  $o = [ordered]@{
    oauth_consumer_key = $k.ck; oauth_nonce = [Guid]::NewGuid().ToString('N'); oauth_signature_method = 'HMAC-SHA1'
    oauth_timestamp = [string][int][double]::Parse((Get-Date -UFormat %s)); oauth_token = $k.at; oauth_version = '1.0'
  }
  $ps = ($o.Keys | Sort-Object | ForEach-Object { "$(Enc $_)=$(Enc $o[$_])" }) -join '&'
  $baseStr = "$method&$(Enc $u)&$(Enc $ps)"
  $hmac = New-Object Security.Cryptography.HMACSHA1 (,$utf8.GetBytes("$(Enc $k.cs)&$(Enc $k.as)"))
  $o['oauth_signature'] = [Convert]::ToBase64String($hmac.ComputeHash($utf8.GetBytes($baseStr)))
  'OAuth ' + (($o.Keys | ForEach-Object { "$(Enc $_)=`"$(Enc $o[$_])`"" }) -join ', ')
}
function Send([string]$u, [string]$ctype, [byte[]]$body) {
  $req = [Net.HttpWebRequest]::Create($u); $req.Method = 'POST'; $req.ContentType = $ctype
  $req.Headers.Add('Authorization', (AuthHeader 'POST' $u))
  $s = $req.GetRequestStream(); $s.Write($body, 0, $body.Length); $s.Close()
  try { $res = $req.GetResponse() } catch [Net.WebException] {
    $r = $_.Exception.Response; if (-not $r) { throw }
    $msg = (New-Object IO.StreamReader($r.GetResponseStream())).ReadToEnd(); throw "HTTP $([int]$r.StatusCode) $u : $msg"
  }
  (New-Object IO.StreamReader($res.GetResponseStream(), [Text.Encoding]::UTF8)).ReadToEnd() | ConvertFrom-Json
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 4. Upload image (multipart; multipart fields are not part of the OAuth signature)
$bd = [Guid]::NewGuid().ToString('N')
$ms = New-Object IO.MemoryStream
$w = { param($t) $b = $utf8.GetBytes($t); $ms.Write($b, 0, $b.Length) }
& $w "--$bd`r`nContent-Disposition: form-data; name=`"media_category`"`r`n`r`ntweet_image`r`n"
& $w "--$bd`r`nContent-Disposition: form-data; name=`"media_type`"`r`n`r`nimage/png`r`n"
& $w "--$bd`r`nContent-Disposition: form-data; name=`"media`"; filename=`"$Date.png`"`r`nContent-Type: image/png`r`n`r`n"
$img = [IO.File]::ReadAllBytes($png); $ms.Write($img, 0, $img.Length)
& $w "`r`n--$bd--`r`n"
$up = Send 'https://api.x.com/2/media/upload' "multipart/form-data; boundary=$bd" $ms.ToArray()
$mediaId = if ($up.data.id) { $up.data.id } else { $up.media_id_string }
if (-not $mediaId) { throw "upload: no media id: $($up | ConvertTo-Json -Compress)" }

# 5. Post
$payload = @{ text = $text; media = @{ media_ids = @([string]$mediaId) } } | ConvertTo-Json -Compress -Depth 4
$tw = Send 'https://api.x.com/2/tweets' 'application/json' $utf8.GetBytes($payload)
[IO.File]::AppendAllText($posted, "$Date`n", $utf8)
Write-Output "posted: https://x.com/i/status/$($tw.data.id)"
