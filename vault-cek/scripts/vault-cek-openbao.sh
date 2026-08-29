#!/usr/bin/env bash
# vault-cek — OPENBAO adaptörü (L13/L54 · CANLI VARSAYILAN · cutover 2026-08-07; taslak 2026-07-23).
# Kontrat, Infisical/Railway adaptörleriyle BİREBİR AYNI → consumer'lar YENİDEN-KABLOLANMAZ;
# yalnız backbone Infisical→OpenBao değişir (swappable-seam 3. kanıtı):
#   vault-cek doctor            bao/curl + AppRole identity + KV erişimi (3-durum; exit-4 korunur)
#   vault-cek resolve           addr/mount/namespace göster (SIR DEĞİL)
#   vault-cek get <KEY>         <KEY>'i çek → cortex-access.env (değer BASILMAZ)
#   vault-cek list [<kaynak>]   <kaynak> path'indeki KEY ADLARINI göster (değer DEĞİL; default shared)
#   vault-cek put <KEY> [--tenant <ad>] [--uzerine-yaz] [--stdin]
#                               <KEY>'i kasaya YATIR — değer STDIN'den ya da ortamdaki <KEY>
#                               değişkeninden gelir; argv'ye ASLA düşmez. Üzerine-yazma fail-closed.
#
# Backbone: OpenBao KV-v2 + AppRole auth. Değer stdout/log/chat'e ASLA basılmaz
#   (get → yalnız cortex-access.env'e 600; token/secret YALNIZ shell-değişkeninde).
# Auth: ~/.config/openbao/identity.env → BAO_ROLE_ID + BAO_SECRET_ID + BAO_ADDR (HARDCODE YOK).
# Model: Infisical folder/düz-KEY → KV-v2 KEY-başına-secret eşleği:
#   `<KAYNAK>__<REST>` → secret/<kaynak-lower>/<REST> (AÇIK HEDEF — daima kazanır) ·
#   `__`-siz → ÖNCE secret/<kendi-kiracı>/<KEY>, bulunamazsa secret/shared/<KEY> (L68/F3) ·
#   field=value. Kiracı adı login yanıtından türetilir (EK AĞ TURU YOK); türetilemezse shared.
#   cortex-access.env'e ORİJİNAL <KEY> adıyla yazılır.
# Motor: `bao` CLI varsa CLI-yolu, yoksa curl HTTP-API fallback (jq gerekli).
set -uo pipefail

ENV_FILE="${CORTEX_ACCESS_ENV:-$HOME/.config/cortex-access.env}"
IDENT_FILE="${OPENBAO_IDENTITY_ENV:-$HOME/.config/openbao/identity.env}"
MOUNT="${BAO_KV_MOUNT:-secret}"      # KV-v2 mount adı
OVR_PATH="${VAULT_PATH:-}"           # KEY-map path override (opsiyonel, mount-altı göreli)
TENANT_OVR=""                        # put: hedef kiracı klasörü override (--tenant)
UZERINE=0                            # put: 1 ise mevcut kaydın üstüne yaz (varsayılan fail-closed)
STDIN_MODU=0                         # put: değer borudan mı gelsin (--stdin)

grn(){ printf '\033[32m%s\033[0m\n' "$*"; }
red(){ printf '\033[31m%s\033[0m\n' "$*"; }
ylw(){ printf '\033[33m%s\033[0m\n' "$*"; }
die(){ red "✗ $*" >&2; exit 1; }
die2(){ red "✗ $*" >&2; exit 2; }   # kullanım/sözleşme hatası (RC=2)

# --mount <m> / --path <p> herhangi konumda ayrıştır → kalan pozisyonelleri ARGS'a topla.
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --mount) MOUNT="${2:-}"; shift 2 ;;
    --mount=*) MOUNT="${1#--mount=}"; shift ;;
    --path) OVR_PATH="${2:-}"; shift 2 ;;
    --path=*) OVR_PATH="${1#--path=}"; shift ;;
    --tenant) TENANT_OVR="${2:-}"; shift 2 ;;
    --tenant=*) TENANT_OVR="${1#--tenant=}"; shift ;;
    --uzerine-yaz) UZERINE=1; shift ;;
    --stdin) STDIN_MODU=1; shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]:-}"

