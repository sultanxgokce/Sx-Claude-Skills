#!/usr/bin/env python3
"""notion.test.sh için ÇEVRİMDIŞI sahte-Notion sunucusu.
Gerçek Notion'a BAĞLANMAZ (CI'da Notion yok → canlı çağrı sahte-yeşil üretirdi).
Doğrular: Authorization başlığı · Notion-Version başlığı (yoksa gerçek Notion gibi 400) ·
sayfalama (has_more/next_cursor/start_cursor) · files-tipi alan."""
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

ROWS = [{"id": f"row-{i}", "object": "page",
         "properties": {"Name": {"type": "title", "title": [{"plain_text": f"PLAKA{i}"}]},
                        "Ruhsat": {"type": "files", "files": [
                            {"type": "file", "name": f"{i}.png",
                             "file": {"url": "http://127.0.0.1:1/imzali-ve-sureli"}}]},
                        "Marka": {"type": "select", "select": {"name": "FORD"}}}}
        for i in range(3)]

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def _send(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)

    def _guard(self):
        if not (self.headers.get("Authorization") or "").startswith("Bearer "):
            self._send(401, {"object": "error", "status": 401, "code": "unauthorized",
                             "message": "API token is invalid."}); return False
        if self.headers.get("Notion-Version") != "2022-06-28":
            self._send(400, {"object": "error", "status": 400, "code": "validation_error",
                             "message": "Notion-Version header failed validation"}); return False
        return True

    def do_GET(self):
        if not self._guard(): return
        if self.path == "/v1/users/me":
            return self._send(200, {"object": "user", "type": "bot", "name": "TEST-BOT"})
        if self.path.startswith("/v1/pages/"):
            return self._send(200, {"object": "page", "id": self.path.split("/")[-1],
                                    "url": "http://ornek/sayfa", "last_edited_time": "2026-01-01T00:00:00.000Z",
                                    "properties": ROWS[0]["properties"]})
        self._send(404, {"object": "error", "status": 404, "code": "object_not_found", "message": "yok"})

    def do_POST(self):
        if not self._guard(): return
        n = int(self.headers.get("Content-Length") or 0)
        body = json.loads(self.rfile.read(n) or b"{}")
        cur = body.get("start_cursor")
        if self.path == "/v1/search":
            if cur is None:
                return self._send(200, {"object": "list", "results": [
                    {"object": "database", "id": "db-1", "title": [{"plain_text": "Araçlarımız"}]}],
                    "has_more": True, "next_cursor": "c1"})
            if cur == "c1":  # dedupe sınavı: db-1 TEKRAR döner
                return self._send(200, {"object": "list", "results": [
                    {"object": "database", "id": "db-1", "title": [{"plain_text": "Araçlarımız"}]},
                    {"object": "database", "id": "db-2", "title": [{"plain_text": "İkinci"}]}],
                    "has_more": True, "next_cursor": "c1"})  # imleç TEKRARI → döngü kalkanı sınavı
            return self._send(200, {"object": "list", "results": [], "has_more": False, "next_cursor": None})
        if self.path.endswith("/query"):
            if "yok" in self.path:
                return self._send(404, {"object": "error", "status": 404, "code": "object_not_found",
                                        "message": "Could not find database"})
            if cur is None:
                return self._send(200, {"object": "list", "results": ROWS[:2], "has_more": True, "next_cursor": "q1"})
            return self._send(200, {"object": "list", "results": ROWS[2:], "has_more": False, "next_cursor": None})
        self._send(404, {"object": "error", "status": 404, "code": "object_not_found", "message": "yok"})

if __name__ == "__main__":
    s = HTTPServer(("127.0.0.1", 0), H)
    print(s.server_port, flush=True)
    s.serve_forever()
