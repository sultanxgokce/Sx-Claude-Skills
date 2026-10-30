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

# ── SINAV-KAYNAK BAĞIMSIZLIĞI (fixture tazeliği + anlamı) ──────────────────────
# İki fixture her koşuda CANLI kaynaktan yeniden üretiliyor:
#   fixtures/kirpilmis-katalog.json ← katalog/mobilya.json
#   fixtures/esdeger-daire.json     ← demo/ornek-daire.json
# Üreteçler `>/dev/null 2>&1` ile çağrıldığından ÖLÜMLERİ SESSİZDİ: canlı kaynak
# üretecin varsayımını bozacak şekilde değişince üreteç çöküyor, diskteki BAYAT
# fixture kullanılmaya devam ediyor ve kapı YEŞİL kalıyordu.
#
# ÖLÇÜLDÜ (2026-08-11): canlı katalogda `cift-yatak-160` id'si yeniden adlandırılıp
# ölçü 140×190'a kırpıldı (bant id-anahtarlı olduğu için `if (!asgari) continue`
# ile atlandı) → `node fixtures/hile-uret.mjs` RC=1 ile çöktü, fixture sha256'sı
# 84d4994… olarak DEĞİŞMEDİ, süit "geçen: 36 · kalan: 0 · SONUC: GECTI" bastı.
# Yani üretici `tests/` klasörüne hiç dokunmadan sınavı hayalet bir id'yi sınar
# hâle getirdi. Delik gerçekti.
#
# KAPI İKİ KATLI:
#  1) fixture_uret — fixture ÖNCE silinir; üreteç RC=0 vermek ZORUNDA ve dosyayı
#     YAZMIŞ olmak zorunda. Bayat dosyanın hayatta kalma yolu yok.
#  2) anlam_iddiasi — fixture'ın TAŞIDIĞI TUZAK ölçülür (kaynak meşru biçimde
#     değişse de sınavın anlamı korunur). Sabit id/sayı gömülmez; her şey canlı
#     kaynak + kural-setinden TÜRETİLİR.

# 1) TAZELİK: üreteci fail-loud koştur (bayat fixture'a hayat hakkı yok)
fixture_uret() {
  local ad="$1" uretec="$2" hedef="$3"
  rm -f "$hedef"
  local cikti rc
  cikti="$(node "$uretec" 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ] || [ ! -s "$hedef" ]; then
    printf '  ✗ %-42s üreteç rc=%s → BAYAT fixture kullanılamaz\n' "$ad" "$rc"
    echo "$cikti" | sed 's/^/      /' | head -6
    KALAN=$((KALAN+1)); return 1
  fi
  printf '  ✓ %-42s taze üretildi\n' "$ad"; GECEN=$((GECEN+1)); return 0
}

