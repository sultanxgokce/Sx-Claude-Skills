#!/usr/bin/env bash
# zeyl — gereklilik defteri. Sultan'ın gün içinde söylediği, aklında kalan, kaybolan şeyler.
#
# 🔴 NİÇİN VAR — ÖLÇÜLDÜ, tahmin değil (2026-08-30, oturum transkripti sayıldı):
#   Sultan 6 günde 27 mesaj yazdı; 16'sı en az bir gereklilik taşıyordu; toplam 72 kalem.
#   Diske BİREBİR inen 27. **45 kalem (%62) hiçbir dosyada yok.**
#   Aynı oturumdaki compaction ÜÇ kalemi fiilen yedi (canlı · ezber · ders-çalış → grep 0).
#   Ve Sultan tekrar söylemek zorunda kaldı: "hala" kelimesi 5 mesajda 6 kez.
#   Kayıtsızlığın faturası zaten ödeniyordu — faturayı SULTAN kesiyordu, sistem değil.
#
# 🔴 NİÇİN YENİ BİR DEPO DEĞİL: bu kutuda gereklilik defteri DÖRT KEZ kuruldu, dördü de öldü
#   (GEREKLILIKLER.md 1 gün · tohumlar 8 gün · Notlarım 1 gün · seyir-defteri 32 kayıt/0 kapanış).
#   Hepsinin ortak kusuru: Sultan'ın GİTMESİ gereken bir yerdeydiler. Gidilmeyen yüzey yaşamadı.
#   Zeyl ayrı bir depo AÇMAZ — seyir-defterinin kendi dosyasına yazar (aynı şema + üç delta),
#   ve oturum-başı kimlik bloğunda Sultan'ın ZATEN baktığı yerde görünür.
#
# ÜÇ İSİM (Sultan onayladı 2026-08-31 · _agents/spec/p04-gereklilik-defteri/02-UC-ISIM.md):
#   ÇAĞIRAN   = oturum-başı kimlik bloğu (yeni cron YOK)
#   ÇIKIŞ     = `ham` kayıt bir turdan fazla verdiktsiz yaşayamaz (giriş tavanı YOK)
#   DOĞRULAMA = `zeyl doktor` — her açık kaydın tazeliğini diskten TÜRETEREK ölçer
#
# KULLANIM
#   zeyl yaz "<Sultan'ın cümlesi>" [--kaynak=<kullanim-testi|gun-ici-not|canli-kullanim|
#             denetim-bulgusu|sultan-talebi|kod-incelemesi|hata-sonrasi|bilinmeyen>]
#             [--tur-no=<n>] [--proje=<ad>] [--not=<bilinmeyen kaynak için zorunlu açıklama>]
#   zeyl bekleyen                 → verdikt bekleyen `ham` kayıtlar (toplu soru için)
#   zeyl verdikt <id> <acik|dustu|engelli> [--sebep="…"] [--ref=<id|bağ>]
#   zeyl yapildi <id> --kanit=<commit-sha|dosya-yolu|PR#no>
#   zeyl ozet                     → tek satır (kimlik bloğu bunu basar; bekleyen yoksa SESSİZ)
#   zeyl doktor                   → 0 sağlıklı · 1 ihlal · 2 ölçülemedi
set -uo pipefail

