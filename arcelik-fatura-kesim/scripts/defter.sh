#!/usr/bin/env bash
# kesim-defteri — "daha önce kesildi mi?" sorusunun YEREL katmanı (Kural 3, katman 1).
# Anahtar: SAP Belge No (tarih/tutar DEĞİL — aynı gün iki paket gelebilir, ölçüldü 20.08.2026).
# append-only: satır SİLİNMEZ; yanlış kayıt "iptal" satırıyla düzeltilir (iz kaybolmasın).
set -euo pipefail
DEFTER="${ARCELIK_KESIM_DEFTERI:-$HOME/.config/arcelik-kesim-defteri.jsonl}"
Y=$'\033[32m'; K=$'\033[31m'; S=$'\033[33m'; N=$'\033[0m'
touch "$DEFTER"; chmod 600 "$DEFTER"

sor() {  # RC 0 = kesilmemiş (yol açık) · 1 = KESİLMİŞ (DUR) · 2 = kullanım
  local sap="${1:?kullanım: $0 sor <SAP_BELGE_NO>}"
  local satir; satir="$(grep -F "\"sap\":\"$sap\"" "$DEFTER" | tail -1 || true)"
  if [ -z "$satir" ]; then
    echo "${Y}✓ defterde YOK — bu SAP belge için kesim kaydı bulunamadı${N}"
    echo "  ⚠️  Bu YALNIZ 1. katmandır. e-Logo giden-fatura sorgusu da yeşil olmadan KESME (Kural 3)."
    return 0
  fi
  case "$satir" in
    *'"durum":"iptal"'*) echo "${S}• defterde İPTAL kaydı var — insan kararı gerekir, kendiliğinden kesme${N}"; echo "  $satir"; return 1;;
    *) echo "${K}✗ KESİLMİŞ — DUR. Çift kesim = çift vergi.${N}"; echo "  $satir"; return 1;;
  esac
}

yaz() {
  local sap="${1:?}" fatura="${2:?}" tutar="${3:-}" tarih="${4:-$(date +%F)}"
  if grep -qF "\"sap\":\"$sap\"" "$DEFTER"; then
    echo "${K}✗ bu SAP belge zaten defterde — üzerine yazmıyorum${N}"; grep -F "\"sap\":\"$sap\"" "$DEFTER" | tail -1; return 1
  fi
  printf '{"sap":"%s","fatura_no":"%s","tutar":"%s","tarih":"%s","durum":"kesildi","kaydeden":"MUHASIP"}\n' \
    "$sap" "$fatura" "$tutar" "$tarih" >> "$DEFTER"
  echo "${Y}✓ deftere işlendi: $sap → $fatura${N}"
}

case "${1:-}" in
  sor)   shift; sor "$@";;
  yaz)   shift; yaz "$@";;
  liste) column -t -s'|' < <(sed 's/[{}"]//g;s/,/|/g' "$DEFTER") 2>/dev/null || cat "$DEFTER";;
  *) cat <<H
kesim-defteri — çift kesim kalkanı (Kural 3, yerel katman)
  $0 sor <SAP_BELGE_NO>              RC0=kesilmemiş · RC1=KESİLMİŞ, DUR
  $0 yaz <SAP> <FATURA_NO> [tutar]   kesim sonrası işle (üzerine yazmaz)
  $0 liste                           tüm kayıtlar
🔴 Defterin yeşili TEK BAŞINA yetmez — e-Logo sorgusu da yeşil olmalı.
H
   [ -n "${1:-}" ] && exit 2 || exit 0;;
esac
