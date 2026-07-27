#!/usr/bin/env bash
# layiha-aday-goc.sh — 00-SKORLAR.json'daki 100 taslak-layiha adayını layiha-aday-havuzu.jsonl'e
# TEK-SEFERLİK göçer (L24 FAZ-0). İdempotent: mevcut slug'ı ezmez, yeniden koşunca yeni satır eklenmez.
#
# NE: `_agents/spec/taslak-layiha/00-SKORLAR.json` (git-tracked, PR#647) 100 aday-kaydın
#     kaynak-gerçeğidir (tarihsel — bu script sonrası artık kanonik-DEĞİL). Bu script her kaydı
#     `_agents/handoff/layiha-aday-havuzu.jsonl`'e (append-only, `bulgu-havuzu.jsonl` deseni) taşır.
#
# Kullanım:
#   layiha-aday-goc.sh              # DRY-RUN: kaç eklenecek/atlanacak basar, dosyaya DOKUNMAZ
#   layiha-aday-goc.sh --apply      # gerçekten yazar
#
# Havuz-konumu (per-container — L24 F3'ten beri `hat-yolu.lib.sh` üzerinden, TEK kapı):
#   1) $LAYIHA_ADAY_HAVUZ (env override)  2) <hat-kökü>/_agents/handoff/layiha-aday-havuzu.jsonl
#   ⛔ `$HOME/.claude/...` kademesi KALDIRILDI (K1): orası 10 container'ın ORTAK dizini; git-siz yerde
#      artık RC=2 + reçete. Kök `--git-common-dir`'den → worktree'ler ayrışmaz (B6).
#
# Kaynak-dosya konumu: $LAYIHA_ADAY_KAYNAK (env override) yoksa <hat-kökü>/_agents/spec/taslak-layiha/00-SKORLAR.json
#
# Çıkış: 0 OK · 2 girdi/ortam hatası
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then echo "HATA: python3 yok." >&2; exit 2; fi

PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HAT_LIB="${HAT_YOLU_LIB:-$PAKET/../layiha/scripts/hat-yolu.lib.sh}"
[ -r "$HAT_LIB" ] || { echo "HATA: hat-yolu.lib.sh yok: $HAT_LIB — 'layiha' paketi kurulu mu?" >&2; exit 2; }
# shellcheck source=/dev/null
source "$HAT_LIB"

if [ -n "${LAYIHA_ADAY_HAVUZ:-}" ]; then HAVUZ="$LAYIHA_ADAY_HAVUZ"
else HAVUZ="$(hat_yolu aday-havuzu)" || exit 2; fi
if [ -n "${LAYIHA_ADAY_KAYNAK:-}" ]; then KAYNAK="$LAYIHA_ADAY_KAYNAK"
else
  _kok="$(hat_root)" || exit 2
  KAYNAK="$_kok/_agents/spec/taslak-layiha/00-SKORLAR.json"
fi
APPLY=0
for arg in "$@"; do case "$arg" in --apply) APPLY=1;; esac; done

if [ ! -f "$KAYNAK" ]; then echo "HATA: kaynak yok: $KAYNAK" >&2; exit 2; fi

HAVUZ="$HAVUZ" KAYNAK="$KAYNAK" APPLY="$APPLY" python3 - <<'PY'
import os, json, io, subprocess, sys

havuz = os.environ["HAVUZ"]
kaynak = os.environ["KAYNAK"]
apply_ = os.environ["APPLY"] == "1"

with io.open(kaynak, encoding="utf-8") as f:
    kaynak_data = json.load(f)
kayitlar = kaynak_data.get("kayitlar", [])

mevcut = []
if os.path.exists(havuz):
    with io.open(havuz, encoding="utf-8") as f:
        for l in f:
            if l.strip():
                try: mevcut.append(json.loads(l))
                except Exception: pass
mevcut_slug = {r.get("slug") for r in mevcut}

tarih = subprocess.check_output(["date", "+%F"]).decode().strip()

# pct'ye göre azalan sırala (eşitlikte kaynak-no sırası korunur — kararlı-sıralama)
sirali = sorted(kayitlar, key=lambda r: (-r.get("pct", 0), r.get("no", 0)))

yeni = []
atlanan = 0
for i, r in enumerate(sirali, start=1):
    slug = r.get("slug", "")
    if not slug or slug in mevcut_slug:
        atlanan += 1
        continue
    skor = r.get("skor", {}) or {}
    rec = {
        "id": "A%03d" % i,
        "slug": slug,
        "baslik": r.get("baslik", ""),
        "goal": r.get("goal", ""),
        "nicin_degerli": "",  # kaynak-şemada yok (00-SKORLAR.json'da bu alan üretilmedi); boş bırakıldı
        "sinif": r.get("sinif", ""),
        "spekulatif": bool(r.get("spekulatif", False)),
        "kanit": r.get("kanit", ""),
        "pct": r.get("pct", 0),
        "skor": {
            "deger": skor.get("deger", 0),
            "yapilabilirlik": skor.get("yapilabilirlik", 0),
            "kanit_gucu": skor.get("kanit_gucu", 0),
            "uyum": skor.get("uyum", 0),
            "juri": skor.get("juri", 0),
            "gerekce": skor.get("gerekce", ""),
        },
        "dokuman": "_agents/spec/taslak-layiha/%s-DESIGN.md" % slug,
        "tarih": tarih,
        "kaynak": "tur-2026-07-25",
        "durum": "aday",
        "terfi": {"tarih": "", "layiha_kodu": "", "gerekce": ""},
    }
    yeni.append(rec)

if not apply_:
    print("DRY-RUN: kaynak=%d kayıt · eklenecek=%d · atlanacak(zaten-var)=%d" % (len(kayitlar), len(yeni), atlanan))
    print("Gerçekten yazmak için: --apply")
    sys.exit(0)

os.makedirs(os.path.dirname(havuz) or ".", exist_ok=True)
with io.open(havuz, "a", encoding="utf-8") as f:
    for rec in yeni:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")

print("OK: %d yeni aday eklendi (atlanan=%d, havuz-toplam artık %d)" % (len(yeni), atlanan, len(mevcut) + len(yeni)))
PY