# ── defter çöz — seyir-defteri.sh ile AYNI SÖZLEŞME (2026-09-03, globalleştirme düzeltmesi)
#
# 🔴 NİÇİN DEĞİŞTİ: devralınan sürüm defteri betiğin KENDİ dizininin yanında arıyordu
#   (dirname($0)/../seyir-defteri.jsonl). MİHENK'te bu tesadüfen doğru yere denk geliyordu.
#   Global skill olarak kurulunca betik ~/.claude/skills/zeyl/scripts/ altında yaşar →
#   defter ~/.claude/skills/zeyl/seyir-defteri.jsonl'e düşerdi. Orası 15 kutunun PAYLAŞTIĞI
#   dizindir: bir kutunun gereklilikleri ötekilerin gözüne görünürdü (İ1 ihlali) ve hiçbir
#   projenin kendi defteriyle birleşmezdi. Kardeş betik seyir-defteri.sh git-kökünü kullanıyor;
#   zeyl aynı dosyaya yazdığını iddia ettiğine göre AYNI çözümü kullanmak zorunda.
#
# ⛔ ORTAK-MOUNT FALLBACK YOK: git-kökü bulunamazsa $HOME/.claude'a DÜŞMEZ, rc=2 verir.
#   (layiha paketinin K1 kararıyla aynı gerekçe: oraya düşen defter İ1'i geri alınamaz deler.)
_store(){
  if [ -n "${SEYIR_DEFTERI:-}" ]; then printf '%s' "$SEYIR_DEFTERI"; return 0; fi
  local root; root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$root" ]; then
    printf '✗ ölçülemedi: git-kökü yok → defter yolu çözülemedi.\n  reçete: bir depo içinden koş ya da SEYIR_DEFTERI=<yol> ver.\n' >&2
    exit 2
  fi
  printf '%s/seyir-defteri.jsonl' "$root"
}
# Reçetelerde kullanılacak KENDİ yolu — sabit yol yazmak ölü uç üretir (bkz. ozet).
KENDI_YOL="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/$(basename "${BASH_SOURCE[0]}")"
[ -e "$KENDI_YOL" ] || KENDI_YOL="zeyl"

STORE="$(_store)"

# KÖK = defterin bulunduğu dizin (eskiden betiğin dizini). Kanıt çözümü ve proje-adı
# buradan türer: kanıt "bu deponun" commit'i ya da dosyası olmalı — betiğin kurulduğu
# yerin değil. Global kurulumda ikisi FARKLI yerlerdir; ayrımı yapmayan sürüm, kanıtı
# skill dizininde arayıp geçerli kanıtı REDDEDERDİ (ve olmayanı kabul edebilirdi).
KOK="$(cd "$(dirname "$STORE")" && pwd)"

# ── kimlik — seyir-defteri.sh ile AYNI SÖZLEŞME · UYDURMA YOK
# Devralınan sürüm "NİŞANCI"ya sabitlenmişti; başka kutuda koşunca her kayıt yanlış
# kişiye yazılırdı (provenance-dürüstlüğü). Bilinmiyorsa uydurmaz, host:dizin basar.
_kim(){
  if [ -n "${ZEYL_KIM:-}" ]; then printf '%s' "$ZEYL_KIM"; return; fi
  if [ -n "${EKIP_UYE:-}" ]; then printf '%s' "$EKIP_UYE"; return; fi
  if [ -n "${AGENT_NAME:-}" ]; then printf '%s' "$AGENT_NAME"; return; fi
  printf '%s:%s' "$(hostname 2>/dev/null || echo host)" "$(basename "$(pwd 2>/dev/null || echo '?')")"
}
KIM="$(_kim)"

# Kapalı küme — serbest metin ölçümü öldürür, kapalı küme gerçeği kırpar.
# Panzehir: `bilinmeyen` + ZORUNLU not (taşma valfi) ve payı ölçülür (bkz. doktor).
VALID_KAYNAK="kullanim-testi gun-ici-not canli-kullanim denetim-bulgusu sultan-talebi kod-incelemesi hata-sonrasi bilinmeyen"
VALID_VERDIKT="acik dustu engelli"

die(){ printf '🔴 %s\n' "$*" >&2; exit 2; }
_in(){ case " $2 " in *" $1 "*) return 0;; *) return 1;; esac; }
_now(){ date -u +%Y-%m-%dT%H:%M:%SZ; }
command -v jq >/dev/null 2>&1 || die "jq gerekli (ön-koşul)"

