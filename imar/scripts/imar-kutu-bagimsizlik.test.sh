#!/usr/bin/env bash
# imar-kutu-bagimsizlik.test.sh — ⛩️ bu becerinin EN ÖNEMLİ kapısı.
#
# NİÇİN: İMAR, MİHENK kutusunda doğdu ve 12 yerde o kutuya çiviliydi. Reçeteyi filo becerisine
# çevirmenin tek ölçülebilir iddiası şudur: "BAŞKA bir kutuda kurulur ve koşar." Bu sınav onu
# MİHENK'i hiç görmeyen sahte bir kutuda ölçer.
#
# 🔴 Asıl tehlike çökmek DEĞİL, sessizce yanlış yere yazmak ya da olmayan dizini ölçüp "0" basmak.
#    Bu yüzden kapılar yalnız "koştu mu" demiyor; "nereye yazdı" ve "ölçemediğini söyledi mi" diyor.
#
# HERMETİK: gerçek MİHENK deposuna, gerçek deftere, crontab'a DOKUNMAZ.
set -uo pipefail
cd "$(dirname "$0")"
S="$PWD"
GECEN=0; DUSEN=0
kapi(){ local ad="$1" bek="$2"; shift 2
  "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -eq "$bek" ]; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad (rc=$rc, beklenen=$bek)"; fi; }
