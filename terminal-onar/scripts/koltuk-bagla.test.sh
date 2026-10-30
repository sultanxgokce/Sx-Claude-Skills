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
export KOLTUK_TUZ="$S/tuz"   # 2.24.0: kimlik tuzu geçici yolda (gerçek $HOME'a dokunulmaz)
# Sahte tmux: oturum listesi $S/oturumlar'dan; "çalıştırılan" komutlar $S/iz'e yazılır.
cat > "$S/bin/tmux" <<'T'
#!/usr/bin/env bash
case "$1" in
  list-sessions) [ -n "${SAHTE_BOZUK:-}" ] && { echo "error connecting to /tmp/tmux-1000/default (Permission denied)" >&2; exit 1; }
                 [ -n "${SAHTE_SUNUCU_YOK:-}" ] && { echo "no server running on /tmp/tmux-1000/default" >&2; exit 1; }
                 case "$3" in *session_activity*) sed 's/$/\t1760000000/' "$SAHTE/oturumlar" ;; *) cat "$SAHTE/oturumlar" ;; esac ;;
  list-panes)    if [ "$2" = -a ]; then   # tüm bölmeler: ad·pencere-etkin·bölme-etkin·kimlik·pid·komut (kimlik = %ad, sahte)
                   while IFS= read -r n; do case "$n" in BASIRET|cc-1|ZAKIR|KALFA|NEDIM|MUHASIP) k=claude; p=100 ;; *) k=bash; p=200 ;; esac
                     printf '%s\t1\t1\t%%%s\t%s\t%s\n' "$n" "$n" "$p" "$k"; done < "$SAHTE/oturumlar"
                 else t="${4#=}"; case "$t" in BASIRET|cc-1|ZAKIR|KALFA|NEDIM|MUHASIP) echo "100 claude" ;; *) echo "200 bash" ;; esac; fi ;;
  display-message) if [ "$3" = -c ]; then [ -f "$SAHTE/istemci-bilgi" ] || exit 1; cat "$SAHTE/istemci-bilgi"; else echo 1760000000; fi ;;
  set-hook)      echo "$*" >> "$SAHTE/iz-kanca" ;;
  has-session)   grep -qxF -- "${3#=}" "$SAHTE/oturumlar" ;;
  capture-pane)  case "$4" in =*) echo "can't find pane: $4" >&2; exit 1 ;; esac   # gerçek tmux gibi: bölme hedefinde '=ad' geçersiz
                 case "$4" in %*) t="${4#%}" ;; *) t="${4%:}" ;; esac; [ -f "$SAHTE/ekran-$t" ] && cat "$SAHTE/ekran-$t" || exit 1 ;;
  list-windows)  case "$*" in *window_width*) if [ -f "$SAHTE/pencereler" ]; then cat "$SAHTE/pencereler"; else echo "@1 200 50"; fi ;; *) echo "@1" ;; esac ;;
  list-clients)  [ -n "${SAHTE_ISTEMCI_BOZUK:-}" ] && exit 1; cat "$SAHTE/istemciler" 2>/dev/null; exit 0 ;;
  show-options)  cat "$SAHTE/yerel-ws" 2>/dev/null; exit 0 ;;
  set-option|resize-window) echo "$*" >> "$SAHTE/iz-set" ;;
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

echo "K · ad dışı kimlik (2.24.0 · P4GT2W: adreste müvekkil adı yerine kimlik)"
kk() { ( . ./koltuk-adi.sh; koltuk_kimlik "$1" ); }
KB=$(kk BASIRET); KC=$(kk CARSI)
[[ "$KB" =~ ^k[0-9a-f]{16}$ ]] && [ "$KB" != "$KC" ] && ok "K0 kimlik biçimi k+16 onaltılık, ad başına ayrı" || bad K0 "KB=$KB KC=$KC"
kos maiset-ana /p "$KB"
[ "$(iz)" = "attach-session -t =BASIRET" ] && ok "K1 kimlik → doğru koltuğa TAM eşleşmeli bağlanır" || bad K1 "rc=$(rc) iz=$(iz)"
kos maiset-ana /p "$KC"
[ "$(iz)" = "attach-session -t =CARSI" ] && ok "K2 başka kimlik → kendi koltuğu (ilk satıra düşmez)" || bad K2 "iz=$(iz)"
kos maiset-ana /p k0123456789abcdef
[ "$(rc)" = 3 ] && [ -z "$(iz)" ] && ok "K3 bilinmeyen kimlik → rc=3, oturum AÇILMAZ" || bad K3 "rc=$(rc) iz=$(iz)"
! grep -qE 'BASIRET|CARSI|maiset-ana' "$S/cikti" && grep -q "kimlikte bir koltuk yok" "$S/cikti" && ok "K4 🔴 kimlik reddinde koltuk ADLARI BASILMAZ (sebep yazılır)" || bad K4 "$(tr '\r' ' ' < "$S/cikti")"
kos maiset-ana /p "$(kk ttyd-maiset)"
[ "$(rc)" = 3 ] && [ -z "$(iz)" ] && ok "K5 altyapı oturumunun kimliği de açılamaz (beyaz liste aynı)" || bad K5 "rc=$(rc) iz=$(iz)"
printf '%s\n' maiset-ana BASIRET k00000000000000aa > "$S/oturumlar"
kos maiset-ana /p k00000000000000aa
[ "$(iz)" = "attach-session -t =k00000000000000aa" ] && ok "K6 kimlik biçiminde ADI olan koltuk adıyla bağlanır (ad önceliklidir)" || bad K6 "iz=$(iz)"
printf '%s\n' maiset-ana BASIRET CARSI imglistener ttyd-maiset kapi-maiset maiset-kurtarici > "$S/oturumlar"
KOLTUK_TUZ="$S/yok-dizin/tuz" kos maiset-ana /p "$KB"
[ "$(rc)" = 3 ] && [ -z "$(iz)" ] && grep -q "tuz yok" "$S/cikti" && ok "K7 tuz yaratılamazsa kimlik uydurulmaz → red, bağlanmaz" || bad K7 "rc=$(rc) iz=$(iz)"
kos maiset-ana /p BASIRET
[ "$(iz)" = "attach-session -t =BASIRET" ] && ok "K8 adla bağlanma çalışmaya devam eder" || bad K8 "iz=$(iz)"

