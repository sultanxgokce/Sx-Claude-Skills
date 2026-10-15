#!/usr/bin/env bash
# vault-cek put — KABUL TESTİ (L68/F1, kasa-erisim-kademesi-DESIGN.md §5 "Kabul-kanıtı" A1..A8).
# CANLI kasaya yazar; yalnız KANARYA anahtarları kullanılır — GERÇEK SIR KULLANMA.
# Değer hiçbir yere basılmaz; sentinel'ler sırsız uydurma dizelerdir.
# Kullanım: bash kabul-testi-put.sh          (RC=0 → 8/8 geçti)
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VC="$DIR/vault-cek.sh"
GECEN=0; KALAN=0
S_A2='KNRY-a2-4b71'; S_A4='KNRY-a4-9c02'; S_A5='KNRY-a5-3f8e'

ol(){ printf '%s\n' "──────────────────────────────────────────"; }
gec(){ GECEN=$((GECEN+1)); printf '  ✓ %s GEÇTİ\n' "$1"; }
kal(){ KALAN=$((KALAN+1)); printf '  ✗ %s KALDI — %s\n' "$1" "$2"; }

# Kanarya temizliği (metadata sil → version sayacı 1'den başlasın)
_sil(){ # $1=tenant $2=key
  local t="$1" k="$2"
  [ -f "$HOME/.config/openbao/identity.env" ] || return 0
  set -a; . "$HOME/.config/openbao/identity.env"; set +a
  local tok; tok="$(jq -nc --arg r "$BAO_ROLE_ID" --arg s "$BAO_SECRET_ID" '{role_id:$r,secret_id:$s}' \
        | curl -s -m 20 -d @- "$BAO_ADDR/v1/auth/approle/login" | jq -r '.auth.client_token // empty')"
  [ -n "$tok" ] || return 0
  curl -s -o /dev/null -X DELETE -H "X-Vault-Token: $tok" \
       "$BAO_ADDR/v1/secret/metadata/$t/$k"
}

ol; echo "A1 — argümansız put → RC=2 + kullanım satırı"
OUT="$(bash "$VC" put 2>&1)"; RC=$?
printf '%s\n' "$OUT"; echo "exit=$RC"
{ [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q 'kullanım: put <KEY>'; } \
  && gec A1 || kal A1 "RC=$RC (2 bekleniyordu) ya da kullanım satırı yok"

ol; echo "A2 — taze anahtar yatır → hedef/http/version, DEĞER YOK"
_sil nexus KANARYA_TEST; sleep 1
OUT="$(printf '%s' "$S_A2" | bash "$VC" put NEXUS__KANARYA_TEST --stdin 2>&1)"; RC=$?
printf '%s\n' "$OUT"; echo "exit=$RC"
{ [ "$RC" -eq 0 ] \
  && printf '%s' "$OUT" | grep -q 'hedef=secret/nexus/KANARYA_TEST http=200 version=1' \
  && ! printf '%s' "$OUT" | grep -q "$S_A2"; } \
  && gec A2 || kal A2 "RC=$RC / beklenen satır yok / DEĞER SIZDI"

ol; echo "A3 — aynı put tekrar → fail-closed (üzerine-yazma reddi)"
OUT="$(printf '%s' "$S_A2" | bash "$VC" put NEXUS__KANARYA_TEST --stdin 2>&1)"; RC=$?
printf '%s\n' "$OUT"; echo "exit=$RC"
{ [ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q 'hedefte zaten var — --uzerine-yaz ister'; } \
  && gec A3 || kal A3 "RC=$RC (≠0 bekleniyordu) ya da mesaj yok"

ol; echo "A4 — --uzerine-yaz ile ikinci sürüm"
OUT="$(printf '%s' "$S_A4" | bash "$VC" put NEXUS__KANARYA_TEST --stdin --uzerine-yaz 2>&1)"; RC=$?
printf '%s\n' "$OUT"; echo "exit=$RC"
{ [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'version=2'; } \
  && gec A4 || kal A4 "RC=$RC ya da version=2 yok"

ol; echo "A5 — bash -x altında değer trace'e DÜŞMEMELİ"
_sil nexus KANARYA_TRACE; sleep 1
TR="$(printf '%s' "$S_A5" | bash -x "$DIR/vault-cek-openbao.sh" put NEXUS__KANARYA_TRACE --stdin 2>&1)"
N="$(printf '%s' "$TR" | grep -c "$S_A5")"
echo "trace satır sayısı=$(printf '%s\n' "$TR" | wc -l) · sentinel eşleşmesi=$N"
[ "$N" -eq 0 ] && gec A5 || kal A5 "değer trace'e $N kez düştü"

ol; echo "A6 — başka kiracının klasörüne yatırma (ölü-kutu yetkisi)"
OUT="$(printf '%s' 'KNRY-a6-deadrop' | bash "$VC" put SEDIR__DENEME --stdin --uzerine-yaz 2>&1)"; RC=$?
printf '%s\n' "$OUT"; echo "exit=$RC"
{ [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'http=200'; } \
  && gec A6 || kal A6 "RC=$RC — hedef kiracıda create/update yetkisi yok olabilir (policy ölçümü)"

ol; echo "A7 — put yalnız openbao'da; başka backbone RC=2 + açık ret"
OUT="$(VAULT_BACKEND=railway bash "$VC" put NEXUS__X 2>&1)"; RC=$?
printf '%s\n' "$OUT"; echo "exit=$RC"
{ [ "$RC" -eq 2 ] && printf '%s' "$OUT" | grep -q "bu backbone'da put yok"; } \
  && gec A7 || kal A7 "RC=$RC ya da mesaj yok"

ol; echo "A8 — doctor regresyonu (put eklendikten sonra aynı davranış)"
OUT="$(bash "$VC" doctor 2>&1)"; RC=$?
printf '%s\n' "$OUT"; echo "exit=$RC"
{ [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'vault erişimi HAZIR'; } \
  && gec A8 || kal A8 "RC=$RC ya da HAZIR satırı yok"

ol; echo "temizlik: kanarya anahtarları siliniyor"
_sil nexus KANARYA_TEST; _sil nexus KANARYA_TRACE
echo "  not: secret/sedir/DENEME merkez tarafından SİLİNEMEZ (yalnız create/update) — hedef kiracıda kalır."

ol; printf 'SONUÇ: %d/8 geçti · %d kaldı\n' "$GECEN" "$KALAN"
[ "$KALAN" -eq 0 ]
