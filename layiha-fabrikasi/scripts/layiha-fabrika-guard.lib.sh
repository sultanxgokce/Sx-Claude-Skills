#!/usr/bin/env bash
# layiha-fabrika-guard.lib.sh — L24 kill-switch okuma-tarafı (fail-closed, ÜRETİM-yolları-ONLY).
# (_agents/spec/layiha-fabrikasi-dagitim-DESIGN.md §5 FAZ-D2 · F2: kapsam'lı bayrak)
#
# NE: Sultan'ın "hata bulunursa fabrikayı kapatabilmeliyim" şartını karşılar. F2'den itibaren
#   kapatma İKİ MODLU (Sultan-kararı K2): "hepsini kapat" (filo) ve "şu odayı kapat" (yerel).
#
# BAYRAK: LAYIHA_FABRIKA_BAYRAK env-override yoksa /config/.claude/layiha-fabrikasi.kapali
#   (paylaşılan _global bind-mount — 10/10 container AYNI dosyayı görür; kapatma MERKEZDEN
#   yönetilebilsin diye bilinçle ortak). İçerik JSON:
#       {"ts":"…Z","sebep":"…","kapsam":"filo"|"yerel","scope":["<hostname>",…]}
#     · kapsam=filo  → TÜM odalar kapalı (scope yalnız "kim kapattı" bilgisidir)
#     · kapsam=yerel → YALNIZ scope[] içindeki hostname'ler kapalı; ötekiler üretmeye devam eder
#
#   ⚠️ İ1-NOTU: bu dosya ortak mount'ta durur ama KİRACI-VERİSİ TAŞIMAZ — yalnız hostname listesi
#      + Sultan'ın yazdığı gerekçe. Layiha/bulgu verisi ASLA buraya yazılmaz (K1; hat-yolu.lib.sh).
#
# GERİYE-UYUM: JSON olmayan (eski-usul çıplak/boş) bayrak = kapsam:"filo" sayılır — yani eskiden
#   yazılmış her bayrak eskisi gibi TÜM filoyu kapatmaya devam eder. Sessiz-gevşeme YOK.
#
# FAIL-CLOSED (üç yüzü de kapalı tarafa düşer):
#   · bayrak-dizini okunamıyor             → KAPALI
#   · bayrak var ama okunamıyor/bozuk-JSON → KAPALI (filo)
#   · jq yok (kapsam okunamaz)             → KAPALI (filo)
#   Gerekçe: "kapatma emri var ama anlayamadım" durumunda üretmek, düğmenin varlık-sebebini siler.
#
# KAPSAM (DAR, bilinçli) — bayrak YALNIZ layiha-fabrikası bandını durdurur:
#   ✔ GUARD'LI : `mucit-t1.sh --profil layiha` (layiha aday-üretiminin zorunlu boğaz-noktası).
#                Bundan sonra eklenecek her layiha-üretim yüzeyi de bu guard'ı çağırmalıdır.
#   ✘ MUAF (1) : CRUD — `layiha-aday-havuzu.sh` (liste/goster/terfi/durum). Fabrika bozuksa bile
#                Sultan eldeki adaylarına erişebilmeli; kapatma-düğmesi onu kilitleyemez.
#   ✘ MUAF (2) : KAŞİF dış-taraması (`kasif-havuz-ekle.sh`) ve DİVAN fikir-hattı
#                (`mucit-t1.sh --profil divan` = VARSAYILAN). DİVAN kendi anayasası (§8) olan
#                AYRI bir programdır; "layiha-fabrikasını kapat" onu susturma yetkisi VERMEZ.
#                → Bu muafiyet insan-yüzeyinde de AÇIKÇA yazılır (layiha-fabrika.sh; F2/B9).
#   Bu ayrım kanıtlıdır: `scripts/mucit-t1.test.sh` G13-G15 · `scripts/layiha-fabrika.test.sh` T2b/T2c.
#
# DEĞER-GÜVENLİK: sır içermez/okumaz; salt dosya-varlık + kapsam/scope/gerekçe alanları.
#
# SIDE-EFFECT-FREE: bu dosya YALNIZ fonksiyon tanımlar (source edildiğinde hiçbir şey çalıştırmaz).
#   `set -euo pipefail` altındaki üretim-script'lerine source edilir → her dal açıkça korunmuştur.

# Bayrak yolu (tek-otorite; insan-yüzeyi de bunu kullanır).
_layiha_fabrika_bayrak() {
  printf '%s' "${LAYIHA_FABRIKA_BAYRAK:-/config/.claude/layiha-fabrikasi.kapali}"
}

# Bu odanın kimliği. LAYIHA_FABRIKA_HOST yalnız TEST-dikişidir (üretimde ayarlanmaz).
_layiha_fabrika_host() {
  if [ -n "${LAYIHA_FABRIKA_HOST:-}" ]; then printf '%s' "$LAYIHA_FABRIKA_HOST"; return 0; fi
  hostname 2>/dev/null || printf 'bilinmeyen-oda'
}

