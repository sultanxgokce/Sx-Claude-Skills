#!/usr/bin/env bash
# sultan-eli.test.sh — kapının ÜÇ durumunu da ayrı ayrı kanıtlar.
# En kritik iddia: 3 (ölçemedim) ≠ 1 (insan yok). Bu ayrım kaybolursa kapı, yer-gerçeği
# yerine bilgisizliğe bağlanır ve ölçemediği her kutuda meşru Sultan'ı reddeder.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
K="$HERE/sultan-eli.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "PASS  $1"; else fail=$((fail+1)); echo "FAIL  $1 (beklenen=$2 gelen=$3)"; fi; }

KOK="$T/kayit"; mkdir -p "$KOK/proje"
export SULTAN_ELI_KOK="$KOK"

_satir() {  # $1=içerik $2=kaç saniye önce
  python3 - "$1" "$2" <<'PY'
import json,sys,datetime
ic, geri = sys.argv[1], int(sys.argv[2])
an = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(seconds=geri)
print(json.dumps({"type":"user","message":{"role":"user","content":ic},
                  "timestamp":an.isoformat().replace("+00:00","Z")}))
PY
}

# ── Ö · ölçemedim ≠ insan yok ────────────────────────────────────────────────
bash "$K" dogrula --imza sokum >/dev/null 2>&1
check "Ö1 kayıt hiç yokken exit 3 (ÖLÇÜLEMEDİ, '1' DEĞİL)" "3" "$?"
check "Ö2 'insan yok' demiyor" "1" \
      "$(bash "$K" dogrula --imza sokum 2>&1 | grep -c 'ÖLÇÜLEMEDİ')"

# ── Y · insan izi YOK ────────────────────────────────────────────────────────
# Kayıt VAR ama içinde yalnız ajanın kendi araç çağrıları var (bunlar <bash-input> taşımaz).
{ _satir "sıradan bir kullanıcı mesajı" 5
  echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash"}]},"timestamp":"2026-08-04T15:00:00.000Z"}'
} > "$KOK/proje/a.jsonl"
bash "$K" dogrula --imza sokum >/dev/null 2>&1
check "Y1 kayıt var ama insan-! yok → exit 1" "1" "$?"
check "Y2 ajanın tool_use satırı insan sayılmıyor" "0" \
      "$(bash "$K" dogrula --imza Bash >/dev/null 2>&1; [ $? = 0 ] && echo 1 || echo 0)"

# ── V · insan izi VAR ────────────────────────────────────────────────────────
_satir "<bash-input> iskan sokum tez --apply</bash-input>" 5 >> "$KOK/proje/a.jsonl"
bash "$K" dogrula --imza "sokum tez" >/dev/null 2>&1
check "V1 taze insan-! + imza eşleşiyor → exit 0" "0" "$?"

# ── İ · imza gerçekten bağlıyor (zaman-penceresine indirgenmiyor) ────────────
bash "$K" dogrula --imza "sunucu-kur" >/dev/null 2>&1
check "İ1 BAŞKA komutun insan-izi bu kapıyı AÇMIYOR" "1" "$?"
bash "$K" dogrula --imza ab >/dev/null 2>&1
check "İ2 anlamsız kısa imza reddedildi (kapı gevşetilemez)" "2" "$?"
bash "$K" dogrula >/dev/null 2>&1
check "İ3 imzasız çağrı reddedildi" "2" "$?"

# ── Z · zaman penceresi ──────────────────────────────────────────────────────
rm -f "$KOK/proje/a.jsonl"
_satir "<bash-input> iskan sokum tez --apply</bash-input>" 5000 > "$KOK/proje/a.jsonl"
bash "$K" dogrula --imza "sokum tez" >/dev/null 2>&1
check "Z1 ESKİ insan-izi kapıyı açmıyor (dünkü onay bugüne geçmez)" "1" "$?"
SULTAN_ELI_PENCERE=99999 bash "$K" dogrula --imza "sokum tez" >/dev/null 2>&1
check "Z1b pencere genişleyince aynı satır geçiyor (kontrol gerçekten zaman ölçüyor)" "0" "$?"

