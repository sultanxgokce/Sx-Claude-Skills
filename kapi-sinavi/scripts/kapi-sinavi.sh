#!/usr/bin/env bash
# kapi-sinavi.sh — bir KAPININ gerçekten kapı olduğunu kanıtlayan sınav kabuğu.
#
# NİÇİN VAR (2026-08-23, e-Logo derin kazısı · iki kol bağımsız aynı sonuca vardı)
# ────────────────────────────────────────────────────────────────────────────
# Bir gecede aynı hastalığın DÖRT vakası ölçüldü ve dördü de "yeşil" görünüyordu:
#
#   1) Tıklama muhafızı yazıldı, 14/14 sınavını geçti — ve onu çağıran TEK BİR SATIR YOKTU.
#   2) İkinci bir koruma fonksiyonu hiçbir yerden çağrılmıyordu; beceri metni onu kanon
#      gösteriyordu.
#   3) Muhafızın izin listesi DARALTILDI, sınavı güncellenmedi → sınav kırmızıya döndü ve
#      kimse görmedi (13/14). Kırmızı sınav, hiç sınav olmamasından farksızdır.
#   4) Muhafız alt-dizge eşleştiriyordu: tehlikeli bir düğme, adının içine gömülü bir izin
#      belirtecine takılıp İZİN alıyordu. 14 sınav vakasının HİÇBİRİ yakın-kaçış değildi.
#
# Ortak kök: **kapının VARLIĞI, etkinliğinin kanıtı sayıldı.** Sınavlar "kapı doğru karar
# veriyor mu"yu ölçüyordu; hiçbiri "kapı devrede mi" ve "bu sınav gerçekten bu kapıyı mı
# ölçüyor" sorusunu sormuyordu.
#
# 🔴 DEĞİŞMEZ 1 — RC=3 ÖLÇÜLEMEDİ demektir, YEŞİL DEĞİL.
#    Ölçemediğimiz kapı "temiz" sayılmaz. Filonun kendi kanonu burada da geçerlidir.
#
# 🔴 DEĞİŞMEZ 2 — mutasyon GERÇEK AĞACA DOKUNMAZ.
#    Her mutasyon projenin geçici bir KOPYASINDA koşar. Bu bir güvenlik aracıdır; kendi
#    koşumunda risk üretemez.
#
# 🔴 DEĞİŞMEZ 3 — bu araç kapı YAZMAZ, kapı ONAYLAMAZ. Yalnız ölçer ve bulgu basar.
#
# Kullanım:
#   kapi-sinavi.sh kayit                 defteri doğrula (dosyalar var mı, alanlar tam mı)
#   kapi-sinavi.sh kos      [ad]         kapının sınavını koş; yeşilse damgayı kaydet
#   kapi-sinavi.sh bagli-mi [ad]         kapı fiilen ÇAĞRILIYOR mu (üretim yolundan)
#   kapi-sinavi.sh bayat-mi [ad]         kapı son yeşil koşumdan sonra değişti mi
#   kapi-sinavi.sh mutasyon <ad>         sil · no-op · yer-kaydırma — üçü de KIRMIZI yakmalı
#   kapi-sinavi.sh denetle  [--mutasyon] hepsi, tek RC
#
# Defter: <kök>/.kapi/kapilar.json · Durum: <kök>/.kapi/durum.json
# Çıkış: 0 temiz · 1 BULGU · 2 kullanım/ortam · 3 ÖLÇÜLEMEDİ
set -uo pipefail

KOK="${KAPI_SINAVI_KOK:-$(pwd)}"
DEFTER="$KOK/.kapi/kapilar.json"
DURUM="$KOK/.kapi/durum.json"

RC_TEMIZ=0; RC_BULGU=1; RC_KULLANIM=2; RC_OLCULEMEDI=3

