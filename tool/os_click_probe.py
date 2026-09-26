# OS 级真实点击探针：定位 WebView2 HWND 物理矩形 + CDP 符头坐标，
# 换算屏幕物理坐标后真实点击，读页面诊断面包屑对照。
# 前置：App 带 --remote-debugging-port=9222 且已打开编辑页。
import json
import subprocess
import sys
import time
import urllib.request

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, "tool")
from cdp_click_test import Conn, find_sheet  # noqa: E402

PS_ENUM = r"""
Add-Type @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class TopWin2 {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public struct RECT { public int Left, Top, Right, Bottom; }
  public static List<string> Find(HashSet<uint> pids) {
    SetProcessDPIAware();
    var res = new List<string>();
    EnumWindows((h, l) => {
      uint pid; GetWindowThreadProcessId(h, out pid);
      if (pids.Contains(pid)) {
        var sb = new StringBuilder(256); GetClassName(h, sb, 256);
        RECT r; GetWindowRect(h, out r);
        if (IsWindowVisible(h) && sb.ToString().StartsWith("Chrome_WidgetWin_1")) {
          res.Add(h.ToString() + "|" + sb.ToString() + "|" + r.Left + "," + r.Top + "," + r.Right + "," + r.Bottom);
        }
      }
      return true;
    }, IntPtr.Zero);
    return res;
  }
}
'@
$pidSet = New-Object 'System.Collections.Generic.HashSet[uint32]'
Get-Process msedgewebview2, ejmusic -ErrorAction SilentlyContinue | ForEach-Object { [void]$pidSet.Add([uint32]$_.Id) }
[TopWin2]::Find($pidSet) | ForEach-Object { Write-Output $_ }
"""

PS_CLICK = r"""
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class Clicker {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr SetActiveWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
}
'@
[Clicker]::SetProcessDPIAware() | Out-Null
[Clicker]::SetForegroundWindow([IntPtr]%MAINHWND%) | Out-Null
Start-Sleep -Milliseconds 600
[Clicker]::SetCursorPos(%X%, %Y%) | Out-Null
Start-Sleep -Milliseconds 200
[Clicker]::mouse_event(2,0,0,0,[IntPtr]::Zero)
Start-Sleep -Milliseconds 60
[Clicker]::mouse_event(4,0,0,0,[IntPtr]::Zero)
Start-Sleep -Milliseconds 800
# 点击谱面之后立刻发键盘：验证 webview 拿走输入焦点后按键是否仍到 Flutter
# → 右方向键 (VK 0x27)，再 'a' 琴键 (VK 0x41)
[Clicker]::keybd_event(0x27,0,0,[IntPtr]::Zero)
Start-Sleep -Milliseconds 50
[Clicker]::keybd_event(0x27,0,2,[IntPtr]::Zero)
Start-Sleep -Milliseconds 400
[Clicker]::keybd_event(0x41,0,0,[IntPtr]::Zero)
Start-Sleep -Milliseconds 50
[Clicker]::keybd_event(0x41,0,2,[IntPtr]::Zero)
Write-Output "clicked %X%,%Y% + keys RIGHT,A"
"""


def ps(script: str) -> str:
    r = subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script],
        capture_output=True, text=True, timeout=30,
    )
    return (r.stdout or "") + (r.stderr or "")


def main():
    pid = ""
    out = subprocess.run(
        ["tasklist", "/FI", "IMAGENAME eq ejmusic.exe", "/FO", "CSV"],
        capture_output=True, text=True,
    ).stdout
    for line in out.splitlines():
        if line.lower().startswith('"ejmusic.exe'):
            pid = line.split('","')[1]
            break
    print("ejmusic pid:", pid)

    enum = ps(PS_ENUM)
    print("可见 WebView2 顶层窗口:")
    hwnd = None
    for row in enum.splitlines():
        print(" ", row)
        if "Chrome_WidgetWin_1" in row:
            hwnd = row.split("|")[0]
    if hwnd is None:
        print("FAIL: 没找到 WebView2 窗口")
        return 1
    rect = [r for r in enum.splitlines() if r.startswith(hwnd)][0].split("|")[2]
    L, T, R, B = (int(v) for v in rect.split(","))
    print("WebView2 HWND:", hwnd, "物理矩形:", (L, T, R, B))

    for attempt in range(10):
        c, _ = find_sheet()
        if c:
            break
        time.sleep(1)
    n = 0
    while not n:
        n = c.evaluate("document.querySelectorAll('[class*=\"vf-notehead\"]').length")
        time.sleep(1)
    target = c.evaluate(
        """(function(){
          var els = document.querySelectorAll('[class*="vf-notehead"]');
          for (var i = 0; i < els.length; i++) {
            var r = els[i].getBoundingClientRect();
            if (r.top > 10 && r.bottom < window.innerHeight - 10
                && r.left > 10 && r.right < window.innerWidth - 10) {
              return {i: i, x: r.left + r.width/2, y: r.top + r.height/2};
            }
          }
          return null;
        })()"""
    )
    dpr = c.evaluate("window.devicePixelRatio || 1")
    print("目标符头 CSS 坐标:", target, "devicePixelRatio:", dpr)

    px = int(L + target["x"] * dpr)
    py = int(T + target["y"] * dpr)
    print("换算屏幕物理坐标:", (px, py))

    c.evaluate("window.__ejmLastRawClick = undefined; window.__ejmLastClick = undefined")
    main_hwnd = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "(Get-Process -Id %s).MainWindowHandle" % pid],
        capture_output=True, text=True).stdout.strip()
    print("主窗口句柄:", main_hwnd)
    print(ps(PS_CLICK.replace("%MAINHWND%", main_hwnd)
             .replace("%X%", str(px)).replace("%Y%", str(py))).strip())
    time.sleep(3)
    print("原始点击面包屑:", c.evaluate("JSON.stringify(window.__ejmLastRawClick || null)"))
    print("命中面包屑:", c.evaluate("JSON.stringify(window.__ejmLastClick || null)"))
    log = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "Get-Content build/direct_run.log -Tail 12"],
        capture_output=True, text=True, encoding="utf-8", errors="replace")
    print("--- Dart 最近日志:")
    print(log.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
