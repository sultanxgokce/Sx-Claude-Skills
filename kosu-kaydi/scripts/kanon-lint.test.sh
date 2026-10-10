#!/usr/bin/env bash
# kanon-lint.test.sh — kanon lint'inin sınavı (hermetik: geçici kanon dosyaları). Her kural için kırmızı/altın çift.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; L="$HERE/kanon-lint.sh"
T="$(mktemp -d)"; trap 'find "$T" -depth -delete' EXIT
gecti=0; dusen=0
ol() { if [ "$2" = "$3" ]; then gecti=$((gecti+1)); else dusen=$((dusen+1)); echo "  ✗ $1: beklenen[$3] gelen[$2]"; fi; }
kos() { CIKTI="$(bash "$L" "$@" 2>&1)"; RC=$?; }
W='bash /config/.claude/skills/kosu-kaydi/scripts/kosu-sar.sh'

echo "════ temiz kanon: satır sonu etiketi · --kilit doğru · gözlemli ════"
cat > "$T/temiz" <<EOF
*/5 * * * * KOSU_KUTU=nazir $W bulgu-defteri --nobetci --gozlem "cat /proc/net/tcp" -- bash /x/sunucu.sh # bulgu-defteri sahip:NAZIR
35 * * * * $W supur --kilit /x.lock -- bash /x/supur.sh # supur sahip:MUAVIN damga:/x/supur.log
EOF
kos "$T/temiz"; ol "temiz → rc 0" "$RC" "0"; ol "temiz → kırmızı 0 sarı 0" "$(printf '%s' "$CIKTI" | grep -c 'kırmızı: 0 · sarı: 0')" "1"
ol "sarılı satır sayısı 2" "$(printf '%s' "$CIKTI" | grep -c 'sarılı satır: 2')" "1"

echo "════ K1 · --kilit + iç flock = her koşu atlanır (KIRMIZI) ════"
printf '%s\n' "35 * * * * $W supur --kilit /x.lock -- flock -n /x.lock bash /x/supur.sh # supur sahip:MUAVIN" > "$T/k1"
kos "$T/k1"; ol "K1 rc 1" "$RC" "1"; ol "K1 mesajı" "$(printf '%s' "$CIKTI" | grep -c 'KIRMIZI K1')" "1"
printf '%s\n' "35 * * * * $W supur --kilit /x.lock -- bash /x/supur.sh # supur sahip:MUAVIN" > "$T/k1a"
kos "$T/k1a"; ol "K1 altın: --kilit doğru → rc 0" "$RC" "0"
printf '%s\n' "35 * * * * $W supur --kilit /x.lock -- bash /x/flockluk.sh # supur sahip:MUAVIN" > "$T/k1b"
kos "$T/k1b"; ol "K1 altın: 'flock' alt dizge olarak geçen dosya adı yakalanmaz" "$RC" "0"
printf '%s\n' "35 * * * * $W supur --kilit /x.lock -- /usr/bin/flock -n /x.lock bash /x/supur.sh # supur sahip:MUAVIN" > "$T/k1c"
kos "$T/k1c"; ol "K1: mutlak yollu /usr/bin/flock da yakalanır → rc 1" "$RC" "1"; ol "K1 mesajı (mutlak yol)" "$(printf '%s' "$CIKTI" | grep -c 'KIRMIZI K1')" "1"
printf '%s\n' "35 * * * * $W supur -- /usr/bin/flock -n /x.lock bash /x/supur.sh # supur sahip:MUAVIN" > "$T/k2b"
kos "$T/k2b"; ol "K2: mutlak yollu flock -n içeride → sarı" "$(printf '%s' "$CIKTI" | grep -c 'SARI    K2')" "1"
printf '%s\n' "35 * * * * $W supur -- flock -E 75 -n /x.lock bash /x/supur.sh # supur sahip:MUAVIN" > "$T/k2c"
kos "$T/k2c"; ol "K2: -n flock'tan hemen sonra değil (flock -E 75 -n) → yine sarı" "$(printf '%s' "$CIKTI" | grep -c 'SARI    K2')" "1"
printf '%s\n' "35 * * * * $W supur -- flock --nonblock /x.lock bash /x/supur.sh # supur sahip:MUAVIN" > "$T/k2d"
kos "$T/k2d"; ol "K2: --nonblock uzun biçimi → sarı" "$(printf '%s' "$CIKTI" | grep -c 'SARI    K2')" "1"
printf '%s\n' "35 * * * * $W supur -- flock /x.lock bash /x/supur.sh # supur sahip:MUAVIN" > "$T/k2e"
kos "$T/k2e"; ol "K2 altın: bloklayan flock (-n yok) sarı değil (kilit bekler, atlamaz)" "$(printf '%s' "$CIKTI" | grep -c 'SARI    K2')" "0"
printf '%s\n' "35 * * * * $W supur -- flock /x.lock grep -n desen /x/dosya # supur sahip:MUAVIN" > "$T/k2f"
kos "$T/k2f"; f1=$(printf '%s' "$CIKTI" | grep -c 'SARI    K2')
printf '%s\n' "35 * * * * $W supur -- flock -E75 -w 0 -n /x.lock bash /x/supur.sh # supur sahip:MUAVIN" > "$T/k2g"
kos "$T/k2g"; f2=$(printf '%s' "$CIKTI" | grep -c 'SARI    K2')
printf '%s\n' "35 * * * * $W supur -- flock -c 'grep -n desen /x/dosya' /x.lock # supur sahip:MUAVIN" > "$T/k2h"
kos "$T/k2h"; f3=$(printf '%s' "$CIKTI" | grep -c 'SARI    K2')
ol "K2 ayrıştırıcı: komutun kendi -n'si (flock /x.lock grep -n) DEĞİL · bitişik+ayrı değerli seçenekler (-E75 -w 0 -n) K2 · alıntılı -c içindeki -n DEĞİL" "$f1/$f2/$f3" "0/1/0"

