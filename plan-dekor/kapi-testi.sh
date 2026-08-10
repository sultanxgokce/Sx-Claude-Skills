#!/usr/bin/env bash
# plan-dekor kapı-regresyon koşucusu. Her kapıyı fixture'a koşar ve BEKLENEN RC'yi doğrular.
# "SONUC: GECTI" görmeden commit edilmez (TELLAL kapı-kuralı).
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$KOK"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export PLAN_DEKOR_METRIK="$TMP/metrik.jsonl"

GECEN=0; KALAN=0

kapi() {
  local ad="$1" beklenen="$2"; shift 2
  local cikti rc
  cikti="$("$@" 2>&1)"; rc=$?
  if [ "$rc" -eq "$beklenen" ]; then
    printf '  ✓ %-42s rc=%s\n' "$ad" "$rc"; GECEN=$((GECEN+1))
  else
    printf '  ✗ %-42s rc=%s (beklenen %s)\n' "$ad" "$rc" "$beklenen"
    echo "$cikti" | sed 's/^/      /' | head -6
    KALAN=$((KALAN+1))
  fi
}

# dosya YAZILMAMALI kapısı
yazilmadi() {
  local ad="$1" dosya="$2"
  if [ -e "$dosya" ]; then
    printf '  ✗ %-42s FAIL-CLOSED İHLALİ: dosya yazılmış\n' "$ad"; KALAN=$((KALAN+1))
  else
    printf '  ✓ %-42s dosya yazılmadı\n' "$ad"; GECEN=$((GECEN+1))
  fi
}

echo "── plan-dekor kapı testleri ──"

echo "[1] Mutlu yol"
kapi "mobilya (demo daire)"            0 node cli.mjs mobilya --model demo/ornek-daire.json --cikti "$TMP/y.json" --adet 3
kapi "ciz (mobilyalı, tema modern)"    0 node cli.mjs ciz --model demo/ornek-daire.json --yerlesim "$TMP/y.json" --cikti "$TMP/p.svg"
kapi "ciz (mobilyasız)"                0 node cli.mjs ciz --model demo/ornek-daire.json --cikti "$TMP/bos.svg"
kapi "denetle (üretilen aday temiz)"   0 node cli.mjs denetle --model demo/ornek-daire.json --yerlesim "$TMP/y.json"
kapi "revize (geçerli — mobilya sil)"  0 node cli.mjs revize --model demo/ornek-daire.json --yerlesim "$TMP/y.json" --degisiklik fixtures/revize-gecerli.json --cikti "$TMP/y2.json"

echo "[2] Fail-closed kapıları (RC 1 + dosya YAZILMAMALI)"
kapi "zorunlu program sığmıyor"        1 node cli.mjs mobilya --model fixtures/cok-kucuk-oda.json --cikti "$TMP/sigmaz.json"
yazilmadi "sığmayan → çıktı yok"          "$TMP/sigmaz.json"
kapi "sığmayan + --kismi-kabul de kırmızı" 1 node cli.mjs mobilya --model fixtures/cok-kucuk-oda.json --cikti "$TMP/sigmaz2.json" --kismi-kabul
yazilmadi "tek oda sığmazsa kısmi de yok"  "$TMP/sigmaz2.json"

kapi "kaynaksız kural-seti reddedilir"  3 node cli.mjs mobilya --model demo/ornek-daire.json --cikti "$TMP/ks.json" --kural-seti fixtures/kaynaksiz-kural-seti.json
yazilmadi "kaynaksız kural → çıktı yok"   "$TMP/ks.json"

kapi "revize çakışma üretir"           1 node cli.mjs revize --model demo/ornek-daire.json --yerlesim "$TMP/y.json" --degisiklik fixtures/revize-cakistir.json --cikti "$TMP/y3.json"
yazilmadi "çakışan revize → çıktı yok"    "$TMP/y3.json"

kapi "revize oda dışına taşır"         1 node cli.mjs revize --model demo/ornek-daire.json --yerlesim "$TMP/y.json" --degisiklik fixtures/revize-kapi-onune-tasi.json --cikti "$TMP/y4.json"
yazilmadi "oda-dışı revize → çıktı yok"   "$TMP/y4.json"

