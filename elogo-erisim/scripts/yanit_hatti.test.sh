#!/usr/bin/env bash
# yanit_hatti.test.sh — uygulama yanıtı (KABUL/RED) hattının KAPILARI.
#
# 🔴 NİÇİN: bu kapılar 2026-08-29'da canlıda firsthand denendi ama SINAVA BAĞLANMADI.
#    Öz kural (Sultan): "bir dahaki sefere bunu makine mi yakalar, insan mı hatırlar?
#    İnsan hatırlayacaksa YANLIŞ CEVAPTIR." Bu dosya o cevabı düzeltir.
# 🔴 AĞSIZ: `olc()` monkeypatch'lenir — sınav gerçek e-Logo'ya ASLA dokunmaz.
set -uo pipefail
export PYTHONDONTWRITEBYTECODE=1
K="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
g=0; d=0
ok(){ g=$((g+1)); echo "GEC  $*"; }
no(){ d=$((d+1)); echo "DUS  $*"; }

cikti="$(python3 - <<PY 2>/dev/null
import os, sys
sys.path.insert(0, "$K")
os.environ["MMEX_BIZ_VKN"] = "1111111111"          # sentetik (İ1: gerçek VKN yazılmaz)
for _o in ("ELOGO", "ELOGO_DEMO"):                      # sahte kimlik — gercek kasa okunmaz
    os.environ[f"{_o}_WS_USER"] = "sinav"
    os.environ[f"{_o}_WS_PASSWORD"] = "sinav"
    os.environ[f"{_o}_WS_WSDL"] = "http://yok.invalid"
import yanit_hazirla as Y
from elogo_gonder import yanit_zarf_kur, GonderimHatasi

# ── ağı kes: login/logout/olc sahte ────────────────────────────────────────────
Y.S.login = lambda *a, **k: "SID"
Y.S.logout = lambda *a, **k: None
GELEN = {"no": "ABC2026000000001", "senaryo": "TICARIFATURA", "tip": "SATIS",
         "tarih": "2026-08-24", "odenecek": "100.00",
         "satici": "Satici · 2222222222", "alici": "Biz · 1111111111",
         "satici_vkn": "2222222222", "alici_vkn": "1111111111", "onceki_yanit": "yok"}
def kur(**fark):
    d = dict(GELEN); d.update(fark); Y.olc = lambda *a, **k: d
UU = "CCAE1F50-EB92-4FFC-8A7F-D0E2B57AB00D"
def kos(*ek):
    return Y.main([UU, "RED", "--aciklama", "gerekce", "--alias",
                   "urn:mail:defaultgb@ornekfirma", *ek])

# ── YÖN kapısı ────────────────────────────────────────────────────────────────
kur();                                   print("Y1", "OK" if kos() == 0 else "NO")
kur(alici_vkn="9999999999");             print("Y2", "OK" if kos() == 5 else "NO")   # bize gelmemiş
# 🔴 Y3 AYIRT EDİCİ OLMALI (mutasyon 2026-08-29'da yakaladı): önce alıcı VKN normalken
#    kimliği siliyordum ve rc=5 geliyordu — ama o 5'i YÖN kapısı üretiyordu ("" != VKN),
#    kimlik kapısı silinse bile sınav YEŞİL kalıyordu. Alıcıyı da boşaltınca iki kapı
#    ayrışır: kimlik kapısı varsa RET, yoksa "" == "" olur ve belge geçer.
kur(alici_vkn="")
os.environ.pop("MMEX_BIZ_VKN")
print("Y3", "OK" if kos() == 5 else "NO")                                            # kimliğimiz yok
os.environ["MMEX_BIZ_VKN"] = "1111111111"

# ── SENARYO kapısı ────────────────────────────────────────────────────────────
kur(senaryo="TEMELFATURA");              print("S1", "OK" if kos() == 3 else "NO")
kur(senaryo="IHRACAT");                  print("S2", "OK" if kos() == 3 else "NO")

# ── MÜKERRER kapısı ───────────────────────────────────────────────────────────
kur(onceki_yanit="VAR");                 print("M1", "OK" if kos() == 4 else "NO")
kur(onceki_yanit="ÖLÇÜLEMEDİ (x)");      print("M2", "OK" if kos() == 4 else "NO")   # ölçülemedi ≠ geç
kur(onceki_yanit="verilemez (temel fatura)"); print("M3", "OK" if kos() == 4 else "NO")

# ── ALIAS kapısı (gönderim yolunda) ───────────────────────────────────────────
kur()
print("A1", "OK" if Y.main([UU, "RED", "--aciklama", "g", "--alias",
                            "urn:mail:defaultirsaliyepk@ornekfirma"]) == 7 else "NO")
print("A2", "OK" if Y.main([UU, "RED", "--aciklama", "g", "--alias", "bozuk"]) == 7 else "NO")

# ── KURU KOŞUM varsayılan: --gercekten-gonder YOKSA ağa ÇIKILMAZ ──────────────
patladi = {"v": False}
def _tuzak(*a, **k): patladi["v"] = True; raise AssertionError("AĞA ÇIKILDI")
Y.S._cagir = _tuzak
kur(); rc = kos()
print("K1", "OK" if rc == 0 and not patladi["v"] else "NO")

# ── zarf kurucusunun kendi doğrulamaları ──────────────────────────────────────
def ret(fn):
    try: fn(); return False
    except GonderimHatasi: return True
print("Z1", "OK" if ret(lambda: yanit_zarf_kur("s", UU, "BELKI", "g", "urn:mail:a@ornekfirma")) else "NO")
print("Z2", "OK" if ret(lambda: yanit_zarf_kur("s", "kisa", "RED", "g", "urn:mail:a@ornekfirma")) else "NO")
print("Z3", "OK" if ret(lambda: yanit_zarf_kur("s", UU, "RED", "  ", "urn:mail:a@ornekfirma")) else "NO")
print("Z4", "OK" if ret(lambda: yanit_zarf_kur("s", UU, "RED", "a<b>c", "urn:mail:a@ornekfirma")) else "NO")
z = yanit_zarf_kur("SID", UU, "RED", "gerekce", "urn:mail:a@ornekfirma")
print("Z5", "OK" if all(x in z for x in ("DOCUMENTTYPE=CREATEAPPLICATIONRESPONSE",
                                        f"UUID={UU}", "APPLICATIONRESPONSE=RED",
                                        "DESCRIPTION=gerekce", "ALIAS=urn:mail:a@ornekfirma")) else "NO")
print("Z6", "OK" if "binaryData" not in z else "NO")   # belge verisi YOK — datayı e-Logo üretir
PY
)"
for t in Y1 Y2 Y3 S1 S2 M1 M2 M3 A1 A2 K1 Z1 Z2 Z3 Z4 Z5 Z6; do
  s="$(printf '%s\n' "$cikti" | grep "^$t " || true)"
  case "$s" in "$t OK") ok "$t";; "") no "$t — çıktı YOK";; *) no "$t — $s";; esac
done
echo "── yanit_hatti: geçen=$g düşen=$d"
[ "$d" -eq 0 ]
