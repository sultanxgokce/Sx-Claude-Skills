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
#   olcum-disiplini.sh bicim <dosya> [beklenen-tur]
#     Dosyanın GERÇEKTEN o tür olduğunu SİHİRLİ BAYTLARINDAN doğrular.
#     Uzantı bir iddiadır, baytlar kanıttır. rc: 0 uyuşuyor · 1 UYUŞMUYOR · 3 tanınmıyor
#
#   olcum-disiplini.sh kart --hipotez "..." --degisken "..." --beklenen "..." \
#                           --gecersiz "..." --ortam "..." [--sayim "..."]
#     --sayim: beklenen bir SAYI içeriyorsa ZORUNLU. "o sayıyı üreten eşleşmelerden
#              birini açıp gerçekten aradığın şey olduğunu doğruladın mı?"
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

# ── bicim ────────────────────────────────────────────────────────────────────
# Bir dosyanın GERÇEKTEN iddia edilen türde olduğunu SİHİRLİ BAYTLARINDAN doğrular.
#
# 🔴 NİÇİN (ölçülmüş, 2026-09-09): bir servisten "PDF" istendi; yanıtın alan adı
#    `dataType=PDF` idi, dosya adı `.zip`, baytlar ise `PK\x03\x04` — yani ZIP.
#    İçinde tek bir gerçek PDF vardı. Açmadan diske "fatura.pdf" diye yazmak BOZUK
#    bir dosya üretirdi ve bunu KİMSE dosyayı açana kadar fark etmezdi: teslim
#    edilmiş, arşivlenmiş, "gönderdim" denmiş bir bozukluk.
#
#    > Uzantı bir İDDİADIR. Baytlar KANITTIR. İkisi çelişince baytlar kazanır.
_bicim(){
  local yol="${1:-}" beklenen="${2:-}"
  [[ -n "$yol" ]] || { _hata "kullanım: bicim <dosya> [beklenen-tür]"; return "$RC_KULLANIM"; }
  [[ -f "$yol" ]] || { _hata "dosya yok ya da düz dosya değil: $yol"; return "$RC_KULLANIM"; }
  [[ -s "$yol" ]] || { _bulgu "dosya BOŞ (0 bayt): $yol"; return "$RC_BULGU"; }
  # beklenen verilmezse uzantıdan türet — uzantı yoksa ÖLÇÜLEMEDİ
  if [[ -z "$beklenen" ]]; then
    # 🔴 UZANTI DOSYA ADINDAN OKUNUR, YOLDAN DEĞİL (sınav yakaladı 2026-09-09):
    #    ilk sürüm `case "$yol" in *.*)` yapıyordu; `/tmp/tmp.AbCd/uzantisiz` gibi
    #    DİZİN adında nokta olan bir yolda uzantı VAR sanıp "uzantisiz" adının
    #    tamamını uzantı olarak alıyordu. Ölçüm aracının kendi ölçümü yanlıştı.
    local dosya="${yol##*/}"
    case "$dosya" in
      ?*.*) beklenen="${dosya##*.}" ;;
      *) _hata "uzantı yok ve beklenen tür verilmedi → ÖLÇÜLEMEDİ"; return "$RC_OLCULEMEDI" ;;
    esac
  fi
  beklenen="$(printf '%s' "$beklenen" | tr 'A-Z' 'a-z')"
  local bas; bas="$(head -c 8 "$yol" | od -An -tx1 | tr -d ' \n')"
  local gercek="bilinmiyor"
  case "$bas" in
    25504446*)   gercek="pdf" ;;                 # %PDF
    504b0304*|504b0506*|504b0708*) gercek="zip" ;;
    89504e47*)   gercek="png" ;;
    ffd8ff*)     gercek="jpg" ;;
    1f8b*)       gercek="gz"  ;;
    3c3f786d6c*) gercek="xml" ;;                 # <?xml
    efbbbf3c3f*) gercek="xml" ;;                 # BOM + <?xml
    *)
      # metin tabanlılar: ilk görünür karakterden karar ver
      local ilk; ilk="$(tr -d '[:space:]' < "$yol" | head -c 1)"
      case "$ilk" in
        '<') gercek="xml/html" ;;
        '{'|'[') gercek="json" ;;
      esac ;;
  esac
  # eşdeğerlik: zip tabanlı ofis biçimleri, xml/html ailesi
  local uyar=""
  case "$beklenen:$gercek" in
    docx:zip|xlsx:zip|pptx:zip|odt:zip|jar:zip) gercek="$beklenen" ;;
    html:xml/html|xml:xml/html|htm:xml/html)    gercek="$beklenen" ;;
    json:json|xml:xml) ;;
  esac
  if [[ "$gercek" == "$beklenen" ]]; then
    printf '✓ %s · baytlar %s ile uyuşuyor\n' "$yol" "$beklenen"
    return "$RC_TEMIZ"
  fi
  if [[ "$gercek" == "bilinmiyor" ]]; then
    _hata "⏸ ÖLÇÜLEMEDİ · $yol — baytlar tanınmıyor (baş: ${bas:0:16})"
    _hata "   'yanlış tür' DEMEK DEĞİLDİR; bu araç o biçimi bilmiyor."
    return "$RC_OLCULEMEDI"
  fi
  _bulgu "$yol · '$beklenen' bekleniyordu, baytlar '$gercek' diyor"
  if [[ "$gercek" == "zip" ]]; then
    _hata "   → ZIP içinde asıl dosya olabilir. İçerik:"
    if command -v python3 >/dev/null 2>&1; then
      python3 - "$yol" <<'PZ' 2>/dev/null || _hata "     (zip açılamadı)"
