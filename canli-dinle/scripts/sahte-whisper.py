#!/usr/bin/env python3
"""Sahte whisper-cli: -f dosya, -of önek; sahte sunucuyla aynı kelime kuralı, segment olarak yazar."""
import json, math, os, struct, sys
a = sys.argv; wav = a[a.index("-f") + 1]; onek = a[a.index("-of") + 1]
P, O = float(os.environ["FAKE_P"]), float(os.environ["FAKE_O"])
d = open(wav, "rb").read(); i = d.find(b"data"); dur = struct.unpack("<I", d[i + 4:i + 8])[0] / 32000.0
sf = os.environ["FAKE_SAYAC"]
idx = int(open(sf).read()) if os.path.exists(sf) else 0
open(sf, "w").write(str(idx + 1))
ofs = 0.0 if idx == 0 else idx * P - O
seg = []; m = math.floor((ofs - 1.25) / 2.0)   # segment = (k(2m+1), k(2m+2)): sınırı aşan segmentte ses kesilince yalnız sığan kelime gelir
while True:
    bas = 2 * m + 1.25
    if bas - ofs >= dur: break
    kel = [k for k in (2 * m + 1, 2 * m + 2) if k >= 0 and k + 0.25 - ofs < dur and k + 0.25 >= ofs]
    if kel:
        f = int((kel[0] + 0.25 - ofs) * 1000)
        seg.append({"offsets": {"from": f, "to": f + 1200}, "text": " " + " ".join("k%d" % k for k in kel)})
    m += 1
json.dump({"transcription": seg}, open(onek + ".json", "w"))
