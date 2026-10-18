#!/usr/bin/env bash
# kesim-defteri — "daha önce kesildi mi?" sorusunun YEREL katmanı (Kural 3, katman 1).
# Anahtar: SAP Belge No (tarih/tutar DEĞİL — aynı gün iki paket gelebilir, ölçüldü 20.08.2026).
# append-only: satır SİLİNMEZ; yanlış kayıt "iptal" satırıyla düzeltilir (iz kaybolmasın).
set -euo pipefail
DEFTER="${ARCELIK_KESIM_DEFTERI:-$HOME/.config/arcelik-kesim-defteri.jsonl}"
Y=$'\033[32m'; K=$'\033[31m'; S=$'\033[33m'; N=$'\033[0m'
# 🔴 ALTYAPI HATASI SEMANTİK KODA ÇARPMASIN (ölçüldü 2026-08-23):
#    burada düz `touch` vardı; dizin yoksa/izin yoksa `set -e` devreye girip betik **rc=1**
#    ile ölüyordu — ve rc=1 bu betikte "KESİLMİŞ" demek. Yani okunamayan defter,
#    "bu fatura zaten kesilmiş" cevabına dönüşüyordu. Arıza artık kendi kodunu taşır: 5.
if ! touch "$DEFTER" 2>/dev/null || ! chmod 600 "$DEFTER" 2>/dev/null; then
  echo "${K}✗ ALTYAPI: kesim defteri açılamadı/izin verilemedi: $DEFTER${N}" >&2
  echo "  Bu 'kesilmiş' DEĞİLDİR, 'kesilmemiş' de DEĞİLDİR — ölçülemedi." >&2
  exit 5
fi
if [ ! -r "$DEFTER" ]; then
  echo "${K}✗ ALTYAPI: kesim defteri OKUNAMIYOR: $DEFTER${N}" >&2; exit 5
fi
# 🔴 DÜZ DOSYA OLMALI (ölçüldü 2026-08-23, sınav yakaladı): yolda bir DİZİN varsa `touch` ve
#    `chmod` başarılı olur, `-r` de doğrudur — ama `grep` dizin üstünde boş döner ve betik
#    "defterde YOK → yol açık" (rc=0) der. Yani bozuk kurulum, ÇİFT KESİM yönünde açılırdı.
#    Fail-open'ın en pahalı yönü buydu: çift kesim = çift vergi.
if [ ! -f "$DEFTER" ]; then
  echo "${K}✗ ALTYAPI: kesim defteri DÜZ DOSYA değil (dizin/özel dosya?): $DEFTER${N}" >&2
  echo "  Bu 'kesilmemiş' DEĞİLDİR — ölçülemedi. Çift kesim riski var, DURULDU." >&2
  exit 5
fi

# 🔴 RC SÖZLEŞMESİ (2026-08-23'te AYRIŞTIRILDI — derin kazı bulgusu S3):
#    0 = kesilmemiş (yol açık) · 1 = KESİLMİŞ (DUR) · 3 = İPTAL kaydı (insan kararı)
#    2 = kullanım hatası · başka her şey = ALTYAPI hatası
#    Eskiden "iptal" de 1 döndürüyordu ve çağıran `rc != 0` → "kesilmiş" diyordu; yani
#    ALTYAPI HATASI İŞ KARARINA DÖNÜŞÜYORDU (defter okunamazsa fatura sessizce düşüyordu).
#    Her dal artık kendi kodunu taşır ki çağıran "ölçemedim"i "yok" ile karıştırmasın.
sor() {  # bkz. RC sözleşmesi
  local sap="${1:?kullanım: $0 sor <SAP_BELGE_NO>}"
  local satir; satir="$(grep -F "\"sap\":\"$sap\"" "$DEFTER" | tail -1 || true)"
  if [ -z "$satir" ]; then
    echo "${Y}✓ defterde YOK — bu SAP belge için kesim kaydı bulunamadı${N}"
    echo "  ⚠️  Bu YALNIZ 1. katmandır. e-Logo giden-fatura sorgusu da yeşil olmadan KESME (Kural 3)."
    return 0
  fi
  case "$satir" in
    *'"durum":"iptal"'*) echo "${S}• defterde İPTAL kaydı var — insan kararı gerekir, kendiliğinden kesme${N}"; echo "  $satir"; return 3;;
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

