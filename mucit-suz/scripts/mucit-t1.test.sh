#!/usr/bin/env bash
# mucit-t1.test.sh — PROFİL parametrizasyonu (L24) + geriye-uyum kapıları.
# İZOLE: gerçek havuz/deftere DOKUNMAZ; her koşu temp-dizinde fixture üretir.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUT="$ROOT/scripts/mucit-t1.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); echo "  ✅ $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  ❌ $1"; echo "     beklenen: $2"; echo "     gerçek  : $3"; }
esit() { [[ "$2" == "$3" ]] && ok "$1" || bad "$1" "$2" "$3"; }

# ── fixture: 2 uygun bulgu (kanıtlı, ham), kart-kaynağı boş dosya ──
cat >"$T/havuz.jsonl" <<'JSONL'
{"id":"b1","baslik":"Bir numaralı teknik bulgu","durum":"ham","kanit":"scripts/x.sh:10 — somut kanıt satırı","kaynak":"denetim"}
{"id":"b2","baslik":"İki numaralı teknik bulgu","durum":"ham","kanit":"scripts/y.sh:20 — somut kanıt satırı","kaynak":"denetim"}
JSONL
echo '[]' >"$T/kartlar.json"

BUGUN="$(date -u +%FT%H:%M:%SZ)"
# divan defteri: BU HAFTA 3 gerçek-aday → haftalık tavan (3) DOLU
: >"$T/divan.jsonl"
for i in 1 2 3; do echo "{\"verdikt\":\"aday-arzi\",\"tarih\":\"$BUGUN\"}" >>"$T/divan.jsonl"; done
# layiha defteri: BUGÜN 3 gerçek-aday → günlük tavan (10) DOLU DEĞİL
: >"$T/layiha.jsonl"
for i in 1 2 3; do echo "{\"verdikt\":\"aday-arzi\",\"tarih\":\"$BUGUN\"}" >>"$T/layiha.jsonl"; done

sut() { "$SUT" suz --havuz "$T/havuz.jsonl" --kartlar "$T/kartlar.json" "$@" 2>"$T/err"; }

echo "── mucit-t1 PROFİL kapıları ──"

# G1 · sözdizimi
bash -n "$SUT" 2>/dev/null; esit "G1 bash -n temiz" "0" "$?"

# G2 · GERİYE-UYUM: bayraksız çağrı = divan (hafta/3) — 3 dolu → RC=3 kilit
sut --defter "$T/divan.jsonl" >/dev/null; esit "G2 bayraksız (divan) haftalık tavan dolu → RC=3" "3" "$?"

# G3 · aynı durum --profil divan ile birebir aynı
sut --profil divan --defter "$T/divan.jsonl" >/dev/null; esit "G3 --profil divan aynı sonuç → RC=3" "3" "$?"

# G4 · layiha profili: aynı 3 kayıt günlük 10 tavanına takılmaz → RC=0
OUT="$(sut --profil layiha --defter "$T/layiha.jsonl")"; RC=$?
esit "G4 --profil layiha (gün/10) 3 kayıtla geçer → RC=0" "0" "$RC"
esit "G4b kalan-kota 7" "7" "$(jq -r '.kalan' <<<"$OUT")"
esit "G4c tavan 10" "10" "$(jq -r '.tavan' <<<"$OUT")"
esit "G4d profil alanı" "layiha" "$(jq -r '.profil' <<<"$OUT")"
esit "G4e periyot alanı" "gun" "$(jq -r '.periyot' <<<"$OUT")"

# G5 · KRİTİK: layiha profili DİVAN defterini KULLANMAZ (DİVAN-ANAYASA §8 kotası tüketilmez).
#      Sahte kök kurulur: divan-defteri TAVANA KADAR doldurulur (haftalık 3). Aynı kökte
#      layiha profili --defter VERİLMEDEN koşar; divan defterini okusaydı RC=3 kilidine düşerdi.
mkdir -p "$T/kok/_agents/handoff"
for i in 1 2 3; do
  echo "{\"verdikt\":\"aday-arzi\",\"tarih\":\"$BUGUN\"}" >>"$T/kok/_agents/handoff/mucit-defteri.jsonl"
done
sahte() { HAT_ROOT="$T/kok" "$SUT" suz --havuz "$T/havuz.jsonl" --kartlar "$T/kartlar.json" "$@" 2>/dev/null; }

sahte --profil divan >/dev/null
esit "G5a sahte-kökte divan defteri DOLU → RC=3 (fixture doğru kuruldu)" "3" "$?"

