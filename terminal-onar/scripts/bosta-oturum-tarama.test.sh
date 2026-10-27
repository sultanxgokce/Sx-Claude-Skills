#!/usr/bin/env bash
# bosta-oturum-tarama.test.sh — (terminal-onar; Nexus'tan taşındı, T6YWE6) sahte tmux + sahte zil ile sınıflar, zil-defteri ve kapatma kapısı.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'find "$T" -delete' EXIT
GUN=86400; NOW=2000000000
cat > "$T/tmux" <<'X'
#!/usr/bin/env bash
case "$1" in
  list-panes) cat "$FAKE_PANES" ;;
  capture-pane) cat "$FAKE_EKRAN_DIR/$(echo "$*" | sed 's/.*-t //; s/:.*//')" 2>/dev/null ;;
  kill-session) echo "$*" >> "$FAKE_KILL" ;;
esac
X
cat > "$T/zil" <<'X'
#!/usr/bin/env bash
echo "$1" >> "$FAKE_ZIL"
X
chmod +x "$T/tmux" "$T/zil"; mkdir -p "$T/ekran"
export OT_TMUX="$T/tmux" OT_NOTIFY="$T/zil" OT_FILO=/yok OT_DEFTER="$T/d.json" OT_MUAF="$T/muaf" OT_SIMDI=$NOW
export FAKE_PANES="$T/panes" FAKE_EKRAN_DIR="$T/ekran" FAKE_KILL="$T/kill" FAKE_ZIL="$T/zilg"
printf 'serdar\n' > "$T/muaf"
pane() { printf '%s\t%s:0.0\t%s\tclaude\n' "$1" "$1" "$((NOW - $2 * GUN))"; }
{ pane taze 2; pane eski 8; pane soru 9; pane serdar 20; pane orta 6; } > "$T/panes"
printf 'Do you want to proceed?\n❯ 1. Yes\n' > "$T/ekran/soru"
echo "boş" > "$T/ekran/eski"; echo "boş" > "$T/ekran/orta"
P=0; F=0
ok() { if [ "$2" = "$3" ]; then P=$((P+1)); else F=$((F+1)); echo "✗ $1 (beklenen=$3 gelen=$2)"; fi; }
cls() { python3 "$HERE/bosta-oturum-tarama.py" "${@:2}" | awk -v k="$1" '$1==k {print $3}'; }
ok "T1 taze" "$(cls taze)" "taze"
ok "T2 Sultan-eşli muaf" "$(cls serdar)" "muaf"
ok "T3 soru penceresi dokunulmaz" "$(cls soru)" "soru"
ok "T4 ≥6g boş zil sınıfı" "$(cls eski)" "zil"
ok "T5 6g'de zil sınıfı" "$(cls orta)" "zil"
python3 "$HERE/bosta-oturum-tarama.py" >/dev/null
ok "T6 kuru koşu zil yollamaz" "$(test -e "$T/zilg" && echo var || echo yok)" "yok"
ok "T6b kuru koşu defter yazmaz" "$(jq 'length' "$T/d.json")" "0"
python3 "$HERE/bosta-oturum-tarama.py" --zil >/dev/null
ok "T7 --zil iki oturuma zil" "$(wc -l < "$T/zilg")" "2"
ok "T8 zil sonrası bekle" "$(cls eski)" "bekle"
python3 "$HERE/bosta-oturum-tarama.py" --kapat >/dev/null
ok "T9 zil 24 saat dolmadan kapatma YOK" "$(test -e "$T/kill" && echo var || echo yok)" "yok"
export OT_SIMDI=$((NOW + GUN + 60))
ok "T10 24 saat sonra eski kapat" "$(cls eski)" "kapat"
ok "T11 orta da 7g + zil 24 saat önce → kapat" "$(cls orta)" "kapat"
ok "T11b soru 10g bile olsa kapatılmaz" "$(cls soru)" "soru"
ok "T11c Sultan-eşli 21g bile olsa muaf" "$(cls serdar)" "muaf"
python3 "$HERE/bosta-oturum-tarama.py" --kapat >/dev/null
ok "T12 --kapat yalnız kapat sınıfını kapatır" "$(sort "$T/kill" | tr '\n' '|')" "kill-session -t =eski|kill-session -t =orta|"
printf '%s\t%s:0.0\t%s\tclaude\n' eski eski "$((OT_SIMDI - 60))" > "$T/panes"
export OT_SIMDI=$((NOW + 2 * GUN))
ok "T13 etkinlik değişince sayaç sıfır (taze)" "$(cls eski)" "taze"
printf '{"eski":{"zil_ts":%s,"etkinlik":%s}}' "$((NOW - 3 * GUN))" "$((NOW - 9 * GUN))" > "$T/d.json"
printf '%s\t%s:0.0\t%s\tclaude\n' eski eski "$((NOW - 8 * GUN))" > "$T/panes"
export OT_SIMDI=$((NOW + GUN))
ok "T14 zilden sonra etkinlik değiştiyse (az da olsa) eski zil geçersiz" "$(cls eski)" "zil"
printf '{}' > "$T/d.json"; printf '%s\t%s:0.0\t%s\tclaude\n' eski eski "$((NOW - 9 * GUN))" > "$T/panes"; export OT_SIMDI=$NOW
printf '#!/usr/bin/env bash\nexit 1\n' > "$T/zilkotu"; chmod +x "$T/zilkotu"
OT_NOTIFY="$T/zilkotu" python3 "$HERE/bosta-oturum-tarama.py" --zil >/dev/null; ok "T15 zil başarısızsa rc=4" "$?" "4"
ok "T15b başarısız zil deftere yazılmaz" "$(jq 'length' "$T/d.json")" "0"
printf '{"eski":{"zil_ts":%s,"etkinlik":%s}}' "$((NOW - 2 * GUN))" "$((NOW - 9 * GUN))" > "$T/d.json"
printf '#!/usr/bin/env bash\nexit 1\n' > "$T/tmuxkotu"; sed -n '2,5p' "$T/tmux" >/dev/null
cp "$T/tmux" "$T/tmuxk"; sed -i 's/kill-session) echo .*/kill-session) exit 1 ;;/' "$T/tmuxk"
OT_TMUX="$T/tmuxk" python3 "$HERE/bosta-oturum-tarama.py" --kapat >/dev/null; ok "T16 kapatma başarısızsa rc=4" "$?" "4"

