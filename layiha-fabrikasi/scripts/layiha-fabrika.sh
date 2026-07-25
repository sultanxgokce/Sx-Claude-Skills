#!/usr/bin/env bash
# layiha-fabrika.sh — L24 kill-switch insan-yüzeyi (kapat/aç/durum) — ÇİFT MODLU (Sultan-kararı K2).
# (_agents/spec/layiha-fabrikasi-dagitim-DESIGN.md §5 FAZ-D2 · F2)
#
# NE: Sultan'ın layiha günlük-üretim-bandını TEK-komutla kapatıp-açabilmesi için insan-dostu kabuk.
#   Mekanik: bayrak-dosyasını yazar/siler/okur — asıl fail-closed KONTROLÜ
#   layiha-fabrika-guard.lib.sh'te (bu script YALNIZ bayrağı YÖNETİR; tek-otorite orada).
#
# İKİ MOD:
#   kapat --filo  (VARSAYILAN) → 10 odanın hepsi durur. Eski davranışın aynısı (geriye-uyum).
#   kapat --yerel             → YALNIZ bu oda durur; öteki odalar üretmeye devam eder.
#   Bayrak ortak mount'ta durduğu için her iki mod da MERKEZDEN görülebilir/yönetilebilir (K4).
#
# KAPSAM (guard-lib ile birebir — kanıt: layiha-fabrika.test.sh T2b/T2c, mucit-t1.test.sh G13-G15):
#   ✔ durur : mucit-t1.sh --profil layiha (layiha bandının zorunlu boğaz-noktası)
#   ✘ MUAF  : aday-havuzu CRUD (layiha-aday-havuzu.sh) · KAŞİF dış-taraması (kasif-havuz-ekle.sh)
#             · DİVAN fikir-hattı (mucit-t1.sh --profil divan = VARSAYILAN)
#   Bu muafiyet ekranda AÇIKÇA yazılır — "fabrikayı kapattım" ≠ "KAŞİF de durdu" (F2/B9).
#
# Kullanım:
#   layiha-fabrika.sh kapat [--filo|--yerel] [--sebep "..."]
#   layiha-fabrika.sh ac    [--filo|--yerel]
#   layiha-fabrika.sh durum
#
# Bayrak-yolu: LAYIHA_FABRIKA_BAYRAK env-override yoksa /config/.claude/layiha-fabrikasi.kapali
#   (guard-lib ile AYNI kaynak — tek-otorite, env-override testte kullanılır).
#
# Çıkış: 0 OK · 2 kullanım-hatası / güvenlik-kapısı.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Kardeş-göreli source: guard-lib ile birlikte taşınır (F3'te paket-içine taşınacak).
source "$HERE/layiha-fabrika-guard.lib.sh"

BAYRAK="$(_layiha_fabrika_bayrak)"
HOST="$(_layiha_fabrika_host)"
CMD="${1:-durum}"; shift || true

TAB="$(printf '\t')"

_jq_gerek() {
  if command -v jq >/dev/null 2>&1; then return 0; fi
  echo "HATA: bu komut jq gerektirir (bayrak JSON olarak yazılıyor); jq bulunamadı." >&2
  echo "      NOT: okuma-tarafı jq'suz da çalışır ve fail-closed davranır — üretim güvende." >&2
  exit 2
}

# Ortak mount'ta 10 container aynı bayrağı yazabilir → oku-değiştir-yaz kritik-bölümü serileştirilir.
# Kilit AYRI dosyada: bayrak `mv` ile atomik değiştirildiği için inode değişir; kilidi bayrağın
# kendisinde tutmak yarışı kapatmazdı.
_kilit() {
  local d
  d="$(dirname -- "$BAYRAK")"
  mkdir -p -- "$d" 2>/dev/null || true
  [ -w "$d" ] || return 0
  command -v flock >/dev/null 2>&1 || return 0
  exec 9>"$BAYRAK.lock" || return 0
  flock -w 10 9 2>/dev/null || true
}

# stdin'deki JSON'u bayrağa ATOMİK yaz (yarım-okunan bayrak = yanlış kapsam kararı).
_yaz() {
  local tmp d
  d="$(dirname -- "$BAYRAK")"
  tmp="$(mktemp "$d/.layiha-fabrikasi.XXXXXX")" || { echo "HATA: geçici dosya açılamadı ($d)" >&2; exit 2; }
  cat > "$tmp"
  mv -f -- "$tmp" "$BAYRAK"
}

