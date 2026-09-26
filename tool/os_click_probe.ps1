param([int]$WebHwnd, [int]$MainHwnd, [int]$X, [int]$Y)
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class U5 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern uint SendInput(uint n, INPUT[] i, int s);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)]
  public struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Sequential)]
  public struct INPUT { public uint type; public MOUSEINPUT mi; }
  public const uint LEFTDOWN = 0x2, LEFTUP = 0x4, ABSOLUTE = 0x8000, VIRTUALDESK = 0x4000;
}
'@
[U5]::SetProcessDPIAware() | Out-Null
$SWP_NOMOVE = 0x2; $SWP_NOSIZE = 0x1; $SWP_SHOWWINDOW = 0x40
$TOPMOST = [IntPtr](-1); $NOTOPMOST = [IntPtr](-2)
[U5]::SetWindowPos([IntPtr]$WebHwnd, $TOPMOST, 0,0,0,0, $SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_SHOWWINDOW) | Out-Null
Start-Sleep -Milliseconds 200
[U5]::SetWindowPos([IntPtr]$WebHwnd, $NOTOPMOST, 0,0,0,0, $SWP_NOMOVE -bor $SWP_NOSIZE -bor $SWP_SHOWWINDOW) | Out-Null
Start-Sleep -Milliseconds 200
[U5]::SetForegroundWindow([IntPtr]$MainHwnd) | Out-Null
Start-Sleep -Milliseconds 300
[U5]::SetCursorPos($X, $Y) | Out-Null
Start-Sleep -Milliseconds 200
# SendInput 绝对坐标（0..65535 归一化到虚拟桌面）
$sm = [System.Windows.Forms.SystemInformation]::VirtualScreen
$nx = [int](($X - $sm.Left) * 65535 / ($sm.Width - 1))
$ny = [int](($Y - $sm.Top) * 65535 / ($sm.Height - 1))
$down = New-Object U5+INPUT
$down.type = 0; $down.mi.dx = $nx; $down.mi.dy = $ny
$down.mi.dwFlags = [U5]::LEFTDOWN -bor [U5]::ABSOLUTE -bor [U5]::VIRTUALDESK
$up = New-Object U5+INPUT
$up.type = 0; $up.mi.dx = $nx; $up.mi.dy = $ny
$up.mi.dwFlags = [U5]::LEFTUP -bor [U5]::ABSOLUTE -bor [U5]::VIRTUALDESK
$inputs = [U5+INPUT[]]@($down, $up)
$null = [U5]::SendInput(2, $inputs, [System.Runtime.InteropServices.Marshal]::SizeOf([type][U5+INPUT]))
Start-Sleep -Milliseconds 100
Write-Output "sent $X,$Y"
