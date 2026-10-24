#!/usr/bin/env bash
# kabuk-testleri: sure=120
# agir-sira-sarma.test.sh — denetci.sh ve kanit.sh olcum'un ağır koşularının kod kutusunun ortak sırasına (agir-sira.sh) sarılması
#   (görev …489VP8 · SERDAR 24 Eki "(a) ONAY"): en çok 15 dk bekle → UYARIYLA koş (fail-open) · sıra yoksa/kapalıysa sarmasız ·
#   sınav kancası (DENETCI_KOMUT) sırayı hiç görmez · bekleme zaman aşımına SAYILMAZ. HERMETİK: sahte sıra betiği, sahte codex; gerçek
#   sıra kütüğüne (/config/.filo) ve yüke dokunmaz; G bölümü gerçek sıra betiğini YALNIZ geçici AGIR_SIRA_DIZ ile koşar. Mutasyon kanıtlı.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="${MUTANT_PKG:-$HERE}"; D="$PKG/denetci.sh"; K="$PKG/kanit.sh"   # mutant koşusunda PKG = mutasyonlu tam kopya
T="$(mktemp -d)"; trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], True)" "$T"' EXIT
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2 ${3:-}"; fi; }
unset DENETCI_KOMUT KANIT_SIRA DENETCI_SIRA AGIR_SIRA_BEKLE
export FABRIKA_AILE_NOTIFY=- KANIT_DEPO="$T"; ( cd "$T" && git init -q -b main ) >/dev/null 2>&1
# sahte sıra: çağrıyı (etiket · ZAMAN_ASIMI · BEKLE · komut) kaydeder, SIRA_UYKU sn "bekler", komutu koşar, rc'sini geçirir
SIRA="$T/sira-sahte.sh"; cat > "$SIRA" <<'SH'
#!/usr/bin/env bash
E="$1"; shift 2
printf '%s|%s|%s|%s\n' "$E" "${AGIR_SIRA_ZAMAN_ASIMI:-}" "${AGIR_SIRA_BEKLE:-}" "$1" >> "$SIRA_LOG"
sleep "${SIRA_UYKU:-0}"
"$@"
SH
chmod +x "$SIRA"; export SIRA_LOG="$T/sira.log" AGIR_SIRA_BETIK="$SIRA"
# sahte codex: -o dosyasına SAHTE_JSON'u yazar
ZB="$T/bin"; mkdir -p "$ZB"; cat > "$ZB/codex" <<'SH'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do [ "$1" = "-o" ] && { printf '%s' "$SAHTE_JSON" > "$2"; exit 0; }; shift; done; exit 1
SH
chmod +x "$ZB/codex"; export PATH="$ZB:$PATH"
J='{"kod_puani":5,"dogru_sey":"E","ozet":"o","bulgular":[],"kanit_gorusu":"k"}'
printf 'diff --git a/x b/x\n+satir\n' > "$T/d.patch"