echo "T · telefon kipi (2.25.0 · …XQY97Y D4): tel. öneki → ignore-size, masaüstü daralmaz; ad aynı kapılardan geçer"
: > "$S/iz-set"; kos maiset-ana /p tel.
[ "$(iz)" = "new-session -A -f ignore-size -s maiset-ana -c /p" ] && ok "T1 'tel.' → ana oturum ignore-size ile (yoksa açılır — argümansız yolun aynısı)" || bad T1 "$(iz)"
: > "$S/iz-set"; kos maiset-ana /p tel.BASIRET
[ "$(iz)" = "attach-session -f ignore-size -t =BASIRET" ] && [ ! -s "$S/iz-set" ] && ok "T2 'tel.<koltuk>' → TAM eşleşmeli hedefe ignore-size ile; pencere ayarına (window-size) dokunulmaz" || bad T2 "iz=$(iz) set=$(cat "$S/iz-set")"
kos maiset-ana /p "tel.$KB"
[ "$(iz)" = "attach-session -f ignore-size -t =BASIRET" ] && ok "T3 'tel.<kimlik>' → kimlik çözülür, aynı koltuğa ignore-size ile" || bad T3 "rc=$(rc) iz=$(iz)"
kos maiset-ana /p tel.YOK
[ "$(rc)" = 3 ] && [ -z "$(iz)" ] && ok "T4 🔴 olmayan koltuk telefon kipinde de reddedilir, oturum AÇILMAZ" || bad T4 "rc=$(rc) iz=$(iz)"
kos maiset-ana /p tel.ttyd-maiset
[ "$(rc)" = 3 ] && [ -z "$(iz)" ] && ok "T5 🔴 altyapı oturumu telefon kipinde de açılamaz" || bad T5 "rc=$(rc) iz=$(iz)"
kos maiset-ana /p tel.tel.BASIRET
[ "$(rc)" = 3 ] && [ -z "$(iz)" ] && ok "T6 önek bir kez ayrılır: 'tel.tel.X' geçersiz ad (nokta) → red" || bad T6 "rc=$(rc) iz=$(iz)"
kos maiset-ana /p TEL.BASIRET
[ "$(rc)" = 3 ] && [ -z "$(iz)" ] && ok "T7 önek harfi harfine: 'TEL.' telefon kipi değil, geçersiz ad → red" || bad T7 "rc=$(rc) iz=$(iz)"
kos maiset-ana /p "$KB" tel
[ "$(rc)" = 3 ] && [ -z "$(iz)" ] && ok "T8 kip ikinci argümanla verilemez (birden çok argüman reddi aynen)" || bad T8 "rc=$(rc) iz=$(iz)"
printf '%s\n' BASIRET CARSI imglistener > "$S/oturumlar"
kos maiset-ana /p tel.maiset-ana
[ "$(rc)" = 3 ] && [ -z "$(iz)" ] && ok "T9 🔴 ana oturum YOKKEN 'tel.<ana adı>' YARATMAZ (A4'ün telefon yüzü)" || bad T9 "rc=$(rc) iz=$(iz)"
printf '%s\n' maiset-ana BASIRET CARSI imglistener ttyd-maiset kapi-maiset maiset-kurtarici > "$S/oturumlar"
: > "$S/iz-set"; kos maiset-ana /p BASIRET
[ "$(iz)" = "attach-session -t =BASIRET" ] && [ -s "$S/iz-set" ] && ok "T10 öneksiz adres bugünkü gibi: bayraksız bağlanır, window-size latest yazılır" || bad T10 "iz=$(iz) set=$(cat "$S/iz-set")"

echo "P · telefon boyu (2.36.5 · telefon-terminal-zoom-boy): pencere telefondan darsa telefon boyuna BÜYÜR; masaüstü hiç küçülmez"
: > "$S/iz-kanca"; kos maiset-ana /p tel.BASIRET
grep -q "^set-hook -t =BASIRET: client-attached\[86\] if-shell -F '#{m:\*ignore-size\*,#{client_flags}}' { run-shell -b \"bash $B --tel-buyut '#{client_name}'\" }$" "$S/iz-kanca" \
  && grep -q '^set-hook -t =BASIRET: client-resized\[86\] ' "$S/iz-kanca" && [ "$(iz)" = "attach-session -f ignore-size -t =BASIRET" ] \
  && ok "P1 'tel.<koltuk>' oturuma iki kanca kurar (bağlanış + boy değişimi), yalnız ignore-size istemcide koşar; bağlanma yine ignore-size" || bad P1 "kanca=$(cat "$S/iz-kanca") iz=$(iz)"
: > "$S/iz-kanca"; kos maiset-ana /p tel.
grep -q '^set-hook -t =maiset-ana: client-resized\[86\] ' "$S/iz-kanca" && ok "P2 'tel.' (ana oturum) yolunda da kanca kurulur" || bad P2 "kanca=$(cat "$S/iz-kanca")"
: > "$S/iz-kanca"; kos maiset-ana /p BASIRET
[ ! -s "$S/iz-kanca" ] && ok "P3 öneksiz (masaüstü) adreste kanca YOK — yalnız telefon kipi" || bad P3 "kanca=$(cat "$S/iz-kanca")"
printf '%s\n' BASIRET CARSI > "$S/oturumlar"; : > "$S/iz-kanca"; kos maiset-ana /p tel.
[ "$(sed -n 1p "$S/iz")" = "new-session -d -s maiset-ana -c /p" ] && [ "$(sed -n 2p "$S/iz")" = "new-session -A -f ignore-size -s maiset-ana -c /p" ] \
  && grep -q '^set-hook -t =maiset-ana: client-resized\[86\] ' "$S/iz-kanca" \
  && ok "P2b 🔴 ana oturum YOKKEN 'tel.': önce ayrık açılır, SONRA kanca kurulur, sonra bağlanılır (yeni oturum kancasız kalmaz)" || bad P2b "iz=$(tr '\n' '|' < "$S/iz") kanca=$(cat "$S/iz-kanca")"
printf '%s\n' maiset-ana BASIRET CARSI imglistener ttyd-maiset kapi-maiset maiset-kurtarici > "$S/oturumlar"
pb() { : > "$S/iz-set"; SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --tel-buyut "${1:-/dev/pts/7}" > "$S/cikti" 2>&1; echo $? > "$S/rc"; }
psifirla() { rm -f "$S/pencereler" "$S/istemciler" "$S/yerel-ws"; printf '50\t50\toff\tattached,focused,ignore-size,UTF-8\tBASIRET\n' > "$S/istemci-bilgi"; }
setler() { tr '\n' '|' < "$S/iz-set"; }
psifirla; echo "@1 30 50" > "$S/pencereler"; pb
grep -qx 'resize-window -t @1 -x 50 -y 50' "$S/iz-set" && grep -qx 'set-option -w -u -t @1 window-size' "$S/iz-set" \
  && ok "P4 🔴 pencere 30 sütun, telefon 50 → pencere 50'ye büyür, yerel ayar silinir (manual'de kalmaz)" || bad P4 "set=$(setler)"
psifirla; echo "@1 200 50" > "$S/pencereler"; pb
[ ! -s "$S/iz-set" ] && ok "P5 pencere telefondan genişse dokunulmaz (masaüstü boyu korunur)" || bad P5 "set=$(setler)"
psifirla; echo "@1 30 50" > "$S/pencereler"; echo "attached,focused,UTF-8" > "$S/istemciler"; pb
[ ! -s "$S/iz-set" ] && ok "P6 🔴 oturumda boyu sayılan (masaüstü) istemci varsa dokunulmaz — boy onundur" || bad P6 "set=$(setler)"
psifirla; echo "@1 30 50" > "$S/pencereler"; echo "attached,focused,ignore-size,UTF-8" > "$S/istemciler"; pb
grep -qx 'resize-window -t @1 -x 50 -y 50' "$S/iz-set" && ok "P7 yalnız telefon(lar) bağlıysa büyütülür (P6 tautoloji değil)" || bad P7 "set=$(setler)"
psifirla; echo "@1 30 50" > "$S/pencereler"; echo latest > "$S/yerel-ws"; pb
grep -qx 'set-option -w -t @1 window-size latest' "$S/iz-set" && ! grep -q -- ' -u ' "$S/iz-set" && ok "P8 pencerenin yerel window-size ayarı varsa AYNEN geri yazılır" || bad P8 "set=$(setler)"
psifirla; echo "@1 30 50" > "$S/pencereler"; printf '50\t50\toff\tattached,focused,UTF-8\tBASIRET\n' > "$S/istemci-bilgi"; pb
[ ! -s "$S/iz-set" ] && ok "P9 🔴 kanca masaüstü (ignore-size'sız) istemciden gelirse hiçbir şey yapılmaz" || bad P9 "set=$(setler)"
psifirla; echo "@1 30 50" > "$S/pencereler"; rm -f "$S/istemci-bilgi"; pb
[ ! -s "$S/iz-set" ] && [ "$(rc)" = 0 ] && ok "P10 istemci ölçülemezse (gitti) dokunulmaz, sessiz çıkar" || bad P10 "rc=$(rc) set=$(setler)"
psifirla; echo "@1 30 50" > "$S/pencereler"; SAHTE_ISTEMCI_BOZUK=1 pb
[ ! -s "$S/iz-set" ] && ok "P11 oturumun istemci listesi ölçülemezse dokunulmaz (bilinmeyeni 'kimse yok' saymaz)" || bad P11 "set=$(setler)"
psifirla; printf '%s\n' "@1 60 20" "@2 40 60" > "$S/pencereler"; printf '50\t31\ton\tattached,ignore-size\tBASIRET\n' > "$S/istemci-bilgi"; pb
grep -qx 'resize-window -t @1 -x 60 -y 30' "$S/iz-set" && grep -qx 'resize-window -t @2 -x 50 -y 60' "$S/iz-set" \
  && ok "P12 her boyut ayrı büyür, hiçbiri küçülmez; durum çubuğu satırı düşülür (31 satır − 1 = 30)" || bad P12 "set=$(setler)"
