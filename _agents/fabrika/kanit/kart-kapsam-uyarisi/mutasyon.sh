#!/usr/bin/env bash
# mutasyon.sh <yazilim-fabrikasi dizini> — kapsam uyarısı (retro W42 ders M2) kapılarının mutasyon ölçümü.
# Her mutant beceri dizininin TAM kopyasında koşar; önce bozulmamış KONTROL kopyası kart.test.sh'ı geçmeli (geçmezse rc=2).
# İç koşum tavanlı: 124 = askıda → yakalama SAYILMAZ.
set -uo pipefail
SRC="$(cd "$1" && pwd)"; KOK="$(mktemp -d)"; yakalanan=0; kacan=0; askida=0
kos() { ( cd "$1/scripts" && timeout 300 bash kart.test.sh </dev/null >/dev/null 2>&1 ); }
kopya() { local d="$KOK/$1"; mkdir -p "$d"; cp -a "$SRC/." "$d/"; echo "$d"; }
K="$(kopya kontrol)"; kos "$K" || { echo "✗ KONTROL kopyası kırmızı — mutasyon ölçülemez"; exit 2; }
echo "✓ kontrol kopyası yeşil"
mut() {  # mut <ad> <eski> <yeni>  (scripts/kart.sh içinde, tam bir kez geçmeli)
  local d; d="$(kopya "$1")"
  python3 - "$d/scripts/kart.sh" "$2" "$3" <<'PY' || { echo "✗ mutant '$1': çapa yok (bayat)"; kacan=$((kacan+1)); return; }
import sys
p, eski, yeni = sys.argv[1:4]; s = open(p, encoding="utf-8").read()
if s.count(eski) != 1: raise SystemExit(1)
open(p, "w", encoding="utf-8").write(s.replace(eski, yeni))
PY
  kos "$d"; local rc=$?
  if [ $rc = 124 ]; then askida=$((askida+1)); echo "⏸ mutant '$1' askıda (124) — yakalama SAYILMAZ"
  elif [ $rc != 0 ]; then yakalanan=$((yakalanan+1)); echo "✓ mutant '$1' sınavı KIRMIZI yapıyor"
  else kacan=$((kacan+1)); echo "✗ mutant '$1' KAÇTI (sınav yeşil kaldı)"; fi
}
mut iki-depo-uyarmaz 'if len(anilan) >= 2:' 'if False:'
mut tek-depo-da-uyarilir 'if len(anilan) >= 2:' 'if len(anilan) >= 1:'
mut cok-gunluk-uyarmaz $'if h:\n    print("ÇOK GÜNLÜK' $'if False:\n    print("ÇOK GÜNLÜK'
mut ad-siniri-yok 'return any(re.search(r"(?<![\w-])" + re.escape(a) + r"(?![\w-])", cumle) for a in adlar)' 'return any(re.search(re.escape(a), cumle) for a in adlar)'
mut harf-duyarsiz 'return any(re.search(r"(?<![\w-])" + re.escape(a) + r"(?![\w-])", cumle) for a in adlar)' 'return any(re.search(r"(?<![\w-])" + re.escape(a) + r"(?![\w-])", cumle, re.I) for a in adlar)'
mut karta-yazilmaz '"kapsam_uyarilari":[u for u in kuyari.splitlines() if u.strip()]}' '"kapsam_uyarilari":[]}'
mut uyari-reddeder '    KUYARI="$(kapsam_uyar' '    [ -n "$(kapsam_uyar "$IS" "$IS_C" "$(basename "$DEPO")")" ] && exit 1; KUYARI="$(kapsam_uyar'
mut hafta-kodu-yok '|W\d{2}|' '|'
echo "── SONUÇ: $yakalanan yakalandı · $kacan kaçtı · $askida askıda ──"
[ "$kacan" = 0 ] && [ "$askida" = 0 ]
