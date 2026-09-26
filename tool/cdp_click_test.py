# CDP 真实鼠标点击复现：编辑器谱面选中。
# 前置：App 以 WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS=--remote-debugging-port=9222 启动，
#       EJMUSIC_DEBUG_LOCATION 直达编辑页。
# 用法：uv run --with websocket-client python tool/cdp_click_test.py
import base64
import json
import sys
import time
import urllib.request

import websocket

sys.stdout.reconfigure(encoding="utf-8")

CDP = "http://127.0.0.1:9222"


def targets():
    with urllib.request.urlopen(f"{CDP}/json") as r:
        return json.load(r)


class Conn:
    def __init__(self, url):
        self.ws = websocket.create_connection(url, timeout=15, suppress_origin=True)
        self.mid = 0

    def send(self, method, params=None):
        self.mid += 1
        self.ws.send(json.dumps({"id": self.mid, "method": method, "params": params or {}}))
        return self.mid

    def recv_until(self, mid):
        deadline = time.time() + 20
        while time.time() < deadline:
            try:
                msg = json.loads(self.ws.recv())
            except websocket.WebSocketTimeoutException:
                break
            if msg.get("id") == mid:
                return msg
        raise TimeoutError(f"no response for id={mid}")

    def call(self, method, params=None):
        mid = self.send(method, params)
        return self.recv_until(mid)

    def evaluate(self, expr):
        r = self.call("Runtime.evaluate", {"expression": expr, "returnByValue": True})
        res = r.get("result", {}).get("result", {})
        if res.get("subtype") == "error":
            raise RuntimeError(res.get("description", "eval error"))
        return res.get("value")

    def click(self, x, y):
        for t in ("mousePressed", "mouseReleased"):
            self.call(
                "Input.dispatchMouseEvent",
                {"type": t, "x": x, "y": y, "button": "left", "clickCount": 1},
            )

    def screenshot(self, path):
        r = self.call("Page.captureScreenshot", {"format": "png"})
        with open(path, "wb") as f:
            f.write(base64.b64decode(r["result"]["data"]))


def find_sheet():
    for t in targets():
        if t.get("type") != "page":
            continue
        try:
            c = Conn(t["webSocketDebuggerUrl"])
            if c.evaluate("!!(window.EJMusic && window.opensheetmusicdisplay)"):
                return c, t
            c.ws.close()
        except Exception:
            continue
    return None, None


def wait_for(expr, timeout=90, poll=1.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        c, t = find_sheet()
        if c is not None:
            try:
                v = c.evaluate(expr)
                if v:
                    return c, t
            except Exception:
                pass
            c.ws.close()
        time.sleep(poll)
    raise TimeoutError(f"wait_for timeout: {expr}")


def main():
    print("等待编辑器 WebView 就绪…")
    c, t = wait_for("!!window.EJMusic")
    print("找到目标:", t.get("url", "")[:80], t.get("title", ""))
    try:
        c.call("Page.enable")
    except Exception:
        pass

    # 等谱面渲染出符头
    n = c.evaluate("document.querySelectorAll('[class*=\"vf-notehead\"]').length")
    deadline = time.time() + 60
    while not n and time.time() < deadline:
        time.sleep(1)
        n = c.evaluate("document.querySelectorAll('[class*=\"vf-notehead\"]').length")
    print("符头数量:", n)
    if not n:
        print("FAIL: 谱面没有符头")
        return 1

    state = c.evaluate(
        "JSON.stringify({scrollY: window.scrollY, iw: window.innerWidth,"
        " ih: window.innerHeight, dpr: window.devicePixelRatio,"
        " docH: document.body.scrollHeight})"
    )
    print("页面状态:", state)

    info = c.evaluate(
        """(function(){
          var els = document.querySelectorAll('[class*="vf-notehead"]');
          for (var i = 0; i < els.length; i++) {
            var r = els[i].getBoundingClientRect();
            if (r.top > 10 && r.bottom < window.innerHeight - 10
                && r.left > 10 && r.right < window.innerWidth - 10) {
              return {i: i, x: r.left + r.width/2, y: r.top + r.height/2};
            }
          }
          return null;
        })()"""
    )
    print("视口内目标符头:", info)
    if not info:
        print("FAIL: 视口内没有符头")
        return 1

    c.evaluate("window.__ejmLastClick = undefined")
    c.click(info["x"], info["y"])
    time.sleep(1.5)
    breadcrumb = c.evaluate("JSON.stringify(window.__ejmLastClick || null)")
    print("点击面包屑:", breadcrumb)

    # 未命中时按 devicePixelRatio 缩放坐标重试
    if not breadcrumb or breadcrumb == "null":
        dpr = c.evaluate("window.devicePixelRatio || 1")
        print("未命中，devicePixelRatio =", dpr, "，尝试缩放坐标重试")
        c.click(info["x"] * dpr, info["y"] * dpr)
        time.sleep(1.5)
        breadcrumb = c.evaluate("JSON.stringify(window.__ejmLastClick || null)")
        print("重试面包屑:", breadcrumb)

    c.screenshot("build/cdp_after_click.png")
    print("截图: build/cdp_after_click.png")
    return 0 if breadcrumb and breadcrumb != "null" else 2


if __name__ == "__main__":
    sys.exit(main())
