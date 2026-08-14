#!/usr/bin/env bash
# vault-cek put — ÇEVRİMDIŞI sınama (CI kapısı; ağ/kasa/kimlik GEREKTİRMEZ).
# Canlı-kasa kabul testleri ayrı dosyadadır: kabul-testi-put.sh (A1..A8) — o CI'da KOŞMAZ,
# çünkü GitHub runner'ında OpenBao ve AppRole kimliği yoktur (sahte-yeşil kalkanı).
# Burada yalnız kasa'ya DOKUNMADAN doğrulanabilenler var: sözleşme, ret-yolları, sır-hijyeni.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VC="$DIR/vault-cek.sh"; OB="$DIR/vault-cek-openbao.sh"
G=0; K=0
gec(){ G=$((G+1)); printf '  ✓ %s\n' "$1"; }
kal(){ K=$((K+1)); printf '  ✗ %s — %s\n' "$1" "$2"; }
# Kasaya kazara ulaşmayı imkânsız kıl: sahte kimlik dosyası + erişilemez adres.
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
printf 'BAO_ADDR=http://127.0.0.1:1\nBAO_ROLE_ID=x\nBAO_SECRET_ID=y\n' > "$TMP/identity.env"
export OPENBAO_IDENTITY_ENV="$TMP/identity.env"

echo "T1 · üç kabuk dosyası sözdizimi"
ok=1; for f in "$VC" "$OB" "$DIR/vault-cek-infisical.sh" "$DIR/vault-cek-railway.sh"; do
  bash -n "$f" || ok=0; done
[ "$ok" -eq 1 ] && gec T1 || kal T1 "bash -n düştü"

echo "T2 · argümansız put → RC=2 + kullanım satırı"
o="$(bash "$VC" put 2>&1)"; r=$?
{ [ "$r" -eq 2 ] && printf '%s' "$o" | grep -q 'kullanım: put <KEY>'; } && gec T2 || kal T2 "rc=$r · $o"

echo "T3 · geçersiz KEY (enjeksiyon kalkanı) → RC=2"
o="$(bash "$VC" put 'BAD;KEY' --stdin </dev/null 2>&1)"; r=$?
{ [ "$r" -eq 2 ] && printf '%s' "$o" | grep -q 'geçersiz KEY'; } && gec T3 || kal T3 "rc=$r · $o"

echo "T4 · geçersiz hedef klasör (path-traversal) → RC=2"
o="$(bash "$VC" put NEXUS__X --tenant '../etc' --stdin </dev/null 2>&1)"; r=$?
{ [ "$r" -eq 2 ] && printf '%s' "$o" | grep -q 'geçersiz hedef klasör'; } && gec T4 || kal T4 "rc=$r · $o"

echo "T5 · değer kaynağı yok (ne --stdin ne ortam) → RC=2, argv önerilmez"
o="$(bash "$VC" put NEXUS__YOKKI 2>&1)"; r=$?
{ [ "$r" -eq 2 ] && printf '%s' "$o" | grep -q 'argv YASAK'; } && gec T5 || kal T5 "rc=$r · $o"

echo "T6 · boş değer reddi → RC=2"
o="$(printf '' | bash "$VC" put NEXUS__BOS --stdin 2>&1)"; r=$?
{ [ "$r" -eq 2 ] && printf '%s' "$o" | grep -q 'BOŞ'; } && gec T6 || kal T6 "rc=$r · $o"

echo "T7 · put yalnız openbao'da — infisical/railway RC=2 + açık ret"
ok=1
for b in infisical railway; do
  o="$(VAULT_BACKEND=$b bash "$VC" put NEXUS__X 2>&1)"; r=$?
  { [ "$r" -eq 2 ] && printf '%s' "$o" | grep -q "bu backbone'da put yok"; } || { ok=0; echo "    $b: rc=$r · $o"; }
done
[ "$ok" -eq 1 ] && gec T7 || kal T7 "başka backbone put'u sessizce kabul etti"

echo "T8 · yapısal sır-hijyeni: değer-alan bayrak YOK, jq --arg YOK"
ok=1
grep -qE '^\s*--deger|--value\)' "$OB" && { ok=0; echo "    değer-alan bayrak bulundu"; }
grep -vE '^\s*#' "$OB" | grep -q 'jq .*--arg' && { ok=0; echo "    jq --arg kullanımı bulundu (argv sızıntısı)"; }
grep -q 'data-binary @-' "$OB" || { ok=0; echo "    curl stdin-borusu (@-) yok"; }
[ "$ok" -eq 1 ] && gec T8 || kal T8 "argv-değişmezi ihlali"

echo "T9 · yardım metni put'u ilan ediyor"
o="$(bash "$OB" yardim 2>&1)"
printf '%s' "$o" | grep -q 'vault-cek put <KEY>' && gec T9 || kal T9 "help'te put yok"

echo "T10 · xtrace altında değer trace'e düşmüyor (ağsız: yazma 'yasak/ulaşılamaz'da biter)"
S='SENTINEL-offline-7b2d'
tr_out="$(printf '%s' "$S" | bash -x "$OB" put NEXUS__TRACE_OFFLINE --stdin 2>&1)"
n="$(printf '%s' "$tr_out" | grep -c "$S")"
[ "$n" -eq 0 ] && gec T10 || kal T10 "değer trace'e $n kez düştü"

printf 'SONUÇ: %d geçti · %d kaldı\n' "$G" "$K"
[ "$K" -eq 0 ]
