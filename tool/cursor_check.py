# -*- coding: utf-8 -*-
"""点击谱中段若干音符后，验证蓝选中与绿光标都落在所点音符上。"""
import json, sys, time, urllib.request
sys.stdout.reconfigure(encoding='utf-8')
import websocket

targets = json.loads(urllib.request.urlopen('http://127.0.0.1:9222/json').read())
url = [t for t in targets if t['type'] == 'page'][0]['webSocketDebuggerUrl']
ws = websocket.create_connection(url, suppress_origin=True, timeout=60)
mid = 0
def ev(expr):
    global mid
    mid += 1
    ws.send(json.dumps({'id': mid, 'method': 'Runtime.evaluate',
                        'params': {'expression': expr, 'returnByValue': True}}))
    while True:
        m = json.loads(ws.recv())
        if m.get('id') == mid:
            return m['result']['result'].get('value')
def click(x, y):
    global mid
    for t in ('mousePressed', 'mouseReleased'):
        mid += 1
        ws.send(json.dumps({'id': mid, 'method': 'Input.dispatchMouseEvent',
                            'params': {'type': t, 'x': x, 'y': y,
                                       'button': 'left', 'clickCount': 1}}))

for _ in range(120):
    if ev('!!window.__ejmOSMD'):
        break
    time.sleep(0.5)
time.sleep(1)

CHECK = """(function(){
  var glyphs = document.querySelectorAll('[class*="vf-notehead"],[class*="vf-rest"]');
  var sel = null;
  for (var i = 0; i < glyphs.length; i++) {
    if (glyphs[i].style && glyphs[i].style.fill === 'rgb(26, 115, 232)') { sel = glyphs[i]; break; }
  }
  if (!sel) return JSON.stringify({err: 'no-blue'});
  var imgs = document.querySelectorAll('#container img');
  if (!imgs.length) return JSON.stringify({err: 'no-cursor'});
  var r1 = sel.getBoundingClientRect(), r2 = imgs[0].getBoundingClientRect();
  return JSON.stringify({dx: Math.round(Math.abs((r1.left+r1.width/2)-(r2.left+r2.width/2))),
    dy: Math.round(Math.abs((r1.top+r1.height/2)-(r2.top+r2.height/2)))});
})()"""

# 取视口内均匀分布的 6 个符头（含需要滚动的小节），逐个点击验证
picks = json.loads(ev("""(function(){
  var out = [];
  function scan() {
    var els = document.querySelectorAll('[class*="vf-notehead"]');
    var cands = [];
    for (var i = 0; i < els.length; i++) {
      var r = els[i].getBoundingClientRect();
      if (r.width && r.top > 80 && r.top < 520) cands.push({x: r.left + r.width/2, y: r.top + r.height/2});
    }
    if (!cands.length) return null;
    return cands[Math.floor(cands.length/2)];
  }
  var h = document.documentElement.scrollHeight;
  for (var f = 0.05; f <= 0.85; f += 0.16) {
    window.scrollTo(0, (h - innerHeight) * f);
    var c = scan();
    if (c) out.push(c);
  }
  window.scrollTo(0, 0);
  return JSON.stringify(out);
})()"""))
print('取样 %d 个符头' % len(picks))
bad = 0
for i, c in enumerate(picks):
    x, y = round(c['x']), round(c['y'])
    click(x, y)
    time.sleep(0.7)
    r = json.loads(ev(CHECK))
    ok = 'err' not in r and r['dx'] < 25 and r['dy'] < 25
    if not ok:
        bad += 1
    print('  #%d (%d,%d) -> %s %s' % (i, x, y, r, 'OK' if ok else 'BAD'))
print('PASS' if bad == 0 else 'FAIL: %d bad' % bad)
sys.exit(0 if bad == 0 else 1)
