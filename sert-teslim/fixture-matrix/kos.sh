#!/bin/sh
# kos.sh — /sert-teslim PORTABILITY-KANITI: MMEx-DIŞI proje-X generic-delivery, MOTOR-çekirdeği koşar.
# cumle_bolucu (C-ID) → trust_boundary (yeşil + AYNI-komut kırmızı, marker-tabanlı) → durum_uret (PROOF'tan
# 'kanitli') → matris-lint (TEMİZ). Hiçbir MMEx-değeri kullanmaz → motor proje-agnostik.
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CORE="$DIR/../core"
W=$(mktemp -d); mkdir -p "$W/kanit"
MARKER="$W/marker.txt"
CHK="$DIR/check.sh"
KOMUT="sh $CHK $MARKER"

cp "$DIR/PLAN.md" "$W/PLAN.md"
node "$CORE/cumle_bolucu.mjs" "$W/PLAN.md" --json "$W/cumleler.json"
CID=$(node -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1]));console.log(j.cumleler.find(c=>c.tip==="liste").c_id)' "$W/cumleler.json")

rm -f "$MARKER"  # KIRMIZI: marker-yok → check FAIL
node "$CORE/trust_boundary.mjs" --m-id M1 --cmd "$KOMUT" --runner generic-rc --kanit "$W/kanit" --cwd "$W" --as-kirmizi >/dev/null 2>&1
touch "$MARKER"  # YEŞİL: marker-var → check PASS
node "$CORE/trust_boundary.mjs" --m-id M1 --cmd "$KOMUT" --runner generic-rc --kanit "$W/kanit" --cwd "$W" --kirmizi-ref "$W/kanit/M1-kirmizi.json" >/dev/null 2>&1

printf '# MATRİS — generic-fixture-teslim\n| M# | C-ID | kaynak-cümle-verbatim | yuzey | kanıt-türü | doğrulama-komutu(+hash) | etki-alanı | veri-rejimi | durum | kanıt-JSON-ref |\n|---|---|---|---|---|---|---|---|---|---|\n| M1 | %s | Fixture-check komutu marker-dosya varlığında PASS vermeli (kandırılamayan-saf-kod). | fixture | komut | `%s` | - | sentetik | bekliyor | kanit/M1.json |\n' "$CID" "$KOMUT" > "$W/MATRIS.md"

node "$CORE/durum_uret.mjs" --matris "$W/MATRIS.md" --kanit "$W/kanit" >/dev/null 2>&1
DURUM=$(grep -oE "\| M1 .*\| (kanitli|bekliyor|fail) \|" "$W/MATRIS.md" | grep -oE "kanitli|bekliyor|fail" | head -1)
sh "$CORE/matris-lint.sh" "$W/MATRIS.md" "$W/kanit" >/dev/null 2>&1 && LINT=TEMIZ || LINT=KIRLI

if [ "$DURUM" = "kanitli" ] && [ "$LINT" = "TEMIZ" ]; then
  echo "PORTABILITY-PASS: sert-teslim proje-X generic-delivery → M1=kanitli (PROOF'tan) + matris-lint=TEMİZ"
  exit 0
fi
echo "PORTABILITY-FAIL: durum=$DURUM lint=$LINT"; exit 1
