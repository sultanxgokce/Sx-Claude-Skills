#!/usr/bin/env bash
# kosu-sar.test.sh — koşu kaydı sarmalayıcısının sınavı (hermetik: sahte kanon, sahte crontab, geçici kayıt dizini).
# Ölçtüğü (Nexus kokpit-ux/05 K1-K6): her koşu tam satır · sonuc kümesi · beyan protokolü (K4) · gözlem/tahmin iki kaynak ve
# çelişki (K5) · @reboot türetilemez · sahip/damga yoksa bilinmiyor/null (K3) · satır şeması 15 alan, geçerli JSON · komut yoksa olculemedi.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; S="$HERE/kosu-sar.sh"
T="$(mktemp -d)"; trap 'find "$T" -depth -delete' EXIT
gecti=0; dusen=0
ol() { if [ "$2" = "$3" ]; then gecti=$((gecti+1)); else dusen=$((dusen+1)); echo "  ✗ $1: beklenen[$3] gelen[$2]"; fi; }
alan() { tail -1 "$T/kayit/sinav."*.jsonl | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); v=d.get('$1'); print('null' if v is None else (str(v).lower() if isinstance(v,bool) else v))"; }
satir_sayisi() { cat "$T/kayit/sinav."*.jsonl 2>/dev/null | wc -l | tr -d ' '; }
# sahte kanon: sahipli+damgalı iş · damgasız iş · @reboot iş
cat > "$T/kanon" <<'K'
# sahip: NAZIR
# damga: /tmp/supur.log
35 * * * * flock -n /x bash /config/.claude/skills/kosu-kaydi/scripts/kosu-sar.sh supur -- echo supur
# açıklama satırı (sahip yok)
*/5 * * * * bash /config/.claude/skills/kosu-kaydi/scripts/kosu-sar.sh nobetci -- true
# sahip: NAZIR
@reboot bash /config/.claude/skills/kosu-kaydi/scripts/kosu-sar.sh acilis -- true
K
cp "$T/kanon" "$T/canli"; printf '#!/usr/bin/env bash\ncat "%s/canli"\n' "$T" > "$T/ct.sh"; chmod +x "$T/ct.sh"
export KOSU_KUTU=sinav KOSU_KAYIT_DIZ="$T/kayit" KOSU_KANON="$T/kanon" KOSU_CRONTAB_KOMUT="$T/ct.sh" KOSU_SIMDI="2026-10-09T12:00:00+03:00"

echo "════ K1 · her koşu tam satır, geçerli JSON, 15 alan ════"
bash "$S" supur -- echo merhaba >/dev/null; rc=$?
ol "K1 komut rc geçirildi" "$rc" "0"
ol "K1 bir satır yazıldı" "$(satir_sayisi)" "1"
ol "K1 15 alan" "$(tail -1 "$T"/kayit/sinav.*.jsonl | python3 -c 'import json,sys;print(len(json.loads(sys.stdin.read())))')" "15"
ol "K1 sonuc=tamam" "$(alan sonuc)" "tamam"
ol "K3 sahip kanondan" "$(alan sahip)" "NAZIR"
ol "K3 kutuk damgadan" "$(alan kutuk)" "/tmp/supur.log"
ol "K5 sonraki_planli canlıdan (35 dk)" "$(alan sonraki_planli)" "2026-10-09T12:35:00+03:00"
ol "K5 ifadeden_tahmin kanondan" "$(alan ifadeden_tahmin)" "2026-10-09T12:35:00+03:00"
ol "K5 tahmin=true · turetilemedi=false" "$(alan tahmin)/$(alan turetilemedi)" "true/false"

