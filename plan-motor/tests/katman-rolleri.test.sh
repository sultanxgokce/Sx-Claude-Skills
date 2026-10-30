#!/usr/bin/env bash
# katman-rolleri.test.sh — SINIR KATMANI kapısı, PAKETİN İÇİNDE.
#
# 🔴 NEDEN VAR: sınır katmanı kümesi kodda sabitti (üstelik İKİ kopya) ve gerçek bir müşteri
# çiziminde `Zone_Line` katmanını duvar sayıyordu. O katman mobilya/donatı taşıyor; mobilya
# ayak izleri odalardan oyuldu → 8 odada toplam 89.76 yerine 71.51 m² (%20 kayıp), ve hata
# SESSİZDİ (lifting RC 0 dönüyordu). Bkz. DEVIR-CEVAP.md 2026-08-12.
#
# DEĞİŞMEZ: bu betik TELLAL reposuna bağlı DEĞİLDİR ve müşteri dosyası KULLANMAZ
# (müşteri evrakı ortak rafa konmaz). Fixture burada, sentetik olarak ÜRETİLİR.
#
# Kullanım: bash tests/katman-rolleri.test.sh   ·   Exit: 0 tuttu · 1 kırıldı
set -uo pipefail
PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PAKET" || exit 1

GECTI=0; KALDI=0
iddia() { # iddia <beklenen-rc> <ad> <komut...>
  local bek="$1" ad="$2"; shift 2
  local out; out="$("$@" 2>&1)"; local rc=$?
  if [ "$rc" = "$bek" ]; then GECTI=$((GECTI+1)); echo "  ✓ $ad"
  else KALDI=$((KALDI+1)); echo "  ✗ $ad (rc=$rc, beklenen=$bek)"; printf '%s\n' "$out" | sed 's/^/      /' | head -12; fi
}

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# ── FIXTURE ÜRETİMİ (fail-loud; hedefi önce sil — bayat fixture sessizce kullanılmasın) ──
# Taşıdığı tuzak: bir oda sınırı + odanın İÇİNDE ayrı katmanda bir mobilya dikdörtgeni.
# Mobilya sınıra girerse oda alanı küçülür — kusurun ta kendisi.
rm -f "$T/ents.json" "$T/dogru.json" "$T/mutant.json" "$T/eksik.json"
node --input-type=module -e '
import { writeFileSync } from "fs";
const T = process.argv[1];
const dikd = (x0,y0,x1,y1) => [{x:x0,y:y0},{x:x1,y:y0},{x:x1,y:y1},{x:x0,y:y1}];
writeFileSync(T+"/ents.json", JSON.stringify([
  { tur:"poly",  katman:"duvar_x",   koseler: dikd(0,0,500,400),     kapali:true },   // oda 20 m²
  { tur:"poly",  katman:"mobilya_x", koseler: dikd(50,50,110,230),   kapali:true },   // koltuk 1.08 m²
  { tur:"metin", katman:"TEXT",      metin:"ODA", x:250, y:200 },
]));
const taban = { ad:"t", surum:"1.0",
  rol_kumesi:["duvar","kolon","aciklik","mobilya","not","yok-say"],
  sinir_rolleri:["duvar","kolon","aciklik"],
  kapi:{ beyan_zorunlu:true },
  roller:{ duvar_x:"duvar", mobilya_x:"mobilya", TEXT:"not" } };
writeFileSync(T+"/dogru.json", JSON.stringify(taban));
const mut = structuredClone(taban); mut.roller.mobilya_x = "duvar";        // MUTASYON
writeFileSync(T+"/mutant.json", JSON.stringify(mut));
const eksik = structuredClone(taban); delete eksik.roller.mobilya_x;        // BEYANSIZ
writeFileSync(T+"/eksik.json", JSON.stringify(eksik));
' "$T" || { echo "✗ fixture üretilemedi — sessiz geçilmez"; exit 1; }
for f in ents dogru mutant eksik; do
  [ -s "$T/$f.json" ] || { echo "✗ fixture BOŞ: $f.json"; exit 1; }