echo "════ K2 · flock -n sarmalayıcının içinde, --kilit yok (SARI) ════"
printf '%s\n' "35 * * * * $W supur -- flock -n /x.lock bash /x/supur.sh # supur sahip:MUAVIN" > "$T/k2"
kos "$T/k2"; ol "K2 rc 0 (sarı kırmızı değil)" "$RC" "0"; ol "K2 mesajı" "$(printf '%s' "$CIKTI" | grep -c 'SARI    K2')" "1"

echo "════ K3 · sahip etiketi (KIRMIZI) — satır sonu ya da satır üstü ════"
printf '%s\n' "35 * * * * $W supur -- bash /x/supur.sh" > "$T/k3"
kos "$T/k3"; ol "K3 etiketsiz → rc 1" "$RC" "1"; ol "K3 mesajı iş adını söyler" "$(printf '%s' "$CIKTI" | grep -c 'K3 satır 1: sahip etiketi yok (iş: supur)')" "1"
printf '%s\n' "# sahip: MUAVIN" "35 * * * * $W supur -- bash /x/supur.sh" > "$T/k3a"
kos "$T/k3a"; ol "K3 altın: satır üstü notu yeter → rc 0" "$RC" "0"
printf '%s\n' "# sahip: MUAVIN" "# damga: /x/log" "35 * * * * $W supur -- bash /x/supur.sh" > "$T/k3b"
kos "$T/k3b"; ol "K3 altın: '# sahip:' + '# damga:' bitişik yorum bloğu → sayılır, rc 0 (sarmalayıcı bloğun tamamını okur)" "$RC" "0"
printf '%s\n' "# sahip: MUAVIN" "" "35 * * * * $W supur -- bash /x/supur.sh" > "$T/k3f"
kos "$T/k3f"; ol "K3: boş satır bloğu keser → sahip sayılmaz, rc 1" "$RC" "1"
printf '%s\n' "# sahip: MUAVIN" "0 1 * * * bash /x/baska.sh" "35 * * * * $W supur -- bash /x/supur.sh" > "$T/k3g"
kos "$T/k3g"; ol "K3: araya başka cron satırı girince blok kapanır, rc 1" "$RC" "1"
printf '%s\n' "35 * * * * $W supur -- bash /x/supur.sh # supur damga:/x/log" > "$T/k3c"
kos "$T/k3c"; ol "K3: satır sonunda damga var sahip yok → rc 1" "$RC" "1"
printf '%s\n' "# sahip:" "35 * * * * $W supur -- bash /x/supur.sh" > "$T/k3d"
kos "$T/k3d"; ol "K3: satır üstü '# sahip:' DEĞERSİZ → etiket sayılmaz, rc 1" "$RC" "1"
printf '%s\n' "35 * * * * $W supur -- bash /x/supur.sh # supur sahip:" > "$T/k3e"
kos "$T/k3e"; ol "K3: satır sonu 'sahip:' değersiz → rc 1" "$RC" "1"

echo "════ sekmeli crontab satırları (alan ayracı sekme) — bütün kurallar yine işler ════"
printf '35\t*\t*\t*\t*\t%s\tsupur\t--kilit\t/x.lock\t--\tflock -n /x.lock bash /x/supur.sh\n' "$W" > "$T/sekme"
kos "$T/sekme"; ol "sekmeli: sarılı satır tanındı" "$(printf '%s' "$CIKTI" | grep -c 'sarılı satır: 1')" "1"
ol "sekmeli: K1 ve K3 kırmızı" "$(printf '%s' "$CIKTI" | grep -cE 'KIRMIZI K[13]')" "2"; ol "sekmeli rc 1" "$RC" "1"

