#!/usr/bin/env bash
# iskonto.test.sh — `cac:AllowanceCharge` hattı.
#
# 🔴 FİKSTÜR GERÇEKTİR, KOLAY HÂL DEĞİL: sayılar gerçek bir gelen e-Faturadan alındı
#    (brüt 62,50 · oran %30 · iskonto 18,75 · net 43,75 · KDV 8,75 · ödenecek 52,50).
#    Bu dosyanın kardeşi `coklu_kdv.test.sh` tam da bu yüzden bir kusuru kaçırmıştı:
#    fikstürü yuvarlama farkı üretmeyen sayılardan seçmişti.
set -uo pipefail
export PYTHONDONTWRITEBYTECODE=1
K="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
g=0; d=0
ok(){ g=$((g+1)); echo "GEC  $*"; }
no(){ d=$((d+1)); echo "DUS  $*"; }

cikti="$(python3 - <<PY 2>/dev/null
# 🔴 Bu heredoc TIRNAKSIZ ($K genisliyor) → icinde BACKTICK KULLANMA:
#    bash onu komut ikamesi sanip calistirir ve 'syntax error' basar.
import re, sys
from decimal import Decimal as D
sys.path.insert(0, "$K")
from ubl_ortak import Kalem, Taraf
from ubl_satis import SatisFaturasi, kur
from fatura_hazirla import belge_kur, kalemleri_coz, topla, urun_kapisi, KurusHatasi

T = Taraf(unvan="A LTD", vkn="1234567890", vergi_dairesi="VD", il="Mardin",
          ilce="Midyat", adres="Adres 1")
def kalem(**f):
    v = dict(ad="Urun", miktar=D("1"), birim="C62", birim_fiyat_kurus=6250, kdv_orani=20,
             iskonto_kurus=1875, iskonto_orani=D("30")); v.update(f); return Kalem(**v)

# ── K · Kalem aritmetiği (GERÇEK sayılar) ─────────────────────────────────────
k = kalem()
print("K1", "OK" if (k.brut_kurus(), k.matrah_kurus(), k.kdv_kurus()) == (6250, 4375, 875) else "NO")
print("K2", "OK" if not k.iskonto_eksikleri() else "NO")
print("K3", "OK" if kalem(iskonto_orani=D("25")).iskonto_eksikleri() else "NO")   # oran tutarı açıklamıyor
print("K4", "OK" if kalem(iskonto_kurus=9999).iskonto_eksikleri() else "NO")      # brütten büyük
print("K5", "OK" if kalem(iskonto_kurus=-1, iskonto_orani=None).iskonto_eksikleri() else "NO")
k0 = kalem(iskonto_kurus=0, iskonto_orani=None, birim_fiyat_kurus=1000)
print("K6", "OK" if (k0.matrah_kurus(), k0.kdv_kurus()) == (1000, 200) else "NO")  # REGRESYON

# ── C · kalemleri_coz biçimleri ───────────────────────────────────────────────
c2 = kalemleri_coz([("A", "100.00")], 20)[0]
c5 = kalemleri_coz([("A", "62.50", 20, "18.75", 30)], 20)[0]
print("C1", "OK" if (c2.brut, c2.oran, c2.iskonto, c2.net) == ("100.00", 20, "0", D("100.00")) else "NO")
print("C2", "OK" if (c5.iskonto, c5.iskonto_orani, c5.net) == ("18.75", D("30"), D("43.75")) else "NO")
def ret(fn):
    try: fn(); return False
    except KurusHatasi: return True
print("C3", "OK" if ret(lambda: kalemleri_coz([("A", "10.00", 20, "20.00")], 20)) else "NO")  # iskonto>brüt
print("C4", "OK" if ret(lambda: kalemleri_coz([("A", "10.00", 20, "-1.00")], 20)) else "NO")  # negatif
print("C5", "OK" if topla([("A", "62.50", 20, "18.75")]) == (D("43.75"), D("8.75"), D("52.50")) else "NO")

# ── U · UBL çıktısı GERÇEK faturayla birebir mi ───────────────────────────────
f = SatisFaturasi(duzenleyen=T, muhatap=T, tarih="2026-08-29", numara_modu="verilen",
                  fatura_no="FGW2026000000999", kalemler=[kalem()])
