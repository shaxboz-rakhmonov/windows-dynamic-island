# One-step setup for the Claude usage rings: points the Claude Code status line at claude-limits.cjs.
# Run: powershell -ExecutionPolicy Bypass -File setup-claude.ps1      (add -Force to replace an existing status line)
param([switch]$Force)
$js = Join-Path $PSScriptRoot 'claude-limits.cjs'
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Write-Host 'Node.js is required (https://nodejs.org). Install it and run this again.'; exit 1 }
$dir = Join-Path $env:USERPROFILE '.claude'; New-Item -ItemType Directory -Force $dir | Out-Null
$f = Join-Path $dir 'settings.json'
$o = if (Test-Path $f) { Get-Content $f -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
if ($o.statusLine -and -not $Force) { Write-Host 'You already have a Claude Code status line. Re-run with -Force to replace it (a backup is saved).'; exit 1 }
if (Test-Path $f) { Copy-Item $f "$f.bak-island" -Force }
$sl = [pscustomobject]@{ type = 'command'; command = "node `"$js`"" }
if ($o.PSObject.Properties['statusLine']) { $o.statusLine = $sl } else { $o | Add-Member -NotePropertyName statusLine -NotePropertyValue $sl }
$o | ConvertTo-Json -Depth 20 | Set-Content $f -Encoding UTF8
Write-Host 'Done. Restart Claude Code, send any message, then restart the island (stop.ps1, then Start-ScheduledTask WinDynamicIsland). The rings will show your 5-hour and weekly usage.'
Write-Host 'If the rings stay on "--": the limits only exist for Claude Pro/Max subscriptions — that is the "works / does not work" check.'
