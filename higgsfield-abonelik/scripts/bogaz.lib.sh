#!/usr/bin/env bash
# bogaz.lib.sh — TEK DIS-URETIM BOGAZI, ORTAK GOVDE.
#
# ── NEDEN (plan v2 §4 · kirmizi takim bulgusu C1) ────────────────────────────
# v1 altyapiyi (onay · sayac · idempotans · yukleme izni) SAGLAYICIYA OZEL kuruyordu.
# Kirmizi takim bunun iki kotu sondan birini garanti ettigini gosterdi: ya arac altyapiyi
# ATLAR (kapisiz harcama), ya altyapi HER NIS ICIN KOPYALANIR (drift).
#
# 🔴 Ve ben tam bunu yapmak uzereydim: staging.sh'i yazdim, ardindan video hatti gelince
# ayni alti kapiyi IKINCI KEZ yazacaktim. satis.sh'te kapali kumeyi, ses tarafinda
# anahtar_al'i tek kaynaga almistim — ucuncu kez ayni dersi odemeyeyim diye govde buraya.
#
# Adaptor sozlesmesi (staging ve video icin AYNI):
#   --ad         insan-okur ad
#   --hazir-mi   rc 0 = kullanilabilir (anahtar/arac var)
#   --birim-usd  beyan edilen birim maliyet (0 = bedava)
#   --gercek-mi  rc 0 = GERCEK saglayici · rc 1 = SAHTE (teslim edilemez)
#   uret ...     uretimi yapar
set -uo pipefail