done

# yardımcı: sınır kümesini bas (rol-dosyası argümanla)
cat > "$T/olc.mjs" <<'MJS'
import { readFileSync } from "fs";
const { rolleriYukle, katmanlariCoz } = await import(process.env.PAKET + "/lib/katman.mjs");
const ents = JSON.parse(readFileSync(process.argv[3], "utf8"));
const c = katmanlariCoz(ents, rolleriYukle(process.argv[2]));
console.log(c.sinirKatmanlari.sort().join(","));
MJS
export PAKET

echo "── katman rolleri: sınır kümesi VERİDEN gelir ──"

iddia 0 "doğru beyanda mobilya sınıra GİRMEZ (yalnız duvar_x)" \
  bash -c 'out=$(node "$1/olc.mjs" "$1/dogru.json" "$1/ents.json") || exit 1; [ "$out" = "duvar_x" ] || { echo "sınır=$out"; exit 1; }' _ "$T"

iddia 1 "BEYANSIZ katman fail-closed (sessiz varsayım yok)" \
  node "$T/olc.mjs" "$T/eksik.json" "$T/ents.json"

# MUTASYON KANITI: mobilyayı duvar ilan edince sınır kümesi DEĞİŞMELİ — yani bu sınav
# gerçekten veriyi ölçüyor, sabit bir doğruyu tekrarlamıyor (ölü-kapı panzehiri).
iddia 0 "mutasyon (mobilya→duvar) sınır kümesini DEĞİŞTİRİR — sınav veriyi ölçüyor" \
  bash -c '
    a=$(node "$1/olc.mjs" "$1/dogru.json"  "$1/ents.json") || exit 1
    b=$(node "$1/olc.mjs" "$1/mutant.json" "$1/ents.json") || exit 1
    [ "$a" != "$b" ] || { echo "mutasyon fark yaratmadı — sınav ÖLÜ ($a)"; exit 1; }
    case "$b" in *mobilya_x*) : ;; *) echo "mutant sınıra mobilyayı almadı: $b"; exit 1;; esac' _ "$T"

echo "── sevk edilen veri dosyası ──"

iddia 0 "katman-rolleri.json yüklenir ve şeması geçerli" \
  node --input-type=module -e 'const {rolleriYukle}=await import(process.env.PAKET+"/lib/katman.mjs"); rolleriYukle();'

iddia 0 "Zone_Line 'mobilya' beyan edilmiş ve SINIRA girmiyor (kusurun kaynağı kapalı)" \
  node --input-type=module -e '
    const {rolleriYukle,sinirKatmanlari}=await import(process.env.PAKET+"/lib/katman.mjs");
    const r=rolleriYukle();
    if (r.roller["Zone_Line"]!=="mobilya") { console.error("Zone_Line rolü: "+r.roller["Zone_Line"]); process.exit(1); }
    if (sinirKatmanlari(r).includes("Zone_Line")) { console.error("Zone_Line SINIRA girmiş"); process.exit(1); }
  '

# Kapsam: ÖLÇÜM hattı (sınır üreten yollar). `lib/cad-render.mjs`in SIRA/BICIM listeleri
# ÇİZİM SIRASI ve stildir — orada katman adı bulunması meşrudur, ölçümü etkilemez.
iddia 0 "ölçüm hattında sabit sınır listesi KALMADI (tek kaynak: veri)" \
  bash -c '! grep -nE "px_walls.{0,80}Zone_Line" cli.mjs lib/cad-cikar.mjs 2>/dev/null | grep -vE "^[^:]+:[0-9]+: *(//|\*)" | grep .'

echo
echo "GEÇTİ=$GECTI KALDI=$KALDI"
[ "$KALDI" = 0 ] && { echo "SONUC: GECTI"; exit 0; } || { echo "SONUC: KALDI"; exit 1; }