echo "════ K4 · sessiz başarı YALNIZ beyanla ════"
bash "$S" nobetci -- true >/dev/null
ol "K4 beyansız rc0+boş çıktı = tamam (çıkarım yok)" "$(alan sonuc)" "tamam"
ol "K3 sahipsiz satır → bilinmiyor" "$(alan sahip)" "bilinmiyor"
ol "K3 damgasız → kutuk null" "$(alan kutuk)" "null"
bash "$S" nobetci -- bash -c 'echo dokunmadim > "$KOSU_BEYAN"' >/dev/null
ol "K4 beyanla → ayakta-dokunmadim" "$(alan sonuc)" "ayakta-dokunmadim"
bash "$S" nobetci -- bash -c 'echo dokunmadim > "$KOSU_BEYAN"; exit 3' >/dev/null; rc=$?
ol "K4 beyan + rc≠0 → hata (beyan başarıyı yaratmaz)" "$(alan sonuc)" "hata"
ol "K4 rc geçirildi" "$rc" "3"
echo "════ K4 · nöbetçi kipi (--nobetci): beyan kanon satırında, dosyaya dokunulmaz (NÂZIR A291) ════"
bash "$S" nobetci --nobetci -- true >/dev/null
ol "--nobetci + rc0 + boş çıktı → ayakta-dokunmadim" "$(alan sonuc)" "ayakta-dokunmadim"
bash "$S" nobetci --nobetci -- echo "sunucu yeniden başlatıldı" >/dev/null
ol "--nobetci + rc0 + çıktı VAR → tamam (iş yaptı)" "$(alan sonuc)" "tamam"
bash "$S" nobetci --nobetci -- bash -c 'exit 2' >/dev/null; rc=$?
ol "--nobetci + rc≠0 → hata, rc geçer" "$(alan sonuc)/$rc" "hata/2"
bash "$S" nobetci --bilinmeyen -- true >/dev/null 2>&1; ol "bilinmeyen bayrak rc=2" "$?" "2"
echo "════ atlandi-kilit · flock -n -E 75 (NÂZIR A293) ════"
exec 9>"$T/kilit"; flock 9   # kilidi bu kabuk tutar → sarmalayıcı alamaz
bash "$S" supur --kilit "$T/kilit" -- bash -c 'echo KOSTU > "'"$T"'/iz"' >/dev/null; rc=$?
ol "--kilit dolu → atlandi-kilit (hata değil)" "$(alan sonuc)" "atlandi-kilit"
ol "kilit doluyken komut HİÇ koşmadı" "$(test -e "$T/iz" && echo kostu || echo kosmadi)" "kosmadi"
ol "rc = kilit kodu 75" "$rc/$(alan rc)" "75/75"
( KOSU_KILIT_RC=99 bash "$S" supur --kilit "$T/kilit" -- true >/dev/null; echo "rc=$?" > "$T/rc99" ); ol "kilit kodu ortamla DEĞİŞMEZ (şema sabit 75)" "$(alan rc)/$(cat "$T/rc99")" "75/rc=75"
bash "$S" supur -- bash -c 'exit 75' >/dev/null
ol "--kilit YOKKEN işin kendi 75'i → hata (sezgi yok)" "$(alan sonuc)" "hata"
flock -u 9; exec 9>&-
bash "$S" supur --kilit "$T/kilit" -- bash -c 'exit 75' >/dev/null
ol "kilit BOŞKEN alt komutun 75'i → hata (kilit atlaması sanılmaz)" "$(alan sonuc)" "hata"
bash "$S" supur --kilit "$T/kilit" -- bash -c 'echo KOSTU > "'"$T"'/iz"' >/dev/null
ol "kilit boşken iş koşar: tamam" "$(alan sonuc)/$(test -e "$T/iz" && echo kostu)" "tamam/kostu"
bash "$S" supur --kilit -- true >/dev/null 2>&1; ol "--kilit dosyasız rc=2" "$?" "2"
rm -f "$T/iz"; ( KOSU_FLOCK_KOMUT=/yok/flock bash "$S" supur --kilit "$T/kilit" -- bash -c 'echo KOSTU > "'"$T"'/iz"' >/dev/null 2>&1; echo "rc=$?" > "$T/rcf" )
ol "flock YOKSA → olculemedi (atlandı DENMEZ), rc 127" "$(alan sonuc)/$(cat "$T/rcf")" "olculemedi/rc=127"
ol "flock yokken komut koşturulmadı (kilitsiz koşmaz)" "$(test -e "$T/iz" && echo kostu || echo kosmadi)" "kosmadi"