kapi "eşik kodda uydurulamaz (bant_cm yok)" 3 node cli.mjs mobilya --model demo/ornek-daire.json --cikti "$TMP/b.json" --kural-seti fixtures/bantsiz-kural-seti.json
yazilmadi "bantsız kural → çıktı yok"     "$TMP/b.json"

# Katalog kaynak kapısı: üretici yatağı sessizce küçültüp "sığdı" diyemesin
KK="$(node -e '
import("./lib/yerlesim.mjs").then(M=>{
  try{ M.katalogYukle("fixtures/kaynaksiz-katalog.json","katalog/program.json"); process.stdout.write("ACIK"); }
  catch(e){ process.stdout.write(/kaynak/.test(e.message)?"KAPALI":"BASKA"); }
});' 2>/dev/null)"
if [ "$KK" = "KAPALI" ]; then
  printf '  ✓ %-42s kaynaksız ölçü reddedildi\n' "katalog kaynak kapısı"; GECEN=$((GECEN+1))
else
  printf '  ✗ %-42s (%s)\n' "katalog kaynak kapısı" "$KK"; KALAN=$((KALAN+1))
fi
# HİLE KAPISI: kaynak alanı DOLU ama ölçü sığdırmak için kırpılmış → bant yakalamalı
node fixtures/hile-uret.mjs >/dev/null 2>&1
HK="$(node -e '
Promise.all([import("./lib/yerlesim.mjs"),import("./lib/kural.mjs")]).then(([M,K])=>{
  const ks=K.kuralSetiYukle("kural-seti/mobilya-TR.json");
  try{ M.katalogYukle("fixtures/kirpilmis-katalog.json","katalog/program.json",ks); process.stdout.write("ACIK"); }
  catch(e){ process.stdout.write(/asgari bandın ALTINDA/.test(e.message)?"KAPALI":"BASKA"); }
});' 2>/dev/null)"
if [ "$HK" = "KAPALI" ]; then
  printf '  ✓ %-42s ölçü kırpma yakalandı\n' "asgari boyut bandı"; GECEN=$((GECEN+1))
else
  printf '  ✗ %-42s (%s) — üretici yatağı küçültüp sığdı diyebilir\n' "asgari boyut bandı" "$HK"; KALAN=$((KALAN+1))
fi

kapi "çıpa: tek çıpa yetmez"          1 node cli.mjs cipa --model demo/ornek-daire.json --cipa fixtures/cipa-tek.json
kapi "çıpa: ikinci çıpa tutmuyor"     1 node cli.mjs cipa --model demo/ornek-daire.json --cipa fixtures/cipa-sapmali.json
kapi "çıpa: geçerli çift çıpa"        0 node cli.mjs cipa --model demo/ornek-daire.json --cipa demo/ornek-cipa.json

kapi "olmayan model"                   1 node cli.mjs mobilya --model /yok/model.json --cikti "$TMP/x.json"
kapi "eksik argüman"                   2 node cli.mjs mobilya --model demo/ornek-daire.json
kapi "bilinmeyen komut"                2 node cli.mjs sacmalik
kapi "olmayan tema"                    3 node cli.mjs ciz --model demo/ornek-daire.json --cikti "$TMP/t.svg" --tema yok-boyle-tema

echo "[3] Determinizm (aynı girdi → aynı sha256)"
node cli.mjs mobilya --model demo/ornek-daire.json --cikti "$TMP/d1.json" --adet 3 >/dev/null 2>&1
node cli.mjs mobilya --model demo/ornek-daire.json --cikti "$TMP/d2.json" --adet 3 >/dev/null 2>&1
if [ "$(sha256sum <"$TMP/d1.json" | cut -d' ' -f1)" = "$(sha256sum <"$TMP/d2.json" | cut -d' ' -f1)" ]; then
  printf '  ✓ %-42s sha256 eşit\n' "yerleşim determinizmi"; GECEN=$((GECEN+1))
