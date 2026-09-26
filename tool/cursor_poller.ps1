# 物理光标轨迹记录器：每 25ms 记录 GetCursorPos + 左键状态，写到 build\cursor_log.txt
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class C2 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out P p);
  [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int k);
  public struct P { public int x, y; }
}
'@
[C2]::SetProcessDPIAware() | Out-Null
$sw = [System.Diagnostics.Stopwatch]::StartNew()
while ($true) {
  $p = New-Object C2+P
  [C2]::GetCursorPos([ref]$p) | Out-Null
  $down = ([C2]::GetAsyncKeyState(1) -band 0x8000) -ne 0
  Add-Content -Path "build\cursor_log.txt" -Value ("{0} {1} {2} {3}" -f $sw.ElapsedMilliseconds, $p.x, $p.y, $(if ($down) {1} else {0})) -Encoding ASCII
  Start-Sleep -Milliseconds 25
}