_hata(){ printf '%s\n' "$*" >&2; }
_bulgu(){ printf '🔴 %s\n' "$*"; }
_olcemedim(){ printf '⚠️  ÖLÇÜLEMEDİ · %s\n' "$*"; }
_iyi(){ printf '✓ %s\n' "$*"; }
# Geçici dizini sil. Silme fiili `find -delete` ile yapılır: yol DEĞİŞMEZ 2'nin
# gereği olarak daima mktemp'ten gelir, ve bu dosyanın konusu tam olarak
# "tehlikeli fiil alt-dizge ile tanınmaz" olduğu için burada da desen bırakılmaz.
_temizle(){ [ -n "${1:-}" ] && [ -d "$1" ] && find "$1" -depth -delete 2>/dev/null; return 0; }
_dosya_sil(){ [ -n "${1:-}" ] && [ -f "$1" ] && find "$1" -maxdepth 0 -delete 2>/dev/null; return 0; }

# 🔴 BAYT-KODU ÖNBELLEĞİ (MUHASİP ölçtü 2026-08-23, merkez doğruladı)
#    Mutasyon koşumlarında yanlış KIRMIZI görülebiliyor: mutasyonlu `.pyc` diskte kalıyor
#    ve geri alınan kaynağın mtime'ı aynı saniyeye düşerse Python yeniden derlemiyor.
#    Bizim `mutasyon` altkomutumuz bu tuzağa DÜŞMÜYOR çünkü kopya `__pycache__`'i dışlıyor —
#    ama o dışlama TEK korumaydı ve tesadüfiydi. Ayrıca ölçüldü: `kos`, sınavı gerçek ağaçta
#    koştuğu için kullanıcının deposuna `__pycache__` bırakıyordu (ölçüm-aracı ölçtüğü şeyi
#    kirletmemeli). Her iki yüz de tek satırla kapandı: bayt-kodu HİÇ yazılmıyor.
_sinav_kos(){ # <calisma-dizini> <sinav-yolu>
  ( cd "$1" && PYTHONDONTWRITEBYTECODE=1 bash "$2" )
}

command -v jq >/dev/null 2>&1 || { _hata "HATA: jq gerekli"; exit "$RC_KULLANIM"; }

_defter_var(){
  [[ -f "$DEFTER" ]] || { _hata "HATA: kapı defteri yok: $DEFTER"; _hata "  → önce .kapi/kapilar.json yaz (şema: SKILL.md)"; exit "$RC_KULLANIM"; }
  jq -e . "$DEFTER" >/dev/null 2>&1 || { _hata "HATA: $DEFTER geçerli JSON değil"; exit "$RC_KULLANIM"; }
}

_adlar(){
  local istenen="${1:-}"
  if [[ -n "$istenen" ]]; then
    local v; v="$(jq -r --arg a "$istenen" '.kapilar[] | select(.ad==$a) | .ad' "$DEFTER")"
    [[ -n "$v" ]] || { _hata "HATA: defterde '$istenen' adlı kapı yok"; exit "$RC_KULLANIM"; }
    printf '%s\n' "$v"
  else
    jq -r '.kapilar[].ad' "$DEFTER"
  fi
}
# 🔴 TUZAK (bu aracın kendi sınavı yakaladı, 2026-08-23):
#    `_adlar` bir süreç-ikamesinin `< <(...)` içinde koşar; oradaki `exit` yalnız ALT
#    KABUĞU sonlandırır, ana kabuk hiç etkilenmez. Sonuç: olmayan bir kapı adı verilince
#    döngü sıfır kez dönüyor ve araç sessizce 0 (TEMİZ) dönüyordu — kendi fail-open'ımız.
#    Bu yüzden ad doğrulaması ANA KABUKTA, döngüden ÖNCE yapılır.
_ad_dogrula(){
  [[ -z "${1:-}" ]] && return 0
  jq -e --arg a "$1" '.kapilar[] | select(.ad==$a)' "$DEFTER" >/dev/null 2>&1 \
    || { _hata "HATA: defterde '$1' adlı kapı yok"; exit "$RC_KULLANIM"; }
}
_alan(){ jq -r --arg a "$1" --arg k "$2" '.kapilar[] | select(.ad==$a) | .[$k] // ""' "$DEFTER"; }
_dizi(){ jq -r --arg a "$1" --arg k "$2" '.kapilar[] | select(.ad==$a) | (.[$k] // [])[]' "$DEFTER"; }
_sha(){ sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }

