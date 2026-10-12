#!/usr/bin/env bash
# koltuk-bagla.test.sh — koltuk seçicinin kapıları. HERMETİK: sahte tmux ile koşar, gerçek oturuma dokunmaz.
# Ağırlık merkezi RED yüzü: adresten gelen ad uydurulamaz, altyapı oturumu açılamaz, yeni oturum doğmaz.
set -uo pipefail
cd "$(dirname "$0")"
B="$PWD/koltuk-bagla.sh"
GECEN=0; DUSEN=0
ok()  { GECEN=$((GECEN+1)); echo "  ✓ $1"; }
bad() { DUSEN=$((DUSEN+1)); echo "  ✗ $1 — $2"; }
S="$(mktemp -d)"; trap 'rm -r -f -- "$S" 2>/dev/null' EXIT
mkdir -p "$S/bin"
# Sahte tmux: oturum listesi $S/oturumlar'dan; "çalıştırılan" komutlar $S/iz'e yazılır.
cat > "$S/bin/tmux" <<'T'
#!/usr/bin/env bash
case "$1" in
  list-sessions) [ -n "${SAHTE_BOZUK:-}" ] && { echo "error connecting to /tmp/tmux-1000/default (Permission denied)" >&2; exit 1; }
                 [ -n "${SAHTE_SUNUCU_YOK:-}" ] && { echo "no server running on /tmp/tmux-1000/default" >&2; exit 1; }
                 cat "$SAHTE/oturumlar" ;;
  list-panes)    t="${4#=}"; [ "$t" = BASIRET ] && echo "100 claude" || echo "200 bash" ;;
  display-message) echo 1760000000 ;;
  list-windows)  echo "@1" ;;
  set-option)    : ;;
  new-session|attach-session) echo "$*" >> "$SAHTE/iz"; exit 0 ;;
  *) exit 1 ;;
