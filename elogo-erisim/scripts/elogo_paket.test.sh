#!/usr/bin/env bash
# elogo_paket.test.sh — paketleyicinin kapıları.
#
# Bu sınav AĞSIZ ve ŞİRKETSİZ koşar: ne e-Logo'ya istek gider, ne gerçek bir
# faturaya dokunur. Paketleme saf hesaptır; sınavı da saf olmalıdır.
#
# En değerli iki kapı P3 ve P4: ikisi de "hash neyin üstünde alınıyor" sorusunu
# kilitler. Bu soru yanlış cevaplanırsa sunucu "özet uyuşmadı" der ve hata
# fatura içeriğinde aranır — yanlış yerde saatler harcanır.
set -uo pipefail
cd "$(dirname "$0")"
GECEN=0; DUSEN=0
kapi() { # kapi <ad> <beklenen-rc> <python-ifade>
  local ad="$1" bek="$2" kod="$3"
  python3 -c "$kod" >/dev/null 2>&1; local rc=$?
  if [[ $rc -eq $bek ]]; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad (rc=$rc, beklenen=$bek)"; fi
}
O='import sys; sys.path.insert(0,"."); from elogo_paket import paketle, zip_kur, belge_adini_turet, AD_TAVANI, PaketHatasi'
# Sentetik UBL: gerçek bir faturaya, gerçek numaraya, gerçek müşteriye DOKUNMAZ.
NS='xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"'

echo "A · alan sözleşmesi"
kapi "dört alan da üretilir" 0 "$O
p = paketle(b'<x/>', 'a')
assert set(p) == {'fileName','binaryData','contentType','hash','currentDate'}, p"
kapi "zip adı belge adından türer" 0 "$O
assert paketle(b'<x/>','abc')['fileName'] == 'abc.zip'"
kapi "contentType sabit 'base64'" 0 "$O
assert paketle(b'<x/>','a')['contentType'] == 'base64'"

echo "B · 🔴 özetin doğru tarafı (asıl kapı)"
kapi "P3 · MD5 ZIP baytları üstünde, base64 üstünde DEĞİL" 0 "$O
import base64, hashlib
p = paketle(b'<x/>','a')
ham = base64.b64decode(p['binaryData'])
assert p['hash'] == hashlib.md5(ham).hexdigest().upper(), 'zip baytlarının MD5i değil'
assert p['hash'] != hashlib.md5(p['binaryData'].encode()).hexdigest().upper(), 'base64ün MD5i olmuş'"
kapi "P4 · özet MD5, SHA-256 değil (32 hane hex)" 0 "$O
h = paketle(b'<x/>','a')['hash']
assert len(h) == 32 and all(c in '0123456789ABCDEF' for c in h), h"

echo "C · determinizm (aynı fatura → aynı özet)"
kapi "iki paketleme aynı hash verir" 0 "$O
from datetime import date
a = paketle(b'<x/>','a', date(2026,1,1)); b = paketle(b'<x/>','a', date(2026,1,1))
assert a['hash'] == b['hash'] and a['binaryData'] == b['binaryData']"
kapi "içerik değişince hash değişir" 0 "$O
assert paketle(b'<x/>','a')['hash'] != paketle(b'<y/>','a')['hash']"

echo "D · zip gerçekten zip mi"
kapi "çıktı açılabilir bir zip ve XML içeriyor" 0 "$O
import base64, io, zipfile
p = paketle(b'<Invoice/>','fatura')
z = zipfile.ZipFile(io.BytesIO(base64.b64decode(p['binaryData'])))
assert z.namelist() == ['fatura.xml'], z.namelist()
assert z.read('fatura.xml') == b'<Invoice/>'"

