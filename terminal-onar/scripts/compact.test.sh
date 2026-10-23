#!/usr/bin/env bash
# compact.test.sh — kutu-içi zorunlu compact kapıları. HERMETİK: sahte tmux + sahte oturum kayıtları; gerçek koltuğa tuş gitmez.
# Ağırlık merkezi: ölçülemeyen koltuğa dokunulmaz · meşgul/taslaklı koltuğa tuş gitmez (kuyruk) · kimliksiz/reis-dışı uygulayamaz.
set -uo pipefail
cd "$(dirname "$0")"
GECEN=0; DUSEN=0
ok()  { GECEN=$((GECEN+1)); echo "  ✓ $1"; }
bad() { DUSEN=$((DUSEN+1)); echo "  ✗ $1 — $2"; }
S="$(mktemp -d)"; trap 'rm -r -f -- "$S" 2>/dev/null' EXIT
mkdir -p "$S/bin" "$S/durum" "$S/kayit"
cat > "$S/bin/tmux" <<'T'
#!/usr/bin/env bash
case "$1" in
  list-sessions) case "$3" in *session_activity*) sed 's/$/\t1760000000/' "$SAHTE/oturumlar" ;; *) cat "$SAHTE/oturumlar" ;; esac ;;
  list-panes)    if [ "$2" = -a ]; then while IFS= read -r n; do case "$n" in BASIRET|ZAKIR|KALFA|NEDIM|MUHASIP) k=claude; p=100 ;; *) k=bash; p=200 ;; esac
                     printf '%s\t1\t1\t%%%s\t%s\t%s\n' "$n" "$n" "$p" "$k"; done < "$SAHTE/oturumlar"
                 else t="${4#=}"; case "$t" in BASIRET|ZAKIR|KALFA|NEDIM|MUHASIP) echo "100 claude" ;; *) echo "200 bash" ;; esac; fi ;;
  display-message) echo 1760000000 ;;
  capture-pane)  case "$4" in %*) t="${4#%}" ;; *) t="${4%:}" ;; esac; [ -f "$SAHTE/ekran-$t" ] && cat "$SAHTE/ekran-$t" || exit 1 ;;
  list-windows)  echo "@1" ;;
  send-keys)     echo "send-keys ${*:2}" >> "$SAHTE/iz"; exit 0 ;;
  set-option)    : ;;
  *) exit 1 ;;
esac
T
printf '#!/usr/bin/env bash\nexit 1\n' > "$S/bin/pgrep"; chmod +x "$S/bin/tmux" "$S/bin/pgrep"
printf '%s\n' maiset-ana BASIRET ZAKIR KALFA NEDIM MUHASIP > "$S/oturumlar"
printf '❯ \n' > "$S/ekran-BASIRET"; printf '⏺ Düşünüyor…\nesc to interrupt\n' > "$S/ekran-ZAKIR"; printf '❯ yarım kalmış yazı\n' > "$S/ekran-KALFA"
printf '❯ \n' > "$S/ekran-NEDIM"; printf '❯ \n' > "$S/ekran-MUHASIP"
# oturum kayıtları: son asistan kullanımı + (varsa) compact_boundary
kayit() {  # ad tok model [compact-epoch]
  local f="$S/kayit/$1.jsonl"; : > "$f"
  printf '{"type":"user","timestamp":"2026-10-01T08:00:00.000Z","message":{"role":"user","content":"selam"}}\n' >> "$f"
  [ -n "${4:-}" ] && printf '{"type":"system","subtype":"compact_boundary","timestamp":"%s","compactMetadata":{"trigger":"manual"}}\n' "$(date -u -d "@$4" +%Y-%m-%dT%H:%M:%S.000Z)" >> "$f"
  printf '{"type":"assistant","timestamp":"2026-10-15T10:00:00.000Z","message":{"model":"%s","usage":{"input_tokens":%s,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}\n' "$3" "$2" >> "$f"
}
SIMDI=$(date +%s)
kayit BASIRET 170000 bilinmeyen-model                       # %85, hiç compact, boş → gider
kayit ZAKIR   150000 bilinmeyen-model $((SIMDI-7200))       # %75, 2 sa önce compact, çalışıyor → kuyruk
kayit KALFA   130000 bilinmeyen-model                       # %65, girdi (taslak) → kuyruk
kayit MUHASIP 150000 claude-sonnet-5-5                    # kanon: sonnet-5 500k → %30, tamam (payda kanondan, ~ yok)
# NEDIM: kayıt yok → ölçülemedi
KQ="$S/durum/compact-bekleyen.jsonl"
kos() { : > "$S/iz"; SAHTE="$S" PATH="$S/bin:$PATH" TO_KUTU=maiset TO_PROJE="$S/proje" TO_DURUM_DIZ="$S/durum" TO_OTURUM_DIZ="$S/kayit" TO_COMPACT_KUYRUK="$KQ" TO_COMPACT_BEKLE_SN=0 bash compact.sh "$@" > "$S/cikti" 2>"$S/hata"; echo $? > "$S/rc"; }
c() { cat "$S/cikti"; } ; h() { cat "$S/hata"; }; iz() { cat "$S/iz"; }; rc() { cat "$S/rc"; }

