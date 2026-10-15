#!/usr/bin/env bash
# vault-cek — KENDİ-KİRACI-ÖNCE çözümü · ÇEVRİMDIŞI sınama (L68/F3).
# Ağ/kasa/kimlik GEREKTİRMEZ: yalnız ad-türetme mantığı ve yapısal değişmezler sınanır.
# Canlı uçtan-uca kanıt PR gövdesindedir (GitHub runner'ında OpenBao yok — sahte-yeşil kalkanı).
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OB="$DIR/vault-cek-openbao.sh"
G=0; K=0
gec(){ G=$((G+1)); printf '  ✓ %s\n' "$1"; }
kal(){ K=$((K+1)); printf '  ✗ %s — %s\n' "$1" "$2"; }

# Kasaya kazara ulaşmayı imkânsız kıl (adres kapalı port).
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
printf 'BAO_ADDR=http://127.0.0.1:1\nBAO_ROLE_ID=x\nBAO_SECRET_ID=y\n' > "$TMP/identity.env"
export OPENBAO_IDENTITY_ENV="$TMP/identity.env"

# Fonksiyonları çağırmak için adaptörü `help` moduyla source et (kasaya dokunmaz).
# 🔴 TUZAK: adaptör source edilirken kendi `set -- "${ARGS[@]}"` satırıyla POZİSYONELLERİ EZER.
#    Bu yüzden argüman source'tan ÖNCE isimli değişkene alınır — yoksa sınama "help" adını
#    doğrular ve her şeye yeşil der (ilk yazımda tam bu oldu, T3 yakaladı).
calistir(){ local fn="$1" arg="${2-}"; ( unset VAULT_TENANT; set -- help; . "$OB" >/dev/null 2>&1; "$fn" "$arg" ); }

echo "T1 · sözdizimi"
bash -n "$OB" && gec T1 || kal T1 "bash -n düştü"

echo "T2 · kiracı-adı doğrulaması: geçerli adlar kabul"
ok=1
for a in nexus sedir cloudtop-code s02 a; do calistir _tenant_ad_gecerli "$a" || { ok=0; echo "    reddedildi: $a"; }; done
[ "$ok" -eq 1 ] && gec T2 || kal T2 "geçerli ad reddedildi"

echo "T3 · kiracı-adı doğrulaması: kötü adlar RED (traversal · shared · büyük-harf · boş)"
ok=1
for a in "" "shared" "../etc" "a/b" "NEXUS" "-x" "a b" "$(printf 'x%.0s' $(seq 40))"; do
  calistir _tenant_ad_gecerli "$a" && { ok=0; echo "    kabul edildi (olmamalıydı): '$a'"; }
done
[ "$ok" -eq 1 ] && gec T3 || kal T3 "kötü ad kabul edildi"

echo "T4 · VAULT_TENANT override — geçerli ad kazanır, kötü ad RED (shared'a düşer)"
o="$( ( export VAULT_TENANT=sedir; set -- help; . "$OB" >/dev/null 2>&1; _tenant_bul ) )"
o2="$( ( export VAULT_TENANT=../etc; set -- help; . "$OB" >/dev/null 2>&1; _tenant_bul ) )"
{ [ "$o" = "sedir" ] && [ -z "$o2" ]; } && gec T4 || kal T4 "override='$o' kötü-override='$o2'"

echo "T5 · policy'den türetme: TEK tenant-* → o kiracı"
o="$( ( unset VAULT_TENANT; set -- help; . "$OB" >/dev/null 2>&1
        _LOGIN_JSON='{"p":["default","tenant-sedir"],"r":"sedir"}'; _tenant_bul ) )"
[ "$o" = "sedir" ] && gec T5 || kal T5 "beklenen sedir, gelen '$o'"

echo "T6 · ÇOKLU tenant-* → belirsiz; rol-adı yedeğine düşer"
o="$( ( unset VAULT_TENANT; set -- help; . "$OB" >/dev/null 2>&1
        _LOGIN_JSON='{"p":["tenant-a","tenant-b"],"r":"huma"}'; _tenant_bul ) )"