# 2) ANLAM: fixture gerçekten tuzağı taşıyor mu? (beklenen tek sözcük: TAMAM)
anlam_iddiasi() {
  local ad="$1" kod="$2" gerek="${3:-}"
  if [ -n "$gerek" ] && [ ! -s "$gerek" ]; then
    printf '  ✗ %-42s fixture YOK (üreteç çökmüş) — anlam sınanamaz\n' "$ad"; KALAN=$((KALAN+1)); return
  fi
  local got
  got="$(node -e "$kod" 2>&1 | tail -1)"
  if [ "$got" = "TAMAM" ]; then
    printf '  ✓ %-42s fixture tuzağı taşıyor\n' "$ad"; GECEN=$((GECEN+1))
  else
    printf '  ✗ %-42s %s\n' "$ad" "$got"; KALAN=$((KALAN+1))
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
fixture_uret "hile fixture tazeliği" fixtures/hile-uret.mjs fixtures/kirpilmis-katalog.json
# ANLAM: fixture'daki kırpma GERÇEK mi, HAYALET mi? Sabit id gömmeden TÜRETİLİR:
#  · bandın altına düşen ≥1 kalem OLMALI (yoksa sınav boş)
#  · o kalem CANLI katalogda da bulunmalı (hayalet id sınanamaz)
#  · canlı katalogda o kalem bandın ÜSTÜNDE olmalı (kırpmayı fixture yapmalı, kaynak değil)
anlam_iddiasi "hile fixture'ı gerçekten kırpıyor" '
const fs=require("fs");
const J=p=>JSON.parse(fs.readFileSync(p,"utf8"));
const bant=J("kural-seti/mobilya-TR.json").katalog_bandi.asgari_boyut_cm;
const canli=new Map(J("katalog/mobilya.json").mobilyalar.map(x=>[x.id,x.boyut_cm]));
const fx=J("fixtures/kirpilmis-katalog.json").mobilyalar;
const alti=(b,a)=>b[0]<a[0]||b[1]<a[1];
const kirpik=fx.filter(x=>bant[x.id]&&alti(x.boyut_cm,bant[x.id]));
if(!kirpik.length){console.log("BOŞ SINAV: fixture içinde bandın altında kalem YOK");process.exit(0);}
for(const x of kirpik){
  const c=canli.get(x.id);
  if(!c){console.log(`HAYALET: ${x.id} canlı katalogda YOK`);process.exit(0);}
  if(alti(c,bant[x.id])){console.log(`KAYNAK ZATEN KIRPIK: ${x.id} canlıda ${c} < ${bant[x.id]}`);process.exit(0);}
}
console.log("TAMAM");' fixtures/kirpilmis-katalog.json
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
fixture_uret "eşdeğer fixture tazeliği" fixtures/esdeger-girdi-uret.mjs fixtures/esdeger-daire.json
# ANLAM: fixture GERÇEKTEN ters sıralı mı, yoksa kaynağın kopyası mı? Kopyaysa bu
# kapı kendini kendisiyle kıyaslar ve HİÇBİR ŞEY sınamaz (boş yeşil).
#  · duvarlar/odalar/açıklıklar/noktalar-anahtarları tam TERS olmalı
#  · her dizi >1 uzunlukta olmalı (1'lik dizinin tersi kendisidir → tuzak yok)
#  · geometri BİREBİR aynı olmalı (küme olarak), yoksa determinizm değil başka şey ölçülür
anlam_iddiasi "eşdeğer fixture gerçekten ters sıralı" '
const fs=require("fs");
const J=p=>JSON.parse(fs.readFileSync(p,"utf8"));
const a=J("demo/ornek-daire.json"), b=J("fixtures/esdeger-daire.json");
const S=x=>JSON.stringify(x);
for(const alan of ["duvarlar","odalar","acikliklar"]){
  const A=a[alan]||[], B=b[alan]||[];
  if(A.length<2){console.log(`TUZAK YOK: ${alan} uzunluğu ${A.length} — tersi kendisi`);process.exit(0);}
  if(S(B)!==S([...A].reverse())){console.log(`TERS DEĞİL: ${alan}`);process.exit(0);}
  const kume=L=>S(L.map(S).sort());   // eleman-JSON string olarak sırala (obje sort no-op olur)
  if(kume(A)!==kume(B)){console.log(`GEOMETRİ FARKLI: ${alan}`);process.exit(0);}
}
const na=Object.keys(a.noktalar), nb=Object.keys(b.noktalar);
if(na.length<2){console.log("TUZAK YOK: noktalar tek anahtar");process.exit(0);}
if(S(nb)!==S([...na].reverse())){console.log("TERS DEĞİL: noktalar anahtar sırası");process.exit(0);}
if(na.some(k=>S(a.noktalar[k])!==S(b.noktalar[k]))){console.log("GEOMETRİ FARKLI: nokta koordinatı");process.exit(0);}
if(a.ad!==b.ad){console.log("AD FARKLI: SVG başlığı determinizme girer");process.exit(0);}
console.log("TAMAM");' fixtures/esdeger-daire.json
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

echo "[8] Daire-ölçeği program kısıtları (D033/D034/D035 — oda temiz ≠ daire doğru)"
# Kapılar VERİYİ okur, sayı/mobilya adı BİLMEZ: katalog büyüdükçe kapı kendiliğinden genişler.
DK="$(node -e '
const fs=require("fs"), y=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const prog=JSON.parse(fs.readFileSync("katalog/program.json","utf8"));
const kat=JSON.parse(fs.readFileSync("katalog/mobilya.json","utf8"));
const model=JSON.parse(fs.readFileSync("demo/ornek-daire.json","utf8"));
const kis=prog.daire_kisitlari||{};
const tekil=kis.daire_tekil||[], bantlar=(kis.opsiyonel_butcesi||{}).bantlar||[];
const m2={}; for(const o of model.odalar) m2[o.id]=o.alan_m2 ?? o.alan ?? null;
const tipi={}; for(const o of model.odalar) tipi[o.id]=o.tip;
const zor=new Set(); for(const t of Object.keys(prog.programlar||{}))
  for(const z of (prog.programlar[t].zorunlu||[])) zor.add(t+"|"+z.mobilya);
const hata=[];
for(const aday of y.adaylar){
  const yer=aday.yerlesimler;
  // (a) daire-tekillik: listedeki mobilya dairede EN ÇOK 1 — "hiç"i de yakalamak için,
  //     bir odanın programında geçiyorsa TAM 1 beklenir (devir çalışmazsa 0 olurdu).
  for(const id of tekil){
    const n=yer.filter(v=>v.mobilya===id).length;
    const programda=Object.values(prog.programlar||{}).some(p=>
      [...(p.zorunlu||[]),...(p.opsiyonel||[])].some(x=>x.mobilya===id));
    if(n>1) hata.push(`daire-tekil ihlali: ${id} ×${n}`);
    else if(programda && n===0) hata.push(`devir kirik: ${id} programda var ama dairede 0`);
  }
  // (b) m2-bagli opsiyonel tavani: ZORUNLULAR sayilmaz.
  const say={}; for(const v of yer){ const k=tipi[v.oda]+"|"+v.mobilya;
    if(!zor.has(k)) say[v.oda]=(say[v.oda]||0)+1; }
  for(const oda of Object.keys(say)){
    const a=m2[oda]; if(a==null) continue;
    const b=bantlar.find(x=>a<=x.azami_m2);
    if(b && say[oda]>b.azami_opsiyonel)
      hata.push(`opsiyonel tavani: ${oda} ${a}m2 -> ${say[oda]} > ${b.azami_opsiyonel}`);
  }
}
process.stdout.write(hata.length?hata.slice(0,3).join(" | "):"TEMIZ");
' "$TMP/y.json" 2>&1)"
if [ "$DK" = "TEMIZ" ]; then
  printf '  ✓ %-42s tekillik+devir+tavan\n' "daire-ölçeği kısıtları (3 adayda)"; GECEN=$((GECEN+1))
else
  printf '  ✗ %-42s %s\n' "daire-ölçeği kısıtları" "$DK"; KALAN=$((KALAN+1))
fi

# Kısıt verisi CANLI mı: blok boşsa kapı sessizce hiçbir şey ölçmez (ölü-kapı panzehiri).
CANLI="$(node -e '
const p=require("./katalog/program.json").daire_kisitlari||{};
const t=(p.daire_tekil||[]).length, b=((p.opsiyonel_butcesi||{}).bantlar||[]).length;
process.stdout.write(t>0&&b>0?"CANLI":`OLU (tekil=${t} bant=${b})`);
' 2>&1)"
if [ "$CANLI" = "CANLI" ]; then
  printf '  ✓ %-42s veri dolu\n' "daire_kisitlari ölü değil"; GECEN=$((GECEN+1))
else
  printf '  ✗ %-42s %s\n' "daire_kisitlari ölü değil" "$CANLI"; KALAN=$((KALAN+1))
fi

# ── SESSİZ DÜŞÜRME YASAK: tekillik kararı raporlanmalı ─────────────────────────
# 🔴 Müşteri bulgusu 2026-08-13, İKİNCİ tekrar: iki teslim üst üste "mutfak boş kalmış,
# masa salona konmuş" dendi. Kural doğru çalışıyordu ama KARARINI söylemiyordu; kimse
# neden boş olduğunu göremedi. Düşürme bir karardır — çıktıda adıyla görünmeli.
# "$TMP/y.json" yukarıdaki daire-ölçeği koşusunun çıktısıdır (aynı fixture, ek iddia).
DUS="$(node -e '
const y=require(process.argv[1]);
const d=y.tekil_dusenler;
if(!Array.isArray(d)) { process.stdout.write("ALAN YOK"); process.exit(0); }
if(d.length===0) { process.stdout.write("BOS — bu fixture tekillik dusurmesi icermiyor, kapi olu"); process.exit(0); }
const eksik=d.filter(x=>!x.oda||!x.mobilya||!x.gerekce);
process.stdout.write(eksik.length?`ALAN EKSIK: ${JSON.stringify(eksik[0])}`:"TEMIZ");
' "$TMP/y.json" 2>&1)"
if [ "$DUS" = "TEMIZ" ]; then
  printf '  ✓ %-42s düşürme adıyla raporlandı\n' "sessiz düşürme yok (tekillik)"; GECEN=$((GECEN+1))
else
  printf '  ✗ %-42s %s\n' "sessiz düşürme yok (tekillik)" "$DUS"; KALAN=$((KALAN+1))
fi

# ── KUZEY OKU: beyan YOKSA çizilmez (uydurma iddia kapısı) ─────────────────────
# 🔴 Eskiden ok KOŞULSUZ basılıyordu, hep yukarı — modelde kuzey alanı olmadığı hâlde.
# Kuru koşuda yakalandı (2026-08-13): her plan "kuzey yukarıdadır" diye asılsız bir iddia
# taşıyordu. Emlak sunum planında yön alıcının güvendiği bilgidir.
KZ="$TMP/kuzey"; mkdir -p "$KZ"
node -e '
const fs=require("fs");
const m=JSON.parse(fs.readFileSync("demo/ornek-daire.json","utf8"));
delete m.kuzey_azimut; fs.writeFileSync(process.argv[1]+"/beyansiz.json",JSON.stringify(m));
m.kuzey_azimut=35;     fs.writeFileSync(process.argv[1]+"/beyanli.json",JSON.stringify(m));
' "$KZ" 2>/dev/null || node -e '
const fs=require("fs");
const aday=fs.readdirSync("demo").filter(f=>f.endsWith(".json"));
let m=null;
for (const f of aday) { const j=JSON.parse(fs.readFileSync("demo/"+f,"utf8")); if (j.odalar&&j.noktalar) { m=j; break; } }
if (!m) { console.error("model fixture bulunamadi"); process.exit(1); }
delete m.kuzey_azimut; fs.writeFileSync(process.argv[1]+"/beyansiz.json",JSON.stringify(m));
m.kuzey_azimut=35;     fs.writeFileSync(process.argv[1]+"/beyanli.json",JSON.stringify(m));
' "$KZ"
[ -s "$KZ/beyansiz.json" ] || { echo "  ✗ kuzey fixture üretilemedi"; KALAN=$((KALAN+1)); }

node cli.mjs ciz --model "$KZ/beyansiz.json" --cikti "$KZ/beyansiz.svg" >/dev/null 2>&1
node cli.mjs ciz --model "$KZ/beyanli.json"  --cikti "$KZ/beyanli.svg"  >/dev/null 2>&1
if [ -s "$KZ/beyansiz.svg" ] && ! grep -q '>K</text>' "$KZ/beyansiz.svg"; then
  printf '  ✓ %-42s beyansız modelde ok YOK\n' "kuzey oku uydurulmuyor"; GECEN=$((GECEN+1))
else
  printf '  ✗ %-42s beyan yokken kuzey oku BASILMIŞ\n' "kuzey oku uydurulmuyor"; KALAN=$((KALAN+1))
fi
# Karşı-kanıt: beyan VARSA ok çizilmeli — yoksa kapı "hep yok" diyerek ölü yeşil verirdi.
if [ -s "$KZ/beyanli.svg" ] && grep -q '>K</text>' "$KZ/beyanli.svg" && grep -q 'rotate(35' "$KZ/beyanli.svg"; then
  printf '  ✓ %-42s beyanlı modelde ok VAR + açı uygulanmış\n' "kuzey beyanı çizime yansıyor"; GECEN=$((GECEN+1))
else
  printf '  ✗ %-42s beyan varken ok/açı yok (kapı ölü olurdu)\n' "kuzey beyanı çizime yansıyor"; KALAN=$((KALAN+1))
fi

# ── ODA ETİKETİ ODANIN İÇİNDE (U/L biçimli oda) ────────────────────────────────
# 🔴 Kuru koşu bulgusu 2026-08-13: SUIT ODA ebeveyn banyoyu saran U biçimindeydi; ağırlık
# merkezi banyonun içine düştü ve etiket ekranda "UIT ODA" diye kırpık göründü.
# Bu iddia ÖNCE tuzağın gerçekten var olduğunu kanıtlar (merkez DIŞARIDA), sonra çareyi ölçer.
ETK="$(node --input-type=module -e '
const { agirlikMerkezi, noktaIcinde, icNokta } = await import("./lib/geo.mjs");
// U: (0,0)-(600,400), üstten ortada (200,150)-(400,400) oyuk
const u = [[0,0],[600,0],[600,400],[400,400],[400,150],[200,150],[200,400],[0,400]];
const merkez = agirlikMerkezi(u);
const ic = icNokta(u);
const tuzak = !noktaIcinde(merkez, u);        // merkez DIŞARIDA olmalı — yoksa sınav ölü
const care  = noktaIcinde(ic, u);             // çare İÇERİDE nokta vermeli
const ic2 = icNokta(u);
const kararli = ic[0] === ic2[0] && ic[1] === ic2[1];   // determinizm
process.stdout.write(`${tuzak}|${care}|${kararli}`);
' 2>&1)"
case "$ETK" in
  true\|true\|true) printf '  ✓ %-42s U odada etiket içeride + kararlı\n' "oda etiketi odanın içinde"; GECEN=$((GECEN+1)) ;;
  *) printf '  ✗ %-42s tuzak|care|kararli = %s\n' "oda etiketi odanın içinde" "$ETK"; KALAN=$((KALAN+1)) ;;
