# 低音谱点击验证：找视口内垂直堆叠的符头（和弦），点击其中最下面的符头，
# 验证命中的事件包含被点的符头（高亮元素应覆盖点击坐标）。
# 真实 OS 点击（合成点击会被未激活窗口丢弃）。
# 前置：App 带 --remote-debugging-port=9222 且已打开编辑页。
import json
import subprocess
import sys
import time

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, "tool")
from cdp_click_test import Conn, find_sheet  # noqa: E402

PS_ENUM = r"""
Add-Type @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class TopWin3 {
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
          res.Add(h.ToString() + "|" + r.Left + "," + r.Top + "," + r.Right + "," + r.Bottom);
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
[TopWin3]::Find($pidSet) | ForEach-Object { Write-Output $_ }
"""

PS_CLICK = r"""
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class Clicker3 {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  public struct RECT { public int Left, Top, Right, Bottom; }
}
'@
[Clicker3]::SetProcessDPIAware() | Out-Null
[Clicker3]::SetForegroundWindow([IntPtr]%MAINHWND%) | Out-Null
Start-Sleep -Milliseconds 600
# 真实点击标题栏（非客户区，无副作用）确保窗口在前台
$r = New-Object Clicker3+RECT
[Clicker3]::GetWindowRect([IntPtr]%MAINHWND%, [ref]$r) | Out-Null
$tx = [int](($r.Left + $r.Right) / 2); $ty = $r.Top + 12
[Clicker3]::SetCursorPos($tx, $ty) | Out-Null
Start-Sleep -Milliseconds 150
[Clicker3]::mouse_event(2,0,0,0,[IntPtr]::Zero); Start-Sleep -Milliseconds 40
[Clicker3]::mouse_event(4,0,0,0,[IntPtr]::Zero)
Start-Sleep -Milliseconds 600
[Clicker3]::SetCursorPos(%X%, %Y%) | Out-Null
Start-Sleep -Milliseconds 200
[Clicker3]::mouse_event(2,0,0,0,[IntPtr]::Zero)
Start-Sleep -Milliseconds 60
[Clicker3]::mouse_event(4,0,0,0,[IntPtr]::Zero)
Write-Output "title-click ($tx,$ty) then clicked %X%,%Y%"
"""


def ps(script: str) -> str:
    r = subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script],
        capture_output=True, text=True, timeout=30,
    )
    return (r.stdout or "") + (r.stderr or "")


def main():
    out = subprocess.run(
        ["tasklist", "/FI", "IMAGENAME eq ejmusic.exe", "/FO", "CSV"],
        capture_output=True, text=True,
    ).stdout
    pid = ""
    for line in out.splitlines():
        if line.lower().startswith('"ejmusic.exe'):
            pid = line.split('","')[1]
            break

    c = None
    for _ in range(15):
        try:
            c, _ = find_sheet()
            break
        except Exception:
            time.sleep(1)
    if c is None:
        print("FAIL: CDP 连不上")
        return 1
    n = 0
    while not n:
        n = c.evaluate('document.querySelectorAll("[class*=\'vf-notehead\']").length')
        time.sleep(1)
    print("视口内符头数:", n)

    layout = c.evaluate("""
      (function(){
        var els = document.querySelectorAll('[class*="vf-notehead"]');
        var items = [];
        for (var i = 0; i < els.length; i++) {
          var r = els[i].getBoundingClientRect();
          if (r.top < 0 || r.bottom > window.innerHeight - 20
              || r.left < 0 || r.right > window.innerWidth - 20) continue;
          items.push({i: i, x: r.left + r.width/2, y: r.top + r.height/2});
        }
        items.sort(function(a, b){ return a.x - b.x; });
        var chords = [], singles = [];
        var run = [];
        for (var j = 0; j < items.length; j++) {
          if (run.length && Math.abs(items[j].x - run[run.length-1].x) > 3) {
            if (run.length > 1) chords.push(run); else singles.push(run[0]);
            run = [];
          }
          run.push(items[j]);
        }
        if (run.length > 1) chords.push(run); else if (run.length) singles.push(run[0]);
        return {chordCount: chords.length, singleCount: singles.length,
                lowestOfFirstChord: chords.length
                  ? chords[0].reduce(function(m, p){ return p.y > m.y ? p : m; })
                  : null,
                lowestSingle: singles.length
                  ? singles.reduce(function(m, p){ return p.y > m.y ? p : m; })
                  : null};
      })()
    """)
    print("布局:", json.dumps(layout, ensure_ascii=False))
    target = layout["lowestOfFirstChord"] or layout["lowestSingle"]
    is_chord = layout["lowestOfFirstChord"] is not None
    if not target:
        print("FAIL: 视口内没有可点击符头")
        return 1
    print(f"目标: {'和弦最低符头' if is_chord else '低音谱单音'} CSS ({target['x']:.0f},{target['y']:.0f})")

    # WebView2 物理矩形 + DPR → 屏幕物理坐标
    enum = ps(PS_ENUM)
    rect = None
    for row in enum.splitlines():
        if "|" in row and row.split("|")[0].isdigit():
            rect = row.split("|")[1]
    if rect is None:
        print("FAIL: 没找到 WebView2 窗口:", enum)
        return 1
    L, T, _, _ = (int(v) for v in rect.split(","))
    dpr = c.evaluate("window.devicePixelRatio || 1")
    px = int(L + target["x"] * dpr)
    py = int(T + target["y"] * dpr)
    print(f"屏幕物理坐标: ({px},{py}) dpr={dpr}")

    main_hwnd = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "(Get-Process -Id %s).MainWindowHandle" % pid],
        capture_output=True, text=True).stdout.strip()
    c.evaluate("window.__ejmLastClick = undefined")
    print(ps(PS_CLICK.replace("%MAINHWND%", main_hwnd)
             .replace("%X%", str(px)).replace("%Y%", str(py))).strip())
    time.sleep(2)

    hit = c.evaluate("JSON.stringify(window.__ejmLastClick || null)")
    print("命中面包屑:", hit)
    if not hit:
        print("FAIL: 点击未送达")
        return 1
    if json.loads(hit)["s"] != 1:
        print("FAIL: 命中不是低音谱（s 应为 1）:", hit)
        return 1

    cover = c.evaluate("""
      (function(){
        var cx = %f, cy = %f;
        var els = document.querySelectorAll('[style*="rgb(26, 115, 232)"]');
        var out = [];
        for (var i = 0; i < els.length; i++) {
          var r = els[i].getBoundingClientRect();
          var ppx = r.left + r.width/2, ppy = r.top + r.height/2;
          if (Math.abs(ppx - cx) <= 12 && Math.abs(ppy - cy) <= 12) {
            out.push([Math.round(ppx), Math.round(ppy)]);
          }
        }
        return JSON.stringify({highlighted: els.length, covering: out});
      })()
    """ % (target["x"], target["y"]))
    data = json.loads(cover)
    print("高亮覆盖检查:", cover)
    if data["covering"]:
        h = json.loads(hit)
        print(f"PASS: 命中事件 m={h['m']} s={h['s']} k={h['k']}，"
              f"{len(data['covering'])} 个符头覆盖点击点")
        return 0
    print("FAIL: 命中的事件不包含被点击的符头（选错音符）")
    return 1


if __name__ == "__main__":
    sys.exit(main())
