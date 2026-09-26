# 坐标级点击一致性全量验证（模拟用户真实点击路径）：
# 每个可见符头取视口中心坐标，用 CDP Input.dispatchMouseEvent 点击
# （走浏览器真实命中测试，等价用户点击），命中身份必须等于
# __ejmOSMD 图形模型里离点击点最近的 entry。
# 前置：App 带 --remote-debugging-port=9222，构建资产已注入 __ejmOSMD。
import json
import sys
import time

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, "tool")
from cdp_click_test import Conn, find_sheet  # noqa: E402

ENUM = """
(function(){
  var osmd = window.__ejmOSMD;
  if (!osmd) return JSON.stringify({error: 'no osmd'});
  var sx = window.scrollX, sy = window.scrollY;
  var entries = [];
  var ms = osmd.GraphicSheet.MeasureList;
  for (var mi = 0; mi < ms.length; mi++) {
    for (var si = 0; si < ms[mi].length; si++) {
      var gm = ms[mi][si]; if (!gm) continue;
      var ses = gm.staffEntries || [];
      for (var ei = 0; ei < ses.length; ei++) {
        var ves = ses[ei].graphicalVoiceEntries || [];
        if (!ves.length) continue;
        var notes = ves[0].notes || [];
        if (!notes.length) continue;
        var g = null;
        try { g = notes[0].getSVGGElement(); } catch (e) {}
        if (!g || !g.getBoundingClientRect) continue;
        var heads = g.querySelectorAll('[class*="vf-notehead"]');
        var pts = [];
        for (var n = 0; n < heads.length; n++) {
          var hr = heads[n].getBoundingClientRect();
          if (!hr.width && !hr.height) continue;
          pts.push({x: hr.left + sx + hr.width/2, y: hr.top + sy + hr.height/2});
        }
        if (!pts.length) {
          var gr = g.getBoundingClientRect();
          pts.push({x: gr.left + sx + gr.width/2, y: gr.top + sy + gr.height/2});
        }
        entries.push({m: mi, s: si, k: ei, pts: pts});
      }
    }
  }
  // 目标按文档坐标收集（滚动不变），点击前再用当时 scroll 换算视口坐标
  var els = document.querySelectorAll('[class*="vf-notehead"]');
  var targets = [];
  for (var i = 0; i < els.length; i++) {
    var r = els[i].getBoundingClientRect();
    if (!r.width && !r.height) continue;
    var dx = r.left + sx + r.width/2, dy = r.top + sy + r.height/2;
    var best = -1, bestQ = Infinity;
    for (var a = 0; a < entries.length; a++) {
      var qs = entries[a].pts;
      for (var b = 0; b < qs.length; b++) {
        var qx = qs[b].x - dx, qy = qs[b].y - dy;
        var q = qx*qx + qy*qy;
        if (q < bestQ) { bestQ = q; best = a; }
      }
    }
    if (best >= 0 && bestQ <= 36) {
      targets.push({dx: dx, dy: dy,
                    m: entries[best].m, s: entries[best].s, k: entries[best].k});
    }
  }
  return JSON.stringify({entries: entries.length, targets: targets});
})()
"""

# 点击前一刻用当前 scroll 把文档坐标换算成视口坐标，
# 消除"上次点击触发滚动"的竞态
TOVIEW = """
(function(){
  var t = document.querySelectorAll('[class*="vf-notehead"]');
  return JSON.stringify({x: %f - window.scrollX, y: %f - window.scrollY,
                         w: window.innerWidth, h: window.innerHeight});
})()
"""


def main():
    c = None
    for _ in range(20):
        try:
            c, _ = find_sheet()
            break
        except Exception:
            time.sleep(1)
    if c is None:
        print("FAIL: CDP 连不上")
        return 1
    deadline = time.time() + 60
    n = 0
    while not n and time.time() < deadline:
        try:
            n = c.evaluate('document.querySelectorAll("[class*=\'vf-notehead\']").length')
        except Exception:
            pass
        time.sleep(1)
    print("符头数:", n)

    data = json.loads(c.evaluate(ENUM))
    if "error" in data:
        print("FAIL:", data["error"])
        return 1
    targets = data["targets"]
    print(f"图形模型 entries={data['entries']}，可验证目标 {len(targets)} 个")

    bad = []
    checked = 0
    for idx, t in enumerate(targets):
        # 目标不在视口内则先滚过去（模拟用户翻页后点击）
        pos = json.loads(c.evaluate(TOVIEW % (t["dx"], t["dy"])))
        if not (5 <= pos["y"] <= pos["h"] - 5 and 5 <= pos["x"] <= pos["w"] - 5):
            c.evaluate(f"window.scrollTo(0, {t['dy'] - pos['h'] / 2})")
            time.sleep(0.4)
            pos = json.loads(c.evaluate(TOVIEW % (t["dx"], t["dy"])))
            if not (5 <= pos["y"] <= pos["h"] - 5
                    and 5 <= pos["x"] <= pos["w"] - 5):
                continue
        c.evaluate("window.__ejmLastClick = undefined")
        c.click(pos["x"], pos["y"])
        hit = None
        for _ in range(20):
            try:
                v = c.evaluate("JSON.stringify(window.__ejmLastClick || null)")
            except Exception:
                v = None
            if v and v != "null":
                hit = json.loads(v)
                break
            time.sleep(0.05)
        checked += 1
        if hit is None:
            bad.append({**t, "pos": [pos["x"], pos["y"]], "hit": None})
        elif (hit["m"], hit["s"], hit["k"]) != (t["m"], t["s"], t["k"]):
            bad.append({**t, "pos": [pos["x"], pos["y"]], "hit": hit})
        # 等可能发生的滚动稳定后再继续
        time.sleep(0.3)
        if (idx + 1) % 50 == 0:
            print(f"  进度 {idx+1}/{len(targets)}，已点 {checked}，错误 {len(bad)}")

    print(f"完成 {checked} 次真实坐标点击，不一致 {len(bad)} 个")
    for b in bad[:10]:
        print("  不一致:", json.dumps(b, ensure_ascii=False))
    if not bad:
        print(f"PASS: {checked} 个符头坐标点击全部命中正确事件")
        return 0
    print("FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