echo "C · ölçüm (yalnız ölçüm, tuş gitmez)"
kos
[ "$(rc)" = 0 ] && grep -q 'BASIRET.*bos.*~%85.*⟳ hiç.*compact gerek (boş' "$S/cikti" && ok "C1 BASIRET: ~%85 (payda tahmin işareti ~), hiç compact, boş → 'compact gerek (boş: --uygula ile gider)'" || bad C1 "$(c)"
grep -q 'ZAKIR.*calisiyor.*~%75.*⟳ 2 sa önce.*compact gerek (calisiyor' "$S/cikti" && ok "C1b ZAKIR: son compact '2 sa önce' kayıttan okunur; çalışıyor → '--uygula ile kuyruğa'" || bad C1b "$(c)"
grep -q 'KALFA.*girdi.*~%65.*compact gerek (girdi' "$S/cikti" && ok "C1c KALFA: girdi (taslak var) → kuyruk adayı" || bad C1c "$(c)"
grep -q 'MUHASIP.*bos.* %30 .*tamam' "$S/cikti" && ! grep -q 'MUHASIP.*~%30' "$S/cikti" && ok "C1d MUHASIP: sonnet-5 → kanondan 500k payda, %30 tamam, ~ işareti YOK (payda kanondan)" || bad C1d "$(c)"
grep -q 'NEDIM.*—.*ölçülemedi: sahte kayıt yok' "$S/cikti" && ok "C1e NEDIM: kayıt yok → ölçülemedi (yüzde uydurulmaz)" || bad C1e "$(c)"
grep -q '── 3 compact gerek · 0 gönderildi · 0 kuyrukta · 1 ölçülemedi' "$S/cikti" && [ -z "$(iz)" ] && ok "C1f özet 3 gerek / 1 ölçülemedi; yalnız ölçümde tuş GİTMEDİ" || bad C1f "$(c) | iz: $(iz)"
! grep -q 'maiset-ana' "$S/cikti" && ok "C1g Claude'suz koltuk (maiset-ana) listede yok (compact'ı yok)" || bad C1g "$(c)"
kos --json
[ "$(jq -r '.[]|select(.koltuk=="BASIRET")|.yuzde' "$S/cikti")" = 85 ] && [ "$(jq -r '.[]|select(.koltuk=="BASIRET")|.payda_tahmin' "$S/cikti")" = true ] && [ "$(jq -r '.[]|select(.koltuk=="MUHASIP")|.payda_tahmin' "$S/cikti")" = false ] && [ "$(jq -r '.[]|select(.koltuk=="NEDIM")|.yuzde' "$S/cikti")" = null ] && [ "$(jq 'length' "$S/cikti")" = 5 ] && ok "C2 --json: 5 koltuk, yüzde/payda_tahmin/null makine-okunur" || bad C2 "$(c)"
kos --koltuk BASIRET
[ "$(grep -c '^  [A-Za-z]' "$S/cikti")" = 1 ] && grep -q BASIRET "$S/cikti" && ok "C3 --koltuk BASIRET: tek koltuk satırı" || bad C3 "$(c)"
kos --esik 90
grep -q '── 0 compact gerek' "$S/cikti" && ok "C3b --esik 90: hiçbiri eşik üstü değil" || bad C3b "$(c)"
kos --esik abc; [ "$(rc)" = 2 ] && ok "C3c --esik sayı değilse rc 2" || bad C3c "rc=$(rc)"