# ── B · BÜYÜK kayıt: fixture-yeşil ≠ gerçek-yeşil (regresyon) ────────────────
# NİÇİN: ilk sürüm (`tail | python3`) 14/14 fixture testini geçti ama GERÇEK oturum kaydında
#   insan-izi varken "yok" dedi. Bu blok, fixture'ı gerçeğe biraz daha yaklaştırır (kalabalık
#   dosya + sondan uzak eşleşme).
#   ⚠️ DÜRÜST SINIR: bu test, o vakayı YENİDEN ÜRETMİYOR — boruyu geri takan mutasyon
#   koşuldu ve B1 KIRILMADI. Yani B1 bir regresyon-kapısı değil, yalnız bir kalabalık-dosya
#   sağlamasıdır. Gerçek güvence testte değil, ÖLÇÜMDE: bu sürüm canlı kayıtta koşturulup
#   doğru cevap verdiği görüldü. Bunu "test kapattı" diye yazmak sahte-yeşil olurdu.
rm -f "$KOK/proje/a.jsonl"
_satir "<bash-input> iskan sokum tez --apply</bash-input>" 5 > "$KOK/proje/buyuk.jsonl"
python3 - "$KOK/proje/buyuk.jsonl" <<'PY'
import sys
with open(sys.argv[1],"a") as f:
    for i in range(600):
        f.write('{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash"}]},"timestamp":"2026-08-04T15:00:00.000Z"}\n')
PY
bash "$K" dogrula --imza "sokum tez" >/dev/null 2>&1
check "B1 büyük kayıtta insan-izi bulunuyor (erken-çıkış exit'i ters çevirmiyor)" "0" "$?"

# ── S · saniye içi: kayıt ile kapı aynı saniyede (05.11, canlıda iki kez meşru RED) ───────
# Saat tam saniyeye yuvarlanırsa kayıt "gelecekte" görünür. Saniyenin başına hizalanır ki kapı aynı saniyede koşsun.
: > "$KOK/proje/a.jsonl"
python3 - "$KOK/proje/s.jsonl" <<'PY'
import json,sys,time,datetime
while time.time()%1>0.15: time.sleep(0.005)
an=datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="milliseconds").replace("+00:00","Z")
open(sys.argv[1],"w").write(json.dumps({"type":"user","message":{"role":"user","content":"<bash-input>saniye ici</bash-input>"},"timestamp":an})+"\n")
PY
bash "$K" dogrula --imza "saniye ici" >/dev/null 2>&1
check "S1 kayıtla aynı saniyede koşan kapı insanı görür" "0" "$?"
_satir "<bash-input>ileri tarih</bash-input>" -30 > "$KOK/proje/s.jsonl"
bash "$K" dogrula --imza "ileri tarih" >/dev/null 2>&1
check "S2 gelecek tarihli kayıt hâlâ reddedilir" "1" "$?"
: > "$KOK/proje/s.jsonl"

# ── D · durum tanısı verdikt vermez ──────────────────────────────────────────
bash "$K" durum >/dev/null 2>&1
check "D1 durum her hâlde exit 0 (tanı, kapı değil)" "0" "$?"
check "D2 durum ölçüm yüzeyini söylüyor" "1" \
      "$(bash "$K" durum 2>&1 | grep -c 'ölçüm yüzeyi')"

# ── K · korkuluk-dürüstlüğü: kod kendi sınırını YAZILI taşıyor ───────────────
# Bu satır süs değil: bu dosyanın verdiği güvence abartılırsa ilk yanlış kullanım doğar.
check "K1 'kilit değil korkuluk' uyarısı kodda duruyor" "1" \
      "$(grep -c 'KİLİT DEĞİL' "$K")"
check "K2 kastı durdurmadığı açıkça yazılı" "1" \
      "$(grep -c 'KASTI durdurmaz' "$K")"