OUT2="$(sahte --profil layiha)"; RC2=$?
esit "G5b aynı kökte layiha profili kilide DÜŞMEZ → RC=0 (ayrı defter kanıtı)" "0" "$RC2"
esit "G5c layiha sayacı sıfırdan başlar (kalan=10)" "10" "$(jq -r '.kalan' <<<"$OUT2")"
esit "G5d divan defteri layiha koşusundan sonra DEĞİŞMEDİ (3 satır)" "3" "$(wc -l <"$T/kok/_agents/handoff/mucit-defteri.jsonl")"

# G6 · divan çıktısı ISO-hafta formatında (geriye-uyum: 'hafta' anahtarı korunuyor)
OUT3="$(sut --profil divan --defter "$T/bos.jsonl")";
esit "G6 divan periyot=hafta" "hafta" "$(jq -r '.periyot' <<<"$OUT3")"
esit "G6b 'hafta' anahtarı hâlâ var (T2 kontratı kırılmadı)" "0" "$(jq -e 'has("hafta")' <<<"$OUT3" >/dev/null; echo $?)"
esit "G6c hafta değeri ISO-hafta biçimi" "0" "$(jq -r '.hafta' <<<"$OUT3" | grep -qE '^[0-9]{4}-W[0-9]{2}$'; echo $?)"

# G7 · gün biçimi
OUT4="$(sut --profil layiha --defter "$T/bos2.jsonl")"
esit "G7 layiha dönem değeri YYYY-MM-DD" "0" "$(jq -r '.donem' <<<"$OUT4" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; echo $?)"

# G8 · bilinmeyen profil reddedilir
sut --profil yok >/dev/null 2>&1; esit "G8 bilinmeyen profil → RC=2" "2" "$?"

# G9 · bilinmeyen periyot reddedilir
sut --periyot ay --defter "$T/bos3.jsonl" >/dev/null 2>&1; esit "G9 bilinmeyen periyot → RC=2" "2" "$?"

# G10 · bayrak profili EZER (sıra bağımsız): layiha + --tavan 1, bugün 3 üretilmiş → kilit
sut --profil layiha --defter "$T/layiha.jsonl" --tavan 1 >/dev/null
esit "G10 --tavan profili ezer → RC=3" "3" "$?"

# G11 · ters sıra da çalışır (--tavan önce, --profil sonra)
sut --tavan 1 --profil layiha --defter "$T/layiha.jsonl" >/dev/null
esit "G11 ters bayrak-sırası aynı sonuç → RC=3" "3" "$?"

# G12 · env ile profil
MUCIT_PROFIL=layiha sut --defter "$T/layiha.jsonl" >/dev/null
esit "G12 MUCIT_PROFIL env → RC=0" "0" "$?"

# ── KİLL-SWITCH KAPSAM-DİSİPLİNİ (L24 FAZ-D2) ──
# Bayrak "layiha-fabrikasını kapat" demektir; DİVAN'ı (ayrı anayasa, §8) susturamaz.
: >"$T/kapali.flag"
bayrakli() { LAYIHA_FABRIKA_BAYRAK="$T/kapali.flag" "$SUT" suz --havuz "$T/havuz.jsonl" --kartlar "$T/kartlar.json" "$@" 2>"$T/err2"; }

OUT5="$(bayrakli --profil layiha --defter "$T/bos4.jsonl")"; RC5=$?
esit "G13 bayrak VARKEN layiha üretimi ATLANIR (exit 0, çıktı yok)" "0" "$RC5"
esit "G13b atlama sessiz değil — stderr 'KAPALI' der" "0" "$(grep -q 'KAPALI' "$T/err2"; echo $?)"
esit "G13c layiha koşusu aday BASMAZ" "" "$OUT5"

OUT6="$(bayrakli --profil divan --defter "$T/bos5.jsonl")"; RC6=$?
esit "G14 bayrak VARKEN divan (DİVAN hattı) ÇALIŞMAYA DEVAM eder" "0" "$RC6"
esit "G14b divan çıktısı gerçek JSON (susturulmadı)" "divan" "$(jq -r '.profil' <<<"$OUT6")"

# bayraksız layiha yeniden çalışır (idempotent aç/kapa)
OUT7="$(LAYIHA_FABRIKA_BAYRAK="$T/yok.flag" "$SUT" suz --havuz "$T/havuz.jsonl" --kartlar "$T/kartlar.json" --profil layiha --defter "$T/bos6.jsonl" 2>/dev/null)"
esit "G15 bayrak KALKINCA layiha üretimi geri gelir" "layiha" "$(jq -r '.profil' <<<"$OUT7")"

echo
echo "pass=$PASS fail=$FAIL"
[[ $FAIL -eq 0 ]]
