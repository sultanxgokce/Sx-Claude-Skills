#!/usr/bin/env bash
# coklu_kdv.test.sh — kalem başına KDV oranı. Hermetik, ağa çıkmaz.
#
# 🔴 NİÇİN VAR (FAZ 3 envanteri, 2026-08-25): UBL katmanı kalem başına oranı ve
#    `TaxSubtotal` gruplamasını ZATEN destekliyordu (`Kalem.kdv_orani`, oran→grup sözlüğü);
#    üst katman (`topla`/`belge_kur`) tek oran alıyordu. Yani yetenek vardı ama
#    ÇAĞRILMIYORDU — "yazılmış ≠ bağlanmış"ın kendi veri modelimizin içindeki hâli.
set -uo pipefail
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
python3 - <<'PY'
import sys, re, io, contextlib; sys.path.insert(0, ".")
from decimal import Decimal as D
from fatura_hazirla import belge_kur, topla, kalemleri_coz, KurusHatasi
from ubl_ortak import Taraf
G=B=0
def gec(m):
    global G; G+=1; print(f"  ✓ {m}")
def dus(m):
    global B; B+=1; print(f"  ✗ {m}")

BIZ=Taraf(unvan="S LTD",vkn="1234567890",vergi_dairesi="V",il="I",ilce="C",adres="A")
AL =Taraf(unvan="A LTD",vkn="9876543210",il="I",ilce="C",adres="A")
def kur(kalemler, dayanak, oran=20):
    b=io.StringIO()
    with contextlib.redirect_stderr(b):
        x,o = belge_kur(kalemler=kalemler, dayanak_toplam=dayanak, sap="S",
            fatura_no="TST2026000000001", tarih="2026-08-25", duzenleyen=BIZ, muhatap=AL,
            kdv_orani=oran, dayanak_kaynagi="fis_paketi")
    return x, o, b.getvalue()

print("Ç1 · kalem KENDİ oranını taşıyabiliyor mu")
x,o,_ = kur([("A","1000.00",20),("B","1000.00",10)], "2300.00")
gec("KDV 300,00 (200+100)") if str(o["kdv"])=="300.00" else dus(f"KDV {o['kdv']} — tek oran uygulanmış olabilir")
gec("ödenecek 2300,00") if str(o["odenecek"])=="2300.00" else dus(f"ödenecek {o['odenecek']}")

print("\nÇ2 🔴 · BELGE düzeyinde oranlar AYRI gruplanıyor mu (tek torba DEĞİL)")
belge_bloklari = re.findall(r"<cac:TaxTotal>(?:(?!</cac:TaxTotal>).)*?</cac:TaxTotal>", x, re.S)
ust = belge_bloklari[0]
oranlar = re.findall(r"<cbc:Percent>(\d+)</cbc:Percent>", ust)
gec(f"belge TaxTotal'ında iki grup: %{' + %'.join(sorted(oranlar))}") if sorted(oranlar)==["10","20"] \
  else dus(f"gruplama yanlış: {oranlar} (tek torbaya toplanmış olabilir)")
alt = re.findall(r"<cac:TaxSubtotal>.*?<cbc:TaxableAmount[^>]*>([\d.]+).*?<cbc:TaxAmount[^>]*>([\d.]+).*?<cbc:Percent>(\d+)", ust, re.S)
gec("grup tutarları doğru (1000/200/%20 · 1000/100/%10)") if sorted(alt)==sorted(
    [("1000.00","200.00","20"),("1000.00","100.00","10")]) else dus(f"grup tutarları: {alt}")

print("\nÇ3 · GERİYE UYUM — ikili biçim (ad, net) hâlâ çalışıyor")
x2,o2,_ = kur([("A","1000.00"),("B","500.00")], "1800.00")
gec("ikili biçim geçti, KDV 300,00") if str(o2["kdv"])=="300.00" else dus(f"ikili biçim bozuldu: {o2['kdv']}")
gec("tek oranda tek grup yazılıyor") if len(re.findall(r"<cbc:Percent>", re.findall(
    r"<cac:TaxTotal>(?:(?!</cac:TaxTotal>).)*?</cac:TaxTotal>", x2, re.S)[0]))==1 else dus("tek oranda çok grup")

print("\nÇ4 🔴 · KARIŞIK liste SESSİZ geçmiyor (oran vermeyi unutmak gerçek bir hata)")
_,_,uyari = kur([("A","1000.00",10),("B","1000.00")], "2300.00")
gec("karışık listede uyarı basıldı") if "KARIŞIK ORAN" in uyari else dus("karışık liste sessiz geçti")
gec("uyarı hangi kalemin düştüğünü söylüyor") if "B" in uyari else dus("kalem adı yok")
_,_,u2 = kur([("A","1000.00"),("B","1000.00")], "2400.00")
gec("hepsi varsayılansa uyarı YOK (yanlış alarm değil)") if "KARIŞIK ORAN" not in u2 else dus("gereksiz uyarı")

