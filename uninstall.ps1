# Removes autostart and stops the island.
Unregister-ScheduledTask -TaskName 'WinDynamicIsland' -Confirm:$false -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*DynamicIsland.ps1*' -and $_.ProcessId -ne $PID } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Write-Host 'Removed.'