echo "════ K4 · aynı iş iki sarılı satırda (KIRMIZI, ikileme) ════"
printf '%s\n' "*/5 * * * * $W bulgu -- bash /x/a.sh # bulgu sahip:NAZIR" "@reboot $W bulgu -- bash /x/a.sh # bulgu sahip:NAZIR" > "$T/k4"
kos "$T/k4"; ol "K4 rc 1" "$RC" "1"; ol "K4 mesajı ilk satırı gösterir" "$(printf '%s' "$CIKTI" | grep -c "K4 satır 2: iş 'bulgu' ikinci kez sarılı (ilk: satır 1)")" "1"
printf '%s\n' "*/5 * * * * $W bulgu -- bash /x/a.sh # bulgu sahip:NAZIR" "*/5 * * * * $W bulgu-defteri -- bash /x/b.sh # bulgu-defteri sahip:NAZIR" > "$T/k4a"
kos "$T/k4a"; ol "K4 altın: 'bulgu' ile 'bulgu-defteri' ayrı iş → rc 0" "$RC" "0"

echo "════ K5 · crontab başına ortam satırı (SARI, A313) ════"
printf '%s\n' "KOSU_KUTU=nazir" "KOSU_KANON=/x/cron" "*/5 * * * * $W bulgu -- bash /x/a.sh # bulgu sahip:NAZIR" > "$T/k5"
kos "$T/k5"; ol "K5 rc 0" "$RC" "0"; ol "K5 iki sarı" "$(printf '%s' "$CIKTI" | grep -c 'SARI    K5')" "2"
ol "K5 'satır içine taşı' der" "$(printf '%s' "$CIKTI" | grep -c 'satırın içine taşı')" "2"

echo "════ K6 · gözlem komutu kutuda yok (SARI, yalnız --kutu-ici) ════"
printf '%s\n' "*/5 * * * * $W bulgu --nobetci --gozlem \"olmayan-komut-xyz -ltnp\" -- bash /x/a.sh # bulgu sahip:NAZIR" > "$T/k6"
kos "$T/k6"; ol "K6 kutu-ici verilmeden bakılmaz → rc 0, sarı 0" "$(printf '%s' "$CIKTI" | grep -c 'sarı: 0 · (K6 gözlem komutu bakılmadı')" "1"
kos "$T/k6" --kutu-ici; ol "K6 kutu-ici → sarı" "$(printf '%s' "$CIKTI" | grep -c "K6 satır 1: gözlem komutu 'olmayan-komut-xyz' bu kutuda yok")" "1"; ol "K6 rc 0" "$RC" "0"
printf '%s\n' "*/5 * * * * $W bulgu --nobetci --gozlem \"awk '\\\$2 ~ /:2256\\\$/ {print \\\$10}' /proc/net/tcp\" -- bash /x/a.sh # bulgu sahip:NAZIR" > "$T/k6a"
kos "$T/k6a" --kutu-ici; ol "K6 altın: awk var → sarı 0" "$(printf '%s' "$CIKTI" | grep -c 'kırmızı: 0 · sarı: 0')" "1"

echo "════ K8 · sarılmamış zamanlı satırda flock (SARI, A320) ════"
printf '%s\n' "*/5 * * * * flock -n /x/fed.lock bash /x/federe.sh" > "$T/k8"
kos "$T/k8"; ol "K8 rc 0 (sarı)" "$RC" "0"; ol "K8 mesajı" "$(printf '%s' "$CIKTI" | grep -c 'SARI    K8 satır 1: sarılmamış kilitli iş')" "1"
printf '%s\n' "*/5 * * * * /usr/bin/flock -n /x/fed.lock bash /x/federe.sh" > "$T/k8a"
kos "$T/k8a"; ol "K8: mutlak yollu flock da" "$(printf '%s' "$CIKTI" | grep -c 'SARI    K8')" "1"
printf '%s\n' "*/5 * * * * bash /x/flockluk.sh" "# flock -n /x.lock yorumda" > "$T/k8b"
kos "$T/k8b"; ol "K8 altın: alt dizge 'flock' ve yorum satırı K8 değil" "$(printf '%s' "$CIKTI" | grep -c 'SARI    K8')" "0"
printf '%s\n' "*/5 * * * * bash /x/a.sh # flock burada kullanılmaz" > "$T/k8c"
kos "$T/k8c"; ol "K8 altın: satır SONU yorumundaki flock K8 değil" "$(printf '%s' "$CIKTI" | grep -c 'SARI    K8')" "0"
kos "$T/k2"; ol "K8 altın: SARILI satırdaki flock K8 değil (K2'nin konusu)" "$(printf '%s' "$CIKTI" | grep -c 'SARI    K8')/$(printf '%s' "$CIKTI" | grep -c 'SARI    K2')" "0/1"