# 🔴 HOŞGÖRÜLÜ OKUYUCU: bu dosyada iki şema ve 10 markdown satırı karışık duruyor
# (ölçüldü). Bozuk satırda ÇÖKMEK, defteri kullanılamaz yapardı; SESSİZCE atlamak ise
# kaybı gizlerdi. Atlanan satır sayısı `doktor`da RAPORLANIR.
# 🔴 GERÇEKTEN hoşgörülü olmalı: `jq -c 'select(...)' dosya` İLK bozuk satırda ÖLÜR ve
# ondan sonrasını hiç okumaz. İlk yazımda tam bunu yaptım — yorumda "hoşgörülü" yazıyordu,
# kod hoşgörülü DEĞİLDİ ve defter boş görünüyordu. `-R` + `fromjson?` satır satır dener,
# bozuğu atlar, devam eder. (Bu oturumda kaçıncı "iddia ettim ama ölçmedim" bilmiyorum.)
_kayitlar(){ [ -f "$STORE" ] && jq -Rc 'fromjson? | select(type=="object")' "$STORE" 2>/dev/null || true; }
_bozuk_sayisi(){ [ -f "$STORE" ] || { echo 0; return; }
  local t g; t=$(grep -c . "$STORE" 2>/dev/null || echo 0); g=$(_kayitlar | grep -c . || echo 0)
  echo $((t-g)); }

_yeni_id(){ local n; n="$(_kayitlar | jq -r 'select(.tip=="not") | .id' 2>/dev/null \
  | grep -oE '[0-9]+$' | sort -n | tail -1)"; printf 'z%04d' "$(( ${n:-0} + 1 ))"; }

# Son dispozisyon (yoksa "ham"): kayıt açıldığında verdikt YOKTUR.
_durum(){ local id="$1" d
  d="$(_kayitlar | jq -r --arg id "$id" 'select(.tip=="disp" and .not_id==$id) | .durum' 2>/dev/null | tail -1)"
  printf '%s' "${d:-ham}"; }

_gereklilikler(){ _kayitlar | jq -c 'select(.tip=="not" and .tur=="gereklilik")' 2>/dev/null; }

_yas_gun(){ local ts="$1" a b; a=$(date -u -d "$ts" +%s 2>/dev/null) || { echo 0; return; }
  b=$(date -u +%s); echo $(( (b-a)/86400 )); }

