#!/usr/bin/env bash
# kredi-mutabakat.sh — Higgsfield defteri ile BIZIM defterimizi karsilastir:
# hangi harcama BIZE ait, hangisi SAHIPSIZ?
#
# ── 🔴 NIÇIN VAR (2026-09-08, MUAVIN'in olctugu bosluk) ──────────────────────
# Iki kutu (TELLAL + AKAR) TEK cuzdandan harciyor ve Higgsfield defterinde
# "KIM" sutunu YOK: defter yalniz NE KADAR diyor, KIM demiyor.
# Somut vaka: 0,15 kredilik bir dogrulama uretimi yaptim; ayni dakika BESIR
# kendi kutusunda o satiri gordu ve "benim degil" yazdi. Dogru bir cikarimdi
# ama CIKARIMDI — kayit degildi.
#
# Bu arac cikarimi KAYDA cevirir: bizim deftere yazilmis her uretimi Higgsfield
# satirlariyla eslestirir, eslesmeyeni SAHIPSIZ diye basar.
#
# 🔴 VE ILK KOSUSUNDA KENDI BOSLUGUMU GOSTERDI: ses uretimlerini `higgsfield
# generate create` ile DOGRUDAN cagirmisim, bogazdan gecmemis, yani KENDI
# DEFTERIME de yazilmamis. Yani "kim" sorusu yalniz kutular arasinda degil,
# KENDI KUTUMUN ICINDE de cevapsizdi. Aracin ilk isi bunu soylemek oldu.
#
# Kullanim: kredi-mutabakat.sh [--saat N] [--tolerans-dk M]
# Exit: 0=mutabakat tam · 1=sahipsiz satir VAR · 2=kullanim
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$SCRIPT_DIR")"
SAAT=24; TOL=3
while [ $# -gt 0 ]; do
  case "$1" in
    --saat) shift; SAAT="${1:-24}" ;;
    --tolerans-dk) shift; TOL="${1:-3}" ;;
    *) echo "kullanim: kredi-mutabakat.sh [--saat N] [--tolerans-dk M]" >&2; exit 2 ;;
  esac; shift
done
case "$SAAT$TOL" in ''|*[!0-9]*) echo "[kirmizi] sayisal deger bekleniyor" >&2; exit 2 ;; esac

DEFTERIMIZ="${TELLAL_DEFTER:-$REPO/uretim/defter.jsonl}"
[ -f "$DEFTERIMIZ" ] || { echo "[kirmizi] kendi defterimiz yok: $DEFTERIMIZ" >&2; exit 1; }

# 🔴 DEFTERI KENDI OKUMAZ: hf-defter.sh tek kaynaktir (K02). Eski surumum
# `account transactions` ciktisini dogrudan ayristiriyordu ve VARSAYILAN 20
# SATIR aliyordu — yani "20 harcamanin 20'si sahipsiz" hukmum KESIK bir evren
# uzerindeydi. Dogrusu: "GORDUGUM 20 satirin 20'si". Gercek pencere 81 satir.
# BESIR'in dersi: "Bir olcum aracinin TAVANINI bilmiyorsan, olctugun sey olay
# degil TAVANDIR; cikti 'tam 20' dediginde supphe vermeliydi."
TSV="$(bash "$SCRIPT_DIR/hf-defter.sh" --saat "$SAAT" 2>/dev/null)" || {
  echo "[kirmizi] defter okunamadi — mutabakat YAPILAMADI (tahmin etmiyorum)" >&2; exit 1; }
[ -n "$TSV" ] || { echo "[kirmizi] defter BOS geldi — hukum YOK" >&2; exit 1; }
HFDOSYA="$(mktemp)"; printf '%s\n' "$TSV" > "$HFDOSYA"
trap 'rm -f "$HFDOSYA"' EXIT

TELLAL_SAAT="$SAAT" TELLAL_TOL="$TOL" TELLAL_BIZIM="$DEFTERIMIZ" TELLAL_HF="$HFDOSYA" python3 - <<'PYK'
import sys, os, json
from datetime import datetime, timedelta, timezone
saat = int(os.environ["TELLAL_SAAT"]); tol = int(os.environ["TELLAL_TOL"])
sinir = datetime.now(timezone.utc) - timedelta(hours=saat)

# Higgsfield satirlari: damga UTC (2026-09-08 olcumu)
hf = []
for l in open(os.environ["TELLAL_HF"], encoding="utf-8"):
    p = l.rstrip("\n").split("\t")
    if len(p) < 4 or p[2] != "spend": continue
    try: t = datetime.fromisoformat(p[0])
    except ValueError: continue
    try: d = float(p[1])
    except ValueError: continue
    if d < 0: hf.append([t, p[3], -d, False])

# Bizim defter: yerel saat, tz'siz ISO -> yerel kabul edilip UTC'ye cevrilir
bizim = []
for l in open(os.environ["TELLAL_BIZIM"], encoding="utf-8"):
    l = l.strip()
    if not l: continue
    try: k = json.loads(l)
    except Exception: continue
    try: t = datetime.fromisoformat(k["tarih"]).astimezone(timezone.utc)
    except Exception: continue
    if t < sinir: continue
    bizim.append([t, k.get("arac", "?"), False])

# Eslestir: zaman yakinligi (tolerans)
for h in hf:
    for b in bizim:
        if b[2]: continue
        if abs((h[0] - b[0]).total_seconds()) <= tol * 60:
            h[3] = True; b[2] = True; break

sahipsiz = [h for h in hf if not h[3]]
bizde_karsiliksiz = [b for b in bizim if not b[2]]
top = sum(h[2] for h in hf); sah = sum(h[2] for h in sahipsiz)

print(f"── kredi mutabakatı · son {saat} saat · tolerans {tol} dk")
print(f"   Higgsfield: {len(hf)} harcama · {top:.2f} kredi")
print(f"   bizim defter: {len(bizim)} kayıt · eşleşen {len(hf)-len(sahipsiz)}")
print(f"   🔴 SAHİPSİZ: {len(sahipsiz)} satır · {sah:.2f} kredi")
for h in sahipsiz[:12]:
    print(f"      {h[0].strftime('%Y-%m-%d %H:%M')}Z  {h[1]:<16} -{h[2]:.2f}")
if len(sahipsiz) > 12: print(f"      … {len(sahipsiz)-12} satır daha")
if bizde_karsiliksiz:
    print(f"   [sarı] bizim defterde karşılıksız {len(bizde_karsiliksiz)} kayıt (ücretsiz/yerel adım olabilir)")
sys.exit(1 if sahipsiz else 0)
PYK
