#!/usr/bin/env bash
# kurus.test.sh — KURUŞ KURALININ sınavı. Ağa çıkmaz, dosya yazmaz.
#
# 🔴 SULTAN KURALI (2026-08-22 · TOLERANS YOK): fatura toplamı, dayanak fiş paketiyle
#    KURUŞU KURUŞUNA aynı olacak. 1 kuruş fark bile red sebebi olabilir; "ihmal edilebilir
#    fark" diye bir kategori YOKTUR. Kapı gevşetilemez, tolerans parametresi EKLENMEZ.
#
# 🔴 NİÇİN BU SINAV VAR (derin kazı 2026-08-23): kural DÖRT yerde yazılıydı, kapı TEK
#    yerdeydi, sınav SIFIRDI. Üç mercek bağımsız olarak aynı boşluğu gösterdi:
#    **kapı GİRDİYİ sınıyordu, ÜRÜNÜ sınamıyordu.** Kapıdan sonra AYRI bir kod yolu UBL'i
#    üretiyordu ve o yolu kimse denetlemiyordu — aradaki her kusur kapının ARKASINDAN geçerdi.
#
# Üç bölüm:
#   P1 · GİRDİ HİJYENİ — para olmayan değer kapıya hiç girmez
#   P2 · KAPI          — toplam birebir değilse üretim YOK
#   P3 · ÜRÜN KAPISI   — belgenin KENDİSİ sınanır (kapının göremediği yer)
set -uo pipefail
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
GECEN=0; DUSEN=0

vaka(){  # vaka "<ad>" <beklenen: RET|GEC> <python-ifadesi>
  local ad="$1" bek="$2" kod="$3" cikti rc
  # 🔴 stderr AYRI TUTULUR (2026-08-25): kapının insan-uyarıları stderr'e gider;
  #    stdout burada VERİ kanalıdır (GEC/RET). Karıştırmak sınavı bozdu — ve daha
  #    kötüsü, uyarı metni beklenen değere benzeseydi YANLIŞ YEŞİL verirdi.
  cikti=$(python3 - <<PY 2>/dev/null
import sys
sys.path.insert(0, ".")
from decimal import Decimal as D
from fatura_hazirla import belge_kur, kurus_kapisi, KurusHatasi, urun_kapisi
from ubl_ortak import Taraf
# 🔴 SAHTE TARAFLAR — sınav kutu-yerel türeve BAĞLANMAZ (İ1c: bağımlılık yönü gövde←türev).
#    Eskiden `from mmex_fatura import BIZ, ALICI` diyordu; o dosya kuruma-özel veri taşıdığı
#    için ortak raftan çıkarıldı ve sınav kırıldı. Kırılması DOĞRUYDU: gövdenin sınavı,
#    bir tüzel kişinin kimliğine muhtaç olmamalı.
BIZ = Taraf(unvan="ÖRNEK SATICI LTD", vkn="1234567890", vergi_dairesi="Örnek VD",
            il="Ankara", ilce="Çankaya", adres="Örnek Adres 1")
ALICI = Taraf(unvan="ÖRNEK ALICI AŞ", vkn="9876543210", vergi_dairesi="",
              il="İstanbul", ilce="Kadıköy", adres="Örnek Adres 2")
K = dict(sap="SINAV", fatura_no="TST2026000000001", tarih="2026-08-20",
         duzenleyen=BIZ, muhatap=ALICI,
         dayanak_kaynagi="fis_paketi")   # beyan zorunlu (dayanak.test.sh); kuruş eşitliğine ORTOGONAL
try:
    $kod
    print("GEC")
except KurusHatasi as e:
    print("RET|" + str(e).replace("\n", " ")[:90])
PY
)
  rc="${cikti%%|*}"
  if [[ "$rc" == "$bek" ]]; then
    GECEN=$((GECEN+1)); printf '  ✓ %-46s %s\n' "$ad" "$bek"
  else
    DUSEN=$((DUSEN+1)); printf '  ✗ %-46s beklenen=%s geldi=%s\n' "$ad" "$bek" "$cikti"
  fi
}