echo "E · fail-closed (eksikse paket ÜRETİLMEZ)"
kapi "boş xml reddedilir" 1 "$O
try: paketle(b'','a')
except PaketHatasi: raise SystemExit(1)"
kapi "boşluk-xml reddedilir" 1 "$O
try: paketle(b'   ','a')
except PaketHatasi: raise SystemExit(1)"
kapi "boş belge adı reddedilir" 1 "$O
try: paketle(b'<x/>','  ')
except PaketHatasi: raise SystemExit(1)"
kapi "adda yol ayracı reddedilir" 1 "$O
try: paketle(b'<x/>','../kacis')
except PaketHatasi: raise SystemExit(1)"
kapi "str verilirse reddedilir (kodlama belirsizliği)" 1 "$O
try: paketle('<x/>','a')
except PaketHatasi: raise SystemExit(1)"
kapi "boş zip reddedilir" 1 "$O
try: zip_kur({})
except PaketHatasi: raise SystemExit(1)"
kapi "boş içerikli belge reddedilir" 1 "$O
try: zip_kur({'a.xml': b''})
except PaketHatasi: raise SystemExit(1)"

echo "F · ağsızlık ve şirketsizlik (mutasyon kanıtı)"
kapi "modül ağ kitaplığı import ETMEZ" 0 "$O
import elogo_paket, inspect
k = inspect.getsource(elogo_paket)
for yasak in ('urllib','requests','http.client','socket'):
    assert yasak not in k, yasak"
kapi "modülde firma/VKN izi YOK" 0 "$O
import elogo_paket, inspect, re
k = inspect.getsource(elogo_paket)
assert not re.search(r'\b[0-9]{10,11}\b', k), 'VKN/TCKN benzeri sayı var'"

echo "G · 🔴 paket adı belgenin KENDİ kimliğinden türer (gövde kusuru)"
kapi "G1 · kökteki cbc:ID ad olur" 0 "$O
x = b'<Invoice $NS><cbc:ID>FTR0000000000001</cbc:ID></Invoice>'
assert belge_adini_turet(x) == 'FTR0000000000001', belge_adini_turet(x)"
kapi "G2 · 🔴 İÇ İÇE cbc:ID yutulmaz — kalem sıra numarası ad OLMAZ" 0 "$O
x = b'<Invoice $NS><cbc:ID>FTR0000000000001</cbc:ID>'
x += b'<InvoiceLine><cbc:ID>1</cbc:ID></InvoiceLine></Invoice>'
assert belge_adini_turet(x) == 'FTR0000000000001', belge_adini_turet(x)"
kapi "G2b · 🔴 AYIRT EDİCİ: kökte numara yoksa iç içe olana UZANILMAZ, kimliğe düşülür" 0 "$O
x = b'<Invoice $NS><cbc:UUID>aaaa-bbbb</cbc:UUID>'
x += b'<AccountingSupplierParty><Party><cbc:ID>9999</cbc:ID></Party></AccountingSupplierParty>'
x += b'</Invoice>'
# Agacta arama yapan bir uygulama burada '9999' dondururdu — satici kimligini
# fatura numarasi sanmak, YANLIS ADLA GECEN bir gonderim demektir (sessiz hata).
assert belge_adini_turet(x) == 'aaaa-bbbb', belge_adini_turet(x)"
kapi "G3 · numara yoksa tekil kimliğe (cbc:UUID) düşer" 0 "$O
x = b'<Invoice $NS><cbc:UUID>aaaa-bbbb</cbc:UUID></Invoice>'
assert belge_adini_turet(x) == 'aaaa-bbbb'"
kapi "G4 · 🔴 BOŞ numara = YOK numara (boş ad üretilmez)" 0 "$O
x = b'<Invoice $NS><cbc:ID/><cbc:UUID>aaaa-bbbb</cbc:UUID></Invoice>'
assert belge_adini_turet(x) == 'aaaa-bbbb', belge_adini_turet(x)"
kapi "G5 · numara VARSA kimliğe bakılmaz (sıra kilitli)" 0 "$O
x = b'<Invoice $NS><cbc:UUID>aaaa</cbc:UUID><cbc:ID>FTR0000000000002</cbc:ID></Invoice>'
assert belge_adini_turet(x) == 'FTR0000000000002'"
kapi "G6 · 🔴 ikisi de yoksa DURUR — dosya adına DÜŞMEZ" 1 "$O
try: belge_adini_turet(b'<Invoice $NS/>')
except PaketHatasi: raise SystemExit(1)"
kapi "G7 · yalnız boşluktan oluşan numara yok sayılır" 1 "$O
try: belge_adini_turet(b'<Invoice $NS><cbc:ID>   </cbc:ID></Invoice>')
except PaketHatasi: raise SystemExit(1)"
kapi "G8 · bozuk XML anlaşılır hata verir (çıplak çökme değil)" 1 "$O
try: belge_adini_turet(b'<Invoice')
except PaketHatasi: raise SystemExit(1)"