# ── ZK · ZİNCİR KİMLİĞİ (SERDAR kararı 6 Kas, görev …YC9DS) ───────────────────────
# Kayıt komut BAŞINDA düşer; kapı zincirin SONUNDA koşar. Pencere 1 sn'e indirilir (45 sn'lik
# bekleme yerine), böylece "kayıt yaşlandı" durumu saniyeler içinde üretilir.
IM="zincir-sinavi-x"
zk() {  # $1=kapı betiği $2=kayıttaki komut metni $3=kayıt kaç sn önce $4=kök kabuğun komutu
  _satir "<bash-input>$2</bash-input>" "$3" > "$KOK/proje/z.jsonl"
  bash -c "eval '$4'; r=\$?; exit \$r" >/dev/null 2>&1   # gerçek araç sarmalayıcısı gibi: kök kabuk eval ile tutar (exec'e çevrilmez)
}
KOMUT="sleep 3 && SULTAN_ELI_PENCERE=1 bash $K dogrula --imza $IM"
zk "$K" "$KOMUT" 0 "$KOMUT"
check "ZK1 aynı zincir, kapı geç kaldı (pencere dolmuş) → VAR" "0" "$?"

zk "$K" "başka komut $IM" 0 "$KOMUT"
check "ZK2 farklı zincir (kök komut metni kayıttakinden farklı) → YOK" "1" "$?"

zk "$K" "sleep 3 &&  SULTAN_ELI_PENCERE=1 bash $K dogrula --imza $IM" 0 "$KOMUT"
check "ZK3 komut metni bir boşluk farklı → YOK (birebir)" "1" "$?"

# ZK4 · kök, kayıttan ÖNCE başlamış (PID yeniden kullanımı / eski kabuk): kayıt kökten 4 sn sonra düşer
KOMUT4="sleep 6 && SULTAN_ELI_PENCERE=1 bash $K dogrula --imza $IM"
bash -c "eval '$KOMUT4'; r=\$?; exit \$r" >/dev/null 2>&1 & KP=$!
sleep 4; _satir "<bash-input>$KOMUT4</bash-input>" 0 > "$KOK/proje/z.jsonl"
wait $KP
check "ZK4 kök kayıttan ÖNCE başlamış → YOK" "1" "$?"

# ZK5 · aynı komutun SONRADAN yeniden koşusu (replay): kayıt 8 sn önce, kök şimdi başlıyor
KOMUT5="SULTAN_ELI_PENCERE=1 bash $K dogrula --imza $IM"
zk "$K" "$KOMUT5" 8 "$KOMUT5"
check "ZK5 aynı komut kayıttan 8 sn SONRA yeniden koşulunca → YOK (replay)" "1" "$?"

# ZK6 · mutlak üst sınır
SULTAN_ELI_ZINCIR_UST=1 zk "$K" "$KOMUT" 0 "SULTAN_ELI_ZINCIR_UST=1 $KOMUT"
check "ZK6 mutlak üst sınır aşılınca → YOK" "1" "$?"

# ZK7/ZK8 · mutantlar: bağ koşulu sökülünce ZK4/ZK5 senaryosu GEÇMEMELİ (geçerse sınav yakalamıştır)
M="$T/mutant.sh"; sed 's/if not (an-2<=bas<=an+5): continue.*/pass/' "$K" > "$M"
check "ZK7 mutant sökülmüş başlangıç koşulu gerçekten dosyayı değiştirdi" "1" \
      "$(cmp -s "$K" "$M" && echo 0 || echo 1)"
KOMUT7="SULTAN_ELI_PENCERE=1 bash $M dogrula --imza $IM"
zk "$M" "$KOMUT7" 8 "$KOMUT7"
check "ZK8 mutantta replay GEÇİYOR (0) → başlangıç koşulu sökülünce ZK5 yakalanır" "0" "$?"

# ZK11 · aynı mutant, ZK4 senaryosunda (kök kayıttan ÖNCE) de yakalanmalı
KOMUT11="sleep 6 && SULTAN_ELI_PENCERE=1 bash $M dogrula --imza $IM"
bash -c "eval '$KOMUT11'; r=\$?; exit \$r" >/dev/null 2>&1 & KP=$!
sleep 4; _satir "<bash-input>$KOMUT11</bash-input>" 0 > "$KOK/proje/z.jsonl"
wait $KP
check "ZK11 mutantta 'kök önce başlamış' senaryosu GEÇİYOR (0) → ZK4 yakalanır" "0" "$?"