echo "════ K · kanit.sh olcum ════"
: > "$SIRA_LOG"; O="$(bash "$K" olcum is-k olc --asama tek -- bash -c 'echo $((6*7)); exit 0' 2>&1)"; rc=$?
[ $rc -eq 0 ] && grep -q '^kanit-is-k-olc|kos|900|bash$' "$SIRA_LOG"; g $? "K1 ölçüm komutu sıradan geçer: etiket kanit-<iş>-<etiket> · kos kipi · bekle 900 sn (15 dk)" "→ $(cat "$SIRA_LOG") $O"
grep -qx 42 "$T/_agents/fabrika/kanit/is-k/olcum-olc-tek.txt"; g $? "K2 komutun çıktısı kanıt dosyasında (sarma çıktıyı yutmaz)"
: > "$SIRA_LOG"; bash "$K" olcum is-k2 olc --asama tek -- bash -c 'exit 3' >/dev/null 2>&1; rc=$?
[ $rc -ne 0 ] && grep -q '"rc": 3\|rc=3' "$T/_agents/fabrika/kanit/is-k2/olcum-olc-tek.txt"; g $? "K3 komutun rc'si (3) sarmadan geçip kayda yazılır (renk kırmızı)"
: > "$SIRA_LOG"; KANIT_SIRA=0 bash "$K" olcum is-k3 olc --asama tek -- true >/dev/null 2>&1
[ ! -s "$SIRA_LOG" ]; g $? "K4 KANIT_SIRA=0 → sıra çağrılmaz"
: > "$SIRA_LOG"; AGIR_SIRA_BETIK="$T/yok.sh" bash "$K" olcum is-k4 olc --asama tek -- bash -c 'echo $((6*7))' >/dev/null 2>&1; rc=$?
[ $rc -eq 0 ] && grep -qx 42 "$T/_agents/fabrika/kanit/is-k4/olcum-olc-tek.txt"; g $? "K5 sıra betiği yoksa (başka kutu) komut sarmasız koşar"
: > "$SIRA_LOG"; AGIR_SIRA_BEKLE=7 bash "$K" olcum is-k5 olc --asama tek -- true >/dev/null 2>&1
grep -q '|kos|7|' "$SIRA_LOG"; g $? "K6 AGIR_SIRA_BEKLE ortamdan geçer (900 yalnız varsayılan)"
: > "$SIRA_LOG"; AGIR_SIRA_BEKLE=99999 bash "$K" olcum is-k7 olc --asama tek -- true >/dev/null 2>&1
grep -q '|kos|900|' "$SIRA_LOG" && ! grep -q '|99999|' "$SIRA_LOG"; g $? "K7 AGIR_SIRA_BEKLE=99999 → 900'e kırpılır (en çok 15 dk SERT tavan)" "→ $(cat "$SIRA_LOG")"
: > "$SIRA_LOG"; AGIR_SIRA_BEKLE=0 bash "$K" olcum is-k8 olc --asama tek -- true >/dev/null 2>&1; r0=$(cat "$SIRA_LOG")
: > "$SIRA_LOG"; AGIR_SIRA_BEKLE=abc bash "$K" olcum is-k8b olc --asama tek -- true >/dev/null 2>&1
grep -q '|kos|900|' <<<"$r0" && grep -q '|kos|900|' "$SIRA_LOG"; g $? "K8 AGIR_SIRA_BEKLE=0 / sayı değil → 900"

echo "════ D · denetci.sh (codex yolu) ════"
bash "$K" olcum is-d olc --asama tek -- true >/dev/null 2>&1
: > "$SIRA_LOG"; SAHTE_JSON="$J" bash "$D" is-d --diff "$T/d.patch" >"$T/d.out" 2>&1; rc=$?
[ $rc -eq 0 ] && grep -q '^denetci-is-d|kos|900|bash$' "$SIRA_LOG"; g $? "D1 codex koşusu sıradan geçer: etiket denetci-<iş> · kos · 900 sn; 5/E GEÇTİ rc 0" "→ rc=$rc $(cat "$SIRA_LOG")"
bash "$K" olcum is-d2 olc --asama tek -- true >/dev/null 2>&1
: > "$SIRA_LOG"; SAHTE_JSON="$J" SIRA_UYKU=4 DENETCI_ZAMAN_ASIMI=2 bash "$D" is-d2 --diff "$T/d.patch" >"$T/d2.out" 2>&1; rc=$?
[ $rc -eq 0 ]; g $? "D2 sıradaki 4 sn bekleme 2 sn'lik zaman aşımına SAYILMAZ (timeout sıranın İÇİNDE)" "→ rc=$rc $(tail -3 "$T/d2.out")"
bash "$K" olcum is-d3 olc --asama tek -- true >/dev/null 2>&1
: > "$SIRA_LOG"; SAHTE_JSON="$J" DENETCI_SIRA=0 bash "$D" is-d3 --diff "$T/d.patch" >/dev/null 2>&1
[ ! -s "$SIRA_LOG" ]; g $? "D3 DENETCI_SIRA=0 → sıra çağrılmaz"
bash "$K" olcum is-d4 olc --asama tek -- true >/dev/null 2>&1
SAHTE="$T/sahte-denetci.sh"; printf '#!/usr/bin/env bash\nprintf "%%s" "$SAHTE_JSON"\n' > "$SAHTE"; chmod +x "$SAHTE"
: > "$SIRA_LOG"; SAHTE_JSON="$J" DENETCI_KOMUT="$SAHTE" bash "$D" is-d4 --diff "$T/d.patch" >/dev/null 2>&1
[ ! -s "$SIRA_LOG" ]; g $? "D4 sınav kancası (DENETCI_KOMUT) sırayı HİÇ görmez"
bash "$K" olcum is-d5 olc --asama tek -- true >/dev/null 2>&1
: > "$SIRA_LOG"; SAHTE_JSON="$J" AGIR_SIRA_BETIK="$T/yok.sh" bash "$D" is-d5 --diff "$T/d.patch" >/dev/null 2>&1; rc=$?
[ $rc -eq 0 ] && [ ! -s "$SIRA_LOG" ]; g $? "D5 sıra betiği yoksa denetim sarmasız yine yürür (rc 0)"
bash "$K" olcum is-d6 olc --asama tek -- true >/dev/null 2>&1
: > "$SIRA_LOG"; SAHTE_JSON="$J" AGIR_SIRA_BEKLE=5000 bash "$D" is-d6 --diff "$T/d.patch" >/dev/null 2>&1
grep -q '^denetci-is-d6|kos|900|' "$SIRA_LOG"; g $? "D6 AGIR_SIRA_BEKLE=5000 → 900'e kırpılır (en çok 15 dk SERT tavan)" "→ $(cat "$SIRA_LOG")"