echo "P1 · GİRDİ HİJYENİ — para olmayan değer kapıya girmez"
echo "    (ölçüldü: kapı D('100.004')'ü kabul ediyordu; matrah yuvarlanmadığı için"
echo "     D('240.000')==D('240.00') çıkıp YEŞİL yanıyor, gövde ise kuruşa yuvarlayıp"
echo "     satır kırılımını SESSİZCE değiştiriyordu)"
vaka "kalem kuruş-altı basamak taşıyor"        RET 'belge_kur(kalemler=[("A","100.004"),("B","99.996")], dayanak_toplam="240.00", **K)'
vaka "kalem sıfıra yuvarlanacak kadar küçük"   RET 'belge_kur(kalemler=[("A","0.005"),("B","0.005")], dayanak_toplam="0.01", **K)'
vaka "dayanak kuruş-altı basamak taşıyor"      RET 'kurus_kapisi([("A","10.00")], "10.005", dayanak_kaynagi="fis_paketi")'
vaka "kalem sayı değil"                        RET 'kurus_kapisi([("A","abc")], "10.00", dayanak_kaynagi="fis_paketi")'
vaka "temiz para değerleri geçer"              GEC 'kurus_kapisi([("A","10.00"),("B","5.50")], "18.60", dayanak_kaynagi="fis_paketi")'

