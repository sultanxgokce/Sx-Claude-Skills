#!/usr/bin/env bash
# kasif-ogren.sh — KAŞİF'in KURAL HALKASI (ADR-025 K5): kaydı REFLEKSE çeviren parça.
#
# NİÇİN VAR: Defter PASİFTİR (okunmayı bekler, AI'ın inisiyatifine kalır); kural AKTİFTİR
#   (davranışı kısıtlar). Sultan'ın teşhisi birebir: "deftere bakıp kendince önemli gördüğü
#   noktaları kendi derecelendirerek alır — tamamen AI'ın inisiyatifine kalmış bir şey."
#   İnsanda deneyim istemsiz devreye girer; AI'da girmez. Bu script o boşluğu kapatır.
#
# 🛡️ TASARIM KARARI — BU SCRIPT LLM ÇAĞIRMAZ. Kural üretimi %100 deterministiktir (sayar,
#   eşiğe bakar, yazar). Gerekçe: KAŞİF güvenilmez web içeriği okuyor; öğrenme halkası LLM
#   olsaydı okuduğu metin ona kural yazdırabilirdi (enjeksiyon). Sayaç enjekte edilemez.
#   NEDİM emsalinde (nedim-learn.sh:53-55) kalkan bir PROMPT cümlesidir — burada kalkana
#   ihtiyaç yok, çünkü saldırı yüzeyi hiç yok. Bu daha ucuz VE daha güvenli.
#
# KAPILAR (ADR-025 K5, NEDİM emsali nedim-learn.sh:48,52):
#   1. ≥3 ÖRNEK          — tek/iki örnekten kural doğmaz (rastlantı ≠ desen)
#   2. 7 GÜN COOLDOWN    — aday, doğduğu gün terfi edemez
#   3. ADAY DOĞAR        — kural doğuşta UYARIR, FİLTRELEMEZ (yanlış kural iş kaybettirmesin)
#   4. TERFİ SULTAN'IN   — --sultan-onay bayrağı olmadan aday→kural GEÇMEZ (insan-adına yazma yasağı)
#   5. VARSAYILAN DRY-RUN — yazmak için --yaz gerekir (kanon K05)
#
# KURAL TİPLERİ (hepsi mevcut defterlerden türer — yeni disiplin istemez):
#   kisir-kaynak   : bir adrese ≥3 tur gidildi, hiç bulgu çıkmadı        → "oraya gitme"
#   elenen-sinif   : MUCİT aynı gerekçeyle ≥3 kez eledi                  → "bu sınıfı getirme"
#   guclu-tekrar   : aynı fikir ≥3 AYRI kaynaktan geldi                  → "bu sinyali ciddiye al"
#
# KULLANIM:
#   kasif-ogren.sh                      → DRY-RUN: hangi kurallar doğardı (hiçbir şey yazmaz)
#   kasif-ogren.sh --yaz                → adayları yontem.jsonl'e işler (idempotent)
#   kasif-ogren.sh liste                → insan-görünümü (kurallar + adaylar)
#   kasif-ogren.sh terfi <id> --sultan-onay [--gerekce "..."]
#   kasif-ogren.sh reddi <id> --gerekce "..."   → bir daha aday olarak doğmaz
# RC: 0=başarı · 2=kullanım/kapı hatası
set -uo pipefail

PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HAT_LIB="${HAT_YOLU_LIB:-$PAKET/../layiha/scripts/hat-yolu.lib.sh}"

ESIK="${KASIF_OGREN_ESIK:-3}"           # kaç örnekten sonra aday doğar
COOLDOWN="${KASIF_OGREN_COOLDOWN:-7}"   # gün
BUGUN="${KASIF_TARIH:-$(date +%F)}"

command -v jq >/dev/null 2>&1 || { echo "HATA: jq gerekli" >&2; exit 2; }

# ── yol çözümü (hermetik test kalkanı: KASIF_TEST=1 iken kendiliğinden türetme YOK) ──
_dir=""
if [ -n "${KASIF_HAFIZA_DIR:-}" ]; then _dir="$KASIF_HAFIZA_DIR"
elif [ "${KASIF_TEST:-0}" != "1" ] && [ -r "$HAT_LIB" ]; then
  # shellcheck source=/dev/null
  source "$HAT_LIB" 2>/dev/null && _dir="$(hat_yolu kasif-dir 2>/dev/null || true)"
fi
KAYNAKLAR="${KASIF_KAYNAKLAR:-${_dir:+$_dir/kaynaklar.jsonl}}"
TEKRAR="${KASIF_TEKRAR:-${_dir:+$_dir/tekrar.jsonl}}"
YONTEM="${KASIF_YONTEM_DEFTERI:-${_dir:+$_dir/yontem.jsonl}}"
MUCIT="${KASIF_MUCIT_DEFTERI:-}"
if [ -z "$MUCIT" ] && [ "${KASIF_TEST:-0}" != "1" ] && command -v hat_yolu >/dev/null 2>&1; then
  MUCIT="$(hat_yolu mucit-defteri 2>/dev/null || true)"
