#!/usr/bin/env bash
# tetik-olcer.sh <kart.sh yolu | eski>   (eski = origin/main'deki kart.sh, geçici kopya dizininde) — sınıflı kartı HEDEF kuralı uygulayan tetikle açar; çıktı: rc ve kart var mı. Sahte depo, gerçek odaya mektup yok.
set -uo pipefail
KS="$1"; T="$(mktemp -d)"; trap 'rm -rf -- "$T"' EXIT
if [ "$KS" = eski ]; then   # kardeş betikler kopyalanır, yalnız kart.sh origin/main sürümüdür
  mkdir -p "$T/eski" && cp -r "$(git rev-parse --show-toplevel)/yazilim-fabrikasi/scripts/." "$T/eski/" && git show origin/main:yazilim-fabrikasi/scripts/kart.sh > "$T/eski/kart.sh" && KS="$T/eski/kart.sh" || { echo "ÖLÇÜLEMEDİ: eski kart.sh kurulamadı"; exit 3; }
fi
mkdir -p "$T/depo" && git -C "$T/depo" init -q -b main && git -C "$T/depo" -c user.email=a@b -c user.name=o commit -q --allow-empty -m i
cat > "$T/tetik.sh" <<'SH'
#!/usr/bin/env bash
h="$(head -5 "$3" | sed -n 's/^HEDEF:[[:space:]]*\([A-Za-z0-9_-]\{1,\}\).*/\1/p' | head -1)"
[ "$(printf '%s' "$h" | tr 'A-Z' 'a-z')" = "$(printf '%s' "$2" | tr 'A-Z' 'a-z')" ] || { echo "TESLİM EDİLMEDİ: hedef-yok" >&2; exit 6; }
exit 0
SH
chmod +x "$T/tetik.sh"
O="$(cd "$T/depo" && FABRIKA_TETIK="$T/tetik.sh" bash "$KS" ac is-olc --is "hedef satırı ölçümü için sınıflı iş" --istedi Sultan --aldi HENDESE --geri-alinamaz h --para e --dis-yuzey h --yetki h --oda sinav-oda </dev/null 2>&1)"; RC=$?
[ -f "$T/depo/_agents/fabrika/kartlar/is-olc.json" ] && V=var || V=yok
echo "kart.sh: $KS · rc=$RC · kart=$V"
echo "$O" | tail -n 2