psifirla; echo "@1 30 50" > "$S/pencereler"; pb "/dev/pts/1;rm"
[ ! -s "$S/iz-set" ] && ok "P13 kancadan gelen istemci adı süzülür (dar karakter kümesi)" || bad P13 "set=$(setler)"
psifirla; rm -f "$S/istemci-bilgi"

echo "R · telefon boyu GERÇEK tmux 3.4 ile (ayrı TMUX_TMPDIR; kutunun oturumlarına dokunmaz)"
if command -v tmux >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  RT="$(mktemp -d)"
  rt()  { TMUX_TMPDIR="$RT" tmux "$@"; }
  rbek() { for _ in $(seq 1 50); do [ "$(rt list-clients 2>/dev/null | wc -l)" -ge "$1" ] && return 0; sleep 0.1; done; return 1; }
  # istemci = gerçek pty (python): <sütun> <satır> [<sonra sütun> <sonra satır> <saniye>] — telefon dönünce pty boyu değişir (SIGWINCH).
  #   pty'nin girdisi açık kalır: kapanırsa koltuktaki kabuk EOF alır, 'logout' olur, oturum düşer (script ile ölçüldü).
  cat > "$RT/telpty.py" <<'PYPTY'
import os, pty, sys, time, fcntl, termios, struct, select
a = sys.argv[1:]; k = a.index('--'); v = [float(x) for x in a[:k]]; cmd = a[k+1:]
pid, fd = pty.fork()
if pid == 0: os.execvp(cmd[0], cmd)
boy = lambda c, r: (fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', int(r), int(c), 0, 0)), os.kill(pid, 28))
boy(v[0], v[1]); t0 = time.time(); d = len(v) < 5
while time.time() - t0 < 25:
    if not d and time.time() - t0 > v[4]: boy(v[2], v[3]); d = True
    if select.select([fd], [], [], 0.2)[0]:
        try: os.read(fd, 65536)
        except OSError: break
PYPTY
  rist() { ( TMUX_TMPDIR="$RT" python3 -I "$RT/telpty.py" "$@" </dev/null >>"$RT/pty.log" 2>&1 & ); }
  rilk() { rt kill-server 2>/dev/null; sleep 0.2
    rt -f /dev/null new-session -d -s KALFA -x 30 -y 50; rt new-session -d -s BASKA -x 200 -y 50
    rt set -g window-size latest; rt set -g aggressive-resize on; rt set -g status off
    rist 200 50 -- tmux attach -t =BASKA; rbek 1; }   # başka oturumda masaüstü: ignore-size telefonun YOK SAYILMASI için şart (tmux kuralı)
  rgen() { rt list-windows -t =KALFA -F '#{window_width}x#{window_height}'; }
  rbekle() { for _ in $(seq 1 40); do [ "$(rgen)" = "$1" ] && return 0; sleep 0.1; done; return 1; }   # kanca arka planda koşar
  unset TMUX TMUX_PANE
  rilk; rist 50 30 -- tmux attach -f ignore-size -t =KALFA; rbek 2; sleep 0.6; R0="$(rgen)"; R0F="$(rt list-clients -t =KALFA -F '#{client_width} #{client_flags}')"
  [ "$R0" = 30x50 ] && [[ "$R0F" == "50 "*ignore-size* ]] && ok "R0 ÖNCE (yalnız ignore-size, kancasız): telefon 50 sütunla BAĞLI ama pencere 30 sütunda kalır — sağı noktalı hatası gerçek tmux'ta üretildi" || bad R0 "→ $R0 telefon=[$R0F]"
  rilk; rist 50 30 70 30 1.5 -- bash "$B" anaoturum / tel.KALFA; rbek 2; rbekle 50x50; R1="$(rgen)"
  R1F="$(rt list-clients -t =KALFA -F '#{client_flags}')"; R1Y="$(rt show-options -wv -t KALFA: window-size 2>/dev/null)"
  [ "$R1" = 50x50 ] && [[ "$R1F" == *ignore-size* ]] && ok "R1 🔴 koltuk-bagla tel.: pencere 50x50 (telefon tam sığar, yükseklik küçülmedi), telefon ignore-size kaldı" || bad R1 "→ $R1 bayrak=$R1F günlük=$(tail -c 300 "$RT/pty.log" | tr -cd "[:print:]")"
  [ -z "$R1Y" ] && ok "R2 pencere 'manual'de kalmadı: yerel window-size silindi (global 'latest' geçerli)" || bad R2 "yerel=$R1Y"
  rt new-session -d -s POZ -x 30 -y 20; rt resize-window -t POZ: -x 40; RPZ="$(rt show-options -wv -t POZ: window-size 2>/dev/null)"; rt kill-session -t POZ
  [ "$RPZ" = manual ] && ok "R2a pozitif kontrol: show-options -wv yerel ayarı GÖRÜYOR (resize-window sonrası 'manual')" || bad R2a "→ [$RPZ]"
  rbekle 70x50; R5="$(rgen)"
  [ "$R5" = 70x50 ] && ok "R5 🔴 telefon döndü (pty 50→70 sütun): kanca pencereyi 70'e büyüttü — bağlanış anı dışında da çalışıyor" || bad R5 "→ $R5"
  # R6 (bağımsız göz #600 tur 1): ana oturum HİÇ yokken 'tel.' — yeni oturum da kancalı olmalı; telefon dönünce büyür
  # yeni oturum tmux'un son etkin istemcisinin boyunda doğar (burada 200x50); dar kalmış pencereyi taklit etmek için bağlandıktan sonra
  # pencere elle 30x20'ye çekilir, yerel ayar silinir; telefon 3 sn sonra döner (60→100) → yalnız KANCA pencereyi büyütebilir
  rist 60 30 100 30 3 -- bash "$B" YENIANA / tel.; rbek 3; sleep 1
  rt resize-window -t YENIANA: -x 30 -y 20; rt set-option -w -u -t YENIANA: window-size
  R6I="$(rt list-windows -t =YENIANA -F '#{window_width}x#{window_height}' 2>/dev/null)"
  R6K="$(rt show-hooks -t YENIANA: 2>/dev/null | grep -c 'client-resized\[86\]')"
  for _ in $(seq 1 50); do [ "$(rt list-windows -t =YENIANA -F '#{window_width}' 2>/dev/null)" = 100 ] && break; sleep 0.1; done
  R6="$(rt list-windows -t =YENIANA -F '#{window_width}x#{window_height}' 2>/dev/null)"
  [ "$R6K" = 1 ] && [ "${R6%x*}" = 100 ] && ok "R6 🔴 ana oturum yokken 'tel.': oturum doğar, kancası kurulur; pencere 30'a daralmışken telefon dönünce (60→100) kanca 100'e büyütür" || bad R6 "kanca=$R6K ilk=$R6I → $R6"
  rt kill-session -t =YENIANA 2>/dev/null
  rist 120 40 -- tmux attach -t =KALFA; rbek 3; rbekle 120x40; R3="$(rgen)"
  [ "$R3" = 120x40 ] && ok "R3 sonra masaüstü bağlanınca boy yine masaüstünün (120) — telefon onu sınırlamaz" || bad R3 "→ $R3"
  rist 90 30 -- bash "$B" anaoturum / tel.KALFA; rbek 4; sleep 1; R4="$(rgen)"
  [ "$R4" = 120x40 ] && ok "R4 🔴 masaüstü bağlıyken ikinci telefon gelince pencere 120 kalır (masaüstü daralmaz)" || bad R4 "→ $R4"
  rt kill-server 2>/dev/null; python3 -c 'import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)' "$RT"
else
  echo "  … R ÖLÇÜLEMEDİ: tmux ya da python3 yok (yeşil değil, sayılmadı)"
fi

echo "D · tür ve hâl (2.2.0: ajan ⟂ diğer · hâl son ekrandan, filo desenleri)"
# ── E · adında '/' olan oturum (dilim 5/7 · SERDAR ölçtü: vekatip '2026/85' listeden düşmüştü) ──
printf '%s\n' maiset-ana BASIRET '2026/85' 'a b' imglistener > "$S/oturumlar"
: > "$S/iz"; : > "$S/rc"; SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" maiset-ana /proje '2026/85' >/dev/null 2>&1
[ "$(iz)" = "attach-session -t =2026/85" ] && ok "E1 '/' içeren koltuk TAM eşleşmeli hedefle (=2026/85) bağlanır (eski desen reddediyordu)" || bad E1 "$(iz)"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste-e"
grep -qP '^2026/85\t' "$S/liste-e" && ok "E2 '/' içeren koltuk LİSTEDE (düşmez)" || bad E2 "$(cat "$S/liste-e")"
: > "$S/iz"; : > "$S/rc"; SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" maiset-ana /proje 'a b' >/dev/null 2>&1
[ "$(iz)" = "attach-session -t =a b" ] && ok "E3 arada boşluklu ad TAM eşleşmeli hedefle bağlanır (tmux izin verir — bağımsız göz tur 1)" || bad E3 "$(iz)"
: > "$S/iz"; : > "$S/rc"; SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" maiset-ana /proje ' a' >/dev/null 2>&1
[ -z "$(iz)" ] && ok "E3b başta boşluklu ad reddedilir (kesilip başka ada dönüşür)" || bad E3b "$(iz)"
printf '%s\n' maiset-ana BASIRET CARSI cc-1 dash ZAKIR KALFA NEDIM MUHASIP imglistener > "$S/oturumlar"
printf '%s\n' "⏺ Düşünüyor…" "esc to interrupt" > "$S/ekran-BASIRET"
printf '%s\n' "Do you want to proceed?" "❯ 1. Yes" "  2. No" "Esc to cancel)" > "$S/ekran-ZAKIR"   # meşgul izi (esc to cancel) + soru → SORU kazanır
printf '%s\n' "You've hit your usage limit · limit reached" "❯ " > "$S/ekran-KALFA"
printf '%s\n' "önceki çıktı" "❯ yarım kalmış bir cümle" > "$S/ekran-NEDIM"
printf '%s\n' "bitti." "" "❯ " > "$S/ekran-MUHASIP"
printf '%s\n' "sadece metin, istem yok" > "$S/ekran-cc-1"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste"; lrc=$?
al() { grep -P "^$1\t" "$S/liste" | cut -f"$2"; }
[ "$lrc" = 0 ] && [ "$(head -1 "$S/liste" | awk -F'\t' '{print NF}')" = 8 ] && ok "D1 liste 8 alan: ad · son · claude · tür · hâl · ne · hesap (2.14.0) · soru (2.23.0)" || bad D1 "rc=$lrc $(head -1 "$S/liste")"
[ "$(al BASIRET 4)" = ajan ] && ok "D2 Claude çalışan oturum 'ajan'" || bad D2 "$(al BASIRET 4)"
[ "$(al maiset-ana 4)" = diger ] && ok "D2b Claude'suz ANA oturum da 'diğer' (istisna yok; önde durması 'ana' bayrağının işi)" || bad D2b "$(al maiset-ana 4)"
[ "$(al CARSI 4)" = diger ] && [ "$(al dash 4)" = diger ] && ok "D3 Claude'suz oturum ve dash* 'diğer'" || bad D3 "$(al CARSI 4)/$(al dash 4)"
[ "$(al cc-1 4)" = diger ] && ok "D4 cc-* Claude çalışsa da 'diğer' (geçici oturum)" || bad D4 "$(al cc-1 4)"
[ "$(al BASIRET 5)" = calisiyor ] && ok "D5 'esc to interrupt' → çalışıyor" || bad D5 "$(al BASIRET 5)"
[ "$(al ZAKIR 5)" = soru ] && ok "D6 'Do you want to' + 'Esc to cancel' birlikte → SORU kazanır (meşgul izi soruyu gizlemez)" || bad D6 "$(al ZAKIR 5)"
[ "$(al KALFA 5)" = sinirda ] && ok "D7 'usage limit' → sınırda" || bad D7 "$(al KALFA 5)"
[ "$(al NEDIM 5)" = girdi ] && [ "$(al MUHASIP 5)" = bos ] && ok "D8 istemde yazı → girdi bekliyor · boş istem → boş" || bad D8 "$(al NEDIM 5)/$(al MUHASIP 5)"
[ "$(al cc-1 5)" = bilinmiyor ] && ok "D9 hiçbir desen tutmazsa 'bilinmiyor' (uydurma yok)" || bad D9 "$(al cc-1 5)"
[ "$(al CARSI 5)" = bilinmiyor ] && ok "D10 Claude'suz oturumun hâli ölçülmez: 'bilinmiyor' (altı değer dışına çıkılmaz)" || bad D10 "$(al CARSI 5)"
# D12: yalnız SON 15 dolu satır sayılır — 20 satır yukarıdaki eski 'esc to interrupt' güncel boş istemi 'çalışıyor' yapamaz
{ echo "esc to interrupt"; for i in $(seq 1 20); do echo "çıktı satırı $i"; done; echo "❯ "; } > "$S/ekran-BASIRET"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste3"
[ "$(grep -P '^BASIRET\t' "$S/liste3" | cut -f5)" = bos ] && ok "D12 eski satırdaki meşgul izi sayılmaz: son 15 satırda boş istem → boş" || bad D12 "$(grep -P '^BASIRET\t' "$S/liste3" | cut -f5)"
{ for i in $(seq 1 20); do echo "çıktı satırı $i"; done; echo "⏺ Düşünüyor…"; echo "esc to interrupt"; } > "$S/ekran-BASIRET"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste4"
[ "$(grep -P '^BASIRET\t' "$S/liste4" | cut -f5)" = calisiyor ] && ok "D12b güncel meşgul izi (son satırlarda) → çalışıyor (D12 tautoloji değil)" || bad D12b "$(grep -P '^BASIRET\t' "$S/liste4" | cut -f5)"
# D13 · 5. HÂL ⏳ dış olay bekliyor (Sultan 15 Eki): yazı kutusu boş + "2 shells running" → dis-olay, 6. sütun ne beklediği
{ echo "⏺ CI bekleniyor; bildirim gelince devam."; echo "❯ "; echo "──────"; echo "  2 shells still running · ⏵⏵ auto mode"; } > "$S/ekran-BASIRET"
printf '%s\n' "Bitti." "❯ " > "$S/ekran-KALFA"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste5"
[ "$(grep -P '^BASIRET\t' "$S/liste5" | cut -f5)" = dis-olay ] && ok "D13 boş kutu + 'shells running' → ⏳ dış olay bekliyor (çalışıyor DEĞİL, boş DEĞİL)" || bad D13 "$(grep -P '^BASIRET\t' "$S/liste5" | cut -f5)"
[ "$(grep -P '^BASIRET\t' "$S/liste5" | cut -f6)" = "CI bekleniyor; bildirim gelince devam." ] && ok "D13b ne beklediği --liste 6. sütununda NEDEN olarak (açıklayıcı son mesaj kabuk sayısından önce; göz tur 4); çizim cloudtop #621'in" || bad D13b "$(grep -P '^BASIRET\t' "$S/liste5" | cut -f6)"
{ echo "⏺ Bitti."; echo "❯ "; echo "──────"; echo "  2 shells still running · ⏵⏵ auto mode"; } > "$S/ekran-BASIRET"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste5b"
[ "$(grep -P '^BASIRET\t' "$S/liste5b" | cut -f5)" = dis-olay ] && [[ "$(grep -P '^BASIRET\t' "$S/liste5b" | cut -f6)" == *"2 shells still running"* ]] && ok "D13b2 açıklayıcı mesaj yoksa 'ne' kabuk sayısını taşır (hâl yine dış olay)" || bad D13b2 "$(grep -P '^BASIRET\t' "$S/liste5b" | cut -f5-6)"
[ "$(grep -P '^KALFA\t' "$S/liste5" | cut -f5)" = bos ] && [ -z "$(grep -P '^KALFA\t' "$S/liste5" | cut -f6)" ] && ok "D13c boş kutu, bekleme izi yok → boş; ne sütunu BOŞ (uydurulmaz)" || bad D13c "$(grep -P '^KALFA\t' "$S/liste5" | cut -f5-6)"
{ echo "❯ "; echo "  2 shells still running"; echo "⏺ Düşünüyor…"; echo "esc to interrupt"; } > "$S/ekran-BASIRET"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste6"
[ "$(grep -P '^BASIRET\t' "$S/liste6" | cut -f5)" = calisiyor ] && ok "D13d meşgul izi varken 'shells running' çalışıyor'u GİZLEMEZ (öncelik: çalışıyor > dış olay)" || bad D13d "$(grep -P '^BASIRET\t' "$S/liste6" | cut -f5)"
# D13e: ESKİ bir "bekleniyor" (10 satır yukarıda) güncel boş istemi dış olay YAPMAZ — yalnız son 5 satır sayılır (bağımsız göz tur 1)
{ echo "⏺ CI bekleniyor; bildirim gelince devam."; for i in $(seq 1 10); do echo "çıktı satırı $i"; done; echo "⏺ Bitti, kapattım."; echo "❯ "; } > "$S/ekran-BASIRET"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste7"
[ "$(grep -P '^BASIRET\t' "$S/liste7" | cut -f5)" = bos ] && ok "D13e eski 'bekleniyor' satırı (son 5 dışı) dış olay sayılmaz → boş" || bad D13e "$(grep -P '^BASIRET\t' "$S/liste7" | cut -f5)"
# D13f: son 5 satır İÇİNDE "bekleniyor" ama ardından "⏺ Bitti" + boş istem → bekleme bitmiş, dış olay DEĞİL → boş (bağımsız göz tur 3)
{ for i in $(seq 1 10); do echo "çıktı satırı $i"; done; echo "⏺ CI bekleniyor; bildirim gelince devam."; echo "⏺ Bitti, kapattım."; echo "❯ "; } > "$S/ekran-BASIRET"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste8"
[ "$(grep -P '^BASIRET\t' "$S/liste8" | cut -f5)" = bos ] && [ -z "$(grep -P '^BASIRET\t' "$S/liste8" | cut -f6)" ] && ok "D13f son 5 satırda 'bekleniyor' + sonra '⏺ Bitti' + boş istem → boş (bitmiş bekleme dış olay sayılmaz)" || bad D13f "$(grep -P '^BASIRET\t' "$S/liste8" | cut -f5-6)"
# D13g: alt çubuk sinyali mesajdan bağımsız — "⏺ Bitti" sonrası bile "2 shells still running" çubuğu varsa dış olay (çubuk istemin ALTINDADIR)
{ echo "⏺ Bitti, kapattım."; echo "❯ "; echo "──────"; echo "  2 shells still running"; } > "$S/ekran-BASIRET"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste9"
[ "$(grep -P '^BASIRET\t' "$S/liste9" | cut -f5)" = dis-olay ] && ok "D13g 'shells running' çubuğu son mesaja bakmaz → dış olay" || bad D13g "$(grep -P '^BASIRET\t' "$S/liste9" | cut -f5)"
# D13h-j (AZWHMF · 27 Eki): Claude Code durum çubuğu artık "· N shells ·" yazıyor ('running' YOK) — kalıp yalnız eskiyi tanıyınca arka plan işi süren koltuk "boş" görünüyordu
{ echo "⏺ Bitti."; echo "❯ "; echo "──────"; echo "  ⏵⏵ bypass permissions on · 7 shells · ← 6 agents"; } > "$S/ekran-BASIRET"
printf '%s\n' "⏺ Bitti." "❯ " "──────" "  ⏵⏵ bypass permissions on · 1 shell · ← 6 agents" > "$S/ekran-KALFA"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste10"
[ "$(grep -P '^BASIRET\t' "$S/liste10" | cut -f5)" = dis-olay ] && [[ "$(grep -P '^BASIRET\t' "$S/liste10" | cut -f6)" == *"7 shells"* ]] && ok "D13h yeni yazım '· 7 shells ·' (running yok) → dış olay, ne = '7 shells'" || bad D13h "$(grep -P '^BASIRET\t' "$S/liste10" | cut -f5-6)"
[ "$(grep -P '^KALFA\t' "$S/liste10" | cut -f5)" = dis-olay ] && ok "D13i tekil '· 1 shell ·' da dış olay" || bad D13i "$(grep -P '^KALFA\t' "$S/liste10" | cut -f5)"
{ echo "⏺ Bitti."; echo "❯ "; echo "──────"; echo "  1 shell command denendi"; } > "$S/ekran-BASIRET"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste11"
[ "$(grep -P '^BASIRET\t' "$S/liste11" | cut -f5)" = bos ] && ok "D13j NEGATİF: '1 shell command' (durum çubuğu değil, düz metin) dış olay SAYILMAZ → boş" || bad D13j "$(grep -P '^BASIRET\t' "$S/liste11" | cut -f5)"
{ echo "⏺ Bitti."; echo "❯ "; echo "──────"; echo "  İki iş için 2 shells"; } > "$S/ekran-BASIRET"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste12"
[ "$(grep -P '^BASIRET\t' "$S/liste12" | cut -f5)" = bos ] && ok "D13k NEGATİF: satır sonunda düz metin '... 2 shells' (solunda · yok, durum çubuğu değil) dış olay SAYILMAZ → boş" || bad D13k "$(grep -P '^BASIRET\t' "$S/liste12" | cut -f5)"
{ echo "⏺ Bitti."; echo "❯ "; echo "──────"; echo "  - 2 shells"; } > "$S/ekran-BASIRET"
SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/liste13"
[ "$(grep -P '^BASIRET\t' "$S/liste13" | cut -f5)" = bos ] && ok "D13l NEGATİF: madde işaretli '- 2 shells' satırı dış olay SAYILMAZ → boş" || bad D13l "$(grep -P '^BASIRET\t' "$S/liste13" | cut -f5)"
printf '%s\n' maiset-ana BASIRET CARSI imglistener ttyd-maiset kapi-maiset maiset-kurtarici > "$S/oturumlar"; rm -f "$S"/ekran-*

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


# ── H · hesap sütunu (2.14.0 · G-BANI-0008 E1 zemini): koltuktaki Claude'un hesap ADI sürecin ortamından; kural hesap_kutu.py hesap_adi ile aynı ──
# Sahte /proc: HESAP_PROC_KOK=$S/proc; sahte tmux claude bölmelerine pid 100 verir → $S/proc/100/environ. Kök/taban da sahte (gerçek /config okunmaz).
echo "H · hesap (sürecin ortamından AD; değer değil)"
mkdir -p "$S/proc/100" "$S/hes/sgk1"
hk() { HESAP_PROC_KOK="$S/proc" HESAP_KOK="$S/hes" HESAP_TABAN="$S/taban" SAHTE="$S" PATH="$S/bin:$PATH" bash "$B" --liste > "$S/listeH" 2>/dev/null; grep -P "^$1\t" "$S/listeH" | cut -f7; }
printf '%s\n' maiset-ana BASIRET CARSI > "$S/oturumlar"
printf 'HOME=/config\0CLAUDE_CONFIG_DIR=%s\0PATH=/usr/bin\0' "$S/hes/sgk1" > "$S/proc/100/environ"
[ "$(hk BASIRET)" = sgk1 ] && ok "H1 CLAUDE_CONFIG_DIR=<kök>/sgk1 → hesap sgk1 (adlı hesap)" || bad H1 "$(hk BASIRET)"
[ -z "$(hk CARSI)" ] && ok "H2 Claude'suz koltukta hesap sütunu BOŞ (uydurulmaz)" || bad H2 "'$(hk CARSI)'"
printf 'HOME=/config\0PATH=/usr/bin\0' > "$S/proc/100/environ"
[ "$(hk BASIRET)" = varsayilan ] && ok "H3 CLAUDE_CONFIG_DIR yok → varsayilan" || bad H3 "$(hk BASIRET)"
printf 'CLAUDE_CONFIG_DIR=%s/\0' "$S/taban" > "$S/proc/100/environ"
[ "$(hk BASIRET)" = varsayilan ] && ok "H4 CLAUDE_CONFIG_DIR taban dizinin kendisi (sondaki / ile) → varsayilan (normpath eşdeğeri)" || bad H4 "$(hk BASIRET)"
printf 'CLAUDE_CONFIG_DIR=%s\0ANTHROPIC_BASE_URL=http://cloudtop-kapi:4000\0' "$S/hes/sgk1" > "$S/proc/100/environ"
[ "$(hk BASIRET)" = kapi ] && ok "H5 ANTHROPIC_BASE_URL varsa → kapi (kapı şeridi hesabı EZER; adlı hesap yazsa da)" || bad H5 "$(hk BASIRET)"
printf 'CLAUDE_CONFIG_DIR=/opt/baska/yer\0' > "$S/proc/100/environ"
[ "$(hk BASIRET)" = bilinmiyor:dizin ] && ok "H6 kök dışı dizin → bilinmiyor:dizin (ad uydurulmaz)" || bad H6 "$(hk BASIRET)"
rm -f "$S/proc/100/environ"
[ "$(hk BASIRET)" = bilinmiyor:okunamadi ] && ok "H7 🔴 ortam okunamazsa 'bilinmiyor:okunamadi' — varsayilan DENMEZ (ölçülemedi ≠ varsayılan)" || bad H7 "$(hk BASIRET)"
printf 'CLAUDE_CONFIG_DIR=%s\0' "$S/hes/sgk1" > "$S/proc/100/environ"
printf '❯ \n' > "$S/ekran-BASIRET"
[ "$(hk BASIRET)" = sgk1 ] && [ "$(grep -P '^BASIRET\t' "$S/listeH" | cut -f5)" = bos ] && [ "$(grep -P '^BASIRET\t' "$S/listeH" | cut -f3)" = 1 ] && ok "H8 hesap sütunu öteki sütunları bozmaz (3. claude=1, 5. hâl=boş, 7. hesap)" || bad H8 "$(grep -P '^BASIRET\t' "$S/listeH")"
rm -f "$S/ekran-BASIRET"
# H11 (bağımsız göz tur 2): pane_pid KABUKTUR, Claude onun çocuğu; hesap değişkeni yalnız çocukta → çocuğun ortamı okunmalı (kabuğunki değil)
mkdir -p "$S/binps" "$S/proc/150"
printf '#!/usr/bin/env bash\nprintf "  100     1 bash\\n  150   100 /usr/local/bin/claude --name BASIRET\\n  200     1 bash\\n"\n' > "$S/binps/ps"; chmod +x "$S/binps/ps"
printf 'HOME=/config\0' > "$S/proc/100/environ"                                  # kabuk: hesap değişkeni YOK
printf 'CLAUDE_CONFIG_DIR=%s\0' "$S/hes/sgk1" > "$S/proc/150/environ"           # çocuk Claude: adlı hesap
h11="$(HESAP_PROC_KOK="$S/proc" HESAP_KOK="$S/hes" HESAP_TABAN="$S/taban" SAHTE="$S" PATH="$S/binps:$S/bin:$PATH" bash "$B" --liste 2>/dev/null | grep -P '^BASIRET\t' | cut -f7)"
[ "$h11" = sgk1 ] && ok "H11 🔴 bölme komutu 'claude' görünse de pane_pid kabuk: ortam ÇOCUK Claude'dan (150) okunur → sgk1 (kabuktan okunsa 'varsayilan' yalanı)" || bad H11 "$h11"
rm -r -f "$S/binps" "$S/proc/150"
# kimlik DEĞERİ hiçbir yolda okunmaz: betikte .credentials.json adı geçmez (okuma yolu yok)
grep -q "credentials" "$B" && bad H9 "betikte kimlik dosyası adı geçiyor" || ok "H9 betik kimlik dosyasına (.credentials.json) hiç dokunmaz"
# Nexus kuralıyla eşdeğerlik (hesap_kutu.py bu kutuda varsa): aynı girdiler iki dilde aynı adı vermeli
HK=/config/projects/Nexus/scripts/hesap_kutu.py
if [ -f "$HK" ]; then
  py() { HESAP_KOK="$S/hes" HESAP_TABAN="$S/taban" python3 -c "import sys; sys.argv=['x']; exec(open('$HK').read().split('\ndef _ad_gecerli')[0]);
import os
def hesap_adi(ccd, kapi):
    if kapi: return 'kapi'
    if not ccd or os.path.normpath(ccd) == os.path.normpath(TABAN): return 'varsayilan'
    if os.path.dirname(os.path.normpath(ccd)) == os.path.normpath(KOK): return os.path.basename(os.path.normpath(ccd))
    return 'bilinmiyor:dizin'
print(hesap_adi('$1', $2))"; }
  sh_adi() { HESAP_KOK="$S/hes" HESAP_TABAN="$S/taban" bash -c "source <(sed -n '/^HESAP_KOK=/,/^koltuk_hesabi()/p' '$B' | sed '\$d'); hesap_adi \"\$1\" \"\$2\"" _ "$1" "$2"; }
  esit=1
  for g in "$S/hes/sgk1|0" "|0" "$S/taban/|0" "$S/hes/sgk1|1" "/opt/baska/yer|0" "$S/hes//sgk1/|0" "$S/hes/x/../sgk1|0" "$S/hes/./sgk1/.|0" "$S/hes/sgk1/..|0" "/../$S/hes/sgk1|0" "$S/taban/../taban|0"; do
    ccd="${g%|*}"; kp="${g#*|}"; a="$(py "$ccd" "$([ "$kp" = 1 ] && echo True || echo False)")"; b="$(sh_adi "$ccd" "$kp")"
    [ "$a" = "$b" ] || { esit=0; echo "    fark: '$ccd' kapi=$kp → py=$a sh=$b"; }
  done
  [ "$esit" = 1 ] && ok "H10 kabuk hesap_adi == Nexus hesap_kutu.py hesap_adi (11 girdi: çift eğik · sondaki / · . · .. · kökte ..)" || bad H10 "iki dil ayrıştı"
else
  echo "  · H10 atlandı: hesap_kutu.py bu kutuda yok (eşdeğerlik Nexus kutusunda ölçülür)"
fi

echo "Q · soru alanı (2.23.0 · K1 Engel kurgusu · V6FJPZ): yazı kutusu varken soru yok · 8. sütun soru JSON · sır süzgeci · beri"
command -v node >/dev/null 2>&1 || { echo "  ÖLÇÜLEMEDİ: node yok — Q bölümü koşmadı"; DUSEN=$((DUSEN+1)); }
QD="$S/q"; mkdir -p "$QD"; export TO_SORU_DURUM="$QD/beri.json"
qkos() { SAHTE="$S" PATH="$S/bin:$PATH" TO_SIMDI="$2" bash "${QB:-$B}" --liste > "$QD/$1"; }
qal() { grep -P "^$2\t" "$QD/$1" | cut -f"$3"; }
qjs() { node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);console.log(eval(process.argv[1]))}catch(e){console.log("JSON-YOK")}})' "$2" <<<"$1"; }
qsil() { python3 -c 'import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)' "$1"; }
# sahte anahtar çalışma anında parçalardan kurulur (sır bekçisi dosyadaki düz biçimi haklı olarak reddeder)
SAHTE_ANAHTAR="sk""-ant-api03-$(printf 'Q%.0s' $(seq 1 32))"
printf '%s\n' maiset-ana BASIRET ZAKIR KALFA NEDIM MUHASIP > "$S/oturumlar"
# ZAKIR: izin kutusu (menü), yazı kutusu YOK
printf '%s\n' "⏺ Bash(git branch -D eski-dal)" "╭──────────────────────────╮" "│ Bash command             │" "│   git branch -D eski-dal │" "│ Do you want to proceed?  │" "│ ❯ 1. Yes                 │" "│   2. No, and tell Claude what to do differently (esc) │" "╰──────────────────────────╯" > "$S/ekran-ZAKIR"
# BASIRET: GERÇEK ekran (BÂNİ koltuğu 23 Eki 15:02: çizgi · ❯+U+00A0 · çizgi · alt çubuk) + ajanın mesajında desen metni (14:5x vakası)
cp "$(dirname "$B")/fikstur/ekran-yazi-kutulu-20261023.txt" "$S/ekran-BASIRET"
# KALFA: numarasız soru (serbest)
printf '%s\n' "⏺ Kurulum bitti." "Do you want to continue with the migration? (y/n)" > "$S/ekran-KALFA"
# NEDIM: sır taşıyan menü sorusu
printf '%s\n' "⏺ Bash(curl)" "Bash command" "  curl -H \"Authorization: Bearer $SAHTE_ANAHTAR\" https://x" "  token=abcdef1234567" "Do you want to proceed?" "❯ 1. Yes" "  2. No" > "$S/ekran-NEDIM"
printf '%s\n' "bitti." "❯ " > "$S/ekran-MUHASIP"
qkos l1 2026-10-23T12:00:00.000Z
[ "$(head -1 "$QD/l1" | awk -F'\t' '{print NF}')" = 8 ] && ok "Q1 liste 8 alan (… · hesap · soru)" || bad Q1 "$(head -1 "$QD/l1" | awk -F'\t' '{print NF}')"
[ "$(qal l1 ZAKIR 5)" = soru ] && [ "$(qjs "$(qal l1 ZAKIR 8)" 'j.tur+"/"+j.siklar.map(x=>x.no).join(",")')" = "menu/1,2" ] && ok "Q2 izin kutusu → hâl soru · 8. sütun menu, şıklar 1,2" || bad Q2 "$(qal l1 ZAKIR 5) $(qal l1 ZAKIR 8)"
[ "$(qjs "$(qal l1 ZAKIR 8)" 'j.metin.includes("git branch -D eski-dal") && j.metin.includes("Do you want to proceed?") && !/[│╭╰]/.test(j.metin)')" = true ] && ok "Q2b soru metni komutu ve soruyu taşır, kutu çizgisi yok" || bad Q2b "$(qal l1 ZAKIR 8)"
[ "$(qal l1 BASIRET 5)" != soru ] && [ -z "$(qal l1 BASIRET 8)" ] && ok "Q3 GERÇEK ekran: yazı kutusu duruyor + mesajda 'Do you want to'/'❯ 1.' → soru DEĞİL ($(qal l1 BASIRET 5)), soru sütunu boş" || bad Q3 "hal=$(qal l1 BASIRET 5) soru=$(qal l1 BASIRET 8)"
[ "$(qal l1 KALFA 5)" = soru ] && [ "$(qjs "$(qal l1 KALFA 8)" 'j.tur+"/"+j.siklar.length')" = "serbest/0" ] && ok "Q4 numarasız soru → serbest, şık yok" || bad Q4 "$(qal l1 KALFA 8)"
N8="$(qal l1 NEDIM 8)"; case "$N8" in *QQQQQQQQQQ*|*abcdef1234567*) bad Q5 "sır sızdı" ;; *"••• gizlendi"*) ok "Q5 soru metnindeki anahtar ve token=… sütuna gizlenmiş çıkar" ;; *) bad Q5 "gizlendi yok: $N8" ;; esac
[ -z "$(qal l1 MUHASIP 8)" ] && [ "$(qal l1 MUHASIP 5)" = bos ] && ok "Q6 soru hâlinde olmayan koltukta soru sütunu boş" || bad Q6 "$(qal l1 MUHASIP 5) $(qal l1 MUHASIP 8)"
# Q3b (göz #440 tur 1): 20 satırlık insan taslağı — kutunun üst çizgisi son 15 satırın DIŞINDA, taslakta 'Do you want to' / '❯ 1.' geçiyor → soru DEĞİL
{ echo "⏺ Bitti."; echo "────────────────────"; echo "❯ şunu ajana soracağım:"; for i in $(seq 1 9); do echo "  satır $i"; done; echo "  Do you want to proceed?"; echo "  ❯ 1. Yes"; echo "  2. No"; for i in $(seq 10 16); do echo "  satır $i"; done; echo "────────────────────"; echo "  ⏵⏵ bypass permissions on"; } > "$S/ekran-MUHASIP"
qkos l1b 2026-10-23T12:00:00.000Z
[ "$(qal l1b MUHASIP 5)" != soru ] && [ -z "$(qal l1b MUHASIP 8)" ] && ok "Q3b uzun çok satırlı taslak (üst çizgi son 15 satırın dışında, taslakta soru deseni) → soru DEĞİL ($(qal l1b MUHASIP 5))" || bad Q3b "hal=$(qal l1b MUHASIP 5)"
printf '%s\n' "bitti." "❯ " > "$S/ekran-MUHASIP"
qkos l2 2026-10-23T12:05:00.000Z
[ "$(qjs "$(qal l2 ZAKIR 8)" 'j.beri')" = 2026-10-23T12:00:00.000Z ] && ok "Q7 aynı soru 5 dk sonra: beri ilk görüldüğü an (12:00)" || bad Q7 "$(qjs "$(qal l2 ZAKIR 8)" 'j.beri')"
printf '%s\n' "⏺ Bitti." "❯ " > "$S/ekran-ZAKIR"; qkos l3 2026-10-23T12:10:00.000Z
[ "$(node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(d.ZAKIR?"VAR":"YOK")' "$TO_SORU_DURUM")" = YOK ] && ok "Q8 soru hâlinden çıkan koltuğun beri kaydı silinir" || bad Q8 "$(cat "$TO_SORU_DURUM")"
# ÖNCE: aynı GERÇEK ekran, yazı kutusu kapısı sökülmüş kuralla (origin/main kuralı) — hâl yanlış 'soru'
QE="$QD/eski"; qsil "$QE"; mkdir -p "$QE"; cp -r "$(dirname "$B")/../scripts" "$(dirname "$B")/../kapi" "$QE/"
python3 - "$QE/scripts/koltuk-bagla.sh" <<'PY'
import sys;p=sys.argv[1];s=open(p,encoding="utf-8").read();a='if ! yazi_kutusu_var "$genis" && printf'; assert a in s; open(p,"w",encoding="utf-8").write(s.replace(a,"if printf"))
PY
QB="$QE/scripts/koltuk-bagla.sh" qkos l0 2026-10-23T12:00:00.000Z
[ "$(qal l0 BASIRET 5)" = soru ] && ok "Q9 ÖNCE (yazı kutusu kapısı yok): aynı gerçek ekran yanlış 'soru' — Q3 bu yanlışı ölçüyor" || bad Q9 "eski kural da soru demedi: $(qal l0 BASIRET 5)"
# MUTANTLAR — terminal-onar kopyasında; her biri bir Q kapısını kırmızıya çevirmeli
mutant() {  # mutant <ad> <dosya-göreli> <eski> <yeni> <kapı-komutu: mutant yakalandıysa 0>
  local M="$QD/m-$1"; qsil "$M"; mkdir -p "$M"; cp -r "$(dirname "$B")/../scripts" "$(dirname "$B")/../kapi" "$M/"
  python3 - "$M/$2" "$3" "$4" <<'PY' || { bad "M-$1" "mutant üretilemedi (desen tutmadı)"; return; }
import sys;p,a,b=sys.argv[1:];s=open(p,encoding="utf-8").read(); assert s.count(a)>=1; open(p,"w",encoding="utf-8").write(s.replace(a,b,1))
PY
  cp "$S/ekran-NEDIM" "$QD/nedim.bak" 2>/dev/null
  printf '%s\n' "⏺ Bash(git branch -D eski-dal)" "Do you want to proceed?" "❯ 1. Yes" "  2. No" > "$S/ekran-ZAKIR"; rm -f "$TO_SORU_DURUM"
  QB="$M/scripts/koltuk-bagla.sh" qkos "o-$1" 2026-10-23T13:00:00.000Z
  if eval "$5"; then ok "M-$1 mutant yakalandı"; else bad "M-$1" "mutant YAKALANMADI — kapı süs"; fi
}
mutant kutu scripts/koltuk-bagla.sh 'if ! yazi_kutusu_var "$genis" && printf' 'if printf' '[ "$(qal o-kutu BASIRET 5)" = soru ]'
mutant sinir scripts/koltuk-bagla.sh 'for (j = i + 1; j <= NR; j++)' 'for (j = i + 1; j <= NR && j <= i + 8; j++)' '{ echo "⏺ Bitti."; echo "────────────────────"; echo "❯ şunu ajana soracağım:"; for i in $(seq 1 9); do echo "  satır $i"; done; echo "  Do you want to proceed?"; echo "  ❯ 1. Yes"; echo "  2. No"; for i in $(seq 10 16); do echo "  satır $i"; done; echo "────────────────────"; } > "$S/ekran-MUHASIP"; QB="$QD/m-sinir/scripts/koltuk-bagla.sh" qkos o-sinir2 2026-10-23T13:00:00.000Z; printf "%s\n" "bitti." "❯ " > "$S/ekran-MUHASIP"; [ "$(qal o-sinir2 MUHASIP 5)" = soru ]'
mutant pencere scripts/koltuk-bagla.sh 'if ! yazi_kutusu_var "$genis" && printf' 'if ! yazi_kutusu_var "$ekran" && printf' '{ echo "⏺ Bitti."; echo "────────────────────"; echo "❯ şunu ajana soracağım:"; for i in $(seq 1 9); do echo "  satır $i"; done; echo "  Do you want to proceed?"; echo "  ❯ 1. Yes"; echo "  2. No"; for i in $(seq 10 16); do echo "  satır $i"; done; echo "────────────────────"; echo "  ⏵⏵ bypass permissions on"; } > "$S/ekran-MUHASIP"; QB="$QD/m-pencere/scripts/koltuk-bagla.sh" qkos o-pencere2 2026-10-23T13:00:00.000Z; printf "%s\n" "bitti." "❯ " > "$S/ekran-MUHASIP"; [ "$(qal o-pencere2 MUHASIP 5)" = soru ]'
mutant suzgec kapi/sir-suz.mjs 'for (const d of SIR_DESENLERI) s = s.replace(d.desen, d.yerine || GIZLI);' '' 'grep -q QQQQQQQQQQ "$QD/o-suzgec"'
mutant okuma scripts/koltuk-bagla.sh 'soru="$(soru_oku "$s")"' 'soru=""' '[ "$(qal o-okuma ZAKIR 5)" = soru ] && [ -z "$(qal o-okuma ZAKIR 8)" ]'
mutant tut scripts/koltuk-bagla.sh 'node "$KB_DIZIN/../kapi/soru.mjs" --tut "${SO[@]}"' 'true' 'printf "%s\n" "⏺ Bitti." "❯ " > "$S/ekran-ZAKIR"; QB="$QD/m-tut/scripts/koltuk-bagla.sh" qkos o-tut2 2026-10-23T13:05:00.000Z; [ "$(node -e "const d=JSON.parse(require(\"fs\").readFileSync(process.argv[1],\"utf8\"));console.log(d.ZAKIR?1:0)" "$TO_SORU_DURUM")" = 1 ]'
unset TO_SORU_DURUM

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[ "$DUSEN" -eq 0 ]