import sys, zipfile
try:
    z = zipfile.ZipFile(sys.argv[1])
    for n in z.namelist()[:5]:
        print(f"     · {n} ({z.getinfo(n).file_size} bayt)")
except Exception as e:
    print(f"     (okunamadı: {type(e).__name__})")
PZ
    fi
  fi
  _hata "   🔴 Uzantı bir İDDİADIR, baytlar KANITTIR. Diske bu adla yazmak bozuk"
  _hata "      dosya üretir ve kimse AÇANA KADAR fark etmez."
  return "$RC_BULGU"
}

# ── kart ─────────────────────────────────────────────────────────────────────
# Ölçüm kartı: ölçümü KURMADAN önce cevaplanması gereken beş soru. Kazıdaki altı
# geçersiz ölçümün altısı da bu beş sorudan birine takılırdı.
_kart(){
  local hipotez="" degisken="" beklenen="" gecersiz="" ortam="" sayim=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --hipotez)  hipotez="${2:-}"; shift 2 ;;
      --degisken) degisken="${2:-}"; shift 2 ;;
      --beklenen) beklenen="${2:-}"; shift 2 ;;
      --gecersiz) gecersiz="${2:-}"; shift 2 ;;
      --ortam)    ortam="${2:-}"; shift 2 ;;
      --sayim)    sayim="${2:-}"; shift 2 ;;
      *) _hata "bilinmeyen bayrak: $1"; exit "$RC_KULLANIM" ;;
    esac
  done
  local eksik=()
  [[ -n "$hipotez"  ]] || eksik+=("--hipotez (neyin doğru olduğunu sanıyorum)")
  [[ -n "$degisken" ]] || eksik+=("--degisken (TEK başına neyi değiştiriyorum)")
  [[ -n "$beklenen" ]] || eksik+=("--beklenen (fark ne olmalı — sayı ya da gözlem)")
  [[ -n "$gecersiz" ]] || eksik+=("--gecersiz (bu ölçümü GEÇERSİZ kılacak şey ne)")
  [[ -n "$ortam"    ]] || eksik+=("--ortam (bu iddiayı hangi ortam KANITLAYABİLİR)")
  # 🔴 ALTINCI SORU — YALNIZ SAYI ÜRETEN ÖLÇÜMLERDE (ölçülmüş vaka 2026-08-30):
  #    bir tarama "39 tevkifatlı fatura buldum" dedi; kontrol edilince OTUZ DOKUZU DA
  #    yanlış-pozitifti — aranan kelime bambaşka bir alanda, etiket olarak geçiyordu.
  #    O sayıya güvenip biçim kopyalansaydı, UYDURMA bir yapı "ölçüldü" diye kanona
  #    girecekti. Beş soru bunu YAKALAMIYORDU: hipotez doğru, değişken tek, ortam doğru,
  #    geçersizlik tanımı bile vardı — eksik olan "SAYIYI ÜRETEN ŞEYİ AÇTIN MI" idi.
  #    Zorunluluk KOŞULLUDUR: yalnız `--beklenen` bir sayı içeriyorsa istenir.
  if [[ -z "$sayim" && "$beklenen" =~ [0-9] ]]; then
    eksik+=("--sayim (beklenen bir SAYI içeriyor → o sayıyı üreten eşleşmelerden en az"
            "         BİRİNİ açıp, gerçekten aradığın şey olduğunu doğruladın mı? nasıl?)")
  fi
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
  [[ -n "$sayim" ]] && printf '  sayım    : %s\n' "$sayim"
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
  bicim)   shift; _bicim "$@" ;;
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
