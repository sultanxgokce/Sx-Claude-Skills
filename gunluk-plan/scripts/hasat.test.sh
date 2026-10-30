#!/usr/bin/env bash
# hasat.sh sınavı — HASAT KAPISI (1.19.0 · görev …ZM3PWD): bulgu göreve çevrilmeden önce "hâlâ var mı" ölçümü.
# Hermetik: gerçek deftere GİTMEZ; sahte gorev.sh (adim/durum = kütük) + sahte kayıt okuyucu HASAT_KAYIT_OKU (fikstür dosyası). Git yüzeyi geçici depoda.
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
HS="${HASAT_SH:-$KOK/hasat.sh}"
gecen=0; kalan=0
kapi(){ if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
iceriyor(){ case "$3" in *"$2"*) gecen=$((gecen+1)); echo "  ✓ $1" ;; *) kalan=$((kalan+1)); echo "  ✗ $1 — '$2' yok: $3" ;; esac; }
icermiyor(){ case "$3" in *"$2"*) kalan=$((kalan+1)); echo "  ✗ $1 — '$2' OLMAMALI: $3" ;; *) gecen=$((gecen+1)); echo "  ✓ $1" ;; esac; }
T=$(mktemp -d); trap 'rm -r -- "$T" 2>/dev/null' EXIT INT TERM
export GUNLUK_PLAN_TARIH="2026-01-10" DEFTER_JETON_YOL="$T/jeton-yok" DEFTER_UC="http://127.0.0.1:9"
cat > "$T/gorev.sh" <<'EOS'
#!/usr/bin/env bash
T="$(dirname "${BASH_SOURCE[0]}")"
case "$1" in
  adim)    printf '%s\n' "$*" >> "$T/adim.log"; [ "${ADIM_RC:-0}" -eq 0 ] || exit "$ADIM_RC" ;;
  durum)   printf '%s\n' "$*" >> "$T/durum.log"; [ "${DURUM_RC:-0}" -eq 0 ] || exit "$DURUM_RC" ;;
  ekle)    printf '%s\n' "$*" >> "$T/ekle.log"; [ "${EKLE_RC:-0}" -eq 0 ] || exit "$EKLE_RC"; echo "${EKLE_CIKTI:-📌 gorev_NEW1 · menzil · tür? · aciliyet? — doğan görev}" ;;
  dogan)   printf '%s\n' "$*" >> "$T/dogan.log"; [ "${DOGAN_RC:-0}" -eq 0 ] || exit "$DOGAN_RC" ;;
  *) printf '%s\n' "$*" >> "$T/baska.log"; exit 2 ;;
