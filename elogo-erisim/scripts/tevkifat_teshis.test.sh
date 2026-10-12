#!/usr/bin/env bash
# tevkifat_teshis.test.sh — kuruş kapısının TEVKİFAT teşhisi.
#
# 🔴 NİÇİN VAR: kapı tevkifatlı dayanakta zaten DURUYORDU, ama "fark 40,00" diyordu.
#    Bu cümle YANLIŞ ONARIMA davettir: insan farkı yuvarlama sanıp dayanağı yükseltir
#    ve TEVKİFATSIZ yanlış fatura keser. Aynı desen ortam kilidinde de görüldü:
#    doğru durur, yanlış sebep söyler. Teşhis o boşluğu kapatır.
# 🔴 Teşhis bir TAHMİNDİR — belge yine ÜRETİLMEZ. Sınav bunu ayrıca kilitler (T9).
# 🔴 Bu heredoc TIRNAKSIZ ($K genişliyor) → içine BACKTICK YAZMA.
set -uo pipefail
export PYTHONDONTWRITEBYTECODE=1
K="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
g=0; d=0
ok(){ g=$((g+1)); echo "GEC  $*"; }
no(){ d=$((d+1)); echo "DUS  $*"; }

cikti="$(python3 - <<PY 2>/dev/null
import sys
sys.path.insert(0, "$K")
from ubl_ortak import Taraf
from fatura_hazirla import belge_kur, KurusHatasi
T = Taraf(unvan="A LTD", vkn="1234567890", vergi_dairesi="VD", il="Mardin",
          ilce="Midyat", adres="Adres 1")

def dene(dayanak, kalem="1000.00", oran=20):
    "(durdu_mu, teshis_var_mi)"
    try:
        belge_kur(kalemler=[("Hizmet", kalem)], dayanak_toplam=dayanak,
                  dayanak_kaynagi="insan_beyani", sap="S", kdv_orani=oran,
                  fatura_no="FGW2026000000999", tarih="2026-08-30",
                  duzenleyen=T, muhatap=T)
        return (False, False)
    except KurusHatasi as e:
        return (True, "TEVKIFAT" in str(e).replace("İ", "I"))

# matrah 1000 · KDV 200 · hesap 1200. Tevkifat dayanagi DUSURUR.
VAKA = {"T1": ("1160.00", 2), "T2": ("1140.00", 3), "T3": ("1120.00", 4),
        "T4": ("1100.00", 5), "T5": ("1060.00", 7), "T6": ("1020.00", 9),
        "T7": ("1000.00", 10)}
for ad, (dyn, pay) in VAKA.items():
    durdu, tes = dene(dyn)
    print(ad, "OK" if (durdu and tes) else "NO")

# AYIRT EDICILIK — teshis her farkta konusmaz
print("T8", "OK" if dene("1163.00") == (True, False) else "NO")    # rastgele fark
print("T9", "OK" if dene("1250.00") == (True, False) else "NO")    # dayanak FAZLA (ters yon)
# KDV YOKken teshis konusmamali. Vaka FARK icermeli: hesap 1000, dayanak 900.
# (ilk kurgum dayanagi 1000 vermisti -> kapi hakli olarak GECIYORDU; sinav hatasiydi.)
print("T10", "OK" if dene("900.00", kalem="1000.00", oran=0) == (True, False) else "NO")

# 🔴 Teshis GECIS SEBEBI DEGILDIR: tevkifat teshisi verilse bile belge URETILMEZ
durdu, tes = dene("1160.00")
print("T11", "OK" if durdu else "NO")
# Mesru belge etkilenmedi (regresyon)
try:
    belge_kur(kalemler=[("Hizmet", "1000.00")], dayanak_toplam="1200.00",
              dayanak_kaynagi="insan_beyani", sap="S", fatura_no="FGW2026000000999",
              tarih="2026-08-30", duzenleyen=T, muhatap=T)
    print("T12", "OK")
except KurusHatasi:
    print("T12", "NO")
PY
)"
for t in T1 T2 T3 T4 T5 T6 T7 T8 T9 T10 T11 T12; do
  s="$(printf '%s\n' "$cikti" | grep "^$t " || true)"
  case "$s" in "$t OK") ok "$t";; "") no "$t — çıktı YOK";; *) no "$t — $s";; esac
done
echo "── tevkifat_teshis: geçen=$g düşen=$d"
[ "$d" -eq 0 ]
