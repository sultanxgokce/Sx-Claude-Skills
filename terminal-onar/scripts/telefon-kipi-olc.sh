#!/usr/bin/env bash
# telefon-kipi-olc.sh <koltuk-bagla.sh> — GERÇEK tmux 3.4 + GERÇEK koltuk-bagla.sh: ayrı TMUX_TMPDIR (kutunun oturumlarına dokunmaz), 'window-size smallest'
# (infra/tmux.conf), 200 sütunluk masaüstü istemcisi + 50 sütunluk "telefon" istemcisi koltuk-bagla.sh üzerinden bağlanır.
# Ölçülen: telefon bağlıyken pencere genişliği. Öneksiz (bugünkü yol) → 50'ye daralır (pozitif kontrol) · 'tel.' önekli → 200 kalır.
set -u
KB="$1"; r=0
export TMUX_TMPDIR="$(mktemp -d)"; unset TMUX
ilk() {
  tmux kill-server 2>/dev/null
  tmux -f /dev/null new-session -d -s anaoturum -x 200 -y 50; tmux new-session -d -s KALFA -x 200 -y 50
  tmux set-option -g window-size smallest
}
bekle() { for i in $(seq 1 40); do [ "$(tmux list-clients 2>/dev/null | wc -l)" -ge "$1" ] && return 0; sleep 0.2; done; return 1; }
olc() {   # $1 oturum (masaüstünün bağlandığı) · $2 telefonun adres argümanı ('' = argümansız)
  ilk
  script -qfc "stty cols 200 rows 50; tmux attach-session -t =$1" /dev/null > /dev/null 2>&1 &
  bekle 1
  script -qfc "stty cols 50 rows 30; bash '$KB' anaoturum / $2" /dev/null > /dev/null 2>&1 &
  bekle 2; sleep 0.5
  echo "$(tmux list-clients -F '#{client_width}#{?#{m:*ignore-size*,#{client_flags}}, ignore-size,}' | tr '\n' ' ')→ pencere $(tmux display-message -p -t "$1:" '#{window_width}')"
  tmux kill-server 2>/dev/null; wait 2>/dev/null
}
a=$(olc KALFA KALFA);        echo "koltuk, öneksiz (bugün)   : $a"
b=$(olc KALFA tel.KALFA);    echo "koltuk, tel. önekli       : $b"
c=$(olc anaoturum '');       echo "ana, argümansız (bugün)   : $c"
d=$(olc anaoturum tel.);     echo "ana, tel.                 : $d"
[[ "$a" == *"→ pencere 50" ]] || { echo "✗ pozitif kontrol: öneksiz telefon koltuğu daraltmadı — düzen bozuk"; r=1; }
[[ "$b" == *"ignore-size"* && "$b" == *"→ pencere 200" ]] || { echo "✗ tel.<koltuk> masaüstünü daralttı"; r=1; }
[[ "$c" == *"→ pencere 50" ]] || { echo "✗ pozitif kontrol: argümansız telefon ana oturumu daraltmadı — düzen bozuk"; r=1; }
[[ "$d" == *"ignore-size"* && "$d" == *"→ pencere 200" ]] || { echo "✗ tel. ana oturumu daralttı"; r=1; }
python3 -c 'import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)' "$TMUX_TMPDIR"
[ $r = 0 ] && echo "✓ gerçek tmux: öneksiz telefon pencereyi 50 sütuna indiriyor; tel. önekiyle (koltuk ve ana) pencere 200 sütunda kalıyor"
exit $r
