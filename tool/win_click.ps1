param([int]$TargetPid, [int]$X, [int]$Y, [switch]$shot, [string]$shotPath)
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class WinOps {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  public struct RECT { public int Left, Top, Right, Bottom; }
}
'@
$p = Get-Process -Id $TargetPid
$h = $p.MainWindowHandle
[WinOps]::ShowWindow($h, 9) | Out-Null
[WinOps]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 700
$r = New-Object WinOps+RECT
[WinOps]::GetWindowRect($h, [ref]$r) | Out-Null
Write-Output ("rect: $($r.Left),$($r.Top) - $($r.Right),$($r.Bottom)")
if ($shot) {
  $w = $r.Right - $r.Left; $ht = $r.Bottom - $r.Top
  $bmp = New-Object System.Drawing.Bitmap $w, $ht
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size($w, $ht)))
  $bmp.Save($shotPath)
  $g.Dispose(); $bmp.Dispose()
  Write-Output "saved: $shotPath"
}
if ($X -gt 0 -and $Y -gt 0) {
  [WinOps]::SetCursorPos($X, $Y) | Out-Null
  Start-Sleep -Milliseconds 200
  [WinOps]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero)  # LEFTDOWN
  [WinOps]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero)  # LEFTUP
  Write-Output "clicked at $X,$Y"
}