# ═══ yaz ═════════════════════════════════════════════════════════════════════
cmd_yaz(){
  local metin="${1:-}"; shift || true
  local kaynak="gun-ici-not" turno="" proje="" aciklama=""
  for a in "$@"; do case "$a" in
    --kaynak=*) kaynak="${a#*=}";; --tur-no=*) turno="${a#*=}";;
    --proje=*) proje="${a#*=}";;   --not=*) aciklama="${a#*=}";;
    *) die "bilinmeyen bayrak: $a";; esac; done
  [ -n "$metin" ] || die 'kullanım: zeyl yaz "<metin>" [--kaynak=…]'
  _in "$kaynak" "$VALID_KAYNAK" || die "geçersiz kaynak '$kaynak' (geçerli: $VALID_KAYNAK)"
  # Taşma valfi kapısı: kümeye sığmayan kayıt REDDEDİLMEZ, ama sebepsiz de geçmez.
  [ "$kaynak" != "bilinmeyen" ] || [ -n "$aciklama" ] || die "--kaynak=bilinmeyen ise --not zorunlu"
  # Sır kalkanı: değer taşıyan satır deftere GİRMEZ (SIR-DEĞER YASAĞI, pazarlıksız).
  printf '%s' "$metin" | grep -qiE '(api[_-]?key|secret|token|password|passwd|bearer |sk-[A-Za-z0-9]{16})' \
    && die "sır-deseni yakalandı — defter değer taşımaz; konumu/şemayı yaz, değeri değil"

  local proje_v="${proje:-$(basename "$KOK")}" id ts; ts="$(_now)"
  if command -v flock >/dev/null 2>&1; then exec 9>>"$STORE"; flock 9; fi
  id="$(_yeni_id)"
  jq -nc --arg id "$id" --arg ts "$ts" --arg kim "$KIM" --arg metin "$metin" \
     --arg kaynak "$kaynak" --arg proje "$proje_v" --arg turno "$turno" --arg ack "$aciklama" \
     '{v:1,tip:"not",id:$id,ts:$ts,kim:$kim,sev:"onemli",tur:"gereklilik",metin:$metin,
       kaynak:$kaynak,proje:$proje,dongu:0}
      + (if $turno=="" then {} else {tur_no:($turno|tonumber? // $turno)} end)
      + (if $ack=="" then {} else {kaynak_not:$ack} end)' >> "$STORE"
  if command -v flock >/dev/null 2>&1; then flock -u 9; exec 9>&-; fi
  # 🔴 MAKBUZ: sessizlik ≠ görünmezlik. Sultan kesilmez ama kaydın düştüğünü GÖRÜR.
  printf '📔 zeyl +1 · %s · %s\n' "$id" "$kaynak"
}

# ═══ bekleyen (toplu soru yüzeyi) ════════════════════════════════════════════
cmd_bekleyen(){
  local n=0
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    local id; id="$(printf '%s' "$k" | jq -r .id)"
    [ "$(_durum "$id")" = "ham" ] || continue
    n=$((n+1))
    printf '%s · %s gün · [%s] %s\n' "$id" "$(_yas_gun "$(printf '%s' "$k" | jq -r .ts)")" \
      "$(printf '%s' "$k" | jq -r .kaynak)" "$(printf '%s' "$k" | jq -r .metin | cut -c1-90)"
  done < <(_gereklilikler)
  [ "$n" -gt 0 ] || echo "verdikt bekleyen yok."
}

# ═══ verdikt (ÇIKIŞ ZORUNLULUĞU) ═════════════════════════════════════════════
cmd_verdikt(){
  local id="${1:-}" d="${2:-}"; shift 2 2>/dev/null || true
  local sebep="" ref=""
  for a in "$@"; do case "$a" in --sebep=*) sebep="${a#*=}";; --ref=*) ref="${a#*=}";; esac; done
  [ -n "$id" ] && [ -n "$d" ] || die "kullanım: zeyl verdikt <id> <$VALID_VERDIKT>"
  _in "$d" "$VALID_VERDIKT" || die "geçersiz verdikt '$d' (geçerli: $VALID_VERDIKT)"
  _gereklilikler | jq -e --arg id "$id" 'select(.id==$id)' >/dev/null 2>&1 || die "kayıt yok: $id"
  # Sebepsiz düşürme YASAK: "yapmayacağız" bir karardır, kararın gerekçesi kaydedilir.
  [ "$d" != "dustu" ] || [ -n "$sebep" ] || die "dustu için --sebep zorunlu"
  [ "$d" != "engelli" ] || [ -n "$ref" ] || die "engelli için --ref zorunlu (neye bağlı)"
  jq -nc --arg id "$id" --arg durum "$d" --arg ts "$(_now)" --arg kim "$KIM" \
     --arg sebep "$sebep" --arg ref "$ref" \
     '{v:1,tip:"disp",not_id:$id,durum:$durum,ts:$ts,kim:$kim}
      + (if $sebep=="" then {} else {sebep:$sebep} end)
      + (if $ref=="" then {} else {ref:$ref} end)' >> "$STORE"
  printf '✓ %s → %s\n' "$id" "$d"
}

