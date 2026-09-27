# -*- coding: utf-8 -*-
"""点击落在 setZoom 重渲染（同步阻塞）进行中时的行为：
raw 是否记录（点击是否到达页面处理器）、渲染后是否命中。"""
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

for delay in (30, 100, 250, 500):
    ev('window.__ejmLastRawClick = null; window.__ejmLastClick = null;')
    # 触发全量重渲染（不等待、不读回包）
    mid += 1
    ws.send(json.dumps({'id': mid, 'method': 'Runtime.evaluate', 'params': {
        'expression': "window.EJMusic.handle({op:'setZoom',zoom:1.0})",
        'returnByValue': True, 'awaitPromise': True}}))
    time.sleep(delay / 1000.0)
    click(191, 225)
    time.sleep(0.8)
    raw = ev('JSON.stringify(window.__ejmLastRawClick)')
    last = ev('JSON.stringify(window.__ejmLastClick)')
    print('delay=%4dms: raw=%s last=%s' % (delay, raw, last))
