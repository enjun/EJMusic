# -*- coding: utf-8 -*-
"""reload → 全量渲染窗口内的点击送达测试（目标限定在视口内）。

reload 布局与当前一致（scroll=0），预取 4 个可见符头坐标
（gi=0/2/6/8 互相可区分）。reload 后按墙钟偏移盲点击，每次点击后
eval 回读 __ejmLastClick.gi 判断该点击是否送达并命中。
"""
import json
import sys
import time
import urllib.request

sys.stdout.reconfigure(encoding='utf-8')
import websocket  # noqa: E402


def get_ws_url():
    with urllib.request.urlopen('http://127.0.0.1:9222/json') as r:
        targets = json.loads(r.read())
    return [t for t in targets if t['type'] == 'page'][0]['webSocketDebuggerUrl']


class CDP:
    def __init__(self, url):
        self.ws = websocket.create_connection(url, suppress_origin=True, timeout=60)
        self.mid = 0

    def cmd(self, method, params=None, timeout=None):
        self.mid += 1
        mid = self.mid
        if timeout:
            self.ws.settimeout(timeout)
        self.ws.send(json.dumps({'id': mid, 'method': method, 'params': params or {}}))
        while True:
            msg = json.loads(self.ws.recv())
            if msg.get('id') == mid:
                if timeout:
                    self.ws.settimeout(60)
                return msg.get('result', {})

    def ev(self, expr, timeout=None):
        r = self.cmd('Runtime.evaluate',
                     {'expression': expr, 'returnByValue': True}, timeout)
        if 'exceptionDetails' in r:
            raise RuntimeError(r['exceptionDetails'])
        return r.get('result', {}).get('value')

    def click(self, x, y):
        self.cmd('Input.dispatchMouseEvent',
                 {'type': 'mousePressed', 'x': x, 'y': y, 'button': 'left',
                  'clickCount': 1})
        self.cmd('Input.dispatchMouseEvent',
                 {'type': 'mouseReleased', 'x': x, 'y': y, 'button': 'left',
                  'clickCount': 1})


TARGETS = [(0, 191, 225), (2, 268, 225), (6, 322, 220), (8, 381, 230)]
OFFSETS = [150, 400, 800, 1600, 3000]


def main():
    cdp = CDP(get_ws_url())
    for _ in range(120):
        if cdp.ev('!!window.__ejmOSMD'):
            break
        time.sleep(0.5)
    cdp.cmd('Page.enable')

    for attempt in range(2):
        print('---- attempt %d ----' % attempt)
        cdp.cmd('Page.reload')
        t0 = time.time()
        # 用 5 个目标轮转 5 个偏移
        plan = list(zip(TARGETS * 2, OFFSETS))
        for (gi, x, y), off in plan:
            wait = t0 + off / 1000.0 - time.time()
            if wait > 0:
                time.sleep(wait)
            cdp.click(x, y)
            # eval 排队到 JS 空闲，返回该点击若送达后的命中状态
            try:
                s = cdp.ev("JSON.stringify(window.__ejmLastClick||null)", timeout=30)
            except Exception as e:
                s = 'eval失败: %s' % e
            v = json.loads(s) if isinstance(s, str) else s
            got = v.get('gi') if isinstance(v, dict) else None
            print('  t=+%5dms 点击 gi=%d → 命中 gi=%s %s'
                  % (off, gi, got, 'OK' if got == gi else 'MISS/SWALLOWED'))
        # JS 恢复响应时刻
        print('  done')
        time.sleep(2.0)
    return 0


if __name__ == '__main__':
    sys.exit(main())
