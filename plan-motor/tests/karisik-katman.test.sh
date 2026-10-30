#!/usr/bin/env bash
# karisik-katman.test.sh — KARIŞIK katmanda ayrım VARLIK düzeyinde yapılır.
#
# 🔴 NEDEN VAR (iki gerçek müşteri dosyasında ölçüldü 2026-09-24): bu büronun çizimlerinde `0`
# katmanı hem duvar çizgisi hem tefriş/sembol konturu taşıyor (Siirt 232 poligon: 155 kapalı /
# 77 açık · Kozluk 310: 167 / 143). Katmana `duvar` dersen raflar duvar olur, `yok-say` dersen
# iç bölmeler kaybolur. Ayrım topolojiktir: kapalı ilmek → tefriş, açık çizgi → duvar adayı.
# MEDDAH şartı 3 (TERS MUTASYON): duvara İKİ kenarıyla oturan kapalı ilmek kolon/şaft olabilir →
# tefriş sayılamaz, SORU sınıfına düşer ve SINIRDA KALIR. Sessizce silinen kolon görünmez hatadır.
set -uo pipefail
PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PAKET" || exit 1
G=0; K=0
ok() { G=$((G+1)); }
kir() { K=$((K+1)); printf '  ✗ %s\n' "$1"; }

cikti="$(node -e "
import('./lib/karisik.mjs').then(({karisikTeshis})=>{
  const roller={roller:{'0':'karisik','DUV':'duvar'},sinir_rolleri:['duvar','kolon','aciklik'],rol_kumesi:['duvar','kolon','aciklik','mobilya','not','yok-say','karisik'],karisik_bitisiklik_cm:2.0};
  const kose=(...p)=>p.map(([x,y])=>({x,y}));
  const ents=[
    // duvar hattı (referans)
    {tur:'poly',katman:'DUV',kapali:false,koseler:kose([0,0],[1000,0])},
    // 1) karışık katmanda AÇIK çizgi → duvar adayı
    {tur:'poly',katman:'0',kapali:false,koseler:kose([0,300],[1000,300])},
    // 2) serbest KAPALI ilmek (raf) → tefriş
    {tur:'poly',katman:'0',kapali:true,koseler:kose([200,500],[300,500],[300,600],[200,600])},
    // 3) duvara İKİ kenarıyla oturan KAPALI ilmek (kolon) → SORU
    {tur:'poly',katman:'0',kapali:true,koseler:kose([400,0],[500,0],[500,300],[400,300])},
  ];
  const r=karisikTeshis(ents,roller);
  const s=ents.map(e=>r.sinifi.get(e)??'-');
  console.log(JSON.stringify({sinif:s,ozet:r.ozet}));
});")"
echo "  · $cikti"

sinifi() { node -e "const o=JSON.parse(process.argv[1]);console.log(o.sinif[$1]??'-')" "$cikti"; }
[ "$(sinifi 1)" = "duvar_adayi" ] && ok || kir "açık çizgi duvar adayı değil: $(sinifi 1)"
[ "$(sinifi 2)" = "tefris" ] && ok || kir "serbest kapalı ilmek tefriş değil: $(sinifi 2)"
# TERS MUTASYON — kolon silinmemeli
[ "$(sinifi 3)" = "soru_kolon_olabilir" ] && ok || kir "TERS MUTASYON: duvara oturan kapalı ilmek '$(sinifi 3)' oldu, SORU olmalıydı"
[ "$(sinifi 3)" != "tefris" ] && ok || kir "TERS MUTASYON: kolon tefriş sayılıp sınırdan DÜŞÜRÜLDÜ"
# `karisik` rollü katman yoksa kural hiç çalışmaz (başka katmanın davranışı değişmez)
bos="$(node -e "
import('./lib/karisik.mjs').then(({karisikTeshis})=>{
  const roller={roller:{'DUV':'duvar'},sinir_rolleri:['duvar'],rol_kumesi:['duvar'],};
  const r=karisikTeshis([{tur:'poly',katman:'DUV',kapali:true,koseler:[{x:0,y:0},{x:1,y:0},{x:1,y:1}]}],roller);
  console.log(r.sinifi.size);
});")"
[ "$bos" = "0" ] && ok || kir "karisik rolü yokken sınıflandırma yapılmış ($bos)"
# Eşik ilan edilmedi: modülde m² / metre eşiği geçmemeli (K01)
if grep -qE "2\.1|3\.0 *\*|< *2,1" lib/karisik.mjs; then kir "modülde sayısal eşik var (K01)"; else ok; fi
# Bayrak varsayılan KAPALI
grep -qF "bayrak('karisik-ayrim')" cli.mjs && ok || kir "bayrak bağlanmamış"

printf 'karisik-katman: gecen=%d kirik=%d\n' "$G" "$K"
[ "$K" -eq 0 ]
