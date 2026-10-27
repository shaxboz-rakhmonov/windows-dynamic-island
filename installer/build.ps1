# Builds DynamicIsland-Setup.exe with the C# compiler that ships with Windows (no SDK needed).
# Run from this folder:  powershell -ExecutionPolicy Bypass -File build.ps1
$here = $PSScriptRoot; $root = Split-Path $here
$fw  = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319'
$csc = "$fw\csc.exe"; $wpf = "$fw\WPF"
$refs = @("$wpf\PresentationFramework.dll","$wpf\PresentationCore.dll","$wpf\WindowsBase.dll","$fw\System.Xaml.dll","$fw\System.Windows.Forms.dll","$fw\System.Drawing.dll","$fw\System.Management.dll","$fw\Microsoft.CSharp.dll","$fw\System.Core.dll") | % { "/r:`"$_`"" }
$res = @('DynamicIsland.ps1','claude-limits.cjs','setup-claude.ps1','config.example.json') | % { "/resource:`"$root\$_`",$_" }
$res += "/resource:`"$here\logo.png`",logo.png"; $res += "/resource:`"$here\app.ico`",app.ico"
$out = Join-Path $here 'DynamicIsland-Setup.exe'
& $csc /nologo /target:winexe /optimize+ /codepage:65001 "/out:$out" "/win32icon:$here\app.ico" @refs @res "$here\Program.cs"
if (Test-Path $out) { Write-Host "Built: $out" } else { Write-Host 'Build failed'; exit 1 }
