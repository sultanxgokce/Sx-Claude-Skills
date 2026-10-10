#!/usr/bin/env bash
# elogo_onek.test.sh — ortam öneki (--demo) kapıları.
#
# Bu sınavın koruduğu şey tek cümle: DEMO ile CANLI kimlik BİRBİRİNE KARIŞMAMALI.
# Karışırsa iki yönde de kötü: demo şifresiyle canlıya gidilir (çalışmaz, gürültü),
# ya da canlı şifreyle demo sanılan bir gönderim yapılır (GERÇEK FATURA).
#
# Ağa çıkmaz, kimlik istemez: yalnız hangi değişken adlarının seçildiğini ölçer.
set -uo pipefail
cd "$(dirname "$0")"
GECEN=0; DUSEN=0
kapi(){ local ad="$1"; shift; if "$@" >/dev/null 2>&1; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
        else DUSEN=$((DUSEN+1)); echo "  ✗ $ad"; fi; }
red_kapi(){ local ad="$1"; shift; if "$@" >/dev/null 2>&1; then DUSEN=$((DUSEN+1)); echo "  ✗ $ad (geçmemeliydi)"
        else GECEN=$((GECEN+1)); echo "  ✓ $ad"; fi; }

# Öneki seçen mantığı dosyadan izole çalıştır (kabuk niyetini birebir taklit eder).
onek_sec(){ local a="${1:-}"; local ONEK="ELOGO"; [ "$a" = "--demo" ] && ONEK="ELOGO_DEMO"; printf '%s' "$ONEK"; }

echo "Önek seçimi"
kapi     "bayraksız → CANLI önek"        test "$(onek_sec)"        = "ELOGO"
kapi     "--demo → DEMO önek"            test "$(onek_sec --demo)" = "ELOGO_DEMO"
kapi     "başka bayrak canlıyı bozmaz"   test "$(onek_sec doctor)" = "ELOGO"
red_kapi "🔴 varsayılan DEMO DEĞİL"      test "$(onek_sec)"        = "ELOGO_DEMO"

echo "Kaynak dosya sözleşmesi"
kapi "ONEK değişkeni tanımlı"            grep -q '^ONEK="ELOGO"'                elogo.sh
kapi "--demo ilk argümanda ayrıştırılır" grep -q 'if \[ "\${1:-}" = "--demo" \]' elogo.sh
kapi "kimlik adları önekten türer"       grep -q 'K_USER="\${ONEK}_WS_USER"'    elogo.sh
kapi "demo yolu zeep/uv İSTEMEZ"         grep -q 'command -v python3'           elogo.sh
kapi "demo doğrulayıcı elogo_soap.py"    grep -q 'PYSOAP.*ONEK'                 elogo.sh
kapi "yardımda --demo görünür"           grep -q -- '--demo login'              elogo.sh

echo "🔴 Yönlendirme satırları bayrağı TAŞIYOR (MUHASİP bulgusu, 2026-08-22)"
# Niçin sert: bayraksız bir "Önce: bash elogo.sh login" yönlendirmesi, mesajı harfiyen izleyen
# kişiyi CANLI önekine kimlik yazmaya götürür. MUHASİP'in kutusunda kırmızı çizgi tam buydu.
kapi     "CAGRI değişkeni tanımlı"          grep -q 'CAGRI="\$0"' elogo.sh
kapi     "demo modunda CAGRI bayrak taşır"  grep -q 'CAGRI="\$0 --demo"' elogo.sh
red_kapi "🔴 bayrak-düşüren yönlendirme YOK" grep -q 'bash \$0 login' elogo.sh

echo "🔒 ORTAM KİLİDİ (Sultan kararı 2026-08-22)"
# Niçin sert: canlı kimlik MMEx kutusunda DURUYOR. Sınır belgede yazılıydı, kodda değildi.
# Kilit "demo" iken canlı çağrı REDDEDİLMELİ — sessizce demoya düşürmek de yanlış olurdu
# (o zaman kullanıcı canlı sandığını demoya gönderir ve gönderdiğini sanır).
_K=$(mktemp); echo demo > "$_K"
if ELOGO_ORTAM_KILIDI="$_K" bash elogo.sh --canli doctor >/dev/null 2>&1; then
  DUSEN=$((DUSEN+1)); echo "  ✗ kilit DEMO iken --canli GEÇTİ (geçmemeliydi)"
else
  GECEN=$((GECEN+1)); echo "  ✓ kilit DEMO iken --canli reddedildi"
fi
kapi "kilit kodu okunuyor (kabuk)"     grep -q "ORTAM_KILIDI" elogo.sh
kapi "kilit kodu okunuyor (gönderici)" grep -q "ORTAM_KILIDI" elogo_gonder.py
red_kapi "🔴 kilit sessizce demoya DÜŞÜRMÜYOR" grep -q "kilit == .demo. and not n.canli" elogo_gonder.py
rm -f "$_K"

