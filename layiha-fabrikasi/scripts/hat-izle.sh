#!/usr/bin/env bash
# hat-izle.sh — otonom fikir-hattının CAM ARKASI (ADR-025 icra-5, EK-A §A4).
#
# Sultan'ın şartı birebir: *"görmezsem olmuş sayamam."*
#
# GÖRÜNÜRLÜK İKİ PARÇADIR, BİRİ YETMEZ:
#   · PANO (bu betik) — bugün ne oldu, adım adım. "Bakınca görürüm."
#   · BEKÇİ (ayrı, sessiz-ölüm) — beklenen tur OLMADIYSA haber verir. "Bakmayı unutursam."
#   İlke: var olan işi pano gösterir, OLMAYAN işi bekçi söyler. Yokluk kendini göstermez.
#
# NİÇİN TERMİNAL, NİÇİN PANEL DEĞİL (EK-A §A4): terminal doğrudan defterlerden okur → yalan
# söyleyemez. Panel build/deploy ister ve bozulduğunda YANLIŞ bilgi gösterir — sessiz-ölümün
# en sinsi türü. Panel ikinci adımda komuta ekranına kart olarak eklenir; kanonik kaynak burasıdır.
#
# DÖRT İŞARET (öğrenilecek tek şey):
#   🟢 akıyor   · 🟡 sende (senin bir şey yapman bekleniyor)
#   🔴 sessiz   · ⚪ kapalı (bilinçli — hak yok ya da hat kapalı)
#
# İPİN UCU = TUR NUMARASI. "t20260728-1 nerede?" sorusunun tek cevabı olsun diye tur numarası
# tarama → süzme → arz zincirinin tamamında taşınır.
#
# KULLANIM:
#   hat-izle.sh              # bugünkü tablo
#   hat-izle.sh --tur <tur>  # tek turu uçtan uca izle
#   hat-izle.sh --ozet       # tek satır (ntfy/gün-sonu için)
#
# SALT-OKUR: hiçbir dosyaya yazmaz, hiçbir şey tetiklemez.

set -euo pipefail

BURASI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$BURASI/../../layiha/scripts/hat-yolu.lib.sh"

simdi_iso() { printf '%s' "${HAT_SIMDI:-$(date +%Y-%m-%dT%H:%M)}"; }
bugun()     { simdi_iso | cut -dT -f1; }

DURUM="$(hat_yolu hat-durum)"     || exit 2
GUNLUK="$(hat_yolu hat-gunluk)"   || exit 2
BULGU="$(hat_yolu bulgu-havuzu)"  || exit 2
MUCIT="$(hat_yolu mucit-defteri)" || exit 2
ACIK="$(hat_yolu handoff-dir)/hat-acik"

# durum → işaret. Bilinmeyen durum ⚪ değil 🔴 sayılır: tanımadığımız hâli "sorun yok" saymak
# tam olarak sessiz-ölümün nasıl oluştuğudur.
isaret() {
  case "$1" in
    bitti-dolu) printf '🟢' ;;
    bitti-bos)  printf '🟢' ;;
    kosuyor)    printf '🟢' ;;
    bekliyor)   printf '⚪' ;;
    basarisiz)  printf '🟡' ;;
    pes-etti)   printf '🔴' ;;
    *)          printf '🔴' ;;
  esac
}

aciklama() {
  case "$1" in
    bitti-dolu) printf 'tamamlandı' ;;
    bitti-bos)  printf 'tamamlandı — bulgu yok (bu da bir sonuçtur)' ;;
    kosuyor)    printf 'şu an çalışıyor' ;;
    bekliyor)   printf 'sırasını bekliyor' ;;
    basarisiz)  printf 'takıldı, tekrar denenecek' ;;
    pes-etti)   printf 'ÜÇ denemede de olmadı — bakman lazım' ;;
    *)          printf 'bilinmeyen durum: %s' "$1" ;;
  esac
}

