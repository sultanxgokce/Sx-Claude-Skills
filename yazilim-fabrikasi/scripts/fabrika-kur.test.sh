#!/usr/bin/env bash
# fabrika-kur.test.sh — hat dosyası kurulumu ve drift denetimini sahte depoda koşturur.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FK="$HERE/fabrika-kur.sh"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }

T="$(mktemp -d)"; mkdir -p "$T/depo"
( cd "$T/depo" && git init -q -b main && git config user.email t@t && git config user.name T &&
  printf '# Proje\n\nkural 1\n' > CLAUDE.md && git add -A && git commit -qm "chore: ilk" ) >/dev/null 2>&1

echo "════ T0 · şablon tavanı ════"
[ "$(wc -l < "$HERE/../sablon/FABRIKA.md")" -le 40 ]; g $? "şablon ≤ 40 satır ($(wc -l < "$HERE/../sablon/FABRIKA.md"))"
! grep -qiE 'next\.js|react|prisma|tailwind|npm test|pnpm' "$HERE/../sablon/FABRIKA.md"; g $? "şablonda kod tabanı/çerçeve adı yok"

echo "════ T1 · denetle: kurulmamış depoda rc=3 ════"
bash "$FK" denetle "$T/depo" >/dev/null 2>&1; [ $? -eq 3 ]; g $? "hat yokken rc=3 (ölçülemedi, yeşil değil)"

echo "════ T2 · kur: dosya + işaretçi ════"
CIKTI="$(bash "$FK" kur "$T/depo" 2>&1)"; g $? "kur rc=0"
[ -f "$T/depo/FABRIKA.md" ]; g $? "FABRIKA.md kuruldu"
cmp -s "$T/depo/FABRIKA.md" "$HERE/../sablon/FABRIKA.md"; g $? "içerik şablonla birebir"
[ "$(sed -n 3p "$T/depo/CLAUDE.md")" = "@FABRIKA.md" ]; g $? "işaretçi başlığın altına, tek satır"
[ "$(grep -c '^@FABRIKA.md$' "$T/depo/CLAUDE.md")" -eq 1 ]; g $? "işaretçi bir kez"
grep -q 'kural 1' "$T/depo/CLAUDE.md"; g $? "CLAUDE.md'nin kendi içeriği korundu"
bash "$FK" denetle "$T/depo" >/dev/null 2>&1; g $? "denetle rc=0"

echo "════ T3 · ikinci kur idempotent ════"
bash "$FK" kur "$T/depo" >/dev/null 2>&1; g $? "ikinci kur rc=0"
[ "$(grep -c '^@FABRIKA.md$' "$T/depo/CLAUDE.md")" -eq 1 ]; g $? "işaretçi çoğalmadı"

echo "════ T4 · drift: elle değişiklik yakalanır, kur üstüne yazmaz ════"
echo "kutu satırı" >> "$T/depo/FABRIKA.md"
bash "$FK" denetle "$T/depo" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "drift rc=1"
bash "$FK" kur "$T/depo" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "kur --zorla'sız REDDETTİ (elle değişikliği ezmedi)"
grep -q "kutu satırı" "$T/depo/FABRIKA.md"; g $? "elle değişiklik yerinde duruyor"
bash "$FK" kur "$T/depo" --zorla >/dev/null 2>&1; g $? "kur --zorla rc=0"
bash "$FK" denetle "$T/depo" >/dev/null 2>&1; g $? "zorla sonrası drift yok"

echo "════ T5 · işaretçi silinirse denetle kırmızı ════"
sed -i '/^@FABRIKA.md$/d' "$T/depo/CLAUDE.md"
bash "$FK" denetle "$T/depo" >/dev/null 2>&1; [ $? -eq 1 ]; g $? "işaretçi yokken rc=1"
bash "$FK" kur "$T/depo" >/dev/null 2>&1 && bash "$FK" denetle "$T/depo" >/dev/null 2>&1; g $? "kur işaretçiyi geri koydu"

echo "════ T6 · CLAUDE.md olmayan depo ════"
mkdir -p "$T/bos" && ( cd "$T/bos" && git init -q -b main ) >/dev/null 2>&1
bash "$FK" kur "$T/bos" >/dev/null 2>&1; g $? "kur rc=0"
[ "$(cat "$T/bos/CLAUDE.md")" = "@FABRIKA.md" ]; g $? "CLAUDE.md işaretçiyle oluşturuldu"

echo "════ T7 · --kanca ════"
bash "$FK" kur "$T/depo" --kanca >/dev/null 2>&1; g $? "kur --kanca rc=0"
[ -x "$T/depo/.githooks/pre-commit" ] && [ "$(git -C "$T/depo" config core.hooksPath)" = ".githooks" ]; g $? "kanca kurulu"

find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null
echo ""
echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