# ── ISLER defteri yolu (K9 deseni) ───────────────────────────────────────────
bogaz_isler_yolu() { # $1=repo-kok -> yol stdout'a; gecersiz env'de rc 1
  local repo="$1" yol="$1/uretim/isler.jsonl"
  if [ -n "${TELLAL_ISLER:-}" ]; then
    if [ "${TELLAL_TEST:-}" = "1" ] && case "$TELLAL_ISLER" in /tmp/*) true ;; *) false ;; esac; then
      yol="$TELLAL_ISLER"
    else
      echo "[kirmizi] TELLAL_ISLER yok sayildi: yalniz TELLAL_TEST=1 ve /tmp altinda gecerlidir" >&2
      return 1
    fi
  fi
  printf '%s' "$yol"
}

# ── Sinav, GERCEK uretim defterini kirletemez ────────────────────────────────
# 🔴 BIREBIR YASANDI (2026-08-19): kapi-testi TELLAL_ISLER'i cevirdi, TELLAL_DEFTER'i
# unuttu; dort sahte satir gercek uretim/defter.jsonl'a dustu. Korudugu veriyi
# kirletebilen sinav kusurludur (is.sh ayni dersi F0.6'da odemisti).
bogaz_sinav_izolasyonu() {
  if [ "${TELLAL_TEST:-}" = "1" ] && [ -n "${TELLAL_ISLER:-}" ]; then
    case "${TELLAL_DEFTER:-}" in
      /tmp/*) return 0 ;;
      *) echo "[kirmizi] sinav kipi: TELLAL_ISLER cevrilmis ama TELLAL_DEFTER cevrilmemis." >&2
         echo "          Sinav GERCEK uretim defterine yazamaz — ikisi birlikte cevrilir." >&2
         return 1 ;;
    esac
  fi
}

# ── 1) Saglayici HAZIR MI (iddia degil, SORGU) ───────────────────────────────
bogaz_hazir_mi() { # $1=adaptor-yolu
  bash "$1" --hazir-mi && return 0
  echo "[kirmizi] saglayici hazir degil: $(bash "$1" --ad 2>/dev/null)" >&2
  echo "          (anahtar/arac eksik — 'hazir' bir iddia degil, sorgu sonucudur)" >&2
  return 1
}

# ── 2) KIP KAPISI — sahte cikti TESLIM EDILEMEZ (KANON D3) ───────────────────
bogaz_kip_kapisi() { # $1=adaptor $2=kip
  [ "$2" = "teslim" ] || return 0
  bash "$1" --gercek-mi && return 0
  echo "[kirmizi] '$(basename "$1" .sh)' SAHTE bir saglayicidir; --kip teslim ile kullanilamaz." >&2
  echo "          Sinav ciktisi duzenegi sinar, musteriye gitmez (KANON D3)." >&2
  return 1
}

# ── 3) MALIYET TAVANI (anayasa §6) ───────────────────────────────────────────
# Arac kendi tavanini ACAMAZ: tavani yukseltmek Sultan-gate'tir.
bogaz_tavan() { # $1=birim-usd $2=tavan-usd $3=carpan(kac birim uretilecek, ondalikli olabilir)
  local birim="$1" tavan="$2" carpan="${3:-1}"
  python3 - "$birim" "$tavan" "$carpan" <<'PY'
import sys
birim, tavan, carpan = (float(x) for x in sys.argv[1:4])
tutar = birim * carpan
if tutar > tavan:
    print(f"[kirmizi] ongorulen maliyet ${tutar:.4f} > tavan ${tavan:.2f} — cagri YAPILMADI.", file=sys.stderr)
    print("          Tavani yukseltmek Sultan-gate'tir (anayasa §6).", file=sys.stderr)
    sys.exit(1)
print(f"{tutar:.4f}")
PY
}

# ── 4) IDEMPOTANS — ayni is ikinci kez saglayiciya GITMEZ ────────────────────
bogaz_anahtar() { printf '%s' "$*" | sha256sum | cut -c1-16; }
bogaz_idempotans() { # $1=isler-yolu $2=anahtar
  mkdir -p "$(dirname "$1")"; [ -f "$1" ] || : > "$1"
  grep -q "\"anahtar\": \"$2\"" "$1" 2>/dev/null || return 0
  echo "[kirmizi] BU IS ZATEN URETILDI (anahtar $2) — saglayiciya GIDILMEDI." >&2
  echo "          Ayni girdi+ayar+saglayici ikinci kez para yakmaz; kasitli tekrar ayri bir karardir." >&2
  return 1
}

# ── 4b) KREDI TAVANI — IKINCI PARA BIRIMI, IKINCI KAPI (2026-08-28) ─────────
# 🔴 NEDEN VAR: Higgsfield ABONELIK yolu dolar degil KREDI yer ve o kredinin
# marjinal dolar maliyeti gercekten SIFIRDIR (abonelik odendi, kullanilmayan
# kredi ay sonunda yanar). Ama adaptor '0 dolar' beyan edince USD tavani
# ETKISIZ kaliyor. Tavansiz bir yol, tavanli bir yoldan TEHLIKELIDIR: 3000
# kredi bir gecede tukenir ve kimse durdurmaz. Para birimi degisince kapi
# kaybolmaz, kapi da para birimi degistirir.
# Tavan verilmemisse VARSAYILAN SIKIDIR (50 kredi ~ 8 tadilat zinciri): bir
# kapinin varsayilani, unutuldugu gun ne olacagini soyler.
bogaz_kredi_tavani() { # $1=birim-kredi $2=tavan-kredi $3=carpan
  local birim="$1" tavan="${2:-50}" carpan="${3:-1}"
  python3 - "$birim" "$tavan" "$carpan" <<'KRD'
import sys
birim, tavan, carpan = (float(x) for x in sys.argv[1:4])
tutar = birim * carpan
if tutar > tavan:
    print(f"[kirmizi] ongorulen KREDI {tutar:.2f} > tavan {tavan:.2f} — cagri YAPILMADI.", file=sys.stderr)
    print("          Abonelik kredisi de bir butcedir; tavani yukseltmek Sultan-gate'tir.", file=sys.stderr)
    sys.exit(1)
print(f"{tutar:.2f}")
KRD
}

# ── 5) IS KAYDI ──────────────────────────────────────────────────────────────
bogaz_kaydet() { # $1=isler $2=anahtar $3=is_id $4=saglayici $5=kip $6=birim $7=sure_sn $8=ek-json-alanlari
  printf '{"anahtar": "%s", "is_id": "%s", "tarih": "%s", "saglayici": "%s", "kip": "%s", "birim_usd": %s, "sure_sn": %s%s}\n' \
    "$2" "$3" "$(date -Is)" "$4" "$5" "$6" "$7" "${8:-}" >> "$1"
}

# ── 6) DEFTER SATIRI — FAIL-CLOSED (2026-08-24) ──────────────────────────────
# 🔴 NEDEN SERT: uc bogazin ucu de bu cagriyi `|| echo "[uyari] ..."` ile yapiyordu,
# yani defter satiri yazilamasa bile arac YESIL basip RC 0 donuyordu. Anayasa §6 her
# kalemi sayacli ister; para cikip satir yazilmadiginda "tamam" demek, olculmemis bir
# harcamayi olculmus gibi gostermektir. Ustelik uyari metni "is kaydi isler.jsonl'da
# duruyor" diyordu — bu da OLCULMEMIS bir teselliydi; o dosyanin yazildigi dogrulanmiyordu.
# Artik: satir yazilamazsa kirmizi + RC 1. Cikti diskte durur (para zaten yanmistir),
# ama is BITMIS SAYILMAZ; operator satiri elle yazana kadar acik kalir.
bogaz_defter() { # $1=script-dizini $2=is_id $3=arac $4=model $5=sure_sn $6=tarif $7=birim $8=not
  local hata
  hata="$(bash "$1/defter.sh" ekle is_id="$2" arac="$3" model="$4" \
    sure_dk="$(python3 -c "print(max(1,round($5/60)))")" deneme_no=1 tarif_ref="$6" \
    maliyet_usd="$7" not="$8" 2>&1)" && return 0
  echo "[kirmizi] DEFTER SATIRI YAZILAMADI — harcama sayaca girmedi (anayasa §6)." >&2
  echo "          defter.sh dedi ki: ${hata:-(cikti yok)}" >&2
  echo "          Cikti diskte DURUYOR ama is BITMIS SAYILMAZ: satir elle yazilmali." >&2
  return 1
}
