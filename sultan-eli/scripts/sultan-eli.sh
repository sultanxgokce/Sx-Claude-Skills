#!/usr/bin/env bash
# sultan-eli.sh — "bu komutu gerçekten insan mı başlattı?" ölçümü
#
# NİÇİN VAR (A06 · NÂZIR bulgusu 2026-08-03 · Sultan kararı 2026-08-04):
#   Filoda 18 beceri bir "Sultan onayladı" bayrağı taşıyor. Ölçüldü: bayrağın VARLIĞI
#   fail-closed zorlanıyor, ama KAYNAĞI hiç sorulmuyor. NÂZIR uçtan uca sınadı: ajan
#   ortamında, insan hiç devrede değilken bir terfi geçti — RC=0. Ajanı durduran tek şey,
#   bayrağı yazmamayı SEÇMESİYDİ. Bugün "kapı var" SANILIYOR; gerçek olan "bayrak var,
#   ölçüm yok" — arada bir sürüklenme değil, bir YANLIŞ GÜVEN vardı.
#
# 🔴 NE OLMADIĞI — ÖNCE BU (abartılmasın, ilk yanlış kullanım buradan doğar):
#   Bu bir KİLİT DEĞİL, bir KORKULUKTUR. Oda anahtarsız doğdu: betiği koşturabilen ajan,
#   betiğin okuyabildiği her şeyi de yazabilir (transkript ajanın kendi kullanıcısına aittir).
#   Yani: KAZAYI ve SESSİZ SÜRÜKLENMEYİ durdurur, KASTI durdurmaz. Bunu bilerek kullan;
#   "artık güvenli" cümlesi bu dosyanın verdiği güvencenin ötesindedir.
#
# NİÇİN YALNIZ GERİ ALINAMAZ KAPILAR (Sultan kararı, 2026-08-04):
#   Tam kilit imkânsız olduğuna göre ölçüm ancak kazayı durdurur → bedeli, kazanın FELAKET
#   olduğu yere harcanır: söküm · üretim-veritabanı · sunucu kurma · CF rota silme.
#   Geri alınabilir kapılarda (terfi, layiha) bayrak BEYAN olarak kalır — çünkü yanlış-red
#   gerçek bir maliyettir: 31 Tem'de meşru bir Sultan işi tam bu yüzden engellendi.
#
# ÖLÇÜLEN YÜZEY (firsthand, 2026-08-04 · SERDAR):
#   İnsanın `!` ile koştuğu komut, Claude Code oturum kaydına `<bash-input>` sarmalayıcısıyla
#   düşer; ajanın kendi komutu DÜŞMEZ (o `tool_use`/Bash olarak görünür). Aynı oturumda:
#     <bash-input> satırı  = 59      ajan Bash çağrısı = 12515
#   ⚠️ NÂZIR'ın önerdiği `userType=external` AYIRT ETMEZ — 168047 satırda var (her user-rolü
#      satırında, araç sonuçları dahil). Ayıran tek şey `<bash-input>` sarmalayıcısıdır.
#   ZAMANLAMA ölçüldü (yaklaşımın yaşam-şartı): kayıt satırı komuttan ÖNCE düşüyor —
#     <bash-input> yazıldı 1785856411.492 · komut koştu .863 · <bash-stdout> yazıldı .866
#   Yani kapı, koşarken kendi çağrısını kayıtta GÖREBİLİR. Sonra düşseydi bu yaklaşım ölüydü.
set -uo pipefail

PENCERE="${SULTAN_ELI_PENCERE:-45}"   # saniye: kaydın tazeliği
KOK="${SULTAN_ELI_KOK:-/config/.claude/projects}"

_kullanim() {
  cat <<'EOF'
sultan-eli.sh — geri alınamaz kapılar için "bunu insan mı başlattı" ölçümü

  dogrula --imza <metin>   kayıtta, son <pencere> sn içinde, <metin> geçen bir insan-`!`
                           komutu var mı? (imza = kapının kendi komut parçası)
  durum                    ölçüm yüzeyi görünüyor mu (tanı; verdikt vermez)
  iz --imza <metin>        İKİ ADIM, 1/2 — insan `!` komutunun İÇİNDE koşar: komutun kendisini ve başlangıcını bir iz dosyasına
                           yazar, hiçbir şeyi onaylamaz. (Harness `!` kaydını komut BİTTİKTEN sonra yazar; içeriden görülmez.)
  onayla --imza <metin> [--nonce <kimlik>]
                           İKİ ADIM, 2/2 — komut BİTTİKTEN sonra ayrı süreçte: iz ile birebir aynı komutun insan kaydı var mı?
                           Bulursa izi ve kaydı HARCAR (tek kullanım). 0 VAR · 1 YOK · 3 ÖLÇÜLEMEDİ

Çıkış: 0 insan-izi VAR · 1 insan-izi YOK · 2 kullanım · 3 ÖLÇÜLEMEDİ (kayıt görünmüyor)

⚠️ 3 ≠ 1. Ölçemediğini "insan yok" saymak, kapıyı yer-gerçeği yerine bilgisizliğe bağlar.
   Çağıran taraf 3'ü kendi politikasına göre yorumlar (İSKÂN: 3 → dur ve Sultan'a sor).
