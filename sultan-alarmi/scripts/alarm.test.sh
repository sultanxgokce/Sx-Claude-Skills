#!/usr/bin/env bash
# alarm.sh sınavı — hermetik: sahte curl/kapimda/gorev.sh, sahte saat; ağa ve gerçek deftere GİTMEZ.
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"; AL="${ALARM_SH:-$KOK/alarm.sh}"
gec=0; kal=0
ok(){ if [ "$2" = "$3" ]; then gec=$((gec+1)); echo "  ✓ $1"; else kal=$((kal+1)); echo "  ✗ $1 — beklenen=[$2] gerçek=[$3]"; fi; }
var(){ case "$3" in *"$2"*) gec=$((gec+1)); echo "  ✓ $1" ;; *) kal=$((kal+1)); echo "  ✗ $1 — '$2' yok: $3" ;; esac; }
yok(){ case "$3" in *"$2"*) kal=$((kal+1)); echo "  ✗ $1 — '$2' OLMAMALI: $3" ;; *) gec=$((gec+1)); echo "  ✓ $1" ;; esac; }
T=$(mktemp -d); trap 'rm -r -- "$T" 2>/dev/null' EXIT INT TERM
export SULTAN_ALARMI_DIZIN="$T/d" NO_COLOR=1 SULTAN_ALARMI_SIMDI=1800000000
unset SULTAN_EKRANDA
cat > "$T/curl" <<'EOC'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$(dirname "$0")/curl.log"; printf '%s' "${CURL_KOD:-200}"
EOC
cat > "$T/kapimda" <<'EOC'
#!/usr/bin/env bash
printf '🚦 SENDE · Kasa Erişimi\n  Ne yapman gerekiyor: x\n🎯 BERİD · devredilmiş\n'
EOC
cat > "$T/gorev.sh" <<'EOC'
#!/usr/bin/env bash
[ "${GOREV_RC:-0}" -eq 0 ] || exit "$GOREV_RC"
printf 'gorev_A  code  onay-bekliyor  acil  -  BERİD  Eski onay işi  (son: 2027-01-14)\n'
printf 'gorev_B  code  onay-bekliyor  acil  -  MİRAHUR  Taze onay işi  (son: 2027-01-15)\n'
printf 'gorev_C  code  acik  esnek  -  MUAVİN  Onay beklemeyen  (son: 2020-01-01)\n'
printf 'gorev_D  code  onay-bekliyor  acil  -  HEZARFEN  Tarihsiz onay işi\n'
EOC
chmod +x "$T/curl" "$T/kapimda" "$T/gorev.sh"
export SULTAN_ALARMI_CURL="$T/curl" SULTAN_ALARMI_KAPIMDA_SH="$T/kapimda" SULTAN_ALARMI_GOREV_SH="$T/gorev.sh"
G(){ bash "$AL" gonder --is "Revak disk silme" --kim "SERDAR bekliyor" --ne "revak terminalinde ! ile tek satır" "$@"; }
echo "— biçim"
o="$(bash "$AL" bicim --is "A" --kim "B" --ne "C")"; ok "B1 sabit biçim" "🚨🔴 SULTAN ALARMI — A · B · C" "$o"
bash "$AL" bicim --is "A" --kim "B" >/dev/null 2>&1; ok "B2 eksik alan rc 2" "2" "$?"
bash "$AL" bicim --is "A" --kim "B" --ne "" >/dev/null 2>&1; ok "B3 boş alan rc 2" "2" "$?"
bash "$AL" bicim --is "A" --kim "B" --ne "$(printf 'x%.0s' $(seq 161))" >/dev/null 2>&1; ok "B4 160+ karakter rc 2" "2" "$?"
bash "$AL" bicim --is "A" --kim "B" --ne $'iki\nsatır' >/dev/null 2>&1; ok "B5 çok satır rc 2" "2" "$?"
bash "$AL" bicim --is "A" --kim "B" --ne "token=abc123xyz" >/dev/null 2>&1; ok "B6 sır deseni rc 2" "2" "$?"
for b in --is --kim --ne --tekrar-dk --esik-gun; do timeout 5 bash "$AL" bicim --is A --kim B --ne C "$b" >/dev/null 2>&1; ok "B7 son argüman '$b' değersiz: takılmaz, rc 2" "2" "$?"; done
echo "— gönder"
o="$(G)"; var "G1 terminal satırı basılır" "🚨🔴 SULTAN ALARMI — Revak disk silme · SERDAR bekliyor · revak terminalinde ! ile tek satır" "$o"
ok "G2 --telefon yokken ağa çıkılmaz" "yok" "$([ -e "$T/curl.log" ] && echo var || echo yok)"
o="$(SULTAN_ALARMI_SIMDI=1800000100 G)"; var "G3 tekrar sınırı: aynı iş susar" "sustu" "$o"
yok "G3b susan alarm satırı yeniden basmaz" "SULTAN ALARMI —" "$o"
rm -r -- "$T/d"; o="$(G --telefon --kuru)"; var "G4 --kuru telefona GİTMEZ ama niyetini söyler" "kuru: telefona gidecekti" "$o"
ok "G4b kuruda curl çağrılmaz" "yok" "$([ -e "$T/curl.log" ] && echo var || echo yok)"
rm -r -- "$T/d"; G --telefon >/dev/null; ok "G5 --telefon: ntfy'ye gider (öncelik 4)" "1:1" "$(grep -c 'Priority: 4' "$T/curl.log"):$(grep -c 'cloudtop-ntfy/alarm\|/alarm' "$T/curl.log")"
ok "G5b kütükte gitti kaydı" "1" "$(grep -c '"telefon": "gitti"' "$T/d/kutuk.jsonl")"
rm -r -- "$T/d"; : > "$T/curl.log"; SULTAN_EKRANDA=1 G --telefon >/dev/null; ok "G6 Sultan ekrandaysa telefon atlanır" "0" "$(grep -c . "$T/curl.log")"
ok "G6b kütükte atlandı kaydı" "1" "$(grep -c '"telefon": "atlandi"' "$T/d/kutuk.jsonl")"
rm -r -- "$T/d"; o="$(CURL_KOD=500 G --telefon 2>&1)"; var "G7 bildirim gitmediyse UYARI (sessiz başarı yok)" "telefon bildirimi gitmedi" "$o"
ok "G7b kütükte hata kaydı" "1" "$(grep -c '"telefon": "hata"' "$T/d/kutuk.jsonl")"
echo "— yükseltme"
rm -r -- "$T/d"; for i in 1 2 3; do SULTAN_ALARMI_SIMDI=$((1800000000 + i*7200)) G >/dev/null; done
o="$(SULTAN_ALARMI_SIMDI=$((1800000000 + 4*7200)) G --telefon)"; var "Y1 4. tekrarda YÜKSELTİLDİ" "TEKRAR 4 — YÜKSELTİLDİ" "$o"
ok "Y1b yükseltmede öncelik 5" "1" "$(grep -c 'Priority: 5' "$T/curl.log")"
rm -r -- "$T/d"; for i in 1 2; do SULTAN_ALARMI_SIMDI=$((1800000000 + i*7200)) G >/dev/null; done
o="$(SULTAN_ALARMI_SIMDI=$((1800000000 + 3*7200)) G)"; var "Y1c eşiğin TAM kendisinde (3.) yükseltilir" "TEKRAR 3 — YÜKSELTİLDİ" "$o"
o="$(SULTAN_ALARMI_SIMDI=$((1800000000 + 3*7200)) G)"; var "Y1d 2. basışta yükseltme yok" "SULTAN ALARMI" "$(rm -r -- "$T/d"; SULTAN_ALARMI_SIMDI=1800000000 G >/dev/null; SULTAN_ALARMI_SIMDI=1800007200 G)"
rm -r -- "$T/d"; o="$(SULTAN_ALARMI_SIMDI=1800007200 G)"; yok "Y2 ilk alarmda yükseltme YOK" "YÜKSELTİLDİ" "$o"
echo "— eşzamanlılık"
rm -r -- "$T/d"; for i in 1 2 3 4 5 6 7 8; do ( G >> "$T/par.out" 2>&1 ) & done; wait
ok "E1 8 eşzamanlı gönderimde alarm TEK kez basılır" "1" "$(grep -c 'SULTAN ALARMI —' "$T/par.out")"
ok "E1b kalan 7'si sustu" "7" "$(grep -c '^sustu' "$T/par.out")"
ok "E1c sayaç 1" "1" "$(awk -F'\t' '{print $3}' "$T/d/durum.tsv")"
echo "— tara"
o="$(bash "$AL" tara)"; rc=$?
var "T1 kapımda SENDE kartı aday" "ADAY|Kasa Erişimi|Sultan kapısı" "$o"
yok "T1b devredilmiş (🎯) kart aday DEĞİL" "devredilmiş" "$o"
var "T2 eski onay-bekliyor (1 günden yaşlı) aday" "Eski onay işi (1 gündür onay bekliyor)" "$o"
yok "T2b taze onay işi aday değil" "Taze onay işi" "$o"
yok "T2c onay beklemeyen iş aday değil" "Onay beklemeyen" "$o"
var "T3 tarihsiz satır ADAYSIZ diye söylenir (sessiz atlanmaz)" "ADAYSIZ|gorev_D" "$o"
var "T4 ölçülemeyen kaynaklar açıkça yazılır" "ÖLÇEMEDİM: sabah paketi" "$o"
ok "T5 rc 0" "0" "$rc"
o="$(GOREV_RC=7 bash "$AL" tara)"; rc=$?; var "T6 defter okunamazsa OKUNAMADI yazar" "OKUNAMADI: defter" "$o"; ok "T6b biri okunduysa rc 0" "0" "$rc"
SULTAN_ALARMI_KAPIMDA_SH=/yok GOREV_RC=7 bash "$AL" tara >/dev/null 2>&1; ok "T7 hiçbir kaynak okunamazsa rc 3 ('aday yok' DENMEZ)" "3" "$?"
echo "— ders"
cp -r -- "$KOK/.." "$T/b" 2>/dev/null; : > "$T/b/DERSLER.md"; bash "$T/b/scripts/alarm.sh" ders "deneme dersi" >/dev/null; ok "D1 ders tarihli satır olarak eklenir" "- 2027-01-15 — deneme dersi" "$(tail -1 "$T/b/DERSLER.md")"
echo; echo "sonuç: $gec geçti · $kal kaldı"; [ "$kal" -eq 0 ]
