Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class CO {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  public struct RECT { public int L, T, R, B; }
  public struct POINT { public int X, Y; }
  public static IntPtr Found = IntPtr.Zero;
  public static bool Cb(IntPtr h, IntPtr l) {
    var sb = new StringBuilder(256); GetClassName(h, sb, 256);
    if (IsWindowVisible(h) && sb.ToString() == "FLUTTER_RUNNER_WIN32_WINDOW") { Found = h; return false; }
    return true;
  }
}
'@
[CO]::SetProcessDPIAware() | Out-Null
[CO]::EnumWindows([CO+EnumProc]{ param($h, $l) [CO]::Cb($h, $l) }, [IntPtr]::Zero) | Out-Null
if ([CO]::Found -eq [IntPtr]::Zero) { Write-Output "{}"; exit 1 }
$p = New-Object CO+POINT
$p.X = 0; $p.Y = 0
[CO]::ClientToScreen([CO]::Found, [ref]$p) | Out-Null
$r = New-Object CO+RECT
[CO]::GetClientRect([CO]::Found, [ref]$r) | Out-Null
Write-Output ("{0}" -f (@{x=$p.X; y=$p.Y; w=$r.R; h=$r.B} | ConvertTo-Json -Compress))
