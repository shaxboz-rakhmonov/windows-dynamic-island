# Installs Windows Dynamic Island: starts at logon, hidden. Run: powershell -ExecutionPolicy Bypass -File install.ps1
$dir = $PSScriptRoot
$vbs = Join-Path $dir 'start.vbs'
Set-Content $vbs "CreateObject(`"Wscript.Shell`").Run `"powershell -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File `"`"$dir\DynamicIsland.ps1`"`"`", 0, False" -Encoding ASCII
$act = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$vbs`""
$trg = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName 'WinDynamicIsland' -Action $act -Trigger $trg -Settings $set -Force | Out-Null
Start-ScheduledTask -TaskName 'WinDynamicIsland'
Write-Host 'Done. Dynamic Island is running and will start with Windows.'
# Claude usage rings: hook the Claude Code status line automatically (only if Claude Code + Node are present and no status line exists yet)
try { if ((Test-Path (Join-Path $env:USERPROFILE '.claude')) -and (Get-Command node -ErrorAction SilentlyContinue)) { & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir 'setup-claude.ps1') } } catch {}
