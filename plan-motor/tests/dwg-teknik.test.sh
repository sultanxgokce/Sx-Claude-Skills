#!/usr/bin/env bash
# dwg-teknik.test.sh — DWG ÇİZİM TEKNİĞİ kapısı, PAKETİN İÇİNDE.
#
# 🔴 NEDEN BURADA: bu iddialar önce TELLAL reposunun `kapi-testi.sh`'ında yaşıyordu.
# Sonuç: kural (skill) yayılıyordu ama SINAV yayılmıyordu — başka bir kutu paketi
# kullanabilir ama doğruluğunu ölçemezdi. MERKEZ verdikti: *"sınav, kuralın yanında yaşar;
# skill içindeki `*.test.sh` dosyalarını merkezî CI keşfeder."* (2026-08-10)
#
# DEĞİŞMEZ: bu betik TELLAL reposuna HİÇ bağlı değildir. Yalnız paketin kendi demo verisini
# ve kendi araçlarını kullanır — başka bir kutuda çıplak çalışır.
#
# Kullanım: bash tests/dwg-teknik.test.sh
# Exit: 0 tüm iddialar tuttu · 1 en az biri kırıldı
set -uo pipefail
PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PAKET" || exit 1

# Kendi-kendine kurulum (kur.sh ile AYNI idempotent kontrol) — "başka bir kutuda çıplak
# çalışır" iddiası npm bağımlılıkları kurulu değilse tutmuyordu (CI'da node_modules yok,
# checkout taze; 2026-08-10 PR#180 bulgusu). Zaten kuruluysa no-op.
if node -e "import('file://$PWD/node_modules/dxf-parser/dist/index.js').catch(()=>process.exit(1))" 2>/dev/null \
   && [ -d node_modules/dejavu-fonts-ttf ] && [ -d node_modules/sharp ]; then
  :
else
  echo "── bağımlılıklar eksik, kuruluyor (npm install --no-fund --no-audit) ──"
  npm install --no-fund --no-audit >/dev/null 2>&1 || { echo "✗ npm install BAŞARISIZ"; exit 1; }
fi

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
GECEN=0; KIRIK=0
yesil() { GECEN=$((GECEN+1)); printf '  ✓ %s\n' "$1"; }
kirmizi() { KIRIK=$((KIRIK+1)); printf '  ✗ KIRILDI %s\n' "$1"; }
iddia() { # iddia <beklenen-rc> <ad> <komut...>
  local bek="$1" ad="$2"; shift 2
  local out rc; out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$bek" ]; then yesil "$ad (rc=$rc)"
  else kirmizi "$ad — beklenen rc=$bek, gelen rc=$rc"; printf '      %s\n' "$(printf '%s' "$out" | tail -2 | tr '\n' ' ')"; fi
}

echo "── plan-motor · DWG çizim tekniği ────────────────────────────"
M="$PAKET/demo/ornek-model.json"
[ -f "$M" ] || { echo "demo modeli yok: $M"; exit 1; }

node cli.mjs ciz --model "$M" --cikti "$T/a.svg" --dwg "$T/a.dwg" >/dev/null 2>&1
iddia 0 "DWG üretildi"                    test -s "$T/a.dwg"
iddia 0 "sihirli bayt AC10xx (DXF yalanı değil)" \
  bash -c "head -c 6 '$T/a.dwg' | grep -qE '^AC10[0-9][0-9]$'"
iddia 0 "öz-denetim temiz"                node scripts/dwg-denetle.mjs "$T/a.dwg"
iddia 0 "çizim tekniği (kontur·dolgu·font·kalem·renk·açıklık)" \
  node scripts/dwg-teknik-kapi.mjs teknik "$T/a.dwg" "$M"

# Determinizm GEOMETRİ üzerinden ölçülür — DWG başlığı zaman damgası taşır, bayt eşitliği YOK.
# Çırak hasadı (2026-08-10): duvar sırası çevriliyordu ama AÇIKLIK sırası çevrilmiyordu.
# Açıklık çizgileri normal vektöründen türer; bir dalda işaretli normal kopyalanırsa
# çizgiler yön-bağımlı olur ve bu ancak açıklık sırası değişince görünür.
node -e '
  const fs=require("fs"); const m=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  m.duvarlar.reverse(); if (Array.isArray(m.acikliklar)) m.acikliklar.reverse();
  fs.writeFileSync(process.argv[2], JSON.stringify(m));
' "$M" "$T/ters.json" 2>/dev/null
node cli.mjs ciz --model "$T/ters.json" --cikti "$T/b.svg" --dwg "$T/b.dwg" >/dev/null 2>&1
iddia 0 "birleşim deterministik (ters duvar VE açıklık sırası = aynı geometri)" \
  node scripts/dwg-teknik-kapi.mjs ayni "$T/a.dwg" "$T/b.dwg"

printf 'ozet: gecen=%d kirik=%d\n' "$GECEN" "$KIRIK"
[ "$KIRIK" -eq 0 ] || { echo "SONUC: KIRMIZI"; exit 1; }
echo "SONUC: GECTI"