# Bayrağı ayrıştır → stdout: "<kapsam>\t<scope-virgüllü>"
#   RC 0 = geçerli JSON kapsam okundu · RC 1 = okunamadı (çağıran GERİYE-UYUM/fail-closed uygular)
_layiha_fabrika_oku() {
  local bayrak="${1:-}" kapsam scope
  [ -n "$bayrak" ] && [ -r "$bayrak" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  # NOT: `local x="$(...)"` çıkış-kodunu YUTAR — bildirim ve atama bilinçli olarak ayrı.
  kapsam="$(jq -r 'if type=="object" then (.kapsam // "") else "" end' "$bayrak" 2>/dev/null)" || return 1
  case "$kapsam" in
    filo|yerel) ;;
    *) return 1 ;;
  esac
  scope="$(jq -r 'if type=="object" then ((.scope // []) | map(tostring) | join(",")) else "" end' "$bayrak" 2>/dev/null)" || return 1
  printf '%s\t%s' "$kapsam" "$scope"
}

# Gerekçe/tarih metnini insan-okunur tek blok olarak bas (JSON ya da eski-usul ham).
_layiha_fabrika_sebep() {
  local bayrak="${1:-}" s t out
  [ -n "$bayrak" ] && [ -r "$bayrak" ] || return 0
  if command -v jq >/dev/null 2>&1 && jq -e 'type=="object"' "$bayrak" >/dev/null 2>&1; then
    s="$(jq -r '.sebep // ""' "$bayrak" 2>/dev/null || printf '')"
    t="$(jq -r '.ts // ""' "$bayrak" 2>/dev/null || printf '')"
    out=""
    if [ -n "$s" ]; then out="$s"; fi
    if [ -n "$t" ]; then
      if [ -n "$out" ]; then
        out="$out
tarih: $t"
      else
        out="tarih: $t"
      fi
    fi
    printf '%s' "$out"
  else
    head -c 2000 -- "$bayrak" 2>/dev/null | tr -d '\000' || true
  fi
}

# BU ODA kapalı mı?  RC 0 = KAPALI · RC 1 = açık.
# Yan-kanal (çağıranın raporlaması için, her çağrıda sıfırlanır):
#   LAYIHA_FABRIKA_KAPSAM = filo|yerel|yok   ·   LAYIHA_FABRIKA_NEDEN = tek-satır insan-açıklaması
_layiha_fabrika_bu_oda_kapali() {
  local bayrak dizin oku kapsam scope host
  LAYIHA_FABRIKA_KAPSAM="yok"
  LAYIHA_FABRIKA_NEDEN=""

  bayrak="$(_layiha_fabrika_bayrak)"
  dizin="$(dirname -- "$bayrak")"

  # fail-closed: bayrak-dizini kendisi okunamıyorsa duruma güvenilemez → üretme.
  if [ ! -d "$dizin" ] || [ ! -r "$dizin" ]; then
    LAYIHA_FABRIKA_KAPSAM="filo"
    LAYIHA_FABRIKA_NEDEN="fail-closed: bayrak-dizini okunamıyor ($dizin)"
    return 0
  fi

  if [ ! -e "$bayrak" ]; then
    return 1
  fi

  if ! oku="$(_layiha_fabrika_oku "$bayrak")"; then
    # eski-usul çıplak/boş bayrak · bozuk JSON · jq yok → hepsi TÜM-FİLO sayılır (geriye-uyum + fail-closed)
    LAYIHA_FABRIKA_KAPSAM="filo"
    LAYIHA_FABRIKA_NEDEN="kapsam okunamadı → tüm-filo varsayıldı (geriye-uyum/fail-closed)"
    return 0
  fi

  kapsam="${oku%%	*}"
  scope="${oku#*	}"
  LAYIHA_FABRIKA_KAPSAM="$kapsam"

  if [ "$kapsam" = "filo" ]; then
    LAYIHA_FABRIKA_NEDEN="kapsam=filo — tüm odalar kapalı"
    return 0
  fi

  host="$(_layiha_fabrika_host)"
  case ",$scope," in
    *",$host,"*)
      LAYIHA_FABRIKA_NEDEN="kapsam=yerel — bu oda ($host) kapatılmış odalar arasında"
      return 0
      ;;
  esac
  LAYIHA_FABRIKA_NEDEN="kapsam=yerel — bu oda ($host) kapatılmış odalar arasında DEĞİL"
  return 1
}

# layiha_fabrika_guard <caller-ad>
#   dönüş: 0 = açık (üretime devam) · 1 = kapalı (üretim ATLANMALI — çağıran `|| exit 0` ile atlar)
layiha_fabrika_guard() {
  local caller="${1:-layiha-fabrikasi}" bayrak sebep
  if ! _layiha_fabrika_bu_oda_kapali; then
    return 0
  fi
  bayrak="$(_layiha_fabrika_bayrak)"
  echo "🔒 layiha-fabrikası KAPALI — $caller üretim-adımı atlandı (aday-havuzu/CRUD ve KAŞİF taraması ETKİLENMEZ)." >&2
  if [ -n "${LAYIHA_FABRIKA_NEDEN:-}" ]; then
    printf '   %s\n' "$LAYIHA_FABRIKA_NEDEN" >&2
  fi
  sebep="$(_layiha_fabrika_sebep "$bayrak")"
  if [ -n "$sebep" ]; then
    printf '   sebep/tarih: %s\n' "$sebep" | head -5 >&2
  else
    echo "   (bayrak boş/okunamaz — gerekçe belirtilmemiş)" >&2
  fi
  return 1
}
