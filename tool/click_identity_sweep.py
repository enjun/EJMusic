# 点击-高亮一致性全量验证（修复后）：
# A. 每个 vf-notehead 元素派发点击 → 自身必须被蓝色高亮（els=符头组，
#    setSelection 直接填充被点元素）且 __ejmLastClick 有命中。
# B. 用 __ejmOSMD 重建图形模型真值：无符头的 entry（休止符）点击其
#    stavenote 组 → 命中身份必须等于该 entry，且组自身被高亮。
# 前置：App 带 --remote-debugging-port=9222，构建资产已注入 __ejmOSMD。
import json
import sys
import time

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, "tool")
from cdp_click_test import Conn, find_sheet  # noqa: E402

SWEEP = """
(function(){
  var els = document.querySelectorAll('[class*="vf-notehead"]');
  var bad = [], total = 0;
  for (var i = 0; i < els.length; i++) {
    var el = els[i];
    var r = el.getBoundingClientRect();
    if (!r.width && !r.height) continue;
    total++;
    var cx = r.left + r.width / 2, cy = r.top + r.height / 2;
    window.__ejmLastClick = undefined;
    el.dispatchEvent(new MouseEvent('click', {
      clientX: cx, clientY: cy, bubbles: true
    }));
    var hit = window.__ejmLastClick;
    var selfStyled = (el.getAttribute('style') || '')
      .indexOf('rgb(26, 115, 232)') >= 0;
    if (!selfStyled || !hit) {
      bad.push({i: i, hit: hit || null, selfStyled: selfStyled,
                pt: [Math.round(cx), Math.round(cy)]});
    }
  }
  return {total: total, badCount: bad.length, sample: bad.slice(0, 10)};
})()
"""

REST_CHECK = """
(function(){
  var osmd = window.__ejmOSMD;
  if (!osmd) return {error: 'no osmd handle'};
  var sx = window.scrollX, sy = window.scrollY;
  var groups = [];
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
        if (g.querySelectorAll('[class*="vf-notehead"]').length) continue;
        groups.push({m: mi, s: si, k: ei, g: g});
      }
    }
  }
  var bad = [];
  for (var i = 0; i < groups.length; i++) {
    var g = groups[i].g;
    var r = g.getBoundingClientRect();
    var cx = r.left + r.width / 2, cy = r.top + r.height / 2;
    window.__ejmLastClick = undefined;
    g.dispatchEvent(new MouseEvent('click', {
      clientX: cx, clientY: cy, bubbles: true
    }));
    var hit = window.__ejmLastClick;
    var ok = hit && hit.m === groups[i].m && hit.s === groups[i].s
          && hit.k === groups[i].k;
    var selfStyled = (g.getAttribute('style') || '')
      .indexOf('rgb(26, 115, 232)') >= 0;
    if (!ok || !selfStyled) {
      bad.push({msk: groups[i].m + ',' + groups[i].s + ',' + groups[i].k,
                hit: hit || null, selfStyled: selfStyled});
    }
  }
  return {restGroups: groups.length, badCount: bad.length, sample: bad};
})()
"""


def main():
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
    while True:
        try:
            if c.evaluate(
                'document.querySelectorAll("[class*=\'vf-notehead\']").length'
            ):
                break
        except Exception:
            pass
        time.sleep(1)

    sweep = c.evaluate(SWEEP)
    print("A 符头扫描:", json.dumps(sweep, ensure_ascii=False))
    rest = c.evaluate(REST_CHECK)
    print("B 休止符验证:", json.dumps(rest, ensure_ascii=False))
    ok = sweep["badCount"] == 0 and rest.get("badCount") == 0
    if ok:
        print(f"PASS: {sweep['total']} 个符头 + {rest.get('restGroups', 0)} "
              "个休止符全部点谁选谁且自身高亮")
        return 0
    print("FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
