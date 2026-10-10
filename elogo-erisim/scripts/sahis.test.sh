#!/usr/bin/env bash
# sahis.test.sh — şahıs (TCKN) + iletişim bloklarının sınavı. Hermetik, ağa çıkmaz.
#
# 🔴 NİÇİN VAR: şahsa e-Arşiv kesmenin ön şartı `cac:Contact` (telefon/e-posta) ve
#    gerçek kişide `cac:Person` (ad/soyad). Kimlik tarafı zaten çalışıyordu
#    (11 hane → TCKN); eksik olan bu iki bloktu (FAZ 3 envanteri, 2026-08-25).
#
# 🔴 BU SINAVIN SINIRI — açıkça yazılıyor ki yanlış güven üretmesin:
#    Burada sınanan şey **kodun bu XML'i ürettiği**dir. e-Logo'nun / GİB'in onu KABUL
#    ettiği DEĞİLDİR. Elimizde UBL-TR XSD'si yok ve kabul edilmiş bir şahıs belgesi de
#    yok; eleman SIRASI bir [ANLATI] iddiasıdır, ölçüm değil.
#    İlk gerçek şahıs faturasından ÖNCE `GetDocumentPreView` ile doğrulanmalıdır.
#    Bu sınav o doğrulamanın YERİNE GEÇMEZ; yalnız sırayı REGRESYONA karşı kilitler.
#    (Kendi dersimiz: "eşit ≠ doğrulandı" — kendi ürettiğimizi kendi niyetimize karşı
#     doğrulamak, zincirin öteki ucunu sormamaktır.)
set -uo pipefail
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
python3 - <<'PY'
import sys, re; sys.path.insert(0, ".")
from decimal import Decimal as D
from ubl_ortak import Taraf, Kalem
from ubl_satis import SatisFaturasi, kur
G=B=0
def gec(m):
    global G; G+=1; print(f"  ✓ {m}")
def dus(m):
    global B; B+=1; print(f"  ✗ {m}")

BIZ = Taraf(unvan="SINAV LTD", vkn="1234567890", vergi_dairesi="VD", il="I", ilce="C", adres="A")
def belge(muhatap):
    return kur(SatisFaturasi(duzenleyen=BIZ, muhatap=muhatap, tarih="2026-08-25",
        kalemler=[Kalem(ad="k", miktar=D("1"), birim="C62", birim_fiyat_kurus=10000, kdv_orani=20)],
        numara_modu="elogo"))

print("Ş1 · ŞAHIS — TCKN + ad/soyad + iletişim blokları üretiliyor mu")
sahis = Taraf(unvan="AYSE YILMAZ", vkn="12345678901", il="I", ilce="C", adres="A",
              telefon="+90 000 000 00 00", eposta="ornek@ornek.com", ad="AYŞE", soyad="YILMAZ")
x = belge(sahis)
for etiket, desen in (("TCKN şeması", r'schemeID="TCKN">12345678901'),
                      ("Contact/Telephone", r"<cbc:Telephone>\+90 000 000 00 00"),
                      ("Contact/ElectronicMail", r"<cbc:ElectronicMail>ornek@ornek\.com"),
                      ("Person/FirstName", r"<cbc:FirstName>AYŞE"),
                      ("Person/FamilyName", r"<cbc:FamilyName>YILMAZ")):
    gec(f"{etiket} yazıldı") if re.search(desen, x) else dus(f"{etiket} YOK")

print("\nŞ2 🔴 · ELEMAN SIRASI — UBL katı sıralıdır, yanlış sıra belgeyi REDDETTİRİR")
# Muhatap Party'si içindeki sıra ölçülür (düzenleyende Person yok).
blok = re.search(r"<cac:AccountingCustomerParty>.*?</cac:AccountingCustomerParty>", x, re.S).group(0)
bulunan = re.findall(r"<cac:(PartyIdentification|PartyName|PostalAddress|PartyTaxScheme|Contact|Person)>", blok)
beklenen = ["PartyIdentification", "PartyName", "PostalAddress", "Contact", "Person"]
if bulunan == beklenen:
    gec(f"sıra kilitlendi: {' → '.join(bulunan)}")
