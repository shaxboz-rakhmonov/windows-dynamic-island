// Windows Dynamic Island — EXE: installer + tray + settings + update notification.
// Built with the C# compiler that ships with Windows (no SDK needed): see build.ps1.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management;
using System.Net;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using Microsoft.Win32;
using WF = System.Windows.Forms;

static class L
{
    public static bool Ru = System.Globalization.CultureInfo.CurrentUICulture.Name.StartsWith("ru", StringComparison.OrdinalIgnoreCase);
    public static string T(string ru, string en) { return Ru ? ru : en; }
}

static class App
{
    public const string Ver = "2.1.0";
    public const string Repo = "shaxboz-rakhmonov/windows-dynamic-island";
    public const string AssetName = "DynamicIsland-Setup.exe";
    public static string InstallDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DynamicIsland");
    public static string ExePath { get { return Path.Combine(InstallDir, "DynamicIsland.exe"); } }
    public static string PsPath { get { return Path.Combine(InstallDir, "DynamicIsland.ps1"); } }
    public static readonly string[] Payload = { "DynamicIsland.ps1", "claude-limits.cjs", "setup-claude.ps1", "config.example.json" };

    public static Stream Res(string name) { return Assembly.GetExecutingAssembly().GetManifestResourceStream(name); }

    public static System.Windows.Media.Imaging.BitmapFrame Logo()
    {
        var d = new System.Windows.Media.Imaging.PngBitmapDecoder(Res("logo.png"), System.Windows.Media.Imaging.BitmapCreateOptions.None, System.Windows.Media.Imaging.BitmapCacheOption.OnLoad);
        return d.Frames[0];
    }

    public static void Hidden(string file, string args, bool wait)
    {
        var psi = new ProcessStartInfo(file, args) { CreateNoWindow = true, UseShellExecute = false, WindowStyle = ProcessWindowStyle.Hidden };
        try { var p = Process.Start(psi); if (wait && p != null) p.WaitForExit(15000); } catch { }
    }

    // powershell.exe processes running our island script
    public static void KillIsland()
    {
        try
        {
            using (var s = new ManagementObjectSearcher("SELECT ProcessId,CommandLine FROM Win32_Process WHERE Name='powershell.exe'"))
                foreach (ManagementObject o in s.Get())
                {
                    var cl = (o["CommandLine"] as string) ?? "";
                    if (cl.IndexOf("DynamicIsland.ps1", StringComparison.OrdinalIgnoreCase) >= 0)
                        try { Process.GetProcessById(Convert.ToInt32(o["ProcessId"])).Kill(); } catch { }
                }
        }
        catch { }
    }

    public static void StartIsland()
    {
        var a = "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File \"" + PsPath + "\"";
        Hidden("powershell.exe", a, false);
    }

    public static void RestartIsland() { KillIsland(); Thread.Sleep(400); StartIsland(); }

