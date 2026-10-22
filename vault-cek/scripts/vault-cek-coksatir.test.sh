#!/usr/bin/env bash
# vault-cek — ÇOK SATIRLI DEĞER: sessiz kırık → sesli (2026-08-29, MEDDAH'ın bulgusu).
# ÇEVRİMDIŞI: ağ/kasa/kimlik gerektirmez; yalnız yazma+ölçme+uyarı fonksiyonları sınanır.
# Gerçek sır KULLANILMAZ — sahte değerler.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OB="$DIR/vault-cek-openbao.sh"
G=0; K=0
gec(){ G=$((G+1)); printf '  ✓ %s\n' "$1"; }
kal(){ K=$((K+1)); printf '  ✗ %s — %s\n' "$1" "$2"; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
printf 'BAO_ADDR=http://127.0.0.1:1\nBAO_ROLE_ID=x\nBAO_SECRET_ID=y\n' > "$TMP/identity.env"
export OPENBAO_IDENTITY_ENV="$TMP/identity.env"

# Adaptörü `help` modunda source et (kasaya dokunmaz) — tenant.test.sh deseni.
# 🔴 TUZAK (tenant.test.sh'te de yazılı, ben de düştüm): adaptör source edilirken kendi
#    `set -- "${ARGS[@]}"` satırıyla POZİSYONELLERİ EZER. Bu yüzden argümanlar source'tan
#    ÖNCE isimli değişkene alınır; `"$@"` ile taşımak sessizce "help" verir.
_fn(){ local fn="$1" a1="${2-}" a2="${3-}" a3="${4-}"
  ( set -- help; . "$OB" >/dev/null 2>&1; "$fn" "$a1" "$a2" "$a3" ); }

TEK='tek-satirlik-sahte-deger'
COK='{
  "tur": "sahte",
  "anahtar": "AAAA"
}'

echo "T1 · sözdizimi"
bash -n "$OB" && gec T1 || kal T1 "bash -n düştü"

echo "T2 · tek satırlı değer: uzunluk/iz/satır doğru, satır=1"
O="$( VAL="$TEK" _fn _env_yaz_olc ORNEK "$TMP/a.env" )"
L="$(printf '%s' "$O" | cut -f1)"; IZ="$(printf '%s' "$O" | cut -f2)"; S="$(printf '%s' "$O" | cut -f3)"
[ "$L" = "${#TEK}" ] && [ "$S" = "1" ] && [ "${#IZ}" = "12" ] \
  && gec T2 || kal T2 "uzunluk=$L satır=$S iz-uzunluk=${#IZ}"

echo "T3 · parmak izi DEĞERİN KENDİSİ DEĞİL (sha256 ilk 12 · geri döndürülemez)"
BEK="$(printf '%s' "$TEK" | sha256sum | cut -c1-12)"
[ "$IZ" = "$BEK" ] && gec T3 || kal T3 "iz=$IZ beklenen=$BEK"
case "$IZ" in *"$TEK"*) kal T3b "iz değeri içeriyor";; *) gec T3b;; esac

echo "T4 · çok satırlı değer: satır sayısı DOĞRU ölçülür"
O2="$( VAL="$COK" _fn _env_yaz_olc ORNEK2 "$TMP/b.env" )"
S2="$(printf '%s' "$O2" | cut -f3)"; L2="$(printf '%s' "$O2" | cut -f1)"
[ "$S2" = "4" ] && [ "$L2" = "${#COK}" ] && gec T4 || kal T4 "satır=$S2 (beklenen 4) uzunluk=$L2"

echo "T5 · 🔴 ASIL VAKA: satır-tabanlı okuma değeri BOZAR — dosya bunu kanıtlar"
YANLIS="$(sed -n 's/^export ORNEK2=//p' "$TMP/b.env" | head -1)"
set -a; . "$TMP/b.env"; set +a
DOGRU="$ORNEK2"
[ "${#YANLIS}" -lt "${#DOGRU}" ] && gec T5 || kal T5 "satır-tabanlı okuma bozmadı (${#YANLIS} vs ${#DOGRU})"
[ "$DOGRU" = "$COK" ] && gec T5b || kal T5b "source ile okunan değer bozuk"

echo "T6 · uyarı: çok satırlıda SESLİ (stderr), tek satırlıda SESSİZ"
U2="$( _fn _cok_satir_uyar ORNEK2 4 abc123abc123 2>&1 1>/dev/null )"
U1="$( _fn _cok_satir_uyar ORNEK 1 abc123abc123 2>&1 1>/dev/null )"
case "$U2" in *"ÇOK SATIRLI"*) gec T6a;; *) kal T6a "çok satırlıda uyarı YOK";; esac
[ -z "$U1" ] && gec T6b || kal T6b "tek satırlıda gereksiz uyarı: $U1"

echo "T7 · uyarı DOĞRU REÇETEYİ verir (set -a … source) ve doğrulama izini söyler"
case "$U2" in *"set -a"*) gec T7a;; *) kal T7a "doğru okuma reçetesi yok";; esac
case "$U2" in *"abc123abc123"*) gec T7b;; *) kal T7b "parmak izi reçetede yok";; esac