echo "════ K5 · çelişki: canlı tablo ≠ kanon ════"
sed -i 's/^35 \* \* \* \* flock/40 * * * * flock/' "$T/canli"
bash "$S" supur -- true >/dev/null
ol "K5 canlı 40 → gözlem 12:40" "$(alan sonraki_planli)" "2026-10-09T12:40:00+03:00"
ol "K5 kanon 35 → tahmin 12:35 (fark = drift göstergesi)" "$(alan ifadeden_tahmin)" "2026-10-09T12:35:00+03:00"

echo "════ K5 · @reboot türetilemez · satırı olmayan iş ════"
bash "$S" acilis -- true >/dev/null
ol "@reboot planlı null" "$(alan sonraki_planli)" "null"
ol "@reboot tahmin null · tahmin=false · turetilemedi=true" "$(alan ifadeden_tahmin)/$(alan tahmin)/$(alan turetilemedi)" "null/false/true"
bash "$S" kanonda-yok -- true >/dev/null
ol "kanonda olmayan iş: sahip bilinmiyor, turetilemedi" "$(alan sahip)/$(alan turetilemedi)" "bilinmiyor/true"
echo "════ K3 · satır SONU etiketi (canlıya taşınan tek yüzey, NÂZIR A292) ════"
printf '%s\n' '# sahip: ESKI' '*/10 * * * * bash /x/kosu-sar.sh etiketli -- true # etiketli sahip:HAFIZADAR damga:/var/log/e.log' '5 4 * * * bash /x/kosu-sar.sh yalin -- true # yalin' >> "$T/kanon"
cp "$T/kanon" "$T/canli"; sed -i 's/^35 \* \* \* \* flock/40 * * * * flock/' "$T/canli"   # canlıdaki 40 draft'ı korunur (K5 kanonsuz kapısı buna bakar)
bash "$S" etiketli -- true >/dev/null
ol "satır sonu sahip: üstteki notu EZER" "$(alan sahip)" "HAFIZADAR"
ol "satır sonu damga:" "$(alan kutuk)" "/var/log/e.log"
bash "$S" yalin -- true >/dev/null
ol "etiketsiz satır sonu yorumu → bilinmiyor" "$(alan sahip)" "bilinmiyor"

echo "════ olculemedi · hatalı kullanım ════"
bash "$S" supur -- /yok/boyle/komut >/dev/null 2>&1; rc=$?
ol "komut yok → sonuc olculemedi" "$(alan sonuc)" "olculemedi"
ol "komut yok → rc 127" "$rc" "127"
printf '#!/bin/sh\necho x\n' > "$T/calismaz.sh"; chmod -x "$T/calismaz.sh"
bash "$S" supur -- "$T/calismaz.sh" >/dev/null 2>&1; rc=$?
ol "çalıştırılamaz komut → sonuc olculemedi" "$(alan sonuc)" "olculemedi"
ol "çalıştırılamaz → rc 126 olduğu gibi geçer (127'ye çevrilmez)" "$rc/$(alan rc)" "126/126"
bash "$S" "KÖTÜ AD" -- true >/dev/null 2>&1; ol "geçersiz iş adı rc=2" "$?" "2"
bash "$S" supur true >/dev/null 2>&1; ol "'--' yoksa rc=2" "$?" "2"
n0=$(satir_sayisi); bash "$S" "KÖTÜ AD" -- true >/dev/null 2>&1; ol "geçersiz kullanım satır YAZMAZ" "$(satir_sayisi)" "$n0"

echo "════ kanon bildirilmemiş · kutu adı türetimi (A290: her kutunun kanon yolu başka) ════"
( unset KOSU_KANON; bash "$S" supur -- true >/dev/null )
ol "kanonsuz: sahip canlı crontab'dan" "$(alan sahip)" "NAZIR"
ol "kanonsuz: tahmin = gözlem (drift ölçülemez), turetilemedi=false" "$(alan sonraki_planli)/$(alan ifadeden_tahmin)/$(alan turetilemedi)" "2026-10-09T12:40:00+03:00/2026-10-09T12:40:00+03:00/false"
( unset KOSU_KUTU; DEFAULT_WORKSPACE=/config/projects/Nazir/ KOSU_KAYIT_DIZ="$T/kayit2" bash "$S" supur -- true >/dev/null )
ol "kutu: DEFAULT_WORKSPACE son parçası küçük harf" "$(ls "$T/kayit2" | sed 's/\..*//')" "nazir"
( unset KOSU_KUTU DEFAULT_WORKSPACE; KOSU_KAYIT_DIZ="$T/kayit3" bash "$S" supur -- true >/dev/null )
ol "kutu: hiçbiri yoksa bilinmiyor (hostname uydurulmaz)" "$(ls "$T/kayit3" | sed 's/\..*//')" "bilinmiyor"