echo "Y · yetki (uygulamak reisin)"
kos --uygula
[ "$(rc)" = 5 ] && grep -q 'kimliksiz' "$S/hata" && [ -z "$(iz)" ] && ok "Y1 AGENT_NAME yokken --uygula RET (rc 5), tuş gitmedi" || bad Y1 "rc=$(rc) $(h) iz=$(iz)"
AGENT_NAME=BASKA TO_REIS=MUTEVELLI kos --uygula
[ "$(rc)" = 5 ] && grep -q 'yalnız kutu reisinin (MUTEVELLI); sen: BASKA' "$S/hata" && [ -z "$(iz)" ] && ok "Y2 reis bilinirken başkası --uygula RET, tuş gitmedi" || bad Y2 "rc=$(rc) $(h)"
AGENT_NAME=BASKA TO_REIS=MUTEVELLI kos
[ "$(rc)" = 0 ] && grep -q 'compact gerek' "$S/cikti" && ok "Y2b reis-dışı ÖLÇEBİLİR (yalnız uygulama kapalı)" || bad Y2b "rc=$(rc)"
AGENT_NAME=MUTEVELLI kos --uygula
[ "$(rc)" = 5 ] && grep -q 'kutu reisi BİLİNMİYOR' "$S/hata" && [ -z "$(iz)" ] && ok "Y3 reis adı bilinmiyorsa (TO_REIS/durum/reis yok) kimlikli çağrı bile --uygula YAPAMAZ (kapalı-varsayılan), tuş gitmedi" || bad Y3 "rc=$(rc) $(h) iz=$(iz)"
printf 'MUTEVELLI' > "$S/durum/reis"; AGENT_NAME=MUTEVELLI kos --uygula; r1=$(rc); rm -f "$S/durum/reis"
[ "$r1" = 0 ] && [ -n "$(iz)" ] && ok "Y3b reis adı \$DURUM_DIZ/reis dosyasından da okunur (TO_REIS yokken uygulama açılır)" || bad Y3b "rc=$r1"
: > "$KQ"

echo "U · uygula: boşa tuş, meşgule kuyruk"
AGENT_NAME=MUTEVELLI TO_REIS=MUTEVELLI kos --uygula
[ "$(rc)" = 0 ] && [ "$(iz)" = "$(printf 'send-keys -t =BASIRET C-u\nsend-keys -t =BASIRET -- /compact\nsend-keys -t =BASIRET Enter')" ] && ok "U1 yalnız BASIRET'e /compact: C-u · metin · AYRI Enter (gömülü Enter yok); ZAKIR/KALFA/NEDIM/MUHASIP'e tuş YOK" || bad U1 "$(iz)"
grep -q 'BASIRET.*⟳ /compact GÖNDERİLDİ' "$S/cikti" && grep -q 'ZAKIR.*⏳ KUYRUKTA (calisiyor' "$S/cikti" && grep -q 'KALFA.*⏳ KUYRUKTA (girdi' "$S/cikti" && ok "U1b ekran: gönderildi / kuyrukta kararları" || bad U1b "$(c)"
[ "$(grep -c . "$KQ")" = 2 ] && grep -q '"koltuk":"ZAKIR","yuzde":75,"hal":"calisiyor","deneme":0,"kim":"MUTEVELLI"' "$KQ" && ok "U2 kuyruk 2 satır (ZAKIR, KALFA), kim=MUTEVELLI (yetki kuyrukta taşınır)" || bad U2 "$(cat "$KQ")"
grep -q 'compact gönderildi: BASIRET (kim: MUTEVELLI)' "$S/durum/gunluk.log" && ok "U3 günlüğe düştü (kim)" || bad U3 "$(cat "$S/durum/gunluk.log")"
AGENT_NAME=MUTEVELLI TO_REIS=MUTEVELLI kos --uygula
[ "$(grep -c . "$KQ")" = 2 ] && ok "U4 ikinci --uygula kuyruğu ŞİŞİRMEZ (aynı koltuk tek satır)" || bad U4 "$(cat "$KQ")"

