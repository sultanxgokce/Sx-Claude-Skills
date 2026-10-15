#!/usr/bin/env bash
# olcum-disiplini.sh — bir ÖLÇÜMÜN gerçekten ölçüm olduğunu kanıtlayan araç takımı.
#
# NİÇİN VAR (2026-08-23 · e-Logo derin kazısı, iki kol · ve aynı gün İKİ CANLI VAKA)
# ────────────────────────────────────────────────────────────────────────────────
# Kazıda altı ölçüm GEÇERSİZ çıktı: değişkeni değiştirdik ama GİRDİYİ değiştirmedik ·
# gölge-DOM yerine ışık-DOM'u saydık · toplam yerine "yazıyla tutar" satırını okuduk ·
# satır sayısı yerine DÜZENLEME KİPİNDEKİ satırı saydık. Hepsinde araç doğru çalıştı,
# yanlış olan SORUYDU.
#
# 🔴 Ve aynı gün, ikisi de bu takımın en basit kuralına takıldı:
#
#     bash sinav.sh | tail -3 ; echo "rc=$?"      ← `tail`'in kodunu okur, sınavın DEĞİL
#
#   MUHASİP (MMEx kutusu) bunu iki kez yaptı ve yanılgı defterine yazdı.
#   MUAVİN (merkez) aynı gün canlı doğrulamada aynısını yaptı: `denetle` çıktısını
#   `tail`'e verdi, `exit=0` gördü, "temiz" sandı — çıplak koşunca **1**'di.
#
#   İki ayrı kutu, iki ayrı ajan, aynı gün, aynı hata. Kural ikisinde de YAZILIYDI.
#   Sonuç açık: **bu bir "dikkatli ol" maddesi değil, mekanik kapı olmak zorunda.**
#
# 🔴 DEĞİŞMEZ 1 — bu araç ölçüm YAPMAZ, ölçümün KURULUŞUNU denetler.
# 🔴 DEĞİŞMEZ 2 — RC=3 ÖLÇÜLEMEDİ demektir, yeşil değil.
# 🔴 DEĞİŞMEZ 3 — ölçülmüş negatif SİLİNMEZ; defter append-only, iddia tekrar sorulur.
#
# Kullanım:
#   olcum-disiplini.sh boru <yol...>        boru-hattı arkasından çıkış kodu okuma avı
#   olcum-disiplini.sh negatif sor   --iddia "..."
#   olcum-disiplini.sh negatif yaz   --iddia "..." --kanit "..."
#   olcum-disiplini.sh kart --hipotez "..." --degisken "..." --beklenen "..." \
#                           --gecersiz "..." --ortam "..."
#
# Çıkış: 0 temiz · 1 BULGU · 2 kullanım/ortam · 3 ÖLÇÜLEMEDİ
set -uo pipefail

DEFTER="${OLCUM_DEFTERI:-${PWD}/.olcum/negatifler.jsonl}"
RC_TEMIZ=0; RC_BULGU=1; RC_KULLANIM=2; RC_OLCULEMEDI=3

_hata(){ printf '%s\n' "$*" >&2; }
_bulgu(){ printf '🔴 %s\n' "$*"; }
_iyi(){ printf '✓ %s\n' "$*"; }