    public static bool Autostart
    {
        get { using (var k = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run")) return k != null && k.GetValue("DynamicIsland") != null; }
        set
        {
            using (var k = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run", true))
            {
                if (value) k.SetValue("DynamicIsland", "\"" + ExePath + "\"");
                else k.DeleteValue("DynamicIsland", false);
            }
        }
    }
}

// settings.json: which widgets / pages are shown (read by DynamicIsland.ps1)
class Settings
{
    public static readonly string[][] Widgets = {
        new[]{"music","Музыка (плеер, обложка)","Music (player, cover)"},
        new[]{"calendar","Календарь на неделю","Week calendar"},
        new[]{"clock","Часы и дата","Clock and date"},
        new[]{"weather","Погода","Weather"},
        new[]{"system","Нагрузка ПК (процессор, память, диск)","PC load (CPU, RAM, disk)"},
        new[]{"gpu","Видеокарта (загрузка и температура)","Graphics card (load, temperature)"},
        new[]{"claude","Лимиты Claude (кружки)","Claude limits (rings)"},
        new[]{"idleplayer","Показывать плеер, когда ничего не играет","Show the player even when nothing is playing"},
        new[]{"snip","Прятать остров во время скриншота","Hide the island while taking a screenshot"}
    };
    public static readonly string[][] Pages = {
        new[]{"all","Страница «Всё в одном»","\"All in one\" page"},
        new[]{"music","Страница «Музыка»","\"Music\" page"},
        new[]{"calendar","Страница «Календарь»","\"Calendar\" page"},
        new[]{"server","Страница «Система / сервер»","\"System / server\" page"}
    };
    public Dictionary<string, bool> V = new Dictionary<string, bool>();
    static string File_ { get { return Path.Combine(App.InstallDir, "settings.json"); } }

    public bool Get(string grp, string key) { bool b; return V.TryGetValue(grp + "." + key, out b) ? b : key != "idleplayer"; }

    public static Settings Load()
    {
        var s = new Settings();
        try
        {
            var txt = File.ReadAllText(File_);
            foreach (var grp in new[] { "widgets", "pages" })
            {
                var m = Regex.Match(txt, "\"" + grp + "\"\\s*:\\s*\\{([^}]*)\\}");
                if (!m.Success) continue;
                foreach (Match kv in Regex.Matches(m.Groups[1].Value, "\"(\\w+)\"\\s*:\\s*(true|false)"))
                    s.V[grp + "." + kv.Groups[1].Value] = kv.Groups[2].Value == "true";
            }
        }
        catch { }
        return s;
    }

    public void Save()
    {
        var sb = new StringBuilder("{\n");
        Action<string, string[][]> grp = (name, items) =>
        {
            sb.Append("  \"" + name + "\": { ");
            sb.Append(string.Join(", ", items.Select(i => "\"" + i[0] + "\": " + (Get(name, i[0]) ? "true" : "false")).ToArray()));
            sb.Append(" }");
        };
        grp("widgets", Widgets); sb.Append(",\n"); grp("pages", Pages); sb.Append("\n}\n");
        Directory.CreateDirectory(App.InstallDir);
        File.WriteAllText(File_, sb.ToString(), new UTF8Encoding(false));
    }
}

static class Installer
{
    public static void Extract()
    {
        Directory.CreateDirectory(App.InstallDir);
        foreach (var n in App.Payload)
            using (var r = App.Res(n)) using (var f = File.Create(Path.Combine(App.InstallDir, n))) r.CopyTo(f);
        // PowerShell 5.1 needs a BOM for non-ASCII scripts
        var ps = App.PsPath; var bytes = File.ReadAllBytes(ps);
        if (!(bytes.Length > 2 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF)) File.WriteAllBytes(ps, new byte[] { 0xEF, 0xBB, 0xBF }.Concat(bytes).ToArray());
        using (var r = App.Res("logo.png")) using (var f = File.Create(Path.Combine(App.InstallDir, "logo.png"))) r.CopyTo(f);
    }

    static void StopOldTray()
    {
        var me = Process.GetCurrentProcess().Id;
        foreach (var p in Process.GetProcessesByName("DynamicIsland"))
            if (p.Id != me) { try { p.Kill(); p.WaitForExit(5000); } catch { } }
    }

    public static void Install(bool autostart, bool launch)
    {
        StopOldTray(); App.KillIsland(); Thread.Sleep(500);
        // an old PowerShell-based install used a scheduled task: remove it so only one copy starts
        App.Hidden("schtasks.exe", "/delete /tn WinDynamicIsland /f", true);
        Extract();
        var self = Process.GetCurrentProcess().MainModule.FileName;
        for (int i = 0; i < 12; i++)
        {
            try { File.Copy(self, App.ExePath, true); break; } catch { Thread.Sleep(400); }
        }
        App.Autostart = autostart;
        try
        {
            var sm = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "Windows Dynamic Island.lnk");
            dynamic sh = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));
            var lnk = sh.CreateShortcut(sm); lnk.TargetPath = App.ExePath; lnk.WorkingDirectory = App.InstallDir; lnk.IconLocation = App.ExePath; lnk.Save();
        }
        catch { }
        try
        {
            using (var k = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\WinDynamicIsland"))
            {
                k.SetValue("DisplayName", "Windows Dynamic Island");
                k.SetValue("DisplayVersion", App.Ver);
                k.SetValue("Publisher", "shaxboz-rakhmonov");
                k.SetValue("InstallLocation", App.InstallDir);
                k.SetValue("DisplayIcon", App.ExePath);
                k.SetValue("UninstallString", "\"" + App.ExePath + "\" --uninstall");
                k.SetValue("NoModify", 1, RegistryValueKind.DWord);
            }
        }
        catch { }
        try
        {   // optional Claude rings: hook the Claude Code status line when Claude Code + Node are present
            if (Directory.Exists(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".claude")))
                App.Hidden("powershell.exe", "-NoProfile -ExecutionPolicy Bypass -File \"" + Path.Combine(App.InstallDir, "setup-claude.ps1") + "\"", true);
        }
        catch { }
        if (launch) Process.Start(new ProcessStartInfo(App.ExePath) { UseShellExecute = false });
    }