EOF
}

# Kayıt dosyası: bu oturuma ait olanı bilmiyoruz (ortamda oturum-kimliği yok — ölçüldü),
# o yüzden EN SON DOKUNULAN kayıt okunur. Yanlış-oturum riski pencere ile daraltılır.
_kayitlar() { find "$KOK" -name '*.jsonl' -mmin -10 2>/dev/null; }

_dogrula() {
  local imza="$1" bulundu=0 gorundu=0
  while IFS= read -r dosya; do
    [ -n "$dosya" ] || continue
    gorundu=1
    # 🔴 İLK SÜRÜM FIXTURE'DA YEŞİL, GERÇEK KAYITTA KIRMIZIYDI (2026-08-04, ölçüldü).
    #   O sürüm `tail -n 400 "$dosya" | python3 …` idi: 14/14 fixture testi geçti, ama gerçek
    #   oturum kaydında insan-izi VARKEN "yok" dedi (aynı python standalone koşturulunca
    #   BULUYORDU — yani hata python'da değil, sarmalayıcıdaydı).
    #   ⚠️ KÖK-NEDEN DOĞRULANMADI. İki aday vardı: (a) erken-çıkan python → tail SIGPIPE →
    #   `pipefail` başarıyı başarısız gösteriyor, (b) satır, tail derinliğinin dışına kaymış.
    #   Boruyu geri takan mutasyon fixture'ı kırmadı → (a) KANITLANMADI. Uydurma bir kök-neden
    #   yazmaktansa bunu açık bırakıyorum; kesin bilinen tek şey: bu sürüm gerçek kayıtta
    #   ölçüldü ve DOĞRU cevap veriyor, öncekiyse vermiyordu.
    #   Bu yüzden pipe kaldırıldı ve derinlik 800'e çıkarıldı: dosyayı python KENDİSİ okur
    #   (deque), yani iki adayın da zemini ortadan kalkar — belirsizliği tartışmak yerine
    #   belirsizliğin kaynağını sildik.
    #   DERS (bu tur 8. kez): fixture-yeşil, gerçek-yeşil DEĞİLDİR. Her kapı gerçek veride sınanır.
    if python3 -c '
import json,sys,datetime,collections,time
# 🔴 Saat kesirli olmalı (05.11, ölçüldü): tam saniyeye yuvarlanan saat, kapı kayıtla AYNI saniyede koşunca
#   kaydı "gelecekte" görüyordu; hızlı başlayan her meşru `!` satırı RED yiyordu (6/6 tekrarlandı).
dosya,imza=sys.argv[1],sys.argv[2]; simdi=time.time(); pencere=float(sys.argv[3])
try: son=collections.deque(open(dosya,encoding="utf-8",errors="replace"), maxlen=800)
except Exception: sys.exit(1)
for satir in son:
    try: o=json.loads(satir)
    except Exception: continue
    ic=o.get("message",{}).get("content")
    if not isinstance(ic,str) or "<bash-input>" not in ic: continue
    if imza not in ic: continue
    ts=o.get("timestamp")
    if not ts: continue
    try: an=datetime.datetime.fromisoformat(ts.replace("Z","+00:00")).timestamp()
    except Exception: continue
    if 0 <= simdi-an <= pencere: sys.exit(0)
sys.exit(1)
' "$dosya" "$imza" "$PENCERE"; then
      bulundu=1; break
    fi
  done <<< "$(_kayitlar)"
  [ "$gorundu" = 1 ] || return 3
  [ "$bulundu" = 1 ] || return 1
  return 0
}

