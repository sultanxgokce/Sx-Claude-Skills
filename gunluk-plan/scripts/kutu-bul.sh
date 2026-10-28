#!/usr/bin/env bash
# kutu-bul.sh — /gunluk-plan'ın "bu hangi kutu?" sorusunun TEK cevap yeri (1.11.0; menzil hatası: kutu adı listenin en sık sütunundan türüyordu).
#   Ders (MENZİLCİ, 27 Eki): görev listesi kutuya özel DEĞİL — herkes tüm kutuların işini görür; "en sık kutu" hep en kalabalık kutuyu (code) verir ve
#   maddeler YANLIŞ kutunun defterine yazılırdı. Kutu adını ölçen tek şey o koltuğa ATANMIŞ işlerin kutusudur.
#   kutu-bul.sh [--kim AJAN] [--liste <dosya>]   → stdout: kutu adı · rc 0 bulundu · 3 ölçülemedi (uydurma kutu YOK; --kutu ver)
# Sıra: GUNLUK_PLAN_KUTU > listede atanan = KIM olan işlerin en sık kutusu. Eşit sayıda iki kutu çıkarsa tahmin edilmez (rc 3).
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CIPA="${GUNLUK_PLAN_CIPA_SH:-$KOK/cipa.sh}"
GOREV="$(bash "$KOK/gorev-yolu.sh" 2>/dev/null)" || GOREV="${GUNLUK_PLAN_GOREV_SH:-/gorev.sh-yok}"
KIM=""; LISTE_DOSYA=""; COZULMUS=0
while [ $# -gt 0 ]; do case "$1" in --kim) KIM="${2:-}"; shift 2 ;; --liste) LISTE_DOSYA="${2:-}"; shift 2 ;; --cozulmus) COZULMUS=1; shift ;; *) echo "kullanım: kutu-bul.sh [--kim AJAN] [--liste dosya]" >&2; exit 2 ;; esac; done
if [ -n "${GUNLUK_PLAN_KUTU:-}" ]; then printf '%s\n' "$GUNLUK_PLAN_KUTU"; exit 0; fi
[ -n "$KIM" ] || KIM="${GUNLUK_PLAN_AJAN:-${AGENT_NAME:-}}"
[ -n "$KIM" ] || KIM="$(bash "$CIPA" ajan 2>/dev/null | python3 -c 'import sys; print(sys.stdin.read().strip())')"
[ -n "$KIM" ] || { echo "ÖLÇÜLEMEDİ: ajan kimliği çıkmadı (--kim ver)" >&2; exit 3; }
[ -z "$KIM" ] || [ "$COZULMUS" -eq 1 ] || KIM="$(bash "$KOK/kimlik-coz.sh" "$KIM")" || { echo "ÖLÇÜLEMEDİ: koltuk adı defter adına çevrilemedi (koltuk-esleme.tsv)" >&2; exit 3; }   # koltuk adı → defter adı (tablo)
if [ -n "$LISTE_DOSYA" ]; then LISTE="$(cat "$LISTE_DOSYA" 2>/dev/null)"; else LISTE="$(bash "$GOREV" liste 2>/dev/null)"; fi
[ -n "$LISTE" ] || { echo "ÖLÇÜLEMEDİ: görev listesi okunamadı" >&2; exit 3; }
printf '%s\n' "$LISTE" | python3 -c '
import sys,unicodedata,collections
def n(t): return unicodedata.normalize("NFKC",t).replace("İ","i").replace("I","i").replace("ı","i").lower().replace("â","a").replace("î","i").replace("û","u").replace("ü","u").replace("ö","o").replace("ç","c").replace("ş","s").replace("ğ","g")   # kimlik karşılaştırması: İ/I/ı/i ve şapkalar aynı sayılır (çıpa kimliği katlanmış gelir)
kim=n(sys.argv[1]); say=collections.Counter()
for s in sys.stdin:
    p=s.rstrip("\n").split(None,6)
    if len(p)<6 or not p[0].startswith("gorev_"): continue   # liste satırı: id kutu durum aciliyet etiket atanan BAŞLIK
    if n(p[5])==kim: say[p[1]]+=1
if not say: sys.exit(3)
(a,x),*r=say.most_common()
if r and r[0][1]==x: sys.exit(3)
print(a)' "$KIM"; rc=$?
[ $rc -eq 0 ] || echo "ÖLÇÜLEMEDİ: '$KIM' koltuğuna atanmış iş yok ya da kutular eşit — kutu tahmin edilmez, --kutu ver" >&2
exit $rc