# Mevcut durumu kilit altında oku → MEVCUT_KAPSAM / MEVCUT_SCOPE
MEVCUT_KAPSAM="yok"; MEVCUT_SCOPE=""
_durumu_oku() {
  local oku
  MEVCUT_KAPSAM="yok"; MEVCUT_SCOPE=""
  [ -e "$BAYRAK" ] || return 0
  if oku="$(_layiha_fabrika_oku "$BAYRAK")"; then
    MEVCUT_KAPSAM="${oku%%${TAB}*}"
    MEVCUT_SCOPE="${oku#*${TAB}}"
  else
    # eski-usul çıplak/boş bayrak · bozuk JSON · jq yok → guard ile AYNI yorum: tüm filo
    MEVCUT_KAPSAM="filo"
  fi
}

# B9: "fabrikayı kapattım" ile "her şey durdu" arasındaki farkı ekran AÇIKÇA söyler.
_kapsam_notu() {
  echo "kapsam-notu: Bu düğme YALNIZ layiha üretim-bandını (günlük yeni-aday üretimi) durdurur."
  echo "  ⚠️  KAŞİF'in dış-taraması DURMAZ — o ayrı bir program (DİVAN fikir-hattı) ve kendi kuralları var."
  echo "      KAŞİF'i de susturmak istiyorsan bu düğme yetmez; bunu ayrıca söylemen gerekir."
  echo "  ⚠️  Eldeki adaylara erişim de DURMAZ — liste/göster/terfi/durum her hâlde çalışır."
}