echo "B · kuyruk turu (bekçi): kayıt yetkisi her turda, boşalınca gider, bu arada compact edilmişse düşer, tavan → vazgeç"
cp "$KQ" "$S/kq.yedek"
printf '{"an":"x","epoch":%s,"koltuk":"KALFA","yuzde":65,"hal":"girdi","deneme":0,"kim":"BASKA"}\n{"an":"x","epoch":%s,"koltuk":"ZAKIR","yuzde":75,"hal":"calisiyor","deneme":0,"kim":"?"}\n' "$SIMDI" "$SIMDI" > "$KQ"
printf '❯ \n' > "$S/ekran-KALFA"; printf '❯ \n' > "$S/ekran-ZAKIR"
TO_REIS=MUTEVELLI kos --bekle --uygula
[ -z "$(iz)" ] && [ ! -s "$KQ" ] && grep -q 'KALFA · kuyruk kaydı YETKİSİZ (kim: BASKA, reis: MUTEVELLI)' "$S/hata" && grep -q 'ZAKIR · kuyruk kaydı YETKİSİZ (kim: ?' "$S/hata" && ok "B0 kuyruk kaydı reis-dışı (BASKA) ya da kimliksiz (?) → koltuk boş olsa da tuş GİTMEZ, kayıt düşer (bekçi yolu yetkiyi atlamaz)" || bad B0 "iz=$(iz) | $(h) | $(cat "$KQ")"
grep -q 'compact kuyruk yetkisiz düştü: KALFA (kim: BASKA)' "$S/durum/gunluk.log" && ok "B0b yetkisiz düşüş günlüğe" || bad B0b "$(cat "$S/durum/gunluk.log")"
printf '{"an":"x","epoch":%s,"koltuk":"KALFA","yuzde":65,"hal":"girdi","deneme":0,"kim":"HERHANGI"}\n' "$SIMDI" > "$KQ"
kos --bekle --uygula
[ -z "$(iz)" ] && [ ! -s "$KQ" ] && grep -q 'KALFA · kuyruk kaydı YETKİSİZ (kim: HERHANGI, reis: bilinmiyor)' "$S/hata" && ok "B0c reis bilinmiyorsa DOLU kim de yetmez: kayıt gönderilmeden düşer (kapalı-varsayılan, göz tur 2)" || bad B0c "iz=$(iz) $(h)"
cp "$S/kq.yedek" "$KQ"; printf '⏺ Düşünüyor…\nesc to interrupt\n' > "$S/ekran-ZAKIR"; printf '❯ yarım kalmış yazı\n' > "$S/ekran-KALFA"
TO_REIS=MUTEVELLI kos --bekle --uygula
grep -q 'ZAKIR · hâlâ calisiyor, bekliyor (deneme 1)' "$S/cikti" && grep -q 'KALFA · hâlâ girdi' "$S/cikti" && [ -z "$(iz)" ] && [ "$(grep -c '"deneme":1' "$KQ")" = 2 ] && ok "B1 ikisi de meşgul: tuş yok, deneme 1" || bad B1 "$(c) $(cat "$KQ")"
printf '❯ \n' > "$S/ekran-KALFA"   # KALFA boşaldı
TO_REIS=MUTEVELLI kos --bekle --uygula
[ "$(iz)" = "$(printf 'send-keys -t =KALFA C-u\nsend-keys -t =KALFA -- /compact\nsend-keys -t =KALFA Enter')" ] && [ "$(grep -c . "$KQ")" = 1 ] && grep -q ZAKIR "$KQ" && grep -q 'KALFA · ⟳ /compact GÖNDERİLDİ (kuyruktan, MUTEVELLI adına' "$S/cikti" && ok "B2 KALFA boşalınca /compact gitti (MUTEVELLI adına), kuyruktan düştü; ZAKIR kaldı" || bad B2 "$(iz) | $(cat "$KQ")"
kayit ZAKIR 40000 bilinmeyen-model $((SIMDI-60))   # biri ZAKIR'ı bu arada compact etmiş
TO_REIS=MUTEVELLI kos --bekle --uygula
grep -q 'ZAKIR · kuyruktan düştü (bu arada compact edilmiş: %20)' "$S/cikti" && [ ! -s "$KQ" ] && [ -z "$(iz)" ] && ok "B3 eşik altına inmiş koltuk kuyruktan düşer, tuş gitmez" || bad B3 "$(c) $(cat "$KQ")"
printf '{"an":"x","epoch":%s,"koltuk":"ZAKIR","yuzde":75,"hal":"calisiyor","deneme":3,"kim":"MUTEVELLI"}\n' $((SIMDI-90000)) > "$KQ"; kayit ZAKIR 150000 bilinmeyen-model
TO_REIS=MUTEVELLI kos --bekle --uygula
grep -q 'VAZGEÇİLDİ' "$S/hata" && [ ! -s "$KQ" ] && grep -q 'compact VAZGEÇİLDİ: ZAKIR' "$S/durum/gunluk.log" && ok "B4 25 saattir meşgul → VAZGEÇİLDİ (ekrana kırmızı + günlük), kuyruktan düşer" || bad B4 "$(h) $(cat "$KQ")"
printf '{"an":"x","epoch":%s,"koltuk":"YOKBOYLE","yuzde":75,"hal":"calisiyor","deneme":0,"kim":"MUTEVELLI"}\n' "$SIMDI" > "$KQ"
TO_REIS=MUTEVELLI kos --bekle --uygula
grep -q 'YOKBOYLE · kuyruktan düştü (koltuk artık yok' "$S/cikti" && [ ! -s "$KQ" ] && ok "B5 koltuk kapanmışsa kuyruktan düşer" || bad B5 "$(c)"
kos --bekle; grep -q 'compact kuyruğu boş' "$S/cikti" && ok "B6 boş kuyruk: tek satır, iş yok" || bad B6 "$(c)"
# Nexus #1171 (FNX51) Sx kopyası: NEDIM BOŞ ama kaydı yok (bağlam ölçülemez) → bayat kayıt /compact GÖNDERMEZ, kuyrukta kalır, tavanda gerçek nedenle düşer
printf '{"an":"x","epoch":%s,"koltuk":"NEDIM","yuzde":80,"hal":"girdi","deneme":0,"kim":"MUTEVELLI"}\n' "$SIMDI" > "$KQ"
TO_REIS=MUTEVELLI kos --bekle --uygula
[ -z "$(iz)" ] && grep -q '"koltuk":"NEDIM".*"deneme":1' "$KQ" && grep -q 'NEDIM · bağlamı ölçülemedi (sahte kayıt yok) — GÖNDERİLMEDİ, bekliyor (deneme 1)' "$S/cikti" && ok "B7 boş ama bağlamı ölçülemeyen koltuğa tuş GİTMEZ; kayıt kuyrukta (deneme 1), neden yazılır" || bad B7 "iz=$(iz) | $(c) | $(cat "$KQ")"
printf '{"an":"x","epoch":%s,"koltuk":"NEDIM","yuzde":80,"hal":"girdi","deneme":3,"kim":"MUTEVELLI"}\n' $((SIMDI-90000)) > "$KQ"
TO_REIS=MUTEVELLI kos --bekle --uygula
[ -z "$(iz)" ] && [ ! -s "$KQ" ] && grep -q 'NEDIM · VAZGEÇİLDİ.*bağlamı hiç ölçülemedi' "$S/hata" && grep -q 'compact VAZGEÇİLDİ: NEDIM (ölçülemedi)' "$S/durum/gunluk.log" && ok "B7b ölçülemeyen kayıt tavanda düşer; neden 'bağlamı hiç ölçülemedi' ('boşalmadı' DEĞİL)" || bad B7b "$(h) | $(cat "$KQ")"