echo "════ cron-sonraki.py tek başına (bağımsız hesap, paket yok) ════"
CS() { python3 "$HERE/cron-sonraki.py" "$1" 2026-10-09T12:00:00+03:00 2>/dev/null; }   # 9 Eki 2026 Cuma
ol "5 alan → sonraki (hafta içi 09:00 → Pzt)" "$(CS '0 9 * * 1-5')" "2026-10-12T09:00:00+03:00"
ol "aynı saat içinde ileri dakika" "$(CS '35 * * * *')" "2026-10-09T12:35:00+03:00"
ol "adım */5" "$(CS '*/5 * * * *')" "2026-10-09T12:05:00+03:00"
ol "ay başı → sonraki ay" "$(CS '0 0 1 * *')" "2026-11-01T00:00:00+03:00"
ol "hafta günü 7 = Pazar" "$(CS '0 12 * * 7')" "2026-10-11T12:00:00+03:00"
ol "hafta günü adla (sun)" "$(CS '0 12 * * sun')" "2026-10-11T12:00:00+03:00"
ol "ay adla (jan) → yıl devri" "$(CS '0 0 * jan *')" "2027-01-01T00:00:00+03:00"
ol "liste 1,15" "$(CS '15 3 1,15 * *')" "2026-10-15T03:15:00+03:00"
ol "gün-ay VE hafta-günü kısıtlı → biri tutunca (cron OR kuralı)" "$(CS '0 6 31 * 1')" "2026-10-12T06:00:00+03:00"
ol "5/15 biçimi" "$(CS '5/15 * * * *')" "2026-10-09T12:05:00+03:00"
# paket bağımsızlığı sınav ortamından bağımsız kanıtlanır: croniter adıyla ZEHİRLİ bir modül öne konur; hesap ona
# dokunsaydı ImportError ile düşerdi (nazir'de paket yok, A290 — bu kapı o kutuyu burada taklit eder)
mkdir -p "$T/zehir"; printf 'raise ImportError("croniter zehirli: hesap pakete dokundu")\n' > "$T/zehir/croniter.py"
ol "croniter zehirliyken de doğru (pakete bağımlılık yok)" "$(PYTHONPATH="$T/zehir" CS '0 9 * * 1-5')" "2026-10-12T09:00:00+03:00"
PYTHONPATH="$T/zehir" python3 -c 'import croniter' >/dev/null 2>&1; ol "zehir gerçekten ısırıyor (pozitif kontrol)" "$?" "1"
python3 "$HERE/cron-sonraki.py" '@daily' >/dev/null 2>&1; ol "@daily rc=3 (türetilemedi)" "$?" "3"
python3 "$HERE/cron-sonraki.py" '1 2 3' >/dev/null 2>&1; ol "3 alan rc=3" "$?" "3"
python3 "$HERE/cron-sonraki.py" '99 * * * *' >/dev/null 2>&1; ol "aralık dışı rc=3 (uydurma yok)" "$?" "3"
ol "seyrek ama geçerli: 29 Şubat → 2028 (366 gün yetmezdi)" "$(CS '30 2 29 2 *')" "2028-02-29T02:30:00+03:00"
python3 "$HERE/cron-sonraki.py" '0 0 31 2 *' 2026-10-09T12:00:00+03:00 >/dev/null 2>&1; ol "hiç gelmeyen gün (31 Şubat) rc=3" "$?" "3"

echo ""; echo "── SONUÇ: $gecti geçti · $dusen düştü ──"
[ "$dusen" -eq 0 ]
