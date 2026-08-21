#!/usr/bin/env bash
# elogo_gonder.test.sh — gönderim kapılarının GERÇEKTEN kapalı olduğunun kanıtı.
#
# Bu sınav AĞA ÇIKMAZ. Kanıtlamak istediği tek şey var: dört kapıdan biri
# düştüğünde kod ağa çıkmaya BİLE kalkışmıyor. Bir gönderim kapısının sınavı,
# geçtiği durumları değil, DURDURDUĞU durumları göstermelidir.
set -uo pipefail
cd "$(dirname "$0")"
GECEN=0; DUSEN=0
kapi() {
  local ad="$1" bek="$2" kod="$3"
  python3 -c "$kod" >/dev/null 2>&1; local rc=$?
  if [[ $rc -eq $bek ]]; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad (rc=$rc, beklenen=$bek)"; fi
}
O='import sys; sys.path.insert(0,"."); from elogo_gonder import zarf_kur, onayi_dogrula, GonderimHatasi'
P='from elogo_paket import paketle; pk = paketle(b"<Invoice/>","fatura")'

echo "K3 · onay kapısı (yer-tutucu geçmez)"
for bos in '""' '"   "' '"yok"' '"evet"' '"test"' '"n/a"' '"onay"'; do
  kapi "reddedilir: $bos" 1 "$O
try: onayi_dogrula($bos)
except GonderimHatasi: raise SystemExit(1)"
done
kapi "tarihsiz beyan reddedilir ('tamam gönder' tam 12 karakter — uzunluk yetmez)" 1 "$O
try: onayi_dogrula('tamam gönder')
except GonderimHatasi: raise SystemExit(1)"
kapi "tarihsiz uzun beyan da reddedilir" 1 "$O
try: onayi_dogrula('Sultan gönderilmesini onayladı')
except GonderimHatasi: raise SystemExit(1)"
kapi "gerçek beyan KABUL edilir" 0 "$O
onayi_dogrula('21.08.2026 Sultan: bu faturayı gönder')"

echo "K4 · paket bütünlüğü (yarım paket ağa çıkmaz)"
kapi "eksik alan reddedilir" 1 "$O
$P
del pk['hash']
try: zarf_kur('sid', pk)
except GonderimHatasi: raise SystemExit(1)"
kapi "boş alan reddedilir" 1 "$O
$P
pk['fileName'] = '  '
try: zarf_kur('sid', pk)
except GonderimHatasi: raise SystemExit(1)"
kapi "MD5 olmayan özet reddedilir (SHA-256 kazası)" 1 "$O
$P
import hashlib; pk['hash'] = hashlib.sha256(b'x').hexdigest()
try: zarf_kur('sid', pk)
except GonderimHatasi: raise SystemExit(1)"
kapi "XML'i bozacak etiket reddedilir" 1 "$O
$P
try: zarf_kur('sid', pk, 'urn:mail:<script>')
except GonderimHatasi: raise SystemExit(1)"

echo "Zarf sözleşmesi (ölçülen belgeye uygunluk)"
kapi "DOCUMENTTYPE=EINVOICE hep var" 0 "$O
$P
assert 'DOCUMENTTYPE=EINVOICE' in zarf_kur('sid', pk)"
kapi "etiket verilmezse ALIAS satırı YOK (belge s.5 kuralı)" 0 "$O
$P
assert 'ALIAS' not in zarf_kur('sid', pk)"
kapi "etiket verilirse ALIAS satırı var" 0 "$O
$P
assert 'ALIAS=urn:mail:x@y.com' in zarf_kur('sid', pk, 'urn:mail:x@y.com')"
kapi "dizi ad-alanı yerinde bildirilir" 0 "$O
$P
assert 'schemas.microsoft.com/2003/10/Serialization/Arrays' in zarf_kur('sid', pk)"
kapi "dört belge alanı da zarfta" 0 "$O
$P
z = zarf_kur('sid', pk)
for alan in ('binaryData','contentType','currentDate','fileName','hash'):
    assert f'<d:{alan}>' in z or f'<d:{alan}>' in z, alan"

echo "🔴 e-Arşiv 2FA yolu bilerek YOK"
kapi "EARCHIVETYPE2 kodda geçmiyor (Sultan kararı 21.08.2026)" 0 "$O
import elogo_gonder, inspect
k = inspect.getsource(elogo_gonder)
govde = k[k.index('def zarf_kur'):]
assert 'EARCHIVETYPE2' not in govde and '2FACODE' not in govde"

echo "CLI · kuru koşum varsayılan (en pahalı kapı)"
python3 - <<'PY' >/dev/null 2>&1
import sys, pathlib, tempfile
sys.path.insert(0, ".")
# ağa çıkarsa patlasın: taşıyıcının çağrı fonksiyonunu sabote et
import elogo_soap
elogo_soap._cagir = lambda *a, **k: (_ for _ in ()).throw(AssertionError("AĞA ÇIKTI"))
import elogo_gonder
f = pathlib.Path(tempfile.mkdtemp()) / "a.xml"; f.write_bytes(b"<Invoice/>")
rc = elogo_gonder._main([str(f)])            # bayraksız
raise SystemExit(0 if rc == 0 else 1)
PY
rc=$?
if [[ $rc -eq 0 ]]; then GECEN=$((GECEN+1)); echo "  ✓ bayraksız çağrı ağa ÇIKMADI ve rc=0"
else DUSEN=$((DUSEN+1)); echo "  ✗ bayraksız çağrı ağa çıktı ya da düştü (rc=$rc)"; fi

python3 - <<'PY' >/dev/null 2>&1
import sys, pathlib, tempfile
sys.path.insert(0, ".")
import elogo_soap
elogo_soap._cagir = lambda *a, **k: (_ for _ in ()).throw(AssertionError("AĞA ÇIKTI"))
import elogo_gonder
f = pathlib.Path(tempfile.mkdtemp()) / "a.xml"; f.write_bytes(b"<Invoice/>")
rc = elogo_gonder._main([str(f), "--gercekten-gonder"])   # onaysız
raise SystemExit(0 if rc == 3 else 1)
PY
rc=$?
if [[ $rc -eq 0 ]]; then GECEN=$((GECEN+1)); echo "  ✓ onaysız --gercekten-gonder rc=3 ile DURDU (ağa çıkmadan)"
else DUSEN=$((DUSEN+1)); echo "  ✗ onaysız gönderim durdurulmadı (rc=$rc)"; fi

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[[ $DUSEN -eq 0 ]]
