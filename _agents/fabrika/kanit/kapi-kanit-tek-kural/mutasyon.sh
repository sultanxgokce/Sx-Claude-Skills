#!/usr/bin/env bash
# mutasyon.sh <yazilim-fabrikasi dizini> [--ana-hat <eski birlestirme-kapisi.sh>] — kanıt tek kural (retro W42 ders M3) kapılarının mutasyon ölçümü.
# Her mutant beceri dizininin TAM kopyasında koşar; önce bozulmamış KONTROL kopyası geçmeli (geçmezse rc=2). İç koşum tavanlı (124 = askıda,
# yakalama sayılmaz). --ana-hat: mutant yerine ANA HATTIN kapısını aynı sınavla koşar ve düşen kapıları basar (önce ölçümü).
set -uo pipefail
SRC="$(cd "$1" && pwd)"; KOK="$(mktemp -d)"; yakalanan=0; kacan=0; askida=0
kos() { ( cd "$1/scripts" && timeout 600 bash birlestirme-kapisi.test.sh </dev/null >"$1/cikti.txt" 2>&1 ); }
kopya() { local d="$KOK/$1"; mkdir -p "$d"; cp -a "$SRC/." "$d/"; echo "$d"; }
if [ "${2:-}" = "--ana-hat" ]; then
  d="$(kopya ana-hat)"; cp "$3" "$d/scripts/birlestirme-kapisi.sh"; kos "$d"; rc=$?
  echo "ANA HAT kapısı + bu dalın sınavı → rc=$rc"; grep -E "✗|SONUÇ" "$d/cikti.txt"; exit 0
fi
K="$(kopya kontrol)"; kos "$K" || { echo "✗ KONTROL kopyası kırmızı — mutasyon ölçülemez"; grep "✗" "$K/cikti.txt"; exit 2; }
echo "✓ kontrol kopyası yeşil ($(grep -o 'SONUÇ: [0-9]* geçti' "$K/cikti.txt"))"
mut() {  # mut <ad> <eski> <yeni>  (scripts/birlestirme-kapisi.sh içinde, tam bir kez geçmeli)
  local d; d="$(kopya "$1")"
  python3 - "$d/scripts/birlestirme-kapisi.sh" "$2" "$3" <<'PY' || { echo "✗ mutant '$1': çapa yok (bayat)"; kacan=$((kacan+1)); return; }
import sys
p, eski, yeni = sys.argv[1:4]; s = open(p, encoding="utf-8").read()
if s.count(eski) != 1: raise SystemExit(1)
open(p, "w", encoding="utf-8").write(s.replace(eski, yeni))
PY
  kos "$d"; local rc=$?
  if [ $rc = 124 ]; then askida=$((askida+1)); echo "⏸ mutant '$1' askıda (124) — yakalama SAYILMAZ"
  elif [ $rc != 0 ]; then yakalanan=$((yakalanan+1)); echo "✓ mutant '$1' sınavı KIRMIZI yapıyor"
  else kacan=$((kacan+1)); echo "✗ mutant '$1' KAÇTI (sınav yeşil kaldı)"; fi
}
mut is-alani-aranmaz $'mapfile -t agaclar < <(printf \'%s\\n\' "$WT"; git -C "$DEPO" worktree list --porcelain 2>/dev/null | sed -n \'s/^worktree //p\')' $'mapfile -t agaclar < <(printf \'%s\\n\' "$WT")'
mut dal-bakilmaz 'if [ -f "$yol/KANIT.json" ] && dal_tutar "$t"; then' 'if [ -f "$yol/KANIT.json" ]; then'
mut pr-basi-okunmaz 'if [ -n "$PR" ] && git -C "$DEPO" remote get-url origin' 'if false && git -C "$DEPO" remote get-url origin'
mut birincil-aranmaz 'if [ -f "$DEPO/_agents/fabrika/kanit/$IS/KANIT.json" ]; then DZ=' 'if false; then DZ='
mut onek-atilmaz '[ "${b##*/}" = "$IS" ]; }' '[ "$b" = "$IS" ]; }'
mut yer-sessiz '_y "  · kanıt yeri: $DZ_YER"' ':'
echo "── SONUÇ: $yakalanan yakalandı · $kacan kaçtı · $askida askıda ──"
[ "$kacan" = 0 ] && [ "$askida" = 0 ]