# 🔴 İPTAL KAYDI (eklendi 2026-09-18) — defter GERÇEĞİ SÖYLEYEBİLMELİ.
#    Ölçülmüş boşluk: bir fatura kesilip GÖNDERİLDİKTEN sonra e-Logo tarafında
#    İPTAL edilebiliyor (e-Arşiv'de mümkün; e-Fatura'da değil). Defterde bunu
#    yazacak hiçbir yol yoktu: kayıt sonsuza dek "kesildi" diyordu.
#    İki zarar: (a) defter yalan söylüyor · (b) çift-kesim kapısı iptal edilmiş
#    bir belgeyi geçerli sayıp DÜZELTME faturasını engelliyor.
#    `numara_defteri.iptal_et` bu işe UYGUN DEĞİL — o, gönderilmemiş numara için
#    ve kendi kapısı gönderilmişi zaten reddediyor (doğru davranış).
#    🔴 SATIR SİLİNMEZ, İŞARETLENİR: append-only (C9 kuralı "iptal gizlemez, işaretler").
iptal() {
  local sap="${1:?}" fatura="${2:?}" gerekce="${3:?gerekçe ZORUNLU — sebepsiz iptal kaydı yazılmaz}"
  grep -qF "\"sap\":\"$sap\"" "$DEFTER" || {
    echo "${K}✗ bu SAP defterde YOK — var olmayan kesim iptal edilemez${N}"; return 2; }
  grep -qF "\"fatura_no\":\"$fatura\"" "$DEFTER" || {
    echo "${K}✗ bu fatura no defterde YOK: $fatura${N}"; return 2; }
  if grep -F "\"sap\":\"$sap\"" "$DEFTER" | grep -q '"tur":"iptal"'; then
    echo "${K}✗ zaten iptal kaydı var — ikinci kez yazılmaz${N}"; return 1; fi
  printf '{"tur":"iptal","sap":"%s","fatura_no":"%s","tarih":"%s","gerekce":"%s","kaydeden":"MUHASIP"}\n' \
    "$sap" "$fatura" "$(date +%F)" "$gerekce" >> "$DEFTER"
  echo "${Y}✓ İPTAL kaydı işlendi: $sap → $fatura${N}"
  echo "  ⚠️  Bu SAP artık 'kesilmiş' SAYILMAZ; düzeltme faturası AYRI bir anahtarla kesilir."
}

case "${1:-}" in
  sor)   shift; sor "$@";;
  yaz)   shift; yaz "$@";;
  iptal) shift; iptal "$@";;
  liste) column -t -s'|' < <(sed 's/[{}"]//g;s/,/|/g' "$DEFTER") 2>/dev/null || cat "$DEFTER";;
  *) cat <<H
kesim-defteri — çift kesim kalkanı (Kural 3, yerel katman)
  $0 sor <SAP_BELGE_NO>              RC0=kesilmemiş · RC1=KESİLMİŞ, DUR
  $0 yaz <SAP> <FATURA_NO> [tutar]   kesim sonrası işle (üzerine yazmaz)
  $0 iptal <SAP> <FATURA_NO> <gerekçe>  gönderilmiş faturanın İPTALİNİ işle (append-only)
  $0 liste                           tüm kayıtlar
🔴 Defterin yeşili TEK BAŞINA yetmez — e-Logo sorgusu da yeşil olmalı.
H
   [ -n "${1:-}" ] && exit 2 || exit 0;;
esac
