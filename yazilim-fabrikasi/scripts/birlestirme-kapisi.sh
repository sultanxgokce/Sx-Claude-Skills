#!/usr/bin/env bash
# birlestirme-kapisi.sh — fabrika 4. adımın SON kapısı: kanıtsız ya da puansız iş BİRLEŞTİRİLEMEZ.
#
# NİÇİN VAR (Sultan sorusu 23 Eyl 2026: "kullandığından nasıl emin olurum"): fabrikanın adımları
# bugüne dek TALİMATTI — kanıt toplamayan, bağımsız göze göstermeyen bir iş yine de birleşebiliyordu.
# Sistem "kullanmadın" diyemiyor, yalnız "kullandığın görünmüyor" diyebiliyordu. Bu kapı onu kapatır:
# birleştirme anında ÜÇ şey ölçülür ve biri eksikse rc≠0.
#
# ÜÇ ÖLÇÜM
#   1) KART     — işin kartı var mı (0. adım atlanmamış mı)
#   2) KANIT    — `kanit.py dogrula` rc=0: manifest ARAÇ imzalı, dosya sha'ları tutuyor
#   3) PUAN     — son DENETIM-<tur>.json: kod_puani=5 VE dogru_sey=E VE denetçi ≠ yazan
#
# 🔴 NE ÖLÇMEZ (dürüstlük): kanıtın DOĞRU şeyi ölçtüğünü ölçmez — onu bağımsız göz yapar.
#    Sınıf işinde Sultan onayını da ölçmez (A06: onay üretilemez, yalnız insan verir) — yalnız
#    kartın sınıf taşıdığını SÖYLER, kararı insana bırakır.
#
# Kullanım:
#   birlestirme-kapisi.sh <iş> [--depo KÖK] [--sessiz]
#   birlestirme-kapisi.sh --pr <N> [--depo KÖK]     (PR'ın dal adından iş adını çözer)
# rc: 0 GEÇTİ · 1 eksik (kanıt yok/puan yetersiz/kart yok) · 2 kullanım · 3 ÖLÇÜLEMEDİ (yeşil değil)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IS=""; PR=""; DEPO="${KANIT_DEPO:-}"; SESSIZ=0
while [ $# -gt 0 ]; do case "$1" in
  --pr) PR="$2"; shift 2 ;; --depo) DEPO="$2"; shift 2 ;; --sessiz) SESSIZ=1; shift ;;
  -h|--help) sed -n '1,22p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
  *) [ -z "$IS" ] && IS="$1" || { echo "✗ tanınmayan argüman: $1" >&2; exit 2; }; shift ;;
esac; done

_y() { [ "$SESSIZ" -eq 1 ] || printf '%s\n' "$*"; }
_h() { printf '✗ %s\n' "$*" >&2; }

# Depo kökü: BİRİNCİL ağaç (worktree'den çağrılsa da kart oradadır); kanıt ise ÇALIŞILAN ağaçta.
if [ -z "$DEPO" ]; then
  c="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" && DEPO="$(dirname "$c")"
fi
[ -n "$DEPO" ] || { _h "depo kökü bulunamadı — ÖLÇÜLEMEDİ"; exit 3; }
WT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$DEPO")"

# --pr verilmişse iş adını PR'ın dalından çöz (is-alani dalı iş adıyla açar)
if [ -z "$IS" ] && [ -n "$PR" ]; then
  command -v gh >/dev/null 2>&1 || { _h "gh yok, PR'dan iş adı çözülemedi — ÖLÇÜLEMEDİ"; exit 3; }
  IS="$(cd "$DEPO" && gh pr view "$PR" --json headRefName --jq .headRefName 2>/dev/null)"
  [ -n "$IS" ] || { _h "PR #$PR dalı okunamadı — ÖLÇÜLEMEDİ"; exit 3; }
  IS="${IS##*/}"   # muavin/<iş> gibi önekleri at
fi
[ -n "$IS" ] || { _h "iş adı gerekiyor (ya da --pr N)"; exit 2; }

KART="$DEPO/_agents/fabrika/kartlar/$IS.json"
DZ="$WT/_agents/fabrika/kanit/$IS"; [ -d "$DZ" ] || DZ="$DEPO/_agents/fabrika/kanit/$IS"