# Motor seçimi: bao CLI > curl+jq HTTP fallback. İkisi de yoksa açık remediation.
if command -v bao >/dev/null 2>&1; then ENGINE=cli
elif command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then ENGINE=http
else die "ne 'bao' CLI ne curl+jq var — kur: bao CLI (openbao.org) YA DA curl+jq (HTTP-yolu)"; fi

_load_ident(){   # identity.env'den ROLE_ID/SECRET_ID/ADDR yükle (değer basmadan). Yoksa açık remediation.
  [ -f "$IDENT_FILE" ] || die "identity.env yok ($IDENT_FILE) — Sultan AppRole provision etmeli (600-dosya: BAO_ROLE_ID/BAO_SECRET_ID/BAO_ADDR)"
  set -a; . "$IDENT_FILE"; set +a
  : "${BAO_ADDR:?identity.env icinde BAO_ADDR yok - OpenBao sunucu adresi}"
  : "${BAO_ROLE_ID:?identity.env icinde BAO_ROLE_ID yok}"
  : "${BAO_SECRET_ID:?identity.env icinde BAO_SECRET_ID yok}"
  export BAO_ADDR
}

# Login yanıtından SÜZÜLMÜŞ kimlik-bilgisi (YALNIZ policy adları + rol adı; TOKEN ASLA burada
# tutulmaz). Kiracı adı bundan türetilir → ek ağ turu YOKTUR (bkz _tenant_bul).
_LOGIN_JSON=""

_login(){   # AppRole → kısa-ömürlü token. Token yalnız $BAO_TOKEN'a (stdout'a BASILMAZ).
  _load_ident
  local tok="" resp="" _xtl=0
  # 🔴 SIR-HİJYENİ: login yanıtı token TAŞIR; xtrace açıksa atama değeri trace'e basar → kapat.
  case $- in *x*) _xtl=1 ;; esac
  set +x
  if [ "$ENGINE" = cli ] && ! command -v jq >/dev/null 2>&1; then
    # jq yoksa yalnız token alınır; kiracı türetilemez → eski (shared) davranışa düşülür.
    tok=$(bao write -field=token auth/approle/login \
          role_id="$BAO_ROLE_ID" secret_id="$BAO_SECRET_ID" 2>/dev/null) || tok=""
  else
    if [ "$ENGINE" = cli ]; then
      resp=$(bao write -format=json auth/approle/login \
             role_id="$BAO_ROLE_ID" secret_id="$BAO_SECRET_ID" 2>/dev/null) || resp=""
    else
      resp=$(curl -sf -X POST "$BAO_ADDR/v1/auth/approle/login" \
             -d "{\"role_id\":\"$BAO_ROLE_ID\",\"secret_id\":\"$BAO_SECRET_ID\"}" 2>/dev/null) || resp=""
    fi
    tok=$(printf '%s' "$resp" | jq -r '.auth.client_token // empty' 2>/dev/null) || tok=""
    # Yanıtı TOKEN'DAN ARINDIRARAK sakla: yalnız policy adları + rol adı kalır (sır değil).
    _LOGIN_JSON=$(printf '%s' "$resp" \
      | jq -c '{p:(.auth.token_policies // .auth.policies // []), r:(.auth.metadata.role_name // "")}' 2>/dev/null) || _LOGIN_JSON=""
    resp=""
  fi
  if [ "$_xtl" -eq 1 ]; then set -x; fi
  [ -n "$tok" ] || die "AppRole login başarısız / token boş (ROLE_ID·SECRET_ID·BAO_ADDR·policy?)"
  export BAO_TOKEN="$tok"
  return 0
}

_tenant_ad_gecerli(){   # $1=aday kiracı adı → RC0 geçerli. (Ad SIR DEĞİL; provizyon charset'i.)
  case "${1:-}" in
    ""|shared) return 1 ;;         # shared zaten yedek yol — kendi-kiracı sayılmaz
    -*|*[!a-z0-9-]*) return 1 ;;   # path-traversal / büyük-harf / boşluk kalkanı
  esac
  [ "${#1}" -le 31 ] || return 1
  return 0
}