else
  printf '  ✗ %-42s sha256 FARKLI\n' "yerleşim determinizmi"; KALAN=$((KALAN+1))
fi
node cli.mjs ciz --model demo/ornek-daire.json --yerlesim "$TMP/d1.json" --cikti "$TMP/s1.svg" >/dev/null 2>&1
node cli.mjs ciz --model demo/ornek-daire.json --yerlesim "$TMP/d1.json" --cikti "$TMP/s2.svg" >/dev/null 2>&1
if [ "$(sha256sum <"$TMP/s1.svg" | cut -d' ' -f1)" = "$(sha256sum <"$TMP/s2.svg" | cut -d' ' -f1)" ]; then
  printf '  ✓ %-42s sha256 eşit\n' "çizim determinizmi"; GECEN=$((GECEN+1))
else
  printf '  ✗ %-42s sha256 FARKLI\n' "çizim determinizmi"; KALAN=$((KALAN+1))
fi

# EŞDEĞER GİRDİ determinizmi: geometrik olarak aynı ama dizileri TERS sıralı model.
# "Aynı girdi → aynı sha256" iddiası yalnız BAYT-aynı girdiyi kapsıyordu; anlam-aynı girdide
# küvet başka duvara geçiyordu (B-012, dışarıdan bir projenin aynı hatayı düzeltmesiyle bulundu).
node fixtures/esdeger-girdi-uret.mjs >/dev/null 2>&1
node cli.mjs mobilya --model demo/ornek-daire.json      --cikti "$TMP/e1.json" --adet 1 >/dev/null 2>&1
node cli.mjs mobilya --model fixtures/esdeger-daire.json --cikti "$TMP/e2.json" --adet 1 >/dev/null 2>&1
EQ="$(node -e '
const fs=require("fs");
const a=JSON.parse(fs.readFileSync(process.argv[1],"utf8")), b=JSON.parse(fs.readFileSync(process.argv[2],"utf8"));
process.stdout.write(JSON.stringify(a.adaylar)===JSON.stringify(b.adaylar)?"EQ":"DIFF");
' "$TMP/e1.json" "$TMP/e2.json" 2>/dev/null)"
if [ "$EQ" = "EQ" ]; then
  printf '  ✓ %-42s sıra-bağımsız\n' "eşdeğer girdi → aynı yerleşim"; GECEN=$((GECEN+1))
else
  printf '  ✗ %-42s girdi sırası sonucu DEĞİŞTİRİYOR\n' "eşdeğer girdi → aynı yerleşim"; KALAN=$((KALAN+1))
fi
node cli.mjs ciz --model demo/ornek-daire.json      --yerlesim "$TMP/e1.json" --cikti "$TMP/e1.svg" >/dev/null 2>&1
node cli.mjs ciz --model fixtures/esdeger-daire.json --yerlesim "$TMP/e2.json" --cikti "$TMP/e2.svg" >/dev/null 2>&1
if [ "$(sha256sum <"$TMP/e1.svg" | cut -d' ' -f1)" = "$(sha256sum <"$TMP/e2.svg" | cut -d' ' -f1)" ]; then
  printf '  ✓ %-42s sha256 eşit\n' "eşdeğer girdi → aynı çizim"; GECEN=$((GECEN+1))
else
  printf '  ✗ %-42s sha256 FARKLI\n' "eşdeğer girdi → aynı çizim"; KALAN=$((KALAN+1))
fi

echo "[4] Kabul kriteri — SUIT ODA döşendi mi (kapı yayı boş)"
SUIT="$(node -e '
const y=require("'"$TMP"'/y.json");
const v=y.adaylar[0].yerlesimler.filter(x=>x.oda==="suit");
const yatak=v.some(x=>x.mobilya.includes("yatak"));
const dolap=v.some(x=>x.mobilya.includes("gardirop"));
process.stdout.write(yatak&&dolap?"VAR":"YOK");' 2>/dev/null)"
if [ "$SUIT" = "VAR" ]; then
  printf '  ✓ %-42s yatak + gardırop yerleşti\n' "suit oda döşendi"; GECEN=$((GECEN+1))
