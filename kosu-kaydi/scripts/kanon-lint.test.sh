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

echo "════ giriş / rc ════"
kos; ol "argümansız rc 2" "$RC" "2"
kos "$T/yok-boyle-dosya"; ol "dosya yok rc 3" "$RC" "3"
kos "$T/temiz" --bilinmeyen; ol "bilinmeyen bayrak rc 2" "$RC" "2"
CIKTI="$(cat "$T/k1" | bash "$L" - 2>&1)"; RC=$?; ol "stdin ('-') ile K1 → rc 1" "$RC" "1"
printf '%s\n' "# sadece yorum" "" > "$T/bos"; kos "$T/bos"; ol "sarılı satır yok → rc 0, sayı 0" "$(printf '%s' "$CIKTI" | grep -c 'sarılı satır: 0')" "1"
printf '%s\n' "35 * * * * bash /x/sarilmamis.sh" > "$T/sarilmamis"; kos "$T/sarilmamis"; ol "sarılmamış satır lint konusu değil (K6 listesi okuyucunun) → rc 0" "$RC" "0"

echo ""; echo "── SONUÇ: $gecti geçti · $dusen düştü ──"
[ "$dusen" -eq 0 ]