    public static int Uninstall(bool silent)
    {
        if (!silent && WF.MessageBox.Show(L.T("Удалить Windows Dynamic Island?", "Uninstall Windows Dynamic Island?"), "Windows Dynamic Island", WF.MessageBoxButtons.YesNo, WF.MessageBoxIcon.Question) != WF.DialogResult.Yes) return 0;
        StopOldTray(); App.KillIsland();
        try { App.Autostart = false; } catch { }
        try { Registry.CurrentUser.DeleteSubKeyTree(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\WinDynamicIsland", false); } catch { }
        try { File.Delete(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "Windows Dynamic Island.lnk")); } catch { }
        // delete the folder after this process exits (the EXE itself is inside it)
        App.Hidden("cmd.exe", "/c ping 127.0.0.1 -n 3 >nul & rmdir /s /q \"" + App.InstallDir + "\"", false);
        return 0;
    }

    static void StopOldTray_() { }
}

// ---------- shared UI helpers
static class UI
{
    public static readonly Brush Bg = new SolidColorBrush(Color.FromRgb(18, 18, 22));
    public static readonly Brush Fg = new SolidColorBrush(Color.FromRgb(236, 236, 242));
    public static readonly Brush Dim = new SolidColorBrush(Color.FromRgb(142, 142, 153));
    public static readonly Brush Accent = new SolidColorBrush(Color.FromRgb(10, 132, 255));