_durum_yaz(){
  mkdir -p "$(dirname "$DURUM")"
  [[ -f "$DURUM" ]] || printf '{}' > "$DURUM"
  local tmp; tmp="$(mktemp)"
  jq --arg a "$1" --arg s "$2" --arg t "$(date -u +%FT%TZ)" \
     '.[$a] = {son_yesil: $t, sha: $s}' "$DURUM" > "$tmp" && mv "$tmp" "$DURUM"
}
_durum_oku(){ [[ -f "$DURUM" ]] && jq -r --arg a "$1" --arg k "$2" '.[$a][$k] // ""' "$DURUM" 2>/dev/null || printf ''; }

# ── kayit ────────────────────────────────────────────────────────────────────
_kayit(){
  _defter_var
  _ad_dogrula "${1:-}"
  local bulgu=0 n=0
  # Ad tekilliği: aynı ad iki kez = hangi kapıyı ölçtüğün belirsiz demektir.
  local cift; cift="$(jq -r '.kapilar[].ad' "$DEFTER" | sort | uniq -d)"
  [[ -z "$cift" ]] || { _bulgu "defterde çift ad: $cift"; bulgu=1; }
  while IFS= read -r ad; do
    [[ -n "$ad" ]] || continue
    n=$((n+1))
    local d s
    d="$(_alan "$ad" dosya)"; s="$(_alan "$ad" sinav)"
    [[ -n "$d" ]] || { _bulgu "$ad: 'dosya' alanı boş"; bulgu=1; }
    [[ -n "$s" ]] || { _bulgu "$ad: 'sinav' alanı boş — sınavı olmayan kapı, kapı değildir"; bulgu=1; }
    [[ -z "$d" || -f "$KOK/$d" ]] || { _bulgu "$ad: dosya yok → $d"; bulgu=1; }
    [[ -z "$s" || -f "$KOK/$s" ]] || { _bulgu "$ad: sınav dosyası yok → $s"; bulgu=1; }
    [[ -n "$(_alan "$ad" cagri)" ]] || { _bulgu "$ad: 'cagri' alanı boş — neyin çağrıldığını bilmeden bağlılık ölçülemez"; bulgu=1; }
  done < <(_adlar "${1:-}")
  [[ $n -gt 0 ]] || { _bulgu "defterde hiç kapı yok"; return "$RC_BULGU"; }
  [[ $bulgu -eq 0 ]] && { _iyi "defter tutarlı ($n kapı)"; return "$RC_TEMIZ"; }
  return "$RC_BULGU"
}

# ── kos ──────────────────────────────────────────────────────────────────────
_kos(){
  _defter_var
  _ad_dogrula "${1:-}"
  local bulgu=0
  while IFS= read -r ad; do
    [[ -n "$ad" ]] || continue
    local s d; s="$(_alan "$ad" sinav)"; d="$(_alan "$ad" dosya)"
    if [[ -z "$s" || ! -f "$KOK/$s" ]]; then
      _olcemedim "$ad: sınav dosyası yok"; [[ $bulgu -eq 1 ]] || bulgu=3; continue
    fi
    # Çıplak koşum: çıkış kodu bir pipe'ın arkasına GİZLENMEZ.
    local kutuk; kutuk="$(mktemp)"
    _sinav_kos "$KOK" "$s" >"$kutuk" 2>&1
    local rc=$?
    if [[ $rc -eq 0 ]]; then
      _iyi "$ad: sınav yeşil (exit=0)"
      [[ -n "$d" && -f "$KOK/$d" ]] && _durum_yaz "$ad" "$(_sha "$KOK/$d")"
    else
      _bulgu "$ad: sınav KIRMIZI (exit=$rc)"
      tail -5 "$kutuk" | sed 's/^/     /'
      bulgu=1
    fi
    _dosya_sil "$kutuk"
  done < <(_adlar "${1:-}")
  return "${bulgu:-0}"
}