echo "════ G · GERÇEK sıra betiği (kütük): yük altında koşulunca 'yuk-altinda-kosuldu' satırı ════"
GERCEK=/config/projects/Nexus/scripts/agir-sira.sh
if [ -f "$GERCEK" ]; then
  GD="$T/gercek-sira"; mkdir -p "$GD"; GL="$GD/sira.log"
  env AGIR_SIRA_BETIK="$GERCEK" AGIR_SIRA_DIZ="$GD" AGIR_SIRA_YUK=1 AGIR_SIRA_YUK_OKU="echo 99" AGIR_SIRA_ADIM=1 AGIR_SIRA_BEKLE=2 bash "$K" olcum is-g1 olc --asama tek -- bash -c 'echo $((6*7))' >/dev/null 2>&1; rc=$?
  [ $rc -eq 0 ] && grep -q $'^[^\t]*\tkanit-is-g1-olc\tyuk-altinda-kosuldu\t' "$GL" && grep -qx 42 "$T/_agents/fabrika/kanit/is-g1/olcum-olc-tek.txt"; g $? "G1 kanit.sh olcum: yük aşılınca komut koşar (42) ve kütükte yuk-altinda-kosuldu satırı var" "→ rc=$rc $(cat "$GL" 2>/dev/null)"
  bash "$K" olcum is-g2 olc --asama tek -- true >/dev/null 2>&1
  env AGIR_SIRA_BETIK="$GERCEK" AGIR_SIRA_DIZ="$GD" AGIR_SIRA_YUK=1 AGIR_SIRA_YUK_OKU="echo 99" AGIR_SIRA_ADIM=1 AGIR_SIRA_BEKLE=2 SAHTE_JSON="$J" bash "$D" is-g2 --diff "$T/d.patch" >/dev/null 2>&1; rc=$?
  [ $rc -eq 0 ] && grep -q $'^[^\t]*\tdenetci-is-g2\tyuk-altinda-kosuldu\t' "$GL"; g $? "G2 denetci.sh: yük aşılınca denetim yine koşar (rc 0) ve kütükte yuk-altinda-kosuldu satırı var" "→ rc=$rc $(cat "$GL" 2>/dev/null)"
else
  echo "  ⚠ G1/G2 ATLANDI: gerçek sıra betiği bu kutuda yok ($GERCEK) — 'geçti' sayılmaz, ölçülemedi"
fi

