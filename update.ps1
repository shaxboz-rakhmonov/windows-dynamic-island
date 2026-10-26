# Updates Windows Dynamic Island to the latest version from GitHub and restarts it.
# Run: powershell -ExecutionPolicy Bypass -File update.ps1
$dir = $PSScriptRoot
$raw = 'https://raw.githubusercontent.com/shaxboz-rakhmonov/windows-dynamic-island/main'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tmp = Join-Path $env:TEMP 'DynamicIsland.new.ps1'
Invoke-WebRequest "$raw/DynamicIsland.ps1" -OutFile $tmp -UseBasicParsing
$err = $null; [void][Management.Automation.Language.Parser]::ParseFile($tmp, [ref]$null, [ref]$err)
if ($err) { Write-Host 'Downloaded file is broken, keeping the current version.'; exit 1 }
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*DynamicIsland.ps1*' -and $_.ProcessId -ne $PID } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Copy-Item $tmp (Join-Path $dir 'DynamicIsland.ps1') -Force
Remove-Item $tmp -Force
if (Get-ScheduledTask -TaskName 'WinDynamicIsland' -ErrorAction SilentlyContinue) { Start-ScheduledTask -TaskName 'WinDynamicIsland' }
else { Start-Process powershell -WindowStyle Hidden -ArgumentList "-NoProfile -STA -ExecutionPolicy Bypass -File `"$dir\DynamicIsland.ps1`"" }
Write-Host 'Updated to the latest version. Your config.json is untouched.'
