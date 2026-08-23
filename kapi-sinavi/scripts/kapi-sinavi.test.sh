#!/usr/bin/env bash
# kapi-sinavi.test.sh — HERMETİK sınav. Gerçek bir depoya, gerçek bir kapıya DOKUNMAZ:
# her vaka kendi geçici fikstür-projesini kurar.
#
# 🔴 Bu sınavın kendisi mutasyon-kanıtlıdır: aracın herhangi bir kapısını gevşetirsen
#    (ör. RC=3'ü 0'a yuvarlarsan, ya da 'çağıran yok' hükmünü kaldırırsan) aşağıdaki
#    vakalar KIRMIZIYA döner. Kapının sınavını yazarken kendi dersimizi uyguluyoruz.
set -uo pipefail

ARAC="$(cd "$(dirname "$0")" && pwd)/kapi-sinavi.sh"
GECEN=0; DUSEN=0

_ok(){ printf '  ✓ %s\n' "$1"; GECEN=$((GECEN+1)); }
_no(){ printf '  ✗ %s\n' "$1"; printf '      %s\n' "${2:-}"; DUSEN=$((DUSEN+1)); }
_bekle(){ # aciklama beklenen_rc gercek_rc
  if [[ "$2" == "$3" ]]; then _ok "$1"; else _no "$1" "beklenen rc=$2, gerçek rc=$3"; fi
}
_sil(){ [ -n "${1:-}" ] && [ -d "$1" ] && find "$1" -depth -delete 2>/dev/null; return 0; }

# ── Fikstür kurucu ───────────────────────────────────────────────────────────
# $1 = tür: tam | sinavsiz-kapi | cagrisiz | yanlis-giris | kirmizi | girissiz
_fikstur(){
  local tur="$1" p; p="$(mktemp -d)"
  mkdir -p "$p/.kapi"

  cat > "$p/kapi.py" <<'PY'
class Yasak(Exception): pass

def izin_var_mi(dugme):
    # Kapı: 'sil' geçen düğme YASAK. (Fikstür — gerçek muhafızın minyatürü.)
    if 'sil' in dugme:
        raise Yasak(dugme)
    return True
PY

  cat > "$p/giris.py" <<'PY'
from kapi import izin_var_mi

def calis(dugme):
    izin_var_mi(dugme)
    return 'yapildi'
PY

  cat > "$p/baska.py" <<'PY'
def ilgisiz():
    return 1
PY

  case "$tur" in
    tam|girissiz|yanlis-giris)
      # Sınav HEM birim HEM bütünleşme vakası taşır → üç mutasyonu da yakalar.
      cat > "$p/kapi.test.sh" <<'SH'
#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1
python3 - <<'PY' || exit 1
import kapi, giris
assert kapi.izin_var_mi('Kaydet') is True          # izin yolu
try:
    kapi.izin_var_mi('Secilenleri sil'); raise SystemExit(1)   # ret yolu
except kapi.Yasak: pass
try:
    giris.calis('Secilenleri sil'); raise SystemExit(1)        # BÜTÜNLEŞME: kapı devrede mi
except kapi.Yasak: pass
PY
SH
      ;;
    sinavsiz-kapi)
      # Sınav yalnız 'izin' yolunu ölçer → sil ve no-op yakalanır, yer-kaydırma YAKALANMAZ.
      cat > "$p/kapi.test.sh" <<'SH'
#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1
python3 -c "import kapi; assert kapi.izin_var_mi('Kaydet') is True" || exit 1
SH
      ;;
    anilan)
      # 🔴 GERÇEK VAKA (2026-08-23): kapı üretim dosyasında yalnız bir açıklama
      #    satırında ANILIYOR. Bu bir İDDİADIR, çağrı değil. Düz metin araması
      #    bunu "bağlı" sayıyordu — aracın yakalamak için yazıldığı kusurun ta kendisi.
      cat > "$p/giris.py" <<'PYF'
def calis(dugme):
    """Her tıklama `kapi.izin_var_mi` üzerinden geçmelidir."""
    # izin_var_mi(dugme)   <- eskiden buradaydı
    return 'yapildi'
PYF
      cat > "$p/kapi.test.sh" <<'SH'
#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1
python3 -c "import kapi; assert kapi.izin_var_mi('Kaydet') is True" || exit 1
SH
      ;;
    cagrisiz)
      # 🔴 Kapı VAR, sınavı VAR, ama onu çağıran üretim yolu YOK (gecenin ana vakası).
      cat > "$p/giris.py" <<'PY'