# 🔴 ANMAK ≠ ÇAĞIRMAK (bu aracın GERÇEK VERİ regresyonu yakaladı, 2026-08-23)
#    İlk sürüm düz metin araması yapıyordu. Gerçek beceriye koşulduğunda `guvenli_tikla`
#    için "bağlı (1 çağıran)" dedi — oysa o ad üretim dosyasında YALNIZCA bir açıklama
#    satırında geçiyordu: "Her tıklama `muhafiz.guvenli_tikla` üzerinden geçmelidir."
#    Yani araç, yakalamak için yazıldığı kusurun ta kendisini kaçırdı: bir İDDİAYI
#    kanıt saydı. Bu, ölçtüğü hastalığın aracın kendisinde nüksetmesiydi.
#
#    Artık .py dosyaları AST ile ayrıştırılır (yorum/dizge/dokümantasyon SAYILMAZ, yalnız
#    gerçek Call düğümleri sayılır). Diğer diller için satır-temelli yaklaşım kullanılır ve
#    yorum satırları elenir — yaklaşıklığı SKILL.md'de açıkça yazılıdır.
_cagri_yerleri(){
  local cagri="$1" tanim="$2"
  ( cd "$KOK" && grep -rl --include='*.py' --include='*.sh' --include='*.js' --include='*.ts' \
      -e "$cagri" . 2>/dev/null \
      | sed 's|^\./||' \
      | grep -v -e '\.test\.' -e '_test\.' -e '/tests\?/' -e '^\.kapi/' \
      | grep -vx -e "$tanim" || true ) \
  | while IFS= read -r f; do
      [[ -n "$f" ]] || continue
      if KAPI_F="$KOK/$f" KAPI_AD="$cagri" python3 - <<'PY'
import ast, os, re, sys
yol=os.environ['KAPI_F']; ad=os.environ['KAPI_AD']
try:
    kaynak=open(yol, encoding='utf-8', errors='replace').read()
except OSError:
    sys.exit(1)
if yol.endswith('.py'):
    try:
        agac=ast.parse(kaynak)
    except SyntaxError:
        sys.exit(1)          # ayrıştıramadığımızı "çağırıyor" saymayız
    for d in ast.walk(agac):
        if not isinstance(d, ast.Call):
            continue
        f=d.func
        if isinstance(f, ast.Name) and f.id==ad: sys.exit(0)
        if isinstance(f, ast.Attribute) and f.attr==ad: sys.exit(0)
    sys.exit(1)
# .sh/.js/.ts — satır temelli; yorum satırları elenir (yaklaşık, SKILL.md'de yazılı)
desen=re.compile(rf'(^|[^\w.]){re.escape(ad)}\s*(\(|$|\s)')
for satir in kaynak.split('\n'):
    s=satir.strip()
    if not s or s.startswith('#') or s.startswith('//') or s.startswith('*'):
        continue
    if desen.search(satir): sys.exit(0)
sys.exit(1)
PY
      then printf '%s\n' "$f"
      fi
    done
}