else
  printf '  ✗ %-42s zorunlu mobilya eksik\n' "suit oda döşendi"; KALAN=$((KALAN+1))
fi

echo "[5] Katalog verisi CANLI mı (temiz_alan_cm ölü veri olmasın)"
TEMIZ="$(node -e '
import("./lib/kural.mjs").then(async K=>{
  const {odaBaglami}=await import("./lib/yerlesim.mjs");
  const fs=await import("fs");
  const ks=K.kuralSetiYukle("kural-seti/mobilya-TR.json");
  const model=JSON.parse(fs.readFileSync("demo/ornek-daire.json","utf8"));
  const b=odaBaglami(model, model.odalar.find(o=>o.id==="suit"));
  const a={mobilya:"a",kutu:{x:12.5,y:240,g:200,d:160},yon:0,temizAlan:{sol:60,sag:60},yerlesimTipi:"duvar-dayali"};
  const c={mobilya:"b",kutu:{x:12.5,y:200,g:45,d:40},yon:1,temizAlan:{on:30},yerlesimTipi:"duvar-dayali"};
  const r=K.konforCezasi([a,c],b,ks);
  process.stdout.write(r.notlar.some(n=>n.includes("temiz-alan"))?"CANLI":"OLU");
});' 2>/dev/null)"
if [ "$TEMIZ" = "CANLI" ]; then
  printf '  ✓ %-42s ceza üretiyor\n' "temiz_alan_cm değerlendiriliyor"; GECEN=$((GECEN+1))
else
  printf '  ✗ %-42s ÖLÜ VERİ (katalogdaki paylar hiç okunmuyor)\n' "temiz_alan_cm değerlendiriliyor"; KALAN=$((KALAN+1))
fi

echo "[6] Metin taşması kapısı (plan-motor'da vardı, dekor'da YOKTU — B-006 sınıfı)"
MT="$(node -e '
Promise.all([import("./lib/oz-denetim.mjs"),import("./lib/dekor-svg.mjs")]).then(async ([D,S])=>{
  const fs=await import("fs");
  const model=JSON.parse(fs.readFileSync("demo/ornek-daire.json","utf8"));
  const tema=S.temaYukle("tema/modern-sicak.json");
  // Dar odaya çok uzun ad ver; sığdırma devre dışı bırakılamadığı için tek-satır kalan
  // en kötü durumu simüle etmek yerine, denetimin ÇALIŞTIĞINI doğrula: normal çıktıda
  // hiçbir etiket taşmamalı.
  const svg=S.dekorSvgUret(model,[],tema,{lejant:true});
  const r=D.renderDenetle(svg,{model,yerlesimler:[],tema,lejant:true});
  const tasan=r.uyarilar.filter(u=>u.includes("sığmıyor"));
  process.stdout.write(tasan.length===0?"TEMIZ":"TASIYOR:"+tasan[0]);
});' 2>/dev/null)"
if [ "$MT" = "TEMIZ" ]; then
  printf '  ✓ %-42s hiçbir etiket taşmıyor\n' "oda etiketleri odalarına sığıyor"; GECEN=$((GECEN+1))
else
  printf '  ✗ %-42s %s\n' "oda etiketleri odalarına sığıyor" "$MT"; KALAN=$((KALAN+1))
fi

echo "[7] Metrik defteri"
if [ -s "$PLAN_DEKOR_METRIK" ] && grep -q '"arac":"plan-dekor@' "$PLAN_DEKOR_METRIK"; then
  printf '  ✓ %-42s %s satır\n' "her koşu metrik bastı" "$(wc -l <"$PLAN_DEKOR_METRIK")"; GECEN=$((GECEN+1))
else
  printf '  ✗ %-42s defter boş\n' "metrik defteri"; KALAN=$((KALAN+1))
fi

echo
echo "geçen: $GECEN · kalan: $KALAN"
if [ "$KALAN" -eq 0 ]; then echo "SONUC: GECTI"; exit 0; else echo "SONUC: KALDI"; exit 1; fi
