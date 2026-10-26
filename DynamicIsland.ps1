# Windows Dynamic Island — плашка в стиле Dynamic Island сверху экрана: музыка, календарь, погода, нагрузка ПК, (опционально) статус сервера.
# Запуск: powershell -STA -File DynamicIsland.ps1
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$ErrorActionPreference='SilentlyContinue'
$script:mx=New-Object Threading.Mutex($false,'Local\WinDynamicIsland'); if(-not $script:mx.WaitOne(0)){ exit }
$script:lastTrack=''
$cfg = $null; try{ $cfg = Get-Content "$PSScriptRoot\config.json" -Raw | ConvertFrom-Json }catch{}
if(-not $cfg){ $cfg = [pscustomobject]@{} }
$ru = (Get-UICulture).Name -like 'ru*'
$TR = @{ nothing=$(if($ru){$TR.nothing}else{'Nothing playing'}); sys=$(if($ru){'СИСТЕМА'}else{'SYSTEM'}); wind=$(if($ru){'ветер'}else{'wind'}); ms=$(if($ru){'м/с'}else{'m/s'}); up=$(if($ru){'Работает'}else{'Uptime'}); d=$(if($ru){'д'}else{'d'}); h=$(if($ru){'ч'}else{'h'}); noconn=$(if($ru){'нет связи с сервером'}else{'server unreachable'}); load=$(if($ru){'Нагрузка'}else{'CPU'}); mem=$(if($ru){'память'}else{'RAM'}); disk=$(if($ru){'диск'}else{'disk'}); errs=$(if($ru){'Ошибок'}else{'Errors'}) }
$dataDir = $PSScriptRoot
# --- музыка (WinRT: что играет в системе)
$null=[Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime]
$null=[Windows.Storage.Streams.DataReader,Windows.Storage.Streams,ContentType=WindowsRuntime]
$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | ? { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | select -First 1
function Await($op,$type){ $t=$asTask.MakeGenericMethod($type).Invoke($null,@($op)); $t.Wait(3000)|Out-Null; $t.Result }
$mgr = Await ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])