echo
echo "P2 · KAPI — toplam birebir olmalı, tolerans YOK"
vaka "dayanak 1 kuruş FAZLA → RET"             RET 'kurus_kapisi([("A","10.00")], "12.01", dayanak_kaynagi="fis_paketi")'
vaka "dayanak 1 kuruş EKSİK → RET"             RET 'kurus_kapisi([("A","10.00")], "11.99", dayanak_kaynagi="fis_paketi")'
vaka "birebir eşit → GEÇER"                    GEC 'kurus_kapisi([("A","10.00")], "12.00", dayanak_kaynagi="fis_paketi")'
vaka "çok kalemli küçük fatura üretilebiliyor" GEC 'belge_kur(kalemler=[("Malzeme","5000.00"),("Nakliye","3000.00"),("İşçilik","2000.00")], dayanak_toplam="12000.00", **K)'
vaka "çok kalemli BÜYÜK fatura üretilebiliyor" GEC 'belge_kur(kalemler=[("Malzeme","400000.00"),("Nakliye","300000.00"),("İşçilik","200000.00"),("Yan Ödeme","100000.00")], dayanak_toplam="1200000.00", **K)'
# 🔴 Kuruş-altı farkta hata metni "fark 0.00" DEMEMELİ — o cümle insanı kapıyı görsel
#    hata sanıp aşmaya davet eder. (Bu vaka artık P1'de yakalanıyor; metin kapısı ayrıca sınanır.)
cikti=$(python3 -c "
import sys; sys.path.insert(0,'.')
from decimal import Decimal as D
from fatura_hazirla import KurusHatasi, q
import fatura_hazirla as fh
try:
    fh.kurus_kapisi([('A','10.00')], '12.01', dayanak_kaynagi='fis_paketi')
except KurusHatasi as e:
    print(str(e))")
grep -q "fark 0.01" <<<"$cikti" && { GECEN=$((GECEN+1)); echo "  ✓ hata metni farkı DÜRÜST gösteriyor (fark 0.01)"; } \
  || { DUSEN=$((DUSEN+1)); echo "  ✗ hata metni farkı yanlış gösteriyor: $cikti"; }

echo
echo "P3 · ÜRÜN KAPISI — belgenin KENDİSİ sınanıyor (kapının göremediği yer)"
echo "    Gövde kusurları taklit edilir: kapı YEŞİL yanar, belge BAŞKA şey söyler."
urun_vaka(){  # urun_vaka "<ad>" <RET|GEC> <yama-kodu>
  local ad="$1" bek="$2" yama="$3" cikti rc
  # 🔴 stderr AYRI TUTULUR (2026-08-25): kapının insan-uyarıları stderr'e gider;
  #    stdout burada VERİ kanalıdır (GEC/RET). Karıştırmak sınavı bozdu — ve daha
  #    kötüsü, uyarı metni beklenen değere benzeseydi YANLIŞ YEŞİL verirdi.
  cikti=$(python3 - <<PY 2>/dev/null
import sys
sys.path.insert(0, ".")
from decimal import Decimal as D
import ubl_ortak
from fatura_hazirla import belge_kur, KurusHatasi
from ubl_ortak import Taraf
# 🔴 SAHTE TARAFLAR — sınav kutu-yerel türeve BAĞLANMAZ (İ1c: bağımlılık yönü gövde←türev).
#    Eskiden `from mmex_fatura import BIZ, ALICI` diyordu; o dosya kuruma-özel veri taşıdığı
#    için ortak raftan çıkarıldı ve sınav kırıldı. Kırılması DOĞRUYDU: gövdenin sınavı,
#    bir tüzel kişinin kimliğine muhtaç olmamalı.
BIZ = Taraf(unvan="ÖRNEK SATICI LTD", vkn="1234567890", vergi_dairesi="Örnek VD",
            il="Ankara", ilce="Çankaya", adres="Örnek Adres 1")
ALICI = Taraf(unvan="ÖRNEK ALICI AŞ", vkn="9876543210", vergi_dairesi="",
              il="İstanbul", ilce="Kadıköy", adres="Örnek Adres 2")
K = dict(sap="SINAV", fatura_no="TST2026000000001", tarih="2026-08-20",
         duzenleyen=BIZ, muhatap=ALICI,
         dayanak_kaynagi="fis_paketi")   # beyan zorunlu (dayanak.test.sh); kuruş eşitliğine ORTOGONAL
$yama
try:
    belge_kur(kalemler=[("A","10.00"),("B","5.50")], dayanak_toplam="18.60", **K)
    print("GEC")
except KurusHatasi as e:
    print("RET|" + str(e).replace("\n", " ")[:90])
PY
)
  rc="${cikti%%|*}"
  if [[ "$rc" == "$bek" ]]; then
    GECEN=$((GECEN+1)); printf '  ✓ %-46s %s\n' "$ad" "$bek"
  else
    DUSEN=$((DUSEN+1)); printf '  ✗ %-46s beklenen=%s geldi=%s\n' "$ad" "$bek" "$cikti"
  fi
}
urun_vaka "yama yok → belge üretilir"              GEC ''
# gövde KDV'yi 1 kuruş eksik yazarsa (yuvarlama kipi ayrışması bunu üretir)
urun_vaka "gövde KDV'yi 1 kuruş EKSİK yazıyor"     RET '
_e = ubl_ortak.Kalem.kdv_kurus
ubl_ortak.Kalem.kdv_kurus = lambda self: _e(self) - 1'
# gövde satır tutarını kaydırırsa (toplam TUTAR ama kırılım değişir)
urun_vaka "satır kırılımı kaymış (toplam tutuyor)" RET '
_m = ubl_ortak.Kalem.matrah_kurus
def _kaydir(self):
    v = _m(self)
    return v + 100 if self.ad == "A" else v - 100
ubl_ortak.Kalem.matrah_kurus = _kaydir'
# gövde matrahı büyütürse
urun_vaka "gövde matrahı şişiriyor"                RET '
_m = ubl_ortak.Kalem.matrah_kurus
ubl_ortak.Kalem.matrah_kurus = lambda self: _m(self) + 1'


echo
echo "P4 · BAĞLANMA — ürün kapısını ÇAĞIRAN yol sınanıyor"
echo "    🔴 NİÇİN AYRI BİR BÖLÜM (ölçüldü 2026-08-23): kapi-sinavi'nin 'yer-kaydirma'"
echo "    mutasyonu, kapı ile çağıranı AYNI DOSYADAYSA hem tanımı hem çağrıyı yeniden"
echo "    adlandırıyor → kod tutarlı kalıyor, kapı devrede kalıyor. Sonuç iki yönde de"
echo "    yanlış: sınav adı import ediyorsa ImportError ile 'yakalandı' görünür (YANLIŞ"
echo "    SEBEP), etmiyorsa 'yakalamadı' görünür (YANLIŞ KIRMIZI). İkisi de bağlanmayı"
echo "    ÖLÇMEZ. Gerçek bağlanma sınavı budur: kapıyı sahtele, çağrıldığını KANITLA."
python3 - <<'BPY' >/dev/null 2>&1
import sys
sys.path.insert(0, ".")
from decimal import Decimal as D
import fatura_hazirla as fh
from ubl_ortak import Taraf
# 🔴 SAHTE TARAFLAR — sınav kutu-yerel türeve BAĞLANMAZ (İ1c: bağımlılık yönü gövde←türev).
#    Eskiden `from mmex_fatura import BIZ, ALICI` diyordu; o dosya kuruma-özel veri taşıdığı
#    için ortak raftan çıkarıldı ve sınav kırıldı. Kırılması DOĞRUYDU: gövdenin sınavı,
#    bir tüzel kişinin kimliğine muhtaç olmamalı.
BIZ = Taraf(unvan="ÖRNEK SATICI LTD", vkn="1234567890", vergi_dairesi="Örnek VD",
            il="Ankara", ilce="Çankaya", adres="Örnek Adres 1")
ALICI = Taraf(unvan="ÖRNEK ALICI AŞ", vkn="9876543210", vergi_dairesi="",
              il="İstanbul", ilce="Kadıköy", adres="Örnek Adres 2")
K = dict(sap="SINAV", fatura_no="TST2026000000001", tarih="2026-08-20",
         duzenleyen=BIZ, muhatap=ALICI,
         dayanak_kaynagi="fis_paketi")   # beyan zorunlu (dayanak.test.sh); kuruş eşitliğine ORTOGONAL

# 1) Kapı ÇAĞRILIYOR mu — sahte kapıya düşen çağrıyı say
cagrildi = []
gercek = fh.urun_kapisi
fh.urun_kapisi = lambda xml, kalemler, ozet, kdv_orani=20: cagrildi.append(1)
fh.belge_kur(kalemler=[("A", "10.00")], dayanak_toplam="12.00", **K)
if len(cagrildi) != 1:
    raise SystemExit(1)

# 2) Kapı ÜRETİLEN BELGEYİ mi alıyor — eline geçen xml, dönen xml ile aynı olmalı
gelen = {}
fh.urun_kapisi = lambda xml, kalemler, ozet, kdv_orani=20: gelen.update(xml=xml, ozet=ozet)
xml, ozet = fh.belge_kur(kalemler=[("A", "10.00")], dayanak_toplam="12.00", **K)
if gelen.get("xml") != xml or gelen.get("ozet") != ozet:
    raise SystemExit(1)

# 3) Kapı İTİRAZ EDERSE belge DÖNMEMELİ — "ürettim ama uyarı verdim" olmaz
fh.urun_kapisi = lambda *a, **k: (_ for _ in ()).throw(fh.KurusHatasi("sahte itiraz"))
try:
    fh.belge_kur(kalemler=[("A", "10.00")], dayanak_toplam="12.00", **K)
    raise SystemExit(1)          # belge döndü = kapı tavsiye niteliğinde, kapı değil
except fh.KurusHatasi:
    pass
fh.urun_kapisi = gercek
raise SystemExit(0)
BPY
if [[ $? -eq 0 ]]; then
  GECEN=$((GECEN+1)); echo "  ✓ belge_kur ürün kapısını çağırıyor · belgeyi ona veriyor · itirazında belge DÖNMÜYOR"
else
  DUSEN=$((DUSEN+1)); echo "  ✗ ürün kapısı BAĞLI DEĞİL ya da itirazı belgeyi durdurmuyor"
fi

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[[ $DUSEN -eq 0 ]]