print("\nÇ5 🔴 · SATIRIN ORANI ürün kapısında sınanıyor mu (tutar doğru, oran yanlış)")
# Belgeyi kurup Percent'i bozalım, sonra ürün kapısını doğrudan çağıralım.
import fatura_hazirla as fh
# 🔴 DİKKAT — bu sınav ilk yazıldığında `replace(..., 1)` kullandı ve YANLIŞ YERİ bozdu:
#    ilk `<cbc:Percent>10</cbc:Percent>` BELGE düzeyindeki TaxTotal'dadır, satırdaki değil
#    (ölçüldü: konum 6974 vs InvoiceLine 7984). Kapı doğru davrandı, sınav yanlış ölçtü —
#    ve o yanlış mutasyon GERÇEK bir açığı ortaya çıkardı (belge grubu kapısı, 4b).
#    Ders: mutasyonun HEDEFİNE ulaştığı, uygulandığı kadar önemlidir.
KALEM = [("A","1000.00",20),("B","1000.00",10)]
i_satir = x.index("<cac:InvoiceLine>")
bas, son = x[:i_satir], x[i_satir:]
bozuk = bas + son.replace("<cbc:Percent>10</cbc:Percent>", "<cbc:Percent>1</cbc:Percent>", 1)
assert bozuk != x and bozuk.index("<cbc:Percent>1</cbc:Percent>") > i_satir, "mutasyon SATIRA gitmedi"
try:
    fh.urun_kapisi(bozuk, KALEM, o, 20)
    dus("satır oranı BOZUKKEN ürün kapısı geçirdi")
except KurusHatasi as e:
    gec("bozuk SATIR oranı yakalandı") if "%" in str(e) else dus(f"yanlış sebep: {str(e)[:60]}")

# ve belge düzeyi (4b kapısı) — iki ayrı bozulma, iki ayrı itiraz
# (a) grup ORANI bozulur → belgede o oranda kalem yok
bozuk_oran = x[:i_satir].replace("<cbc:Percent>10</cbc:Percent>", "<cbc:Percent>1</cbc:Percent>", 1) + son
assert bozuk_oran != x, "oran mutasyonu uygulanmadı"
try:
    fh.urun_kapisi(bozuk_oran, KALEM, o, 20); dus("belge grup ORANI bozukken geçirdi")
except KurusHatasi as e:
    gec("bozuk belge grup ORANI yakalandı") if "girdide o oranda kalem YOK" in str(e) \
      else dus(f"yanlış sebep: {str(e)[:70]}")

# (b) grup TUTARI bozulur → grup kendi kalemlerini açıklamıyor  ← 4b'nin tam hedefi
bozuk_tutar = x[:i_satir].replace(
    '<cbc:TaxAmount currencyID="TRY">100.00</cbc:TaxAmount>',
    '<cbc:TaxAmount currencyID="TRY">99.00</cbc:TaxAmount>', 1) + son
assert bozuk_tutar != x, "tutar mutasyonu uygulanmadı"
try:
    fh.urun_kapisi(bozuk_tutar, KALEM, o, 20); dus("belge grup TUTARI bozukken geçirdi")
except KurusHatasi as e:
    gec("grup, kalemlerini açıklamıyorsa DURUYOR (kazara bulunan açık kapandı)") \
      if "açıklamıyor" in str(e) else dus(f"yanlış sebep: {str(e)[:70]}")

print("\nÇ5b 🔴 · YUVARLAMA — gerçek fatura verisi (fikstür kolay hâli seçmişti)")
# 🔴 Bu vaka, kapının ilk sürümünü GERÇEK FATURADA patlatan sayılardır:
#      8297,57 + 1175,74 + 5036,22 = 14509,53
#      kalem başına yuvarlanmış KDV toplamı = 2901,90  ← canlıda kesildi, KABUL EDİLDİ
#      grup matrahı × %20                   = 2901,91  ← 1 kuruş fazla
#    Kapı "matrah × oran" sanıyordu. Sınav fikstürü (1000,00 × %20 = 200,00) yuvarlama
#    farkı ÜRETMEDİĞİ için yeşil kalmıştı; kusuru kuru prova buldu.
#    Ders: fikstür gerçeğin kolay hâlini seçerse, sınav kolay soruyu sorar.
try:
    xg, og, _ = kur([("Malzeme","8297.57"),("Nakliye","1175.74"),("İşçilik","5036.22")], "17411.43")
    gec("gerçek fatura verisi geçiyor (KDV 2901,90)") if str(og["kdv"])=="2901.90" \
      else dus(f"KDV {og['kdv']} — beklenen 2901.90")
    ug = re.findall(r"<cbc:TaxAmount[^>]*>([\d.]+)", re.findall(
        r"<cac:TaxTotal>(?:(?!</cac:TaxTotal>).)*?</cac:TaxTotal>", xg, re.S)[0])
    gec("belge grubu da 2901,90 (2901,91 DEĞİL)") if "2901.90" in ug and "2901.91" not in ug \
      else dus(f"belge grup KDV'si: {ug}")
except KurusHatasi as e:
    dus(f"GERÇEK VERİ REDDEDİLDİ: {str(e)[:100]}")

print("\nÇ6 · geçersiz oran reddediliyor")
for kotu in (-5, 101, 250):
    try:
        topla([("A","100.00",kotu)]); dus(f"oran {kotu} kabul edildi")
    except KurusHatasi: pass
else: gec("aralık dışı üç oran da reddedildi")
try:
    kalemleri_coz([("A",)], 20); dus("tek elemanlı kalem kabul edildi")
except KurusHatasi: gec("bozuk kalem biçimi reddedildi")

print("\nÇ7 · KURUŞ KAPISI çoklu oranda da BİREBİR (yeni yol eskisini gevşetmedi)")
try:
    kur([("A","1000.00",20),("B","1000.00",10)], "2300.01"); dus("1 kuruş fark GEÇTİ")
except KurusHatasi: gec("1 kuruş fark hâlâ durduruluyor")

print(f"\ntoplam={G+B} geçen={G} düşen={B}")
sys.exit(1 if B else 0)
PY
