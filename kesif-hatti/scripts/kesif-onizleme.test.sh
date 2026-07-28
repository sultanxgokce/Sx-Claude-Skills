#!/usr/bin/env bash
# kesif-onizleme.test.sh — golden testler (hermetik: ağ/ssh/tmux YOK, yalnız fixture dosyalar)
# Koş: bash kesif-hatti/scripts/kesif-onizleme.test.sh ; echo exit=$?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$HERE/kesif-onizleme.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); echo "PASS  $1"; }
no(){ FAIL=$((FAIL+1)); echo "FAIL  $1"; echo "      $2"; }
esit(){ [ "$2" = "$3" ] && ok "$1" || no "$1" "beklenen=[$2] gelen=[$3]"; }
kos(){ KESIF_REPO_ROOT="$1" bash "$SUT" --porcelain 2>"$TMP/err"; }
alan(){ printf '%s\n' "$1" | grep "^$2	" | head -1 | cut -f"$3"; }

R="$TMP/repo"; mkdir -p "$R/_agents/handoff" "$R/_agents/kasif" "$R/_agents/mucit"

# ── fixture: 4 bulgu — 2 ham(süzülmemiş) · 1 ham AMA defterde kaydı var · 1 elendi ──
cat > "$R/_agents/handoff/bulgu-havuzu.jsonl" <<'JSONL'
{"id":"b0001","tip":"firsat","baslik":"ilk firsat","durum":"ham"}
{"id":"b0002","tip":"bulgu","baslik":"ikinci bulgu","durum":"ham"}
{"id":"b0003","tip":"bulgu","baslik":"defterde karari var","durum":"ham"}
{"id":"b0004","tip":"bulgu","baslik":"zaten elenmis","durum":"elendi"}
JSONL
cat > "$R/_agents/mucit/mucit-defteri.jsonl" <<'JSONL'
{"tarih":"2026-07-28","bulgu_id":"b0003","baslik":"defterde karari var","verdikt":"elendi","not":"zaten-var"}
{"tarih":"2026-07-28","bulgu_id":"b0004","baslik":"zaten elenmis","verdikt":"elendi","not":"zayif"}
JSONL
printf '%s\n' '{"id":"a1","baslik":"aday bir","pct":80}' > "$R/_agents/handoff/layiha-aday-havuzu.jsonl"
printf '%s\n' '2026-07-28T16:00:00 | sure=100s | bulgu=4 yeni=4 | tamam' > "$R/_agents/kasif/tur.log"

OUT="$(kos "$R")"; rc=$?
esit "T1 temiz defterde exit=0" "0" "$rc"
esit "T2 ham havuz sayısı" "4" "$(alan "$OUT" havuz 3)"
esit "T3 karar defteri sayısı" "2" "$(alan "$OUT" karar 3)"
esit "T4 aday havuzu sayısı" "1" "$(alan "$OUT" aday 3)"
# ÇEKİRDEK KURAL: defterde kaydı olan (b0003) ve zaten elenen (b0004) süzmeye GİRMEZ → 2 kalır
esit "T5 süzmeye-hazır = defterde kaydı olmayan ham'lar (b0003/b0004 hariç)" "2" "$(alan "$OUT" suzmeye-hazir 2)"
printf '%s' "$OUT" | grep -q '^ornek	b0003' \
  && no "T5b defterde kararı olan bulgu örnek listesinde" "$OUT" \
  || ok "T5b defterde kararı olan bulgu örneklerde YOK (tekrar süzülmez)"
esit "T6 son tur satırı taşınıyor" "1" "$(printf '%s' "$OUT" | grep -c '^son-tur	')"

# ── DÜRÜSTLÜK: YOK ≠ BOŞ ────────────────────────────────────────────────────
R2="$TMP/repo2"; mkdir -p "$R2/_agents/handoff"
printf '%s\n' '{"id":"b1","tip":"bulgu","baslik":"tek","durum":"ham"}' > "$R2/_agents/handoff/bulgu-havuzu.jsonl"
OUT2="$(kos "$R2")"
esit "T7 karar defteri YOKsa 'yok' der (0 demez)" "yok" "$(alan "$OUT2" karar 2)"
esit "T8 aday havuzu YOKsa 'yok' der" "yok" "$(alan "$OUT2" aday 2)"
HUM="$(KESIF_REPO_ROOT="$R2" bash "$SUT" 2>/dev/null)"
printf '%s' "$HUM" | grep -q 'MUCİT bu kutuda hiç süzmemiş' \
  && ok "T8b insan-çıktısı 'hiç süzmemiş' diyor (sıfır-sanılmasın)" \
  || no "T8b 'hiç süzmemiş' ifadesi yok" "$HUM"

# ── SÜZME TAKLİDİ YASAĞI: çıktı 'en iyi' iddiası taşımamalı ────────────────
HUM1="$(KESIF_REPO_ROOT="$R" bash "$SUT" 2>/dev/null)"
if printf '%s' "$HUM1" | grep -qiE 'en iyi|en değerli|öneriyorum'; then
  no "T9 süzme taklidi" "çıktı yargı-iddiası taşıyor"
else ok "T9 süzme taklidi YOK (yargı iddiası yok)"; fi
printf '%s' "$HUM1" | grep -q 'YARGI DEĞİL' \
  && ok "T9b örnek listesi açıkça 'yargı değil' diye etiketli" \
  || no "T9b uyarı etiketi yok" "$HUM1"

# ── fail-closed + kullanım ──────────────────────────────────────────────────
mkdir -p "$TMP/bos"
KESIF_REPO_ROOT="$TMP/bos" bash "$SUT" >/dev/null 2>&1; rc=$?
esit "T10 hiçbir defter yoksa exit=2" "2" "$rc"
BOS="$(KESIF_REPO_ROOT="$TMP/bos" bash "$SUT" 2>/dev/null)"
esit "T10b defter yokken tablo basılmaz (uydurma yok)" "" "$BOS"
KESIF_REPO_ROOT="$R" bash "$SUT" --bilinmeyen >/dev/null 2>&1; rc=$?
esit "T11 bilinmeyen bayrak exit=2" "2" "$rc"

# ── bozuk satır tüm defteri düşürmemeli (zarif-bozulma) ────────────────────
R3="$TMP/repo3"; mkdir -p "$R3/_agents/handoff"
{ printf '%s\n' '{"id":"b1","tip":"bulgu","baslik":"saglam","durum":"ham"}'
  printf '%s\n' 'BOZUK-SATIR-JSON-DEGIL'
  printf '%s\n' '{"id":"b2","tip":"bulgu","baslik":"saglam2","durum":"ham"}'; } > "$R3/_agents/handoff/bulgu-havuzu.jsonl"
esit "T12 bozuk satır atlanır, sağlamlar okunur" "2" "$(alan "$(kos "$R3")" havuz 3)"

echo "─────────────────────────────"
echo "TOPLAM: $PASS PASS · $FAIL FAIL"
[ "$FAIL" -eq 0 ] || exit 1
