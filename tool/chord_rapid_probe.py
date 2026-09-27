# -*- coding: utf-8 -*-
"""复现"Shift+音符插入几个后卡死十几秒"：
选中符头后快速连发 Shift+琴键（加音成和弦，间隔 400ms < 300ms 防抖，
考验渲染互斥/排队），全程 30ms 采样 scrollY / 光标 / 蓝选中位置，
并统计每次 CDP 求值耗时——页面 JS 被长阻塞时求值延迟会飙到秒级。
前置：App 带 --remote-debugging-port=9222 且已打开编辑页，资产已注入 __ejmOSMD。
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

# 真实点击空白处激活窗口（拿键盘焦点），CDP 合成点击选中符头
subprocess.run(['powershell', '-NoProfile', '-File', 'tool/os_click2.ps1',
                '-X', str(origin['x'] + 1400), '-Y', str(origin['y'] + 820)],
               capture_output=True, text=True)
time.sleep(0.8)
cdpclick(t['x'], t['y'])
time.sleep(0.8)
print('选中:', ev("JSON.stringify(window.__ejmLastClick||null)"))

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
latencies = []
stop = threading.Event()


def poll():
    while not stop.is_set():
        t0 = time.time()
        try:
            s = json.loads(ev(SAMPLE))
            s['wt'] = time.time()
            s['ms'] = round((time.time() - t0) * 1000)
            samples.append(s)
            latencies.append(s['ms'])
        except Exception:
            pass
        time.sleep(0.03)


th = threading.Thread(target=poll)
th.start()

# 快速连发 6 次 Shift+琴键（加音成和弦）：K=C5, E=D#4, 重复（去重）、K、E、K
VK = {'K': 0x4B, 'E': 0x45, 'F': 0x46, 'D': 0x44, 'J': 0x4A, 'H': 0x48}
VK_SHIFT = 0x10
marks = []
for k in ['K', 'E', 'F', 'D', 'J', 'H']:
    time.sleep(0.4)
    marks.append((time.time(), 'Shift+' + k))
    user32.keybd_event(VK_SHIFT, 0, 0, None)
    time.sleep(0.03)
    user32.keybd_event(VK[k], 0, 0, None)
    time.sleep(0.05)
    user32.keybd_event(VK[k], 0, 2, None)
    time.sleep(0.03)
    user32.keybd_event(VK_SHIFT, 0, 2, None)
print('已注入 6 次快速 Shift+琴键')

time.sleep(6.0)
stop.set()
th.join()

print('采样数:', len(samples))
if latencies:
    latencies.sort()
    print('CDP 求值延迟 ms: p50=%d p95=%d max=%d' % (
        latencies[len(latencies) // 2],
        latencies[int(len(latencies) * 0.95)],
        latencies[-1]))
maxsy = max(s['sy'] for s in samples)
print('scrollY 最大值:', maxsy, '(期望恒 0)')
# 每次按键后的蓝选中是否移动且收敛（不再跳到别处再跳回）
for mt, label in marks:
    after = [s for s in samples if s['wt'] >= mt and s['wt'] <= mt + 3.0]
    if after:
        bx = [s['bx'] for s in after if s['bx'] > 0]
        print('%s 后蓝选中 x 序列: %s' % (label, bx[:8]))
print('最终选中:', ev("JSON.stringify(window.__ejmLastClick||null)"))
print('高亮状态:', ev("JSON.stringify(window.__ejmLastHighlight||null)"))
