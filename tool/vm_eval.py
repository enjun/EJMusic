# Dart VM 服务求值工具：连接 flutter run 的 VM service，在根 isolate 上执行表达式。
# 用法：uv run --with websocket-client python tool/vm_eval.py "<expression>"
import json
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")


class VM:
    def __init__(self):
        log = open("build/win_run.log", encoding="utf-8", errors="replace").read()
        m = re.search(r"Dart VM Service on Windows is available at: (\S+)", log)
        if not m:
            raise RuntimeError("win_run.log 里没找到 VM service 地址")
        ws_url = m.group(1).rstrip("/").replace("http://", "ws://") + "/ws"
        from websocket import create_connection

        self.ws = create_connection(ws_url, timeout=25)
        self.mid = 0

    def _call(self, method, params=None):
        self.mid += 1
        self.ws.send(json.dumps({"id": self.mid, "method": method, "params": params or {}}))
        while True:
            r = json.loads(self.ws.recv())
            if r.get("id") == self.mid:
                if "error" in r:
                    raise RuntimeError(json.dumps(r["error"], ensure_ascii=False))
                return r["result"]

    def isolates(self):
        vm = self._call("getVM")
        return [i["id"] for i in vm.get("isolates", [])]

    def eval(self, isolate_id, expression):
        r = self._call(
            "evaluate",
            {"isolateId": isolate_id, "expression": expression, "disableBreakpoints": True},
        )
        return r.get("value", json.dumps(r, ensure_ascii=False)[:300])


def main():
    vm = VM()
    expr = (
        " ".join(sys.argv[1:])
        or "appRouter.routerDelegate.currentConfiguration.toString()"
    )
    for iso in vm.isolates():
        name = vm._call("getIsolate", {"isolateId": iso}).get("name", "")
        try:
            print(f"[{iso}] {name} →", vm.eval(iso, expr))
            return
        except RuntimeError as e:
            print(f"[{iso}] {name} 失败:", str(e)[:200])


if __name__ == "__main__":
    main()