esac

# ── PUANLAYAN-AJANIN 4 AÇIĞI (2026-08-13 · PUANLAYAN-IS-001.md) ────────────────
# "Bir kapı, kırmızıya dönmediği sürece kapı değildir."
PA="$TMP/pa"; mkdir -p "$PA"
node --input-type=module -e '
import { readFileSync, writeFileSync } from "fs";
const PA = process.argv[1];
const m = JSON.parse(readFileSync("demo/ornek-daire.json", "utf8"));
writeFileSync(PA + "/acikliksiz.json", JSON.stringify({ ...m, acikliklar: [] }));
' "$PA"

# (D) TESLİM YOLU: açıklıksız model sunum planı olarak teslim EDİLEMEZ.
node cli.mjs mobilya --model "$PA/acikliksiz.json" --cikti "$PA/y.json" --adet 1 >/dev/null 2>&1
kapi "açıklıksız model TESLİM edilemez"        1 node cli.mjs ciz --model "$PA/acikliksiz.json" --yerlesim "$PA/y.json" --cikti "$PA/a.svg" --teslim
yazilmadi "teslim reddinde dosya yazılmadı"      "$PA/a.svg"
# Karşı-kanıt: aynı model TESLİM BAYRAĞI OLMADAN çizilebilmeli — yoksa kapı iç koşuyu da keser.
kapi "aynı model iç koşuda çizilebilir"        0 node cli.mjs ciz --model "$PA/acikliksiz.json" --yerlesim "$PA/y.json" --cikti "$PA/b.svg"
# Karşı-kanıt 2: açıklığı OLAN model teslim kipinden GEÇMELİ (kapı "hep kırmızı" olmasın).
node cli.mjs mobilya --model demo/ornek-daire.json --cikti "$PA/y2.json" --adet 1 >/dev/null 2>&1
kapi "açıklıklı model teslim kipinden geçer"   0 node cli.mjs ciz --model demo/ornek-daire.json --yerlesim "$PA/y2.json" --cikti "$PA/c.svg" --teslim