fi

[ -n "$YONTEM" ] || { echo "HATA: yöntem defteri yolu çözülemedi (proje klasöründe misin?)" >&2; exit 2; }

_gun_farki() {  # $1=eski tarih (YYYY-MM-DD) → bugüne kaç gün
  local a b
  a="$(date -d "$1" +%s 2>/dev/null)" || { echo 9999; return; }
  b="$(date -d "$BUGUN" +%s 2>/dev/null)" || { echo 9999; return; }
  echo $(( (b - a) / 86400 ))
}

_var_mi() {  # $1=tip $2=anahtar → varsa satırı bas
  [ -s "$YONTEM" ] || return 1
  jq -c --arg t "$1" --arg k "$2" 'select(.tip==$t and .anahtar==$k)' "$YONTEM" 2>/dev/null | tail -1 | grep -q .
}

_durum() {  # $1=tip $2=anahtar → mevcut durum ya da boş
  [ -s "$YONTEM" ] || return 0
  jq -rs --arg t "$1" --arg k "$2" '[.[]|select(.tip==$t and .anahtar==$k)] | last | .durum // ""' "$YONTEM" 2>/dev/null
}

# ── ADAY ÜRETİMİ (deterministik) ────────────────────────────────────────────────────────
# stdout: TSV  tip \t anahtar \t ornek \t kural-metni
_adaylari_uret() {
  # 1) kısır kaynak: ziyaret ≥ ESIK, bulgu 0
  if [ -n "$KAYNAKLAR" ] && [ -s "$KAYNAKLAR" ]; then
    jq -rs --argjson e "$ESIK" '
      [ .[] | {h:(.host // ""), z:(.ziyaret // 0), b:((.bulgu_idler // []) | length)} ]
      | group_by(.h) | map({h:.[0].h, z:(map(.z)|add), b:(map(.b)|add)})
      | .[] | select(.h != "" and .z >= $e and .b == 0)
      | "kisir-kaynak\t\(.h)\t\(.z)\tBu kaynağa gitme: \(.h) — \(.z) tur gidildi, hiç bulgu çıkmadı."
    ' "$KAYNAKLAR" 2>/dev/null
  fi
  # 2) elenen sınıf: MUCİT aynı gerekçe-anahtarıyla ≥ ESIK kez elemiş
  if [ -n "$MUCIT" ] && [ -s "$MUCIT" ]; then
    jq -rs --argjson e "$ESIK" '
      [ .[] | select(.verdikt=="elendi") | (.not // "") | ascii_downcase
        | if test("zaten.?var") then "zaten-var"
          elif test("kanıt|kanit") then "kanitsiz"
          elif test("mihenk") then "mihenk-alani"
          elif test("gürültü|gurultu|pazarlama|trend") then "gurultu"
          else "" end ]
      | map(select(. != "")) | group_by(.) | map({k:.[0], n:length})
      | .[] | select(.n >= $e)
      | "elenen-sinif\t\(.k)\t\(.n)\tBu sınıfı getirme — MUCİT \(.n) kez aynı gerekçeyle eledi (\(.k))."
    ' "$MUCIT" 2>/dev/null
  fi
  # 3) güçlü tekrar: aynı fikir ≥ ESIK AYRI kaynaktan (pozitif kural)
  if [ -n "$TEKRAR" ] && [ -s "$TEKRAR" ]; then
    jq -rs --argjson e "$ESIK" '
      [ .[] | {k:(.dedup_key // ""), h:((.hostlar // []) | unique | length)} ]
      | group_by(.k) | map({k:.[0].k, h:(map(.h)|max)})
      | .[] | select(.k != "" and .h >= $e)
      | "guclu-tekrar\t\(.k)\t\(.h)\tBu sinyali ciddiye al: “\(.k)” — aynı fikir \(.h) ayrı kaynaktan geldi."
    ' "$TEKRAR" 2>/dev/null
  fi
}

_sonraki_id() {
  local n=0
  if [ -s "$YONTEM" ]; then
    n="$(jq -rs '[ .[] | (.id // "") | ltrimstr("y") | tonumber? ] | (max // 0)' "$YONTEM" 2>/dev/null || echo 0)"
    [[ "$n" =~ ^[0-9]+$ ]] || n=0
  fi
  printf 'y%04d' $((n+1))
}

# ── komutlar ─────────────────────────────────────────────────────────────────────────────
CMD="uret"; YAZ=0; SULTAN=0; GEREKCE=""; HEDEF=""
while [ $# -gt 0 ]; do
  case "$1" in
    liste)        CMD="liste"; shift ;;
    terfi)        CMD="terfi"; HEDEF="${2:-}"; shift 2 ;;
    reddi)        CMD="reddi"; HEDEF="${2:-}"; shift 2 ;;
    --yaz)        YAZ=1; shift ;;
    --sultan-onay) SULTAN=1; shift ;;
    --gerekce)    GEREKCE="${2:-}"; shift 2 ;;
    -h|--help)    sed -n '/^# KULLANIM:/,/^# RC:/p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "HATA: bilinmeyen argüman: $1" >&2; exit 2 ;;
  esac
done

case "$CMD" in
liste)
  [ -s "$YONTEM" ] || { echo "(yöntem defteri boş — henüz kural doğmadı)"; exit 0; }
  echo "📏 KURALLAR (uygulanır)"
  jq -rs '[.[]|select(.durum=="kural")] | if length==0 then "  (yok)" else (.[] | "  • [\(.id)] \(.kural)") end' "$YONTEM"
  echo "🕯️ ADAYLAR (uyarır, filtrelemez — terfi Sultan'ın)"
  jq -rs '[.[]|select(.durum=="aday")] | if length==0 then "  (yok)" else (.[] | "  • [\(.id)] \(.kural)  [\(.ornek) örnek · doğdu \(.dogdu)]") end' "$YONTEM"
  ;;