_tenant_bul(){   # stdout: kutunun KENDİ kiracı adı, ya da BOŞ (türetilemedi → sessizce shared).
  # ⚙️ EK AĞ TURU YOK: kaynak, zaten yapılmış olan AppRole login'in yanıtıdır
  #    (lookup-self'e gerek kalmadı — ölçüm 2026-08-14: yanıt hem token_policies hem
  #    metadata.role_name taşıyor). Provizyon değişmezi (bao-provizyon.sh:140-145):
  #    policy adı = `tenant-<ad>` ∧ AppRole rol adı = `<ad>`.
  local pols n aday
  # 0) Açık override — kurtarma/test için (ad sır değil).
  if [ -n "${VAULT_TENANT:-}" ]; then
    _tenant_ad_gecerli "$VAULT_TENANT" && { printf '%s' "$VAULT_TENANT"; return 0; }
    return 1
  fi
  [ -n "$_LOGIN_JSON" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  # 1) Policy'den türet — yetkinin GERÇEK kaynağı budur. TEK bir `tenant-*` varsa kesin;
  #    sıfır ya da BİRDEN ÇOK varsa belirsiz → türetme, yedeğe geç.
  pols=$(printf '%s' "$_LOGIN_JSON" | jq -r '.p[]? // empty' 2>/dev/null | grep '^tenant-' || true)
  n=$(printf '%s' "$pols" | grep -c . || true)
  if [ "$n" = "1" ]; then
    aday="${pols#tenant-}"
    _tenant_ad_gecerli "$aday" && { printf '%s' "$aday"; return 0; }
  fi
  # 2) Yedek: AppRole rol adı.
  aday=$(printf '%s' "$_LOGIN_JSON" | jq -r '.r // empty' 2>/dev/null) || aday=""
  _tenant_ad_gecerli "$aday" && { printf '%s' "$aday"; return 0; }
  return 1
}

_map_key(){   # $1=KEY → MAP_PATH (mount-altı klasör), MAP_INFKEY (secret adı). Override: --path/VAULT_PATH.
  # MAP_ONEKSIZ=1 → anahtar `__`-siz VE --path/VAULT_PATH override'ı yok demektir; yalnız bu
  # durumda `get` kendi-kiracı-önce çözümünü uygular (açık hedef DAİMA kazanır — değişmez).
  local k="$1"
  MAP_ONEKSIZ=0
  if [ -n "$OVR_PATH" ]; then
    MAP_PATH="${OVR_PATH#/}"; MAP_INFKEY="$k"
  elif [ "${k%%__*}" != "$k" ]; then
    local src="${k%%__*}" rest="${k#*__}"
    MAP_PATH="$(printf '%s' "$src" | tr '[:upper:]' '[:lower:]')"; MAP_INFKEY="$rest"
  else
    MAP_PATH="shared"; MAP_INFKEY="$k"; MAP_ONEKSIZ=1
  fi
}

_kv_list(){   # $1=path → secret adları (satır-satır) stdout'a; hata→RC≠0. Değer okunmaz (metadata-LIST).
  local p="$1"
  if [ "$ENGINE" = cli ]; then
    bao kv list -format=json "$MOUNT/$p" 2>/dev/null | jq -r '.[]' 2>/dev/null
  else
    curl -sf -H "X-Vault-Token: $BAO_TOKEN" -X LIST "$BAO_ADDR/v1/$MOUNT/metadata/$p" \
      | jq -r '.data.keys[]?' 2>/dev/null
  fi
}

_kv_liste_kodu(){  # $1=path → YALNIZ http-kodu (200 var · 404 boş/yok · 403 yasak). Değer okunmaz.
  local p="$1"
  if [ "$ENGINE" = cli ]; then
    # CLI kod döndürmez: çıktı varsa 200, "No value found" ise 404, izin hatası ise 403 say.
    local o; o="$(bao kv list "$MOUNT/$p" 2>&1)"
    case "$o" in
      *"permission denied"*) printf '403' ;;
      *"No value found"*|*"not found"*) printf '404' ;;
      *) [ -n "$o" ] && printf '200' || printf '404' ;;
    esac
  else
    curl -s -o /dev/null -w '%{http_code}' -H "X-Vault-Token: $BAO_TOKEN" \
         -X LIST "$BAO_ADDR/v1/$MOUNT/metadata/$p"
  fi
}

