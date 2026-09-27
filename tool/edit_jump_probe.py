# -*- coding: utf-8 -*-
"""复现"第 2/3/4 个插入音符时高亮/谱面跳动"：
真实点击选音符（前置激活窗口）→ 真实键盘注入连插 4 个音符（A=C4），
全程 30ms 高频采样 scrollY / 光标 img 位置 / 可见性，
定位"跳动"到底是页面滚动、光标瞬移还是布局回流。
"""
import ctypes
import json
import subprocess
import sys
import threading
import time
import urllib.request

sys.stdout.reconfigure(encoding='utf-8')
import websocket

user32 = ctypes.windll.user32
user32.SetProcessDPIAware()


def cdp():
    targets = json.loads(urllib.request.urlopen('http://127.0.0.1:9222/json').read())
    url = [t for t in targets if t['type'] == 'page'][0]['webSocketDebuggerUrl']
    ws = websocket.create_connection(url, suppress_origin=True, timeout=30)
    mid = 0

    def send(obj):
        nonlocal mid
        mid += 1
        obj['id'] = mid
        ws.send(json.dumps(obj))

    def ev(expr):
        send({'method': 'Runtime.evaluate', 'params': {
            'expression': expr, 'returnByValue': True}})
        while True:
            m = json.loads(ws.recv())
            if m.get('id') == mid:
                return m['result']['result'].get('value')

    def click(x, y):
        for t2 in ('mousePressed', 'mouseReleased'):
            send({'method': 'Input.dispatchMouseEvent', 'params': {
                'type': t2, 'x': x, 'y': y, 'button': 'left',
                'clickCount': 1}})
    return ev, click


ev, cdpclick = cdp()
for _ in range(120):
    if ev('!!window.__ejmOSMD'):
        break
    time.sleep(0.5)
time.sleep(1.5)

# 选一个可见符头并换算屏幕坐标（窗口客户区原点 + css==物理像素）
t = json.loads(ev("""(function(){
  var els = document.querySelectorAll('[class*="vf-notehead"]');
  for (var i = 0; i < els.length; i++) {
    var r = els[i].getBoundingClientRect();
    if (r.width && r.top > 120 && r.top < 450 && r.left > 300)
      return JSON.stringify({x: Math.round(r.left + r.width/2), y: Math.round(r.top + r.height/2)});
  }
  return null;})()"""))
print('目标符头 css 坐标:', t)

ps = subprocess.run(
    ['powershell', '-NoProfile', '-File', 'tool/client_origin.ps1'],
    capture_output=True, text=True)
origin = json.loads(ps.stdout.strip())
sx = origin['x'] + t['x']
sy = origin['y'] + t['y']
print('屏幕坐标:', sx, sy, 'origin:', origin)

# 真实点击谱面下方空白处（激活窗口、保留键盘焦点，不选中任何音符）
r = subprocess.run(['powershell', '-NoProfile', '-File', 'tool/os_click2.ps1',
                    '-X', str(origin['x'] + 1400), '-Y', str(origin['y'] + 820)],
                   capture_output=True, text=True)
print('空白激活点击:', r.stdout.strip() or r.stderr.strip())
time.sleep(0.8)
# CDP 合成点击选中符头（合成点击走真实命中测试，选中链路一致）
cdpclick(t['x'], t['y'])
time.sleep(0.8)
print('选中:', ev("JSON.stringify(window.__ejmLastClick||null)"))

# 采样表达式：页面状态快照
SAMPLE = """(function(){
  var img = document.querySelector('#container img');
  var g = document.querySelectorAll('[class*="vf-notehead"],[class*="vf-rest"]');
  var bx = -1, by = -1;
  for (var i = 0; i < g.length; i++) {
    if (g[i].style && g[i].style.fill === 'rgb(26, 115, 232)') {
      var r2 = g[i].getBoundingClientRect();
      bx = Math.round(r2.left + r2.width / 2);
      by = Math.round(r2.top + r2.height / 2 + window.scrollY);
      break;
    }
  }
  return JSON.stringify({t: Date.now(), sy: window.scrollY,
    vis: img ? img.style.visibility : 'x',
    cx: img ? img.offsetLeft : -1, cy: img ? img.offsetTop : -1,
    bx: bx, by: by});
})()"""

samples = []
stop = threading.Event()


def poll():
    while not stop.is_set():
        try:
            s = json.loads(ev(SAMPLE))
            s['wt'] = time.time()
            samples.append(s)
        except Exception:
            pass
        time.sleep(0.03)


th = threading.Thread(target=poll)
th.start()

# 连续插入 4 个音符（A = C4），间隔 2.5s 让每次防抖渲染完整走完
VK_A = 0x45  # 先用 E？不：A=0x41。E 是 0x45。琴键 A=C4
VK = {'A': 0x41, 'S': 0x53, 'D': 0x44, 'F': 0x46}
marks = []
for i, k in enumerate(['A', 'A', 'A', 'A']):
    time.sleep(2.5)
    marks.append(time.time())
    user32.keybd_event(VK[k], 0, 0, None)
    time.sleep(0.05)
    user32.keybd_event(VK[k], 0, 2, None)
print('已注入 4 次 A 键')

time.sleep(3.0)
stop.set()
th.join()

print('采样数:', len(samples))
# 找 scrollY 激励与光标位置激励
prev = None
for s in samples:
    if prev is not None:
        dsy = s['sy'] - prev['sy']
        dcx = s['cx'] - prev['cx']
        dcy = s['cy'] - prev['cy']
        if abs(dsy) > 5 or abs(dcx) > 30 or abs(dcy) > 30 or s['vis'] != prev['vis']:
            print('t=%+.2fs sy=%5d(%+4d) vis=%s->%s cursor=(%s,%s)(%+5d,%+5d)'
                  ' blue=(%s,%s)'
                  % (s['wt'] - marks[0], s['sy'], dsy,
                     prev['vis'], s['vis'], s['cx'], s['cy'], dcx, dcy,
                     s['bx'], s['by']))
    prev = s
print('注入时刻标记:', ['%+.2f' % (m - marks[0]) for m in marks])