    public static Button Btn(string text, bool primary)
    {
        var b = new Button { Content = text, Padding = new Thickness(22, 9, 22, 9), Margin = new Thickness(6, 0, 0, 0), Cursor = System.Windows.Input.Cursors.Hand, FontSize = 14, BorderThickness = new Thickness(0) };
        b.Foreground = Brushes.White; b.Background = primary ? Accent : new SolidColorBrush(Color.FromRgb(58, 58, 66));
        return b;
    }
    public static TextBlock Text(string t, double size, Brush fg, bool bold)
    {
        return new TextBlock { Text = t, FontSize = size, Foreground = fg, FontWeight = bold ? FontWeights.SemiBold : FontWeights.Normal, TextWrapping = TextWrapping.Wrap };
    }
    public static Window Base(string title, double w, double h)
    {
        var win = new Window { Title = title, Width = w, Height = h, Background = Bg, Foreground = Fg, WindowStartupLocation = WindowStartupLocation.CenterScreen, ResizeMode = ResizeMode.NoResize, FontFamily = new FontFamily("Segoe UI") };
        win.Icon = App.Logo();
        return win;
    }
}

class SetupWindow : Window
{
    public SetupWindow()
    {
        var w = UI.Base("Windows Dynamic Island", 480, 430); // copy basic props
        Title = w.Title; Width = w.Width; Height = w.Height; Background = UI.Bg; Foreground = UI.Fg; WindowStartupLocation = w.WindowStartupLocation; ResizeMode = ResizeMode.NoResize; FontFamily = w.FontFamily; Icon = w.Icon;
        var root = new StackPanel { Margin = new Thickness(34, 26, 34, 24) };
        var logo = new Image { Source = App.Logo(), Width = 96, Height = 96, HorizontalAlignment = HorizontalAlignment.Center };
        root.Children.Add(logo);
        var t = UI.Text("Windows Dynamic Island", 24, UI.Fg, true); t.HorizontalAlignment = HorizontalAlignment.Center; t.Margin = new Thickness(0, 14, 0, 4); root.Children.Add(t);
        var s = UI.Text(L.T("Остров сверху экрана: музыка, календарь, погода, нагрузка ПК.", "A Dynamic Island on top of your screen: music, calendar, weather, PC load."), 13, UI.Dim, false);
        s.TextAlignment = TextAlignment.Center; s.Margin = new Thickness(0, 0, 0, 20); root.Children.Add(s);
        var auto = new CheckBox { Content = L.T("Запускать вместе с Windows", "Start with Windows"), IsChecked = true, Foreground = UI.Fg, FontSize = 14, Margin = new Thickness(0, 0, 0, 8), HorizontalAlignment = HorizontalAlignment.Center };
        root.Children.Add(auto);
        var where = UI.Text(L.T("Папка установки: ", "Install folder: ") + App.InstallDir, 11, UI.Dim, false); where.TextAlignment = TextAlignment.Center; where.Margin = new Thickness(0, 0, 0, 24); root.Children.Add(where);
        var status = UI.Text("", 13, UI.Dim, false); status.TextAlignment = TextAlignment.Center; status.Margin = new Thickness(0, 0, 0, 12); root.Children.Add(status);
        var row = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center };
        var install = UI.Btn(L.T("Установить", "Install"), true); var close = UI.Btn(L.T("Отмена", "Cancel"), false);
        row.Children.Add(install); row.Children.Add(close); root.Children.Add(row);
        Content = root;
        close.Click += delegate { Close(); };
        install.Click += delegate
        {
            install.IsEnabled = false; close.IsEnabled = false; status.Text = L.T("Устанавливаю…", "Installing…");
            Dispatcher.BeginInvoke(new Action(() =>
            {
                try
                {
                    Installer.Install(auto.IsChecked == true, true);
                    status.Foreground = new SolidColorBrush(Color.FromRgb(52, 211, 153));
                    status.Text = L.T("Готово! Остров запущен, значок — в трее (внизу справа).", "Done! The island is running; the icon is in the tray (bottom right).");
                    install.Visibility = Visibility.Collapsed; close.Content = L.T("Закрыть", "Close"); close.IsEnabled = true;
                }
                catch (Exception e) { status.Foreground = Brushes.Salmon; status.Text = (L.T("Не получилось: ", "Failed: ") + e.Message); install.IsEnabled = true; close.IsEnabled = true; }
            }), DispatcherPriority.Background);
        };
    }
}