echo "════ MUTASYON (kopya; her mutant bir kapıyı kırmızı yapmalı) ════"
mut() { # mut <ad> <dosya> <eski> <yeni> <kapı> <açıklama> — paketin tam kopyasında TEK çapa değişir, aksi halde 'çapa bayat'
  local dst="$T/pkg-$1"; mkdir -p "$dst"; cp "$HERE"/*.sh "$HERE"/*.py "$dst/" 2>/dev/null
  python3 - "$dst/$2" "$3" "$4" <<'PY'
import sys; s=open(sys.argv[1],encoding="utf-8").read(); a,b=sys.argv[2],sys.argv[3]
n=s.count(a); open(sys.argv[1],"w",encoding="utf-8").write(s.replace(a,b,1) if n==1 else s); sys.exit(0 if n==1 else 3)
PY
  [ $? -eq 0 ] || { g 1 "$1 mutant üretilemedi (çapa bayat)"; return; }
  MUTANT_PKG="$dst" bash "$dst/agir-sira-sarma.test.sh" --mutant-kos > "$T/m-$1.out" 2>&1
  grep -q "✗ $5" "$T/m-$1.out"; g $? "$1 $6"
}
if [ "${1:-}" != "--mutant-kos" ]; then
  mut M1 kanit.py '"AGIR_SIRA_ZAMAN_ASIMI": "kos"' '"AGIR_SIRA_ZAMAN_ASIMI": "ertele"' K1 "kanit kipi ertele olursa K1 kırmızı (yük altında iş durur)"
  mut M2 kanit.py 'ham = os.environ.get("AGIR_SIRA_BEKLE", "900")' 'ham = os.environ.get("AGIR_SIRA_BEKLE", "600")' K1 "kanit varsayılan bekleme 900'den kayarsa K1 kırmızı"
  mut M3 kanit.py 'os.environ.get("KANIT_SIRA", "1") == "0" or ' '' K4 "kanit KANIT_SIRA=0 kapısı kalkarsa K4 kırmızı"
  mut M4 kanit.py ' or not os.path.isfile(betik)' '' K5 "kanit sıra betiği yoksa sarmaya kalkarsa K5 kırmızı"
  mut M5 denetci.sh 'AGIR_SIRA_ZAMAN_ASIMI=kos AGIR_SIRA_BEKLE="$SIRA_BEKLE"' 'AGIR_SIRA_ZAMAN_ASIMI=ertele AGIR_SIRA_BEKLE="$SIRA_BEKLE"' D1 "denetci kipi ertele olursa D1 kırmızı"
  mut M6 denetci.sh '    AGIR_SIRA_ZAMAN_ASIMI=kos AGIR_SIRA_BEKLE="$SIRA_BEKLE" bash "$SIRA_BETIK"' '    timeout -k "$ZA_K" "$ZA" env AGIR_SIRA_ZAMAN_ASIMI=kos AGIR_SIRA_BEKLE="$SIRA_BEKLE" bash "$SIRA_BETIK"' D2 "denetci timeout sıranın DIŞINA taşınırsa bekleme zaman aşımına sayılır (D2 kırmızı)"
  mut M7 denetci.sh '[ -z "${DENETCI_KOMUT:-}" ] && [ -f "$SIRA_BETIK" ]' '[ -f "$SIRA_BETIK" ]' D4 "denetci sınav kancasında da sıraya girerse D4 kırmızı"
  mut M9 kanit.py '        bekle = min(bekle, 900)' '        bekle = bekle' K7 "kanit 900 tavanını kırpmazsa K7 kırmızı (15 dk sert tavan değil)"
  mut M10 denetci.sh '[ "$SIRA_BEKLE" -gt 900 ] &&' 'false &&' D6 "denetci 900 tavanını kırpmazsa D6 kırmızı"
  mut M11 kanit.py 'ham.isdigit() and int(ham) > 0 else 900' 'ham.isdigit() else 900' K8 "kanit sıfır/sayı olmayan beklemede 900'e dönmezse K8 kırmızı"
  mut M8 denetci.sh '"${DENETCI_SIRA:-1}" != 0 ] && [ -z' '"x" != 0 ] && [ -z' D3 "denetci DENETCI_SIRA=0 kapısı kalkarsa D3 kırmızı"
fi
echo ""; echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"; [ "$kalan" -eq 0 ]
