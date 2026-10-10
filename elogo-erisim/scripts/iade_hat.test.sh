#!/usr/bin/env bash
# iade_hat.test.sh — `belge_kur(dayanaklar=…)` İADE dalının KAPILARI gerçekten koşuyor mu?
#
# 🔴 NİÇİN VAR: iade belgesi AYRI bir üretim yolundan çıkıyor (`ubl_iade.kur`). Bu dosyanın
#    kendi tarihi, denetlenmeyen ikinci bir üretim yolunun kapının ARKASINDAN geçtiğinin
#    kaydıdır (`urun_kapisi`'nin doğuş gerekçesi). Aynı hatayı iade dalında tekrarlamamak
#    için burada kapıların VARLIĞI değil, ATEŞLEDİĞİ sınanır.
set -uo pipefail
export PYTHONDONTWRITEBYTECODE=1
K="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gec=0; dus=0
gec(){ gec=$((gec+1)); echo "GEC  $*"; }
dus(){ dus=$((dus+1)); echo "DUS  $*"; }

# 🔴 Hermetik (2026-10-10, depoya taşınırken CI'da 8/8 düştü): eskiden MMEx kutusunun backend'ine
#    `cd` ediyor ve kutu-yerel türevi yola ekliyordu; ikisine de ihtiyaç YOK (fatura_hazirla yalnız
#    beceri modüllerini içe alır). Temiz makinede `cd` düşünce betik HİÇ koşmuyordu ("çıktı YOK").
ciktilar="$(cd "$K" && python3 - <<PY 2>/dev/null
import sys
sys.path.insert(0, "$K")
import fatura_hazirla as fh
from fatura_hazirla import belge_kur, Dayanak, KurusHatasi
from ubl_ortak import Taraf   # VKN sentetiktir: ortak rafa gercek VKN yazilmaz (I1)

T = Taraf(unvan="A LTD", vkn="1234567890", vergi_dairesi="VD", il="Mardin",
          ilce="Midyat", adres="Adres 1")
ORT = dict(kalemler=[("Kalem", "2834.83")], dayanak_toplam="3401.80",
           dayanak_kaynagi="fis_paketi", sap="S1", fatura_no="FGW2026000000009",
           tarih="2026-08-27", duzenleyen=T, muhatap=T,
           dayanaklar=[Dayanak(fatura_no="AP02026000000123", tarih="2026-08-13")])

# T1 — meşru iade belgesi kurulur ve İADE damgasını taşır
try:
    xml, ozet = belge_kur(**ORT, dayanak_kirilimi=("2834.83", "566.97"))
    print("T1", "OK" if ("<cbc:InvoiceTypeCode>IADE" in xml.replace("\n", "")
                         or "IADE" in xml) and ozet["odenecek"] == __import__("decimal").Decimal("3401.80") else "NO")
    print("T2", "OK" if "AP02026000000123" in xml else "NO")     # BillingReference yazıldı
    print("T3", "OK" if "2026-08-13" in xml else "NO")           # dayanak TARİHİ yazıldı
    print("T4", "OK" if "İADE FATURASIDIR" in xml else "NO")     # VUK şerhi
except Exception as e:
    print("T1 NO", e); print("T2 NO"); print("T3 NO"); print("T4 NO")

# T5 — KURUŞ/KIRILIM KAPISI iade dalında ATEŞLİYOR mu (mutasyon: KDV 1 kuruş kaydır)
try:
    belge_kur(**ORT, dayanak_kirilimi=("2834.83", "566.98")); print("T5 NO")
except KurusHatasi:
    print("T5 OK")

# T6 — ÜRÜN KAPISI iade dalında ATEŞLİYOR mu (mutasyon: üretilen XML'in tutarını boz)
orij = fh.kur_iade
fh.kur_iade = lambda f: orij(f).replace(">3401.80<", ">3401.81<")
try:
    belge_kur(**ORT); print("T6 NO")
except KurusHatasi:
    print("T6 OK")
finally:
    fh.kur_iade = orij

# T7 — GİB 1150: dayanaksız iade REDDEDİLİR (boş liste iade sayılır ama kurulamaz)
try:
    belge_kur(**{**ORT, "dayanaklar": []}); print("T7 NO")
except Exception:
    print("T7 OK")

# T8 — REGRESYON: dayanaksız çağrı hâlâ SATIŞ üretir (iade dalı satışı yutmadı)
try:
    xml, _ = belge_kur(**{k: v for k, v in ORT.items() if k != "dayanaklar"},
                       dayanak_kirilimi=("2834.83", "566.97"))
    print("T8", "OK" if "İADE FATURASIDIR" not in xml else "NO")
except Exception as e:
    print("T8 NO", e)
PY
)"
for t in T1 T2 T3 T4 T5 T6 T7 T8; do
  satir="$(printf '%s\n' "$ciktilar" | grep "^$t " || true)"
  case "$satir" in
    "$t OK"*) gec "$t";;
    "")       dus "$t — çıktı YOK (betik hiç koşmadı olabilir)";;
    *)        dus "$t — $satir";;
  esac
done
echo "── iade_hat: geçen=$gec düşen=$dus"
[ "$dus" -eq 0 ]