def calis(dugme):
    return 'yapildi'
PY
      cat > "$p/kapi.test.sh" <<'SH'
#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1
python3 -c "import kapi; assert kapi.izin_var_mi('Kaydet') is True" || exit 1
SH
      ;;
    kirmizi)
      cat > "$p/kapi.test.sh" <<'SH'
#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1
echo "bilerek kirmizi"; exit 1
SH
      ;;
  esac
  chmod +x "$p/kapi.test.sh"

  local girisler='["giris.py"]'
  [[ "$tur" == "girissiz"    ]] && girisler='[]'
  [[ "$tur" == "yanlis-giris" ]] && girisler='["baska.py"]'
  cat > "$p/.kapi/kapilar.json" <<JSON
{"v":1,"kapilar":[{"ad":"muhafiz","dosya":"kapi.py","cagri":"izin_var_mi",
 "sinav":"kapi.test.sh","girisler":$girisler,"mutasyon":"python"}]}
JSON
  printf '%s' "$p"
}

_kos(){ local p="$1"; shift; KAPI_SINAVI_KOK="$p" bash "$ARAC" "$@" >/dev/null 2>&1; printf '%s' $?; }

# ── 1 · kayit ────────────────────────────────────────────────────────────────
printf 'kayit — defter tutarlılığı\n'
P="$(_fikstur tam)"
_bekle "temiz defter → 0" 0 "$(_kos "$P" kayit)"

python3 - "$P/.kapi/kapilar.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d['kapilar'][0]['sinav']=''
json.dump(d,open(p,'w'))
PY
_bekle "sınavsız kapı → BULGU (sınavı olmayan kapı, kapı değildir)" 1 "$(_kos "$P" kayit)"

python3 - "$P/.kapi/kapilar.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p))
d['kapilar'][0]['sinav']='kapi.test.sh'
d['kapilar'].append(dict(d['kapilar'][0]))
json.dump(d,open(p,'w'))
PY
_bekle "çift ad → BULGU" 1 "$(_kos "$P" kayit)"

python3 - "$P/.kapi/kapilar.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d['kapilar']=d['kapilar'][:1]
d['kapilar'][0]['dosya']='olmayan.py'
json.dump(d,open(p,'w'))
PY
_bekle "var olmayan kapı dosyası → BULGU" 1 "$(_kos "$P" kayit)"

printf 'bozuk' > "$P/.kapi/kapilar.json"
_bekle "bozuk JSON → kullanım hatası (sessiz geçmez)" 2 "$(_kos "$P" kayit)"
_sil "$P"

P="$(mktemp -d)"
_bekle "defter yok → kullanım hatası" 2 "$(_kos "$P" kayit)"
_sil "$P"

# ── 2 · kos ──────────────────────────────────────────────────────────────────
printf 'kos — sınavı çıplak koş, damgala\n'
P="$(_fikstur tam)"
_bekle "yeşil sınav → 0" 0 "$(_kos "$P" kos)"
if [[ -f "$P/.kapi/durum.json" ]] && grep -q 'son_yesil' "$P/.kapi/durum.json"; then
  _ok "yeşil koşum damgası diske yazıldı"
else
  _no "yeşil koşum damgası diske yazıldı" "durum.json yok ya da damgasız"
fi
_sil "$P"

P="$(_fikstur kirmizi)"
_bekle "kırmızı sınav → BULGU" 1 "$(_kos "$P" kos)"
_sil "$P"

# ── 3 · bagli-mi — bu aracın varlık sebebi ───────────────────────────────────
printf 'bagli-mi — kapı fiilen çağrılıyor mu\n'
P="$(_fikstur tam)"
_bekle "kapı giriş noktasından çağrılıyor → 0" 0 "$(_kos "$P" bagli-mi)"
_sil "$P"

P="$(_fikstur cagrisiz)"
_bekle "🔴 ÇAĞIRAN YOK → BULGU ('yazılmış ama bağlanmamış')" 1 "$(_kos "$P" bagli-mi)"
_sil "$P"

P="$(_fikstur anilan)"
_bekle "🔴 yalnız YORUMDA anılıyor → ÇAĞIRAN YOK (anmak ≠ çağırmak)" 1 "$(_kos "$P" bagli-mi)"
_sil "$P"

P="$(_fikstur yanlis-giris)"
_bekle "çağrılıyor ama beyan edilen giriş noktasından değil → BULGU" 1 "$(_kos "$P" bagli-mi)"
_sil "$P"

