param([int]$X, [int]$Y)
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class U8 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, IntPtr e);
  public static IntPtr Found = IntPtr.Zero;
  public static bool Cb(IntPtr h, IntPtr l) {
    var sb = new StringBuilder(256); GetClassName(h, sb, 256);
    if (IsWindowVisible(h) && sb.ToString() == "FLUTTER_RUNNER_WIN32_WINDOW") { Found = h; return false; }
    return true;
  }
  public static bool ForceForeground(IntPtr h) {
    for (int i = 0; i < 5; i++) {
      if (GetForegroundWindow() == h) return true;
      keybd_event(0x12, 0, 0, IntPtr.Zero);
      uint ft = GetWindowThreadProcessId(GetForegroundWindow(), IntPtr.Zero);
      uint ct = GetCurrentThreadId();
      if (ft != 0 && ft != ct) { AttachThreadInput(ct, ft, true); SetForegroundWindow(h); AttachThreadInput(ct, ft, false); }
      else { SetForegroundWindow(h); }
      keybd_event(0x12, 0, 2, IntPtr.Zero);
      System.Threading.Thread.Sleep(150);
    }
    return GetForegroundWindow() == h;
  }
}
'@
[U8]::SetProcessDPIAware() | Out-Null
[U8]::EnumWindows([U8+EnumProc]{ param($h, $l) [U8]::Cb($h, $l) }, [IntPtr]::Zero) | Out-Null
if ([U8]::Found -eq [IntPtr]::Zero) { Write-Output "no app window"; exit 1 }
[U8]::ShowWindow([U8]::Found, 9) | Out-Null
Start-Sleep -Milliseconds 150
$fg = [U8]::ForceForeground([U8]::Found)
Write-Output ("foreground={0}" -f $fg)
if (-not $fg) { exit 2 }
[U8]::SetCursorPos($X, $Y) | Out-Null
Start-Sleep -Milliseconds 250
[U8]::mouse_event(0x2, 0, 0, 0, [IntPtr]::Zero)
Start-Sleep -Milliseconds 60
[U8]::mouse_event(0x4, 0, 0, 0, [IntPtr]::Zero)
Write-Output "clicked $X,$Y"