# (A) ETİKET ↔ MOBİLYA çakışması HATA'dır (uyarı değil) — müşterinin gördüğü kusur teslim olmaz.
# (B) Genişlik kestirimi TEK KAYNAK: ikinci bir KARAKTER_ORANI tanımı kalmamalı.
KOP="$(grep -rn "KARAKTER_ORANI *=" lib/*.mjs | grep -v "^lib/metin-olcu.mjs:" | wc -l)"
if [ "$KOP" = "0" ]; then
  printf '  ✓ %-42s tek kaynak (metin-olcu.mjs)\n' "genişlik kestirimi kopyalanmıyor"; GECEN=$((GECEN+1))
else
  printf '  ✗ %-42s %s ikinci tanım var\n' "genişlik kestirimi kopyalanmıyor" "$KOP"; KALAN=$((KALAN+1))
fi

# Çakışma kapısı GERÇEKTEN ölçüyor mu: etiketi mobilyanın üstüne ZORLA koy → kırmızı olmalı.
CAK="$(node --input-type=module -e '
import { readFileSync } from "fs";
const { renderDenetle } = await import("./lib/oz-denetim.mjs");
const model = JSON.parse(readFileSync("demo/ornek-daire.json","utf8"));
const tema = JSON.parse(readFileSync("tema/modern-sicak.json","utf8"));
const oda = model.odalar[0];
const nk = oda.dongu.map(n => model.noktalar[n]);
const cx = nk.reduce((s,p)=>s+p[0],0)/nk.length, cy = nk.reduce((s,p)=>s+p[1],0)/nk.length;
// Etiket çapasının TAM ÜSTÜNE oturan bir mobilya kutusu uydur.
const yerlesimler = [{ oda: oda.id, mobilya: "sahte", yon: 1, kutu: { x: cx-60, y: cy-40, g: 120, d: 80 }, sembol: "masa" }];
const svg = `<svg viewBox="0 0 10 10"><text x="${cx}" y="${cy}" font-size="20" font-weight="700" data-etiket-oda="${oda.id}">ODA</text></svg>`;
const r = renderDenetle(svg, { model, yerlesimler, tema, lejant: false });
process.stdout.write(r.hatalar.some(h => h.includes("mobilyanın üstüne")) ? "KIRMIZI" : "SESSIZ:" + JSON.stringify(r.hatalar).slice(0,80));
' 2>&1)"
if [ "$CAK" = "KIRMIZI" ]; then
  printf '  ✓ %-42s çakışma HATA veriyor\n' "etiket mobilya üstüne binerse kırmızı"; GECEN=$((GECEN+1))