eksik=0; olcemedi=0
_y "── BİRLEŞTİRME KAPISI · iş: $IS"

# 1 · KART
if [ -f "$KART" ]; then
  sinif="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(','.join(d.get('siniflar') or []) or 'yok')" "$KART" 2>/dev/null)"
  sultan="$(python3 -c "import json,sys;print('E' if json.load(open(sys.argv[1])).get('sultan') else 'H')" "$KART" 2>/dev/null)"
  _y "  ✓ kart var · sınıf: $sinif"
  [ "$sultan" = "E" ] && _y "  ⚠ SINIF İŞİ — birleştirme kararı SULTAN'ın; bu kapı onay ÜRETMEZ (A06)"
else
  _h "kart YOK: $KART — 0. adım atlanmış"; eksik=$((eksik+1))
fi

# 2 · KANIT
if [ -f "$HERE/kanit.py" ]; then
  KANIT_KOK="${DZ%/_agents/fabrika/kanit/$IS}"     # kanıt dizininden deponun kökünü türet
  cik="$(python3 "$HERE/kanit.py" --depo "$KANIT_KOK" dogrula "$IS" 2>&1)"; krc=$?
  case "$krc" in
    0) _y "  ✓ kanıt: $(printf '%s' "$cik" | head -1 | sed 's/^✓ //')" ;;
    1) _h "kanıt manifesti BOZUK (elle yazılmış ya da dosya değişmiş)"; eksik=$((eksik+1)) ;;
    *) _h "kanıt YOK — 'kanıtsız iş gönderilemez'"; eksik=$((eksik+1)) ;;
  esac
else
  _h "kanit.py bulunamadı — ÖLÇÜLEMEDİ"; olcemedi=$((olcemedi+1))
fi

# 3 · PUAN
SON="$(ls "$DZ"/DENETIM-[0-9]*.json 2>/dev/null | sort -V | tail -1)"
if [ -n "$SON" ]; then
  okuma="$(python3 - "$SON" <<'PY'
import json,sys
d=json.load(open(sys.argv[1],encoding="utf-8")); s=d["sonuc"]
print(f"{s['kod_puani']}|{s['dogru_sey']}|{d.get('yazan','?')}|{d.get('denetci','?')}|{d.get('tur','?')}|{len(s['bulgular'])}")
PY
)"
  IFS='|' read -r puan dogru yazan denetci tur nb <<<"$okuma"
  _y "  · denetim tur $tur · $puan/5 · doğru şey: $dogru · bulgu: $nb · yazan: $yazan → denetçi: $denetci"
  [ "$puan" = "5" ] || { _h "kod puanı 5 DEĞİL ($puan) — adım 2'ye dönülmeliydi"; eksik=$((eksik+1)); }
  [ "$dogru" = "E" ] || { _h "'doğru şey mi' EVET değil ($dogru) — kod doğru olsa da yanlış iş olabilir"; eksik=$((eksik+1)); }
  case "$denetci" in
    *"$yazan"*) _h "denetçi yazanla AYNI ($yazan) — bağımsız göz değil (K1)"; eksik=$((eksik+1)) ;;
  esac
else
  _h "DENETİM kaydı YOK — bağımsız göz hiç koşmamış"; eksik=$((eksik+1))
fi

if [ "$olcemedi" -gt 0 ]; then _y ""; _h "ÖLÇÜLEMEDİ — kapı yeşil demiyor (rc=3)"; exit 3; fi
if [ "$eksik" -gt 0 ]; then
  _y ""
  _h "BİRLEŞTİRME ENGELLENDİ — $eksik eksik."
  _y "  Yapılacak: kanıtı topla (kanit.sh), bağımsız göze gönder (denetci.sh), 5+E alınca tekrar dene."
  _y "  Acil durumda: FABRIKA_KAPISIZ=1 — gerekçeyi iş kartına ve PR gövdesine yaz (sessiz atlama yasak)."
  exit 1
fi
_y ""; _y "✓ GEÇTİ — kanıt imzalı, bağımsız göz 5/5 + doğru şey E, kart yerinde."
exit 0
