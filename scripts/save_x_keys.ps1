# Store X API keys (OAuth 1.0a, Read and Write) for the daily auto-post.
# Encrypted with Windows DPAPI: only this Windows user on this PC can decrypt it.
$dir = "$env:USERPROFILE\.news_manga"
New-Item -ItemType Directory -Force $dir | Out-Null
$names = @('API Key (Consumer Key)', 'API Key Secret (Consumer Secret)', 'Access Token', 'Access Token Secret')
$vals = @()
foreach ($n in $names) {
  $s = Read-Host -AsSecureString "$n を貼り付けて Enter"
  if ($s.Length -lt 10) { Write-Host "$n が短すぎます。やり直してください。" -ForegroundColor Red; exit 1 }
  $vals += [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
}
$json = @{ ck = $vals[0]; cs = $vals[1]; at = $vals[2]; as = $vals[3] } | ConvertTo-Json -Compress
ConvertTo-SecureString $json -AsPlainText -Force | ConvertFrom-SecureString | Set-Content -Path "$dir\x_keys.dat" -Encoding ASCII
Write-Host '保存しました。毎朝の自動投稿はこのキーを使います。' -ForegroundColor Green