# ── ZİNCİR KİMLİĞİ (SERDAR kararı 6 Kas 2026, görev …YC9DS) ─────────────────────────────
# SORUN: kayıt komutun BAŞINDA düşer, kapı zincirin SONUNDA koşabilir (`cd x && uzun-is && kapi`).
#   Pencere 45 sn kayıt anından sayıldığı için geç kalan kapı meşru Sultan'ı reddediyordu
#   (fixture: kayıt 5 sn → VAR, 60 sn → YOK). Pencereyi büyütmek kapıyı GEVŞETİRDİ → yapılmadı.
# ÇÖZÜM = ZAMAN değil KİMLİK bağı: kapının kendi süreç zincirinde, komut satırı kayıttaki insan
#   komutunu BİREBİR taşıyan bir kök varsa ve o kök KAYIT ANINDA başlamışsa (-2..+5 sn) kayıt kabul
#   edilir (mutlak üst sınır 10 dk). Yoksa eski 45 sn kuralı AYNEN geçerlidir (bu bölüm yalnız ekler).
#   Başka komuttan, aynı komutun sonradan yeniden koşusundan, yeniden kullanılmış PID'den geçmez.
# 🔴 DÜRÜST SINIR: kaydı Claude Code yazar; satıra PID giremez, o yüzden bağ komut METNİ + başlangıç
#   saatidir. Gerçek `!` sarmalayıcısının komut satırını nasıl taşıdığı fixture ile ÖLÇÜLEMEZ:
#   birebir ya da kabuk-tırnaklı (shlex) biçim aranır; eşleşmezse eski kurala düşer (regresyon yok).
ZINCIR_TAVAN=600   # saniye: MUTLAK üst sınır; ortam değişkeni yalnız DÜŞÜREBİLİR, yükseltemez
# Sınav dikişi (denetci.sh emsali): tavan yalnız SULTAN_ELI_SINAV=1 iken sınav için düşürülebilir.
[ "${SULTAN_ELI_SINAV:-}" = 1 ] && case "${SULTAN_ELI_SINAV_TAVAN:-}" in [1-9]|[1-9][0-9]*) ZINCIR_TAVAN="$SULTAN_ELI_SINAV_TAVAN" ;; esac
ZINCIR_UST="${SULTAN_ELI_ZINCIR_UST:-$ZINCIR_TAVAN}"
case "$ZINCIR_UST" in ''|*[!0-9]*) ZINCIR_UST="$ZINCIR_TAVAN" ;; esac
[ "$ZINCIR_UST" -le "$ZINCIR_TAVAN" ] || ZINCIR_UST="$ZINCIR_TAVAN"

