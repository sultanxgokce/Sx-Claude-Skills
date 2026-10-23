#!/usr/bin/env bash
# olc-komut.sh <paket-scripts-dizini> — Sultan'a giden iki yüzeyde (oda tetiğinin gövdesi + gün sonu "Sultan'a gidenler" bölümü)
# 'kart.sh' kaç kez geçiyor? Beklenen (0.19.0 göz tur 2): 0 ve iki yüzey de dolu → rc 0; >0 → rc 1; yüzey boş → rc 3 (ölçülemedi).
set -uo pipefail
P="$1"; T="$(mktemp -d)"; mkdir -p "$T/depo"
( cd "$T/depo" && git init -q -b main && git config user.email t@t && git config user.name T && echo x > f && git add -A && git commit -qm "chore: ilk" ) >/dev/null 2>&1
cat > "$T/tetik-sahte.sh" <<'TT'
#!/usr/bin/env bash
printf '%s\t%s\n' "$2" "$(tr '\n' ' ' < "$3")" >> "$TETIK_KAYIT"; exit 0
TT
chmod +x "$T/tetik-sahte.sh"; : > "$T/tetik.tsv"
export KANIT_DEPO="$T/depo" FABRIKA_TETIK="$T/tetik-sahte.sh" TETIK_KAYIT="$T/tetik.tsv" FABRIKA_AILE_NOTIFY=- DEFTER_JETON_YOL="$T/jeton-yok"
cd "$T/depo"
bash "$P/kart.sh" ac olcum-sinifli --is "Sultan satırı ölçümü" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki e --oda olcum-oda >/dev/null 2>&1
echo "── kart.sh ac rc=$? (paket: $P)"
GOVDE="$(grep -P '^olcum-oda\t' "$T/tetik.tsv")"
echo "── oda tetiğinin Sultan'a giden gövdesi:"; printf '%s\n' "$GOVDE"
GS="$(bash "$P/gun-sonu.sh" 2>&1)"; echo "── gun-sonu.sh rc=$?"
BOLUM="$(awk '/^## Sultan.a gidenler/{f=1;print;next} f&&/^## /{f=0} f' <<<"$GS")"
echo "── gün sonu 'Sultan'a gidenler' bölümü:"; printf '%s\n' "$BOLUM"
N1="$(grep -o 'kart\.sh' <<<"$GOVDE" | wc -l)"; N2="$(grep -o 'kart\.sh' <<<"$BOLUM" | wc -l)"
echo "SAYIM: tetik gövdesi kart.sh=$N1 · gün sonu bölümü kart.sh=$N2 · toplam=$((N1+N2))"
if [ -z "$GOVDE" ] || [ "$(grep -c . <<<"$BOLUM")" -lt 2 ]; then echo "SONUÇ: Sultan'a giden yüzeylerden biri boş — ölçülemedi"; exit 3; fi
if [ $((N1+N2)) -eq 0 ]; then echo "SONUÇ: Sultan'a giden satırlarda komut YOK"; exit 0; fi
echo "SONUÇ: Sultan'a giden satırlarda komut VAR"; exit 1