P="$(_fikstur girissiz)"
_bekle "giriş noktası beyan edilmemiş → ÖLÇÜLEMEDİ (0 DEĞİL)" 3 "$(_kos "$P" bagli-mi)"
_sil "$P"

# ── 4 · bayat-mi ─────────────────────────────────────────────────────────────
printf 'bayat-mi — kapı son yeşilden sonra değişti mi\n'
P="$(_fikstur tam)"
_bekle "hiç yeşil koşum yok → ÖLÇÜLEMEDİ (0 DEĞİL)" 3 "$(_kos "$P" bayat-mi)"
_kos "$P" kos >/dev/null
_bekle "koşumdan hemen sonra → taze" 0 "$(_kos "$P" bayat-mi)"
printf '\n# kapı değişti\n' >> "$P/kapi.py"
_bekle "kapı değişti, yeniden koşulmadı → BAYAT" 1 "$(_kos "$P" bayat-mi)"
_sil "$P"

# ── 5 · mutasyon ─────────────────────────────────────────────────────────────
printf 'mutasyon — sil · no-op · yer-kaydırma\n'
P="$(_fikstur tam)"
ONCE="$(sha256sum "$P/kapi.py" | cut -d" " -f1)$(sha256sum "$P/giris.py" | cut -d" " -f1)"
_bekle "gerçek sınav üç mutasyonu da yakalar → 0" 0 "$(_kos "$P" mutasyon muhafiz)"
SONRA="$(sha256sum "$P/kapi.py" | cut -d" " -f1)$(sha256sum "$P/giris.py" | cut -d" " -f1)"
if [[ "$ONCE" == "$SONRA" ]]; then
  _ok "🔴 DEĞİŞMEZ 2 — mutasyon GERÇEK AĞACA dokunmadı (sha aynı)"
else
  _no "🔴 DEĞİŞMEZ 2 — mutasyon GERÇEK AĞACA dokunmadı" "dosyalar değişmiş!"
fi
_sil "$P"

P="$(_fikstur sinavsiz-kapi)"
_bekle "sınav bütünleşmeyi ölçmüyor → BULGU (yer-kaydırma yakalanmaz)" 1 "$(_kos "$P" mutasyon muhafiz)"
_sil "$P"

P="$(_fikstur kirmizi)"
_bekle "sınav zaten kırmızı → ÖLÇÜLEMEDİ (kırmızıdan kırmızıya geçiş kanıt değil)" 3 "$(_kos "$P" mutasyon muhafiz)"
_sil "$P"

P="$(_fikstur girissiz)"
_bekle "giriş yok → yer-kaydırma ölçülemez → ÖLÇÜLEMEDİ" 3 "$(_kos "$P" mutasyon muhafiz)"
_sil "$P"

# ── 6 · denetle — RC birleştirme kuralı ──────────────────────────────────────
printf 'denetle — tek RC, ölçülemeyen asla yeşile yuvarlanmaz\n'
P="$(_fikstur tam)"
_kos "$P" kos >/dev/null
_bekle "her şey temiz → 0" 0 "$(_kos "$P" denetle)"
_sil "$P"

P="$(_fikstur tam)"   # kos koşulmadı → bayat-mi ÖLÇÜLEMEDİ verir, kırmızı yok
R="$(KAPI_SINAVI_KOK="$P" bash "$ARAC" denetle 2>&1)"; RC=$?
_bekle "kırmızı yok ama ölçülemeyen var → 3" 3 "$RC"
if grep -q 'YEŞİL DEĞİLDİR' <<< "$R"; then
  _ok "ölçülemeyen durumda 'YEŞİL DEĞİLDİR' açıkça basılıyor"
else
  _no "ölçülemeyen durumda 'YEŞİL DEĞİLDİR' açıkça basılıyor" "uyarı metni yok"
fi
_sil "$P"

P="$(_fikstur cagrisiz)"
_bekle "bulgu varken → 1 (3'e düşmez)" 1 "$(_kos "$P" denetle)"
_sil "$P"

# ── 7 · kullanım ─────────────────────────────────────────────────────────────
printf 'kullanım\n'
P="$(_fikstur tam)"
_bekle "bilinmeyen komut → 2" 2 "$(_kos "$P" saklambac)"
_bekle "defterde olmayan kapı adı → 2" 2 "$(_kos "$P" kos yokboyle)"
_sil "$P"

printf '\ntoplam=%d geçen=%d düşen=%d\n' "$((GECEN+DUSEN))" "$GECEN" "$DUSEN"
[[ $DUSEN -eq 0 ]]
