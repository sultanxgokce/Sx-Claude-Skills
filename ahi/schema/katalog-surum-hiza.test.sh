#!/usr/bin/env bash
# katalog-surum-hiza.test.sh — katalog↔SKILL.md sürüm hizası aracının sınavı (görev …JBZET · kart katalog-surum-hiza). Hermetik: geçici depo.
# kabuk-testleri: sure=60
#   H1 hizalı katalog → rc 0, "sapma 0"            H2 bir sapma → rc 1, girdi adıyla "SAPMA"           H3 path alanı dizin/SKILL.md biçiminde de ölçülür
#   H4 SKILL.md yok / versiyonsuz → ÖLÇÜLEMEDİ, rc 3 (sapma yokken "sapma 0" denmez)              H5 catalog.json yok/bozuk → rc 2
#   H6 --duzelt: yalnız sapan girdinin version satırı değişir, biçim/sıra/öteki alanlar aynen; yeniden ölçüm rc 0; geri okuma raporu
#   H7 --duzelt ölçülemeyen girdiye dokunmaz, rc 3 ile söyler       H8 gerçek depo (bu checkout): sapma 0 (CI kapısının koruduğu şey)
#   M1-M3 MUTASYON: kıyas gevşerse / düzeltme yazmazsa / ölçülemeyen "sapma yok" sayılırsa sınav KIRMIZI
set -u
# KSH_ARAC=<yol>: sınanan aracı değiştirir (mutant kanıtı için — kanit.sh olcum --mutasyon sinav).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ARAC="${KSH_ARAC:-$HERE/katalog-surum-hiza.mjs}"; KOK="$(cd "$HERE/../.." && pwd)"
gecen=0; kalan=0; g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2 ${3:-}"; fi; }
T="$(mktemp -d)"; trap 'rm -rf -- "$T"' EXIT
kur() {  # kur <dizin> : üç skill (a 1.0.0 · b path=b/SKILL.md 2.3.4 · c path=c/ 0.1.0) + katalog
  local d="$1"; mkdir -p "$d/a" "$d/b" "$d/c"
  printf -- '---\nname: a\nversion: 1.0.0\n---\n' > "$d/a/SKILL.md"; printf -- '---\nname: b\nversion: 2.3.4\n---\n' > "$d/b/SKILL.md"; printf -- '---\nname: c\nversion: "0.1.0"\n---\n' > "$d/c/SKILL.md"
  cat > "$d/catalog.json" <<'J'
{
  "version": "2.1",
  "updated": "2026-10-29",
  "skills": [
    {
      "id": "a",
      "name": "A skill",
      "version": "1.0.0",
      "tags": ["x"]
    },
    {
      "id": "b",
      "path": "b/SKILL.md",
      "version": "2.3.4",
      "name": "B"
    },
    {
      "id": "c",
      "path": "c/",
      "version": "0.1.0"
    }
  ]
}
J
}
echo "── H1-H3 · hizalı katalog, path biçimleri"
kur "$T/h1"; O="$(node "$ARAC" "$T/h1" 2>&1)"; RC=$?; [ "$RC" -eq 0 ] && grep -q "sapma 0" <<<"$O" && grep -q "girdi 3" <<<"$O"; g $? "H1 hizalı üç girdi → rc 0, 'sapma 0'" "$O"
[ "$RC" -eq 0 ] && ! grep -q "ÖLÇÜLEMEDİ" <<<"$O"; g $? "H3 path 'b/SKILL.md' ve 'c/' biçimleri ölçüldü (ölçülemedi yok)"
echo "── H2 · sapma"
kur "$T/h2"; sed -i 's/"version": "2.3.4"/"version": "2.0.0"/' "$T/h2/catalog.json"; O="$(node "$ARAC" "$T/h2" 2>&1)"; RC=$?
[ "$RC" -eq 1 ] && grep -q "SAPMA b: katalog 2.0.0 ≠ SKILL.md 2.3.4" <<<"$O" && grep -q "sapma 1" <<<"$O"; g $? "H2 bir sapma → rc 1, girdi adı ve iki sürüm yazılı" "$O"
echo "── H4-H5 · ölçülemedi / okunamadı"
kur "$T/h4"; rm "$T/h4/c/SKILL.md"; printf -- '---\nname: a\n---\n' > "$T/h4/a/SKILL.md"; O="$(node "$ARAC" "$T/h4" 2>&1)"; RC=$?
[ "$RC" -eq 3 ] && grep -q "ÖLÇÜLEMEDİ c: c/SKILL.md yok" <<<"$O" && grep -q "ÖLÇÜLEMEDİ a: a/SKILL.md versiyonsuz" <<<"$O" && ! grep -q "✓ sapma 0" <<<"$O"; g $? "H4 SKILL.md yok / versiyonsuz → rc 3, iki girdi ÖLÇÜLEMEDİ, 'sapma 0' denmedi" "$O"
mkdir -p "$T/h5"; O="$(node "$ARAC" "$T/h5" 2>&1)"; [ $? -eq 2 ] && grep -q "okunamadı" <<<"$O"; g $? "H5a catalog.json yok → rc 2" "$O"
echo '{bozuk' > "$T/h5/catalog.json"; O="$(node "$ARAC" "$T/h5" 2>&1)"; [ $? -eq 2 ]; g $? "H5b bozuk JSON → rc 2"
node "$ARAC" >/dev/null 2>&1; [ $? -eq 2 ]; g $? "H5c argümansız → rc 2"
echo "── H6 · --duzelt"
kur "$T/h6"; sed -i 's/"version": "2.3.4"/"version": "2.0.0"/; s/"version": "0.1.0"/"version": "0.0.9"/' "$T/h6/catalog.json"; cp "$T/h6/catalog.json" "$T/h6/once.json"
O="$(node "$ARAC" "$T/h6" --duzelt 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "✎ b: 2.0.0 → 2.3.4" <<<"$O" && grep -q "✎ c: 0.0.9 → 0.1.0" <<<"$O" && grep -q "geri okuma: hepsi hizalı" <<<"$O"; g $? "H6a iki sapma düzeltildi, geri okuma hizalı, rc 0" "$O"
O2="$(node "$ARAC" "$T/h6" 2>&1)"; [ $? -eq 0 ] && grep -q "sapma 0" <<<"$O2"; g $? "H6b yeniden ölçüm: sapma 0"
D="$(diff "$T/h6/once.json" "$T/h6/catalog.json" | grep -E '^[<>]' | grep -vc '"version"')"; [ "$D" = 0 ] && [ "$(diff "$T/h6/once.json" "$T/h6/catalog.json" | grep -c '^>')" = 2 ] && grep -q '"version": "1.0.0"' "$T/h6/catalog.json" && grep -q '"tags": \["x"\]' "$T/h6/catalog.json"; g $? "H6c yalnız iki version satırı değişti; biçim, sıra ve öteki alanlar aynen (a 1.0.0 dokunulmadı)" "diff dışı satır: $D"
echo "── H7 · --duzelt ölçülemeyene dokunmaz"
kur "$T/h7"; rm "$T/h7/c/SKILL.md"; sed -i 's/"version": "2.3.4"/"version": "2.0.0"/' "$T/h7/catalog.json"; O="$(node "$ARAC" "$T/h7" --duzelt 2>&1)"; RC=$?
[ "$RC" -eq 3 ] && grep -q "✎ b: 2.0.0 → 2.3.4" <<<"$O" && grep -q '"version": "0.1.0"' "$T/h7/catalog.json" && grep -q "ÖLÇÜLEMEDİ c" <<<"$O"; g $? "H7 sapan düzeltildi, ölçülemeyen c aynen kaldı, rc 3 söylendi" "$O"
echo "── H8 · gerçek depo"
O="$(node "$ARAC" "$KOK" 2>&1)"; RC=$?; [ "$RC" -eq 0 ] && grep -q "sapma 0" <<<"$O"; g $? "H8 bu checkout: katalog↔SKILL.md sapma 0 (CI kapısının koruduğu şey)" "$(tail -2 <<<"$O")"
echo "── MUTASYON (araç kopyası): her mutant bir kapıyı KIRMIZI yapmalı"
m() {  # m <ad> <eski> <yeni> → $MU mutant araç
  MU="$T/mut-$1.mjs"; python3 - "$ARAC" "$MU" "$2" "$3" <<'PY'
import sys; src,dst,a,b=sys.argv[1:]; s=open(src,encoding="utf-8").read(); n=s.count(a)
if n!=1: print("ÇAPA", n); sys.exit(1)
open(dst,"w",encoding="utf-8").write(s.replace(a,b))
PY
}
m kiyas-gevsek "s.version !== v) sapma.push" "false) sapma.push" && { kur "$T/m1"; sed -i 's/"version": "2.3.4"/"version": "2.0.0"/' "$T/m1/catalog.json"; node "$MU" "$T/m1" >/dev/null 2>&1; [ $? -eq 0 ]; g $? "M1 kıyas gevşeyince H2 KIRMIZI (mutant sapmayı görmez, rc 0 döner)"; } || g 1 "M1 mutant kurulamadı"
m duzelt-yazmaz "writeFileSync(catalogP, metin);" "/* yazmaz */" && { kur "$T/m2"; sed -i 's/"version": "2.3.4"/"version": "2.0.0"/' "$T/m2/catalog.json"; node "$MU" "$T/m2" --duzelt >/dev/null 2>&1; node "$ARAC" "$T/m2" >/dev/null 2>&1; [ $? -ne 0 ]; g $? "M2 düzeltme diske yazmayınca H6b KIRMIZI (yeniden ölçüm sapma bulur)"; } || g 1 "M2 mutant kurulamadı"
m olculemedi-yesil "if (olculemedi.length) { console.error" "if (false) { console.error" && { kur "$T/m3"; rm "$T/m3/c/SKILL.md"; node "$MU" "$T/m3" >/dev/null 2>&1; [ $? -eq 0 ]; g $? "M3 ölçülemeyen 'sapma yok' sayılınca H4 KIRMIZI (rc 0 döndü)"; } || g 1 "M3 mutant kurulamadı"
echo ""; echo "SONUÇ: $gecen geçti · $kalan kaldı"; [ "$kalan" -eq 0 ]