# ═══ yapildi (KANIT KAPISI) ══════════════════════════════════════════════════
cmd_yapildi(){
  local id="${1:-}"; shift || true
  local kanit=""
  for a in "$@"; do case "$a" in --kanit=*) kanit="${a#*=}";; esac; done
  [ -n "$id" ] || die "kullanım: zeyl yapildi <id> --kanit=<sha|yol|PR#no>"
  # 🔴 KANITSIZ "YAPILDI" YOK. Bu kutunun en sert kuralı; ajan kendi işine kanıtsız
  # "bitti" diyemez. Kanıt DİSKTE ya da git'te GERÇEKTEN bulunmalı — beyan yetmez.
  [ -n "$kanit" ] || die "--kanit zorunlu: kanıtsız 'yapıldı' bu defterde YAZILAMAZ"
  local gecerli=0
  case "$kanit" in
    PR#[0-9]*) gecerli=1 ;;
    *) if git -C "$KOK" cat-file -e "$kanit^{commit}" 2>/dev/null; then gecerli=1
       elif [ -e "$KOK/$kanit" ] || [ -e "$kanit" ]; then gecerli=1; fi ;;
  esac
  [ "$gecerli" = 1 ] || die "kanıt çözülemedi: '$kanit' — commit diskte yok, dosya yok. Kanıtsız-✅ reddedildi."
  local acan; acan="$(_gereklilikler | jq -r --arg id "$id" 'select(.id==$id) | .kim' | tail -1)"
  [ -n "$acan" ] || die "kayıt yok: $id"
  # ⚠️ ÜRETEN ⟂ DOĞRULAYAN: uyarı basılır, ENGELLENMEZ. Bu kutuda tek ajan çalışıyor;
  # sert kilit defteri kullanılamaz yapardı. Ama iz kayda düşer, doktor sayar.
  local ayni=""; [ "$acan" != "$KIM" ] || ayni="1"
  jq -nc --arg id "$id" --arg ts "$(_now)" --arg kim "$KIM" --arg kanit "$kanit" --arg ayni "$ayni" \
     '{v:1,tip:"disp",not_id:$id,durum:"yapildi",ts:$ts,kim:$kim,kanit:$kanit}
      + (if $ayni=="" then {} else {ayni_kimlik:true} end)' >> "$STORE"
  printf '✓ %s → yapildi (kanıt: %s)\n' "$id" "$kanit"
  [ -z "$ayni" ] || printf '⚠ üreten ile doğrulayan AYNI kimlik (%s) — kanıt var, bağımsız göz yok.\n' "$KIM"
}

# ═══ ozet (ÇAĞIRAN bunu basar) ═══════════════════════════════════════════════
cmd_ozet(){
  [ -f "$STORE" ] || exit 0
  local ham=0 acik=0 eskiTs="" eskiId="" eskiMetin=""
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    local id d ts; id="$(printf '%s' "$k" | jq -r .id)"; d="$(_durum "$id")"
    ts="$(printf '%s' "$k" | jq -r .ts)"
    case "$d" in
      ham)  ham=$((ham+1));  [ -n "$eskiTs" ] || { eskiTs="$ts"; eskiId="$id"; eskiMetin="$(printf '%s' "$k" | jq -r .metin | cut -c1-60)"; } ;;
      acik) acik=$((acik+1)); [ -n "$eskiTs" ] || { eskiTs="$ts"; eskiId="$id"; eskiMetin="$(printf '%s' "$k" | jq -r .metin | cut -c1-60)"; } ;;
    esac
  done < <(_gereklilikler)
  # 🔴 BEKLEYEN YOKSA HİÇ BASMA. Sıfır gösteren sayaç gürültüdür (estetik-yön §2).
  [ $((ham+acik)) -gt 0 ] || exit 0
  printf '📔 ZEYL — %s açık gereklilik' "$((ham+acik))"
  [ "$ham" = 0 ] || printf ' · 🔴 %s tanesi VERDİKT BEKLİYOR' "$ham"
  [ -z "$eskiTs" ] || printf ' · en eskisi %s gündür' "$(_yas_gun "$eskiTs")"
  printf '\n'
  [ -z "$eskiId" ] || printf '   → sıradaki: %s "%s"\n' "$eskiId" "$eskiMetin"
  [ "$ham" = 0 ] || printf '   → verdikt: %s bekleyen\n' "$KENDI_YOL"
}