# ZK12 · ALT DİZE saldırısı: kök komut, kayıtlı komutu ÖNEK/SONEK eklenmiş halde taşıyor → YOK
zk "$K" "$KOMUT" 0 "$KOMUT; g=\$?; echo sonek; exit \$g"   # sonek eklendi, kapının çıkış kodu taşınır
check "ZK12a kök komut = kayıtlı komut + sonek (alt dize) → YOK" "1" "$?"
_satir "<bash-input>$KOMUT</bash-input>" 0 > "$KOK/proje/z.jsonl"
bash -c "eval 'echo onek; $KOMUT'; r=\$?; exit \$r" >/dev/null 2>&1
check "ZK12b kök komut = önek + kayıtlı komut (eval içinde alt dize) → YOK" "1" "$?"

# ── ZA · GERÇEK SARMALAYICI BİÇİMİ (SERDAR 6 Kas 20:2x: canlı '!' koşusu insan-izi YOK dedi) ──────────────
# Harness kökü ps'ten ÖLÇÜLEN biçimde sarar: `source <snap> 2>/dev/null || true && shopt -u extglob … && { …unalias…; } >/dev/null 2>&1 || true
#   && eval '<komut>' < /dev/null && pwd -P >| <cwd dosyası>`. ZK sınavları yalnız `eval '<komut>'; …` taşıyordu → fixtürde yeşil, canlıda kırmızı.
SNAP="$T/snap.sh"; : > "$SNAP"
gercek() {  # $1=kapı betiği $2=kayıttaki komut $3=eval'e giren (alıntılanmış) ifade → harness biçimli kök kabuk
  _satir "<bash-input>$2</bash-input>" 0 > "$KOK/proje/z.jsonl"
  bash -c "source $SNAP 2>/dev/null || true && shopt -u extglob 2>/dev/null || true && { \\builtin unalias -- 'which'; \\builtin unset -f -- 'which'; } >/dev/null 2>&1 || true && eval $3 < /dev/null && pwd -P >| $T/cwd-dosyasi" >/dev/null 2>&1
}
q() { python3 -c 'import shlex,sys;print(shlex.quote(sys.argv[1]))' "$1"; }
gercek "$K" "$KOMUT" "$(q "$KOMUT")"
check "ZA1 gerçek harness biçimi (tek tırnaklı eval + < /dev/null + pwd -P) → VAR" "0" "$?"
gercek "$K" "$KOMUT" "\"$KOMUT\""
check "ZA2 eval argümanı ÇİFT tırnaklı → VAR (alıntı biçimine bağlı değil)" "0" "$?"
gercek "$K" "$KOMUT" "$(printf '%q' "$KOMUT")"
check "ZA3 eval argümanı ters-bölülü (alıntısız) → VAR" "0" "$?"
gercek "$K" "$KOMUT" "$(q "echo onek; $KOMUT")"
check "ZA4 harness biçimi ama eval argümanı = önek + komut → YOK (alt dize)" "1" "$?"
gercek "$K" "$KOMUT" "$(q "$KOMUT; g=\$?; echo sonek; exit \$g")"
check "ZA5 harness biçimi ama eval argümanı = komut + sonek → YOK (alt dize; çıkış kodu taşınır)" "1" "$?"
gercek "$K" "$KOMUT" "$(q "bash -c $(q "$KOMUT; g=\$?; exit \$g")")"
check "ZA6 komut başka bir kabuğun içinde, metni değişmiş (sonekli) koşuyor → YOK" "1" "$?"
gercek "$K" "sleep 3 &&  SULTAN_ELI_PENCERE=1 bash $K dogrula --imza $IM" "$(q "$KOMUT")"
check "ZA8 harness biçimi ama kayıtlı komutta bir boşluk fazla → YOK (birebir)" "1" "$?"
# ZA9 · teşhis: eşleşmeyen zincirde sebep sayıları basılır, komut metni BASILMAZ (kayıt 5 sn yaşlı → pencere dolu, zincir denenir)
_satir "<bash-input>$KOMUT</bash-input>" 5 > "$KOK/proje/z.jsonl"
TANI="$(bash -c "eval $(q "SULTAN_ELI_PENCERE=1 bash $K dogrula --imza $IM 2>&1; true")" 2>&1)"
check "ZA9a teşhis satırı basıldı (tanı: pid=… başlangıç-kayıt=… eval-argümanı=…)" "1" "$(printf '%s' "$TANI" | grep -c '^tanı: pid=.*eval-argümanı=' | sed 's/^[2-9].*/1/;s/^1[0-9]*$/1/')"
check "ZA9b teşhis komut metnini BASMIYOR" "0" "$(printf '%s' "$TANI" | grep -c 'sleep 3 && SULTAN_ELI')"

