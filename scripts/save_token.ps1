# Store a long-lived Claude token (from `claude setup-token`) for the daily job.
# Encrypted with Windows DPAPI: only this Windows user on this PC can decrypt it.
$dir = "$env:USERPROFILE\.news_manga"
New-Item -ItemType Directory -Force $dir | Out-Null
$sec = Read-Host -AsSecureString 'claude setup-token で表示されたトークンを貼り付けて Enter'
if ($sec.Length -lt 20) { Write-Host 'トークンが短すぎます。やり直してください。' -ForegroundColor Red; exit 1 }
$sec | ConvertFrom-SecureString | Set-Content -Path "$dir\claude_token.dat" -Encoding ASCII
Write-Host '保存しました。毎朝の自動実行はこのトークンを使います。' -ForegroundColor Green
