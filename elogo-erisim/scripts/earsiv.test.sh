#!/usr/bin/env bash
# earsiv.test.sh — e-ARŞİV belgesi (e-Fatura mükellefi OLMAYAN alıcı).
#
# 🔴 BİÇİM UYDURULMADI: kendi 12 e-Arşiv faturamızdan ölçüldü (2026-09-09).
#    Fark yalnız senaryo değil: IssueTime + üç ek AdditionalDocumentReference.
# 🔴 Bu heredoc TIRNAKSIZ ($K genişliyor) → içine BACKTICK YAZMA.
set -uo pipefail
export PYTHONDONTWRITEBYTECODE=1
K="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
g=0; d=0
ok(){ g=$((g+1)); echo "GEC  $*"; }
no(){ d=$((d+1)); echo "DUS  $*"; }

cikti="$(python3 - <<PY 2>/dev/null
import re, sys
sys.path.insert(0, "$K")
from ubl_ortak import Taraf, EksikAlan, EARSIV_SENARYO
from fatura_hazirla import belge_kur, KurusHatasi
from elogo_gonder import zarf_kur, alias_dogrula, GonderimHatasi

SATICI = Taraf(unvan="A LTD", vkn="1234567890", vergi_dairesi="VD", il="Mardin",
               ilce="Midyat", adres="Adres 1")
SAHIS = Taraf(unvan="AHMET YILMAZ", vkn="11111111111", vergi_dairesi="", il="Mardin",
              ilce="Midyat", adres="Adres 2", ad="AHMET", soyad="YILMAZ")
ORT = dict(kalemler=[{"ad":"Urun","miktar":1,"birim":"C62","birim_fiyat":"375.00","oran":20}],
           dayanak_toplam="450.00", dayanak_kaynagi="insan_beyani",
           dayanak_kirilimi=("375.00","75.00"), sap="S", fatura_no="FGW2026000000999",
           tarih="2026-08-31", duzenleyen=SATICI, muhatap=SAHIS, belge_turu="satis")

x, _ = belge_kur(**ORT, senaryo=EARSIV_SENARYO, saat="12:00:00")
print("B1", "OK" if "<cbc:ProfileID>EARSIVFATURA</cbc:ProfileID>" in x else "NO")
print("B2", "OK" if "<cbc:IssueTime>12:00:00</cbc:IssueTime>" in x else "NO")
kok = re.findall(r"^  <(?:cbc|cac):(\w+)", x, re.M)
print("B3", "OK" if kok[:12] == ["UBLVersionID","CustomizationID","ProfileID","ID","CopyIndicator",
                                 "UUID","IssueDate","IssueTime","InvoiceTypeCode","Note",
                                 "DocumentCurrencyCode","LineCountNumeric"] else "NO")
ref = [(re.findall(r"<cbc:ID>([^<]*)</", b), re.findall(r"<cbc:DocumentType>([^<]*)</", b))
       for b in re.findall(r"<cac:AdditionalDocumentReference>(.*?)</cac:AdditionalDocumentReference>", x, re.S)]
print("B4", "OK" if [r[0][0] for r in ref[:3]] == ["gonderimSekli","duzenlemeTarihi","EINVOICE"] else "NO")
print("B5", "OK" if [r[1][0] for r in ref[:3]] == ["KAGIT","12:00:00","2"] else "NO")
print("B6", "OK" if ref[3][0][0] == "FGW2026000000999" else "NO")     # XSLT eki EN SONDA
print("B7", "OK" if 'schemeID="TCKN"' in x else "NO")                 # 11 hane -> TCKN

# REGRESYON: e-Fatura yolu DEGISMEDI
xe, _ = belge_kur(**ORT)
print("R1", "OK" if "<cbc:ProfileID>TICARIFATURA</cbc:ProfileID>" in xe else "NO")
print("R2", "OK" if "IssueTime" not in xe else "NO")
print("R3", "OK" if "gonderimSekli" not in xe else "NO")

# KAPILAR
def ret(fn):
    try: fn(); return False
    except (EksikAlan, KurusHatasi, GonderimHatasi): return True
print("K1", "OK" if ret(lambda: belge_kur(**ORT, senaryo=EARSIV_SENARYO, gonderim_sekli="POSTA")) else "NO")
print("K2", "OK" if ret(lambda: belge_kur(**ORT, senaryo=EARSIV_SENARYO, saat="12:00")) else "NO")
print("K3", "OK" if ret(lambda: belge_kur(**ORT, senaryo="UYDURMA")) else "NO")

# GONDERIM zarfi
paket = {"binaryData":"QQ==","contentType":"base64","fileName":"a.zip","hash":"0"*32,
         "currentDate":"2026-09-09"}
za = zarf_kur("S", paket, None, "varsayilan", "EARCHIVE")
print("G1", "OK" if "DOCUMENTTYPE=EARCHIVE" in za else "NO")
# 🔴 AYIRT EDICI (mutasyon 2026-09-09 yakaladi): alias=None verirsem, ALIAS satiri
#    mutasyonlu halde de yazilmaz -> sinav komsuyu olcer. Etiket VEREREK sinanir:
#    e-Arsiv zarfi, etiket verilse BILE onu tasimamalidir (derinlemesine savunma).
zae = zarf_kur("S", paket, "urn:mail:defaultpk@ornekfirma", "varsayilan", "EARCHIVE")
print("G2", "OK" if "ALIAS=" not in zae else "NO")
zf = zarf_kur("S", paket, "urn:mail:defaultpk@ornekfirma", "varsayilan", "EINVOICE")
print("G3", "OK" if "ALIAS=urn:mail:defaultpk@ornekfirma" in zf else "NO")
print("G4", "OK" if ret(lambda: zarf_kur("S", paket, None, "varsayilan", "UYDURMA")) else "NO")
print("G5", "OK" if alias_dogrula(None, True, "EARCHIVE") == 0 else "NO")   # etiketsiz e-Arsiv GECER
print("G6", "OK" if alias_dogrula("urn:mail:defaultpk@ornekfirma", True, "EARCHIVE") == 7 else "NO")  # etiketli e-Arsiv RET
print("G7", "OK" if alias_dogrula(None, True, "EINVOICE") == 7 else "NO")   # etiketsiz e-Fatura RET
PY
)"
for t in B1 B2 B3 B4 B5 B6 B7 R1 R2 R3 K1 K2 K3 G1 G2 G3 G4 G5 G6 G7; do
  s="$(printf '%s\n' "$cikti" | grep "^$t " || true)"
  case "$s" in "$t OK") ok "$t";; "") no "$t — çıktı YOK";; *) no "$t — $s";; esac
done
echo "── earsiv: geçen=$g düşen=$d"
[ "$d" -eq 0 ]
