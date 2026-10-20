#!/usr/bin/env bash
# K43HN vakası birebir (yalıtılmış): "kutu" rolünde ayrı bir tmux sunucusu kurulur, içindeki bir Claude'un gördüğü $TMUX verilir,
# dava-resume-olc.sh'ın çıkış tuzağındaki komut ($TMUX dolu + TMUX_TMPDIR=geçici + çıplak kill-server) $1 tmux'uyla koşulur.
# rc 0 = kutu sunucusu ayakta kaldı · rc 1 = kutu sunucusu ÖLDÜ (vaka).  Kullanım: vaka.sh <tmux yolu>
set -u
TM="${1:?tmux yolu}"; T="$(mktemp -d)"; K="$T/kutu.sok"
trap '/usr/bin/tmux -S "$K" kill-server 2>/dev/null; rm -r -f -- "$T"' EXIT
unset TMUX TMUX_PANE
# Bekçinin ret izi geçici dizine (20 Eki: bu betik canlı /config/.terminal-onar/tmux-bekcisi.log'a sahte "RED" satırı yazmıştı)
export TO_DURUM_DIZ="$T/durum"; mkdir -p "$TO_DURUM_DIZ"
/usr/bin/tmux -S "$K" -f /dev/null new-session -d -s koltuk "sleep 120"
kp="$(/usr/bin/tmux -S "$K" display -p '#{pid}')"
echo "kutu sunucusu: pid=$kp · koltuk oturumu: $(/usr/bin/tmux -S "$K" ls -F '#S' | paste -sd,)"
mkdir -p "$T/olcum"
TMUX="$K,$kp,0" TMUX_TMPDIR="$T/olcum" "$TM" kill-server; echo "kill-server rc=$?"
sleep 1
if /usr/bin/tmux -S "$K" has-session -t koltuk 2>/dev/null; then
  echo "SONUÇ: kutu sunucusu AYAKTA (pid=$(/usr/bin/tmux -S "$K" display -p '#{pid}')) — koltuk yerinde"; exit 0
else
  echo "SONUÇ: kutu sunucusu ÖLDÜ — bütün koltuklar gitti (K43HN)"; exit 1
fi
