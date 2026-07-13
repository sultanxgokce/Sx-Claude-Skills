#!/usr/bin/env bash
# ogren.sh — sultan-uslubu.md'ye aday-kayıt EKLE (tek-yazar, flock).
#
# Sultan-üslûbu store'un tek-yazma-yolu (katip.py emsali: şema/id/kilit tek-kaynak).
# /sultan-ogren manuel-hattı + opsiyonel recall-hook bunu çağırır. Yeni kayıt DAİMA
# 'aday' (tentatif); pekiştirme (aday→onaylı) insan/skill eli (bloğu 🟢'ya taşı).
#
# Kullanım:
#   ogren.sh --eksen <dil|cikti-tasarim|cikti-format|ifade> --kural "<tek-cümle>" \
#            [--kanit "<Sultan-verbatim + tarih>"] [--ornek "<önce→sonra>"] [--guven aday|onayli]
# Store: SULTAN_USLUBU env ya da /config/.claude/sultan-uslubu.md.
# Fail-safe: eksik --kural / geçersiz --eksen → rc=2. Determinizm: id=max(seq)+1.
set -uo pipefail

STORE="${SULTAN_USLUBU:-/config/.claude/sultan-uslubu.md}"
eksen=""; kural=""; kanit=""; ornek=""; guven="aday"
while [ $# -gt 0 ]; do
  case "$1" in
    --eksen) eksen="${2:-}"; shift 2;;
    --kural) kural="${2:-}"; shift 2;;
    --kanit) kanit="${2:-}"; shift 2;;
    --ornek) ornek="${2:-}"; shift 2;;
    --guven) guven="${2:-}"; shift 2;;
    *) echo "[sultanca] ⛔ bilinmeyen arg: $1" >&2; exit 2;;
  esac
done

case "$eksen" in dil|cikti-tasarim|cikti-format|ifade) :;;
  *) echo "[sultanca] ⛔ --eksen dil|cikti-tasarim|cikti-format|ifade olmalı ('$eksen' değil)" >&2; exit 2;; esac
[ -n "${kural// }" ] || { echo "[sultanca] ⛔ --kural boş olamaz" >&2; exit 2; }
case "$guven" in aday|onayli) :;; *) guven="aday";; esac
[ -f "$STORE" ] || { echo "[sultanca] ⛔ store yok: $STORE" >&2; exit 2; }

# flock (tek-yazar kritik-bölge)
exec 9>>"$STORE.lock"
flock 9 2>/dev/null || true

# id = max(su-seq)+1 (deterministik; renumber-yok)
mx="$(grep -oE '^### su[0-9]{3}' "$STORE" 2>/dev/null | grep -oE '[0-9]{3}' | sort -n | tail -1)"
mx="${mx:-0}"; next=$(( 10#$mx + 1 ))
id="$(printf 'su%03d' "$next")"
today="$(date +%Y-%m-%d)"

# blok üret (append EOF; dosya-sonu newline garantisi)
{
  [ -s "$STORE" ] && [ "$(tail -c1 "$STORE" | wc -l | tr -d ' ')" = "0" ] && printf '\n'
  printf '\n### %s · %s · %s\n' "$id" "$eksen" "$guven"
  printf -- '- **kural:** %s\n' "$kural"
  printf -- '- **kanıt:** %s\n' "${kanit:-(gözlem — Sultan-verbatim eklenecek)}"
  [ -n "${ornek// }" ] && printf -- '- **ornek:** %s\n' "$ornek"
  printf -- '- **updated:** %s\n' "$today"
} >> "$STORE"

echo "[sultanca] ✔ $id eklendi (eksen=$eksen guven=$guven)"
