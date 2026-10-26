# Stops the island for now (it starts again at the next logon, or run: Start-ScheduledTask WinDynamicIsland).
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*DynamicIsland.ps1*' -and $_.ProcessId -ne $PID } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Write-Host 'Stopped. To start again: Start-ScheduledTask WinDynamicIsland'
