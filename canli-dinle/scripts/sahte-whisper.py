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
seg = []; k = math.ceil(ofs - 0.25)
while k + 0.25 - ofs < dur:
    if k + 0.25 >= ofs:
        t = int((k + 0.25 - ofs) * 1000); seg.append({"offsets": {"from": t, "to": t + 200}, "text": " k%d" % k})
    k += 1
json.dump({"transcription": seg}, open(onek + ".json", "w"))