esac
T
printf '#!/usr/bin/env bash\nexit 1\n' > "$S/bin/pgrep"
chmod +x "$S/bin/tmux" "$S/bin/pgrep"
printf '%s\n' maiset-ana BASIRET CARSI imglistener ttyd-maiset kapi-maiset maiset-kurtarici > "$S/oturumlar"
kos() { : > "$S/iz"; SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" "$@" > "$S/cikti" 2>&1; echo $? > "$S/rc"; }
iz()  { cat "$S/iz"; }
rc()  { cat "$S/rc"; }

echo "A · bağlanma (kabul yüzü)"
kos maiset-ana /p
[ "$(iz)" = "new-session -A -s maiset-ana -c /p" ] && ok "A1 argümansız → ana oturum (bugünkü davranış aynı)" || bad A1 "$(iz)"
kos maiset-ana /p BASIRET
[ "$(iz)" = "attach-session -t =BASIRET" ] && ok "A2 var olan koltuk → TAM eşleşmeli hedefle (=ad) bağlanır" || bad A2 "$(iz)"
kos maiset-ana /p maiset-ana
[ "$(iz)" = "attach-session -t =maiset-ana" ] && ok "A3 ana oturumun adı açıkça verilirse de beyaz listeden geçer (VAR → bağlanır, yaratmaz)" || bad A3 "$(iz)"
printf '%s\n' BASIRET CARSI imglistener > "$S/oturumlar"
kos maiset-ana /p maiset-ana
[ "$(rc)" = 3 ] && [ -z "$(iz)" ] && ok "A4 🔴 ana oturum YOKKEN adı açıkça verilirse YARATILMAZ (beyaz liste delinmez)" || bad A4 "rc=$(rc) iz=$(iz)"
kos maiset-ana /p
[ "$(iz)" = "new-session -A -s maiset-ana -c /p" ] && ok "A5 ... ama argümansız yol ana oturumu yine açar (A4 tautoloji değil)" || bad A5 "$(iz)"
printf '%s\n' maiset-ana BASIRET CARSI imglistener ttyd-maiset kapi-maiset maiset-kurtarici > "$S/oturumlar"

echo "B · red yüzü (adres güvenilmez girdi)"
kos maiset-ana /p YOKKOLTUK
[ "$(rc)" = 3 ] && [ -z "$(iz)" ] && ok "B1 kutuda olmayan ad → rc=3, YENİ OTURUM AÇILMAZ" || bad B1 "rc=$(rc) iz=$(iz)"
grep -q "koltuk yok" "$S/cikti" && ok "B2 red sessiz değil: sebebi ekrana basılır" || bad B2 "$(cat "$S/cikti")"
for g in ttyd-maiset kapi-maiset maiset-kurtarici imglistener; do
  kos maiset-ana /p "$g"
  [ "$(rc)" = 3 ] && [ -z "$(iz)" ] && ok "B3 altyapı oturumu açılamaz: $g" || bad "B3 $g" "rc=$(rc) iz=$(iz)"
done
for k in 'BASIRET:0' 'BASIRET.1' '=BASIRET' '^' 'a b' '../x' "$(printf 'x%.0s' {1..70})" ; do
  kos maiset-ana /p "$k"
  [ "$(rc)" = 3 ] && [ -z "$(iz)" ] && ok "B4 tmux hedef sözdizimi/kaçış reddedilir: '${k:0:12}'" || bad "B4 $k" "rc=$(rc) iz=$(iz)"
done
kos maiset-ana /p BASIRET CARSI
[ "$(rc)" = 3 ] && [ -z "$(iz)" ] && grep -q "birden çok" "$S/cikti" && ok "B7 🔴 birden çok arg (?arg=X&arg=Y) → red, ilki seçilmez" || bad B7 "rc=$(rc) iz=$(iz)"
kos maiset-ana /p BASIRET BASIRET
[ "$(rc)" = 3 ] && ok "B8 aynı ad iki kez de belirsizdir, red" || bad B8 "rc=$(rc)"
kos maiset-ana /p basiret
[ "$(rc)" = 3 ] && ok "B5 harf büyüklüğü tam eşleşir (basiret ≠ BASIRET)" || bad B5 "rc=$(rc)"
kos maiset-ana /p 'BASIRE'
[ "$(rc)" = 3 ] && ok "B6 önek eşleşmez (BASIRE ≠ BASIRET)" || bad B6 "rc=$(rc)"

echo "C · liste (tek kaynak)"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste"; lrc=$?
[ "$lrc" = 0 ] && ok "C1 --liste rc=0" || bad C1 "rc=$lrc"
[ "$(cut -f1 "$S/liste" | tr '\n' ' ')" = "maiset-ana BASIRET CARSI " ] && ok "C2 gizliler listede YOK, görünürler sırasıyla var" || bad C2 "$(cut -f1 "$S/liste" | tr '\n' ' ')"
[ "$(grep -P '^BASIRET\t' "$S/liste" | cut -f3)" = 1 ] && [ "$(grep -P '^CARSI\t' "$S/liste" | cut -f3)" = 0 ] && ok "C3 Claude çalışan koltuk işaretli, çalışmayan değil" || bad C3 "$(cat "$S/liste")"
[ "$(grep -P '^CARSI\t' "$S/liste" | cut -f2)" = 1760000000 ] && ok "C4 son etkinlik tmux'tan okunur" || bad C4 "$(cat "$S/liste")"
: > "$S/oturumlar"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste"; lrc=$?
[ "$lrc" = 0 ] && [ ! -s "$S/liste" ] && ok "C5 hiç oturum yoksa boş liste (uydurma yok)" || bad C5 "rc=$lrc"
SAHTE_BOZUK=1 SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste" 2>"$S/hata"; lrc=$?
[ "$lrc" = 3 ] && [ ! -s "$S/liste" ] && grep -q "ölçülemedi" "$S/hata" && ok "C6 🔴 tmux listesi ALINAMAZSA boş liste DEĞİL rc=3 'ölçülemedi' (C5 tautoloji değil)" || bad C6 "rc=$lrc"
SAHTE_SUNUCU_YOK=1 SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste"; lrc=$?
[ "$lrc" = 0 ] && [ ! -s "$S/liste" ] && ok "C7 tmux sunucusu hiç yoksa gerçekten boş: rc=0" || bad C7 "rc=$lrc"
printf '%s\n' maiset-ana BASIRET > "$S/oturumlar"
SAHTE_BOZUK=1 kos maiset-ana /p BASIRET
[ "$(rc)" = 3 ] && [ -z "$(iz)" ] && ok "C8 liste alınamazken koltuğa da BAĞLANILMAZ (yanlış 'yok' demez, red basar)" || bad C8 "rc=$(rc) iz=$(iz)"

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[ "$DUSEN" -eq 0 ]