[ "$o" = "huma" ] && gec T6 || kal T6 "beklenen huma, gelen '$o'"

echo "T7 · policy YOK ∧ rol-adı YOK → BOŞ (sessizce eski shared davranışı)"
o="$( ( unset VAULT_TENANT; set -- help; . "$OB" >/dev/null 2>&1
        _LOGIN_JSON='{"p":["default"],"r":""}'; _tenant_bul ) )"
o2="$( ( unset VAULT_TENANT; set -- help; . "$OB" >/dev/null 2>&1; _LOGIN_JSON=''; _tenant_bul ) )"
{ [ -z "$o" ] && [ -z "$o2" ]; } && gec T7 || kal T7 "boş beklendi: '$o' / '$o2'"

echo "T8 · kötü policy adı (tenant-../etc) türetilmez → BOŞ"
o="$( ( unset VAULT_TENANT; set -- help; . "$OB" >/dev/null 2>&1
        _LOGIN_JSON='{"p":["tenant-../etc"],"r":""}'; _tenant_bul ) )"
[ -z "$o" ] && gec T8 || kal T8 "traversal türetildi: '$o'"

echo "T9 · _map_key: açık hedef ve --path override öneksiz-yolu KAPATIR (MAP_ONEKSIZ=0)"
o="$( ( set -- help; . "$OB" >/dev/null 2>&1; _map_key SEDIR__X; printf '%s|%s|%s' "$MAP_PATH" "$MAP_INFKEY" "$MAP_ONEKSIZ" ) )"
o2="$( ( set -- help; . "$OB" >/dev/null 2>&1; OVR_PATH=shared; _map_key PCLOUD_AUTH_TOKEN; printf '%s' "$MAP_ONEKSIZ" ) )"
o3="$( ( set -- help; . "$OB" >/dev/null 2>&1; _map_key PCLOUD_AUTH_TOKEN; printf '%s|%s' "$MAP_PATH" "$MAP_ONEKSIZ" ) )"
{ [ "$o" = "sedir|X|0" ] && [ "$o2" = "0" ] && [ "$o3" = "shared|1" ]; } \
  && gec T9 || kal T9 "açık='$o' override='$o2' öneksiz='$o3'"

echo "T10 · yapısal: get bloğunda shared-yedeği DURUYOR (geriye-uyum değişmezi)"
ok=1
grep -q 'MAP_ONEKSIZ' "$OB" || { ok=0; echo "    MAP_ONEKSIZ yok"; }
grep -q '_tenant_bul' "$OB" || { ok=0; echo "    _tenant_bul yok"; }
grep -q 'MAP_PATH="shared"' "$OB" || { ok=0; echo "    shared yedeği kayıp"; }
[ "$ok" -eq 1 ] && gec T10 || kal T10 "geriye-uyum yapısı bozulmuş"

echo "T11 · sır-hijyeni: token saklanan JSON'a girmiyor (yalnız policy+rol süzülüyor)"
ok=1
grep -q 'client_token' "$OB" || { ok=0; echo "    login token okuma satırı kayboldu"; }
grep -q '_LOGIN_JSON=\$(printf' "$OB" || { ok=0; echo "    süzme (jq -c) satırı yok"; }
grep -qE "_LOGIN_JSON.*client_token" "$OB" && { ok=0; echo "    token _LOGIN_JSON'a sızıyor"; }
[ "$ok" -eq 1 ] && gec T11 || kal T11 "login-yanıtı süzme değişmezi ihlali"

echo "T12 · ağsız get: temiz hata, çökme yok (RC≠0)"
o="$(bash "$OB" get PCLOUD_AUTH_TOKEN 2>&1)"; r=$?
{ [ "$r" -ne 0 ] && printf '%s' "$o" | grep -q 'login başarısız'; } && gec T12 || kal T12 "rc=$r · $o"

printf 'SONUÇ: %d geçti · %d kaldı\n' "$G" "$K"
[ "$K" -eq 0 ]
