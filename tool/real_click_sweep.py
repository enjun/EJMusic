# 真实 OS 点击扫描（ALT 前置 + SetCursorPos + mouse_event，非 CDP 合成）：
# 1) 两次标定点击拟合 物理→css 仿射；2) 对散布符头按仿射反算物理坐标
# 真实点击，回读页面蓝色选中（style.fill）的 __ejmEi 扩展属性身份，
# 必须与所点符头的身份一致。模拟用户真实链路：OS→Flutter→插件→WebView2。
# 前置：App 以 9222 CDP 启动停在编辑页（CDP 仅用于读状态，点击走真实 OS）。
import json
import subprocess
import sys
import time

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, "tool")
from cdp_click_test import Conn, find_sheet  # noqa: E402


def os_click(x, y):
    r = subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
         "-File", "tool/os_click2.ps1", "-X", str(x), "-Y", str(y)],
        capture_output=True, text=True, timeout=30)
    return r.stdout.strip()


def last_click(c):
    return json.loads(c.evaluate(
        "JSON.stringify((window.__ejmClickLog||[]).slice(-1)[0]||null)"))


def selection(c):
    return json.loads(c.evaluate("""
(function(){
  var heads = document.querySelectorAll("[class*='vf-notehead']");
  var idx = null, n = 0;
  for (var i = 0; i < heads.length; i++) {
    if (heads[i].style.fill) { idx = heads[i].__ejmEi; n++; }
  }
  return JSON.stringify({idx: idx === undefined ? null : idx, n: n});
})()
"""))


def targets(c):
    return json.loads(c.evaluate("""
(function(){
  var els = document.querySelectorAll("[class*='vf-notehead']");
  var sx = window.scrollX, sy = window.scrollY, out = [];
  for (var i = 0; i < els.length; i++) {
    var r = els[i].getBoundingClientRect();
    if (!r.width || !r.height) continue;
    var e = els[i].__ejmEi;
    if (e === undefined) continue;
    out.push({dx: r.left + sx + r.width/2, dy: r.top + sy + r.height/2,
              idx: e});
  }
  return JSON.stringify(out);
})()
"""))


def cursor_pos(c):
    return json.loads(c.evaluate("""
(function(){
  var el = document.getElementById('cursorImg-0');
  if (!el) return JSON.stringify(null);
  var r = el.getBoundingClientRect();
  return JSON.stringify({x: r.left + window.scrollX + r.width/2,
                         y: r.top + window.scrollY + r.height/2});
})()
"""))


def main():
    c, _ = find_sheet()
    if c is None:
        print("FAIL: CDP 连不上")
        return 1
    # 安装点击记录器（真实点击的 DOM 侧回执）
    c.evaluate("""
(function(){
  window.__ejmClickLog = [];
  document.addEventListener('click', function(ev){
    var t = ev.target, idx;
    while (t && t !== document.body) {
      if (t.__ejmEi !== undefined) { idx = t.__ejmEi; break; }
      t = t.parentElement;
    }
    window.__ejmClickLog.push({x: ev.clientX, y: ev.clientY,
                               hit: idx === undefined ? null : idx,
                               t: Date.now()});
  }, true);
})()
""")
    n = c.evaluate("document.querySelectorAll(\"[class*='vf-notehead']\").length")
    print("符头数:", n)
    c.evaluate("window.scrollTo(0,0)")
    time.sleep(0.8)
    c.evaluate("window.__ejmClickLog = []")

    # 两点标定（视口 css <- 物理）
    cal = [(200, 420), (1100, 700)]
    pts = []
    for px, py in cal:
        c.evaluate("window.__ejmClickLog = []")
        os_click(px, py)
        got = None
        for _ in range(20):
            time.sleep(0.1)
            got = last_click(c)
            if got:
                break
        if not got:
            print(f"FAIL: 真实点击未送达 ({px},{py})")
            return 1
        pts.append((px, py, got["x"], got["y"]))
        print(f"  标定 物理({px},{py}) -> css({got['x']},{got['y']})")
    sx = (pts[1][2] - pts[0][2]) / (pts[1][0] - pts[0][0])
    sy = (pts[1][3] - pts[0][3]) / (pts[1][1] - pts[0][1])
    ox = pts[0][2] - sx * pts[0][0]
    oy = pts[0][3] - sy * pts[0][1]
    print(f"物理->css 仿射: x={sx:.4f} y={sy:.4f} 截距=({ox:.1f},{oy:.1f})")

    # 选散布的符头目标：每 40 个取 1 个，且必须在当前视口附近可点
    tgs = targets(c)
    step = max(1, len(tgs) // 15)
    picked = tgs[::step][:15]
    print("真实点击目标数:", len(picked))

    bad = []
    for i, t in enumerate(picked):
        c.evaluate(f"window.scrollTo(0, {t['dy'] - 300})")
        time.sleep(0.5)
        v = json.loads(c.evaluate(
            "(function(){return JSON.stringify({sx:window.scrollX,"
            "sy:window.scrollY})})()"))
        vx = t["dx"] - v["sx"]
        vy = t["dy"] - v["sy"]
        px = int(round((vx - ox) / sx))
        py = int(round((vy - oy) / sy))
        c.evaluate("window.__ejmClickLog = []")
        os_click(px, py)
        got = None
        for _ in range(20):
            time.sleep(0.1)
            got = last_click(c)
            if got:
                break
        time.sleep(0.4)
        sel = selection(c)
        cur = cursor_pos(c)
        # 绿色光标必须落在所点事件上（x 偏差 <60px；光标若还停在
        # 小节第一个步位，中后段音符处偏差通常 >100px）
        curDx = abs(cur["x"] - t["dx"]) if cur else None
        ok = (got is not None and sel["idx"] == t["idx"]
              and curDx is not None and curDx < 60)
        status = "OK" if ok else "BAD"
        curX = f"{cur['x']:.0f}" if cur else "?"
        dev = f"{curDx:.0f}" if curDx is not None else "?"
        print(f"  [{status}] idx={t['idx']} css=({vx:.0f},{vy:.0f}) "
              f"物理=({px},{py}) 收到css="
              f"({got['x'] if got else '?'},{got['y'] if got else '?'}) "
              f"选中={sel['idx']}(n={sel['n']}) "
              f"光标x={curX} 目标x={t['dx']:.0f} 偏差={dev}")
        if not ok:
            bad.append(t)
    print(f"完成：{len(picked)} 个真实点击，错误 {len(bad)}")
    if not bad:
        print("PASS: 真实点击选中与光标全部正确")
        return 0
    print("FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