echo "K · tur kilidi (göz tur 3): bekçi ile elle çağrı çakışırsa ikinci tur dokunmaz; tur ortasında eklenen satır kaybolmaz"
printf '{"an":"x","epoch":%s,"koltuk":"KALFA","yuzde":65,"hal":"girdi","deneme":0,"kim":"MUTEVELLI"}\n' "$SIMDI" > "$KQ"; printf '❯ \n' > "$S/ekran-KALFA"
( exec 8>"$KQ.tur.kilit"; flock 8; sleep 2 ) & kp=$!; sleep 0.3
TO_REIS=MUTEVELLI kos --bekle --uygula; r=$(rc); wait "$kp"
[ "$r" = 0 ] && grep -q 'zaten koşuyor' "$S/cikti" && [ -z "$(iz)" ] && [ "$(grep -c . "$KQ")" = 1 ] && ok "K1 kilit tutuluyorken tur: 'zaten koşuyor', tuş GİTMEDİ, kuyruk DEĞİŞMEDİ" || bad K1 "rc=$r $(c) iz=$(iz)"
TO_REIS=MUTEVELLI kos --bekle --uygula
[ -n "$(iz)" ] && [ ! -s "$KQ" ] && ok "K1b kilit düşünce aynı kuyruk işlenir (KALFA'ya gitti)" || bad K1b "$(iz) $(cat "$KQ")"
# tur ortasında ekleme: tur anlık kopyasını aldıktan SONRA başka bir süreç kuyruğa satır ekler → yeniden yazım onu korur.
# 🔴 C8NZW (18 Eki): yazıcı eskiden sabit 0,5 sn bekliyordu; betiğin anlık kopyaya varması bundan uzun sürünce satır
#    kopyaya GİRİYOR, turda olağan kayıt gibi işleniyordu (BASIRET'e compact gitti) → K2 "kayboldu" diye kırmızıydı, oysa
#    satır kaybolmamış, sınav yarışı kuramamıştı. Yazıcı artık anlık kopyanın OLUŞMASINI bekler (tur sonunda silinir,
#    bayat kopya kalmaz) VE gerçek yazıcılar gibi ekleme kilidini alır (cp kopyayı yaratıp henüz okurken eklenen satır
#    yine kopyaya girerdi — ilk düzeltmede 3 koşunun 1'i bu yüzden kırmızıydı). Kopya 10 sn'de görünmezse yazmaz ve K2
#    kırmızı kalır (sessiz yeşil değil).
printf '{"an":"x","epoch":%s,"koltuk":"ZAKIR","yuzde":75,"hal":"calisiyor","deneme":0,"kim":"MUTEVELLI"}\n' "$SIMDI" > "$KQ"
printf '⏺ Düşünüyor…\nesc to interrupt\n' > "$S/ekran-ZAKIR"
( i=0; while [ ! -e "$KQ.tur.anlik" ] && [ $i -lt 200 ]; do sleep 0.05; i=$((i+1)); done
  # gerçek yazıcılar gibi ekleme kilidini alır: kopya oluşur oluşmaz (cp henüz okurken) eklemek satırı kopyaya sokardı
  [ -e "$KQ.tur.anlik" ] && ( flock -w 10 9 && printf '{"an":"y","epoch":%s,"koltuk":"BASIRET","yuzde":85,"hal":"calisiyor","deneme":0,"kim":"MUTEVELLI"}\n' "$SIMDI" >> "$KQ" ) 9>"$KQ.ekle.kilit" ) & ep=$!
