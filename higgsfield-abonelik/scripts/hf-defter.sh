#!/usr/bin/env bash
# hf-defter.sh — Higgsfield harcama defterini TAM ve NORMALIZE okur (tek kaynak).
#
# ── 🔴 NIÇIN VAR (2026-09-08, BESIR olctu, MUAVIN acil olarak tasidi) ────────
# `higgsfield account transactions` VARSAYILAN olarak 20 SATIR doner. Hem benim
# kredi-oku.sh hem kredi-mutabakat.sh bu kesik listeyi "defterin tamami" sanip
# hukum verdi: "20 harcamanin 20'si sahipsiz" dedim; dogrusu "GORDUGUM 20
# satirin 20'si". Iki ayri oda bayt bayt AYNI rakami basti (128,80) — iki
# bagimsiz olcum ayni sayiyi veriyorsa o bir OLAY degil, bir TAVANDIR.
#
# 🔴 VE TAVAN 100'DE DE VAR: `--size 100` tam 100 satir doner, `--size 150`
# reddedilir ("size must be <= 100"). Yani sayfa buyutmek tavani kaldirmaz,
# YUKARI TASIR. Tek dogru cozum SAYFALAMA: --cursor ile tukenene kadar oku.
#
# BESIR'in dersi (kayda gecti): "Bir olcum aracinin TAVANINI bilmiyorsan,
# olctugun sey olay degil tavandir. Cikti 'tam 20' dediginde bu supphe
# vermeliydi; YUVARLAK SAYI BIR ISARETTIR."
#
# ── NICIN JSON, NICIN TABLO DEGIL ───────────────────────────────────────────
# Tablo ciktisi degisken genislikte model adi tasiyor ("Seedance 2.5") ve bu
# beni bir kez yuttu; ayrica damgasi dakika hassasiyetinde ve tz'siz.
# `--json` ise: created_at ISO-8601 + 'Z' (tz ACIK), credits sayi, action alan.
# Ayristirma kirilganligi ortadan kalkar.
#
# Cikti (TSV): <ISO-UTC>\t<kredi(+/-)>\t<eylem>\t<model>
# Kullanim: hf-defter.sh [--saat N]
# Exit: 0=okundu · 1=okunamadi (fail-closed) · 2=kullanim
set -uo pipefail
SAAT=24
while [ $# -gt 0 ]; do
  case "$1" in
    --saat) shift; SAAT="${1:-24}" ;;
    *) echo "kullanim: hf-defter.sh [--saat N]" >&2; exit 2 ;;
  esac; shift
done
case "$SAAT" in ''|*[!0-9]*) echo "[kirmizi] --saat tamsayi olmali" >&2; exit 2 ;; esac

# Sinama enjeksiyonu: hazir TSV dosyasi verilirse aga cikilmaz.
# 🔴 AMA PENCERE YINE UYGULANIR (2026-09-08, kapi yakaladi): ilk yazisimda
# enjekte edilen dosyayi oldugu gibi `cat` ediyordum. Boylece SINAV YOLU GERCEK
# YOLDAN FARKLI davraniyordu — gercek yol pencereyi sayfalarken uygular, sinav
# yolu hic uygulamazdi. Sadik olmayan bir sinav dikisi, pencere hatasini
# GECIRIR: "10 saat onceki satir dusmez" iddiasi enjeksiyonda hep KIRILIRDI
# ve sebebi urun degil DIKIS olurdu.
# Kural: bir test dikisi KAYNAGI degistirir, DAVRANISI degistirmez.
if [ -n "${TELLAL_HF_TSV:-}" ]; then
  [ -f "$TELLAL_HF_TSV" ] || { echo "[kirmizi] TSV dosyasi yok: $TELLAL_HF_TSV" >&2; exit 1; }
  TELLAL_SAAT="$SAAT" python3 - "$TELLAL_HF_TSV" <<'PYF'
import sys, os
from datetime import datetime, timedelta, timezone
sinir = datetime.now(timezone.utc) - timedelta(hours=int(os.environ["TELLAL_SAAT"]))
for l in open(sys.argv[1], encoding="utf-8"):
    p = l.rstrip("\n").split("\t")
    if len(p) < 4: continue
    try: t = datetime.fromisoformat(p[0])
    except ValueError: continue
    if t >= sinir: sys.stdout.write(l)
PYF
  exit 0
fi
command -v higgsfield >/dev/null 2>&1 || { echo "[kirmizi] higgsfield CLI YOK — defter okunamadi" >&2; exit 1; }

CURSOR=""; SAYFA=0; TOPLAM=0
GEC="$(mktemp)"; trap 'rm -f "$GEC"' EXIT
while :; do
  SAYFA=$((SAYFA+1))
  if [ -z "$CURSOR" ]; then
    higgsfield account transactions --size 100 --json >"$GEC" 2>/dev/null
  else
    higgsfield account transactions --size 100 --cursor "$CURSOR" --json >"$GEC" 2>/dev/null
  fi
  [ -s "$GEC" ] || { echo "[kirmizi] sayfa $SAYFA okunamadi — defter EKSIK, hukum YOK" >&2; exit 1; }
  CIKTI="$(TELLAL_SAAT="$SAAT" python3 - "$GEC" <<'PYK'
import json, sys, os
from datetime import datetime, timedelta, timezone
saat = int(os.environ["TELLAL_SAAT"])
sinir = datetime.now(timezone.utc) - timedelta(hours=saat)
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception as e:
    print("HATA " + str(e)[:60]); sys.exit(0)
items = d.get("items") or []
eski = False
satir = []
for it in items:
    ts = (it.get("created_at") or "").replace("Z", "+00:00")
    try: t = datetime.fromisoformat(ts)
    except ValueError: continue
    if t < sinir:
        eski = True          # pencerenin gerisine gectik -> sayfalamayi bitir
        continue
    satir.append("\t".join([t.astimezone(timezone.utc).isoformat(),
                            str(it.get("credits", 0)),
                            str(it.get("action", "")),
                            str(it.get("display_name", ""))]))
print("VERI")
print("\n".join(satir))
print("SON " + ("1" if (eski or not d.get("cursor")) else "0") + " " + str(d.get("cursor") or ""))
PYK
)"
  case "$CIKTI" in HATA*) echo "[kirmizi] JSON cozulemedi: ${CIKTI#HATA }" >&2; exit 1 ;; esac
  printf '%s\n' "$CIKTI" | sed -n '/^VERI$/,/^SON /p' | sed '1d;$d' | grep -v '^$' || true
  N="$(printf '%s\n' "$CIKTI" | sed -n '/^VERI$/,/^SON /p' | sed '1d;$d' | grep -c . || true)"
  TOPLAM=$((TOPLAM+N))
  SONSAT="$(printf '%s\n' "$CIKTI" | grep '^SON ')"
  BITTI="$(printf '%s' "$SONSAT" | awk '{print $2}')"
  CURSOR="$(printf '%s' "$SONSAT" | awk '{print $3}')"
  [ "$BITTI" = "1" ] && break
  [ -n "$CURSOR" ] || break
  # 🔴 SONSUZ DONGU KALKANI: uc bozulursa arac asilmasin.
  [ "$SAYFA" -ge 50 ] && { echo "[kirmizi] 50 sayfa asildi — defter TAM okunamadi, hukum YOK" >&2; exit 1; }
done
echo "[bilgi] defter tam okundu: $SAYFA sayfa · $TOPLAM satır (pencere ${SAAT}s)" >&2
