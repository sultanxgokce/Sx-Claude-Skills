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
O='import sys; sys.path.insert(0,"."); from elogo_paket import paketle, zip_kur, PaketHatasi'

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

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[[ $DUSEN -eq 0 ]]