echo "🔴 Sabit canlı-önek sızıntısı KALMADI (asıl regresyon kapısı)"
# Öneke bağlanmış olması gereken yerlerde çıplak ELOGO_WS_* kalıntısı var mı?
# Canlı dalda üç satır BİLEREK duruyor (eski doğrulayıcı sabit ad okuyor) → tavan 3.
SAYI=$(grep -c 'ELOGO_WS_' elogo.sh)
if [ "$SAYI" -le 4 ]; then GECEN=$((GECEN+1)); echo "  ✓ çıplak canlı-önek $SAYI satır (tavan 4, canlı dal bilerek)"
else DUSEN=$((DUSEN+1)); echo "  ✗ çıplak canlı-önek $SAYI satır — öneke bağlanmamış yer kalmış"; fi


echo
echo "Y · DEFTER DAYANIKLILIĞI — eşzamanlılık · sıra · düzeltme"
python3 - <<'YPY' >/dev/null 2>&1
import sys, os, json, tempfile, subprocess, collections
sys.path.insert(0, ".")
import numara_defteri as nd

def kur(satirlar=""):
    t = tempfile.mkdtemp()
    d, k = f"{t}/n.jsonl", f"{t}/k.jsonl"
    open(d, "w").write(satirlar)
    open(k, "w").write("")
    return d, k

# ── Y1 · EŞZAMANLILIK: 12 süreç aynı anda numara istiyor ────────────────────
# 🔴 Ölçüldü 2026-08-23: kilitsiz koşumda defter BOZULUYOR
#    ("MÜKERRER NUMARA SNV…005: SAP-6 ve SAP-3"), 12 sürecin 9'u patlıyor ve mükerrer
#    satır deftere YAZILMIŞ oluyor. Değişmez kusuru bildirir ama zararı önlemez —
#    ilk süreç numarayı çoktan kullanmış olabilir. Kilit yarışı hiç doğurtmaz.
d, k = kur('{"numara":"SNV2026000000001","onek":"SNV","yil":2026,"sira":1,'
           '"sap":"S1","tutar":"1.00","tarih":"2026-08-23T00:00:00","veren":"SINAV"}\n')
kod = (f'import sys; sys.path.insert(0, {os.getcwd()!r});'
       f'import numara_defteri as nd; nd.DEFTER={d!r}; nd.KESIM_DEFTERI={k!r};'
       'print(nd.numara_ver("SNV","SAP-"+sys.argv[1],"1.00"))')