iceren(){ local ad="$1" ara="$2"; shift 2
  local o; o="$("$@" 2>&1)"
  if [[ "$o" == *"$ara"* ]]; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad (çıktıda '$ara' yok)"; fi; }
icermeyen(){ local ad="$1" ara="$2"; shift 2
  local o; o="$("$@" 2>&1)"
  if [[ "$o" != *"$ara"* ]]; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad ('$ara' çıktıda var, olmamalı)"; fi; }

KOK="$(mktemp -d)"; trap 'rm -r -f "$KOK" 2>/dev/null' EXIT
# Sahte kutu: adı MİHENK DEĞİL ve yolları /config/projects/mihenk ile hiç kesişmiyor
KUTU="deneme-kutusu"
REPO="$KOK/projects/$KUTU"; EV="$KOK/projects/$KUTU-muneccim"
mkdir -p "$REPO" "$EV"
PROFIL="$KOK/profil.json"
cat > "$PROFIL" <<JSON
{
  "sema": 1,
  "kutu": "$KUTU",
  "ajan": "DENEME",
  "repo_kok": "$REPO",
  "muneccim_ev": "$EV",
  "defter_yaz": "$KOK/yok/defter-yaz.py",
  "alarm": { "taban": "http://ornek-gecit:80", "konu": "deneme-konu", "cihaz_teyidi": "2026-10-15 Sultan: geldi" }
}
JSON

echo "A · 🔴 profil kapısı: ölçülmeden kurulum YOK"
kapi "A1 geçerli profil kabul edilir" 0 python3 "$S/imar-profil.py" dogrula "$PROFIL"
python3 -c "
import json,sys
p=json.load(open('$PROFIL')); p['alarm']['cihaz_teyidi']=''
json.dump(p,open('$KOK/teyitsiz.json','w'),ensure_ascii=False)"
kapi "A2 🔴 cihaz teyidi BOŞ profil REDDEDİLİR (200 kanıt değildir)" 1 python3 "$S/imar-profil.py" dogrula "$KOK/teyitsiz.json"
python3 -c "
import json
p=json.load(open('$PROFIL')); p['uydurma_alan']='x'
json.dump(p,open('$KOK/fazla.json','w'),ensure_ascii=False)"
kapi "A3 🔴 bilinmeyen alan REDDEDİLİR (sessizce atlanan alan ölçülmemiş alandır)" 1 python3 "$S/imar-profil.py" dogrula "$KOK/fazla.json"
python3 -c "
import json
p=json.load(open('$PROFIL')); p['repo_kok']='goreli/yol'
json.dump(p,open('$KOK/goreli.json','w'),ensure_ascii=False)"
kapi "A4 🔴 göreli yol REDDEDİLİR (koşulduğu dizine göre kayar)" 1 python3 "$S/imar-profil.py" dogrula "$KOK/goreli.json"
kapi "A5 profil dosyası YOKSA rc=2 (ölçemedim), 0 DEĞİL" 2 python3 "$S/imar-profil.py" dogrula "$KOK/hic-yok.json"

echo "B · 🔴 SAHTE KUTUDA kurulum fiilen koşar"
kapi "B1 kuru koşu geçer" 0 bash "$S/imar-kur.sh" "$PROFIL" --kuru
kapi "B2 gerçek kurulum geçer" 0 bash "$S/imar-kur.sh" "$PROFIL"
kapi "B3 🔴 şalter KAPALI doğdu (değişmez)" 1 env IMAR_DURUM="$REPO/_agents/spec/imar/DURUM.json" IMAR_KUTUK="$REPO/hafiza/imar-kutuk.log" IMAR_SERI="$EV/arastirma-serisi" bash "$S/imar.sh" acik-mi
iceren "B4 kurulum şalterin kapalı doğduğunu SÖYLER" "şalter kapalı doğdu" bash "$S/imar-kur.sh" "$PROFIL"
iceren "B5 Bulgu Defteri yokken ÖLÇÜLEMEDİ der, uydurmaz" "ÖLÇÜLEMEDİ der, uydurmaz" bash "$S/imar-kur.sh" "$PROFIL"
iceren "B6 zamanlayıcı satırı ÜRETİLİR ama crontab'a dokunulmaz" "crontab'a DOKUNMAZ" bash "$S/imar-kur.sh" "$PROFIL"

echo "C · 🔴 SIZINTI: sahte kutu MİHENK'i hiç görmedi"
kapi "C1 kurulum MİHENK deposuna dizin AÇMADI" 1 test -e /config/projects/mihenk/_agents/spec/imar/DURUM.json.deneme
icermeyen "C2 🔴 kurulum çıktısında 'mihenk' GEÇMEZ" "mihenk" bash "$S/imar-kur.sh" "$PROFIL"
kapi "C3 şalter sahte kutunun İÇİNE yazıldı" 0 test -f "$REPO/_agents/spec/imar/DURUM.json"
kapi "C4 araştırma serisi sahte kutunun evinde açıldı" 0 test -d "$EV/arastirma-serisi/gunluk"
# 🔴 SINAV KENDİNİ TARAMAZ (betik-bekçisinin dersi, 12 Eki): ilk yazımda bu kapı kendi dosyasını
#    buluyordu — C1/C2 satırları "mihenk" kelimesini taşımak ZORUNDA, yoksa sızıntıyı ölçemezler.
#    Masumu suçlayan kapı, suçluyu bulan kapıdan daha pahalıdır. Taranan şey ÜRETİM kodudur.
kapi "C5 🔴 ÜRETİM kodunda çivili kutu adı YOK (sınav dosyaları hariç)" 0 bash -c '
  for f in '"$S"'/*.sh '"$S"'/*.py; do
    case "$f" in *.test.sh) continue ;; esac
    grep -n "mihenk\|NECCÂR\|NECCAR" "$f" 2>/dev/null \
      | grep -vE ":[[:space:]]*#|Eski sürüm|KUTU ÇİVİSİ|çiviliydi|Eski satır" | grep -q . && exit 1
  done
  exit 0'

echo "G · 🔴 gözün tur-2 bulgusu: KUTU VERİSİ BECERİ DİZİNİNE DÜŞMESİN"
# Beceri BÜTÜN kutularda ORTAKTIR. Kutu verisi (hafiza · karne · mezarlık · DURUM) beceri
# dizinine düşerse bir kutunun verisi ötekine karışır — bu bir SIZINTIDIR, hata mesajı değil.
# Gözün kanıtı: `imar.sh durum` koşarken becerinin worktree kökünde fikir-mezarligi.jsonl arıyordu.
BECERI_KOK="$(cd "$S/.." && pwd)"
kapi "G1 durum komutu sahte kutuda koşar" 0 env IMAR_REPO="$REPO" IMAR_DURUM="$REPO/_agents/spec/imar/DURUM.json" \
  IMAR_KUTUK="$REPO/hafiza/imar-kutuk.log" IMAR_SERI="$EV/arastirma-serisi" IMAR_KUTU="$KUTU" IMAR_AJAN="DENEME" \
  bash "$S/imar.sh" durum
icermeyen "G2 🔴 çıktıda BECERİ dizini yolu GEÇMEZ (kutu verisi oraya düşmez)" "$BECERI_KOK/hafiza" \
  env IMAR_REPO="$REPO" IMAR_DURUM="$REPO/_agents/spec/imar/DURUM.json" IMAR_KUTUK="$REPO/hafiza/imar-kutuk.log" \
  IMAR_SERI="$EV/arastirma-serisi" IMAR_KUTU="$KUTU" IMAR_AJAN="DENEME" bash "$S/imar.sh" durum
kapi "G3 🔴 beceri dizininde hafiza/ AÇILMADI (sızıntı yok)" 1 test -d "$BECERI_KOK/hafiza"
# Beklentiyi ilk yazımda ters koydum (grep -q BULDUĞUNDA 0 döner, 1 beklemiştim) — kapı niyetini
# söyleyen biçime çevrildi: mesajın İÇİNDE eksik değişkenin adı geçiyor mu?
iceren "G4 🔴 IMAR_REPO yoksa şalter eksiğin ADINI söyler (beceri köküne yazmaz)" "IMAR_REPO" \
  env -u IMAR_REPO IMAR_SERI="$EV/arastirma-serisi" bash "$S/imar.sh" durum
kapi "G5 karne IMAR_REPO yoksa rc=3" 3 env -u IMAR_REPO IMAR_SERI="$EV/arastirma-serisi" python3 "$S/imar-karne.py"
kapi "G6 üretim kodunda kutu verisi betik konumundan TÜRETİLMEZ" 0 bash -c '
  for f in '"$S"'/imar.sh '"$S"'/imar-karne.py '"$S"'/imar-olgunluk.py '"$S"'/imar-defter.py; do
    grep -nE "dirname.*abspath\(__file__\)|BASH_SOURCE" "$f" | grep -qE "hafiza|karne|mezarlig|DURUM" && exit 1
  done
  exit 0'

echo "D · 🔴 profil çözülmeden araç YEŞİL BASMAZ (fail-closed)"
kapi "D1 IMAR_SERI yoksa karne ÖLÇEMEDİM der (rc=3)" 3 env -u IMAR_SERI IMAR_REPO="$REPO" python3 "$S/imar-karne.py"
kapi "D2 IMAR_SERI yoksa olgunluk ÖLÇEMEDİM der (rc=3)" 3 env -u IMAR_SERI IMAR_REPO="$REPO" python3 "$S/imar-olgunluk.py"
iceren "D3 eksikliğin ADI söylenir (hangi değişken)" "IMAR_SERI" env -u IMAR_SERI IMAR_REPO="$REPO" python3 "$S/imar-karne.py"

echo "E · 🔴 gözün tur-1 bulgusu: İLAN EDİLEN alan KODA BAĞLI mı (kayıt var, çağıran yok)"
# Profil `defter_yaz`i ZORUNLU ilan ediyordu ama kod küresel yolu varsayıyordu: ilan kutu
# bağımsızlığını kanıtlamaz, yalnız iddia eder. Kapı, çözücüden gelen değerin koda ULAŞTIĞINI ölçer.
iceren "E1 çözücü IMAR_DEFTER_YAZ'ı profilden taşır" "IMAR_DEFTER_YAZ=\"$KOK/yok/defter-yaz.py\"" \
  python3 "$S/imar-profil.py" cozumle "$PROFIL"
iceren "E2 çözücü BULGULAR_JSON taşır (profil ezebilir)" "BULGULAR_JSON=" python3 "$S/imar-profil.py" cozumle "$PROFIL"
iceren "E3 çözücü IMAR_WA_GONDER taşır (alarm yolu kutudan kutuya değişir)" "IMAR_WA_GONDER=" python3 "$S/imar-profil.py" cozumle "$PROFIL"
# 🔴 BU KAPIYI ÜÇ KEZ YANLIŞ YAZDIM ve her seferinde KENDİ GİRDİ HATAMI ölçtüm:
#    (1) argüman adları uydurma (--olum/--kanit-sinifi yok) → rc=2 argparse hatası
#    (2) --sinif'a kanıt sınıfı verdim → rc=2 "kanıt sınıfı olmalı"
#    (3) ancak üçüncüde ölçtüm: --kanit KANIT SINIFI (olcum|kaynak|zanaat), --sinif ise dört-sınıf
#        listesi. Doğru çağrı rc=3 ve "defter aracı yok (<profilin yolu>)" veriyor.
#    Ders: kapıyı YAZMADAN ÖNCE aracın gerçek davranışını ölç; yoksa kapı yeşil/kırmızı basar ama
#    adının söylediği şeyi değil, senin yazım hatanı ölçer (vekil ölçüt).
kapi "E4 🔴 defter aracı PROFİLDEN okunur: profilin gösterdiği yok dosya ÖLÇÜLEMEDİ üretir (rc=3)" 3 \
  env IMAR_DEFTER_YAZ="$KOK/yok/defter-yaz.py" python3 "$S/imar-fikir-kapisi.py" \
      --baslik "deneme" --deger 40 --pazar 30 --teknik 30 --deney "x" --oldur "y" --kanit olcum
iceren "E4b 🔴 ret mesajı PROFİLİN yolunu söyler (küresel varsayılanı değil)" "$KOK/yok/defter-yaz.py" \
  env IMAR_DEFTER_YAZ="$KOK/yok/defter-yaz.py" python3 "$S/imar-fikir-kapisi.py" \
      --baslik "deneme" --deger 40 --pazar 30 --teknik 30 --deney "x" --oldur "y" --kanit olcum
kapi "E5 üretim kodunda küresel yol TEK BAŞINA kalmaz (profil ezebilir)" 0 bash -c '
  grep -q "IMAR_DEFTER_YAZ" '"$S"'/imar-defter.py \
  && grep -q "IMAR_DEFTER_YAZ" '"$S"'/imar-fikir-kapisi.py \
  && grep -q "IMAR_WA_GONDER" '"$S"'/cark-tur.sh'

echo "F · 🔴 gözün tur-1 bulgusu: SAYIM DÜRÜST olsun (atlanan kapı yeşil değildir)"
# 🔴 ÖZYİNELEME TUZAĞI (ilk yazımda düştüm, sınav 115 sn'de Terminated oldu): bu kapılar toplu
#    koşucuyu ÇAĞIRIYORDU, o da yedi sınavın içinde BU sınavı koşuyordu → sonsuz özyineleme.
#    Bir aracı sınayan kapı, o aracın kendisini sınadığı kümede yer alıyorsa koşturarak ölçemez.
#    Sayımın dürüstlüğü METİNDEN ölçülür (koşucu üç sayıyı ayrı basıyor mu), davranış ise
#    koşucunun ölçemediği durumdan (F3).
kapi "F1 toplu koşucu ATLANAN kapıyı AYRI sayar (metin kapısı, özyinelemesiz)" 0 bash -c '
  grep -q "ATLANAN (ölçülemedi, geçti SAYILMAZ)" '"$S"'/imar-sinav-hepsi.sh'
kapi "F2 🔴 atlanan varken 'hepsi koştu' DENMEZ uyarısı var" 0 bash -c '
  grep -q "hepsi koştu. DENMEZ" '"$S"'/imar-sinav-hepsi.sh'
kapi "F2b koşucu ATLANDI/⏭ satırlarını fiilen sayar (grep -c)" 0 bash -c '
  grep -q "grep -cE .ATLANDI" '"$S"'/imar-sinav-hepsi.sh'
kapi "F3 sınav dizini yoksa rc=3 (ölçemedim), 0 DEĞİL" 3 bash "$S/imar-sinav-hepsi.sh" "$KOK/hic-yok"
# 🔴 SAYAÇ KENDİ KAPI ADINI EŞLEMESİN: bu araçta bizzat oldu — F2b'nin ADI "ATLANDI/⏭" taşıyor ve
#    sayaç onu gerçek atlama sanıp 2 yerine 3 saydı. Aynı desen bugün üçüncü kez ısırdı (C5 kendini
#    taradı, prob vekil ölçüttü, şimdi sayaç kendi adını saydı). Kapı artık onu ölçer.
kapi "F4 🔴 sayaç kapı satırlarını (✓/✗) atlama saymaz" 0 bash -c '
  grep -q "grep -vE .\^\[\[:space:\]\]\*\[✓✗\]" '"$S"'/imar-sinav-hepsi.sh'

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[ "$DUSEN" -eq 0 ]
