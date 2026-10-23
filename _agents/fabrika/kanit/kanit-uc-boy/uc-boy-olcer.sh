#!/usr/bin/env bash
# uc-boy-olcer.sh <kod kaynağı: git ref | "agac"> — 4PZV4: kanıt aracı TEK komutla üç boy kare alıyor mu?
#   Verilen kaynaktaki yazilim-fabrikasi/scripts geçici dizine alınır; GERÇEK tarayıcıyla (kutudaki playwright) yerel bir sayfa
#   `kanit.sh ekran … --uc-boy --gelen olc` ile karelenir; gelen klasörü GEÇİCİ dizine kilitlidir (Sultan'ın klasörüne yazılmaz).
#   Ölçülen: çıkış kodu · manifestte kaç yeşil kayıt ve hangi genişlikler · PNG'lerin gerçek piksel genişliği · gelen kopyaları.
#   Çıkış 0 = üç yeşil kayıt (1440/1280/390), PNG genişlikleri tutuyor, üç kopya · 1 = değil.
set -uo pipefail
R="$(git rev-parse --show-toplevel)"; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
mkdir -p "$T/s" "$T/d" "$T/gelen"; git -C "$T/d" init -q
if [ "$1" = agac ]; then cp -a "$R/yazilim-fabrikasi/scripts/." "$T/s/"
else git -C "$R" archive "$1" yazilim-fabrikasi/scripts | tar -x -C "$T/s" --strip-components=2; fi
printf '<html><title>Urun</title><body style="margin:0"><main id="urun" style="height:600px;background:#123">x</main></body></html>' > "$T/sayfa.html"
O="$(cd "$T/d" && KANIT_DEPO="$T/d" KANIT_GELEN_DIZ="$T/gelen" bash "$T/s/kanit.sh" ekran olc ana --url "file://$T/sayfa.html" --asama tek --urun-imi '#urun' --bekle '#urun' --uc-boy --gelen olc < /dev/null 2>&1)"; rc=$?
echo "kod kaynağı: $1 · kanit.sh ekran --uc-boy rc=$rc"; printf '%s\n' "$O" | grep -E "kare alındı|özeti|unrecognized|error|SARI" | sed 's/^/   /'
M="$T/d/_agents/fabrika/kanit/olc/KANIT.json"
K="$(python3 - "$M" "$T/d/_agents/fabrika/kanit/olc" <<'PY' 2>/dev/null
import json, struct, sys, os
m = json.load(open(sys.argv[1])); out = []
for k in m["kayitlar"]:
    w = "-"
    p = os.path.join(sys.argv[2], k["dosya"])
    if os.path.exists(p):
        b = open(p, "rb").read(24); w = struct.unpack(">I", b[16:20])[0] if b[:8] == b"\x89PNG\r\n\x1a\n" else "png-değil"
    out.append(f'{k["etiket"]}:{k["renk"]}:{w}')
print(" ".join(out))
PY
)"
echo "manifest (etiket:renk:PNG-genişlik): ${K:-(kayıt yok)}"; echo "gelen kopyaları: $(ls "$T/gelen" | tr '\n' ' ')"
[ "$rc" = 0 ] && [ "$K" = "ana-1440:yesil:1440 ana-1280:yesil:1280 ana-390:yesil:390" ] && [ "$(ls "$T/gelen" | wc -l)" = 3 ]
