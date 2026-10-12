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
assert 'ALIAS=urn:mail:defaultpk@ornekfirma' in zarf_kur('sid', pk, 'urn:mail:defaultpk@ornekfirma')"
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
NS = ('xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" '
      'xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"')
f = pathlib.Path(tempfile.mkdtemp()) / "a.xml"
# Numarali sentetik belge: ad artik DOSYA ADINDAN degil cbc:ID den turuyor.
f.write_bytes(f"<Invoice {NS}><cbc:ID>FTR0000000000001</cbc:ID></Invoice>".encode())
rc = elogo_gonder._main([str(f)])            # bayraksız
raise SystemExit(0 if rc == 0 else 1)
PY
rc=$?
if [[ $rc -eq 0 ]]; then GECEN=$((GECEN+1)); echo "  ✓ bayraksız çağrı ağa ÇIKMADI ve rc=0"
else DUSEN=$((DUSEN+1)); echo "  ✗ bayraksız çağrı ağa çıktı ya da düştü (rc=$rc)"; fi

# ── 🔴 RET DALLARI: her dalın KENDİ rc'si ve KENDİ sınav satırı ──────────────
# DERS (2026-08-23, derin kazı · D1/K3): bu sınav eskiden TEK vaka ile "onaysız gönderim
# rc=3 ile durur" diyordu. ALIAS kapısı (2026-08-22) onay kapısının ÖNÜNE eklenince rc
# 7'ye döndü ve sınav KIRMIZI kaldı — kimse koşmadığı için fark edilmedi.
# Kapı davranışı hep güvenliydi; bozulan SINAVIN KESİNLİĞİ idi.
# 🔴 Kural: KAPI SIRASI DA BİR SÖZLEŞMEDİR. Sınav çıkış koduna bağlıysa, araya giren her
#    yeni kapı o sözleşmeyi kırar. Bu yüzden aşağıda hem her dal ayrı ayrı, hem de
#    DALLARIN SIRASI ayrıca sınanır — yeni bir kapı araya girerse hangi satırın kırıldığı
#    doğrudan görünür ve "sınavı gerçeğe uydur" yerine "sırayı bilinçli seç" kararı çıkar.
ret_dali(){   # ret_dali "<ad>" <beklenen-rc> [ek argümanlar...]
  local ad="$1" bek="$2"; shift 2
  python3 - "$bek" "$@" <<'RETPY' >/dev/null 2>&1
import sys, pathlib, tempfile
sys.path.insert(0, ".")
import elogo_soap
# 🔴 Ağ katmanı sabote edildi: herhangi bir kapı sızdırırsa sınav patlar, sessizce geçmez.
elogo_soap._cagir = lambda *a, **k: (_ for _ in ()).throw(AssertionError("AĞA ÇIKTI"))
elogo_soap.login = lambda *a, **k: (_ for _ in ()).throw(AssertionError("AĞA ÇIKTI"))
import elogo_gonder
bek = int(sys.argv[1])
f = pathlib.Path(tempfile.mkdtemp()) / "a.xml"; f.write_bytes(b'<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"><cbc:ID>FTR0000000000001</cbc:ID></Invoice>')  # numarali: ad belgeden turer (#280)
rc = elogo_gonder._main([str(f), "--gercekten-gonder", *sys.argv[2:]])
raise SystemExit(0 if rc == bek else 1)
RETPY
  local rc=$?
  if [[ $rc -eq 0 ]]; then GECEN=$((GECEN+1)); echo "  ✓ $ad (rc=$bek, ağa çıkmadan)"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad — beklenen rc=$bek gelmedi"; fi
}

ONAY='23.08.2026 Sultan: "sinav amacli onay beyani"'
IYI_ALIAS='urn:mail:defaultpk@ornekfirma'

