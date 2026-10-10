#!/usr/bin/env bash
# miktar_birim.test.sh — sözlük kalem biçimi: MİKTAR × BİRİM FİYAT.
#
# 🔴 NİÇİN: hat her satırı "1 adet × satır tutarı" diye yazıyordu. Fiş paketinde bu
#    doğruydu (kalem TÜRÜ toplamı), ama adet taşıyan bir faturada belge YANLIŞ GÖRÜNÜR:
#    tutar tutar ama alıcı kaç adet aldığını göremez. Ölçüldü 2026-09-02, gerçek bir
#    şahıs faturası kesilirken (228 adet × 300 TL).
# 🔴 Bu heredoc TIRNAKSIZ ($K genişliyor) → içine BACKTICK YAZMA.
set -uo pipefail
export PYTHONDONTWRITEBYTECODE=1
K="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
g=0; d=0
ok(){ g=$((g+1)); echo "GEC  $*"; }
no(){ d=$((d+1)); echo "DUS  $*"; }

cikti="$(python3 - <<PY 2>/dev/null
import re, sys
from decimal import Decimal as D
sys.path.insert(0, "$K")
from ubl_ortak import Taraf
from fatura_hazirla import belge_kur, kalemleri_coz, KurusHatasi
T = Taraf(unvan="A LTD", vkn="1234567890", vergi_dairesi="VD", il="Mardin",
          ilce="Midyat", adres="Adres 1")
def ret(fn):
    try: fn(); return False
    except KurusHatasi: return True

# ── C · çözümleme ─────────────────────────────────────────────────────────────
c = kalemleri_coz([{"ad": "U", "miktar": 228, "birim": "NIU", "birim_fiyat": "300.00", "oran": 20}], 20)[0]
print("C1", "OK" if (c.miktar, c.birim, c.brut, c.net) == (D("228"), "NIU", "68400.00", D("68400.00")) else "NO")
# tuple bicimi DEGISMEDI: miktar 1, birim C62 (REGRESYON)
t = kalemleri_coz([("U", "1000.00", 20)], 20)[0]
print("C2", "OK" if (t.miktar, t.birim) == (D("1"), "C62") else "NO")
# iki tanik: brut ile miktar x fiyat CELISIRSE RET
print("C3", "OK" if ret(lambda: kalemleri_coz(
    [{"ad": "U", "miktar": 2, "birim_fiyat": "100.00", "brut": "300.00"}], 20)) else "NO")
# uyusuyorsa gecer
c2 = kalemleri_coz([{"ad": "U", "miktar": 2, "birim_fiyat": "100.00", "brut": "200.00"}], 20)[0]
print("C4", "OK" if c2.brut == "200.00" else "NO")
print("C5", "OK" if ret(lambda: kalemleri_coz([{"ad": "U", "miktar": 0, "birim_fiyat": "10.00"}], 20)) else "NO")
print("C6", "OK" if ret(lambda: kalemleri_coz([{"ad": "U", "miktar": -3, "birim_fiyat": "10.00"}], 20)) else "NO")
print("C7", "OK" if ret(lambda: kalemleri_coz([{"ad": "U", "miktar": 2}], 20)) else "NO")   # ne brut ne fiyat

# ── U · UBL: adet ve birim BELGEYE yazılıyor mu ───────────────────────────────
kalemler = [{"ad": "Urun A", "miktar": 228, "birim": "NIU", "birim_fiyat": "300.00", "oran": 20},
            {"ad": "Urun B", "miktar": 290, "birim": "NIU", "birim_fiyat": "600.00", "oran": 20}]
mat = D("68400") + D("174000"); kdv = mat / 5
xml, oz = belge_kur(kalemler=kalemler, dayanak_toplam=str(mat + kdv),
                    dayanak_kaynagi="insan_beyani", dayanak_kirilimi=(str(mat), str(kdv)),
                    sap="S", fatura_no="FGW2026000000999", tarih="2026-09-02",
                    duzenleyen=T, muhatap=T)
mik = re.findall(r'<cbc:InvoicedQuantity unitCode="([^"]*)">([^<]*)</', xml)
fi = re.findall(r"<cbc:PriceAmount[^>]*>([^<]*)</", xml)
tut = re.findall(r"<cbc:LineExtensionAmount[^>]*>([^<]*)</", xml)
print("U1", "OK" if mik == [("NIU", "228.00"), ("NIU", "290.00")] else "NO")
print("U2", "OK" if fi == ["300.00", "600.00"] else "NO")            # BİRİM fiyat, satır tutarı değil
print("U3", "OK" if tut[:1] == ["242400.00"] and "68400.00" in tut else "NO")
print("U4", "OK" if oz["odenecek"] == mat + kdv else "NO")
# tuple bicimi hala 1 adet (REGRESYON)
x2, _ = belge_kur(kalemler=[("U", "1000.00")], dayanak_toplam="1200.00",
                  dayanak_kaynagi="insan_beyani", sap="S", fatura_no="FGW2026000000998",
                  tarih="2026-09-02", duzenleyen=T, muhatap=T)
print("U5", "OK" if re.findall(r'<cbc:InvoicedQuantity unitCode="([^"]*)">([^<]*)</', x2)
                    == [("C62", "1.00")] else "NO")
# ÜRÜN KAPISI: satır tutarı miktar x fiyat ile tutmalı — fiyatı boz
print("U6", "OK" if ret(lambda: belge_kur(
    kalemler=[{"ad": "U", "miktar": 2, "birim_fiyat": "100.00", "brut": "250.00", "oran": 20}],
    dayanak_toplam="300.00", dayanak_kaynagi="insan_beyani", sap="S",
    fatura_no="FGW2026000000997", tarih="2026-09-02", duzenleyen=T, muhatap=T)) else "NO")
PY
)"
for t in C1 C2 C3 C4 C5 C6 C7 U1 U2 U3 U4 U5 U6; do
  s="$(printf '%s\n' "$cikti" | grep "^$t " || true)"
  case "$s" in "$t OK") ok "$t";; "") no "$t — çıktı YOK";; *) no "$t — $s";; esac
done
echo "── miktar_birim: geçen=$g düşen=$d"
[ "$d" -eq 0 ]
