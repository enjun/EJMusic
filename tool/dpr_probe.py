# DPR 双重缩放验证探针：把 OSMD 光标移到两个相距很远的步位，
# 分别取 DOM 文档坐标（含 scrollY）与 OS 截图中绿色光标位置，
# 拟合 DOM→屏幕物理像素的仿射映射。修复后斜率应 ≈ dpr(1.25)，
# 若 ≈ dpr²(1.5625) 则内容被双重缩放。
# 前置：App 以 9222 CDP 启动且停在编辑页；PowerShell + .NET 可用。
import base64
import io
import json
import struct
import subprocess
import sys
import time
import zlib

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, "tool")
from cdp_click_test import Conn, find_sheet  # noqa: E402

CURSOR = """
(function(){
  var el = document.getElementById('cursorImg-0');
  if (!el) return JSON.stringify({error: 'no cursor'});
  var r = el.getBoundingClientRect();
  return JSON.stringify({x: r.left + window.scrollX + r.width/2,
                         y: r.top + window.scrollY + r.height/2,
                         scrollY: window.scrollY, innerW: window.innerWidth});
})()
"""

SCROLL_STABLE = """
(function(){
  return JSON.stringify({sy: window.scrollY});
})()
"""


def wait_scroll_stable(c, tries=15):
    last = None
    for _ in range(tries):
        v = json.loads(c.evaluate(SCROLL_STABLE))["sy"]
        if last is not None and abs(v - last) < 1:
            return v
        last = v
        time.sleep(0.3)
    return last


def decode_png_gray(data):
    # 极简 PNG 解码（8-bit RGB/RGBA，逐行 filter 0-4）
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos, w, h, bitd, ctype = 8, 0, 0, 0, 0
    idat = b""
    while pos < len(data):
        ln = struct.unpack(">I", data[pos:pos + 4])[0]
        typ = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + ln]
        if typ == b"IHDR":
            w, h, bitd, ctype = struct.unpack(">IIBB", chunk[:10])
        elif typ == b"IDAT":
            idat += chunk
        pos += 12 + ln
    assert bitd == 8 and ctype in (2, 6), f"unsupported png {bitd}/{ctype}"
    bpp = 4 if ctype == 6 else 3
    raw = zlib.decompress(idat)
    stride = w * bpp
    out = bytearray()
    prev = bytearray(stride)
    p = 0
    for _ in range(h):
        f = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        if f == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif f == 3:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif f == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                c = prev[i - bpp] if i >= bpp else 0
                b = prev[i]
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        out += line
        prev = line
    return w, h, bpp, bytes(out)


def green_center(path):
    with open(path, "rb") as f:
        w, h, bpp, px = decode_png_gray(f.read())
    pts = []
    for y in range(h):
        row = y * w * bpp
        for x in range(w):
            i = row + x * bpp
            r, g, b = px[i], px[i + 1], px[i + 2]
            if g > 200 and r < 180 and b < 180 and g - max(r, b) > 40:
                pts.append((x, y))
    if not pts:
        return {"n": 0, "cx": None, "cy": None}
    # 按 100px 网格聚类，取与最大簇 x 相近的所有簇（光标竖条可能被谱线
    # 分成上下两段）；剔除屏幕上无关的常驻绿色 UI（如任务栏图标）
    clusters = {}
    for x, y in pts:
        clusters.setdefault((x // 100, y // 100), []).append((x, y))
    best_key = max(clusters, key=lambda k: len(clusters[k]))
    bx = sum(p[0] for p in clusters[best_key]) / len(clusters[best_key])
    sel = [p for k, v in clusters.items()
           for p in v if abs(sum(q[0] for q in v) / len(v) - bx) < 60]
    n = len(sel)
    return {"n": n, "cx": round(sum(p[0] for p in sel) / n, 1),
            "cy": round(sum(p[1] for p in sel) / n, 1)}


def shot(c, name):
    # 真实屏幕抓取（DPI-aware 物理像素）——验证的是"屏幕实际显示的映射"，
    # CDP captureScreenshot 拿到的是 DOM 渲染内容，测不出显示层缩放
    subprocess.run(["powershell", "-NoProfile", "-File", "tool/os_shot.ps1",
                    "-Out", f"build\\{name}.png"], check=True,
                   stdout=subprocess.DEVNULL)
    return green_center(f"build/{name}.png")


def main():
    c, _ = find_sheet()
    if c is None:
        print("FAIL: 找不到谱面页")
        return 1
    # 光标复位 → 截屏 A
    c.evaluate('window.EJMusic.handle({op:"cursorReset"})')
    time.sleep(1.0)
    wait_scroll_stable(c)
    os_a = shot(c, "probe2_a")
    dom_a = json.loads(c.evaluate(CURSOR))
    # 光标走 300 步 → 等滚动完全停稳 → 截屏 B → 再读 DOM（含当时 scrollY）
    c.evaluate('window.EJMusic.handle({op:"cursorTo",step:300})')
    time.sleep(1.5)
    wait_scroll_stable(c)
    os_b = shot(c, "probe2_b")
    dom_b = json.loads(c.evaluate(CURSOR))
    print("DOM A:", dom_a, "OS A:", os_a)
    print("DOM B:", dom_b, "OS B:", os_b)
    if not (os_a["n"] and os_b["n"]):
        print("FAIL: 截图中没找到绿色光标")
        return 1
    sx = (os_b["cx"] - os_a["cx"]) / (dom_b["x"] - dom_a["x"])
    # 屏幕显示的是视口位置：DOM 文档 y 要减去截屏那一刻的 scrollY
    vy_a = dom_a["y"] - dom_a["scrollY"]
    vy_b = dom_b["y"] - dom_b["scrollY"]
    sy = (os_b["cy"] - os_a["cy"]) / (vy_b - vy_a)
    ox = os_a["cx"] - sx * dom_a["x"]
    oy = os_a["cy"] - sy * vy_a
    print(f"物理像素斜率 x={sx:.3f} y={sy:.3f} 截距=({ox:.0f},{oy:.0f})")
    print("期望 1.250（正常 DPI）；1.5625=双重缩放；1.000=raw 1:1")
    ok = abs(sx - 1.0) < 0.1 and abs(sy - 1.0) < 0.1
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