echo "H · 🔴 uzunluk kapısı — ret ağa çıkmadan ÖNCE düşer"
kapi "H1 · ölçülmüş GEÇEN uzunluk (47, .zip dahil) kabul edilir" 0 "$O
ad = 'A' * (AD_TAVANI - 4)
assert paketle(b'<x/>', ad)['fileName'] == ad + '.zip'
assert len(ad + '.zip') == AD_TAVANI"
kapi "H2 · tavanın bir hane üstü REDDEDİLİR" 1 "$O
try: paketle(b'<x/>', 'A' * (AD_TAVANI - 3))
except PaketHatasi: raise SystemExit(1)"
kapi "H3 · ölçülmüş RET uzunluğu (56) reddedilir" 1 "$O
try: paketle(b'<x/>', 'A' * 52)
except PaketHatasi: raise SystemExit(1)"
kapi "H4 · tavan ölçülmüş değerde, tahminle yükseltilmemiş" 0 "$O
assert AD_TAVANI == 47, AD_TAVANI"
kapi "H5 · adda zarfı bozacak karakter reddedilir (ad artık XML'den geliyor)" 1 "$O
try: paketle(b'<x/>', 'a&b')
except PaketHatasi: raise SystemExit(1)"
kapi "H6 · adda yazdırılamaz karakter reddedilir" 1 "$O
try: paketle(b'<x/>', 'a\\nb')
except PaketHatasi: raise SystemExit(1)"

echo "I · 🔴 ÇAĞIRAN KİM — gövde fiilen bu yolu kullanıyor mu (mutasyon)"
kapi "I1 · gönderici dosya adına (yol.stem) DÜŞMÜYOR" 0 "$O
import re
ham = open('elogo_gonder.py', encoding='utf-8').read().splitlines()
# 🔴 Yorumlar AYIKLANIR: eski kusurlu satır belgelemek için yorumda anılıyor.
#    Desen-eşlemesi niyet görmez, dizgi görür — bu filoda ölçülmüş sahte-blok sınıfı.
k = '\\n'.join(l for l in ham if not l.lstrip().startswith('#'))
assert 'yol.stem' not in k, 'eski kusurlu varsayilan KODDA geri gelmis'"
kapi "I2 · gönderici türeticiyi fiilen çağırıyor" 0 "$O
k = open('elogo_gonder.py', encoding='utf-8').read()
assert 'belge_adini_turet' in k, 'turetici cagrilmiyor — kurdum ama kosmuyor'
assert 'or belge_adini_turet(ham)' in k, 'varsayilan yola baglanmamis'"
kapi "I4 · kuru koşumda ad-türetme dalı ÖLÜ DEĞİL (tek argümanla çağrılabilir)" 0 "$O
import tempfile, pathlib, io, contextlib, elogo_paket
f = pathlib.Path(tempfile.mkdtemp()) / 'alakasiz-uzun-dosya-adi.xml'
f.write_bytes(b'<Invoice $NS><cbc:ID>FTR0000000000009</cbc:ID></Invoice>')
t = io.StringIO()
with contextlib.redirect_stdout(t):
    rc = elogo_paket._main([str(f)])          # ad VERİLMEDİ — türetme dalı
assert rc == 0, rc
assert 'FTR0000000000009.zip' in t.getvalue(), t.getvalue()
assert 'alakasiz' not in t.getvalue()"
kapi "I3 · paketleyicinin kendi kuru koşumu da dosya adına düşmüyor" 0 "$O
import re, inspect, elogo_paket
k = inspect.getsource(elogo_paket)
assert not re.search(r'else\\s+yol\\.stem', k), 'kuru kosumda eski varsayilan duruyor'"

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[[ $DUSEN -eq 0 ]]
