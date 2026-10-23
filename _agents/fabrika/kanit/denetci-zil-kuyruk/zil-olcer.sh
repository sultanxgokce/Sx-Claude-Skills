#!/usr/bin/env bash
# zil-olcer.sh <yazilim-fabrikasi/scripts dizini> — B843Q: GERÇEK Nexus aile-notify ile, MEŞGUL bir yazana (bu ölçümü koşan
#   koltuk: HENDESE — ölçüm koşarken pencere iş başında) denetçinin bitiş zili kuyruğa giriyor mu? Sahte göz, geçici depo;
#   sinyal defteri ve kuyruk GEÇİCİ dosyalara yönlenir (gerçek kayda/kuyruğa yazılmaz, boşaltıcı teslim etmez).
#   Çıkış 0 = zil kuyrukta bekliyor (alıcı HENDESE) · 1 = kuyruğa girmedi · 3 = koltuk meşgul değildi (zil doğrudan gitti → ölçüm geçersiz).
set -uo pipefail
S="$(cd "$1" && pwd)"; AN=/config/projects/Nexus/scripts/aile-notify.sh
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T"' EXIT
P="$T/d"; mkdir -p "$P"
git -C "$P" init -q -b main . && git -C "$P" config user.email s@s && git -C "$P" config user.name s && echo a > "$P/a"
git -C "$P" add -A && git -C "$P" commit -q -m "chore: zil olcer deposu"
mkdir -p "$P/_agents/fabrika/kartlar"
printf '{"is":"zil-olc","cumle":"s","istedi":"SERDAR","aldi":"HENDESE","cevaplar":{},"siniflar":[],"sultan":false,"durum":"acik","gecmis":[]}\n' > "$P/_agents/fabrika/kartlar/zil-olc.json"
( cd "$P" && KANIT_DEPO="$P" python3 "$S/kanit.py" olcum zil-olc s --asama tek -- echo o >/dev/null 2>&1 )
cat > "$T/goz.sh" <<'G'
#!/usr/bin/env bash
printf '%s' '{"kod_puani":5,"dogru_sey":"E","ozet":"s","bulgular":[],"kanit_gorusu":"s"}'
G
chmod +x "$T/goz.sh"; printf 'diff --git a/x b/x\n+y\n' > "$T/f.patch"
( cd "$P" && env -u TMUX -u TMUX_PANE AGENT_NAME=HENDESE KANIT_DEPO="$P" KART_DEPO="$P" DENETCI_KOMUT="$T/goz.sh" FABRIKA_AILE_NOTIFY="$AN" \
  AILE_SINYAL_LOG="$T/sinyal.log" AILE_KUYRUK="$T/kuyruk.log" DENETCI_KAYIT_COMMIT=0 DENETCI_KARNE=0 \
  bash "$S/denetci.sh" zil-olc --diff "$T/f.patch" --depo "$P" < /dev/null ) > "$T/out" 2>&1
echo "── denetçinin zil satırı:"; grep -E "zil|kuyrukta|gönderilemedi" "$T/out" | tail -3
echo "── geçici sinyal defteri (HENDESE'ye):"; awk -F'|' '$5=="HENDESE"{print $3"|"$4"|"$6"|"substr($7,1,70)}' "$T/sinyal.log" 2>/dev/null
b=$(awk -F'\t' '$1=="bekliyor" && $4=="HENDESE"' "$T/kuyruk.log" 2>/dev/null | wc -l)
d=$(awk -F'|' '$5=="HENDESE" && $3=="ping" && $6=="iletildi"' "$T/sinyal.log" 2>/dev/null | wc -l)
k=$(awk -F'|' '$5=="HENDESE" && $6=="kendine"' "$T/sinyal.log" 2>/dev/null | wc -l)
echo "── kuyrukta bekleyen (HENDESE): $b · doğrudan iletildi: $d · kendine düştü: $k"
[ "$d" -gt 0 ] && { echo "ÖLÇÜLEMEDİ: koltuk meşgul değildi, zil doğrudan gitti"; exit 3; }
[ "$b" -ge 1 ]
