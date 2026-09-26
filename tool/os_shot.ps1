param([string]$Out = "build\os.png")
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class D1 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  public static IntPtr Found = IntPtr.Zero;
  public static bool Cb(IntPtr h, IntPtr l) {
    var sb = new StringBuilder(256); GetClassName(h, sb, 256);
    if (IsWindowVisible(h) && sb.ToString() == "FLUTTER_RUNNER_WIN32_WINDOW") { Found = h; return false; }
    return true;
  }
}
'@
[D1]::SetProcessDPIAware() | Out-Null
[D1]::EnumWindows([D1+EnumProc]{ param($h, $l) [D1]::Cb($h, $l) }, [IntPtr]::Zero) | Out-Null
if ([D1]::Found -ne [IntPtr]::Zero) {
  [D1]::ShowWindow([D1]::Found, 9) | Out-Null
  [D1]::SetForegroundWindow([D1]::Found) | Out-Null
  Start-Sleep -Milliseconds 500
}
$b = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap($b.Width, $b.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size)
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output ("saved {0} {1}x{2}" -f $Out, $b.Width, $b.Height)