case "$CMD" in
  kapat)
    MOD="filo"; SEBEP=""; SEBEP_VERILDI=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --filo)  MOD="filo"; shift ;;
        --yerel) MOD="yerel"; shift ;;
        --sebep) SEBEP="${2:-}"; SEBEP_VERILDI=1; shift 2 ;;
        *) echo "HATA: bilinmeyen bayrak: $1 (--filo|--yerel|--sebep)" >&2; exit 2 ;;
      esac
    done
    _jq_gerek
    _kilit
    _durumu_oku
    TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    if [ "$MOD" = "yerel" ] && [ "$MEVCUT_KAPSAM" = "filo" ]; then
      echo "ℹ️  Şu an ZATEN TÜM FİLO kapalı — 'yalnız bu odayı kapat' bir şeyi değiştirmez."
      echo "    Önce hepsini açman gerekir:   layiha-fabrika.sh ac --filo"
      echo "    bayrak: $BAYRAK"
      exit 0
    fi

    if [ "$MOD" = "yerel" ]; then
      YENI_SCOPE="$MEVCUT_SCOPE"
      case ",$MEVCUT_SCOPE," in
        *",$HOST,"*) : ;;   # zaten kapalı — idempotent, mükerrer kayıt yazma
        *) YENI_SCOPE="${MEVCUT_SCOPE:+$MEVCUT_SCOPE,}$HOST" ;;
      esac
      # --sebep verilmediyse mevcut gerekçeyi koru (başka odanın gerekçesini silme).
      if [ "$SEBEP_VERILDI" -eq 0 ] && [ -e "$BAYRAK" ]; then
        SEBEP="$(jq -r '.sebep // ""' "$BAYRAK" 2>/dev/null || printf '')"
      fi
      jq -n --arg ts "$TS" --arg s "$SEBEP" --arg sc "$YENI_SCOPE" \
        '{ts:$ts, sebep:$s, kapsam:"yerel", scope:($sc|split(","))}' | _yaz
      echo "🔒 layiha-fabrikası KAPATILDI — YALNIZ bu oda ($HOST)."
      echo "   kapalı odalar: $YENI_SCOPE"
      echo "   öteki odalar layiha üretmeye DEVAM ediyor. Hepsini durdurmak için: kapat --filo"
    else
      jq -n --arg ts "$TS" --arg s "$SEBEP" --arg h "$HOST" \
        '{ts:$ts, sebep:$s, kapsam:"filo", scope:[$h]}' | _yaz
      echo "🔒 layiha-fabrikası KAPATILDI — TÜM FİLO (bütün odalar)."
      echo "   yalnız bu odayı durdurmak isteseydin: kapat --yerel"
    fi
    if [ -n "$SEBEP" ]; then echo "   sebep: $SEBEP"; fi
    echo "   bayrak: $BAYRAK"
    _kapsam_notu
    ;;

  ac)
    MOD=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --filo)  MOD="filo"; shift ;;
        --yerel) MOD="yerel"; shift ;;
        *) echo "HATA: bilinmeyen bayrak: $1 (--filo|--yerel)" >&2; exit 2 ;;
      esac
    done
    _kilit
    if [ ! -e "$BAYRAK" ]; then
      echo "ℹ️  layiha-fabrikası zaten açıktı (bayrak yoktu) — değişiklik yok."
      exit 0
    fi
    _durumu_oku

    if [ "$MEVCUT_KAPSAM" = "filo" ]; then
      # Tek-parça bayrak: filo-kapatmasında bir odayı ayrıca açmak mümkün DEĞİL.
      if [ "$MOD" = "yerel" ]; then
        echo "⚠️  Şu anki kapatma TÜM FİLO için geçerli — tek oda ayrıca açılamaz (bayrak tek parçadır)." >&2
        echo "    Hepsini açmak için:            layiha-fabrika.sh ac --filo" >&2
        echo "    Sonra tek tek kapatmak için:   ilgili odalarda  layiha-fabrika.sh kapat --yerel" >&2
        exit 2
      fi
      # Bayraksız `ac`: SİMETRİ — `kapat`ın varsayılanı da filo olduğu için `kapat`/`ac` çifti
      # bayraksız hâlde birbirinin TAM TERSİ olmalı; yoksa en sık round-trip sürtünmeye dönüşür.
      # AMA yalnız kapatmayı YAPAN oda için: başka odanın filo-kararını buradan sessizce geri
      # almak, "odamı açayım" derken 10 odayı açma kazasıdır → orada açık onay (--filo) istenir.
      if [ "$MOD" != "filo" ]; then
        case ",$MEVCUT_SCOPE," in
          *",$HOST,"*) : ;;   # kapatmayı bu oda koymuş → simetrik geri-alma serbest
          *)
            echo "⚠️  TÜM FİLO kapalı ve bu kapatmayı BAŞKA bir oda koymuş (${MEVCUT_SCOPE:-bilinmiyor})." >&2
            echo "    Buradan açmak 10 odayı birden açar — kaza olmasın diye açık onay istiyorum:" >&2
            echo "    Hepsini açmak için:   layiha-fabrika.sh ac --filo" >&2
            exit 2
            ;;
        esac
      fi
      rm -f -- "$BAYRAK"
      echo "🔓 layiha-fabrikası AÇILDI — TÜM FİLO (bütün odalar tekrar üretiyor)."
    else
      if [ "$MOD" = "filo" ]; then
        rm -f -- "$BAYRAK"
        echo "🔓 layiha-fabrikası AÇILDI — kapalı olan bütün odalar açıldı (${MEVCUT_SCOPE:-yok})."
      else
        case ",$MEVCUT_SCOPE," in
          *",$HOST,"*) : ;;
          *)
            echo "ℹ️  Bu oda ($HOST) zaten açıktı — kapatma başka odalar için (${MEVCUT_SCOPE:-yok})."
            exit 0
            ;;
        esac
        _jq_gerek
        KALAN="$(jq -r --arg h "$HOST" '((.scope // []) - [$h]) | join(",")' "$BAYRAK")"
        if [ -z "$KALAN" ]; then
          rm -f -- "$BAYRAK"
          echo "🔓 layiha-fabrikası AÇILDI — bu oda ($HOST) açıldı; başka kapalı oda kalmadı."
        else
          TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
          SEBEP="$(jq -r '.sebep // ""' "$BAYRAK" 2>/dev/null || printf '')"
          jq -n --arg ts "$TS" --arg s "$SEBEP" --arg sc "$KALAN" \
            '{ts:$ts, sebep:$s, kapsam:"yerel", scope:($sc|split(","))}' | _yaz
          echo "🔓 layiha-fabrikası AÇILDI — yalnız bu oda ($HOST)."
          echo "   hâlâ kapalı odalar: $KALAN"
        fi
      fi
    fi
    echo "   bayrak: $BAYRAK"
    ;;

  durum)
    _durumu_oku
    if _layiha_fabrika_bu_oda_kapali; then
      echo "🔒 DURUM — bu oda ($HOST): KAPALI (layiha üretimi durdu)"
    else
      echo "🔓 DURUM — bu oda ($HOST): AÇIK (layiha üretimi çalışıyor)"
    fi
    if [ -n "${LAYIHA_FABRIKA_NEDEN:-}" ]; then
      echo "   neden: $LAYIHA_FABRIKA_NEDEN"
    fi
    if [ -e "$BAYRAK" ]; then
      case "$MEVCUT_KAPSAM" in
        filo)  echo "   kapatma-kapsamı: TÜM FİLO (bütün odalar)" ;;
        yerel) echo "   kapatma-kapsamı: yalnız şu odalar → ${MEVCUT_SCOPE:-(boş)}" ;;
      esac
      SEBEP="$(_layiha_fabrika_sebep "$BAYRAK")"
      if [ -n "$SEBEP" ]; then
        echo "--- gerekçe/tarih ---"
        printf '%s\n' "$SEBEP"
      else
        echo "   (bayrak boş — gerekçe belirtilmemiş)"
      fi
    else
      echo "   kapatma-kapsamı: yok (hiçbir odada kapatma bulunmuyor)"
    fi
    echo "bayrak-yolu: $BAYRAK"
    _kapsam_notu
    ;;

  *)
    echo "HATA: bilinmeyen komut: $CMD (kapat|ac|durum)" >&2
    exit 2
    ;;
esac