echo "K5 · ALIAS kapısı (rc=7) — dört yönden"
ret_dali "alias YOK → RET"             7
ret_dali "alias biçimsiz → RET"        7 --alias "sinav@ornek"
ret_dali "alias İRSALİYE kutusu → RET" 7 --alias "urn:mail:irsaliye@ornekfirma" --sultan-onayi "$ONAY"
ret_dali "alias boş dizge → RET"       7 --alias "" --sultan-onayi "$ONAY"

echo "K3b · ONAY kapısı (rc=3) — alias geçerliyken üç yönden"
ret_dali "onaysız gönderim → RET"      3 --alias "$IYI_ALIAS"
ret_dali "yer-tutucu onay → RET"       3 --alias "$IYI_ALIAS" --sultan-onayi "TODO"
ret_dali "TARİHSİZ onay → RET"         3 --alias "$IYI_ALIAS" --sultan-onayi "Sultan gonderilmesini onayladi"

echo "🔒 SIRA SÖZLEŞMESİ — bu satır kırılırsa araya yeni bir kapı girmiştir"
ret_dali "alias kapısı onay kapısından ÖNCE" 7 --sultan-onayi "$ONAY"



echo "K6 · ORTAM KİLİDİ — FAIL-CLOSED (yedi değerle)"
echo "    🔴 ÖLÇÜLMÜŞ KUSUR (2026-08-23): kontrol \`kilit == \"demo\"\` idi — NEGATİF."
echo "    Kilit yok/boş/'demoo'/'prod' iken canlı gönderim AĞA ULAŞIYORDU (4/7 sızdırdı)."
echo "    Portal tarafı aynı işi POZİTİF listeyle yapıp 7/7 durduruyordu; iki kapı aynı"
echo "    hattı koruyup farklı dil konuşuyordu. Artık ikisi de pozitif listeli."
kilit_vaka(){   # kilit_vaka "<ad>" "<kilit-değeri|YOK>" <ağa-ulaşmalı-mı:0|1>
  local ad="$1" deger="$2" bek="$3" kd; kd="$(mktemp -d)/kilit"
  [[ "$deger" == "YOK" ]] || printf '%s' "$deger" > "$kd"
  local cikti; cikti=$(ELOGO_ORTAM_KILIDI="$kd" python3 - <<'KPY' 2>&1
import sys, pathlib, tempfile
sys.path.insert(0, ".")
import elogo_soap
for f in ("_cagir", "login", "kimlik_env"):
    setattr(elogo_soap, f, lambda *a, **k: (_ for _ in ()).throw(AssertionError("AGA-CIKTI")))
import elogo_gonder
x = pathlib.Path(tempfile.mkdtemp()) / "a.xml"; x.write_bytes(b'<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"><cbc:ID>FTR0000000000001</cbc:ID></Invoice>')  # numarali: ad belgeden turer (#280)
sys.exit(elogo_gonder._main([str(x), "--canli", "--gercekten-gonder",
                             "--alias", "urn:mail:defaultpk@ornekfirma",
                             "--sultan-onayi", "23.08.2026 Sultan: sinav"]))
KPY
)
  local ulasti=0; [[ "$cikti" == *"AGA-CIKTI"* ]] && ulasti=1
  if [[ $ulasti -eq $bek ]]; then
    GECEN=$((GECEN+1)); echo "  ✓ kilit=$ad → $([[ $bek -eq 1 ]] && echo 'geçti (beklenen)' || echo 'DURDU')"
  else
    DUSEN=$((DUSEN+1)); echo "  ✗ kilit=$ad → $([[ $ulasti -eq 1 ]] && echo '🔴 AĞA ULAŞTI' || echo 'durdu ama geçmeliydi')"
  fi
}
kilit_vaka "YOK (dosya yok)"  "YOK"     0
kilit_vaka "boş"              ""        0
kilit_vaka "demoo (yazım)"    "demoo"   0
kilit_vaka "prod"             "prod"    0
kilit_vaka "DEMO  (boşluklu)" "DEMO "   0
kilit_vaka "demo"             "demo"    0
# 🔴 Karşı-vaka: tanınan 'canli' değeri GEÇMELİ. Yoksa muhafızı 'her şeyi reddet' yapıp
#    sınav yeşile boyanır — aşırı-daraltma kapanı (muhafiz.test.sh C bölümünün kardeşi).
kilit_vaka "canli"            "canli"   1