class SettingsWindow : Window
{
    public SettingsWindow()
    {
        Title = L.T("Настройки Dynamic Island", "Dynamic Island settings"); Width = 440; SizeToContent = SizeToContent.Height; Background = UI.Bg; Foreground = UI.Fg;
        WindowStartupLocation = WindowStartupLocation.CenterScreen; ResizeMode = ResizeMode.NoResize; FontFamily = new FontFamily("Segoe UI"); Icon = App.Logo();
        var cur = Settings.Load();
        var root = new StackPanel { Margin = new Thickness(28, 22, 28, 22) };
        var boxes = new Dictionary<string, CheckBox>();
        Action<string, string, string[][]> section = (title, grp, items) =>
        {
            var h = UI.Text(title, 15, UI.Fg, true); h.Margin = new Thickness(0, 8, 0, 8); root.Children.Add(h);
            foreach (var it in items)
            {
                var cb = new CheckBox { Content = L.T(it[1], it[2]), IsChecked = cur.Get(grp, it[0]), Foreground = UI.Fg, FontSize = 14, Margin = new Thickness(2, 3, 0, 3) };
                boxes[grp + "." + it[0]] = cb; root.Children.Add(cb);
            }
        };
        section(L.T("Что показывать на острове", "What the island shows"), "widgets", Settings.Widgets);
        section(L.T("Страницы (листаются колёсиком)", "Pages (scroll with the wheel)"), "pages", Settings.Pages);
        var h2 = UI.Text(L.T("Запуск", "Startup"), 15, UI.Fg, true); h2.Margin = new Thickness(0, 12, 0, 8); root.Children.Add(h2);
        var auto = new CheckBox { Content = L.T("Запускать вместе с Windows", "Start with Windows"), IsChecked = App.Autostart, Foreground = UI.Fg, FontSize = 14, Margin = new Thickness(2, 3, 0, 3) };
        root.Children.Add(auto);
        var pr = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 14, 0, 0) };
        pr.Children.Add(UI.Text(L.T("Быстро: ", "Presets: "), 13, UI.Dim, false));
        Action<string, string, string[]> preset = (ru, en, on) =>
        {
            var b = UI.Btn(L.T(ru, en), false); b.Padding = new Thickness(12, 5, 12, 5); b.FontSize = 12;
            b.Click += delegate { foreach (var kv in boxes) kv.Value.IsChecked = on.Contains(kv.Key) || kv.Key == "widgets.snip"; };
            pr.Children.Add(b);
        };
        preset("Всё", "Everything", boxes.Keys.Where(k => k != "widgets.idleplayer").ToArray());
        preset("Только музыка", "Music only", new[] { "widgets.music", "widgets.idleplayer", "pages.music" });
        preset("Только часы", "Clock only", new[] { "widgets.clock", "pages.all" });
        root.Children.Add(pr);
        var ver = UI.Text(L.T("Версия ", "Version ") + App.Ver, 11, UI.Dim, false); ver.Margin = new Thickness(0, 16, 0, 0); root.Children.Add(ver);
        var row = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 14, 0, 0) };
        var save = UI.Btn(L.T("Сохранить", "Save"), true); var cancel = UI.Btn(L.T("Отмена", "Cancel"), false);
        row.Children.Add(cancel); row.Children.Add(save); root.Children.Add(row);
        Content = root;
        cancel.Click += delegate { Close(); };
        save.Click += delegate
        {
            var s = new Settings();
            foreach (var kv in boxes) s.V[kv.Key] = kv.Value.IsChecked == true;
            s.Save(); App.Autostart = auto.IsChecked == true;
            App.RestartIsland(); Close();
        };
    }
}

