#!/usr/bin/env bash
# once-sonra.sh <eski-scripts-dizini> <yeni-scripts-dizini> — aynı girdiyle ana hat ve dal: (1) eşik altı istem bayt bayt aynı mı
# (2) BÂNİ vakası (fark eşik altı, istem eşik üstü): eski kırpar + tur yakar, yeni İŞİ BÖL + tur yakmaz.
set -uo pipefail
ESKI="$1"; YENI="$2"; hata=0
kur() {  # kur <dizin> → sahte depo
  local T; T="$(mktemp -d)"; ( cd "$T" && git init -q -b main ) >/dev/null 2>&1
  printf '#!/usr/bin/env bash\ncp "$1" "${SAHTE_ISTEM_KOPYA:-/dev/null}"; printf "%%s" "$SAHTE_JSON"\n' > "$T/sahte.sh"; chmod +x "$T/sahte.sh"
  python3 -c '
import sys
with open(sys.argv[1],"w") as f:
    f.write("diff --git a/y.ts b/y.ts\n--- a/y.ts\n+++ b/y.ts\n@@ -1 +1,50 @@\n")
    for i in range(50): f.write("+"+("y"*55)+" %d\n" % i)
' "$T/f.patch"
  echo "$T"
}
J='{"kod_puani":5,"dogru_sey":"E","ozet":"o","bulgular":[],"kanit_gorusu":"k"}'
for yan in ESKI YENI; do
  dz="${!yan}"; T="$(kur)"
  export KANIT_DEPO="$T" DENETCI_KOMUT="$T/sahte.sh"
  bash "$dz/kanit.sh" olcum is-o olc --asama tek -- echo 1 >/dev/null 2>&1
  # (1) eşik geniş: kırpma da bölme de yok → istem karşılaştırılır
  SAHTE_ISTEM_KOPYA="$T/istem.md" SAHTE_JSON="$J" DENETCI_KIRP_ESIK=900000 bash "$dz/denetci.sh" is-o --diff "$T/f.patch" >/dev/null 2>&1
  cp "$T/istem.md" "${OUT:-.}/istem-$yan.md"
  S0=$(wc -c < "$T/istem.md"); FB=$(wc -c < "$T/f.patch"); E=$(( (S0 - 200) * 11 / 12 ))
  # (2) BÂNİ vakası: fark < eşik, istem > tetik
  CIKTI="$(SAHTE_JSON="$J" DENETCI_KIRP_ESIK=$E bash "$dz/denetci.sh" is-o --diff "$T/f.patch" 2>&1)"; RC=$?
  KAYIT="$T/_agents/fabrika/kanit/is-o/DENETIM-2.json"
  if [ -f "$KAYIT" ]; then KIRP=$(python3 -c "import json;print(json.load(open('$KAYIT'))['kirpildi'])"); else KIRP="(DENETIM-2 yok — tur yakılmadı)"; fi
  echo "── $yan · $dz"
  echo "   (1) eşik altı istem: $S0 bayt"
  echo "   (2) fark $FB bayt < eşik $E · istem ≈ $S0+önceki tur > tetik $((E + E/11)) → rc=$RC · kayıt: $KIRP"
  grep -E "İŞİ BÖL|parçalar|en büyük|KIRPILDI|kırpıldı" <<<"$CIKTI" | sed 's/^/      /'
  rm -rf "$T"
done
if cmp -s "${OUT:-.}/istem-ESKI.md" "${OUT:-.}/istem-YENI.md"; then echo "✓ (1) istem bayt bayt AYNI (kanıt satırları dahil)"
else
  if diff -q <(sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+[^" ]*//g; s/[0-9a-f]{8}-[0-9a-f-]{27}//g; s/[0-9a-f]{32,64}//g' "${OUT:-.}/istem-ESKI.md") <(sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+[^" ]*//g; s/[0-9a-f]{8}-[0-9a-f-]{27}//g; s/[0-9a-f]{32,64}//g' "${OUT:-.}/istem-YENI.md") >/dev/null; then
    echo "✓ (1) istem aynı (yalnız ölçüm zamanı / kimliği / sha farklı — her koşumda yeni ölçüm)"
  else echo "✗ (1) istem FARKLI:"; diff "${OUT:-.}/istem-ESKI.md" "${OUT:-.}/istem-YENI.md" | head -20; hata=1; fi
fi
exit $hata