durum_json() {
  local g; g="$(bugun)"
  python3 - "$DURUM" "$g" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    d = None
if not isinstance(d, dict) or d.get("gun") != sys.argv[2]:
    d = {"gun": sys.argv[2], "tur": "", "kasif": {"durum": "bekliyor"}, "mucit": {"durum": "bekliyor"}}
print(json.dumps(d, ensure_ascii=False))
PY
}

sayac() {  # <dosya> <alan> <deger> — JSONL içinde kaç kayıt eşleşiyor
  [ -f "$1" ] || { printf '0'; return 0; }
  python3 - "$1" "$2" "$3" <<'PY'
import json, sys
n = 0
for satir in open(sys.argv[1], encoding="utf-8", errors="replace"):
    satir = satir.strip()
    if not satir:
        continue
    try:
        if str(json.loads(satir).get(sys.argv[2], "")).lower() == sys.argv[3].lower():
            n += 1
    except Exception:
        pass
print(n)
PY
}

tur_izi() {  # <tur> — turu taşıyan kayıtları defterlerden topla
  python3 - "$1" "$BULGU" "$MUCIT" <<'PY'
import json, os, sys
tur = sys.argv[1]
for etiket, yol in (("tarandı (bulgu)", sys.argv[2]), ("süzüldü (MUCİT)", sys.argv[3])):
    if not os.path.isfile(yol):
        print("  %-18s defter yok" % etiket); continue
    n = 0
    for satir in open(yol, encoding="utf-8", errors="replace"):
        satir = satir.strip()
        if not satir:
            continue
        try:
            if json.loads(satir).get("tur") == tur:
                n += 1
        except Exception:
            pass
    print("  %-18s %d kayıt" % (etiket, n))
PY
}

JSON="$(durum_json)"
TUR="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("tur") or "")' "$JSON")"

case "${1:-}" in
  --ozet)
    kd="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["kasif"]["durum"])' "$JSON")"
    md="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["mucit"]["durum"])' "$JSON")"
    printf '%s hat: tarama %s · süzme %s · bekleyen malzeme %s\n' \
      "$(bugun)" "$(isaret "$kd")" "$(isaret "$md")" "$(sayac "$BULGU" durum ham)"
    exit 0 ;;
  --tur)
    [ -n "${2:-}" ] || { printf 'kullanım: %s --tur <t20260728-1>\n' "${0##*/}" >&2; exit 2; }
    printf '\n  TUR %s — uçtan uca\n\n' "$2"; tur_izi "$2"; printf '\n'; exit 0 ;;
  "") ;;
  *) printf 'kullanım: %s [--tur <tur>|--ozet]\n' "${0##*/}" >&2; exit 2 ;;
esac

printf '\n  ╭─ FİKİR HATTI · %s · %s\n' "$(bugun)" "$(hostname 2>/dev/null || printf 'oda')"
if [ -f "$ACIK" ]; then printf '  │  hat AÇIK\n'; else printf '  │  hat KAPALI (INERT — kendiliğinden hiçbir şey koşmaz)\n'; fi
[ -n "$TUR" ] && printf '  │  tur: %s\n' "$TUR"
printf '  ╰─\n\n'

for adim in kasif mucit; do
  d="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])[sys.argv[2]].get("durum",""))' "$JSON" "$adim")"
  dn="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])[sys.argv[2]].get("deneme",0))' "$JSON" "$adim")"
  ad="$([ "$adim" = kasif ] && printf 'tarama (KAŞİF)' || printf 'süzme  (MUCİT)')"
  printf '  %s  %-16s %s' "$(isaret "$d")" "$ad" "$(aciklama "$d")"
  [ "${dn:-0}" -gt 0 ] && printf ' [deneme %s]' "$dn"
  printf '\n'
done

printf '\n  bekleyen malzeme (süzülmemiş): %s\n' "$(sayac "$BULGU" durum ham)"
if [ -f "$GUNLUK" ]; then
  printf '  bugünkü dürtme sayısı: %s\n' "$(grep -c "\"ts\":\"$(bugun)" "$GUNLUK" 2>/dev/null || printf 0)"
fi
printf '\n  ipin ucu: %s --tur <tur>   ·   hangi defter: %s\n\n' "${0##*/}" "$(hat_tani 2>/dev/null || printf '?')"