class UpdateToast : Window
{
    public UpdateToast(string tag, string url)
    {
        WindowStyle = WindowStyle.None; AllowsTransparency = true; Background = Brushes.Transparent; Topmost = true; ShowInTaskbar = false; ResizeMode = ResizeMode.NoResize;
        Width = 360; SizeToContent = SizeToContent.Height;
        var card = new Border { Background = UI.Bg, CornerRadius = new CornerRadius(16), BorderBrush = new SolidColorBrush(Color.FromRgb(58, 58, 66)), BorderThickness = new Thickness(1), Padding = new Thickness(20, 16, 20, 16), Margin = new Thickness(10) };
        card.Effect = new System.Windows.Media.Effects.DropShadowEffect { BlurRadius = 18, Opacity = 0.5, ShadowDepth = 3 };
        var sp = new StackPanel();
        var top = new StackPanel { Orientation = Orientation.Horizontal };
        top.Children.Add(new Image { Source = App.Logo(), Width = 34, Height = 34, Margin = new Thickness(0, 0, 12, 0) });
        var tx = new StackPanel();
        tx.Children.Add(UI.Text(L.T("Вышло обновление", "Update available"), 15, UI.Fg, true));
        tx.Children.Add(UI.Text("Windows Dynamic Island v" + tag + "  (" + L.T("у вас ", "you have ") + App.Ver + ")", 12, UI.Dim, false));
        top.Children.Add(tx); sp.Children.Add(top);
        var status = UI.Text("", 12, UI.Dim, false); status.Margin = new Thickness(0, 10, 0, 0); sp.Children.Add(status);
        var row = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0, 14, 0, 0) };
        var later = UI.Btn(L.T("Позже", "Later"), false); var upd = UI.Btn(L.T("Обновить", "Update"), true);
        row.Children.Add(later); row.Children.Add(upd); sp.Children.Add(row);
        card.Child = sp; Content = card;
        Loaded += delegate { var a = SystemParameters.WorkArea; Left = a.Right - ActualWidth - 8; Top = a.Bottom - ActualHeight - 8; };
        later.Click += delegate { Close(); };
        upd.Click += delegate
        {
            upd.IsEnabled = false; later.IsEnabled = false; status.Text = L.T("Скачиваю…", "Downloading…");
            ThreadPool.QueueUserWorkItem(_ =>
            {
                try
                {
                    ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072;
                    var tmp = Path.Combine(Path.GetTempPath(), "DynamicIsland-Update-" + Guid.NewGuid().ToString("N") + ".exe");
                    using (var wc = new WebClient()) { wc.Headers["User-Agent"] = "WinDynamicIsland"; wc.DownloadFile(url, tmp); }
                    Dispatcher.Invoke(new Action(() => { status.Text = L.T("Устанавливаю…", "Installing…"); }));
                    Process.Start(new ProcessStartInfo(tmp, "--update") { UseShellExecute = false });
                    Tray.Quit();
                }
                catch (Exception e) { Dispatcher.Invoke(new Action(() => { status.Foreground = Brushes.Salmon; status.Text = L.T("Не получилось: ", "Failed: ") + e.Message; later.IsEnabled = true; })); }
            });
        };
    }
}

static class Tray
{
    static WF.NotifyIcon ni;
    static Mutex mx;
    static DispatcherTimer upTimer;
    static bool checking;

    public static void Quit()
    {
        try { App.KillIsland(); } catch { }
        try { if (ni != null) { ni.Visible = false; ni.Dispose(); } } catch { }
        Environment.Exit(0);
    }

