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

echo "D · 🔴 profil çözülmeden araç YEŞİL BASMAZ (fail-closed)"
kapi "D1 IMAR_SERI yoksa karne ÖLÇEMEDİM der (rc=3)" 3 env -u IMAR_SERI IMAR_REPO="$REPO" python3 "$S/imar-karne.py"
kapi "D2 IMAR_SERI yoksa olgunluk ÖLÇEMEDİM der (rc=3)" 3 env -u IMAR_SERI IMAR_REPO="$REPO" python3 "$S/imar-olgunluk.py"
iceren "D3 eksikliğin ADI söylenir (hangi değişken)" "IMAR_SERI" env -u IMAR_SERI IMAR_REPO="$REPO" python3 "$S/imar-karne.py"

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[ "$DUSEN" -eq 0 ]