$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 WindowStyle="None" AllowsTransparency="True" Background="Transparent" Topmost="True" ShowInTaskbar="False" ResizeMode="NoResize" Width="1260" Height="320" ShowActivated="False"
 TextOptions.TextFormattingMode="Ideal" UseLayoutRounding="True">
 <Grid>
 <StackPanel Name="shell" Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Top" RenderTransformOrigin="0.5,0"><StackPanel.RenderTransform><TranslateTransform x:Name="shT" Y="-44"/></StackPanel.RenderTransform>
 <Path Name="fL" RenderTransformOrigin="1,0" Fill="#FF000000" VerticalAlignment="Top" Data="M0,0 L16,0 L16,16 A16,16 0 0 0 0,0 Z"><Path.RenderTransform><ScaleTransform x:Name="fLS"/></Path.RenderTransform></Path>
 <Border Name="isl" Background="#FF000000" VerticalAlignment="Top" Width="330" Height="34" CornerRadius="0,0,17,17" ClipToBounds="True">
  <Grid>
   <Grid Name="cmp" Margin="14,0,14,0">
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Left" VerticalAlignment="Center">
     <Border Name="cArt" Width="20" Height="20" CornerRadius="5" Margin="0,0,8,0"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#FF3A2A6B" Offset="0"/><GradientStop Color="#FF0F6B8F" Offset="1"/></LinearGradientBrush></Border.Background></Border>
     <TextBlock Name="cTrack" Foreground="#FFEDEDF2" FontSize="12" FontWeight="SemiBold" MaxWidth="110" TextTrimming="CharacterEllipsis" VerticalAlignment="Center" FontFamily="Segoe UI"/>
    </StackPanel>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
     <TextBlock Name="cWx" Foreground="#FFB9B9C4" FontSize="12" Margin="0,0,10,0" FontFamily="Segoe UI Emoji, Segoe UI"/>
     <TextBlock Name="cTime" Foreground="White" FontSize="13" FontWeight="SemiBold" FontFamily="Segoe UI"/>
     <Ellipse Name="dot" Width="9" Height="9" Fill="#FF34D399" Margin="10,0,0,0"/>
    </StackPanel>
   </Grid>
   <Grid Name="pg" Opacity="0" RenderTransformOrigin="0.5,0.1" Margin="22,16,22,26" IsHitTestVisible="False"><Grid.RenderTransform><ScaleTransform x:Name="pgS" ScaleX="0.96" ScaleY="0.96"/></Grid.RenderTransform>
    <Grid Name="p0">
     <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
     <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Width="330">
      <Border Name="aArt" Width="80" Height="80" CornerRadius="12"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#FF3A2A6B" Offset="0"/><GradientStop Color="#FF0F6B8F" Offset="1"/></LinearGradientBrush></Border.Background><TextBlock Text="♪" FontSize="30" Foreground="#AAFFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
      <StackPanel Margin="14,0,0,0" VerticalAlignment="Center" Width="230">
       <TextBlock Name="aTitle" Text="Nothing playing" Foreground="White" FontSize="15" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" FontFamily="Segoe UI"/>
       <TextBlock Name="aArtist" Foreground="#FF8E8E99" FontSize="12" TextTrimming="CharacterEllipsis" FontFamily="Segoe UI"/>
       <ProgressBar Name="aPos" Height="3" Maximum="1000" Margin="0,8,0,0" Foreground="White" Background="#33FFFFFF" BorderThickness="0"/>
       <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,6,0,0">
        <Path Name="aPrev" Width="22" Height="22" Stretch="Uniform" Fill="White" Data="M6,5 H8.5 V19 H6 Z M20,5 V19 L9.5,12 Z" Cursor="Hand" VerticalAlignment="Center" Margin="0,0,22,0"/>
        <Path Name="aPlay" Width="26" Height="26" Stretch="Uniform" Fill="White" Data="M7,4 V20 L20,12 Z" Cursor="Hand" VerticalAlignment="Center" Margin="0,0,22,0"/>
        <Path Name="aNext" Width="22" Height="22" Stretch="Uniform" Fill="White" Data="M15.5,5 H18 V19 H15.5 Z M4,5 V19 L14.5,12 Z" Cursor="Hand" VerticalAlignment="Center"/>
        <Path Name="aPin" Width="20" Height="20" Stretch="Uniform" Fill="#66FFFFFF" Data="M16,12V4H17V2H7V4H8V12L6,14V16H11.2V22H12.8V16H18V14L16,12Z" Cursor="Hand" ToolTip="Pin the active window on top of all windows" VerticalAlignment="Center" Margin="26,0,0,0"/>
       </StackPanel>
      </StackPanel>
     </StackPanel>
     <Rectangle Grid.Column="1" Width="1" Fill="#33FFFFFF" Margin="14,6"/>
     <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
      <StackPanel VerticalAlignment="Center" Width="200">
       <TextBlock Name="aMonth" Foreground="#FF8E8E99" FontSize="12" HorizontalAlignment="Center" Margin="0,0,0,4" FontFamily="Segoe UI"/>
       <UniformGrid Name="aWeek" Columns="7"/>
      </StackPanel>
      <Rectangle Width="1" Fill="#33FFFFFF" Margin="14,6"/>
      <StackPanel VerticalAlignment="Center" Width="120">
       <TextBlock Name="aTime" Foreground="White" FontSize="38" FontWeight="Light" HorizontalAlignment="Center" FontFamily="Segoe UI"/>
       <TextBlock Name="aDate" Foreground="#FF8E8E99" FontSize="12" HorizontalAlignment="Center" FontFamily="Segoe UI"/>
       <TextBlock Name="aWx" Foreground="#FFB9B9C4" FontSize="12" HorizontalAlignment="Center" Margin="0,3,0,0" FontFamily="Segoe UI Emoji, Segoe UI"/>
      </StackPanel>
     </StackPanel>
     <Rectangle Grid.Column="3" Width="1" Fill="#33FFFFFF" Margin="14,6"/>
     <Grid Grid.Column="4" VerticalAlignment="Center" Width="190">
      <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
      <Grid.RowDefinitions><RowDefinition Height="24"/><RowDefinition Height="24"/><RowDefinition Height="24"/></Grid.RowDefinitions>
      <TextBlock Text="CPU" Foreground="#FF6FB1FF" FontSize="11" Margin="0,0,8,0" VerticalAlignment="Center"/><ProgressBar Name="aCpu" Grid.Column="1" Height="5" Maximum="100" Foreground="#FF4C9EFF" Background="#22FFFFFF" BorderThickness="0"/><TextBlock Name="aCpuV" Grid.Column="2" Foreground="White" FontSize="11" Margin="8,0,0,0" VerticalAlignment="Center"/>
      <TextBlock Text="RAM" Grid.Row="1" Foreground="#FF6FE08A" FontSize="11" VerticalAlignment="Center"/><ProgressBar Name="aRam" Grid.Row="1" Grid.Column="1" Height="5" Maximum="100" Foreground="#FF4CD964" Background="#22FFFFFF" BorderThickness="0"/><TextBlock Name="aRamV" Grid.Row="1" Grid.Column="2" Foreground="White" FontSize="11" Margin="8,0,0,0" VerticalAlignment="Center"/>
      <TextBlock Text="DISK" Grid.Row="2" Foreground="#FFFFB066" FontSize="11" VerticalAlignment="Center"/><ProgressBar Name="aDisk" Grid.Row="2" Grid.Column="1" Height="5" Maximum="100" Foreground="#FFFFA040" Background="#22FFFFFF" BorderThickness="0"/><TextBlock Name="aDiskV" Grid.Row="2" Grid.Column="2" Foreground="White" FontSize="11" Margin="8,0,0,0" VerticalAlignment="Center"/>
      </Grid>
    </Grid>
    <Grid Name="p1" Visibility="Collapsed">
     <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
     <Border Name="art" Width="92" Height="92" CornerRadius="14" VerticalAlignment="Center"><Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#FF3A2A6B" Offset="0"/><GradientStop Color="#FF0F6B8F" Offset="1"/></LinearGradientBrush></Border.Background><TextBlock Text="♪" FontSize="36" Foreground="#AAFFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
     <StackPanel Grid.Column="1" Margin="16,0,16,0" VerticalAlignment="Center">
      <TextBlock Name="tTitle" Text="Nothing playing" Foreground="White" FontSize="17" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" FontFamily="Segoe UI"/>
      <TextBlock Name="tArtist" Foreground="#FF8E8E99" FontSize="13" TextTrimming="CharacterEllipsis" FontFamily="Segoe UI"/>
      <ProgressBar Name="pPos" Height="3" Maximum="1000" Margin="0,10,0,0" Foreground="White" Background="#33FFFFFF" BorderThickness="0"/>
      <Grid Margin="0,8,0,0" HorizontalAlignment="Center">
       <StackPanel Orientation="Horizontal">
        <Path Name="bPrev" Width="24" Height="24" Stretch="Uniform" Fill="White" Data="M6,5 H8.5 V19 H6 Z M20,5 V19 L9.5,12 Z" Cursor="Hand" VerticalAlignment="Center" Margin="0,0,26,0"/>
        <Path Name="bPlay" Width="28" Height="28" Stretch="Uniform" Fill="White" Data="M7,4 V20 L20,12 Z" Cursor="Hand" VerticalAlignment="Center" Margin="0,0,26,0"/>
        <Path Name="bNext" Width="24" Height="24" Stretch="Uniform" Fill="White" Data="M15.5,5 H18 V19 H15.5 Z M4,5 V19 L14.5,12 Z" Cursor="Hand" VerticalAlignment="Center"/>
        <Path Name="bPin" Width="20" Height="20" Stretch="Uniform" Fill="#66FFFFFF" Data="M16,12V4H17V2H7V4H8V12L6,14V16H11.2V22H12.8V16H18V14L16,12Z" Cursor="Hand" ToolTip="Pin the active window on top of all windows" VerticalAlignment="Center" Margin="26,0,0,0"/>
       </StackPanel>
      </Grid>
     </StackPanel>
     <StackPanel Grid.Column="2" VerticalAlignment="Center" HorizontalAlignment="Right">
      <TextBlock Name="tTime" Foreground="White" FontSize="32" FontWeight="Light" HorizontalAlignment="Right" FontFamily="Segoe UI"/>
      <TextBlock Name="tWx" Foreground="#FFB9B9C4" FontSize="12" HorizontalAlignment="Right" Margin="0,2,0,0" FontFamily="Segoe UI Emoji, Segoe UI"/>
     </StackPanel>
    </Grid>
    <Grid Name="p2" Visibility="Collapsed">
     <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="200"/></Grid.ColumnDefinitions>
     <StackPanel>
      <TextBlock Name="calM" Foreground="#FF8E8E99" FontSize="13" Margin="2,0,0,6" FontFamily="Segoe UI"/>
      <UniformGrid Name="cal" Columns="7"/>
     </StackPanel>
     <StackPanel Grid.Column="1" Margin="22,0,0,0" VerticalAlignment="Center">
      <TextBlock Name="calD" Foreground="White" FontSize="30" FontWeight="Light" FontFamily="Segoe UI"/>
      <TextBlock Name="calW" Foreground="#FF8E8E99" FontSize="13" Margin="0,2,0,10" FontFamily="Segoe UI"/>
      <TextBlock Name="calX" Foreground="#FFB9B9C4" FontSize="12" TextWrapping="Wrap" FontFamily="Segoe UI Emoji, Segoe UI"/>
     </StackPanel>
    </Grid>
    <Grid Name="p3" Visibility="Collapsed">
     <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
     <Grid VerticalAlignment="Center" Margin="0,0,20,0">
      <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
      <Grid.RowDefinitions><RowDefinition Height="26"/><RowDefinition Height="26"/><RowDefinition Height="26"/></Grid.RowDefinitions>
      <TextBlock Text="CPU" Foreground="#FF6FB1FF" FontSize="12" VerticalAlignment="Center" Margin="0,0,10,0"/><ProgressBar Name="pCpu" Grid.Column="1" Height="6" Maximum="100" Foreground="#FF4C9EFF" Background="#22FFFFFF" BorderThickness="0"/><TextBlock Name="vCpu" Grid.Column="2" Foreground="White" FontSize="12" Margin="10,0,0,0" VerticalAlignment="Center"/>
      <TextBlock Text="RAM" Grid.Row="1" Foreground="#FF6FE08A" FontSize="12" VerticalAlignment="Center"/><ProgressBar Name="pRam" Grid.Row="1" Grid.Column="1" Height="6" Maximum="100" Foreground="#FF4CD964" Background="#22FFFFFF" BorderThickness="0"/><TextBlock Name="vRam" Grid.Row="1" Grid.Column="2" Foreground="White" FontSize="12" Margin="10,0,0,0" VerticalAlignment="Center"/>
      <TextBlock Text="DISK" Grid.Row="2" Foreground="#FFFFB066" FontSize="12" VerticalAlignment="Center"/><ProgressBar Name="pDisk" Grid.Row="2" Grid.Column="1" Height="6" Maximum="100" Foreground="#FFFFA040" Background="#22FFFFFF" BorderThickness="0"/><TextBlock Name="vDisk" Grid.Row="2" Grid.Column="2" Foreground="White" FontSize="12" Margin="10,0,0,0" VerticalAlignment="Center"/>
     </Grid>
     <StackPanel Grid.Column="1" VerticalAlignment="Center">
      <TextBlock Name="tSrvTitle" Text="SYSTEM" Foreground="#FFC79BFF" FontSize="12" FontWeight="SemiBold" Margin="0,0,0,6"/>
      <TextBlock Name="tSrv" Foreground="White" FontSize="12" TextWrapping="Wrap" FontFamily="Segoe UI"/>
      <TextBlock Name="tSvc" Foreground="#FF8E8E99" FontSize="11" Margin="0,6,0,0" TextWrapping="Wrap" FontFamily="Segoe UI"/>
     </StackPanel>
    </Grid>
   </Grid>
   <StackPanel Name="dots" Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Bottom" Margin="0,0,0,8" Opacity="0">
    <Ellipse Name="dA" Width="6" Height="6" Fill="White" Margin="4,0" Cursor="Hand"/>
    <Ellipse Name="d1" Width="6" Height="6" Fill="#55FFFFFF" Margin="4,0" Cursor="Hand"/>
    <Ellipse Name="d2" Width="6" Height="6" Fill="#55FFFFFF" Margin="4,0" Cursor="Hand"/>
    <Ellipse Name="d3" Width="6" Height="6" Fill="#55FFFFFF" Margin="4,0" Cursor="Hand"/>
   </StackPanel>
  </Grid>
 </Border>
 <Path Name="fR" RenderTransformOrigin="0,0" Fill="#FF000000" VerticalAlignment="Top" Data="M16,0 L0,0 L0,16 A16,16 0 0 1 16,0 Z"><Path.RenderTransform><ScaleTransform x:Name="fRS"/></Path.RenderTransform></Path>
 </StackPanel>
 </Grid>
