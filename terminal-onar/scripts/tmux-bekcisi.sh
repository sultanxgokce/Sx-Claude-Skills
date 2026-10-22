#!/usr/bin/env bash
# tmux-bekcisi.sh — kutunun CANLI tmux sunucusunu içeriden kapatan çıplak `kill-server`ı durdurur.
# Kurulumu: onar.sh (K0 adım 0) bu dosyayı /config/.local/bin/tmux olarak kopyalar; PATH'te /usr/bin'den önce gelir.
# Bekçi YALNIZ şunu reddeder: $TMUX dolu (çağıran kutunun sunucusunun İÇİNDE) + açık soket yok (-L/-S) + komutlardan biri kill-server.
# Geri kalan her çağrı bayt bayt gerçek tmux'a gider (exec; çıkış kodu, girdi/çıktı aynen).
#
# 🔴 Niçin (K43HN · 16-17 Eki 2026, code kutusu, ölçüldü): bir ölçüm betiği `export TMUX_TMPDIR=<geçici>` ile kendi sunucusunu
#    kurduğunu sanıp çıkışta `tmux kill-server` koşuyordu. tmux istemcisi $TMUX doluyken TMUX_TMPDIR'ı DEĞİL $TMUX soketini
#    kullanır; betik tmux içindeki bir Claude'dan çağrıldığı için kutunun sunucusu gitti → bütün aile oturumları 4 kez birlikte
#    öldü (16 Eki 19:44 · 17 Eki 11:01 · 11:26 · 12:56). OOM değildi (oom_kill sayacı ölümlerden önce ve sonra 83).
#    Betik düzeltildi (unset TMUX); bu bekçi aynı tuzağı HER betik için kapatır — CI denetimi yetmezdi, ölümlerin dördü de
#    betik daha PR'a girmeden iş alanında koşturulurken oldu.
# Kasten kutuyu kapatmak: TMUX_KILL_SERVER_IZIN=1 tmux kill-server   (ya da: tmux -S "${TMUX%%,*}" kill-server)
# Gerçek tmux: TO_GERCEK_TMUX (sınav) → /usr/bin/tmux → /bin/tmux → /usr/local/bin/tmux; kendisi asla seçilmez.
set -u
gercek="${TO_GERCEK_TMUX:-}"
if [ -z "$gercek" ]; then
  for _a in /usr/bin/tmux /bin/tmux /usr/local/bin/tmux; do
    [ -x "$_a" ] && ! [ "$_a" -ef "$0" ] && { gercek="$_a"; break; }
  done
fi
[ -n "$gercek" ] && [ -x "$gercek" ] || { echo "tmux bekçisi: gerçek tmux bulunamadı (/usr/bin/tmux yok)" >&2; exit 127; }

if [ -n "${TMUX:-}" ] && [ "${TMUX_KILL_SERVER_IZIN:-}" != 1 ]; then
  args=("$@"); n=$#; i=0; soket=0
  # tmux getopt'u: kümelenmiş bayraklar (-2L ad · -Lad) ve argümanlı bayraklar (c f L S T)
  while [ "$i" -lt "$n" ]; do
    a="${args[$i]}"
    case "$a" in
      --) i=$((i+1)); break ;;
      -?*)
        j=1
        while [ "$j" -lt "${#a}" ]; do
          h="${a:$j:1}"
          case "$h" in
            c|f|L|S|T)
              case "$h" in L|S) soket=1 ;; esac
              [ "$j" -eq $(( ${#a} - 1 )) ] && i=$((i+1))   # argüman bir sonraki sözcükte
              break ;;
          esac
          j=$((j+1))
        done ;;
      *) break ;;
    esac
    i=$((i+1))
  done
  if [ "$soket" = 0 ]; then
    # komut konumları: ilk komut ve her ';' ayıracından sonraki sözcük (kill-server'ın tek anlamlı kısaltmaları dahil)
    konum=1
    while [ "$i" -lt "$n" ]; do
      a="${args[$i]}"
      if [ "$konum" = 1 ] && [[ "$a" =~ ^kill-ser(v(e(r)?)?)?$ ]]; then
        echo "tmux bekçisi: 'kill-server' REDDEDİLDİ — \$TMUX dolu ve açık soket (-L/-S) yok: bu, kutunun CANLI sunucusunu (bütün oturumlar) kapatırdı." >&2
        echo "  yalıtılmış sunucu içindiyse: önce 'unset TMUX' ya da 'tmux -L <ad> …' · kutuyu kasten kapatıyorsan: TMUX_KILL_SERVER_IZIN=1" >&2
        { printf '%s RED kill-server · çağıran pid=%s: ' "$(date '+%F %T')" "$PPID"; ps -o args= -p "$PPID" 2>/dev/null | cut -c1-200; } \
          >> "${TO_DURUM_DIZ:-/config/.terminal-onar}/tmux-bekcisi.log" 2>/dev/null
        exit 1
      fi
      konum=0; [ "$a" = ";" ] && konum=1
      i=$((i+1))
    done
  fi
fi
exec "$gercek" "$@"
