#!/usr/bin/env bash
# ffmpeg KANIT BATARYASI — "listede var" degil, "gercekten calisiyor" olcer.
FF="${1:-/config/bin/ffmpeg}"; FP="${2:-/config/bin/ffprobe}"; T=$(mktemp -d); FAIL=0
say(){ printf '%-24s %s\n' "$1" "$2"; }
ok(){ say "$1" "YESIL"; }; no(){ say "$1" "KIRMIZI  ($2)"; FAIL=1; }

"$FF" -version >/dev/null 2>&1 || { echo "ffmpeg calismiyor: $FF"; exit 9; }
say "surum" "$("$FF" -version 2>/dev/null | head -1)"

FONT=$(fc-match -f '%{file}' sans 2>/dev/null)
[ -f "$FONT" ] || FONT=$(find /usr/share/fonts /config/fonts -name '*.ttf' 2>/dev/null | head -1)
[ -f "$FONT" ] && say "font" "$FONT" || no "font" "sistemde .ttf YOK"

# 1) drawtext: rc VE piksel-degisimi birlikte
A=$("$FF" -v error -f lavfi -i color=c=black:s=320x240:d=1 -frames:v 1 -f framehash - 2>/dev/null | tail -1)
B=$("$FF" -v error -f lavfi -i color=c=black:s=320x240:d=1 \
      -vf "drawtext=fontfile=$FONT:text='KANIT':fontsize=48:fontcolor=white:x=20:y=90" \
      -frames:v 1 -f framehash - 2>/dev/null | tail -1); RC=$?
if   [ $RC -ne 0 ];                       then no "drawtext" "render rc=$RC"
elif [ -z "$B" ] || [ "$A" = "$B" ];      then no "drawtext" "piksel DEGISMEDI = yazi basilmadi"
else ok "drawtext"; fi

# 2) aac: uret + geri oku + sessiz degil
"$FF" -v error -f lavfi -i "sine=f=440:d=1" -c:a aac -b:a 128k -y "$T/a.m4a" 2>/dev/null; RC=$?
CN=$("$FP" -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$T/a.m4a" 2>/dev/null)
MV=$("$FF" -nostats -i "$T/a.m4a" -af volumedetect -f null - 2>&1 | grep -oE 'max_volume: -?[0-9.]+' | awk '{print $2}')
if   [ $RC -ne 0 ];      then no "aac-encoder" "rc=$RC"
elif [ "$CN" != "aac" ]; then no "aac-encoder" "probe codec='$CN'"
elif [ -z "$MV" ];       then no "aac-encoder" "cikti SESSIZ ya da okunamadi"
else ok "aac-encoder"; fi

# 3) ses bindirme + mp4 mux
"$FF" -v error -f lavfi -i testsrc=s=320x240:d=1 -f lavfi -i sine=f=440:d=1 \
      -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest -y "$T/v.mp4" 2>/dev/null; RC=$?
ST=$("$FP" -v error -show_entries stream=codec_type -of csv=p=0 "$T/v.mp4" 2>/dev/null | sort | tr '\n' ',')
if   [ $RC -ne 0 ];               then no "mp4+h264+aac" "rc=$RC"
elif [ "$ST" != "audio,video," ]; then no "mp4+h264+aac" "akislar='$ST'"
else ok "mp4+h264+aac"; fi

# 4) kap gercekten mp4 mi (webm'e sessiz dususu yakalar)
FMT=$("$FP" -v error -show_entries format=format_name -of csv=p=0 "$T/v.mp4" 2>/dev/null)
case "$FMT" in *mp4*) ok "mp4-kabi";; *) no "mp4-kabi" "format='$FMT'";; esac

find "$T" -type f -delete 2>/dev/null; rmdir "$T" 2>/dev/null
[ $FAIL -eq 0 ] && echo "SONUC: GECTI" || echo "SONUC: KALDI"
exit $FAIL
