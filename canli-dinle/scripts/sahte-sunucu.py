#!/usr/bin/env python3
"""Sınav için sahte Groq: ses parçasının süresinden ve sırasından mutlak zamanlı kelimeler üretir (kelime n, saniye n+0,25)."""
import json, math, os, re, struct, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
P, O = float(os.environ["FAKE_P"]), float(os.environ["FAKE_O"])
SAYAC = {"n": 0}

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        b = self.rfile.read(int(self.headers["Content-Length"]))
        if self.path.endswith("/audio/transcriptions"):
            i = b.find(b"RIFF"); veri = b.find(b"data", i)
            n = struct.unpack("<I", b[veri + 4:veri + 8])[0] if veri > 0 else 0
            dur = n / 32000.0
            idx = SAYAC["n"]; SAYAC["n"] += 1
            ofs = 0.0 if idx == 0 else idx * P - O
            w = []; k = math.ceil(ofs - 0.25)
            while k + 0.25 - ofs < dur:
                if k + 0.25 >= ofs: w.append({"word": "k%d" % k, "start": k + 0.25 - ofs, "end": k + 0.5 - ofs})
                k += 1
            cevap = {"text": " ".join(x["word"] for x in w), "words": w}
        else:
            m = len(re.findall(rb"k\d+", b))
            cevap = {"choices": [{"message": {"content": "ÖZET(%d)" % m}}]}
        d = json.dumps(cevap).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(d))); self.end_headers(); self.wfile.write(d)

s = ThreadingHTTPServer(("127.0.0.1", 0), H)
open(sys.argv[1], "w").write(str(s.server_address[1]))
s.serve_forever()