# ── bagli-mi ─────────────────────────────────────────────────────────────────
# Bu gecenin dersinin doğrudan karşılığı: kapı VAR ama ÇAĞRILMIYOR.
# ⚠️ SINIR (dürüstçe): statik metin taramasıdır. "Çağıran yok" hükmü KESİNDİR
#    (0 eşleşme çürütülemez); "bağlı" hükmü YAKLAŞIKTIR — çağıran satır ölü bir
#    kolda olabilir. Bu yüzden 'girisler' beyanı yoksa sonuç YEŞİL değil ÖLÇÜLEMEDİ olur.
_bagli_mi(){
  _defter_var
  _ad_dogrula "${1:-}"
  local bulgu=0
  while IFS= read -r ad; do
    [[ -n "$ad" ]] || continue
    local cagri dosya; cagri="$(_alan "$ad" cagri)"; dosya="$(_alan "$ad" dosya)"
    if [[ -z "$cagri" ]]; then _olcemedim "$ad: 'cagri' yok"; [[ $bulgu -eq 1 ]] || bulgu=3; continue; fi

    # Tanım dosyasının KENDİSİ ve sınav dosyaları çağrı sayılmaz —
    # kapıyı yalnız kendi sınavı çağırıyorsa o kapı üretimde YOKTUR.
    local yerler; yerler="$(_cagri_yerleri "$cagri" "$dosya")"
    local sayi; sayi="$(printf '%s' "$yerler" | grep -c . || true)"

    if [[ "$sayi" -eq 0 ]]; then
      _bulgu "$ad: ÇAĞIRAN YOK — '$cagri' yalnız kendi dosyasında/sınavında geçiyor"
      _hata  "     → 'yazılmış ama bağlanmamış' vakası. Bu kapı için kapı sayısı SIFIRDIR."
      bulgu=1; continue
    fi

    local girisler; girisler="$(_dizi "$ad" girisler)"
    if [[ -z "$girisler" ]]; then
      _olcemedim "$ad: 'girisler' beyan edilmemiş — yalnız çağrı VARLIĞI ölçüldü ($sayi yer)"
      [[ $bulgu -eq 1 ]] || bulgu=3; continue
    fi
    local eslesen=0
    while IFS= read -r g; do
      [[ -n "$g" ]] || continue
      printf '%s\n' "$yerler" | grep -qx -e "$g" && eslesen=1
    done <<< "$girisler"
    if [[ $eslesen -eq 0 ]]; then
      _bulgu "$ad: çağrılıyor ama beyan edilen giriş noktalarının HİÇBİRİNDEN değil"
      _hata  "     çağıranlar: $(printf '%s' "$yerler" | tr '\n' ' ')"
      _hata  "     → kapı ölü bir koldan çağrılıyor olabilir."
      bulgu=1; continue
    fi
    _iyi "$ad: bağlı ($sayi çağıran, giriş noktası doğrulandı)"
  done < <(_adlar "${1:-}")
  return "${bulgu:-0}"
}

# ── bayat-mi ─────────────────────────────────────────────────────────────────
_bayat_mi(){
  _defter_var
  _ad_dogrula "${1:-}"
  local bulgu=0
  while IFS= read -r ad; do
    [[ -n "$ad" ]] || continue
    local d; d="$(_alan "$ad" dosya)"
    if [[ -z "$d" || ! -f "$KOK/$d" ]]; then _olcemedim "$ad: kapı dosyası yok"; [[ $bulgu -eq 1 ]] || bulgu=3; continue; fi
    local kayitli; kayitli="$(_durum_oku "$ad" sha)"
    if [[ -z "$kayitli" ]]; then
      # 🔴 Kayıt yoksa "temiz" DEĞİL, ÖLÇÜLEMEDİ. Bu ayrım bu aracın varlık sebebidir.
      _olcemedim "$ad: hiç yeşil koşum kaydı yok → 'kos' çalıştır"
      [[ $bulgu -eq 1 ]] || bulgu=3; continue
    fi
    if [[ "$kayitli" != "$(_sha "$KOK/$d")" ]]; then
      _bulgu "$ad: BAYAT — kapı son yeşil koşumdan sonra değişti (son yeşil: $(_durum_oku "$ad" son_yesil))"
      bulgu=1
    else
      _iyi "$ad: taze (son yeşil: $(_durum_oku "$ad" son_yesil))"
    fi
  done < <(_adlar "${1:-}")
  return "${bulgu:-0}"
}

