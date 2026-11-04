# Register a Windows scheduled task that runs run_daily.ps1 every morning at 8:00
$script = Join-Path $PSScriptRoot 'run_daily.ps1'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Daily -At 8:00
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
Register-ScheduledTask -TaskName 'NewsManga_Daily' -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Write-Output 'registered: NewsManga_Daily (daily 8:00)'