    public static int Run()
    {
        bool created; mx = new Mutex(true, @"Local\WinDynamicIslandTray", out created);
        if (!created) return 0;
        var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        App.KillIsland(); App.StartIsland();
        ni = new WF.NotifyIcon { Icon = new System.Drawing.Icon(App.Res("app.ico")), Visible = true, Text = "Dynamic Island" };
        var menu = new WF.ContextMenuStrip();
        menu.Items.Add(L.T("Настройки…", "Settings…"), null, (s, e) => OpenSettings());
        var lay = new WF.ToolStripMenuItem(L.T("Расположение острова", "Island position"));
        var opts = new[] { new[] { "top", "Поверх всех окон", "Always on top" }, new[] { "normal", "Как обычное окно", "Like a normal window" }, new[] { "desktop", "Только на рабочем столе", "Desktop only" } };
        foreach (var o in opts)
        {
            var key = o[0]; var it = new WF.ToolStripMenuItem(L.T(o[1], o[2])) { Tag = key };
            it.Click += (s, e) => { try { File.WriteAllText(Path.Combine(App.InstallDir, "layer.txt"), key); } catch { } };
            lay.DropDownItems.Add(it);
        }
        lay.DropDownOpening += (s, e) =>
        {
            string cur = "top"; try { cur = File.ReadAllText(Path.Combine(App.InstallDir, "layer.txt")).Trim(); } catch { }
            foreach (WF.ToolStripMenuItem it in lay.DropDownItems) it.Checked = (string)it.Tag == cur;
        };
        menu.Items.Add(lay);
        menu.Items.Add(L.T("Проверить обновления", "Check for updates"), null, (s, e) => CheckUpdate(true));
        menu.Items.Add(L.T("Перезапустить остров", "Restart island"), null, (s, e) => ThreadPool.QueueUserWorkItem(_ => App.RestartIsland()));
        menu.Items.Add("-");
        var v = menu.Items.Add(L.T("Версия ", "Version ") + App.Ver); v.Enabled = false;
        menu.Items.Add(L.T("Выход", "Exit"), null, (s, e) => Quit());
        ni.ContextMenuStrip = menu;
        ni.DoubleClick += (s, e) => OpenSettings();
        upTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(25) };
        upTimer.Tick += (s, e) => { upTimer.Interval = TimeSpan.FromHours(6); CheckUpdate(false); };
        upTimer.Start();
        app.Run();
        return 0;
    }

    static SettingsWindow sw;
    static void OpenSettings()
    {
        if (sw != null) { sw.Activate(); return; }
        sw = new SettingsWindow(); sw.Closed += delegate { sw = null; }; sw.Show(); sw.Activate();
    }

    static Version Parse(string s) { Version v; return Version.TryParse(s, out v) ? v : new Version(0, 0); }

    static void CheckUpdate(bool manual)
    {
        if (checking) return; checking = true;
        ThreadPool.QueueUserWorkItem(_ =>
        {
            try
            {
                ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072;
                string j; using (var wc = new WebClient()) { wc.Headers["User-Agent"] = "WinDynamicIsland"; wc.Encoding = Encoding.UTF8; j = wc.DownloadString("https://api.github.com/repos/" + App.Repo + "/releases/latest"); }
                var tag = Regex.Match(j, "\"tag_name\"\\s*:\\s*\"v?([0-9.]+)\"");
                var url = Regex.Match(j, "\"browser_download_url\"\\s*:\\s*\"([^\"]*" + Regex.Escape(App.AssetName) + ")\"");
                if (tag.Success && url.Success && Parse(tag.Groups[1].Value) > Parse(App.Ver))
                    Application.Current.Dispatcher.Invoke(new Action(() => new UpdateToast(tag.Groups[1].Value, url.Groups[1].Value).Show()));
                else if (manual)
                    ni.ShowBalloonTip(3000, "Dynamic Island", L.T("У вас последняя версия (", "You have the latest version (") + App.Ver + ")", WF.ToolTipIcon.Info);
            }
            catch { if (manual) ni.ShowBalloonTip(3000, "Dynamic Island", L.T("Не удалось проверить обновления", "Could not check for updates"), WF.ToolTipIcon.Warning); }
            finally { checking = false; }
        });
    }
}

static class Program
{
    [STAThread]
    static int Main(string[] a)
    {
        var args = new HashSet<string>(a ?? new string[0], StringComparer.OrdinalIgnoreCase);
        var self = Process.GetCurrentProcess().MainModule.FileName;
        bool inInstall = string.Equals(Path.GetDirectoryName(self), App.InstallDir, StringComparison.OrdinalIgnoreCase);
        if (args.Contains("--uninstall")) return Installer.Uninstall(args.Contains("--silent"));
        if (args.Contains("--update"))
        {   // started by the tray after downloading a new version: keep the autostart choice, replace files, relaunch
            Installer.Install(App.Autostart, true); return 0;
        }
        if (inInstall) return Tray.Run();
        var app = new Application();
        app.Run(new SetupWindow());
        return 0;
    }
}
