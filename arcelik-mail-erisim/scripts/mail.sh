#!/usr/bin/env bash
# arcelik-mail-erisim — Arçelik posta kutusu (fiş paketi) SALT-OKUR CLI.
# Değişmez: mail silmez/göndermez/okundu-işaretlemez · prod'a YAZMAZ (yalnız SELECT) · sır DEĞERİ basmaz.
set -euo pipefail
K="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVF="$HOME/.config/cortex-access.env"
Y=$'\033[32m'; K1=$'\033[31m'; S1=$'\033[33m'; N=$'\033[0m'

kimlik_yukle() { [ -f "$ENVF" ] && { set -a; . "$ENVF" >/dev/null 2>&1; set +a; }; }
py() { export PATH="/config/.local/bin:$PATH"; unset VIRTUAL_ENV || true
       ( cd /config/projects/MMEx/backend && uv run --with 'psycopg[binary]' python "$@" ); }

url_al() {  # prod URL'yi seçer; DEĞER basmaz
  kimlik_yukle
  for k in MMEPANEL__PROD_DATABASE_URL MMEPANEL_PROD_DATABASE_URL PROD_DATABASE_URL; do
    v="${!k:-}"; [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  done
  return 1
}

cmd_doctor() {
  echo "── arcelik-mail-erisim · doctor (3-durum) ──"
  kimlik_yukle   # ← subshell $(url_al) değişkenleri dışarı taşımaz; sahte-yeşil kapanı için burada da yükle
  local u; if ! u="$(url_al)"; then
    echo "${K1}✗ KIRMIZI · prod DB kimliği YOK${N}"
    echo "  aranan ad(lar): MMEPANEL__PROD_DATABASE_URL · PROD_DATABASE_URL"
    echo "  çözüm: kasaya konmalı → vault-cek get MMEPANEL__PROD_DATABASE_URL"
    # sahte-yeşil kapanı: yerel URL prod sanılmasın
    if [ -n "${MMEPANEL__DATABASE_URL:-}" ]; then
      case "${MMEPANEL__DATABASE_URL}" in
        sqlite*) echo "  ${S1}uyarı: MMEPANEL__DATABASE_URL var ama sqlite (YEREL) — prod DEĞİL, kullanılmadı.${N}";;
      esac
    fi
    return 3
  fi
  case "$u" in sqlite*) echo "${K1}✗ KIRMIZI · bulunan URL sqlite (yerel) — prod değil. Sahte-yeşil engellendi.${N}"; return 3;; esac
  MAILDB="$u" py "$K/probe.py" doctor
}

cmd_listele() {
  local gun=30; [ "${1:-}" = "--gun" ] && { gun="${2:?--gun için sayı ver}"; }
  local u; u="$(url_al)" || { echo "${K1}✗ kimlik yok — önce: $0 doctor${N}"; return 3; }
  MAILDB="$u" py "$K/probe.py" listele "$gun"
}

cmd_indir() {
  local mid="${1:?kullanım: $0 fis-indir <mail_id> [dizin]}"
  local dz="${2:-./fis-paketleri}"
  local u; u="$(url_al)" || { echo "${K1}✗ kimlik yok — önce: $0 doctor${N}"; return 3; }
  MAILDB="$u" py "$K/probe.py" indir "$mid" "$dz"
}

cmd_baglan() {
  kimlik_yukle
  export PATH="/config/.local/bin:$PATH"; unset VIRTUAL_ENV || true
  python3 "$K/devicecode.py" "$@"
}

case "${1:-}" in
  baglan)      shift; cmd_baglan "$@";;
  doctor)      shift; cmd_doctor "$@";;
  fis-listele) shift; cmd_listele "$@";;
  fis-indir)   shift; cmd_indir "$@";;
  *) cat <<H
arcelik-mail-erisim — Arçelik posta kutusu (fiş paketi) · SALT-OKUR
  $0 baglan [--kasa-client]        Device Code Flow — İNSAN onayıyla bir kez bağlan (parola YOK)
  $0 doctor                        3-durum sağlık (kimlik + bağlantı + hat canlılığı)
  $0 fis-listele [--gun N]         son N günün fiş paketi mailleri (varsayılan 30)
  $0 fis-indir <mail_id> [dizin]   o mailin PDF eklerini diske yazar
Değişmez: mail silinmez/gönderilmez/okundu-işaretlenmez · prod'a YAZILMAZ · token değeri basılmaz.
Arıza çıkarsa: SKILL.md → "Arıza sözlüğü".
H
     [ -n "${1:-}" ] && exit 2 || exit 0;;
esac