x = kur(f)
sat = re.search(r"<cac:InvoiceLine>(.*?)</cac:InvoiceLine>", x, re.S).group(1)
belge = x.replace(re.search(r"<cac:InvoiceLine>.*?</cac:InvoiceLine>", x, re.S).group(0), "")
sira = re.findall(r"<(?:cbc|cac):(\w+)", sat)
print("U1", "OK" if sira[:4] == ["ID", "InvoicedQuantity", "LineExtensionAmount", "AllowanceCharge"] else "NO")
print("U2", "OK" if sira.index("AllowanceCharge") < sira.index("TaxTotal") else "NO")
sb = re.sub(r"\s+", " ", re.search(r"<cac:AllowanceCharge>(.*?)</cac:AllowanceCharge>", sat, re.S).group(1)).strip()
print("U3", "OK" if "<cbc:MultiplierFactorNumeric>30.00</cbc:MultiplierFactorNumeric>" in sb else "NO")
print("U4", "OK" if '<cbc:Amount currencyID="TRY">18.75</cbc:Amount>' in sb else "NO")
print("U5", "OK" if "<cbc:ChargeIndicator>false</cbc:ChargeIndicator>" in sb else "NO")
kok = re.findall(r"^  <(?:cbc|cac):(\w+)", belge, re.M)
print("U6", "OK" if kok[-3:] == ["AllowanceCharge", "TaxTotal", "LegalMonetaryTotal"] else "NO")
lmt = re.findall(r"<cbc:(\w+)", re.search(r"<cac:LegalMonetaryTotal>(.*?)</cac:LegalMonetaryTotal>", x, re.S).group(1))
print("U7", "OK" if lmt == ["LineExtensionAmount", "TaxExclusiveAmount", "TaxInclusiveAmount",
                            "AllowanceTotalAmount", "PayableAmount"] else "NO")
tut = lambda y: re.findall(r"<cbc:%s[^>]*>([^<]*)</" % y, x)
print("U8", "OK" if (tut("TaxExclusiveAmount"), tut("TaxInclusiveAmount"),
                     tut("AllowanceTotalAmount"), tut("PayableAmount")) ==
                    (["43.75"], ["52.50"], ["18.75"], ["52.50"]) else "NO")
# REGRESYON: iskontosuz belgede AllowanceCharge HİÇ olmamalı
f0 = SatisFaturasi(duzenleyen=T, muhatap=T, tarih="2026-08-29", numara_modu="verilen",
                   fatura_no="FGW2026000000998",
                   kalemler=[kalem(iskonto_kurus=0, iskonto_orani=None, birim_fiyat_kurus=1000)])
x0 = kur(f0)
print("U9", "OK" if "AllowanceCharge" not in x0 and "AllowanceTotalAmount" not in x0 else "NO")

# 🔴 BAĞLANTI: 'iskonto_eksikleri()' YAZILMIŞ olması yetmez, 'kur()' yolundan
#    ÇAĞRILIYOR olmalı. K3-K5 fonksiyonu DOĞRUDAN çağırıyor; çağrı 'ortak_eksikler()'ten
#    silinse onlar yeşil kalır ve geçersiz iskontolu belge KURULURDU ("yazılmış ≠ bağlanmış").
from ubl_ortak import EksikAlan
def kurulmaz(kk):
    try:
        kur(SatisFaturasi(duzenleyen=T, muhatap=T, tarih="2026-08-29", numara_modu="verilen",
                          fatura_no="FGW2026000000997", kalemler=[kk]))
        return False
    except EksikAlan:
        return True
print("B1", "OK" if kurulmaz(kalem(iskonto_orani=D("25"))) else "NO")     # oran tutarı açıklamıyor
print("B2", "OK" if kurulmaz(kalem(iskonto_kurus=9999)) else "NO")        # brütten büyük

# ── P · ÜRÜN KAPISI — belgeyi bozup yakalıyor mu ──────────────────────────────
GIRDI = [("Urun", "62.50", 20, "18.75", 30)]
ozet = {"matrah": D("43.75"), "kdv": D("8.75"), "odenecek": D("52.50")}
def kapi(xx):
    try: urun_kapisi(xx, GIRDI, ozet, 20); return False
    except KurusHatasi: return True
print("P0", "OK" if not kapi(x) else "NO")                                   # sağlam belge GEÇER
print("P1", "OK" if kapi(x.replace(">18.75</cbc:Amount>", ">17.00</cbc:Amount>", 1)) else "NO")
print("P2", "OK" if kapi(re.sub(r"<cbc:AllowanceTotalAmount[^<]*</cbc:AllowanceTotalAmount>", "", x)) else "NO")
print("P3", "OK" if kapi(x.replace("<cbc:ChargeIndicator>false", "<cbc:ChargeIndicator>true", 2)) else "NO")
print("P4", "OK" if kapi(re.sub(r"<cac:AllowanceCharge>(?:(?!</cac:AllowanceCharge>).)*?30\.00.*?</cac:AllowanceCharge>",
                                "", x, flags=re.S)) else "NO")               # satır bloğu silindi
print("P5", "OK" if kapi(x.replace('<cbc:PriceAmount currencyID="TRY">62.50', '<cbc:PriceAmount currencyID="TRY">99.99')) else "NO")
# iskontosuz girdi + iskontolu belge
try:
    urun_kapisi(x, [("Urun", "43.75", 20)], ozet, 20); print("P6", "NO")
except KurusHatasi: print("P6", "OK")
PY
)"
for t in K1 K2 K3 K4 K5 K6 C1 C2 C3 C4 C5 U1 U2 U3 U4 U5 U6 U7 U8 U9 B1 B2 P0 P1 P2 P3 P4 P5 P6; do
  s="$(printf '%s\n' "$cikti" | grep "^$t " || true)"
  case "$s" in "$t OK") ok "$t";; "") no "$t — çıktı YOK";; *) no "$t — $s";; esac
done
echo "── iskonto: geçen=$g düşen=$d"
[ "$d" -eq 0 ]