# ── mutasyon ─────────────────────────────────────────────────────────────────
# Üç sınıf:
#   sil          — kapı yok edilir. Sınav yeşil kalırsa: sınav kapıya HİÇ dokunmuyor.
#   no-op        — kapı hep izin verir. Sınav yeşil kalırsa: yalnız 'izin' yolu sınanıyor.
#   yer-kaydirma — kapı durur ama ÇAĞRI kaldırılır. Sınav yeşil kalırsa: BAĞLANTI sınavı yok.
# Üçü de projenin GEÇİCİ KOPYASINDA koşar (Değişmez 2).
_mutasyon(){
  local ad="${1:-}"
  [[ -n "$ad" ]] || { _hata "kullanım: mutasyon <ad>"; exit "$RC_KULLANIM"; }
  _defter_var; _adlar "$ad" >/dev/null

  local dosya sinav cagri tur
  dosya="$(_alan "$ad" dosya)"; sinav="$(_alan "$ad" sinav)"
  cagri="$(_alan "$ad" cagri)"; tur="$(_alan "$ad" mutasyon)"
  [[ -n "$sinav" && -f "$KOK/$sinav" ]] || { _olcemedim "$ad: sınav yok → mutasyon ölçülemez"; return "$RC_OLCULEMEDI"; }
  case "${tur:-python}" in
    python) ;;
    *) _olcemedim "$ad: mutasyon türü '$tur' desteklenmiyor (yalnız python)"; return "$RC_OLCULEMEDI" ;;
  esac

  # Ön koşul: mutasyonsuz hâl YEŞİL olmalı. Kırmızıdan kırmızıya geçiş hiçbir şey kanıtlamaz.
  if ! _sinav_kos "$KOK" "$sinav" >/dev/null 2>&1; then
    _olcemedim "$ad: sınav mutasyonsuz hâlde ZATEN KIRMIZI → mutasyon anlamsız (önce onar)"
    return "$RC_OLCULEMEDI"
  fi

  local bulgu=0
  for m in sil no-op yer-kaydirma; do
    local tmp; tmp="$(mktemp -d)"
    ( cd "$KOK" && tar -c --exclude=.git --exclude=__pycache__ --exclude=node_modules . ) | ( cd "$tmp" && tar -x )
    local uygulandi=1
    case "$m" in
      sil)
        python3 - "$tmp/$dosya" "$cagri" <<'PY' || uygulandi=0
import re,sys
p,f=sys.argv[1],sys.argv[2]
s=open(p,encoding='utf-8').read()
yeni,n=re.subn(rf'\bdef\s+{re.escape(f)}\s*\(', f'def {f}__SILINDI(', s, count=1)
if n==0: sys.exit(1)
open(p,'w',encoding='utf-8').write(yeni)
PY
        ;;
      no-op)
        python3 - "$tmp/$dosya" "$cagri" <<'PY' || uygulandi=0
import re,sys
p,f=sys.argv[1],sys.argv[2]
lines=open(p,encoding='utf-8').read().split('\n')
pat=re.compile(rf'^(\s*)def\s+{re.escape(f)}\s*\(')
for i,l in enumerate(lines):
    m=pat.match(l)
    if not m: continue
    j=i  # imza birden çok satıra yayılabilir: ':' ile biten ilk satırı bul
    while j<len(lines) and not lines[j].rstrip().endswith(':'): j+=1
    if j>=len(lines): sys.exit(1)
    lines.insert(j+1, m.group(1)+'    return True  # MUTASYON:no-op')
    open(p,'w',encoding='utf-8').write('\n'.join(lines)); sys.exit(0)