_kv_get(){   # $1=path $2=key → field 'value' stdout'a (YALNIZ komut-ikamesiyle capture edilir).
  local p="$1" k="$2"
  if [ "$ENGINE" = cli ]; then
    bao kv get -field=value "$MOUNT/$p/$k" 2>/dev/null
  else
    curl -sf -H "X-Vault-Token: $BAO_TOKEN" "$BAO_ADDR/v1/$MOUNT/data/$p/$k" \
      | jq -er '.data.data.value' 2>/dev/null
  fi
}

_kv_var_mi(){   # $1=path $2=key → RC0 varsa, RC1 yoksa. YALNIZ http-kodu okunur; DEĞER OKUNMAZ.
  local p="$1" k="$2" kod
  kod="$(curl -s -o /dev/null -w '%{http_code}' -m 15 \
         -H "X-Vault-Token: $BAO_TOKEN" "$BAO_ADDR/v1/$MOUNT/data/$p/$k")"
  [ "$kod" = "200" ]
}

_kv_put(){   # $1=path $2=key · DEĞER **STDIN'den** okunur (argv'ye ASLA düşmez — R6).
  # Boru faz4-tasi.sh:99-104'ten: jq -Rs stdin → curl -d @-. `jq --arg` YASAK (argv).
  # Fark: orada `printf '%s' "$V" |` vardı; burada here-string kullanılıyor çünkü
  # `printf` argümanı `set -x` altında değeri trace'e basıyordu (kabul-testi A5).
  # stdout: gövde + son satırda http-kodu.
  local p="$1" k="$2"
  jq -Rs '{data:{value:(rtrimstr("\n"))}}' \
    | curl -s -m 20 -w '\n%{http_code}' \
           -H "X-Vault-Token: $BAO_TOKEN" \
           --data-binary @- "$BAO_ADDR/v1/$MOUNT/data/$p/$k"
}

cmd="${1:-help}"

# ── ÇOK-SATIRLI DEĞER YARDIMCILARI (2026-08-29, MEDDAH'ın bulgusu) ───────────────────
# Satır-içi kod yerine FONKSİYON: çevrimdışı sınama yalnız fonksiyon çağırabiliyor
# (vault-cek-tenant.test.sh deseni). Satır-içi kalsaydı bu davranış test EDİLEMEZDİ —
# ve tam da test edilemeyen davranışlar sessizce bozuluyor.

# _env_yaz_olc <KEY> <ENV_DOSYA> — değeri VAL ortam-değişkeninden alır, env dosyasına
# shlex-quote'lu yazar (600) ve "uzunluk<TAB>parmak-izi<TAB>satır-sayısı" basar.
# 🔴 Değer stdout'a ASLA düşmez; parmak izi sha256'nın ilk 12 hanesidir (geri döndürülemez).
_env_yaz_olc() {
  KEY="$1" ENVF="$2" python3 -c '
import os,re,shlex,hashlib
k=os.environ["KEY"]; envf=os.environ["ENVF"]; val=os.environ["VAL"]
lines=[l for l in open(envf).read().splitlines() if not re.match(r"^export "+re.escape(k)+"=",l)] if os.path.exists(envf) else []
lines.append("export %s=%s"%(k, shlex.quote(val)))
open(envf,"w").write("\n".join(lines)+"\n"); os.chmod(envf,0o600)
iz=hashlib.sha256(val.encode("utf-8")).hexdigest()[:12]
print("%d\t%s\t%d" % (len(val), iz, val.count("\n")+1))'
}

