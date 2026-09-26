param([int]$X, [int]$Y)
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class U7 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, IntPtr e);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  public static IntPtr Found = IntPtr.Zero;
  public static bool Cb(IntPtr h, IntPtr l) {
    var sb = new StringBuilder(256); GetClassName(h, sb, 256);
    if (IsWindowVisible(h) && sb.ToString() == "FLUTTER_RUNNER_WIN32_WINDOW") { Found = h; return false; }
    return true;
  }
}
'@
[U7]::SetProcessDPIAware() | Out-Null
[U7]::EnumWindows([U7+EnumProc]{ param($h, $l) [U7]::Cb($h, $l) }, [IntPtr]::Zero) | Out-Null
if ([U7]::Found -eq [IntPtr]::Zero) { Write-Output "no app window"; exit 1 }
[U7]::ShowWindow([U7]::Found, 9) | Out-Null
Start-Sleep -Milliseconds 150
# ALT 键技巧：绕过 SetForegroundWindow 的前台锁
[U7]::keybd_event(0x12, 0, 0, [IntPtr]::Zero)
Start-Sleep -Milliseconds 60
[U7]::SetForegroundWindow([U7]::Found) | Out-Null
[U7]::keybd_event(0x12, 0, 2, [IntPtr]::Zero)
Start-Sleep -Milliseconds 400
$fg = [U7]::GetForegroundWindow()
Write-Output ("foreground={0} target={1}" -f ($fg -eq [U7]::Found), [U7]::Found)
[U7]::SetCursorPos($X, $Y) | Out-Null
Start-Sleep -Milliseconds 250
[U7]::mouse_event(0x2, 0, 0, 0, [IntPtr]::Zero)
Start-Sleep -Milliseconds 60
[U7]::mouse_event(0x4, 0, 0, 0, [IntPtr]::Zero)
Write-Output "clicked $X,$Y"