sys.exit(1)
PY
        ;;
      yer-kaydirma)
        local hedefler; hedefler="$(_dizi "$ad" girisler)"
        if [[ -z "$hedefler" ]]; then
          _olcemedim "$ad/$m: 'girisler' beyan edilmemiş → çağrı kaldırılamaz"
          [[ $bulgu -eq 1 ]] || bulgu=3; _temizle "$tmp"; continue
        fi
        uygulandi=0
        while IFS= read -r g; do
          [[ -n "$g" && -f "$tmp/$g" ]] || continue
          if grep -q -e "$cagri" "$tmp/$g"; then
            sed -i "s/\\b${cagri}\\b/${cagri}__KALDIRILDI/g" "$tmp/$g" && uygulandi=1
          fi
        done <<< "$hedefler"
        ;;
    esac

    if [[ $uygulandi -eq 0 ]]; then
      _olcemedim "$ad/$m: mutasyon uygulanamadı (fonksiyon/çağrı bulunamadı)"
      [[ $bulgu -eq 1 ]] || bulgu=3; _temizle "$tmp"; continue
    fi

    if _sinav_kos "$tmp" "$sinav" >/dev/null 2>&1; then
      _bulgu "$ad/$m: mutasyon KIRMIZI YAKMADI → sınav bu kapıyı ölçmüyor"
      bulgu=1
    else
      _iyi "$ad/$m: mutasyon yakalandı"
    fi
    _temizle "$tmp"
  done
  return "${bulgu:-0}"
}

# ── denetle ──────────────────────────────────────────────────────────────────
_denetle(){
  local mut=0; [[ "${1:-}" == "--mutasyon" ]] && mut=1
  local kirmizi=0 olculemedi=0 rc
  # 🔴 SIRA BİLİNÇLİ: bayat-mi, kos'tan ÖNCE koşar. Aksi hâlde `kos` yeni damgayı
  #    yazar ve bayatlık kapısı KENDİ ÖLÇTÜĞÜ ŞEYİ tazeler — hiçbir zaman ateşlemez.
  #    (Bu aracın sınavı yakaladı: "kırmızı yok ama ölçülemeyen var" vakası 0 dönüyordu.)
  #    Doğru soru: "BEN GELDİĞİMDE bu kapının son yeşil koşumu güncel miydi?"
  for adim in _kayit _bayat_mi _bagli_mi _kos; do
    printf '\n── %s ──\n' "${adim#_}"
    $adim; rc=$?
    [[ $rc -eq 1 ]] && kirmizi=1
    [[ $rc -eq 3 ]] && olculemedi=1
  done
  if [[ $mut -eq 1 ]]; then
    printf '\n── mutasyon ──\n'
    while IFS= read -r ad; do
      [[ -n "$ad" ]] || continue
      _mutasyon "$ad"; rc=$?
      [[ $rc -eq 1 ]] && kirmizi=1
      [[ $rc -eq 3 ]] && olculemedi=1
    done < <(_adlar)
  fi
  printf '\n'
  # 🔴 Sıralama bilinçli: bulgu varsa 1; yoksa ama ölçülemeyen varsa 3.
  #    Ölçülemeyen ASLA 0'a yuvarlanmaz — bu aracın tüm anlamı o ayrımdadır.
  if [[ $kirmizi -eq 1 ]]; then
    if [[ $olculemedi -eq 1 ]]; then printf '🔴 BULGU var (ayrıca ölçülemeyen kalem VAR)\n'
    else printf '🔴 BULGU var\n'; fi
    return "$RC_BULGU"
  fi
  if [[ $olculemedi -eq 1 ]]; then
    printf '⚠️  Kırmızı yok — ama ÖLÇÜLEMEYEN kalem var. Bu YEŞİL DEĞİLDİR.\n'
    return "$RC_OLCULEMEDI"
  fi
  printf '✓ tüm kapılar: sınavlı · bağlı · taze\n'
  return "$RC_TEMIZ"
}

case "${1:-}" in
  kayit)    shift; _kayit "${1:-}" ;;
  kos)      shift; _kos "${1:-}" ;;
  bagli-mi) shift; _bagli_mi "${1:-}" ;;
  bayat-mi) shift; _bayat_mi "${1:-}" ;;
  mutasyon) shift; _mutasyon "${1:-}" ;;
  denetle)  shift; _denetle "${1:-}" ;;
  -h|--help|"") sed -n '/^# Kullanım:/,/^set -/p' "$0" | sed 's/^# \{0,1\}//'; exit "$RC_KULLANIM" ;;
  *) _hata "bilinmeyen komut: $1"; exit "$RC_KULLANIM" ;;
esac
