# Updates Windows Dynamic Island to the latest version from GitHub and restarts it (config.json is never touched).
# Run from the install folder: powershell -ExecutionPolicy Bypass -File update.ps1
$dir = $PSScriptRoot
$raw = 'https://raw.githubusercontent.com/shaxboz-rakhmonov/windows-dynamic-island/main'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$files = 'DynamicIsland.ps1','install.ps1','uninstall.ps1','stop.ps1','update.ps1','setup-claude.ps1','claude-limits.cjs','config.example.json'
$tmpDir = Join-Path $env:TEMP ('di-upd-' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory $tmpDir | Out-Null
foreach ($f in $files) { try { Invoke-WebRequest "$raw/$f" -OutFile (Join-Path $tmpDir $f) -UseBasicParsing } catch { Write-Host "Could not download $f - update cancelled."; Remove-Item $tmpDir -Recurse -Force; exit 1 } }
foreach ($f in $files | Where-Object { $_ -like '*.ps1' }) { $err = $null; [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $tmpDir $f), [ref]$null, [ref]$err); if ($err) { Write-Host "$f is broken, keeping the current version."; Remove-Item $tmpDir -Recurse -Force; exit 1 } }
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*DynamicIsland.ps1*' -and $_.ProcessId -ne $PID } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
foreach ($f in $files) { Copy-Item (Join-Path $tmpDir $f) (Join-Path $dir $f) -Force }
Remove-Item $tmpDir -Recurse -Force
if (Get-ScheduledTask -TaskName 'WinDynamicIsland' -ErrorAction SilentlyContinue) { Start-ScheduledTask -TaskName 'WinDynamicIsland' }
else { Start-Process powershell -WindowStyle Hidden -ArgumentList "-NoProfile -STA -ExecutionPolicy Bypass -File `"$dir\DynamicIsland.ps1`"" }
Write-Host 'Updated to the latest version. Your config.json is untouched.'