terfi|reddi)
  [ -n "$HEDEF" ] || { echo "HATA: kural id gerekli (ör. y0001)" >&2; exit 2; }
  [ -s "$YONTEM" ] || { echo "HATA: yöntem defteri yok" >&2; exit 2; }
  SATIR="$(jq -cs --arg i "$HEDEF" '[.[]|select(.id==$i)] | last // empty' "$YONTEM" 2>/dev/null)"
  [ -n "$SATIR" ] || { echo "HATA: kural bulunamadı: $HEDEF" >&2; exit 2; }
  if [ "$CMD" = "terfi" ]; then
    # ⚖️ İNSAN-ADINA ONAY YASAĞI: bu bayrağı ajan kendi kendine koyamaz; Sultan'ın açık emri gerekir.
    [ "$SULTAN" -eq 1 ] || { echo "HATA: aday→kural terfisi YALNIZ Sultan onayıyla olur (--sultan-onay)." >&2
                             echo "      Ajan bu bayrağı kendi iradesiyle koyamaz (ADR-025 K5 · Yetki-Sınırı)." >&2; exit 2; }
    D="$(echo "$SATIR" | jq -r '.dogdu')"; F="$(_gun_farki "$D")"
    if [ "$F" -lt "$COOLDOWN" ]; then
      echo "HATA: cooldown dolmadı — kural $D tarihinde doğdu, $F gün oldu (gereken: $COOLDOWN)." >&2
      echo "      Bekleme süresi kasıtlıdır: taze desen rastlantı olabilir." >&2; exit 2
    fi
    YENI="$(echo "$SATIR" | jq -c --arg t "$BUGUN" --arg g "$GEREKCE" '.durum="kural" | .terfi=$t | .gerekce=($g|select(.!=""))')"
  else
    [ -n "$GEREKCE" ] || { echo "HATA: reddi için --gerekce zorunlu (niçin kural olmasın?)" >&2; exit 2; }
    YENI="$(echo "$SATIR" | jq -c --arg t "$BUGUN" --arg g "$GEREKCE" '.durum="reddi" | .terfi=$t | .gerekce=$g')"
  fi
  printf '%s\n' "$YENI" >> "$YONTEM"
  echo "OK: $HEDEF → $(echo "$YENI" | jq -r .durum)"
  ;;

uret)
  ADAYLAR="$(_adaylari_uret)"
  YENI_SAYI=0; GUNCEL=0
  while IFS=$'\t' read -r tip anahtar ornek metin; do
    [ -n "${tip:-}" ] || continue
    mevcut="$(_durum "$tip" "$anahtar")"
    case "$mevcut" in
      kural|reddi)  continue ;;   # zaten karara bağlanmış — yeniden doğmaz
      aday)         GUNCEL=$((GUNCEL+1)); continue ;;  # zaten aday; sayaç şişirme yok
    esac
    YENI_SAYI=$((YENI_SAYI+1))
    if [ "$YAZ" -eq 1 ]; then
      id="$(_sonraki_id)"
      jq -nc --arg id "$id" --arg tip "$tip" --arg a "$anahtar" --arg k "$metin" \
             --argjson o "$ornek" --arg d "$BUGUN" \
        '{v:1,id:$id,tip:$tip,anahtar:$a,kural:$k,durum:"aday",ornek:$o,dogdu:$d,terfi:null,gerekce:null}' \
        >> "$YONTEM"
      echo "  + [$id] $metin"
    else
      echo "  ~ (doğacak) $metin"
    fi
  done <<< "$ADAYLAR"

  if [ "$YAZ" -eq 1 ]; then
    echo "öğrenme turu: $YENI_SAYI yeni aday yazıldı · $GUNCEL zaten aday · eşik=$ESIK örnek"
  else
    echo "DRY-RUN (hiçbir şey yazılmadı): $YENI_SAYI aday doğardı · $GUNCEL zaten aday · eşik=$ESIK"
    [ "$YENI_SAYI" -gt 0 ] && echo "yazmak için: kasif-ogren.sh --yaz"
  fi
  ;;
esac
exit 0