# _cok_satir_uyar <KEY> <SATIR> <IZ> — çok satırlıysa yüksek sesle uyarır (stderr), değilse susar.
# NİÇİN: çok satırlı bir değer shlex.quote ile DOĞRU yazılır ama env dosyasında FİZİKSEL olarak
# birden çok satıra yayılır. Tüketicilerin çoğu satır-tabanlı okuyor
# (`sed -n 's/^export K=//p' | head -1`) → ölçüldü: 55 karakterlik bir değer **2 karaktere**
# düşüyor ve HİÇ SES ÇIKMIYOR. "Anahtar var mı" diye bakan her kapı yeşil yanıyor; elde kalan
# şey bir süs parantezi. Yazan taraf doğru, okuyan taraf kırık — bu fonksiyon kırığı görünür kılar.
_cok_satir_uyar() {
  local k="$1" satir="$2" iz="$3"
  [ "${satir:-1}" -gt 1 ] || return 0
  printf '%s\n' "⚠️  ÇOK SATIRLI DEĞER (${satir} satır) — satır-tabanlı okuma bu değeri SESSİZCE bozar." >&2
  printf '%s\n' "    Yanlış: sed/grep/head ile 'export ${k}=' satırını ayıklamak → yalnız ilk satır alınır." >&2
  printf '%s\n' "    Doğru : set -a; . \"\$HOME/.config/cortex-access.env\"; set +a   (kabuk dizeyi bütün okur)" >&2
  printf '%s\n' "    Doğrula: değeri BASMADAN  printf '%%s' \"\$${k}\" | sha256sum  → ilk 12 hane ${iz} olmalı." >&2
}