# ── boru ─────────────────────────────────────────────────────────────────────
# Bir boru hattının çıkış kodu, hattın SON komutununkidir. `bash x | tail` yazıp
# ardından `$?` okumak, `tail`'in kodunu okumaktır — ve `tail` neredeyse hep 0 döner.
# Yani KIRMIZI bir koşum "temiz" görünür. Bu, ölçüm-aracının kendisinin yanılttığı
# sınıfın en sık örneğidir.
#
# Güvenli sayılanlar (yanlış-pozitif üretmemek için):
#   · dosyada `set -o pipefail` ya da `set -euo pipefail` varsa
#   · `${PIPESTATUS[...]}` kullanılıyorsa
#   · `$?` bir boru hattından DEĞİL, düz komuttan sonra okunuyorsa
_boru(){
  [[ $# -gt 0 ]] || { _hata "kullanım: boru <yol...>"; exit "$RC_KULLANIM"; }
  local dosyalar=() y
  for y in "$@"; do
    if [[ -d "$y" ]]; then
      while IFS= read -r f; do dosyalar+=("$f"); done < <(find "$y" -type f -name '*.sh' -not -path '*/.git/*' | sort)
    elif [[ -f "$y" ]]; then dosyalar+=("$y")
    else _hata "HATA: yol yok: $y"; exit "$RC_KULLANIM"; fi
  done
  [[ ${#dosyalar[@]} -gt 0 ]] || { _hata "HATA: taranacak .sh dosyası bulunamadı"; exit "$RC_KULLANIM"; }

  local bulgu=0
  for f in "${dosyalar[@]}"; do
    OLCUM_F="$f" python3 - <<'PY' || bulgu=1
import os, re, sys
yol = os.environ['OLCUM_F']
try:
    satirlar = open(yol, encoding='utf-8', errors='replace').read().split('\n')
except OSError:
    sys.exit(0)
metin = '\n'.join(satirlar)

# Dosya genelinde kalkan var mı?
# 🔴 KELİME SINIRI ŞART (bu aracın ilk sürümü kendi avladığı hataya düştü, 2026-08-23):
#    ilk hâl `'pipefail' in metin` diyordu — DÜZ ALT-DİZGE. Deneme dosyasındaki
#    `pipefail_yok` ifadesi kalkan sanıldı ve gerçek bir vaka SESSİZCE atlandı.
#    Aynı gün ölçülen muhafız kusurunun ikizi: izin belirteci tehlikeli ifadenin
#    İÇİNE gömülünce izin veriyordu. Kalkan artık `set` satırında, KELİME olarak aranır.
if re.search(r'^\s*set\s+[^\n#]*\bpipefail\b', metin, re.M):
    sys.exit(0)

# 🔴 KURAL DARALTILDI — GERÇEK VERİ ÇÜRÜTTÜ (2026-08-23, ilk koşumda ölçüldü).
#    İlk hâl "boru + $?" gören her yeri işaretliyordu ve gerçek depoda YEDİ yanlış-pozitif
#    üretti. Hepsi şu meşru desendendi:
#        printf '%s' "$out" | grep -q 'DUMAN TESTİ DÜŞTÜ'
#        kapi "G2 ..." $?
#    Burada `$?` gerçekten `grep`'in kodudur VE kasıt tam olarak odur — grep bir YARGIDIR.
#    Tehlikeli olan, borunun GÖRÜNTÜ SÜZGECİYLE bitmesidir (tail/head/cat/sed…): o süzgeç
#    neredeyse hep 0 döner, yani KIRMIZI bir koşum "temiz" görünür.
#    Bu yüzden yalnız 'anlamsız çıkış kodu' üreten süzgeçlerle biten borular işaretlenir.
#    (Gürültülü kapı, kapatılan kapıdır: kesinlik kapsamdan önce gelir.)
GORUNTU_SUZGECI = ('tail','head','cat','tee','less','more','tr','column','nl','fold','rev','xxd','hexdump')

def boru_var(s):
    # `||` ve `|&` boru sayılmaz; tırnak içi kaba biçimde elenir
    s = re.sub(r'"[^"]*"', '""', s)
    s = re.sub(r"'[^']*'", "''", s)
    s = s.replace('||', '').replace('|&', '')
    if '|' not in s:
        return False
    # borunun SON parçası bir görüntü süzgeci mi?
    son = s.split('|')[-1].strip()
    son = re.sub(r'^[\d<>&\s]*', '', son)          # yönlendirme artıkları
    ilk_kelime = son.split()[0] if son.split() else ''
    ilk_kelime = ilk_kelime.split('/')[-1]           # /usr/bin/tail → tail
    return ilk_kelime in GORUNTU_SUZGECI

bulundu = []
for i, s in enumerate(satirlar):
    if '$?' not in s and '${?' not in s:
        continue
    if 'PIPESTATUS' in s:
        continue
    # $?'in okunduğu satırın KENDİSİ boru içeriyorsa ya da bir ÖNCEKİ ifade boruysa
    aday = None
    if boru_var(s.split('$?')[0]):
        aday = s
    else:
        # en yakın önceki dolu satır
        j = i - 1
        while j >= 0 and not satirlar[j].strip():
            j -= 1
        if j >= 0 and boru_var(satirlar[j]) and not satirlar[j].strip().startswith('#'):
            aday = satirlar[j]
    if aday is not None:
        bulundu.append((i + 1, s.strip(), aday.strip()))

if bulundu:
    print(f'🔴 {yol}')
    for no, s, kaynak in bulundu:
        print(f'   satır {no}: {s}')
        if kaynak != s:
            print(f'      ← ölçtüğü boru: {kaynak}')
    print("   → boru hattının çıkış kodu SON komutunundur; `$?` onu okur, ölçtüğünü DEĞİL.")
    print("   → burada son komut bir GÖRÜNTÜ SÜZGECİ: neredeyse hep 0 döner → kırmızı koşum 'temiz' görünür.")
    print("   → çözüm: komutu çıplak koş, ya da `set -o pipefail`, ya da ${PIPESTATUS[0]}")
    sys.exit(1)
sys.exit(0)
PY
  done
  [[ $bulgu -eq 0 ]] && { _iyi "boru-arkası çıkış kodu okuması yok (${#dosyalar[@]} dosya)"; return "$RC_TEMIZ"; }
  return "$RC_BULGU"
}

# ── negatif defteri ──────────────────────────────────────────────────────────
# "Bunu daha önce ölçtük mü?" — kazıda aynı negatif üç ve dört kez ölçüldü (~25 dk).
# Yanılgı defteri iş BİTTİKTEN SONRA yazıldığı için hiçbirini engellemedi.
_iddia_anahtar(){ printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9çğıöşü' ' ' | tr -s ' ' | sed 's/^ //;s/ $//'; }

_negatif_yaz(){
  local iddia="" kanit=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --iddia) iddia="${2:-}"; shift 2 ;;
      --kanit) kanit="${2:-}"; shift 2 ;;
      *) _hata "bilinmeyen bayrak: $1"; exit "$RC_KULLANIM" ;;
    esac
  done
  [[ -n "$iddia" ]] || { _hata "HATA: --iddia zorunlu"; exit "$RC_KULLANIM"; }
  # 🔴 Kanıtsız negatif kaydı, ölçülmemiş bir şeyi "ölçüldü" diye gelecek turlara satar.
  [[ -n "$kanit" ]] || { _hata "HATA: --kanit zorunlu — kanıtsız negatif, negatif değildir"; exit "$RC_KULLANIM"; }
  mkdir -p "$(dirname "$DEFTER")"
  python3 - "$DEFTER" "$iddia" "$kanit" "$(_iddia_anahtar "$iddia")" <<'PY'
import json,sys,datetime
d,i,k,a = sys.argv[1:5]
with open(d,'a',encoding='utf-8') as f:
    f.write(json.dumps({"tarih":datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d'),
                        "iddia":i,"kanit":k,"anahtar":a}, ensure_ascii=False)+'\n')
print("✓ negatif deftere yazıldı")
PY
  return "$RC_TEMIZ"
}

_negatif_sor(){
  local iddia=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --iddia) iddia="${2:-}"; shift 2 ;;
      *) _hata "bilinmeyen bayrak: $1"; exit "$RC_KULLANIM" ;;
    esac
  done
  [[ -n "$iddia" ]] || { _hata "HATA: --iddia zorunlu"; exit "$RC_KULLANIM"; }
  if [[ ! -f "$DEFTER" ]]; then
    # Defter YOKSA "ölçülmedi" DEĞİL, ÖLÇÜLEMEDİ. Boş defterle "hiç ölçülmemiş"
    # hükmü vermek, tam da bu aracın kapattığı hatadır (yokluk ≠ kanıt).
    printf '⚠️  ÖLÇÜLEMEDİ · negatif defteri yok (%s) — "daha önce ölçülmedi" DENEMEZ\n' "$DEFTER"
    return "$RC_OLCULEMEDI"
  fi
  OLCUM_D="$DEFTER" OLCUM_A="$(_iddia_anahtar "$iddia")" python3 - <<'PY'
import json,os,sys
d=os.environ['OLCUM_D']; a=set(os.environ['OLCUM_A'].split())
vurus=[]
for satir in open(d,encoding='utf-8'):
    satir=satir.strip()
    if not satir: continue
    try: k=json.loads(satir)
    except Exception: continue
    b=set(k.get('anahtar','').split())
    if not b: continue
    ortak=len(a & b)/max(1,len(a | b))     # Jaccard
    if ortak >= 0.5: vurus.append((k,ortak))
if not vurus:
    print("✓ bu iddia defterde yok — ölçüm açılabilir")
    sys.exit(0)
vurus.sort(key=lambda x:-x[1])
print(f"🔴 BU DAHA ÖNCE ÖLÇÜLDÜ ({len(vurus)} kez) — yeniden ölçmeden ÖNCE oku:")
for k,o in vurus:
    print(f"   · {k['tarih']} · benzerlik %{int(o*100)}")
    print(f"     iddia: {k['iddia']}")
    print(f"     kanıt: {k['kanit']}")
print("   → aynı negatifi yeniden ölçmek, kazıda ~25 dakikaya mal oldu (3-4 tekrar).")
sys.exit(1)
PY
}

# ── kart ─────────────────────────────────────────────────────────────────────
# Ölçüm kartı: ölçümü KURMADAN önce cevaplanması gereken beş soru. Kazıdaki altı
# geçersiz ölçümün altısı da bu beş sorudan birine takılırdı.
_kart(){
  local hipotez="" degisken="" beklenen="" gecersiz="" ortam=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --hipotez)  hipotez="${2:-}"; shift 2 ;;
      --degisken) degisken="${2:-}"; shift 2 ;;
      --beklenen) beklenen="${2:-}"; shift 2 ;;
      --gecersiz) gecersiz="${2:-}"; shift 2 ;;
      --ortam)    ortam="${2:-}"; shift 2 ;;
      *) _hata "bilinmeyen bayrak: $1"; exit "$RC_KULLANIM" ;;
    esac
  done
  local eksik=()
  [[ -n "$hipotez"  ]] || eksik+=("--hipotez (neyin doğru olduğunu sanıyorum)")
  [[ -n "$degisken" ]] || eksik+=("--degisken (TEK başına neyi değiştiriyorum)")
  [[ -n "$beklenen" ]] || eksik+=("--beklenen (fark ne olmalı — sayı ya da gözlem)")
  [[ -n "$gecersiz" ]] || eksik+=("--gecersiz (bu ölçümü GEÇERSİZ kılacak şey ne)")
  [[ -n "$ortam"    ]] || eksik+=("--ortam (bu iddiayı hangi ortam KANITLAYABİLİR)")
  if [[ ${#eksik[@]} -gt 0 ]]; then
    _bulgu "ölçüm kartı eksik — ölçüm KURULMADAN önce doldurulur:"
    printf '   · %s\n' "${eksik[@]}"
    _hata "   → eksik kart, ölçümü değil ÜMİDİ kaydeder."
    return "$RC_KULLANIM"
  fi
  printf '📐 ÖLÇÜM KARTI\n'
  printf '  hipotez  : %s\n' "$hipotez"
  printf '  değişken : %s\n' "$degisken"
  printf '  beklenen : %s\n' "$beklenen"
  printf '  geçersiz : %s\n' "$gecersiz"
  printf '  ortam    : %s\n' "$ortam"
  printf '\n── defter kontrolü ──\n'
  # Kartın ÇAĞIRANI burada: negatif defteri gönüllü sorulmaz, kart onu KENDİLİĞİNDEN sorar.
  _negatif_sor --iddia "$hipotez"; local nrc=$?
  case "$nrc" in
    0) return "$RC_TEMIZ" ;;
    1) return "$RC_BULGU" ;;
    *) return "$RC_OLCULEMEDI" ;;
  esac
}

case "${1:-}" in
  boru)    shift; _boru "$@" ;;
  negatif) shift
    case "${1:-}" in
      yaz) shift; _negatif_yaz "$@" ;;
      sor) shift; _negatif_sor "$@" ;;
      *) _hata "kullanım: negatif <yaz|sor> …"; exit "$RC_KULLANIM" ;;
    esac ;;
  kart)    shift; _kart "$@" ;;
  -h|--help|"") sed -n '/^# Kullanım:/,/^set -/p' "$0" | sed 's/^# \{0,1\}//'; exit "$RC_KULLANIM" ;;
  *) _hata "bilinmeyen komut: $1"; exit "$RC_KULLANIM" ;;
esac
