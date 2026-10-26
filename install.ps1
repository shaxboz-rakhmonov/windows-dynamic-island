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