else:
    dus(f"SIRA BOZUK\n       beklenen: {beklenen}\n       bulunan : {bulunan}")
gec("Contact, PostalAddress'ten SONRA") if blok.index("<cac:Contact>") > blok.index("<cac:PostalAddress>") \
  else dus("Contact adresten ÖNCE — UBL sırası bozuk")
gec("Person, Contact'tan SONRA") if blok.index("<cac:Person>") > blok.index("<cac:Contact>") \
  else dus("Person Contact'tan ÖNCE — UBL sırası bozuk")

print("\nŞ3 · FİRMA — iletişim verilmediyse blok HİÇ yazılmamalı (boş etiket ≠ yok)")
firma = Taraf(unvan="ALICI LTD", vkn="9876543210", il="I", ilce="C", adres="A")
y = belge(firma)
blok2 = re.search(r"<cac:AccountingCustomerParty>.*?</cac:AccountingCustomerParty>", y, re.S).group(0)
gec("Contact bloğu yok") if "<cac:Contact>" not in blok2 else dus("boş Contact yazılmış")
gec("Person bloğu yok") if "<cac:Person>" not in blok2 else dus("boş Person yazılmış")
gec("firma VKN şeması doğru") if 'schemeID="VKN">9876543210' in y else dus("VKN şeması bozuk")

print("\nŞ4 · KISMİ — yalnız e-posta verilirse yalnız o alan yazılır")
k = Taraf(unvan="K", vkn="12345678901", il="I", ilce="C", adres="A", eposta="a@b.co")
z = belge(k)
gec("Contact açıldı, ElectronicMail var") if "<cbc:ElectronicMail>a@b.co" in z else dus("e-posta yazılmadı")
gec("Telephone yazılmadı (boş etiket yok)") if "<cbc:Telephone>" not in z else dus("boş Telephone yazılmış")

print("\nŞ5 🔴 · BİÇİM SÜZGECİ — bozuk e-posta/telefon YAKALANIR (yokluk değil, BOZUKLUK)")
for alan, deger in (("eposta","ornek.com"), ("eposta","a@b"), ("telefon","abc-def-ghij"), ("telefon","123")):
    kotu = Taraf(unvan="K", vkn="12345678901", il="I", ilce="C", adres="A", **{alan: deger})
    try:
        belge(kotu); dus(f"bozuk {alan}={deger!r} GEÇTİ")
    except Exception as e:
        if "biçimsiz" in str(e): pass
        else: dus(f"{alan}={deger!r} yanlış sebeple durdu: {str(e)[:60]}")
else: gec("dört bozuk biçim de yakalandı")

print("\nŞ6 · YOKLUK reddedilmiyor (ölçmediğimiz zorunluluğu dayatmıyoruz)")
try:
    belge(Taraf(unvan="K", vkn="12345678901", il="I", ilce="C", adres="A"))
    gec("iletişimsiz şahıs belgesi ÜRETİLDİ (zorunluluk iddia edilmiyor)")
except Exception as e: dus(f"iletişimsiz şahıs reddedildi — ölçülmemiş kural dayatıldı: {str(e)[:70]}")

print("\nŞ7 · REGRESYON — firma faturası (mühürlü yol) hiç değişmedi mi")
gec("düzenleyende Person yok") if "<cac:Person>" not in re.search(
    r"<cac:AccountingSupplierParty>.*?</cac:AccountingSupplierParty>", y, re.S).group(0) \
  else dus("düzenleyene Person sızmış")
gec("PartyTaxScheme hâlâ yazılıyor") if "<cac:PartyTaxScheme>" in y else dus("vergi dairesi kayboldu")

print(f"\ntoplam={G+B} geçen={G} düşen={B}")
sys.exit(1 if B else 0)
PY
