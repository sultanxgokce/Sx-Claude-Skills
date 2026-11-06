#!/usr/bin/env bash
# canli-dinle sınavı: sahte HLS yayını + sahte Groq/whisper. Gerçek ağ ve gerçek anahtar yok.
# Mutant modu: MUTANT=kirpma|ortu|arac-sirasi  (kirpma = sahiplik süzgeci kapalı; ortu = pencereler örtüşür; arac-sirasi = yt-dlp önce)
set -u
D="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'kill $(cat "$T/sunucu.pid" 2>/dev/null) 2>/dev/null; rm -r "$T"' EXIT
GEC=0; FAIL=0
ok(){ echo "  ✓ $1"; GEC=$((GEC+1)); }
bad(){ echo "  ✗ $1"; FAIL=$((FAIL+1)); }
PY="$T/canli_dinle.py"; cp "$D/canli_dinle.py" "$PY"
case "${MUTANT:-}" in
  kirpma) python3 - "$PY" <<'M'
import sys; s=open(sys.argv[1]).read(); s=s.replace("    return [(t, w) for t, w in sozcukler if bas <= t < bit]","    return list(sozcukler)"); open(sys.argv[1],"w").write(s)
M
  ;;
  ortu) python3 - "$PY" <<'M'
import sys; s=open(sys.argv[1]).read(); s=s.replace("else i * parca_sn - ortu_sn / 2.0","else i * parca_sn - ortu_sn * 1.0"); open(sys.argv[1],"w").write(s)
M
  ;;
  arac-sirasi) python3 - "$PY" <<'M'
import sys; s=open(sys.argv[1]).read(); s=s.replace('("streamlink", "yt-dlp")','("yt-dlp", "streamlink")'); open(sys.argv[1],"w").write(s)
M
  ;;
esac
export FAKE_P=4 FAKE_O=1 GROQ_API_KEY=GIZLI-DEGER-123
echo "── T1 araç seçimi"
mkdir -p "$T/b1" "$T/b2"; : >"$T/b1/streamlink"; : >"$T/b1/yt-dlp"; : >"$T/b2/yt-dlp"; chmod +x "$T"/b?/*
sec(){ python3 -c "import sys;sys.path.insert(0,'$T');import canli_dinle as c;print(c.arac_sec('$1'))"; }
[ "$(sec "$T/b1")" = streamlink ] && ok "ikisi de varsa streamlink" || bad "streamlink önceliği"
[ "$(sec "$T/b2")" = yt-dlp ] && ok "yalnız yt-dlp varsa yt-dlp" || bad "yt-dlp yedeği"
[ "$(sec "$T/yok")" = ffmpeg ] && ok "hiçbiri yoksa ffmpeg doğrudan" || bad "ffmpeg yedeği"
echo "── T2 yakalama komutu"
python3 -c "import sys;sys.path.insert(0,'$T');import canli_dinle as c
k=c.yakala_komutu('streamlink','https://x/y',30,'/o',0);assert k.startswith('streamlink --stdout') and '| ffmpeg' in k and 'segment_time 30' in k and 'ar 16000 -ac 1' in k,k
k=c.yakala_komutu('ffmpeg','https://x/y',30,'/o',600);assert k.startswith('ffmpeg') and '-t 600' in k and '|' not in k,k" && ok "streamlink boru hattı; ffmpeg doğrudan, süre sınırı" || bad "komut biçimi"
echo "── T3 sahte yayın uçtan uca (Groq)"
ffmpeg -nostdin -loglevel error -f lavfi -i "sine=frequency=440:duration=14" -c:a aac -f hls -hls_segment_type fmp4 -hls_time 2 -hls_playlist_type vod "$T/y.m3u8" || { bad "fikstür üretilemedi"; exit 1; }
python3 "$D/sahte-sunucu.py" "$T/port" & echo $! >"$T/sunucu.pid"
for _ in $(seq 1 50); do [ -s "$T/port" ] && break; sleep 0.1; done
export CANLI_DINLE_GROQ_URL="http://127.0.0.1:$(cat "$T/port")" CANLI_DINLE_ARAC=ffmpeg
BEKLENEN="$(for n in $(seq 0 13); do printf 'k%d ' "$n"; done)"
CIK(){ python3 "$PY" "$T/y.m3u8" --parca-sn 4 --ortu-sn 1 --pencere-sn 6 --cikti "$1" "${@:2}"; }
CIK "$T/c1" --not >"$T/o1" 2>&1; RC=$?
M="$(cat "$T"/c1/*/metin.txt 2>/dev/null | sed "s/ *$//")"
[ $RC -eq 0 ] && ok "rc 0" || bad "rc $RC: $(tail -3 "$T/o1")"
[ "$M" = "${BEKLENEN% }" ] && ok "metin kesintisiz ve çift sözcüksüz (k0..k13)" || bad "metin: '$M'"
N="$(ls "$T"/c1/*/parca-*.wav | grep -vc ortulu)"; [ "$N" -eq 4 ] && ok "4 parça (4+4+4+2 sn)" || bad "parça sayısı $N"
echo "── T4 10 dk pencerede özet"
O="$(cat "$T"/c1/*/ozet.md 2>/dev/null)"
[ "$(echo "$O" | grep -c 'ÖZET(6)')" -eq 2 ] && echo "$O" | grep -q 'ÖZET(2)' && ok "pencereler 6 sn: 6+6+2 sözcük" || bad "özet: $O"
echo "── T5 yerel kaynak (sahte whisper.cpp)"
export WHISPER_CLI="$D/sahte-whisper.py" FAKE_SAYAC="$T/say" WHISPER_MODEL=/yok
rm -f "$T/say"
CIK "$T/c2" --kaynak yerel >"$T/o2" 2>&1; RC=$?
M2="$(cat "$T"/c2/*/metin.txt 2>/dev/null | sed "s/ *$//")"
[ $RC -eq 0 ] && [ "$M2" = "${BEKLENEN% }" ] && ok "yerel yol aynı metni verir" || bad "yerel rc $RC metin '$M2'"
echo "── T6 anahtar"
if grep -rq GIZLI-DEGER-123 "$T"/c1 "$T"/c2 "$T/o1" "$T/o2" 2>/dev/null; then bad "anahtar çıktıya/kutuya sızdı"; else ok "anahtar hiçbir çıktıda yok"; fi
( unset GROQ_API_KEY; CANLI_DINLE_ANAHTAR_DOSYASI=/yok python3 "$PY" "$T/y.m3u8" --cikti "$T/c3" >"$T/o3" 2>&1 ); [ $? -eq 3 ] && ok "anahtarsız rc 3" || bad "anahtarsız davranış"
echo "sonuç: $GEC geçti, $FAIL kaldı"; [ $FAIL -eq 0 ]
