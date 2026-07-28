#!/usr/bin/env bash
# mucit-elek.test.sh — ELEK-HAFIZASI kapıları (uc-elek-suzme-DESIGN F1+F2).
#
# Neyi kanıtlar:
#   E1-E3  bayrak KAPALIYKEN çıktı BAYT-AYNI (INERT — mevcut davranış hiç değişmedi)
#   E4-E7  bayrak AÇIKKEN kapatıcı/pencereli/preview ayrımı doğru
#   E8-E9  elek penceresi: aynı pencerede bloklar, pencere dışında bırakır
#   D1-D6  durum-yazıcı: iki kapı · kuru-koşu yazmaz · uygular · idempotent · bozuk-girdi fail-closed
#
# İZOLE: gerçek havuz/deftere DOKUNMAZ; her koşu temp-dizinde fixture üretir. Ağ/ssh YOK.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T1="$ROOT/scripts/mucit-t1.sh"
YAZ="$ROOT/scripts/mucit-durum-yaz.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✅ $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  ❌ $1"; echo "     beklenen: $2"; echo "     gerçek  : $3"; }
esit() { [[ "$2" == "$3" ]] && ok "$1" || bad "$1" "$2" "$3"; }

BUGUN="$(date -u +%F)"
ESKI="$(date -u -d '40 days ago' +%F)"
echo '[]' >"$T/kartlar.json"

# ── havuz: 4 uygun bulgu (hepsi ham + kanıtlı) ──────────────────────────────
cat >"$T/havuz.jsonl" <<'JSONL'
{"id":"b1","baslik":"Birinci teknik bulgu","durum":"ham","kanit":"scripts/a.sh:10 kanıt","kaynak":"denetim"}
{"id":"b2","baslik":"İkinci teknik bulgu","durum":"ham","kanit":"scripts/b.sh:20 kanıt","kaynak":"denetim"}
{"id":"b3","baslik":"Üçüncü teknik bulgu","durum":"ham","kanit":"scripts/c.sh:30 kanıt","kaynak":"denetim"}
{"id":"b4","baslik":"Dördüncü teknik bulgu","durum":"ham","kanit":"scripts/d.sh:40 kanıt","kaynak":"denetim"}
JSONL

# ── defter: b1 kapatıcı(zaten-var) · b2 pencereli-BUGÜN · b3 pencereli-ESKİ · b4 preview-BUGÜN ──
cat >"$T/defter.jsonl" <<JSONL
{"turu":"t","tarih":"$BUGUN","bulgu_id":"b1","baslik":"Birinci","verdikt":"elendi","kart":null,"not":"zaten-var: scripts/a.sh:10"}
{"turu":"t","tarih":"$BUGUN","bulgu_id":"b2","baslik":"İkinci","verdikt":"elendi","kart":null,"not":"düşük-değer; bugün bakıldı"}
{"turu":"t","tarih":"$ESKI","bulgu_id":"b3","baslik":"Üçüncü","verdikt":"elendi","kart":null,"not":"düşük-değer; 40 gün önce"}
{"turu":"t","tarih":"$BUGUN","bulgu_id":"b4","baslik":"Dördüncü","verdikt":"preview","kart":null,"not":"kalibrasyon önizlemesi"}
JSONL

t1() { "$T1" suz --havuz "$T/havuz.jsonl" --kartlar "$T/kartlar.json" --defter "$T/defter.jsonl" "$@" 2>"$T/err"; }
idler() { jq -r '[.adaylar[].id] | sort | join(",")'; }

echo "── F2 · elek-hafızası (bayrak KAPALI = INERT) ──"
bash -n "$T1" 2>/dev/null; esit "E1 t1 sözdizimi temiz" "0" "$?"
bash -n "$YAZ" 2>/dev/null; esit "E1b yazıcı sözdizimi temiz" "0" "$?"

KAPALI="$(t1)"; RC=$?
esit "E2 bayraksız koşu RC=0" "0" "$RC"
esit "E3 bayraksız: 4 bulgunun DÖRDÜ de aday (bugünkü davranış — hafıza yok)" "b1,b2,b3,b4" "$(idler <<<"$KAPALI")"

echo "── F2 · elek-hafızası (bayrak AÇIK) ──"
ACIK="$(MUCIT_ELEK_HAFIZA=1 t1)"; RC=$?
esit "E4 bayraklı koşu RC=0" "0" "$RC"
esit "E5 kapatıcı(b1) ELENDİ · pencereli-bugün(b2) ELENDİ · eski(b3)+preview(b4) GEÇTİ" "b3,b4" "$(idler <<<"$ACIK")"
grep -q "elek-hafızası AÇIK" "$T/err" && ok "E6 stderr hafıza satırı basıldı" || bad "E6 stderr satırı" "elek-hafızası AÇIK" "$(cat "$T/err")"
grep -q "kalıcı-kararlı (hafıza): 1" "$T/err" && ok "E7 kapatıcı sayacı=1" || bad "E7 kapatıcı sayacı" "1" "$(grep 'kalıcı' "$T/err" || true)"