# ZA10-ZA13 · mutantlar (sarmalayıcı ayrıştırıcısı): her söküm ilgili vakayı DÜŞÜRMELİ, yani sınav gerçekten ısırıyor
MA="$T/mutant-ayristirici.sh"; sed 's/if any(kom in eval_argumanlari(a) for a in argv): sys.exit(0)/if any(kom in c for a in argv for c in eval_argumanlari(a)): sys.exit(0)/' "$K" > "$MA"
check "ZA10 mutant (eşleştirme 'içeriyor'a gevşetildi) dosyayı gerçekten değiştirdi" "1" "$(cmp -s "$K" "$MA" && echo 0 || echo 1)"
KMA="sleep 3 && SULTAN_ELI_PENCERE=1 bash $MA dogrula --imza $IM"
gercek "$MA" "$KMA" "$(q "echo onek; $KMA")"
check "ZA11 gevşetilmiş mutantta önek+komut GEÇİYOR (0) → ZA4 yakalar" "0" "$?"
MB="$T/mutant-ayristirici2.sh"; sed 's/^    try: t=shlex.split(a)$/    try: t=[]/' "$K" > "$MB"
check "ZA12 mutant (ayrıştırıcı söküldü) dosyayı gerçekten değiştirdi" "1" "$(cmp -s "$K" "$MB" && echo 0 || echo 1)"
KMB="sleep 3 && SULTAN_ELI_PENCERE=1 bash $MB dogrula --imza $IM"
gercek "$MB" "$KMB" "\"$KMB\""
check "ZA13 ayrıştırıcısız mutantta çift tırnaklı eval REDDEDİLİYOR (1) → ZA2 yakalar" "1" "$?"

# ZK13 · üst sınır ortamdan YÜKSELTİLEMEZ: tavan sınav dikişiyle 1 sn, çağıran 9999 vermeye çalışıyor
SULTAN_ELI_SINAV=1 SULTAN_ELI_SINAV_TAVAN=1 SULTAN_ELI_ZINCIR_UST=9999 zk "$K" "$KOMUT" 0 "SULTAN_ELI_SINAV=1 SULTAN_ELI_SINAV_TAVAN=1 SULTAN_ELI_ZINCIR_UST=9999 $KOMUT"
check "ZK13 SULTAN_ELI_ZINCIR_UST tavanın ÜSTÜNE çıkarılamaz → YOK" "1" "$?"
M2="$T/mutant2.sh"; sed 's/^\[ "\$ZINCIR_UST" -le "\$ZINCIR_TAVAN" \].*/:/' "$K" > "$M2"
check "ZK14 tavan mutantı dosyayı gerçekten değiştirdi" "1" "$(cmp -s "$K" "$M2" && echo 0 || echo 1)"
K14="SULTAN_ELI_SINAV=1 SULTAN_ELI_SINAV_TAVAN=1 SULTAN_ELI_ZINCIR_UST=9999 sleep 3 && SULTAN_ELI_PENCERE=1 bash $M2 dogrula --imza $IM"
zk "$M2" "$K14" 0 "$K14"
check "ZK14b tavan mutantında 9999 GEÇİYOR (0) → ZK13 yakalar" "0" "$?"

# ZK9 · eski kural bozulmadı: kök eşleşmesi yoksa 45 sn kuralı aynen
_satir "<bash-input>cd /x && bash kapi.sh $IM</bash-input>" 5 > "$KOK/proje/z.jsonl"
bash "$K" dogrula --imza "$IM" >/dev/null 2>&1
check "ZK9 eski kural: taze kayıt, kök eşleşmesi gerekmeden → VAR" "0" "$?"
_satir "<bash-input>cd /x && bash kapi.sh $IM</bash-input>" 60 > "$KOK/proje/z.jsonl"
bash "$K" dogrula --imza "$IM" >/dev/null 2>&1
check "ZK10 eski kural: 60 sn yaşlı kayıt, kök yok → YOK (gevşemedi)" "1" "$?"
: > "$KOK/proje/z.jsonl"

echo ""
echo "── SONUÇ: PASS=$pass FAIL=$fail ──"
[ "$fail" = "0" ] || exit 1
exit 0