esac
EOS
chmod +x "$T/gorev.sh"; export GUNLUK_PLAN_GOREV_SH="$T/gorev.sh"
printf '#!/usr/bin/env bash\n[ "${ADIMLAR_RC:-0}" -eq 0 ] || exit "$ADIMLAR_RC"\ncat "%s/kayit-$1.txt" 2>/dev/null || exit 3\n' "$T" > "$T/oku.sh"; export HASAT_KAYIT_OKU="$T/oku.sh"   # kayıt okuyucu (gorev.sh paket kopyasına fiil EKLENMEDİ)
# fikstür: kayit <id> <durum> [adım metni ...] — her adım "ts|metin"
kayit(){ local id="$1" d="$2"; shift 2; { printf 'KAYIT\tgorev_%s\t%s\t-\tbaşlık %s\t%s\t%s\n' "$id" "$d" "$id" "${K_KUTU-menzil}" "${K_OZET-Havuz kaydı örneği için beş kelimelik ad: açıklama}"; for a in "$@"; do printf 'ADIM\t%s\t%s\n' "${a%%|*}" "${a#*|}"; done; } > "$T/kayit-gorev_$id.txt"; }
temiz(){ rm -f "$T/adim.log" "$T/durum.log" "$T/baska.log" "$T/ekle.log" "$T/dogan.log"; }
echo "— kullanım"
bash "$HS" >/dev/null 2>&1; kapi "U1 komutsuz rc 2" "2" "$?"
bash "$HS" durum yanlis >/dev/null 2>&1; kapi "U2 gorev_ öneksiz kimlik rc 2" "2" "$?"
bash "$HS" durum gorev_A1 --taze-gun 0 >/dev/null 2>&1; kapi "U3 --taze-gun 0 rc 2" "2" "$?"
bash "$HS" ac gorev_A1 "kısa" >/dev/null 2>&1; kapi "U4 ac gerekçesi 5 harften kısa rc 2" "2" "$?"
for b in --taze-gun --birlesme --yuzey --depo --sonuc --olcum --sinif --soz --kapandi --tarih; do timeout 10 bash "$HS" durum gorev_A1 "$b" >/dev/null 2>&1; r=$?; [ "$r" = 2 ] || { kalan=$((kalan+1)); echo "  ✗ U5 $b değersiz: rc $r (124 = sonsuz döngü)"; continue; }; done
kapi "U5 değer isteyen her bayrak (10) değersiz verilince rc 2, döngüye girmez (göz tur 1)" "2" "$(timeout 10 bash "$HS" dogrula gorev_A1 --sonuc var --olcum >/dev/null 2>&1; echo $?)"
echo "— durum: kapı (fikstür günü 2026-01-10, pencere 7)"
kayit A1 havuz "2026-01-01T10:00:00Z|[kanıt] ilk gözlem"
c="$(bash "$HS" durum gorev_A1 2>&1)"; rc=$?
kapi "D1 doğrulama yok → HASAT=OLMAZ rc 1" "1:HASAT=OLMAZ" "$rc:$(grep '^HASAT=' <<<"$c")"
iceriyor "D1b NEDEN doğrulama komutunu gösterir" "hasat.sh dogrula gorev_A1" "$c"
iceriyor "D1c DOGRULAMA=yok" "DOGRULAMA=yok" "$c"
kayit A2 havuz "2026-01-01T10:00:00Z|[kanıt] ilk" "2026-01-08T09:00:00Z|[doğrulama: var] sınıf=olcum · ölçüm: grep -c x y.sh · tarih=2026-01-08 · yüzey=- · sorun duruyor"
c="$(bash "$HS" durum gorev_A2 2>&1)"; rc=$?
kapi "D2 2 gün önce 'var' → HASAT=OLUR rc 0" "0:HASAT=OLUR" "$rc:$(grep '^HASAT=' <<<"$c")"
kapi "D2b tarih adım metnindeki tarih= alanından, yaş 2" "2026-01-08:2" "$(grep '^DOGRULAMA_TARIH=' <<<"$c" | cut -d= -f2):$(grep '^DOGRULAMA_YAS_GUN=' <<<"$c" | cut -d= -f2)"
kayit A3 havuz "2026-01-02T09:00:00Z|[doğrulama: var] sınıf=olcum · ölçüm: x · tarih=2026-01-02 · yüzey=- · duruyor"
c="$(bash "$HS" durum gorev_A3 2>&1)"; rc=$?
kapi "D3 8 gün önce (pencere 7) → bayat, OLMAZ rc 1" "1:HASAT=OLMAZ" "$rc:$(grep '^HASAT=' <<<"$c")"
iceriyor "D3b NEDEN 'bayat' ve yeniden ölçüm ister" "bayat — yeniden ölçülmeden hasat edilmez" "$c"
c="$(bash "$HS" durum gorev_A3 --taze-gun 10 2>&1)"; kapi "D3c --taze-gun 10 ile aynı kayıt OLUR" "HASAT=OLUR" "$(grep '^HASAT=' <<<"$c")"
kayit A3b havuz "2026-01-03T09:00:00Z|[doğrulama: var] sınıf=olcum · ölçüm: x · tarih=2026-01-03 · yüzey=-"
c="$(bash "$HS" durum gorev_A3b 2>&1)"; kapi "D3d pencere sınırı: TAM 7 gün önce doğrulama hâlâ taze → OLUR (8 gün D3'te OLMAZ)" "OLUR:7" "$(grep '^HASAT=' <<<"$c" | cut -d= -f2):$(grep '^DOGRULAMA_YAS_GUN=' <<<"$c" | cut -d= -f2)"
kayit A4 havuz "2026-01-01T09:00:00Z|[doğrulama: var] … tarih=2026-01-01" "2026-01-09T09:00:00Z|[doğrulama: düzelmiş] sınıf=pr · ölçüm: gh pr view 12 · tarih=2026-01-09 · kendiliğinden kapandı: PR #12"
c="$(bash "$HS" durum gorev_A4 2>&1)"; rc=$?
kapi "D4 SON ölçüm 'düzelmiş' (öncekinde var olsa da) → OLMAZ, DOGRULAMA=duzelmis" "1:duzelmis" "$rc:$(grep '^DOGRULAMA=' <<<"$c" | cut -d= -f2)"
iceriyor "D4b NEDEN kapanışı gösterir" "kapanır" "$c"
kayit A5 havuz "2026-01-09T09:00:00Z|[doğrulama: ölçülemedi] sınıf=olcum · ölçüm: ssh … · tarih=2026-01-09 · sunucuya ulaşılamadı"
c="$(bash "$HS" durum gorev_A5 2>&1)"; rc=$?; kapi "D5 son ölçüm 'ölçülemedi' → OLMAZ rc 1 (olur UYDURULMAZ)" "1:OLMAZ" "$rc:$(grep '^HASAT=' <<<"$c" | cut -d= -f2)"
kayit A6 acik "2026-01-09T09:00:00Z|[doğrulama: var] sınıf=olcum · ölçüm: x · tarih=2026-01-09"
c="$(bash "$HS" durum gorev_A6 2>&1)"; rc=$?; kapi "D6 kayıt havuzda değil (acik) → OLMAZ, NEDEN durumu söyler" "1:1" "$rc:$(grep -c 'havuzda değil (durum: acik)' <<<"$c")"
kayit A7 havuz "|[doğrulama: var] sınıf=olcum · ölçüm: x · tarihsiz metin"
c="$(bash "$HS" durum gorev_A7 2>&1)"; rc=$?; kapi "D7 tarih= yok ve zaman damgası yok → ÖLÇÜLEMEDİ rc 3 (taze DENMEZ)" "3:ÖLÇÜLEMEDİ" "$rc:$(grep '^HASAT=' <<<"$c" | cut -d= -f2)"
kayit A8 havuz "2026-01-09T09:00:00Z|[doğrulama: var] sınıf=olcum · ölçüm: x · (tarih alanı yok) · yüzey=-"
c="$(bash "$HS" durum gorev_A8 2>&1)"; kapi "D8 tarih= yoksa zaman damgasından okunur → OLUR, yaş 1" "OLUR:1" "$(grep '^HASAT=' <<<"$c" | cut -d= -f2):$(grep '^DOGRULAMA_YAS_GUN=' <<<"$c" | cut -d= -f2)"
kayit A9 havuz "2026-02-01T09:00:00Z|[doğrulama: var] sınıf=olcum · ölçüm: x · tarih=2026-02-01"
c="$(bash "$HS" durum gorev_A9 2>&1)"; rc=$?; kapi "D9 gelecek tarihli doğrulama → ÖLÇÜLEMEDİ rc 3" "3:ÖLÇÜLEMEDİ" "$rc:$(grep '^HASAT=' <<<"$c" | cut -d= -f2)"
c="$(GUNLUK_PLAN_TARIH=bozuk bash "$HS" durum gorev_A2 2>&1)"; rc=$?; kapi "D10 bugünün tarihi bozuk → ÖLÇÜLEMEDİ rc 3" "3" "$rc"
ADIMLAR_RC=3 bash "$HS" durum gorev_A2 >/dev/null 2>&1; kapi "D11 kayıt okunamazsa rc 3, 'olur' denmez" "3" "$?"
bash "$HS" durum gorev_YOK >/dev/null 2>&1; kapi "D11b olmayan kayıt rc 3" "3" "$?"
kayit A10 havuz "2026-01-09T09:00:00Z|[doğrulama: geçti] sınıf=pr · ölçüm: MUHAKKİK görev hükmü (bulgu hükmü değil)"
c="$(bash "$HS" durum gorev_A10 2>&1)"; kapi "D12 MUHAKKİK'in görev hükmü (geçti/kaldı) bulgu doğrulaması SAYILMAZ → DOGRULAMA=yok" "yok" "$(grep '^DOGRULAMA=' <<<"$c" | cut -d= -f2)"
echo "— birleşme: --birlesme tarihi ve --yuzey (git)"
c="$(bash "$HS" durum gorev_A2 --birlesme 2026-01-09 2>&1)"; rc=$?
kapi "B1 doğrulamadan (01-08) SONRA birleşme (01-09) → OLMAZ rc 1" "1:OLMAZ" "$rc:$(grep '^HASAT=' <<<"$c" | cut -d= -f2)"
iceriyor "B1b NEDEN yüzeyde birleşmeyi söyler" "ilgili yüzeyde doğrulamadan sonra" "$c"
c="$(bash "$HS" durum gorev_A2 --birlesme 2026-01-08 2>&1)"; kapi "B1c aynı gün birleşme de yeniden ölçüm ister (≥)" "OLMAZ" "$(grep '^HASAT=' <<<"$c" | cut -d= -f2)"
c="$(bash "$HS" durum gorev_A2 --birlesme 2026-01-05 2>&1)"; kapi "B2 doğrulamadan ÖNCE birleşme → OLUR, BIRLESME basılır" "OLUR:2026-01-05" "$(grep '^HASAT=' <<<"$c" | cut -d= -f2):$(grep '^BIRLESME=' <<<"$c" | cut -d= -f2)"
bash "$HS" durum gorev_A2 --birlesme 9-1-2026 >/dev/null 2>&1; kapi "B3 bozuk --birlesme rc 2" "2" "$?"
bash "$HS" durum gorev_A2 --birlesme 2026-01-05 --yuzey x >/dev/null 2>&1; kapi "B4 --birlesme ile --yuzey birlikte rc 2" "2" "$?"
# geçici git deposu: yuzey/a.sh son commit 2026-01-09 (doğrulama 01-08'den sonra), yuzey/eski.sh 2026-01-03
R="$T/depo"; mkdir -p "$R/yuzey"; git -C "$R" init -q 2>/dev/null; git -C "$R" config user.email t@t; git -C "$R" config user.name t
echo 1 > "$R/yuzey/eski.sh"; git -C "$R" add -A; GIT_AUTHOR_DATE="2026-01-03T10:00:00+03:00" GIT_COMMITTER_DATE="2026-01-03T10:00:00+03:00" git -C "$R" commit -qm eski
echo 2 > "$R/yuzey/a.sh"; git -C "$R" add -A; GIT_AUTHOR_DATE="2026-01-09T10:00:00+03:00" GIT_COMMITTER_DATE="2026-01-09T10:00:00+03:00" git -C "$R" commit -qm yeni
c="$(bash "$HS" durum gorev_A2 --yuzey yuzey/a.sh --depo "$R" 2>&1)"; rc=$?
kapi "B5 --yuzey: son commit 01-09 git'ten okunur → OLMAZ, BIRLESME=2026-01-09" "1:2026-01-09" "$rc:$(grep '^BIRLESME=' <<<"$c" | cut -d= -f2)"
c="$(bash "$HS" durum gorev_A2 --yuzey yuzey/eski.sh --depo "$R" 2>&1)"; kapi "B6 --yuzey eski dosya (01-03) → OLUR" "OLUR" "$(grep '^HASAT=' <<<"$c" | cut -d= -f2)"
echo 3 > "$R/yuzey/kayitsiz.sh"; c="$(bash "$HS" durum gorev_A2 --yuzey yuzey/kayitsiz.sh --depo "$R" 2>&1)"; kapi "B7 yüzey diskte var ama hiç commit görmemiş → birleşme yok, OLUR (BIRLESME=-)" "OLUR:-" "$(grep '^HASAT=' <<<"$c" | cut -d= -f2):$(grep '^BIRLESME=' <<<"$c" | cut -d= -f2)"
c="$(bash "$HS" durum gorev_A2 --yuzey yuzey/hic-yok.sh --depo "$R" 2>&1)"; kapi "B7b yüzey ne diskte ne git'te → ÖLÇÜLEMEDİ ('birleşme yok' uydurulmaz)" "ÖLÇÜLEMEDİ:ÖLÇÜLEMEDİ" "$(grep '^HASAT=' <<<"$c" | cut -d= -f2):$(grep '^BIRLESME=' <<<"$c" | cut -d= -f2)"
c="$(bash "$HS" durum gorev_A2 --yuzey yuzey/a.sh --depo "$T/git-degil" 2>&1)"; rc=$?
kapi "B8 depo git değil → BIRLESME=ÖLÇÜLEMEDİ, HASAT=ÖLÇÜLEMEDİ rc 3 ('birleşme yok' UYDURULMAZ)" "3:ÖLÇÜLEMEDİ:ÖLÇÜLEMEDİ" "$rc:$(grep '^BIRLESME=' <<<"$c" | cut -d= -f2):$(grep '^HASAT=' <<<"$c" | cut -d= -f2)"
echo "— dogrula: ölçümü kayda yazar (MUHAKKİK biçimi)"
temiz; c="$(bash "$HS" dogrula gorev_A1 --sonuc var --olcum "grep -c TODO x.sh → 3" --yuzey - --soz "Sorun duruyor, üç yerde." 2>&1)"; rc=$?
kapi "Y1 var: adım yazılır rc 0" "0" "$rc"
kapi "Y1b adım metni: [doğrulama: var] sınıf=olcum · ölçüm: … · tarih=<bugün> · <söz>" "adim gorev_A1 [doğrulama: var] sınıf=olcum · tarih=2026-01-10 · yüzey=- · ölçüm: grep -c TODO x.sh → 3 · Sorun duruyor, üç yerde." "$(cat "$T/adim.log" 2>/dev/null)"
kapi "Y1c var: durum YAZILMAZ (kayıt havuzda kalır)" "yok" "$([ -e "$T/durum.log" ] && echo var || echo yok)"
iceriyor "Y1d çıktı DOGRULAMA=var ve tarih" "DOGRULAMA_TARIH=2026-01-10" "$c"
temiz; bash "$HS" dogrula gorev_A1 --sonuc var >/dev/null 2>&1; kapi "Y2 --olcum yoksa rc 2, adım yazılmaz (ölçümsüz doğrulama yok)" "2:yok" "$?:$([ -e "$T/adim.log" ] && echo var || echo yok)"
bash "$HS" dogrula gorev_A1 --sonuc belki --olcum x >/dev/null 2>&1; kapi "Y3 bozuk --sonuc rc 2" "2" "$?"
bash "$HS" dogrula gorev_A1 --sonuc var --olcum x --sinif tahmin >/dev/null 2>&1; kapi "Y3b bozuk --sinif rc 2" "2" "$?"
temiz; bash "$HS" dogrula gorev_A1 --sonuc duzelmis --olcum "gh pr view 12" >/dev/null 2>&1; kapi "Y4 düzelmiş ama --kapandi yok → rc 2, hiçbir şey yazılmaz" "2:yok" "$?:$([ -e "$T/adim.log" ] || [ -e "$T/durum.log" ] && echo var || echo yok)"
temiz; c="$(bash "$HS" dogrula gorev_A1 --sonuc duzelmis --olcum "gh pr view 12 --json state" --sinif pr --kapandi "PR #12" --soz "Aynı satır başka işle düzeldi." 2>&1)"; rc=$?
kapi "Y5 düzelmiş + --kapandi: rc 0, adım 'kendiliğinden kapandı: PR #12' taşır" "0:1" "$rc:$(grep -c 'adim gorev_A1 \[doğrulama: düzelmiş\] sınıf=pr · tarih=2026-01-10 · ölçüm: gh pr view 12 --json state · kendiliğinden kapandı: PR #12 · Aynı satır' "$T/adim.log" 2>/dev/null)"
kapi "Y5b kayıt iptal ile kapanır, gerekçe 'kendiliğinden kapandı — PR #12: <söz>'" "durum gorev_A1 iptal kendiliğinden kapandı — PR #12: Aynı satır başka işle düzeldi." "$(cat "$T/durum.log" 2>/dev/null)"
iceriyor "Y5c çıktı KAPANDI=PR #12" "KAPANDI=PR #12" "$c"
temiz; bash "$HS" dogrula gorev_A1 --sonuc var --olcum x --kapandi "PR #1" >/dev/null 2>&1; kapi "Y6 --kapandi yalnız düzelmişle: var ile rc 2" "2" "$?"
temiz; c="$(bash "$HS" dogrula gorev_A1 --sonuc olculemedi --olcum "ssh kutu" --soz "Sunucuya ulaşılamadı." 2>&1)"; rc=$?
kapi "Y7 ölçülemedi: adım '[doğrulama: ölçülemedi]' yazılır, kapanış yok" "0:1:yok" "$rc:$(grep -c '^adim gorev_A1 \[doğrulama: ölçülemedi\]' "$T/adim.log"):$([ -e "$T/durum.log" ] && echo var || echo yok)"
temiz; ADIM_RC=1 bash "$HS" dogrula gorev_A1 --sonuc var --olcum x --yuzey - >/dev/null 2>&1; kapi "Y8 defter adımı reddederse rc 1 (sessiz başarı yok)" "1" "$?"
temiz; DURUM_RC=1 bash "$HS" dogrula gorev_A1 --sonuc duzelmis --olcum x --kapandi "c0ffee" >/dev/null 2>&1; kapi "Y9 kapanış reddedilirse rc 1" "1" "$?"
temiz; bash "$HS" dogrula gorev_A1 --sonuc var --olcum x --yuzey - --tarih 2026-01-04 >/dev/null 2>&1; kapi "Y10 --tarih verilirse metne o yazılır" "1" "$(grep -c 'tarih=2026-01-04' "$T/adim.log")"
bash "$HS" dogrula gorev_A1 --sonuc var --olcum x --tarih 4.1.2026 >/dev/null 2>&1; kapi "Y10b bozuk --tarih rc 2" "2" "$?"
temiz; bash "$HS" dogrula gorev_A1 --sonuc var --olcum x >/dev/null 2>&1; kapi "Y11 'var' yüzeysiz yazılmaz rc 2 (birleşme sonradan ölçülemezdi)" "2:yok" "$?:$([ -e "$T/adim.log" ] && echo var || echo yok)"
temiz; bash "$HS" dogrula gorev_A1 --sonuc var --olcum x --yuzey yuzey/a.sh --depo "$R" >/dev/null 2>&1; kapi "Y12 --yuzey + --depo: adıma MUTLAK yol yazılır" "1" "$(grep -c "yüzey=$R/yuzey/a.sh" "$T/adim.log" 2>/dev/null)"
temiz; bash "$HS" dogrula gorev_A1 --sonuc var --olcum x --yuzey "$T/git-degil/x.sh" >/dev/null 2>&1; kapi "Y13 yüzey git deposunda değil → rc 2, adım yazılmaz" "2:yok" "$?:$([ -e "$T/adim.log" ] && echo var || echo yok)"
temiz; DURUM_RC=1 bash "$HS" dogrula gorev_A1 --sonuc duzelmis --olcum x --kapandi "PR #7" >/dev/null 2>&1; r1=$?; bash "$HS" dogrula gorev_A1 --sonuc duzelmis --olcum x --kapandi "PR #7" >/dev/null 2>&1; r2=$?
kapi "Y14 kapanış reddedilince (rc 1) aynı komut yeniden koşulur ve kayıt kapanır (rc 0, iki iptal denemesi kütükte)" "1:0:2" "$r1:$r2:$(grep -c '^durum gorev_A1 iptal kendiliğinden kapandı — PR #7' "$T/durum.log")"
echo "— bayraksız durum: yüzey SON doğrulama adımından okunur (DALGIÇ ön-göz tur 1: sirada-bak yolu birleşmeyi hiç ölçmüyordu)"
kayit D1 havuz "2026-01-08T09:00:00Z|[doğrulama: var] sınıf=olcum · ölçüm: x · tarih=2026-01-08 · yüzey=$R/yuzey/a.sh · duruyor"
c="$(bash "$HS" durum gorev_D1 2>&1)"; rc=$?
kapi "D13 kayıttaki yüzeyde doğrulamadan sonra birleşme (01-09) → bayraksız da OLMAZ rc 1" "1:2026-01-09:$R/yuzey/a.sh" "$rc:$(grep '^BIRLESME=' <<<"$c" | cut -d= -f2):$(grep '^YUZEY=' <<<"$c" | cut -d= -f2)"
kayit D2 havuz "2026-01-08T09:00:00Z|[doğrulama: var] sınıf=olcum · ölçüm: x · tarih=2026-01-08 · yüzey=$R/yuzey/eski.sh"
c="$(bash "$HS" durum gorev_D2 2>&1)"; kapi "D14 kayıttaki yüzey eski (01-03) → OLUR" "OLUR" "$(grep '^HASAT=' <<<"$c" | cut -d= -f2)"
kayit D3 havuz "2026-01-08T09:00:00Z|[doğrulama: var] sınıf=olcum · ölçüm: x · tarih=2026-01-08 · elle yazılmış, yüzeysiz"
c="$(bash "$HS" durum gorev_D3 2>&1)"; rc=$?; kapi "D15 yüzeysiz 'var' (eski biçim) → OLMAZ, NEDEN yüzey ister" "1:1" "$rc:$(grep -c 'son doğrulamada yüzey yok' <<<"$c")"
kayit D4 havuz "2026-01-08T09:00:00Z|[doğrulama: var] sınıf=olcum · ölçüm: x · tarih=2026-01-08 · yüzey=$T/git-degil/x.sh"
c="$(bash "$HS" durum gorev_D4 2>&1)"; rc=$?; kapi "D16 kayıttaki yüzey ölçülemiyor (git değil) → ÖLÇÜLEMEDİ rc 3" "3:ÖLÇÜLEMEDİ" "$rc:$(grep '^HASAT=' <<<"$c" | cut -d= -f2)"
c="$(bash "$HS" durum gorev_D1 --birlesme 2026-01-05 2>&1)"; kapi "D17 --birlesme bayrağı kayıttaki yüzeyi ezer (açık ölçüm kazanır)" "OLUR" "$(grep '^HASAT=' <<<"$c" | cut -d= -f2)"
temiz; bash "$HS" dogrula gorev_A1 --sonuc var --olcum x --yuzey yuzey/yazim-hatasi.sh --depo "$R" >/dev/null 2>&1; kapi "Y15 diskte olmayan yüzey 'var' ile yazılmaz rc 2" "2:yok" "$?:$([ -e "$T/adim.log" ] && echo var || echo yok)"
kayit D5 havuz "2026-01-08T09:00:00Z|[doğrulama: var] sınıf=olcum · ölçüm: x · tarih=2026-01-08 · yüzey=$R/yuzey/hic-olmamis.sh · duruyor"
c="$(bash "$HS" durum gorev_D5 2>&1)"; rc=$?; kapi "D18 kayıttaki yüzey hiç var olmamış (commit yok, disk yok) → ÖLÇÜLEMEDİ rc 3, 'birleşme yok' SAYILMAZ" "3:ÖLÇÜLEMEDİ" "$rc:$(grep '^HASAT=' <<<"$c" | cut -d= -f2)"
mkdir -p "$R/bos luklu"; echo 1 > "$R/bos luklu/b.sh"; git -C "$R" add -A; GIT_AUTHOR_DATE="2026-01-09T11:00:00+03:00" GIT_COMMITTER_DATE="2026-01-09T11:00:00+03:00" git -C "$R" commit -qm bosluk
kayit D6 havuz "2026-01-08T09:00:00Z|[doğrulama: var] sınıf=olcum · ölçüm: x · tarih=2026-01-08 · yüzey=$R/bos luklu/b.sh · duruyor"
c="$(bash "$HS" durum gorev_D6 2>&1)"; kapi "D19 boşluklu yüzey yolu kesilmeden okunur → birleşme 01-09 görülür, OLMAZ" "OLMAZ:$R/bos luklu/b.sh" "$(grep '^HASAT=' <<<"$c" | cut -d= -f2):$(grep '^YUZEY=' <<<"$c" | cut -d= -f2-)"
git -C "$R" rm -q yuzey/eski.sh; GIT_AUTHOR_DATE="2026-01-09T12:00:00+03:00" GIT_COMMITTER_DATE="2026-01-09T12:00:00+03:00" git -C "$R" commit -qm sil
c="$(bash "$HS" durum gorev_D2 2>&1)"; kapi "D20 yüzey dosyası doğrulamadan sonra silindi → silme commit'i birleşmedir, OLMAZ" "OLMAZ:2026-01-09" "$(grep '^HASAT=' <<<"$c" | cut -d= -f2):$(grep '^BIRLESME=' <<<"$c" | cut -d= -f2)"
temiz; bash "$HS" dogrula gorev_A1 --sonuc var --olcum "grep tarih=2020-01-01 · tarih=2020-01-02 x.sh" --yuzey - --soz "yüzey=/sahte · tarih=2020-01-03" >/dev/null 2>&1
{ printf 'KAYIT\tgorev_D7\thavuz\t-\tb\n'; printf 'ADIM\t2026-01-09T09:00:00Z\t%s\n' "$(cut -d' ' -f3- "$T/adim.log")"; } > "$T/kayit-gorev_D7.txt"
c="$(bash "$HS" durum gorev_D7 2>&1)"; kapi "D21 ölçüm/söz metnindeki 'tarih=' ve 'yüzey=' yazıcının alanlarını EZMEZ (tarih 2026-01-10 · yüzey - · OLUR)" "2026-01-10:-:OLUR" "$(grep '^DOGRULAMA_TARIH=' <<<"$c" | cut -d= -f2):$(grep '^YUZEY=' <<<"$c" | cut -d= -f2):$(grep '^HASAT=' <<<"$c" | cut -d= -f2)"
echo "— uzak depo: bayat origin/main'den hüküm verilmez (DALGIÇ tur 2)"
U="$T/uzak.git"; git init -q --bare "$U" 2>/dev/null; git -C "$U" symbolic-ref HEAD refs/heads/main
Y="$T/yerel"; mkdir -p "$Y"; git -C "$Y" init -q -b main 2>/dev/null; git -C "$Y" config user.email t@t; git -C "$Y" config user.name t; echo 1 > "$Y/k.sh"; git -C "$Y" add -A
GIT_AUTHOR_DATE="2026-01-02T10:00:00+03:00" GIT_COMMITTER_DATE="2026-01-02T10:00:00+03:00" git -C "$Y" commit -qm ilk; git -C "$Y" remote add origin "$U"; git -C "$Y" push -q origin main 2>/dev/null; git -C "$Y" fetch -q origin 2>/dev/null
B="$T/baska"; git clone -q "$U" "$B" 2>/dev/null; git -C "$B" config user.email t@t; git -C "$B" config user.name t; echo 2 > "$B/k.sh"; git -C "$B" add -A
GIT_AUTHOR_DATE="2026-01-09T10:00:00+03:00" GIT_COMMITTER_DATE="2026-01-09T10:00:00+03:00" git -C "$B" commit -qm uzakta-birlesti; git -C "$B" push -q origin HEAD:main 2>/dev/null
kayit F1 havuz "2026-01-08T09:00:00Z|[doğrulama: var] sınıf=olcum · ölçüm: x · tarih=2026-01-08 · yüzey=$Y/k.sh"
kapi "F0 fikstür: yerel origin/main bayat (uzaktaki 01-09 birleşmesini henüz görmüyor)" "2026-01-02" "$(git -C "$Y" log -1 --format=%cs origin/main -- k.sh)"
c="$(bash "$HS" durum gorev_F1 2>&1)"; kapi "F1 ölçümden önce fetch: uzaktaki 01-09 birleşmesi görülür → OLMAZ" "OLMAZ:2026-01-09" "$(grep '^HASAT=' <<<"$c" | cut -d= -f2):$(grep '^BIRLESME=' <<<"$c" | cut -d= -f2)"
git -C "$Y" remote set-url origin "$T/yok-boyle-uzak.git"
c="$(bash "$HS" durum gorev_F1 2>&1)"; rc=$?; kapi "F2 uzak depo tazelenemiyor → ÖLÇÜLEMEDİ rc 3 (bayat kopyadan 'birleşme yok' denmez)" "3:ÖLÇÜLEMEDİ" "$rc:$(grep '^HASAT=' <<<"$c" | cut -d= -f2)"
echo "— ac: kapıdan geçerse havuz kaydı YERİNDE kalır, ondan YENİ görev doğar (1.20.0)"
temiz; c="$(bash "$HS" ac gorev_A2 "Meşveret 9. madde; Sultan önem 2" --kip otomatik 2>&1)"; rc=$?
kapi "A1 OLUR + otomatik → rc 0, havuz kaydına durum YAZILMAZ (yerinde kalır)" "0:yok" "$rc:$([ -e "$T/durum.log" ] && echo var || echo yok)"
iceriyor "A1b gorev.sh ekle: başlık + kutu + özet + kaynak" "ekle başlık A2 --kutu menzil --ozet Havuz kaydı örneği için beş kelimelik ad: açıklama --kaynak-kim REİS --kaynak-nereden Hasat (Otomatik)" "$(cat "$T/ekle.log" 2>/dev/null)"
iceriyor "A1c doğan görevin açılış adımı kipi söyler (Otomatik Hasat)" "adim gorev_NEW1 havuz kaydı gorev_A2'den Otomatik Hasat ile açıldı · Meşveret 9. madde; Sultan önem 2 · son doğrulama 2026-01-08 var" "$(cat "$T/adim.log" 2>/dev/null)"
kapi "A1d bağ havuz kaydının doğan görevler alanına yazıldı (gorev.sh dogan havuz yeni)" "dogan gorev_A2 gorev_NEW1" "$(cat "$T/dogan.log" 2>/dev/null)"
iceriyor "A1e çıktı: DOGAN= ve havuz kaydı yerinde" "DOGAN=gorev_NEW1" "$c"
iceriyor "A1f çıktı: havuz kaydı yerinde" "HAVUZ_KAYDI=gorev_A2 (yerinde, durum havuz)" "$c"
temiz; bash "$HS" ac gorev_A2 "kipsiz" >/dev/null 2>&1; kapi "A1g --kip yok → rc 2, hiçbir şey yazılmaz" "2:yok" "$?:$([ -e "$T/ekle.log" ] && echo var || echo yok)"
temiz; bash "$HS" ac gorev_A2 "kötü kip" --kip belki >/dev/null 2>&1; kapi "A1h --kip geçersiz → rc 2" "2:yok" "$?:$([ -e "$T/ekle.log" ] && echo var || echo yok)"
echo "— ac --kip seansli: Sultan'ın kabul cevabı kayıtta olmalı"
temiz; bash "$HS" ac gorev_A2 "cevapsız sunum" --kip seansli >/dev/null 2>&1; kapi "S1 Seanslı + Sultan cevabı kayıtta YOK → rc 1, görev doğmaz" "1:yok" "$?:$([ -e "$T/ekle.log" ] && echo var || echo yok)"
kayit AS havuz "2026-01-08T09:00:00Z|[doğrulama: var] sınıf=olcum · ölçüm: x · tarih=2026-01-08 · yüzey=-" "2026-01-09T09:00:00Z|[Seanslı Hasat] kabul · D1 2026-01-09 Sultan: kabul (sohbet · s_1 · \"olur\" · beyan:REİS)"
temiz; c="$(bash "$HS" ac gorev_AS "seansta kabul" --kip seansli 2>&1)"; rc=$?
kapi "S2 Seanslı + son cevap 'kabul' → rc 0, açılış adımı 'Seanslı Hasat ile açıldı'" "0:1" "$rc:$(grep -c "havuz kaydı gorev_AS'den Seanslı Hasat ile açıldı" "$T/adim.log" 2>/dev/null)"
kayit AB havuz "2026-01-08T09:00:00Z|[doğrulama: var] sınıf=olcum · ölçüm: x · tarih=2026-01-08 · yüzey=-" "2026-01-09T09:00:00Z|[Seanslı Hasat] kabul · D1 2026-01-09 Sultan: kabul (…)" "2026-01-09T10:00:00Z|[Seanslı Hasat] başka sun · D1 2026-01-09 Sultan: başka sun (…)"
temiz; bash "$HS" ac gorev_AB "başka sun sonrası" --kip seansli >/dev/null 2>&1; kapi "S3 SON cevap 'başka sun' (öncesinde kabul olsa da) → rc 1, görev doğmaz" "1:yok" "$?:$([ -e "$T/ekle.log" ] && echo var || echo yok)"
temiz; bash "$HS" ac gorev_AS "düzeltmeyle" --kip seansli --baslik "Düzeltilmiş görev başlığı" --ozet "Düzeltilmiş ad beş kelime burada: açıklama" --kutu akar --atanan ASIL >/dev/null 2>&1
iceriyor "S4 --baslik/--ozet/--kutu/--atanan doğan göreve aynen gider" "ekle Düzeltilmiş görev başlığı --kutu akar --ozet Düzeltilmiş ad beş kelime burada: açıklama --kaynak-kim REİS --kaynak-nereden Hasat (Seanslı) --atanan ASIL" "$(cat "$T/ekle.log" 2>/dev/null)"
echo "— ac: doğan görev hata yolları ve mevcut kapı"
K_OZET="" kayit AO havuz "2026-01-08T09:00:00Z|[doğrulama: var] sınıf=olcum · ölçüm: x · tarih=2026-01-08 · yüzey=-"
temiz; bash "$HS" ac gorev_AO "özetsiz kayıt" --kip otomatik >/dev/null 2>&1; kapi "E1 özet yok (kayıtta da, bayrakta da) → rc 2, görev doğmaz (özet uydurulmaz)" "2:yok" "$?:$([ -e "$T/ekle.log" ] && echo var || echo yok)"
temiz; EKLE_RC=1 bash "$HS" ac gorev_A2 "defter ekle reddediyor" --kip otomatik >/dev/null 2>&1; kapi "E2 defter doğan görevi reddederse rc 1, adım ve bağ YAZILMAZ" "1:yok:yok" "$?:$([ -e "$T/adim.log" ] && echo var || echo yok):$([ -e "$T/dogan.log" ] && echo var || echo yok)"
temiz; EKLE_CIKTI="kayıt alındı ama kimlik yok" bash "$HS" ac gorev_A2 "kimliksiz" --kip otomatik >/dev/null 2>&1; kapi "E3 doğan görev kimliği okunamazsa rc 1, bağ YAZILMAZ" "1:yok" "$?:$([ -e "$T/dogan.log" ] && echo var || echo yok)"
temiz; DOGAN_RC=1 bash "$HS" ac gorev_A2 "bağ yazılamıyor" --kip otomatik >/dev/null 2>&1; kapi "E4 bağ yazılamazsa rc 1 (doğan görev açıldı, elle gorev.sh dogan söylenir)" "1" "$?"
temiz; bash "$HS" ac gorev_A1 "doğrulamasız kayıt" --kip otomatik >/dev/null 2>&1; kapi "A2 doğrulamasız kayıt AÇILMAZ rc 1, görev doğmaz" "1:yok" "$?:$([ -e "$T/ekle.log" ] && echo var || echo yok)"
temiz; bash "$HS" ac gorev_A3 "bayat kayıt" --kip otomatik >/dev/null 2>&1; kapi "A3 bayat doğrulama AÇILMAZ rc 1" "1:yok" "$?:$([ -e "$T/ekle.log" ] && echo var || echo yok)"
temiz; bash "$HS" ac gorev_A2 "yüzeyde birleşme" --kip otomatik --birlesme 2026-01-09 >/dev/null 2>&1; kapi "A4 doğrulamadan sonra birleşme AÇILMAZ rc 1" "1:yok" "$?:$([ -e "$T/ekle.log" ] && echo var || echo yok)"
temiz; bash "$HS" ac gorev_A7 "ölçülemeyen" --kip otomatik >/dev/null 2>&1; kapi "A5 ÖLÇÜLEMEDİ → açılmaz rc 3" "3:yok" "$?:$([ -e "$T/ekle.log" ] && echo var || echo yok)"
temiz; ADIM_RC=1 bash "$HS" ac gorev_A2 "adım reddediyor" --kip otomatik >/dev/null 2>&1; kapi "A6 açılış adımı yazılamazsa rc 1, bağ yazılmaz" "1" "$?"
kapi "A7 hiçbir yol bilinmeyen gorev.sh fiili çağırmadı" "yok" "$([ -e "$T/baska.log" ] && echo var || echo yok)"
echo "— cevap: Seanslı Hasat'ın üç cevabı havuz kaydına adım olur (Sultan'ın sözü aktarılır, üretilmez)"
temiz; bash "$HS" cevap gorev_A2 kabul --oturum s_1 --soz "olur aç" >/dev/null 2>&1; rc=$?
kapi "C1 kabul: adım '[Seanslı Hasat] kabul · D1 … Sultan: kabul (sohbet · ref · \"söz\" · beyan:)'" "0:adim gorev_A2 [Seanslı Hasat] kabul · D1 2026-01-10 Sultan: kabul (sohbet · s_1 · \"olur aç\" · beyan:REİS)" "$rc:$(cat "$T/adim.log" 2>/dev/null)"
temiz; bash "$HS" cevap gorev_A2 baska-sun --oturum s_1 --soz "başkasını sun" >/dev/null 2>&1
iceriyor "C2 başka sun: adım '[Seanslı Hasat] başka sun · …'" "[Seanslı Hasat] başka sun · D1 2026-01-10 Sultan: başka sun" "$(cat "$T/adim.log" 2>/dev/null)"
temiz; bash "$HS" cevap gorev_A2 duzeltmeyle-kabul --oturum s_1 --soz "şöyle aç" --duzeltme "Kapı sorunu kapatılsın" >/dev/null 2>&1
iceriyor "C3 düzeltmeyle kabul: adım düzeltme cümlesini taşır" "[Seanslı Hasat] düzeltmeyle kabul · düzeltme: \"Kapı sorunu kapatılsın\" · D1 2026-01-10 Sultan: düzeltmeyle kabul" "$(cat "$T/adim.log" 2>/dev/null)"
temiz; bash "$HS" cevap gorev_A2 duzeltmeyle-kabul --oturum s_1 --soz "şöyle aç" >/dev/null 2>&1; kapi "C4 düzeltmeyle kabul --duzeltme'siz → rc 2, adım yok" "2:yok" "$?:$([ -e "$T/adim.log" ] && echo var || echo yok)"
temiz; bash "$HS" cevap gorev_A2 kabul --soz "olur" >/dev/null 2>&1; r1=$?; bash "$HS" cevap gorev_A2 kabul --oturum s_1 >/dev/null 2>&1; r2=$?
kapi "C5 A06: --oturum ya da --soz olmadan cevap YAZILMAZ (rc 2, adım yok)" "2:2:yok" "$r1:$r2:$([ -e "$T/adim.log" ] && echo var || echo yok)"
temiz; bash "$HS" cevap gorev_A2 belki --oturum s_1 --soz "x" >/dev/null 2>&1; kapi "C6 bilinmeyen cevap → rc 2" "2:yok" "$?:$([ -e "$T/adim.log" ] && echo var || echo yok)"
temiz; bash "$HS" cevap gorev_A6 kabul --oturum s_1 --soz "olur" >/dev/null 2>&1; kapi "C7 havuzda olmayan kayda cevap yazılmaz rc 1" "1:yok" "$?:$([ -e "$T/adim.log" ] && echo var || echo yok)"
echo "sonuç: $gecen geçti · $kalan kaldı"; [ "$kalan" -eq 0 ]