# ═══ doktor (DOĞRULAMA KOMUTU) ═══════════════════════════════════════════════
cmd_doktor(){
  [ -f "$STORE" ] || { echo "⚠ ÖLÇÜLEMEDİ — defter dosyası yok. Bu 'temiz' DEĞİL."; exit 2; }
  local toplam=0 ham=0 ihlal=0 bilinmeyen=0
  echo "ZEYL DOKTOR"; echo "============================================================"
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    toplam=$((toplam+1))
    local id d kaynak; id="$(printf '%s' "$k" | jq -r .id)"; d="$(_durum "$id")"
    kaynak="$(printf '%s' "$k" | jq -r '.kaynak // "?"')"
    [ "$kaynak" != "bilinmeyen" ] || bilinmeyen=$((bilinmeyen+1))
    if [ "$d" = "ham" ]; then
      ham=$((ham+1)); ihlal=$((ihlal+1))
      printf '🔴 %s · ÇIKIŞ İHLALİ — %s gündür verdiktsiz\n' "$id" "$(_yas_gun "$(printf '%s' "$k" | jq -r .ts)")"
    fi
    if [ "$d" = "yapildi" ]; then
      local kanit; kanit="$(_kayitlar | jq -r --arg id "$id" 'select(.tip=="disp" and .not_id==$id and .durum=="yapildi") | .kanit' | tail -1)"
      local ok=0
      case "$kanit" in PR#[0-9]*) ok=1;; *)
        git -C "$KOK" cat-file -e "${kanit}^{commit}" 2>/dev/null && ok=1
        [ -e "$KOK/$kanit" ] && ok=1 ;; esac
      if [ "$ok" != 1 ]; then
        ihlal=$((ihlal+1)); printf '🔴 %s · KANIT ÇÜRÜDÜ — "%s" artık çözülmüyor\n' "$id" "$kanit"
      fi
    fi
  done < <(_gereklilikler)
  local bozuk; bozuk="$(_bozuk_sayisi)"
  echo "------------------------------------------------------------"
  printf 'gereklilik: %s · verdiktsiz: %s · ihlal: %s\n' "$toplam" "$ham" "$ihlal"
  [ "$bozuk" -le 0 ] || printf '⚠ defterde %s okunamayan satır var (atlandı, GİZLENMEDİ)\n' "$bozuk"
  # `bilinmeyen` payı bir METRİKTİR: %20'yi aşarsa hata ajanda değil KÜMEDEDİR.
  if [ "$toplam" -gt 0 ] && [ $(( bilinmeyen * 100 / toplam )) -ge 20 ]; then
    printf '⚠ kaynak "bilinmeyen" payı %%%s — kapalı küme gerçeği kırpıyor, küme genişletilmeli.\n' \
      "$(( bilinmeyen * 100 / toplam ))"
  fi
  [ "$ihlal" = 0 ] || { echo "🔴 ihlal var."; exit 1; }
  echo "✅ temiz. (Boş defter ONURLUDUR — yalnız verdiktsiz kayıt ve çürük kanıt ihlaldir.)"
  exit 0
}

case "${1:-ozet}" in
  yaz)      shift; cmd_yaz "$@" ;;
  bekleyen) cmd_bekleyen ;;
  verdikt)  shift; cmd_verdikt "$@" ;;
  yapildi)  shift; cmd_yapildi "$@" ;;
  ozet)     cmd_ozet ;;
  doktor)   cmd_doktor ;;
  *) die "kullanım: zeyl <yaz|bekleyen|verdikt|yapildi|ozet|doktor>" ;;
esac