echo "AD · 🔴 paket adı belgeden türer, dosya adına düşmez (gövde kusuru)"
python3 - <<'PY' >/dev/null 2>&1
import sys, pathlib, tempfile
sys.path.insert(0, ".")
import elogo_soap
elogo_soap._cagir = lambda *a, **k: (_ for _ in ()).throw(AssertionError("AĞA ÇIKTI"))
import elogo_gonder
# Numarasız/kimliksiz belge: eskiden dosya adına düşerdi (kusur), şimdi DURUR.
f = pathlib.Path(tempfile.mkdtemp()) / "cok-uzun-bir-dosya-adi.xml"
f.write_bytes(b"<Invoice/>")
rc = elogo_gonder._main([str(f)])
raise SystemExit(0 if rc == 1 else 1)
PY
rc=$?
if [[ $rc -eq 0 ]]; then GECEN=$((GECEN+1)); echo "  ✓ numarasız belgede ad UYDURULMADI, gönderim DURDU"
else DUSEN=$((DUSEN+1)); echo "  ✗ numarasız belgede dosya adına düşülmüş (rc=$rc)"; fi

python3 - <<'PY' >/dev/null 2>&1
import sys, pathlib, tempfile
sys.path.insert(0, ".")
import elogo_soap
elogo_soap._cagir = lambda *a, **k: (_ for _ in ()).throw(AssertionError("AĞA ÇIKTI"))
import elogo_gonder
# Açıkça verilmiş UZUN ad: ret ağa çıkmadan, numara harcanmadan düşer.
f = pathlib.Path(tempfile.mkdtemp()) / "a.xml"
f.write_bytes(b"<Invoice/>")
rc = elogo_gonder._main([str(f), "--belge-adi", "A" * 52])
raise SystemExit(0 if rc == 1 else 1)
PY
rc=$?
if [[ $rc -eq 0 ]]; then GECEN=$((GECEN+1)); echo "  ✓ uzun ad AĞA ÇIKMADAN reddedildi"
else DUSEN=$((DUSEN+1)); echo "  ✗ uzun ad kapıdan geçti (rc=$rc)"; fi

python3 - <<'PY' >/dev/null 2>&1
import sys, pathlib, tempfile
sys.path.insert(0, ".")
import elogo_soap
elogo_soap._cagir = lambda *a, **k: (_ for _ in ()).throw(AssertionError("AĞA ÇIKTI"))
import elogo_gonder, io, contextlib
NS = ('xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" '
      'xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2"')
f = pathlib.Path(tempfile.mkdtemp()) / "alakasiz-dosya-adi.xml"
f.write_bytes(f"<Invoice {NS}><cbc:ID>FTR0000000000007</cbc:ID></Invoice>".encode())
tampon = io.StringIO()
with contextlib.redirect_stdout(tampon):
    rc = elogo_gonder._main([str(f)])
# Dosya adı "alakasiz-dosya-adi" ama paket adı belgenin numarası olmalı.
ok = rc == 0 and "FTR0000000000007.zip" in tampon.getvalue() \
     and "alakasiz" not in tampon.getvalue()
raise SystemExit(0 if ok else 1)
PY
rc=$?
if [[ $rc -eq 0 ]]; then GECEN=$((GECEN+1)); echo "  ✓ dosya adı alakasızken bile paket adı BELGENİN NUMARASI"
else DUSEN=$((DUSEN+1)); echo "  ✗ paket adı belgenin numarasından türemiyor (rc=$rc)"; fi

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[[ $DUSEN -eq 0 ]]