else
  printf '  ✗ %-42s %s\n' "etiket mobilya üstüne binerse kırmızı" "$CAK"; KALAN=$((KALAN+1))
fi

# (C) TEKİLLİK TERCİHİ VERİDEN: beyan yoksa davranış DEĞİŞMEZ, beyan varsa kazanan DEĞİŞİR.
TER="$(node --input-type=module -e '
import { readFileSync } from "fs";
const { plaMobilyala } = await import("./lib/yerlesim.mjs");
const model = JSON.parse(readFileSync("demo/ornek-daire.json","utf8"));
const paket = { program: JSON.parse(readFileSync("katalog/program.json","utf8")),
                indeks: new Map(JSON.parse(readFileSync("katalog/mobilya.json","utf8")).mobilyalar.map(m=>[m.id,m])) };
const kural = JSON.parse(readFileSync("kural-seti/mobilya-TR.json","utf8"));
const kazanan = (prog) => {
  const p = { ...paket, program: prog };
  const r = plaMobilyala(model, p, kural, { adet: 1 });
  const d = (r.tekilDusenler ?? []).find(x => x.mobilya === "yemek-masasi-6");
  return d ? d.kazanan_oda : null;
};
const temel = JSON.parse(readFileSync("katalog/program.json","utf8"));
const a = kazanan(temel);
const buyuk = JSON.parse(JSON.stringify(temel));
for (const k of buyuk.daire_kisitlari.daire_tekil) if (k.mobilya === "yemek-masasi-6") k.tercih = "en_kucuk_oda";
const b = kazanan(buyuk);
process.stdout.write(a === null ? "DUSURME-YOK" : (a !== b ? "TERCIH-ISLIYOR" : `DEGISMEDI(${a})`));
' 2>&1)"
case "$TER" in
  TERCIH-ISLIYOR) printf '  ✓ %-42s beyan kazananı değiştiriyor\n' "tekillik tercihi VERİDEN"; GECEN=$((GECEN+1)) ;;
  DUSURME-YOK)    printf '  ✓ %-42s (bu fixture tekillik yarışı içermiyor)\n' "tekillik tercihi VERİDEN"; GECEN=$((GECEN+1)) ;;
  *)              printf '  ✗ %-42s %s\n' "tekillik tercihi VERİDEN" "$TER"; KALAN=$((KALAN+1)) ;;
esac

echo
echo "geçen: $GECEN · kalan: $KALAN"
if [ "$KALAN" -eq 0 ]; then echo "SONUC: GECTI"; exit 0; else echo "SONUC: KALDI"; exit 1; fi