echo "── F2 · pencere semantiği ──"
grep -q "bu pencerede kararlı   : 1" "$T/err" && ok "E8 pencere sayacı=1 (yalnız b2)" || bad "E8 pencere sayacı" "1" "$(grep 'pencerede' "$T/err" || true)"
# b3'ün kararı 40 gün önce ve elek=haftalik → bu ISO-haftanın dışında → yeniden girer (E5 kanıtladı)
# aylık elekte b3 hâlâ pencere-dışı (40>30) ama b2 pencere-içi:
AYLIK="$(ELEK=aylik MUCIT_ELEK_HAFIZA=1 t1)"
# b2'nin kararı elek=haftalik etiketli → aylık elekte kural-5 EŞLEŞMEZ → b2 yeniden girer.
# Kapatıcı (b1) ise elekten bağımsız bloklamaya devam eder — asıl kanıt bu.
esit "E9 elek=aylik: kapatıcı(b1) hâlâ dışarıda, pencereliler girer" "b2,b3,b4" "$(idler <<<"$AYLIK")"
ELEK=aylik MUCIT_ELEK_HAFIZA=1 t1 >/dev/null
grep -q "bu pencerede kararlı   : 0" "$T/err" && ok "E10 aylık elekte pencere-kümesi BOŞ (kararlar haftalik etiketli)" \
  || bad "E10 aylık pencere-kümesi" "0" "$(grep 'pencerede' "$T/err" || true)"

echo "── F1 · durum-yazıcı ──"
cp "$T/havuz.jsonl" "$T/havuz-yedek.jsonl"
yaz() { "$YAZ" --havuz "$T/havuz.jsonl" --defter "$T/defter.jsonl" "$@" 2>"$T/yerr"; }

yaz >/dev/null; esit "D1 kuru-koşu RC=0" "0" "$?"
esit "D2 kuru-koşu havuza DOKUNMADI" "" "$(diff "$T/havuz.jsonl" "$T/havuz-yedek.jsonl")"

yaz --uygula >/dev/null; esit "D3 bayrak kapalıyken --uygula REDDEDİLDİ (RC=4)" "4" "$?"
esit "D3b red sonrası havuz hâlâ değişmemiş" "" "$(diff "$T/havuz.jsonl" "$T/havuz-yedek.jsonl")"

MUCIT_DURUM_YAZ=1 yaz --uygula >/dev/null; esit "D4 bayrak+uygula RC=0" "0" "$?"
esit "D4b b1 → elendi-kalici" "elendi-kalici" "$(jq -r 'select(.id=="b1").durum' "$T/havuz.jsonl")"
esit "D4c b2 (pencereli) DOKUNULMADI" "ham" "$(jq -r 'select(.id=="b2").durum' "$T/havuz.jsonl")"
esit "D4d b4 (preview) DOKUNULMADI" "ham" "$(jq -r 'select(.id=="b4").durum' "$T/havuz.jsonl")"
esit "D4e kayıt sayısı korundu" "4" "$(jq -s 'length' "$T/havuz.jsonl")"
esit "D4f öteki alanlar korundu (kanit)" "scripts/a.sh:10 kanıt" "$(jq -r 'select(.id=="b1").kanit' "$T/havuz.jsonl")"

cp "$T/havuz.jsonl" "$T/havuz-sonra.jsonl"
MUCIT_DURUM_YAZ=1 yaz --uygula >/dev/null; esit "D5 ikinci koşu RC=0 (idempotent)" "0" "$?"
esit "D5b ikinci koşu hiçbir şey değiştirmedi" "" "$(diff "$T/havuz.jsonl" "$T/havuz-sonra.jsonl")"

echo '{"id":"bX","baslik":BOZUK' >"$T/bozuk.jsonl"
"$YAZ" --havuz "$T/bozuk.jsonl" --defter "$T/defter.jsonl" >/dev/null 2>&1
esit "D6 bozuk havuz → fail-closed RC=2" "2" "$?"

echo "── aday-arzi geçişi (kart taşıma) ──"
printf '%s\n' '{"id":"b9","baslik":"Aday olmuş bulgu","durum":"ham","kanit":"k","kaynak":"d"}' >"$T/h2.jsonl"
printf '%s\n' "{\"turu\":\"canli\",\"tarih\":\"$BUGUN\",\"bulgu_id\":\"b9\",\"baslik\":\"Aday\",\"verdikt\":\"aday-arzi\",\"kart\":\"k0142\",\"not\":\"sevk\"}" >"$T/d2.jsonl"
MUCIT_DURUM_YAZ=1 "$YAZ" --havuz "$T/h2.jsonl" --defter "$T/d2.jsonl" --uygula >/dev/null 2>&1
esit "D7 aday-arzi → durum=aday-onerildi" "aday-onerildi" "$(jq -r '.durum' "$T/h2.jsonl")"
esit "D7b kart alanı defterden taşındı" "k0142" "$(jq -r '.kart' "$T/h2.jsonl")"

echo "─────────────────────────────"
echo "TOPLAM: $PASS PASS · $FAIL FAIL"
[ "$FAIL" -eq 0 ] || exit 1
