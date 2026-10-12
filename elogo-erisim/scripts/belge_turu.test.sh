#!/usr/bin/env bash
# belge_turu.test.sh — belge TÜRÜ ⟂ KALEM YAPISI tutarlılığı.
#
# 🔴 ÖLÇÜLMÜŞ HATA (2026-09-02, Sultan yakaladı 09-03): bir MALZEME İADE belgesi
#    SATIS tipinde ve belgedeki 11 malzeme kalemiyle kesildi. O belge "karşı tarafa
#    11 kalem MAL SATTIK" diye okunur; oysa iade işlemidir.
#    Kanondaki kural belgenin TÜRÜNÜ söylüyordu ("düz fatura kesilir") ama KALEM
#    YAPISINI söylemiyordu. Boşluğu doldurmak ÖLÇÜM DEĞİL VARSAYIMDI.
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
from ubl_ortak import Taraf, Dayanak
from fatura_hazirla import belge_kur, belge_turu_kapisi, KurusHatasi, IADE_NITELIGI
T = Taraf(unvan="A LTD", vkn="1234567890", vergi_dairesi="VD", il="Mardin",
          ilce="Midyat", adres="Adres 1")
COK = [("Parca A", "600.00", 20), ("Parca B", "400.00", 20)]
TEK = [("Malzeme Iade", "1000.00", 20)]
REF = [Dayanak(fatura_no="ABC2026000000001", tarih="2026-08-13")]
ORT = dict(dayanak_toplam="1200.00", dayanak_kaynagi="insan_beyani", sap="S",
           fatura_no="FGW2026000000999", tarih="2026-09-03", duzenleyen=T, muhatap=T)

def dur(**kw):
    "belge KURULMADI mi"
    try:
        belge_kur(**ORT, **kw); return False
    except KurusHatasi:
        return True

# ── DÜNKÜ HATA artık DURUYOR ─────────────────────────────────────────────────
print("H1", "OK" if dur(kalemler=COK, belge_turu="malzeme_iade") else "NO")
print("H2", "OK" if dur(kalemler=COK, belge_turu="ek_garanti_iade") else "NO")
print("H3", "OK" if dur(kalemler=COK, belge_turu="iade_paketi") else "NO")

# ── İKİ MEŞRU YOL geçer, üçüncüsü yok ────────────────────────────────────────
print("M1", "OK" if not dur(kalemler=TEK, belge_turu="malzeme_iade") else "NO")
print("M2", "OK" if not dur(kalemler=COK, belge_turu="malzeme_iade", dayanaklar=REF) else "NO")
print("M3", "OK" if not dur(kalemler=TEK, belge_turu="malzeme_iade", dayanaklar=REF) else "NO")

# ── SATIŞ türleri ETKİLENMEZ (regresyon) ─────────────────────────────────────
print("S1", "OK" if not dur(kalemler=COK, belge_turu="fis_paketi") else "NO")
print("S2", "OK" if not dur(kalemler=COK, belge_turu="satis") else "NO")
print("S3", "OK" if not dur(kalemler=COK) else "NO")          # tür beyansız = eski çağrılar

# ── Tanınmayan tür: fail-closed ──────────────────────────────────────────────
print("T1", "OK" if dur(kalemler=TEK, belge_turu="uydurma") else "NO")
print("T2", "OK" if dur(kalemler=TEK, belge_turu="") else "NO")

# ── Kapı KURUŞ kapısından ÖNCE koşmalı: yapı yanlışsa tutar hiç sorulmasın ───
# (dayanak kasten yanlış; yine de TÜR mesajı gelmeli, KURUŞ değil)
try:
    belge_kur(kalemler=COK, dayanak_toplam="9999.99", dayanak_kaynagi="insan_beyani",
              sap="S", fatura_no="FGW2026000000999", tarih="2026-09-03",
              duzenleyen=T, muhatap=T, belge_turu="malzeme_iade")
    print("O1", "NO")
except KurusHatasi as e:
    print("O1", "OK" if "TUR KAPISI" in str(e).replace("Ü", "U") else "NO")

# ── küme kapalı ve iade türleri BELGE_TURLERI'nin alt kümesi ─────────────────
from fatura_hazirla import BELGE_TURLERI
print("K1", "OK" if IADE_NITELIGI < BELGE_TURLERI else "NO")
PY
)"
for t in H1 H2 H3 M1 M2 M3 S1 S2 S3 T1 T2 O1 K1; do
  s="$(printf '%s\n' "$cikti" | grep "^$t " || true)"
  case "$s" in "$t OK") ok "$t";; "") no "$t — çıktı YOK";; *) no "$t — $s";; esac
done
echo "── belge_turu: geçen=$g düşen=$d"
[ "$d" -eq 0 ]
