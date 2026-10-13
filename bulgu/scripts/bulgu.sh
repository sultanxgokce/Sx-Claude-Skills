#!/usr/bin/env bash
# bulgu.sh — filonun tek bulgu komutu (Sultan /goal K2). Kutunun kendi Bulgu Defteri'ne, defterin KENDİ
# kilitli yazıcısıyla (defter-yaz.py) yazar. Yeni yazıcı icat etmez; yalnız kapıdır.
# rc: 0 tamam · 1 yazıcı hatası · 2 kullanım · 3 bu kutuda defter kurulu değil (hiçbir şey yazılmadı)
set -uo pipefail
KOK="${BULGU_KOK:-/config/.ic-sayfa}"
YAZ="$KOK/defter-yaz.py"
JSON="$KOK/bulgu-defteri/bulgular.json"
ALANLAR="id no sayi baslik hal surum acan kaynak acilis tur notlar gecisler"
_kur_yok() { echo "⛔ bu kutuda Bulgu Defteri kurulu değil ($YAZ yok) — hiçbir şey yazılmadı. SERDAR'a yaz: kur.sh --kutu <kutu>" >&2; exit 3; }
k="${1:-}"; shift || true
case "$k" in
  yaz)
    [ -f "$YAZ" ] || _kur_yok
    baslik="${1:-}"; shift || true
    [ -n "$baslik" ] || { echo "kullanım: bulgu.sh yaz \"<başlık>\" --kim <AJAN> [--not \"…\"]" >&2; exit 2; }
    kim=""; notu=""
    while [ $# -gt 0 ]; do case "$1" in
      --kim) kim="${2:-}"; shift 2 ;; --not) notu="${2:-}"; shift 2 ;;
      *) echo "bilinmeyen: $1" >&2; exit 2 ;; esac; done
    [ -n "$kim" ] || { echo "--kim zorunlu (kaydı kim açıyor?)" >&2; exit 2; }
    if [ -n "$notu" ]; then python3 "$YAZ" yeni --baslik "$baslik" --kim "$kim" --not "$notu" --kok "$KOK"
    else python3 "$YAZ" yeni --baslik "$baslik" --kim "$kim" --kok "$KOK"; fi ;;
  liste)
    [ -f "$YAZ" ] || _kur_yok; python3 "$YAZ" listele --kok "$KOK" ;;
  hal)
    # Hâl geçişi (13 Eki, MUAVİN): acik → uygulandi → canli; 'onaylandi' İNSANINDIR (A06) — bu kapı onu reddeder.
    [ -f "$YAZ" ] || _kur_yok
    no="${1:-}"; yeni="${2:-}"; shift 2 2>/dev/null || { echo "kullanım: bulgu.sh hal <S-N> <acik|uygulandi|canli> --kim <AJAN> --gerekce \"…\"" >&2; exit 2; }
    case "$yeni" in acik|uygulandi|canli) ;; onaylandi) echo "⛔ 'onaylandi' yalnız insanın tikidir (A06) — ajan yazamaz" >&2; exit 2 ;;
      *) echo "bilinmeyen hâl: $yeni (acik|uygulandi|canli)" >&2; exit 2 ;; esac
    [[ "$no" =~ ^S-[0-9]+$ ]] || { echo "kayıt numarası S-N biçiminde olmalı: $no" >&2; exit 2; }
    kim=""; gerekce=""
    while [ $# -gt 0 ]; do case "$1" in
      --kim) kim="${2:-}"; shift 2 ;; --gerekce) gerekce="${2:-}"; shift 2 ;;
      *) echo "bilinmeyen: $1" >&2; exit 2 ;; esac; done
    [ -n "$kim" ] || { echo "--kim zorunlu (geçişi kim yapıyor?)" >&2; exit 2; }
    [ -n "$gerekce" ] || { echo "--gerekce zorunlu (niçin bu hâle geçti? kanıt/PR/commit)" >&2; exit 2; }
    python3 "$YAZ" hal "$no" --hal "$yeni" --gerekce "$gerekce" --kim "$kim" --kok "$KOK" ;;
  sema)
    [ -f "${1:-$JSON}" ] || _kur_yok
    python3 - "${1:-$JSON}" "$ALANLAR" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8")); alan = sys.argv[2].split()
b = d.get("bulgular", []) if isinstance(d, dict) else []
ok = [x for x in b if all(k in x for k in alan) and isinstance(x.get("sayi"), int)]
print(json.dumps({"toplam": len(b), "sema_gecen": len(ok), "gecmeyen": len(b) - len(ok),
                  "son_gecen": [x["no"] + " " + str(x.get("acan")) for x in ok[-3:]]}, ensure_ascii=False))
PY
    ;;
  *) sed -n '2,4p' "$0"; echo "komutlar: yaz · liste · hal · sema"; exit 2 ;;
esac