echo "T8 · 🔴 uyarı DEĞERİ BASMAZ (sır sızıntısı kalkanı)"
U3="$( VAL="$COK" _fn _cok_satir_uyar ORNEK2 4 abc123abc123 2>&1 )"
case "$U3" in *AAAA*) kal T8 "uyarı metninde değer parçası göründü";; *) gec T8;; esac

echo "T9 · env dosyası 600 izinli"
P="$(stat -c '%a' "$TMP/b.env" 2>/dev/null)"
[ "$P" = "600" ] && gec T9 || kal T9 "izin=$P"

echo "T10 · aynı anahtar iki kez yazılınca TEK satır kalır (idempotent, birikme yok)"
VAL="$TEK" _fn _env_yaz_olc ORNEK2 "$TMP/b.env" >/dev/null
N="$(grep -c '^export ORNEK2=' "$TMP/b.env")"
[ "$N" = "1" ] && gec T10 || kal T10 "aynı anahtardan $N satır var"

# ── ATOMİK YAZIM (mmex 6d6ff3b1 · kök neden NARH 18 Eki): dosya yerinde kesilip yeniden yazılıyordu, kilit yoktu →
#    aynı anda okuyan nöbet TRENDYOL satıcı kimliğini boş gördü (16 Eki). Beklenen: kilit + aynı dizinde geçici dosya + rename.
echo "T11 · yazım dosyayı YERİNDE kesmez: yeni dosya yerine geçer (inode değişir)"
VAL="$TEK" _fn _env_yaz_olc ATOM_A "$TMP/c.env" >/dev/null
I1="$(stat -c '%i' "$TMP/c.env")"; VAL="$TEK" _fn _env_yaz_olc ATOM_B "$TMP/c.env" >/dev/null; I2="$(stat -c '%i' "$TMP/c.env")"
[ "$I1" != "$I2" ] && gec T11 || kal T11 "inode aynı kaldı ($I1) — dosya yerinde kesilip yazılıyor"

echo "T12 · eşzamanlı okuyucu HİÇ eksik anahtar görmez (180 KB dosya, 30 yazım sürerken)"
for i in $(seq 1 3000); do printf 'export DOLGU_%04d=%s\n' "$i" "dolgu-degeri-uzun-bir-satir-olsun-ki-yazim-birden-cok-parcada-gitsin"; done > "$TMP/d.env"
printf 'export SABIT=%s\n' "yerinde-kalmali" >> "$TMP/d.env"
rm -f "$TMP/d.bitti"
( for i in $(seq 1 30); do VAL="deger-$i" _fn _env_yaz_olc DEGISEN "$TMP/d.env" >/dev/null; done; : > "$TMP/d.bitti" ) &
EKSIK="$(D="$TMP/d.env" B="$TMP/d.bitti" python3 -c '
import os
d,b=os.environ["D"],os.environ["B"]; okuma=eksik=0
while not os.path.exists(b) or okuma==0:
    try: s=open(d).read()
    except FileNotFoundError: s=""
    okuma+=1
    if "export SABIT=" not in s: eksik+=1
print("%d %d"%(eksik,okuma))')"
wait
set -- $EKSIK
[ "$1" = "0" ] && [ "$2" -gt 0 ] && gec "T12 ($2 okuma, 0 eksik)" || kal T12 "$2 okumanın $1'inde SABIT anahtarı yoktu (yarım dosya okundu)"

echo "T13 · iki eşzamanlı yazan birbirinin anahtarını SİLMEZ (kilit)"
: > "$TMP/e.env"
( for i in $(seq 1 15); do VAL="x" _fn _env_yaz_olc "BIR_$i" "$TMP/e.env" >/dev/null; done ) &
( for i in $(seq 1 15); do VAL="y" _fn _env_yaz_olc "IKI_$i" "$TMP/e.env" >/dev/null; done ) &
wait
N="$(grep -cE '^export (BIR|IKI)_[0-9]+=' "$TMP/e.env")"
[ "$N" = "30" ] && gec T13 || kal T13 "30 anahtardan $N kaldı — eşzamanlı yazan birbirini ezdi"

echo "T14 · env yolu bir BAĞ (symlink) ise bağ korunur, hedef güncellenir; artık geçici dosya kalmaz"
printf 'export ESKI=1\n' > "$TMP/gercek.env"; ln -s "$TMP/gercek.env" "$TMP/bag.env"
VAL="$TEK" _fn _env_yaz_olc YENI "$TMP/bag.env" >/dev/null
[ -L "$TMP/bag.env" ] && grep -q '^export YENI=' "$TMP/gercek.env" && grep -q '^export ESKI=' "$TMP/gercek.env" \
  && gec T14 || kal T14 "bağ bozuldu ya da hedef güncellenmedi"
ARTIK="$(find "$TMP" -maxdepth 1 -name '.*.env.*' | wc -l | tr -d ' ')"
[ "$ARTIK" = "0" ] && gec T14b || kal T14b "$ARTIK artık geçici dosya kaldı"
P="$(stat -c '%a' "$TMP/gercek.env")"; [ "$P" = "600" ] && gec T14c || kal T14c "hedef izni $P"

echo
echo "SONUÇ: $G geçti · $K kaldı"
[ "$K" -eq 0 ]
