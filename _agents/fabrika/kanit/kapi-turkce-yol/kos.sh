#!/usr/bin/env bash
# kos.sh [rev] [mutant] — rev'i (varsayılan HEAD) bütünüyle geçici dizine çıkarır; isteğe bağlı mutant uygular; olculen-commit sınavını koşar.
#   mutant 'tirnak' : 'puan sonrası değişen' farkı yeniden kaçışlı okunur (394. satırdaki core.quotepath=off kaldırılır).
#   SINAV_KAYNAK verilirse sınav dosyası o dosyayla değiştirilir (önce ölçümü: eski kapı + yeni sınav).
set -u; REV="${1:-HEAD}"; M="${2:-}"; R="$(git rev-parse --show-toplevel)"
T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
git -C "$R" archive "$REV" | tar -x -C "$T" || exit 3
[ -n "${SINAV_KAYNAK:-}" ] && cp "$SINAV_KAYNAK" "$T/yazilim-fabrikasi/scripts/birlestirme-kapisi-olculen-commit.test.sh"
KP="$T/yazilim-fabrikasi/scripts/birlestirme-kapisi.sh"
if [ "$M" = tirnak ]; then
  n="$(grep -c 'oc_fark="$(git -c core.quotepath=off -C "$oc_agac" diff --name-only' "$KP")"; [ "$n" = 1 ] || { echo "mutant çapası yok ($n)"; exit 3; }
  sed -i 's/oc_fark="$(git -c core.quotepath=off -C "$oc_agac" diff --name-only/oc_fark="$(git -C "$oc_agac" diff --name-only/' "$KP"; echo "mutant: tirnak"
fi
echo "rev: $(git -C "$R" rev-parse --short "$REV")"
bash "$T/yazilim-fabrikasi/scripts/birlestirme-kapisi-olculen-commit.test.sh" 2>&1 | grep -E '^════ O2[34]|✗|O2[34]|SONUÇ'; exit "${PIPESTATUS[0]}"