TO_COMPACT_SINAV_BEKLE_SN=1 TO_REIS=MUTEVELLI kos --bekle --uygula; wait "$ep"
grep -q '"koltuk":"ZAKIR".*"deneme":1' "$KQ" && grep -q '"koltuk":"BASIRET"' "$KQ" && ok "K2 tur sırasında eklenen BASIRET satırı yeniden yazımda KAYBOLMADI; ZAKIR deneme 1" || bad K2 "$(cat "$KQ")"
# K3 (göz tur 4): elle --uygula da AYNI kilidi alır — bekçi turu kilidi tutarken elle çağrı boş koltuğa tuş GÖNDERMEZ (ölçüm basılır, rc 6)
: > "$KQ"; printf '❯ \n' > "$S/ekran-BASIRET"
( exec 8>"$KQ.tur.kilit"; flock 8; sleep 2 ) & kp=$!; sleep 0.3
TO_COMPACT_KILIT_BEKLE_SN=1 AGENT_NAME=MUTEVELLI TO_REIS=MUTEVELLI kos --uygula; r=$(rc); wait "$kp"
[ "$r" = 6 ] && [ -z "$(iz)" ] && grep -q 'ATLANDI' "$S/hata" && grep -q 'BASIRET.*compact gerek' "$S/cikti" && ok "K3 bekçi turu kilidi tutarken elle --uygula: tuş GİTMEDİ, ölçüm basıldı, rc 6 (iki yol aynı koltuğa gönderemez)" || bad K3 "rc=$r iz=$(iz) $(h)"
AGENT_NAME=MUTEVELLI TO_REIS=MUTEVELLI kos --uygula
[ "$(rc)" = 0 ] && [ -n "$(iz)" ] && ok "K3b kilit düşünce elle --uygula gönderir" || bad K3b "rc=$(rc)"

echo; echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[ "$DUSEN" = 0 ]