_zincir() {
  local imza="$1"
  while IFS= read -r dosya; do
    [ -n "$dosya" ] || continue
    python3 -c '
import json,sys,os,re,shlex,collections,time,datetime
dosya,imza,pid,ust=sys.argv[1],sys.argv[2],int(sys.argv[3]),float(sys.argv[4])
simdi=time.time()
try: tick=os.sysconf("SC_CLK_TCK"); btime=[float(l.split()[1]) for l in open("/proc/stat") if l.startswith("btime")][0]
except Exception: sys.exit(1)
def ata(p):
    try:
        s=open("/proc/%d/stat"%p).read(); r=s.rsplit(")",1)[1].split()
        return int(r[1]), btime+int(r[19])/tick     # ppid, başlangıç (epoch sn)
    except Exception: return 0,0.0
def cmd(p):
    try: return open("/proc/%d/cmdline"%p,"rb").read().decode("utf-8","replace").split("\0")
    except Exception: return []
zincir=[]; p=pid
for _ in range(16):
    pp,bas=ata(p)
    if not bas: break
    zincir.append((p,bas,cmd(p)))
    if pp<=1: break
    p=pp
def kabuk_ayristir(m):
    # Minik kabuk sözcük ayırıcı: sözcük ve İŞLEÇ ayrımını korur (shlex tırnaklı noktalı virgül ile gerçek olanı ayırt edemez).
    # İşleç = tırnaksız & | ; < > ve satır sonu. Dönüş: [("s",değer) | ("o",işleç)]
    out=[]; i=0; n=len(m)
    while i<n:
        c=m[i]
        if c in " \t": i+=1; continue
        if c in "&|;<>\n":
            j=i+1
            while j<n and m[j] in "&|;<>" and c!="\n" and m[i] in "&|;<>": j+=1
            out.append(("o",m[i:j])); i=j; continue
        w=""; tirnakli=False
        while i<n and m[i] not in " \t&|;<>\n":
            c=m[i]
            if c==chr(39):
                k=m.find(chr(39),i+1)
                if k<0: return None
                w+=m[i+1:k]; i=k+1; tirnakli=True
            elif c==chr(34):
                i+=1; tirnakli=True
                while i<n and m[i]!=chr(34):
                    if m[i]==chr(92) and i+1<n and m[i+1] in (chr(34),chr(92),chr(36),chr(96)): w+=m[i+1]; i+=2
                    else: w+=m[i]; i+=1
                if i>=n: return None
                i+=1
            elif c=="\\":
                if i+1>=n: return None
                w+=m[i+1]; i+=2; tirnakli=True
            else: w+=c; i+=1
        if w.isdigit() and not tirnakli and i<n and m[i] in "<>": continue   # 2>&1 gibi fd öneki
        out.append(("s",w))
    return out
def eval_argumanlari(a):
    # KOMUT KONUMUNDAKİ (satır başı ya da bir komut ayıran işleçten &&, ||, ;, |, & ve `{`/`(`/`!` den hemen sonra; yönlendirme hedefi DEĞİL) tırnaksız `eval` sözcüğünün argümanları,
    # bir sonraki işlece kadar — eval onları boşlukla birleştirip koşar. `printf %s eval …` gibi komut konumunda
    # olmayan ya da tırnak içinde geçen `eval` hiçbir şey koşmaz → sayılmaz.
    t=kabuk_ayristir(a)
    if not t: return []
    out=[]
    for i,(tur,x) in enumerate(t):
        if tur!="s" or x!="eval": continue
        if i>0 and not ((t[i-1][0]=="o" and not any(ch in t[i-1][1] for ch in "<>")) or (t[i-1][0]=="s" and t[i-1][1] in ("{","(","!"))): continue
        j=i+1; parca=[]
        while j<len(t) and t[j][0]=="s": parca.append(t[j][1]); j+=1
        if parca: out.append(" ".join(parca))
    return out
tani=[]; yaslar=[]
try: son=collections.deque(open(dosya,encoding="utf-8",errors="replace"),maxlen=800)
except Exception: sys.exit(1)
for satir in son:
    try: o=json.loads(satir)
    except Exception: continue
    ic=o.get("message",{}).get("content")
    if not isinstance(ic,str): continue
    m=re.search(r"<bash-input>(.*?)</bash-input>",ic,re.S)
    if not m or imza not in m.group(1): continue
    kom=m.group(1).strip()   # kabuk baştaki/sondaki boşluğu görmez: kayıt " sleep 5 && …" ise eval argümanı "sleep 5 && …" olur
    ts=o.get("timestamp")
    if not ts: continue
    try: an=datetime.datetime.fromisoformat(ts.replace("Z","+00:00")).timestamp()
    except Exception: continue
    yaslar.append(simdi-an)
    if not (0<=simdi-an<=ust): continue
    for _,bas,argv in zincir:
        if not (an-2<=bas<=an+5): continue            # kök KAYIT ANINDA başlamış olmalı
        # BİREBİR: argv öğesi komutun kendisi, ya da `eval <komut>` sarmalayıcısının eval ARGÜMANI komutun kendisi.
        # Sarmalayıcı kabuk satırını (`source … && eval <alıntılı komut> < /dev/null && pwd -P >| …`) kabuk_ayristir ile AYRIŞTIRIRIZ (yalnız komut konumundaki eval sayılır):
        # alıntı biçimi (tek/çift/ters bölü) fark etmez, eval argümanı çözülüp komutla BİREBİR karşılaştırılır.
        # Başına/sonuna metin eklenmiş farklı komut, başka bir argümanın içinde geçen "eval '…'" metni eşleşmez.
        if any(a==kom for a in argv): sys.exit(0)
        if any(kom in eval_argumanlari(a) for a in argv): sys.exit(0)
    tani.append((an,kom))
if tani:   # kayıt VAR ama zincir eşleşmedi: sebep sayılarla (komut metni basılmaz) — canlı koşuda teşhis için
    for an,kom in tani:
        for pid_,bas,argv in zincir:
            adaylar=[c for a in argv for c in eval_argumanlari(a)]
            print("tanı: pid=%d başlangıç-kayıt=%+.1fsn(izin -2..+5) argv0=%s argc=%d eval-argümanı=%d kayıt-uzun=%d aday-uzun=%s"%(
                pid_,bas-an,os.path.basename(argv[0]) if argv else "?",len(argv),len(adaylar),len(kom),
                ",".join(str(len(c)) for c in adaylar[:3]) or "-"),file=sys.stderr)
if not tani:   # kayıt hiç yok ya da pencere dışı: YOK sonucu kendini açıklasın (komut metni basılmaz)
    print("tanı: zincir=%d süreç · imzalı kayıt=%d · en yakın kaydın yaşı=%s sn (zincir üst sınırı %d)"%(len(zincir),len(yaslar),("%.0f"%min(yaslar,key=abs)) if yaslar else "yok",ust),file=sys.stderr)
sys.exit(1)
' "$dosya" "$imza" "$$" "$ZINCIR_UST" && return 0
  done <<< "$(_kayitlar)"
  return 1
}

