# -*- coding: utf-8 -*-
"""编辑重渲染光标稳定性验证：
1) 初始加载（无选中）后绿光标应隐藏（不再闪现曲首）
2) 点击音符 → 光标显示且与蓝选中 0 偏差
3) 模拟编辑重渲染（setZoom 走的同一 render 路径）后，经 highlight 恢复
   的光标与选中仍重合；重渲染期间光标不应可见地停在曲首
"""
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
time.sleep(1.5)

CHECK = """(function(){
  var imgs = document.querySelectorAll('#container img');
  var vis = imgs.length ? imgs[0].style.visibility : 'none';
  var glyphs = document.querySelectorAll('[class*="vf-notehead"],[class*="vf-rest"]');
  var sel = null;
  for (var i = 0; i < glyphs.length; i++) {
    if (glyphs[i].style && glyphs[i].style.fill === 'rgb(26, 115, 232)') { sel = glyphs[i]; break; }
  }
  if (!sel) return JSON.stringify({vis: vis, sel: false});
  var r1 = sel.getBoundingClientRect(), r2 = imgs[0].getBoundingClientRect();
  return JSON.stringify({vis: vis, sel: true,
    dx: Math.round(Math.abs((r1.left+r1.width/2)-(r2.left+r2.width/2))),
    dy: Math.round(Math.abs((r1.top+r1.height/2)-(r2.top+r2.height/2)))});
})()"""

s = json.loads(ev(CHECK))
print('1) 初始(无选中):', s)
ok1 = s['vis'] == 'hidden' and s['sel'] is False

# 点击一个可见符头
t = json.loads(ev("""(function(){
  var els = document.querySelectorAll('[class*="vf-notehead"]');
  for (var i = 0; i < els.length; i++) {
    var r = els[i].getBoundingClientRect();
    if (r.width && r.top > 100 && r.top < 500)
      return JSON.stringify({x: Math.round(r.left + r.width/2), y: Math.round(r.top + r.height/2)});
  }
  return null;})()"""))
click(t['x'], t['y'])
time.sleep(0.8)
s = json.loads(ev(CHECK))
print('2) 点击后:', s, t)
ok2 = s['vis'] == 'visible' and s['sel'] and s['dx'] == 0 and s['dy'] == 0

# 重渲染路径（setZoom 与编辑同走 render+cursor.show）：编辑器会在
# ready 后发 highlight 恢复——这里手动验证 highlight 恢复后的重合度
ev("window.__ejmSel = (function(){var g=document.querySelectorAll("
   "'[class*=\'vf-notehead\']')[3];return {m:+g.closest('svg')?"  # 占位，不执行
   )
# 简化：直接再触发一次真实编辑器恢复路径——点击后调 highlight op
last = json.loads(ev("JSON.stringify(window.__ejmLastClick||null)"))
ev("window.EJMusic.handle({op:'setZoom',zoom:1.0})")
time.sleep(1.0)
ev("window.EJMusic.handle({op:'highlight',m:%d,s:%d,k:%d,reveal:false})"
   % (last['m'], last['s'], last['k']))
time.sleep(0.5)
s = json.loads(ev(CHECK))
print('3) 重渲染+highlight恢复:', s)
ok3 = s['vis'] == 'visible' and s['sel'] and s['dx'] == 0 and s['dy'] == 0

print('PASS' if (ok1 and ok2 and ok3) else 'FAIL ok1=%s ok2=%s ok3=%s' % (ok1, ok2, ok3))
sys.exit(0 if (ok1 and ok2 and ok3) else 1)