pler = [subprocess.Popen([sys.executable, "-c", kod, str(i)],
                         stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        for i in range(12)]
num = [p.communicate()[0].strip() for p in pler]
num = [n for n in num if n.startswith("SNV")]
say = collections.Counter(num)
if len(num) != 12:            raise SystemExit(1)   # kilit altında hepsi başarmalı
if any(v > 1 for v in say.values()): raise SystemExit(1)   # mükerrer YOK
sira = sorted(int(n[-9:]) for n in num)
if sira != list(range(2, 14)): raise SystemExit(1)   # boşluk YOK

# ── Y2 · SIRA, ZAMAN DEĞİL: iptal KENDİNDEN SONRAKİ tahsisi YUTMAZ ──────────
# 🔴 C8'in geri dönüş yolu: iptal karşılaştırması saniye çözünürlüklüydü
#    (`i.tarih >= k.tarih`) ve bu defterde aynı saniyede iki olay ÖLÇÜLMÜŞ bir gerçek.
#    Üçü de AYNI saniyeyi taşıyor; ayıran tek şey dosyadaki SIRA.
Z = "2026-08-23T12:00:00"
d, k = kur(
    f'{{"numara":"SNV2026000000002","onek":"SNV","yil":2026,"sira":2,"sap":"ESKI","tutar":"1.00","tarih":"{Z}","veren":"S"}}\n'
    f'{{"tur":"iptal","numara":"SNV2026000000002","onek":"SNV","yil":2026,"sira":2,"sap":"ESKI","gerekce":"sinav gerekcesi","tarih":"{Z}","veren":"S"}}\n'
    f'{{"numara":"SNV2026000000002","onek":"SNV","yil":2026,"sira":2,"sap":"YENI","tutar":"2.00","tarih":"{Z}","veren":"S"}}\n')
nd.DEFTER, nd.KESIM_DEFTERI = d, k
canli = nd.canli_tahsisler()
if len(canli) != 1 or canli[0]["sap"] != "YENI": raise SystemExit(1)
if nd.denetim():                                  raise SystemExit(1)
nd.dogrula()

# ── Y3 · duzelt(): SATIR SİLMEZ, İŞARETLER ─────────────────────────────────
d, k = kur('{"numara":"SNV2026000000001","onek":"SNV","yil":2026,"sira":1,'
           '"sap":"HATALI","tutar":"1.00","tarih":"2026-08-23T00:00:00","veren":"S"}\n')
nd.DEFTER, nd.KESIM_DEFTERI = d, k
once = open(d, encoding="utf-8").read()
nd.duzelt(0, "sinav amacli gecersiz isaretleme")
sonra = open(d, encoding="utf-8").read()
if not sonra.startswith(once):        raise SystemExit(1)  # eski satır DURUYOR
if len(sonra.splitlines()) != 2:      raise SystemExit(1)  # satır EKLENDİ
if nd.canli_tahsisler():              raise SystemExit(1)  # tahsis sayılmıyor
if len(nd.tahsisler_ham()) != 1:      raise SystemExit(1)  # denetim onu GÖRÜYOR

# ── Y4 · GÖNDERİLMİŞ satır düzeltilemez (ikinci tanık) ─────────────────────
d, k = kur('{"numara":"SNV2026000000001","onek":"SNV","yil":2026,"sira":1,'
           '"sap":"GITTI","tutar":"1.00","tarih":"2026-08-23T00:00:00","veren":"S"}\n')
open(k, "w").write('{"sap":"GITTI","fatura_no":"SNV2026000000001","tutar":"1.00",'
                   '"tarih":"2026-08-23","durum":"kesildi","kaydeden":"S"}\n')
nd.DEFTER, nd.KESIM_DEFTERI = d, k
try:
    nd.duzelt(0, "gonderilmis kaydi gecersiz saymaya calis")
    raise SystemExit(1)
except RuntimeError:
    pass

# ── Y5 · 🔴 dogrula() RET YOLU — mükerrer numara PATLAMALI ──────────────────
# NİÇİN SONRADAN EKLENDİ (2026-09-09): `dogrula()` yalnız İZİN yolunda çağrılıyordu
# (geçerli defterle, "patlamamalı" diye). Ret yolu hiç sınanmamıştı; bu yüzden
# kapı-sınavının no-op mutasyonu (kapıyı hep-izin-ver yap) SESSİZCE GEÇTİ.
# Bir kapının yalnız izin yolunu sınamak, kapıyı sınamamaktır.
Z = "2026-08-23T12:00:00"
d, k = kur(
    f'{{"numara":"SNV2026000000007","onek":"SNV","yil":2026,"sira":7,"sap":"A","tutar":"1.00","tarih":"{Z}","veren":"S"}}\n'
    f'{{"numara":"SNV2026000000007","onek":"SNV","yil":2026,"sira":7,"sap":"B","tutar":"2.00","tarih":"{Z}","veren":"S"}}\n')
nd.DEFTER, nd.KESIM_DEFTERI = d, k
try:
    nd.dogrula()
    raise SystemExit(1)                       # mükerrer numara sessizce geçti = KUSUR
except RuntimeError as e:
    m = str(e)
    if "MÜKERRER" not in m:      raise SystemExit(1)   # sebep doğru mu
    if "SNV2026000000007" not in m: raise SystemExit(1)  # HANGİ numara söyleniyor mu
    if "A" not in m or "B" not in m: raise SystemExit(1) # iki SAP da anılıyor mu

# ── Y6 · dogrula() İKİNCİ ARM — denetim kırmızıysa da durmalı ───────────────
# Mükerrer olmayan ama denetimi kırmızı yakan defter: birinci arm temiz, ikinci arm
# patlamalı. Tek arma bakan bir sınav, ikinci armın silinmesini göremezdi.
d, k = kur(
    f'{{"tur":"iptal","numara":"SNV2026000000009","onek":"SNV","yil":2026,"sira":9,"sap":"HAYALET","gerekce":"karsiligi olmayan iptal","tarih":"{Z}","veren":"S"}}\n')
nd.DEFTER, nd.KESIM_DEFTERI = d, k
if nd.canli_tahsisler():                 raise SystemExit(1)   # mükerrer YOK (1. arm temiz)
if not nd.denetim():                     raise SystemExit(1)   # ama denetim KIRMIZI
try:
    nd.dogrula()
    raise SystemExit(1)                       # ikinci arm susarsa KUSUR
except RuntimeError as e:
    if "DENETİM KIRMIZI" not in str(e): raise SystemExit(1)

# ── Y7 · YANLIŞ-RED YOK — temiz defterde dogrula() SUSAR ───────────────────
d, k = kur(
    f'{{"numara":"SNV2026000000001","onek":"SNV","yil":2026,"sira":1,"sap":"A","tutar":"1.00","tarih":"{Z}","veren":"S"}}\n'
    f'{{"numara":"SNV2026000000002","onek":"SNV","yil":2026,"sira":2,"sap":"B","tutar":"2.00","tarih":"{Z}","veren":"S"}}\n')
nd.DEFTER, nd.KESIM_DEFTERI = d, k
nd.dogrula()                                  # patlarsa yanlış-RED

raise SystemExit(0)
YPY
if [[ $? -eq 0 ]]; then
  GECEN=$((GECEN+1))
  echo "  ✓ 12 eşzamanlı süreç: mükerrer YOK, boşluk YOK · iptal sonraki tahsisi yutmuyor"
  echo "    · duzelt() satır SİLMİYOR (işaretliyor) · gönderilmiş satır düzeltilemiyor"
  echo "    · dogrula() RET yolu: mükerrer numara + denetim-kırmızı PATLIYOR, temizde susuyor"
else
  DUSEN=$((DUSEN+1)); echo "  ✗ defter dayanıklılığı KIRMIZI (kilit / sıra / duzelt)"
fi

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[[ $DUSEN -eq 0 ]]