# ── KUTU BAĞIMSIZLIĞI + FAIL-CLOSED (T6YWE6): araç izole kutuda Nexus'suz çalışır ──
mkdir -p "$T/home/.filo" "$T/bos"
kapat_durumu() {  # eski: 9 gün boş, zil 2 gün önce atılmış → kapat sınıfı
  printf '%s\t%s:0.0\t%s\tclaude\n' eski eski "$((NOW - 9 * GUN))" > "$T/panes"
  printf '{"eski":{"zil_ts":%s,"etkinlik":%s}}' "$((NOW - 2 * GUN))" "$((NOW - 9 * GUN))" > "$T/d.json"
  rm -f "$T/kill"; export OT_SIMDI=$NOW
}
SAF() { env -u OT_MUAF -u OT_NOTIFY HOME="$T/home" OT_NEXUS="$T/yok" PATH="$T/bos:/usr/bin:/bin" "$@"; }
kapat_durumu
SAF python3 "$HERE/bosta-oturum-tarama.py" --kapat >/dev/null 2>&1; ok "K1 muaf listesi YOKSA --kapat rc=3" "$?" "3"
ok "K1b muaf listesi yokken HİÇBİR şey kapatılmaz" "$(test -e "$T/kill" && echo var || echo yok)" "yok"
: > "$T/home/.filo/sultan-esli-koltuklar.txt"
SAF python3 "$HERE/bosta-oturum-tarama.py" --kapat >/dev/null 2>&1; ok "K2 muaf listesi BOŞSA --kapat rc=3" "$?" "3"
ok "K2b boş muaf listesiyle de kapatılmaz" "$(test -e "$T/kill" && echo var || echo yok)" "yok"
printf 'serdar # Sultan eşli\n' > "$T/home/.filo/sultan-esli-koltuklar.txt"
SAF python3 "$HERE/bosta-oturum-tarama.py" --kapat >/dev/null 2>&1; ok "K3 ~/.filo muaf listesi varken --kapat rc=0" "$?" "0"
ok "K3b varsayılan ~/.filo listesiyle kapatır" "$(cat "$T/kill" 2>/dev/null | tr '\n' '|')" "kill-session -t =eski|"
# zil kanalı: hiçbiri yoksa --zil ölçülemedi (rc 3); PATH'te ulak varsa büyük harfli hedefe gider
printf '%s\t%s:0.0\t%s\tclaude\n' eski eski "$((NOW - 9 * GUN))" > "$T/panes"; printf '{}' > "$T/d.json"; rm -f "$T/zilg"
SAF python3 "$HERE/bosta-oturum-tarama.py" --zil >/dev/null 2>&1; ok "K4 zil kanalı YOKSA --zil rc=3" "$?" "3"
printf '#!/usr/bin/env bash\necho "$*" >> "$FAKE_ZIL"\n' > "$T/bos/ulak"; chmod +x "$T/bos/ulak"
SAF python3 "$HERE/bosta-oturum-tarama.py" --zil >/dev/null 2>&1; ok "K5 PATH'te ulak varsa --zil rc=0" "$?" "0"
ok "K5b ulak gonder ESKI (büyük harf) hedefiyle çağrıldı" "$(cut -d' ' -f1,2 "$T/zilg" 2>/dev/null)" "gonder ESKI"
echo "geçti=$P kaldı=$F"; [ "$F" = 0 ]