echo "════ K7 · canlı ↔ kanon farkı (SARI, yalnız --kanon) ════"
printf '%s\n' "# kanon" "*/5 * * * * $W bulgu -- bash /x/a.sh # bulgu sahip:NAZIR" "0 3 * * * bash /x/gece.sh" > "$T/kanon7"
printf '%s\n' "*/5 * * * * $W bulgu -- bash /x/a.sh # bulgu sahip:NAZIR" "0 3 * * * bash /x/gece.sh" "*/10 * * * * bash /x/elle.sh" > "$T/canli7"
kos "$T/canli7" --kanon "$T/kanon7"; ol "K7 rc 0" "$RC" "0"; ol "K7 kanon dışı satır 3" "$(printf '%s' "$CIKTI" | grep -c 'SARI    K7 satır 3: kanon dışı')" "1"
ol "K7: eşleşen satırlar sarı değil (tek sarı)" "$(printf '%s' "$CIKTI" | grep -cE 'sarı: 1 · .*kanonla karşılaştırıldı')" "1"
printf '0\t3\t*\t*\t*\tbash /x/gece.sh\n' > "$T/canli7s"; printf '%s\n' "0 3 * * *  bash /x/gece.sh" > "$T/kanon7s"
kos "$T/canli7s" --kanon "$T/kanon7s"; ol "K7 altın: sekme/çift boşluk farkı fark değildir" "$(printf '%s' "$CIKTI" | grep -c 'SARI    K7')" "0"
printf '%s\n' "0 3 * * * bash /x/gece.sh" > "$T/canli7e"
kos "$T/canli7e" --kanon "$T/kanon7"; ol "K7 öbür yön: kanonda var canlıda yok (kanon satır 2)" "$(printf '%s' "$CIKTI" | grep -c 'SARI    K7 satır kanon:2: kanonda var, canlıda yok')" "1"
kos "$T/canli7"; ol "K7 --kanon verilmeden bakılmaz, söylenir" "$(printf '%s' "$CIKTI" | grep -c 'SARI    K7')/$(printf '%s' "$CIKTI" | grep -c 'K7 kanon farkı bakılmadı')" "0/1"
kos "$T/canli7" --kanon "$T/yok-kanon"; ol "K7 kanon okunamıyor → rc 3 (temiz denmez)" "$RC" "3"
kos "$T/canli7" --kanon; ol "--kanon değersiz → rc 2" "$RC" "2"
CIKTI="$(cat "$T/canli7" | bash "$L" - --kanon "$T/kanon7" 2>&1)"; RC=$?; ol "stdin canlı + --kanon (crontab -l | lint - --kanon)" "$(printf '%s' "$CIKTI" | grep -c 'SARI    K7')" "1"

echo "════ nazir biçimi: kanon 5 / canlı 7, farkı iki federe flock satırı → K7 iki + K8 iki ════"
{ for i in 1 2 3 4; do echo "$i * * * * bash /x/is$i.sh"; done; echo "*/5 * * * * $W bulgu -- bash /x/a.sh # bulgu sahip:NAZIR"; } > "$T/nk"
{ cat "$T/nk"; echo "*/2 * * * * flock -n /x/f1.lock bash /x/federe-yokla.sh"; echo "*/15 * * * * flock -n /x/f2.lock bash /x/federe-tur.sh"; } > "$T/nc"
kos "$T/nc" --kanon "$T/nk" --kutu-ici; ol "nazir biçimi: K7 2 · K8 2 · rc 0" "$(printf '%s' "$CIKTI" | grep -c 'SARI    K7')/$(printf '%s' "$CIKTI" | grep -c 'SARI    K8')/$RC" "2/2/0"

echo "════ giriş / rc ════"
kos; ol "argümansız rc 2" "$RC" "2"
kos "$T/yok-boyle-dosya"; ol "dosya yok rc 3" "$RC" "3"
kos "$T/temiz" --bilinmeyen; ol "bilinmeyen bayrak rc 2" "$RC" "2"
CIKTI="$(cat "$T/k1" | bash "$L" - 2>&1)"; RC=$?; ol "stdin ('-') ile K1 → rc 1" "$RC" "1"
printf '%s\n' "# sadece yorum" "" > "$T/bos"; kos "$T/bos"; ol "sarılı satır yok → rc 0, sayı 0" "$(printf '%s' "$CIKTI" | grep -c 'sarılı satır: 0')" "1"
printf '%s\n' "35 * * * * bash /x/sarilmamis.sh" > "$T/sarilmamis"; kos "$T/sarilmamis"; ol "sarılmamış satır lint konusu değil (K6 listesi okuyucunun) → rc 0" "$RC" "0"

echo ""; echo "── SONUÇ: $gecti geçti · $dusen düştü ──"
[ "$dusen" -eq 0 ]
