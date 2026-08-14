#!/usr/bin/env bash
# vault-cek — SEAM DİSPATCHER (backbone-agnostik) · L54 cutover 2026-08-07.
# Kontrat DEĞİŞMEDİ; yalnız hangi adaptörün koşacağı artık VERİDEN seçilir → 91+ tüketici
# yeniden-KABLOLANMAZ (swappable-seam deseni; Railway→Infisical→OpenBao 3. geçiş):
#   vault-cek doctor            backbone erişimi (3-durum; exit-4 korunur)
#   vault-cek resolve           hedef/kapsam göster (SIR DEĞİL)
#   vault-cek get <KEY>         <KEY>'i çek → cortex-access.env (değer BASILMAZ)
#   vault-cek list [<kaynak>]   <kaynak>'taki KEY ADLARINI göster (değer DEĞİL; default shared)
#   vault-cek put <KEY> …       <KEY>'i kasaya YATIR (değer stdin/ortam; argv YASAK) — YALNIZ openbao
#   vault-cek backend           HANGİ backbone aktif + nereden geldi (teşhis; SIR DEĞİL)
#
# BACKBONE SEÇİMİ (öncelik sırası — üstteki alttakini ezer):
#   1. $VAULT_BACKEND ortam-değişkeni     (tek-koşumluk; ör. VAULT_BACKEND=infisical vault-cek get X)
#   2. ~/.config/vault-backend dosyası    (KUTU-BAŞINA sabitleme; tek kelime: openbao|infisical|railway)
#   3. yerleşik varsayılan = openbao      (2026-08-07 cutover; öncesi infisical'dı)
# NİÇİN DOSYA: bu skill-dizini 13 konteynerde TEK ve ORTAK mount'tur (aynı inode) — dosyayı
#   değiştirmek filoyu tek anda çevirir. `~/.config` ise KUTU-BAŞINA ayrıdır; cutover'ın
#   tenant-tenant yürüyebilmesi ve tek-kelimeyle geri alınabilmesi bu ayrımdan gelir.
# GERİ DÖNÜŞ: `echo infisical > ~/.config/vault-backend` → o kutu anında eski kasaya döner.
#   Infisical'daki sırlar SİLİNMEDİ (30-gün salt-okur fallback penceresi).
# SESSİZ FALLBACK YOK: openbao düşerse hata döner, gizlice Infisical'a kaçmaz (yanlış-yeşil kalkanı).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIN_FILE="${VAULT_BACKEND_FILE:-$HOME/.config/vault-backend}"
DEFAULT_BACKEND="openbao"

SRC="varsayilan"
BACKEND="${VAULT_BACKEND:-}"
if [ -n "$BACKEND" ]; then
  SRC="env:VAULT_BACKEND"
elif [ -f "$PIN_FILE" ]; then
  BACKEND="$(tr -d '[:space:]' < "$PIN_FILE" | tr '[:upper:]' '[:lower:]')"
  [ -n "$BACKEND" ] && SRC="dosya:$PIN_FILE"
fi
BACKEND="${BACKEND:-$DEFAULT_BACKEND}"

case "$BACKEND" in
  openbao)   ADAPTER="$DIR/vault-cek-openbao.sh" ;;
  infisical) ADAPTER="$DIR/vault-cek-infisical.sh" ;;
  railway)   ADAPTER="$DIR/vault-cek-railway.sh" ;;
  *) printf '\033[31m✗ bilinmeyen backbone: %s (geçerli: openbao|infisical|railway · kaynak=%s)\033[0m\n' \
       "$BACKEND" "$SRC" >&2; exit 1 ;;
esac

if [ ! -f "$ADAPTER" ]; then
  printf '\033[31m✗ adaptör dosyası yok: %s (backbone=%s · kaynak=%s)\033[0m\n' "$ADAPTER" "$BACKEND" "$SRC" >&2
  exit 1
fi

if [ "${1:-}" = "backend" ]; then
  printf '\033[32m✓ aktif backbone: %s\033[0m\n' "$BACKEND"
  printf '  kaynak   : %s\n' "$SRC"
  printf '  adaptör  : %s\n' "$ADAPTER"
  printf '  varsayılan: %s · kutu-sabitleme dosyası: %s (%s)\n' \
    "$DEFAULT_BACKEND" "$PIN_FILE" "$([ -f "$PIN_FILE" ] && echo VAR || echo yok)"
  exit 0
fi

exec bash "$ADAPTER" "$@"