IZDIR="${SULTAN_ELI_IZ:-${XDG_CACHE_HOME:-$HOME/.cache}/sultan-eli/iz}"
IZ_YAS="${SULTAN_ELI_IZ_YAS:-900}"; case "$IZ_YAS" in ''|*[!0-9]*) IZ_YAS=900 ;; esac   # iki adım: iz'in en çok yaşı; python tarafı 900 üstüne çıkarmaz
case "${1:-}" in
  iz|onayla)
    MOD="$1"; shift; IMZA=""; NONCE=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --imza) IMZA="${2:-}"; shift 2 ;;
        --nonce) NONCE="${2:-}"; shift 2 ;;
        *) echo "HATA: bilinmeyen argüman: $1" >&2; exit 2 ;;
      esac
    done
    [ ${#IMZA} -ge 3 ] || { echo "HATA: --imza en az 3 karakter olmalı (kapının kendi komut parçası)" >&2; exit 2; }
    PY="$(dirname "${BASH_SOURCE[0]}")/iki-adim.py"
    [ "${SULTAN_ELI_SINAV:-}" = 1 ] && [ -n "${SULTAN_ELI_SINAV_IKI_ADIM:-}" ] && PY="$SULTAN_ELI_SINAV_IKI_ADIM"   # sınav dikişi (mutant): yalnız SULTAN_ELI_SINAV=1 iken
    [ -r "$PY" ] || { echo "ÖLÇÜLEMEDİ: $PY okunamıyor" >&2; exit 3; }
    if [ "$MOD" = iz ]; then python3 "$PY" iz "$IMZA" "$$" "$IZDIR"; exit $?; fi
    # shellcheck disable=SC2046
    python3 "$PY" onayla "$IMZA" "$IZDIR" "$NONCE" "$IZ_YAS" $(find "$KOK" -name '*.jsonl' -mmin -30 2>/dev/null)
    exit $? ;;
  dogrula)
    IMZA=""
    shift
    while [ $# -gt 0 ]; do
      case "$1" in
        --imza) IMZA="${2:-}"; shift 2 ;;
        *) echo "HATA: bilinmeyen argüman: $1" >&2; exit 2 ;;
      esac
    done
    # İmza ZORUNLU ve anlamlı olmalı. İmzasız "herhangi bir insan komutu var mı" sorusu,
    # kapıyı bir zaman-penceresine indirger: insan başka bir iş için `!` yazdıktan hemen
    # sonra ajan bu kapıdan geçebilirdi. İmza, izi KOMUTA bağlar.
    [ ${#IMZA} -ge 3 ] || { echo "HATA: --imza en az 3 karakter olmalı (kapının kendi komut parçası)" >&2; exit 2; }
    _dogrula "$IMZA"; RC=$?
    ZINCIRDEN=0
    if [ "$RC" = 1 ] && _zincir "$IMZA"; then RC=0; ZINCIRDEN=1; fi
    case "$RC" in
      0) if [ "$ZINCIRDEN" = 1 ]; then echo "insan-izi VAR (zincir kimliği): '$IMZA' geçen '!' komutunun kökü bu zincirde, kayıt anında başlamış"
         else echo "insan-izi VAR: son ${PENCERE}sn içinde '$IMZA' geçen bir '!' komutu kayıtta"; fi ;;
      1) echo "insan-izi YOK: son ${PENCERE}sn içinde '$IMZA' geçen bir '!' komutu kayıtta bulunamadı" >&2 ;;
      3) echo "ÖLÇÜLEMEDİ: oturum kaydı görünmüyor ($KOK) — bu 'insan yok' DEMEK DEĞİLDİR" >&2 ;;
    esac
    exit $RC
    ;;
  durum)
    N="$(_kayitlar | wc -l)"
    echo "kayıt kökü : $KOK"
    echo "taze kayıt : $N dosya (son 10 dk)"
    echo "pencere    : ${PENCERE} sn"
    [ "$N" -gt 0 ] && echo "ölçüm yüzeyi: GÖRÜNÜYOR" || echo "ölçüm yüzeyi: YOK — bu kutuda kapı ölçemez (3 döner)"
    exit 0
    ;;
  ""|-h|--help) _kullanim; exit 2 ;;
  *) echo "HATA: bilinmeyen fiil: $1" >&2; _kullanim; exit 2 ;;
esac
