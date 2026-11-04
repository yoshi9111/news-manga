# Usage: fetch_pdf.ps1 <pdf url>  -> downloads the PDF, converts to UTF-8 text, prints the text file path
param([Parameter(Mandatory = $true)][string]$Url)
$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $PSScriptRoot
if ($Url -notmatch '^https://www\.(mhlw|pmda)\.go\.jp/.+\.pdf$') { Write-Output "refused: only mhlw.go.jp / pmda.go.jp PDF URLs"; exit 1 }

$exe = (Get-Command pdftotext -ErrorAction SilentlyContinue).Source
if (-not $exe) {
  $exe = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter pdftotext.exe -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName
}
if (-not $exe) { Write-Output 'pdftotext not found (winget install oschwartz10612.Poppler)'; exit 1 }

$dir = "$base\logs\pdf"
New-Item -ItemType Directory -Force $dir | Out-Null
$name = [IO.Path]::GetFileNameWithoutExtension(([Uri]$Url).AbsolutePath)
$pdf = "$dir\$name.pdf"; $txt = "$dir\$name.txt"
Invoke-WebRequest -UseBasicParsing -TimeoutSec 60 -Uri $Url -OutFile $pdf
& $exe -layout -enc UTF-8 -l 20 $pdf $txt
$len = (Get-Item $txt).Length
Write-Output ("text: logs/pdf/{0}.txt ({1} bytes, first 20 pages)" -f $name, $len)
