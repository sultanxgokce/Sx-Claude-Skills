#!/usr/bin/env bash
# ubl_satis.test.sh — SATIŞ faturası kurucusunun kapıları.
#
# En sert kapılar C grubunda: satış ile iadenin BİRBİRİNE KARIŞMAMASI.
# Karışırsa iki yönde de mali sonuç doğar — satış faturasına dayanak eklemek belgeyi
# GİB'e iade gibi göstermeye çalışmaktır; iade faturasından dayanağı düşürmek GİB 1150'dir.
set -uo pipefail
cd "$(dirname "$0")"
GECEN=0; DUSEN=0
kapi(){ local ad="$1" bek="$2" kod="$3"
  python3 -c "$kod" >/dev/null 2>&1; local rc=$?
  if [[ $rc -eq $bek ]]; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad (rc=$rc, beklenen=$bek)"; fi; }

O='import sys; sys.path.insert(0,"."); from decimal import Decimal
from ubl_satis import SatisFaturasi, Taraf, Kalem, kur, sozlukten, SATIS_TIPI
from ubl_ortak import EksikAlan
def tam(**kw):
    d = dict(duzenleyen=Taraf("A LTD","1234567890","VD","Türkiye","Ankara","Çankaya","Adres 1"),
             muhatap=Taraf("B AŞ","0987654321","","Türkiye","İstanbul","Kadıköy","Adres 2"),
             tarih="2026-08-22",
             kalemler=[Kalem("Hizmet", Decimal("2"), "C62", 100000, 20)])
    d.update(kw); return SatisFaturasi(**d)'

echo "A · tam belge kurulur"
kapi "eksik YOK" 0 "$O
assert tam().eksikleri_bul() == [], tam().eksikleri_bul()"
kapi "XML üretilir ve Invoice kökü var" 0 "$O
x = kur(tam()); assert x.startswith('<?xml') and 'Invoice' in x"
kapi "tür kodu SATIS" 0 "$O
assert '<cbc:InvoiceTypeCode>SATIS</cbc:InvoiceTypeCode>' in kur(tam())"

echo "B · para (kuruş, float sızıntısı yok)"
kapi "matrah 2×1000.00 = 2000.00" 0 "$O
assert '<cbc:LineExtensionAmount currencyID=\"TRY\">2000.00</cbc:LineExtensionAmount>' in kur(tam())"
kapi "KDV %20 → 400.00" 0 "$O
assert '400.00' in kur(tam())"
kapi "genel toplam 2400.00" 0 "$O
assert '<cbc:PayableAmount currencyID=\"TRY\">2400.00</cbc:PayableAmount>' in kur(tam())"
kapi "XML'de float artığı ('.00000' / 'e-') yok" 0 "$O
x = kur(tam()); assert '.00000' not in x and 'e-0' not in x"

echo "🔴 C · SATIŞ ⟂ İADE ayrımı (asıl kapı)"
kapi "satışta dayanak referansı YOK" 0 "$O
assert 'BillingReference' not in kur(tam())"
kapi "satışta 'İADE FATURASIDIR' şerhi YOK" 0 "$O
assert 'İADE' not in kur(tam())"
kapi "satış kurucusu dayanak alanı KABUL ETMEZ" 1 "$O
try: tam(dayanaklar=[])
except TypeError: raise SystemExit(1)"
kapi "iade kurucusu hâlâ dayanak İSTER (komşu bozulmadı)" 1 "$O
sys.path.insert(0,'.')
from ubl_iade import IadeFaturasi, kur as ikur
f = IadeFaturasi(duzenleyen=Taraf('A','1234567890','VD','Türkiye','An','Ç','Adr'),
                 muhatap=Taraf('B','0987654321','','Türkiye','İs','K','Adr'),
                 tarih='2026-08-22', kalemler=[Kalem('H', Decimal('1'), 'C62', 1000, 20)])
try: ikur(f)
except EksikAlan: raise SystemExit(1)"

echo "D · numara (e-Logo atar)"
kapi "varsayılan modda cbc:ID BOŞ" 0 "$O
assert '<cbc:ID />' in kur(tam()) or '<cbc:ID></cbc:ID>' in kur(tam())"
kapi "verilen modda numara yazılır" 0 "$O
assert 'FTR2026000000001' in kur(tam(numara_modu='verilen', fatura_no='FTR2026000000001'))"
kapi "verilen mod + numara yoksa REDDEDİLİR" 1 "$O
f = tam(numara_modu='verilen')
try: kur(f)
except EksikAlan: raise SystemExit(1)"

echo "E · fail-closed (eksikse HİÇBİR ŞEY üretilmez)"
kapi "kalemsiz reddedilir" 1 "$O
try: kur(tam(kalemler=[]))
except EksikAlan: raise SystemExit(1)"
kapi "KDV oranı yoksa reddedilir" 1 "$O
try: kur(tam(kalemler=[Kalem('H', Decimal('1'), 'C62', 1000, None)]))
except EksikAlan: raise SystemExit(1)"
kapi "geçersiz VKN reddedilir" 1 "$O
try: kur(tam(muhatap=Taraf('B','123','','Türkiye','','','')))
except EksikAlan: raise SystemExit(1)"
kapi "bozuk tarih reddedilir" 1 "$O
try: kur(tam(tarih='22.08.2026'))
except EksikAlan: raise SystemExit(1)"
kapi "düzenleyenin vergi dairesi zorunlu" 1 "$O
try: kur(tam(duzenleyen=Taraf('A','1234567890','','Türkiye','An','Ç','Adr')))
except EksikAlan: raise SystemExit(1)"
kapi "muhatabın vergi dairesi zorunlu DEĞİL (üretici asimetrisi korunur)" 0 "$O
assert tam().eksikleri_bul() == []"

echo "F · eksikler ADIYLA söylenir"
kapi "eksik listesi alan adını içerir" 0 "$O
e = tam(tarih='').eksikleri_bul()
assert any('tarih' in x for x in e), e"

echo "G · ağsız / şirketsiz (mutasyon kanıtı)"
kapi "modül ağ kitaplığı import ETMEZ" 0 "$O
import ubl_satis, inspect
k = inspect.getsource(ubl_satis)
for y in ('urllib','requests','http.client','socket'): assert y not in k, y"
kapi "modülde firma/VKN izi YOK" 0 "$O
import ubl_satis, inspect, re
assert not re.search(r'\b[0-9]{10,11}\b', inspect.getsource(ubl_satis))"

echo "H · sözlükten kurma (türev paketlerin yolu)"
kapi "JSON sözlüğünden kurulur" 0 "$O
f = sozlukten({'duzenleyen':{'unvan':'A','vkn':'1234567890','vergi_dairesi':'VD','adres':'Adr'},
               'muhatap':{'unvan':'B','vkn':'0987654321'},
               'tarih':'2026-08-22',
               'kalemler':[{'ad':'H','miktar':'1','birim_fiyat_kurus':1000,'kdv_orani':20}]})
assert f.eksikleri_bul() == [], f.eksikleri_bul()
assert 'SATIS' in kur(f)"


echo "R · YUVARLAMA KİPİ — kapı ⟂ gövde aynı kipte mi (regresyon)"
echo "    🔴 ÖLÇÜLMÜŞ KUSUR (2026-08-23): kapı ROUND_HALF_UP, gövde argümansız quantize"
echo "    (= bağlam varsayılanı ROUND_HALF_EVEN = bankacı yuvarlaması) kullanıyordu."
echo "    %20'de beraberlik matematiksel olarak DOĞMADIĞI için hiç görünmedi — yani hattın"
echo "    güvenliği kayıt dışı bir tesadüfe dayanıyordu. %10'da 1000, %1'de 100 değer sapıyordu."
python3 - <<'RPY' >/dev/null 2>&1
import sys
sys.path.insert(0, ".")
from decimal import Decimal as D, ROUND_HALF_UP, getcontext
from ubl_ortak import Kalem

# 1) Bağlam varsayılanı HÂLÂ bankacı yuvarlaması olmalı — yani kipimiz "şans eseri" değil,
#    AÇIKÇA yazıldığı için doğru. Varsayılan bir gün değişirse bu satır bize haber verir.
assert getcontext().rounding == "ROUND_HALF_EVEN", "bağlam varsayılanı değişmiş — notu güncelle"

# 2) Beraberlik (.5 kuruş) üreten değerlerde gövde YUKARI yuvarlamalı.
#    %10 · net 10,05 TL → ham KDV 100,5 kr → 101 olmalı (bankacıda 100 çıkardı)
#    %1  · net 2,50 TL  → ham KDV 2,5 kr   → 3 olmalı   (bankacıda 2 çıkardı)
for kurus, oran, beklenen in ((1005, 10, 101), (250, 1, 3), (50, 1, 1), (150, 1, 2)):
    k = Kalem(ad="x", miktar=D(1), birim="C62", birim_fiyat_kurus=kurus, kdv_orani=oran)
    assert k.kdv_kurus() == beklenen, f"{kurus}kr %{oran}: {k.kdv_kurus()} != {beklenen}"

# 3) TARAMA: üç oran için de gövde ile açık HALF_UP hesabı birebir aynı olmalı.
for oran in (20, 10, 1):
    for kurus in range(1, 20001):
        k = Kalem(ad="x", miktar=D(1), birim="C62", birim_fiyat_kurus=kurus, kdv_orani=oran)
        beklenen = int((D(kurus) * D(oran) / D(100)).quantize(D("1"), rounding=ROUND_HALF_UP))
        if k.kdv_kurus() != beklenen:
            raise SystemExit(f"%{oran} · {kurus}kr: gövde={k.kdv_kurus()} beklenen={beklenen}")
raise SystemExit(0)
RPY
if [[ $? -eq 0 ]]; then GECEN=$((GECEN+1)); echo "  ✓ kapı ile gövde AYNI kipte (%20·%10·%1, 60.000 değer tarandı)"
else DUSEN=$((DUSEN+1)); echo "  ✗ kapı ile gövde farklı yuvarlıyor — sessiz 1 kuruş riski"; fi

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[[ $DUSEN -eq 0 ]]