</Window>
'@
$w=[Windows.Markup.XamlReader]::Parse($xaml)
$c=@{}; 'tSrvTitle','fLS','fRS','shT','pgS','fL','fR','isl','cmp','pg','p0','p1','p2','p3','dots','dA','d1','d2','d3','aArt','aTitle','aArtist','aPos','aPrev','aPlay','aNext','aPin','bPin','aWeek','aMonth','aDate','aTime','aWx','aCpu','aCpuV','aRam','aRamV','aDisk','aDiskV','dot','cTime','cWx','cTrack','cArt','art','tTitle','tArtist','pPos','bPrev','bPlay','bNext','tTime','tWx','calM','cal','calD','calW','calX','pCpu','pRam','pDisk','vCpu','vRam','vDisk','tSrv','tSvc' | % { $c[$_]=$w.FindName($_) }
function Place { $a=[System.Windows.SystemParameters]::WorkArea; $w.Left=$a.Left+($a.Width-$w.Width)/2; $w.Top=$a.Top }
Place

# --- фоновый сборщик: тяжёлые опросы вне окна, чтобы анимация не подвисала
$script:st=[hashtable]::Synchronized(@{})
$rs=[runspacefactory]::CreateRunspace(); $rs.ApartmentState='MTA'; $rs.Open()
$rs.SessionStateProxy.SetVariable('st',$script:st); $rs.SessionStateProxy.SetVariable('cfg',$cfg)
$ps=[powershell]::Create(); $ps.Runspace=$rs
[void]$ps.AddScript({
  $ErrorActionPreference='SilentlyContinue'; $n=0
  while($true){
    try{ $st.cpu=[int](Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime
      $os=Get-CimInstance Win32_OperatingSystem; $st.ram=[int](100*(1-$os.FreePhysicalMemory/$os.TotalVisibleMemorySize))
      $d=Get-PSDrive C; $st.disk=[int](100*$d.Used/($d.Used+$d.Free)) }catch{}
    try{ $st.up=[int]((Get-Date)-(Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalMinutes }catch{}
    if($n % 7 -eq 0 -and $cfg.server.url){
      $hd=@{}; $hn=$(if($cfg.server.header){$cfg.server.header}else{'x-api-key'}); if($cfg.server.key){ $hd[$hn]=$cfg.server.key }
      try{ $st.srv=(Invoke-WebRequest -UseBasicParsing "$($cfg.server.url)" -Headers $hd -TimeoutSec 8).Content; $st.err=$false }catch{ $st.err=$true } }
    if($n % 200 -eq 0){
      try{ if($cfg.weather.lat){ $lat=$cfg.weather.lat; $lon=$cfg.weather.lon; $st.city=$cfg.weather.city }
           else{ $g=Invoke-RestMethod 'https://ipwho.is/' -TimeoutSec 8; $lat=$g.latitude; $lon=$g.longitude; $st.city=$g.city }
           $o=(Invoke-RestMethod "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code,wind_speed_10m,is_day&wind_speed_unit=ms" -TimeoutSec 8).current
           $st.wx=(@{code=$o.weather_code;temp=$o.temperature_2m;wind=$o.wind_speed_10m;isDay=($o.is_day -eq 1)} | ConvertTo-Json -Compress) }catch{} }
    $n++; Start-Sleep -Seconds 3 } })
[void]$ps.BeginInvoke()
Add-Type -Namespace U -Name K -MemberDefinition '[StructLayout(LayoutKind.Sequential)] public struct PT { public int X; public int Y; } [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int k); [DllImport("user32.dll")] public static extern bool GetCursorPos(out PT p);' -ErrorAction Continue
# клик в любое место вне острова (в т.ч. по рабочему столу) — сворачиваем
$script:wasDown=$false
$tc=New-Object Windows.Threading.DispatcherTimer; $tc.Interval=[TimeSpan]::FromMilliseconds(60)
$tc.Add_Tick({
  $down=([U.K]::GetAsyncKeyState(1) -band 0x8000) -ne 0
  if($down -and -not $script:wasDown -and $script:open){
    $pt=New-Object U.K+PT; [void][U.K]::GetCursorPos([ref]$pt)
    $src=[Windows.PresentationSource]::FromVisual($w); $sc=$src.CompositionTarget.TransformToDevice.M11
    $tl=$c.isl.PointToScreen([Windows.Point]::new(0,0))
    $inside=($pt.X -ge $tl.X -and $pt.X -le $tl.X+$c.isl.ActualWidth*$sc -and $pt.Y -ge $tl.Y -and $pt.Y -le $tl.Y+$c.isl.ActualHeight*$sc)
    if(-not $inside){ $hide.Stop(); Collapse } }
  $script:wasDown=$down })
$tc.Start()
$ns='System.Windows.Media.Animation'
function Anim($prop,$to,$ms,$ease,$delay=0,$target=$c.isl){
  $a=New-Object "$ns.DoubleAnimation"; $a.To=$to; $a.Duration=[TimeSpan]::FromMilliseconds($ms); $a.BeginTime=[TimeSpan]::FromMilliseconds($delay); $a.EasingFunction=$ease
  $target.BeginAnimation($prop,$a) }
$spring=New-Object "$ns.BackEase"; $spring.Amplitude=0.14; $spring.EasingMode='EaseOut'
$soft=New-Object "$ns.CubicEase"; $soft.EasingMode='EaseInOut'
$W_=[Windows.FrameworkElement]::WidthProperty; $H_=[Windows.FrameworkElement]::HeightProperty; $O_=[Windows.UIElement]::OpacityProperty
$SX_=[Windows.Media.ScaleTransform]::ScaleXProperty; $SY_=[Windows.Media.ScaleTransform]::ScaleYProperty; $Y_=[Windows.Media.TranslateTransform]::YProperty
$sizes=@( @(1010,132), @(580,152), @(560,224), @(560,160) ); $script:page=0; $script:open=$false
function AnimR($prop,$to,$ms,$ease,$delay,$target){
  $a=New-Object "$ns.DoubleAnimation"; $a.To=$to; $a.Duration=[TimeSpan]::FromMilliseconds($ms); $a.BeginTime=[TimeSpan]::FromMilliseconds($delay); $a.EasingFunction=$ease; $a.AutoReverse=$true
  $target.BeginAnimation($prop,$a) }
$elastic=New-Object "$ns.ElasticEase"; $elastic.Oscillations=1; $elastic.Springiness=5; $elastic.EasingMode='EaseOut'
$backH=New-Object "$ns.BackEase"; $backH.Amplitude=0.5; $backH.EasingMode='EaseOut'
$out=New-Object "$ns.CubicEase"; $out.EasingMode='EaseOut'
$SX2_=[Windows.Media.ScaleTransform]::ScaleXProperty; $SY2_=[Windows.Media.ScaleTransform]::ScaleYProperty
$fluid=New-Object "$ns.QuinticEase"; $fluid.EasingMode='EaseOut'
$fluidIO=New-Object "$ns.QuinticEase"; $fluidIO.EasingMode='EaseInOut'
$backS=New-Object "$ns.BackEase"; $backS.Amplitude=0.12; $backS.EasingMode='EaseOut'
function Goo($open){
  if($open){ $sz=$sizes[$script:page]; Anim $W_ $sz[0] 440 $spring; Anim $H_ $sz[1] 440 $spring }
  else { Anim $W_ 330 380 $soft 90; Anim $H_ 34 380 $soft 90 } }
function Show-Page($i){
  $script:page=$i; $pgs=@($c.p0,$c.p1,$c.p2,$c.p3); 0..3 | % { $pgs[$_].Visibility=$(if($_ -eq $i){'Visible'}else{'Collapsed'}) }
  $ds=@($c.dA,$c.d1,$c.d2,$c.d3); 0..3 | % { $ds[$_].Fill=$(if($_ -eq $i){'White'}else{'#55FFFFFF'}) }
  Stats }
function Expand { if($script:open){return}; $script:open=$true
  $sz=$sizes[$script:page]; $c.isl.CornerRadius=[Windows.CornerRadius]::new(0,0,30,30)
  try{ Goo $true }catch{ "$($_.Exception.Message) @$($_.InvocationInfo.ScriptLineNumber)" | Out-File $dataDir\err.log -Append }
  Anim $O_ 0 110 $soft 0 $c.cmp; Anim $O_ 1 220 $soft 130 $c.pg; Anim $O_ 1 240 $soft 220 $c.dots; Anim $SX_ 1 520 $spring 120 $c.pgS; Anim $SY_ 1 520 $spring 120 $c.pgS; $c.pg.IsHitTestVisible=$true }
function Collapse { if(-not $script:open){return}; $script:open=$false
  Anim $O_ 0 140 $soft 0 $c.pg; Anim $O_ 0 120 $soft 0 $c.dots; Anim $SX_ 0.9 220 $soft 0 $c.pgS; Anim $SY_ 0.9 220 $soft 0 $c.pgS; Anim $O_ 1 220 $soft 300 $c.cmp; $c.pg.IsHitTestVisible=$false
  try{ Goo $false }catch{ "$($_.Exception.Message) @$($_.InvocationInfo.ScriptLineNumber)" | Out-File $dataDir\err.log -Append }
  $cr=New-Object Windows.Threading.DispatcherTimer; $cr.Interval=[TimeSpan]::FromMilliseconds(380); $cr.Add_Tick({ $cr.Stop(); if(-not $script:open){ $c.isl.CornerRadius=[Windows.CornerRadius]::new(0,0,17,17) } }); $cr.Start() }
$script:busy=[DateTime]::MinValue
function Go($i){ if(((Get-Date)-$script:busy).TotalMilliseconds -lt 380){return}; $script:busy=Get-Date; if($i -lt 0){$i=3}; if($i -gt 3){$i=0}; if($i -eq $script:page -and $script:open){return}
  if(-not $script:open){ Show-Page $i; return }
  Anim $O_ 0 90 $soft 0 $c.pg; Anim $SX_ 0.94 90 $soft 0 $c.pgS; Anim $SY_ 0.94 90 $soft 0 $c.pgS
  $sw=New-Object Windows.Threading.DispatcherTimer; $sw.Interval=[TimeSpan]::FromMilliseconds(100)
  $sw.Add_Tick({ $sw.Stop(); Show-Page $i; $sz=$sizes[$i]; Anim $W_ $sz[0] 420 $spring; Anim $H_ $sz[1] 420 $spring; Anim $O_ 1 220 $soft 120 $c.pg; Anim $SX_ 1 440 $spring 100 $c.pgS; Anim $SY_ 1 440 $spring 100 $c.pgS }.GetNewClosure()); $sw.Start() }
$hide=New-Object Windows.Threading.DispatcherTimer; $hide.Interval=[TimeSpan]::FromSeconds(1.2); $hide.Add_Tick({ $hide.Stop(); Collapse })
$c.isl.Add_MouseEnter({ $hide.Stop(); Expand })
$c.isl.Add_MouseLeave({ $hide.Stop(); $hide.Interval=[TimeSpan]::FromSeconds(1.2); $hide.Start() })
$c.isl.Add_MouseWheel({ if($script:open){ if($_.Delta -lt 0){ Go ($script:page+1) } else { Go ($script:page-1) } } })
$script:dx=$null
$c.isl.Add_MouseLeftButtonDown({ $script:dx=$_.GetPosition($c.isl).X })
$c.isl.Add_MouseLeftButtonUp({ $script:dx=$null })
$c.isl.Add_MouseMove({ if($script:dx -ne $null -and $_.LeftButton -eq 'Pressed' -and $script:open){ $x=$_.GetPosition($c.isl).X
  if($x-$script:dx -gt 70){ $script:dx=$x; Go ($script:page-1) } elseif($script:dx-$x -gt 70){ $script:dx=$x; Go ($script:page+1) } } })
$c.isl.Add_MouseRightButtonUp({ $w.Close() })
$c.dA.Add_MouseLeftButtonUp({ Go 0 }); $c.d1.Add_MouseLeftButtonUp({ Go 1 }); $c.d2.Add_MouseLeftButtonUp({ Go 2 }); $c.d3.Add_MouseLeftButtonUp({ Go 3 })
function Peek($sec){ Expand; $hide.Stop(); $hide.Interval=[TimeSpan]::FromSeconds($sec); $hide.Start() }
function Sess { if($mgr){ $mgr.GetCurrentSession() } }
$c.bPrev.Add_MouseLeftButtonUp({ $s=Sess; if($s){ $s.TrySkipPreviousAsync()|Out-Null } })
$c.bPlay.Add_MouseLeftButtonUp({ $s=Sess; if($s){ $s.TryTogglePlayPauseAsync()|Out-Null } })
$c.bNext.Add_MouseLeftButtonUp({ $s=Sess; if($s){ $s.TrySkipNextAsync()|Out-Null } })
$c.aPrev.Add_MouseLeftButtonUp({ $s=Sess; if($s){ $s.TrySkipPreviousAsync()|Out-Null } })
$c.aPlay.Add_MouseLeftButtonUp({ $s=Sess; if($s){ $s.TryTogglePlayPauseAsync()|Out-Null } })
# Pin the last active window on top of all windows (pushpin button)
Add-Type -Namespace U -Name P -MemberDefinition '[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow(); [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f); [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i); [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);' -ErrorAction Continue
$script:me=(New-Object Windows.Interop.WindowInteropHelper($w)).Handle; $script:lastFg=[IntPtr]::Zero
function PinState { if($script:lastFg -ne [IntPtr]::Zero -and [U.P]::IsWindow($script:lastFg) -and (([U.P]::GetWindowLong($script:lastFg,-20) -band 8) -ne 0)){ $f='#FFFFC83D' } else { $f='#66FFFFFF' }; $c.aPin.Fill=$f; $c.bPin.Fill=$f }
function PinToggle { $h=$script:lastFg; if($h -eq [IntPtr]::Zero -or -not [U.P]::IsWindow($h)){ return }
  $top=(([U.P]::GetWindowLong($h,-20) -band 8) -ne 0); $ins=$(if($top){[IntPtr](-2)}else{[IntPtr](-1)})
  [U.P]::SetWindowPos($h,$ins,0,0,0,0,0x0053)|Out-Null; PinState }
$c.aPin.Add_MouseLeftButtonUp({ PinToggle }); $c.bPin.Add_MouseLeftButtonUp({ PinToggle })
$c.aNext.Add_MouseLeftButtonUp({ $s=Sess; if($s){ $s.TrySkipNextAsync()|Out-Null } })
$ru=[Globalization.CultureInfo]::GetCultureInfo('ru-RU'); $script:wkDay=$null
function BuildCal($n){
  $c.cal.Children.Clear(); $c.calM.Text=$n.ToString('MMMM yyyy',$ru)
  foreach($h in @(1,2,3,4,5,6,0 | % { ([Globalization.CultureInfo]::CurrentUICulture.DateTimeFormat.GetAbbreviatedDayName([DayOfWeek]$_)).Substring(0,1).ToUpper() })){ $t=New-Object Windows.Controls.TextBlock; $t.Text=$h; $t.FontSize=11; $t.Foreground='#FF6C6C78'; $t.HorizontalAlignment='Center'; $t.Margin='0,0,0,3'; [void]$c.cal.Children.Add($t) }
  $f=Get-Date -Year $n.Year -Month $n.Month -Day 1; $off=([int]$f.DayOfWeek+6)%7
  1..$off | ? { $off } | % { [void]$c.cal.Children.Add((New-Object Windows.Controls.TextBlock)) }
  1..[DateTime]::DaysInMonth($n.Year,$n.Month) | % { $b=New-Object Windows.Controls.Border; $b.Width=26; $b.Height=26; $b.CornerRadius=[Windows.CornerRadius]::new(13)
    $t=New-Object Windows.Controls.TextBlock; $t.Text=$_; $t.FontSize=12.5; $t.HorizontalAlignment='Center'; $t.VerticalAlignment='Center'
    $dw=([int]$f.AddDays($_-1).DayOfWeek+6)%7
    if($_ -eq $n.Day){ $b.Background='#FF0A84FF'; $t.Foreground='White'; $t.FontWeight='SemiBold' } else { $t.Foreground=$(if($dw -ge 5){'#FFFF8A8A'}else{'#FFCFCFD8'}) }
    $b.Child=$t; [void]$c.cal.Children.Add($b) } }
function BuildWeek($n){ $c.aWeek.Children.Clear(); $mon=$n.Date.AddDays(-(([int]$n.DayOfWeek+6)%7)); $nm=@(1,2,3,4,5,6,0 | % { ([Globalization.CultureInfo]::CurrentUICulture.DateTimeFormat.GetAbbreviatedDayName([DayOfWeek]$_)).Substring(0,1).ToUpper() })
  0..6 | % { $d=$mon.AddDays($_); $sp=New-Object Windows.Controls.StackPanel; $sp.HorizontalAlignment='Center'
    $l=New-Object Windows.Controls.TextBlock; $l.Text=$nm[$_]; $l.FontSize=10; $l.Foreground='#FF6C6C78'; $l.HorizontalAlignment='Center'
    $b=New-Object Windows.Controls.Border; $b.Width=24; $b.Height=24; $b.CornerRadius=[Windows.CornerRadius]::new(12)
    $t=New-Object Windows.Controls.TextBlock; $t.Text=$d.Day; $t.FontSize=12; $t.HorizontalAlignment='Center'; $t.VerticalAlignment='Center'
    if($d -eq $n.Date){ $b.Background='#FF0A84FF'; $t.Foreground='White'; $t.FontWeight='SemiBold' } else { $t.Foreground=$(if($_ -ge 5){'#FFFF8A8A'}else{'#FFCFCFD8'}) }
    $b.Child=$t; [void]$sp.Children.Add($l); [void]$sp.Children.Add($b); [void]$c.aWeek.Children.Add($sp) } }
function Stats { if($st.cpu -ne $null){ $cpu=$st.cpu;$ram=$st.ram;$disk=$st.disk
  $c.pCpu.Value=$cpu;$c.vCpu.Text="$cpu%";$c.pRam.Value=$ram;$c.vRam.Text="$ram%";$c.pDisk.Value=$disk;$c.vDisk.Text="$disk%"; $c.aCpu.Value=$cpu;$c.aCpuV.Text="$cpu%";$c.aRam.Value=$ram;$c.aRamV.Text="$ram%";$c.aDisk.Value=$disk;$c.aDiskV.Text="$disk%" } }
$script:lastTrack=''
$geoPlay=[Windows.Media.Geometry]::Parse('M7,4 V20 L20,12 Z'); $geoPause=[Windows.Media.Geometry]::Parse('M6,4 H10 V20 H6 Z M14,4 H18 V20 H14 Z')
function Tick {
  $fg=[U.P]::GetForegroundWindow(); if($fg -ne [IntPtr]::Zero -and $fg -ne $script:me){ $script:lastFg=$fg; PinState }
  if(Test-Path "$dataDir\cmd.txt"){ $q=(Get-Content "$dataDir\cmd.txt" -Raw).Trim(); Remove-Item "$dataDir\cmd.txt"; if($q -eq 'close'){ Collapse } elseif($q -match '^\d$'){ Show-Page ([int]$q); $script:open=$false; Expand; $hide.Stop() } }
  $n=Get-Date; $hm=$n.ToString('HH:mm'); $c.tTime.Text=$hm; $c.cTime.Text=$hm; $c.aTime.Text=$hm
  if($script:wkDay -ne $n.Date){ $script:wkDay=$n.Date; BuildCal $n; BuildWeek $n; $c.aMonth.Text=$n.ToString('MMMM yyyy',$ru); $c.aDate.Text=$n.ToString('ddd, d MMM',$ru); $c.calD.Text=$n.ToString('d MMMM',$ru); $c.calW.Text=$n.ToString('dddd',$ru) }
  $s=Sess
  if($s){
    $p=Await ($s.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
    if($p -and $p.Title){
      $c.tTitle.Text=$p.Title; $c.tArtist.Text=$p.Artist; $c.aTitle.Text=$p.Title; $c.aArtist.Text=$p.Artist; $c.cTrack.Text=$p.Title
      $k=$p.Title+$p.Artist
      if($k -ne $script:lastTrack){ $script:lastTrack=$k
        try{ if($p.Thumbnail){
          $st=Await ($p.Thumbnail.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
          $m=[IO.WindowsRuntimeStreamExtensions].GetMethods() | ? { $_.Name -eq 'AsStreamForRead' -and $_.GetParameters().Count -eq 1 } | select -First 1
          $rs=$m.Invoke($null,@($st)); $ms=New-Object IO.MemoryStream; $rs.CopyTo($ms); $ms.Position=0
          $bi=New-Object Windows.Media.Imaging.BitmapImage; $bi.BeginInit(); $bi.StreamSource=$ms; $bi.CacheOption='OnLoad'; $bi.EndInit(); $bi.Freeze()
          $ib=New-Object Windows.Media.ImageBrush($bi); $ib.Stretch='UniformToFill'; $c.art.Background=$ib; $c.art.Child=$null; $c.aArt.Background=$ib; $c.aArt.Child=$null; $c.cArt.Background=$ib } }catch{} }
    }
    try{ $pl=($s.GetPlaybackInfo().PlaybackStatus -eq 'Playing'); $g=$(if($pl){$geoPause}else{$geoPlay}); $c.bPlay.Data=$g; $c.aPlay.Data=$g }catch{}
    try{ $tl=$s.GetTimelineProperties(); if($tl.EndTime.TotalSeconds -gt 0){ $c.pPos.Value=1000*$tl.Position.TotalSeconds/$tl.EndTime.TotalSeconds; $c.aPos.Value=$c.pPos.Value } }catch{}
  } else { $c.tTitle.Text=$TR.nothing; $c.aTitle.Text=$TR.nothing; $c.aArtist.Text=''; $c.tArtist.Text=''; $c.cTrack.Text=$TR.nothing }
}
function Wx {
  try{ if(-not $st.wx){ return }; $r=$st.wx | ConvertFrom-Json
    $k=[int]$r.code; $ic=if($k -eq 0){if($r.isDay){'☀'}else{'🌙'}}elseif($k -le 2){'⛅'}elseif($k -eq 3){'☁'}elseif($k -ge 95){'⛈'}elseif(($k -ge 71 -and $k -le 77) -or ($k -ge 85 -and $k -le 86)){'❄'}elseif($k -ge 45 -and $k -le 48){'🌫'}else{'🌧'}
    $t=[math]::Round([double]$r.temp); $tx=("{0}{1}°" -f $(if($t -gt 0){'+'}else{''}),$t)
    $wx="$ic $tx"; $c.tWx.Text=$wx; $c.aWx.Text=$wx; $c.cWx.Text=$wx; $c.calX.Text="$wx`n$($TR.wind) $([math]::Round([double]$r.wind)) $($TR.ms)`n$($st.city)"
  }catch{} }
function Srv {
  try{
    if(-not $cfg.server.url){ $m=[int]$st.up; $c.tSrvTitle.Text=$TR.sys
      $c.tSrv.Text=("{0}: {1} {2} {3} {4}`n{5} {6}% · {7} {8}% · {9} {10}%" -f $TR.up,[math]::Floor($m/1440),$TR.d,[math]::Floor(($m%1440)/60),$TR.h,$TR.load,$st.cpu,$TR.mem,$st.ram,$TR.disk,$st.disk)
      $c.tSvc.Text=''; $c.tSrv.Foreground='#FF7AF2A0'; $c.dot.Fill='#FF34D399'; return }
    if($cfg.server.name){ $c.tSrvTitle.Text=([string]$cfg.server.name).ToUpper() }
    if(-not $st.srv){ if($st.err){ throw 'x' }; return }; $r=$st.srv | ConvertFrom-Json
    $bad=@($r.services|?{-not $_.ok}); $ok=(-not $bad.Count) -and (-not $r.errors)
    $c.tSrv.Text=("{0} {1:p0} · {2} {3:p0} · {4} {5:p0}`n{6}: {7}" -f $TR.load,$r.cpu,$TR.mem,$r.ram,$TR.disk,$r.disk,$TR.errs,[int]$r.errors)
    $c.tSvc.Text=(($r.services|%{ $(if($_.ok){'●'}else{'○'})+' '+$_.name }) -join '   ')
    $c.tSrv.Foreground=$(if($ok){'#FF7AF2A0'}else{'#FFFF7A7A'}); $c.dot.Fill=$(if($ok){'#FF34D399'}else{'#FFFF5A5A'})
  }catch{ $c.tSrv.Text=$TR.noconn; $c.tSrv.Foreground='#FFFF7A7A'; $c.dot.Fill='#FFFF5A5A' } }
$t1=New-Object Windows.Threading.DispatcherTimer; $t1.Interval=[TimeSpan]::FromSeconds(2); $t1.Add_Tick({ Tick }); $t1.Start()
$t2=New-Object Windows.Threading.DispatcherTimer; $t2.Interval=[TimeSpan]::FromSeconds(3); $t2.Add_Tick({ Srv; Wx; if($script:open){ Stats } }); $t2.Start()
Tick; Srv; Wx
$w.Add_ContentRendered({ $d=New-Object System.Windows.Media.Animation.DoubleAnimation; $d.To=0; $d.Duration=[TimeSpan]::FromMilliseconds(700); $d.EasingFunction=$spring; $c.shT.BeginAnimation($Y_,$d) })
$null=$w.ShowDialog()
