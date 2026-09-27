#!/usr/bin/env bash
# kademe.sh — onarım MERDİVENİ. Her kademe bir öncekinin bıraktığı yerden devam eder:
#   K0 onar.sh (betik, saniyeler)
#   K1 başsız Claude (claude -p, en çok 10 dk) — YALNIZ onarım betiklerine + okumaya izinli
#   K2 kurtarıcı ajan (tmux sedir-kurtarici) ← /terminal-onar komutu, en çok 20 dk izlenir
#   K3 Sultan'a WhatsApp: "elle bakılmalı" + son günlük satırları
#
#   --kaynak <dugme|bekci|elle>   kim tetikledi (günlüğe yazılır)
#   --arka                        kendini arka plana ayırıp hemen döner (tetikleyen ölse de iş sürer)
#
# Yarıda kalmama: tek kilit (flock) → aynı anda iki merdiven koşmaz. Merdiven ölürse bekçi
# bir dakika içinde durumu yeniden ölçer ve merdiveni baştan başlatır; her kademe idempotenttir.
# Soğuma: bekçi tetiklediğinde K1/K2 15 dakikada bir defadan sık denenmez (düğme/elle bunu atlar).
# Sultan-onayı: 2026-09-25, izin sormayan modda açık onayla kuruldu (gözetimsiz ajan kademesi).
set -u
. "$(dirname "$0")/ortak.sh"

KAYNAK=elle; ARKA=0
while [ $# -gt 0 ]; do case "$1" in
  --kaynak) KAYNAK="$2"; shift 2 ;; --arka) ARKA=1; shift ;; *) shift ;; esac; done

if [ $ARKA = 1 ]; then
  setsid nohup bash "$0" --kaynak "$KAYNAK" >> "$DURUM_DIZ/kademe.out" 2>&1 < /dev/null &
  echo "merdiven arka planda başladı (günlük: $GUNLUK)"; exit 0
fi

exec 9> "$DURUM_DIZ/kademe.lock"
flock -n 9 || { echo "zaten bir onarım sürüyor"; exit 0; }
echo "koşuyor $(date -Is) kaynak=$KAYNAK" > "$DURUM_DIZ/kademe.durum"
bitir() { echo "$1 $(date -Is) kaynak=$KAYNAK" > "$DURUM_DIZ/kademe.durum"; gunluk "MERDİVEN $1"; }
saglam() { bash "$BETIK_DIZ/durum.sh" >/dev/null 2>&1; }
son() { tail -n 8 "$GUNLUK" | sed 's/^/  /'; }

gunluk "MERDİVEN başladı (kaynak=$KAYNAK)"
bash "$BETIK_DIZ/onar.sh"; k0=$?
if [ $k0 = 0 ]; then
  bitir "tamam:K0"
  [ "$KAYNAK" = bekci ] && haber "🔧 Sedir terminali kendini onardı (otomatik). Durum: sağlam."
  [ "$KAYNAK" = dugme ] && haber "✅ Sedir terminali sağlam (Onar düğmesi)."
  exit 0
fi

sogudu() {  # $1 = kademe adı; bekçi için 15 dk soğuma
  [ "$KAYNAK" = bekci ] || return 0
  local f="$DURUM_DIZ/son-$1"
  [ -f "$f" ] && [ $(( $(date +%s) - $(stat -c %Y "$f") )) -lt 900 ] && return 1
  touch "$f"; return 0
}

# K1 · başsız Claude
if sogudu K1; then
  gunluk "K1 başsız Claude devrede"
  timeout 600 claude -p "Sen SEDİR terminal-onarım kademesi K1'sin. /terminal-onar becerisini uygula.
Kademe 0 (onar.sh) düzeni onaramadı. Son günlük:
$(son)
Görevin: $BETIK_DIZ/durum.sh ile ölç, sebebi bul, onar.sh (gerekirse --web-yenile) ile düzelt.
Durum 'sağlam' olunca bitir. Sır değerini asla yazdırma." \
    --permission-mode default --allowedTools "Bash(bash $BETIK_DIZ/*)" Read Grep Glob \
    >> "$DURUM_DIZ/k1.out" 2>&1
  saglam && { bitir "tamam:K1"; haber "🔧 Sedir terminali onarıldı (başsız Claude, kademe 1)."; exit 0; }
  gunluk "K1 onaramadı"
fi

# K2 · kurtarıcı ajan
if sogudu K2; then
  gunluk "K2 kurtarıcı ajana komut gidiyor"
  if claude_oturumu "$KURT_TMUX" >/dev/null; then
    tmux send-keys -t "$KURT_TMUX" -l "/terminal-onar onar — kademe 0 ve 1 başaramadı, merdivenden geldi (kaynak=$KAYNAK). Günlük: $GUNLUK"
    tmux send-keys -t "$KURT_TMUX" Enter
    for i in $(seq 1 60); do sleep 20; saglam && break; done
    saglam && { bitir "tamam:K2"; haber "🔧 Sedir terminali onarıldı (kurtarıcı ajan, kademe 2)."; exit 0; }
    gunluk "K2 20 dk içinde onaramadı"
  else
    gunluk "K2 kurtarıcı ajan da ayakta değil"
  fi
fi

# K3 · insan
bitir "basarisiz"
haber "🚨 Sedir terminali ONARILAMADI — elle bakılmalı.
$(bash "$BETIK_DIZ/durum.sh" 2>/dev/null)
Son adımlar:
$(son)"
exit 1