case "$cmd" in
  resolve)
    _login
    _T="$(_tenant_bul || true)"
    grn "✓ openbao → addr=$BAO_ADDR mount=$MOUNT engine=$ENGINE"
    if [ -n "$_T" ]; then
      printf '  kiracı   : %s (öneksiz anahtar önce %s/%s, sonra %s/shared)\n' "$_T" "$MOUNT" "$_T" "$MOUNT"
    else
      ylw "  kiracı   : belirlenemedi — öneksiz anahtar YALNIZ $MOUNT/shared'da aranır (eski davranış)"
    fi ;;

  doctor)
    if [ ! -f "$IDENT_FILE" ]; then ylw "• motor=$ENGINE var; identity.env YOK ($IDENT_FILE) — Sultan AppRole provision"; exit 4; fi
    _login || exit 4
    # shared erişimini prob et (değer-basmadan; yalnız exit-code — LIST metadata, veri okumaz).
    # 🔴 BOŞ ≠ YASAK (2026-08-06, aynı yanılgıya bir günde İKİ kez düşüldü)
    #   Eski hâli: LIST başarısızsa doğrudan "policy/mount yanlış?" diyordu — oysa en sık sebep
    #   klasörün BOŞ olmasıydı. Göç öncesi kasa tamamen boştu ve doctor her koşuda "bir şey bozuk"
    #   izlenimi verdi; saatler bu yanlış izi kovalamakla geçti. Aynı sınıf Infisical tarafında da
    #   görüldü (`list nexus` → yeşil "(boş)" derken aslında yetki yoktu). Ders: ölçüm aleti
    #   "bilmiyorum" diyebilmeli. HTTP kodu ayrımı yapar: 404=yok/boş · 403=yasak.
    _shared_kod="$(_kv_liste_kodu "shared")"
    case "$_shared_kod" in
      200)
        grn "✓ vault erişimi HAZIR (openbao · $BAO_ADDR · mount=$MOUNT · engine=$ENGINE)" ;;
      404)
        grn "✓ vault erişimi HAZIR (openbao · $BAO_ADDR · mount=$MOUNT · engine=$ENGINE)"
        ylw "  not: $MOUNT/shared BOŞ (404) — kusur DEĞİL; oraya henüz sır konmamış." ;;
      403)
        ylw "• login OK ama $MOUNT/shared YASAK (403) — policy path-scope dar; kimliğin bu klasöre izni yok"; exit 4 ;;
      *)
        ylw "• login OK ama $MOUNT/shared DOĞRULANAMADI (http=$_shared_kod) — mount=$MOUNT doğru mu, ağ?"; exit 4 ;;
    esac ;;

  list)
    _login
    src="${2:-}"
    if [ -n "$OVR_PATH" ]; then P="${OVR_PATH#/}"
    elif [ -n "$src" ]; then P="$(printf '%s' "$src" | tr '[:upper:]' '[:lower:]')"
    else P="shared"; fi
    # KV-v2 LIST → yalnız secret-ADLARI (metadata endpoint'i; değer hiç okunmaz).
    names="$(_kv_list "$P" | sort)" || true
    [ -n "$names" ] || { _kv_list "$P" >/dev/null 2>&1 || die "list başarısız ($MOUNT/$P) — path/policy?"; }
    n="$(printf '%s' "$names" | grep -c . || true)"
    grn "Vault KEY adları [$MOUNT/$P] ($n):"
    if [ "$n" -gt 0 ]; then printf '  • %s\n' $names; else printf '  (boş)\n'; fi ;;

  get)
    KEY="${2:-}"; [ -n "$KEY" ] || die "kullanım: get <KEY>"
    _map_key "$KEY"
    _login
    # ── KENDİ-KİRACI-ÖNCE (L68/F3, 2026-08-14) ──────────────────────────────────────────
    # Öneksiz anahtar ARTIK önce kutunun KENDİ kiracı klasöründe aranır, bulunamazsa
    # `shared`'a düşer. Niçin: bir anahtarı bir ajana vermek tek komut olsun diye
    # (`vault-cek put SEDIR__PCLOUD_AUTH_TOKEN`) — alıcı beceriler hiç değişmeden bulsun.
    # Vaka: pCloud anahtarları SEDİR'in kendi klasöründeydi, beceri `shared`'a bakıyordu →
    # "izin doğru, adres yanlış". Değişmezler: (1) açık `<KAYNAK>__<KEY>` hedefi etkilenmez,
    # (2) kendi klasöründe kopyası olmayan kutu eskisi gibi `shared` görür (geriye-uyum),
    # (3) kiracı türetilemezse / okuma yasaksa SESSİZCE eski davranışa düşülür.
    _TEN=""; _COZUM=""
    if [ "${MAP_ONEKSIZ:-0}" -eq 1 ]; then
      _TEN="$(_tenant_bul || true)"
      if [ -n "$_TEN" ]; then
        # field=value → YALNIZ değer; shell-değişkenine capture, ekrana BASILMAZ.
        VAL=$(_kv_get "$_TEN" "$MAP_INFKEY") || VAL=""
        if [ -n "$VAL" ]; then MAP_PATH="$_TEN"; _COZUM="kendi-kiracı"; fi
      fi
    fi
    if [ -z "${VAL:-}" ]; then
      VAL=$(_kv_get "$MAP_PATH" "$MAP_INFKEY") || VAL=""
      [ -n "$VAL" ] && _COZUM="$([ "${MAP_ONEKSIZ:-0}" -eq 1 ] && printf shared || printf 'açık-hedef')"
    fi
    if [ -z "$VAL" ]; then
      if [ -n "$_TEN" ]; then
        die "$KEY yok (bakıldı: $MOUNT/$_TEN/$MAP_INFKEY → $MOUNT/shared/$MAP_INFKEY) — Sultan OpenBao'ya eklemeli"
      fi
      die "$KEY yok ($MOUNT/$MAP_PATH/$MAP_INFKEY) — Sultan OpenBao'ya eklemeli"
    fi
    # Idempotent yaz: ORİJİNAL <KEY> adıyla (consumer rewire-yok), shlex-quote, 600. Değer python-env (argv-YOK).
    _OLC="$(VAL="$VAL" _env_yaz_olc "$KEY" "$ENV_FILE")"
    LEN="$(printf '%s' "$_OLC" | cut -f1)"
    IZ="$(printf '%s' "$_OLC" | cut -f2)"
    SATIR="$(printf '%s' "$_OLC" | cut -f3)"
    grn "✓ $KEY alındı → cortex-access.env (${LEN} krk, değer basılmadı · iz=${IZ} · $MOUNT/$MAP_PATH/$MAP_INFKEY · yol=${_COZUM:-açık-hedef})"
    _cok_satir_uyar "$KEY" "$SATIR" "$IZ" ;;

  put)
    # ── KALEM (L68/F1): kasaya YATIRAN komut. Değer stdout/log/argv/trace'e ASLA düşmez.
    #    Merkez yatırdığını GERİ OKUYAMAZ (tenant-nexus.hcl ölü-kutu deseni) → çıktı
    #    yalnız "yazıldı, sürüm N" der; "değer doğru" İDDİA EDİLMEZ (R4).
    KEY="${2:-}"; [ -n "$KEY" ] || die2 "kullanım: put <KEY> [--tenant <ad>] [--uzerine-yaz] [--stdin]"
    case "$KEY" in
      --*|"") die2 "kullanım: put <KEY> [--tenant <ad>] [--uzerine-yaz] [--stdin]" ;;
      *[!A-Za-z0-9_]*) die2 "geçersiz KEY: yalnız A-Z a-z 0-9 _ (eval/enjeksiyon kalkanı)" ;;
    esac
    command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 \
      || die "put yalnız HTTP-yolundan yazar (değer argv'ye düşmesin diye) — curl+jq gerekli"

    _map_key "$KEY"
    # --tenant verilirse hedef klasörü EZER; anahtar-adı eşlemesi (§2.1) korunur.
    if [ -n "$TENANT_OVR" ]; then
      MAP_PATH="$(printf '%s' "$TENANT_OVR" | tr '[:upper:]' '[:lower:]')"
    fi
    case "$MAP_PATH" in
      ""|*/*|.|..) die2 "geçersiz hedef klasör: '$MAP_PATH' (tek seviye ad olmalı)" ;;
    esac
    case "$MAP_INFKEY" in
      ""|*/*) die2 "geçersiz anahtar adı: '$MAP_INFKEY'" ;;
    esac

    # 🔴 SIR-HİJYENİ: değer bu noktadan itibaren shell-değişkeninde. xtrace açıksa
    #    atamalar değeri trace'e basar → burada kapatılır, yazma bitince geri açılır.
    _XT=0; case $- in *x*) _XT=1 ;; esac
    set +x
    if [ "$STDIN_MODU" -eq 1 ]; then
      [ ! -t 0 ] || die2 "--stdin verildi ama boru yok — değeri borudan ver"
      VAL="$(cat)"
    else
      VAL="${!KEY:-}"   # dolaylı genişletme (eval YOK) — değer argv'ye düşmez
      [ -n "$VAL" ] || { die2 "değer yok — ya '--stdin' ile borudan ver ya da ortamda $KEY tanımla (argv YASAK)"; }
    fi
    [ -n "$VAL" ] || die2 "değer BOŞ — boş sır yatırılmaz"

    _login

    if [ "$UZERINE" -eq 0 ] && _kv_var_mi "$MAP_PATH" "$MAP_INFKEY"; then
      VAL=""
      die "hedefte zaten var — --uzerine-yaz ister ($MOUNT/$MAP_PATH/$MAP_INFKEY)"
    fi

    _CIKTI="$(_kv_put "$MAP_PATH" "$MAP_INFKEY" <<<"$VAL")" || _CIKTI=""
    VAL=""   # değeri bellekten düşür
    [ "$_XT" -eq 1 ] && set -x

    _KOD="$(printf '%s\n' "$_CIKTI" | tail -n1)"
    _GOVDE="$(printf '%s\n' "$_CIKTI" | sed '$d')"
    case "$_KOD" in
      200|204) ;;
      403) die "YASAK (http=403) — kimliğin $MOUNT/$MAP_PATH üstünde create/update yetkisi yok" ;;
      "") die "yazma denemesi yanıtsız — $BAO_ADDR erişilebilir mi?" ;;
      *)  die "yazılamadı (http=$_KOD · $MOUNT/$MAP_PATH/$MAP_INFKEY)" ;;
    esac
    _VER="$(printf '%s' "$_GOVDE" | jq -r '.data.version // empty' 2>/dev/null)"
    grn "✓ yazıldı: hedef=$MOUNT/$MAP_PATH/$MAP_INFKEY http=$_KOD version=${_VER:-?}"
    ylw "  not: doğrulaması ALICIDA — merkez yatırdığını geri OKUYAMAZ; 'değer doğru' iddia EDİLMEZ." ;;

  *) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
