#!/usr/bin/env bash
# kilit_varsayilan.test.sh — ortam kilidinin VARSAYILAN yol çözümü.
#
# 🔴 NİÇİN AYRI SINAV (ölçüldü 2026-08-27): `elogo_gonder.test.sh` kilit kapısını hep
#    AÇIKÇA verilen bir yolla sınıyordu. Ürün kodundaki kusur ise tam olarak
#    `kilit_yolu` VERİLMEDİĞİNDE yaşıyordu: `Path("")` boş değil `.`'tır ve truthy'dir,
#    bu yüzden `or` varsayılana hiç düşmüyor ve kilit dosyası HİÇ OKUNMUYORDU.
#    Sınav, gerçeğin kolay hâlini seçtiği için yıllarca yeşil kalabilirdi.
set -uo pipefail
export PYTHONDONTWRITEBYTECODE=1
K="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
g=0; d=0
ok(){ g=$((g+1)); echo "GEC  $*"; }
no(){ d=$((d+1)); echo "DUS  $*"; }

cikti="$(python3 - <<PY 2>/dev/null
import os, sys, tempfile
from pathlib import Path
sys.path.insert(0, "$K")
from elogo_gonder import ortam_kilidi_dogrula as f

ev = tempfile.mkdtemp()
cfg = Path(ev) / ".config"; cfg.mkdir()
kilit = cfg / "elogo-ortam"
os.environ.pop("ELOGO_ORTAM_KILIDI", None)
os.environ["HOME"] = ev

# V1/V2 — VARSAYILAN yol gerçekten OKUNUYOR mu (kusurun tam yeri)
kilit.write_text("canli"); print("V1", "OK" if f(True) == 0 else "NO")
kilit.write_text("demo");  print("V2", "OK" if f(True) == 6 else "NO")
# V3 — kilit dosyası YOKSA fail-closed
kilit.unlink();            print("V3", "OK" if f(True) == 6 else "NO")
# V4 — env BOŞ dizgeyse varsayılana düşer (Path("") tuzağının ta kendisi)
kilit.write_text("canli"); os.environ["ELOGO_ORTAM_KILIDI"] = ""
print("V4", "OK" if f(True) == 0 else "NO")
# V5/V6 — env DOLUysa o yol kazanır
d2 = Path(tempfile.mkdtemp()) / "k"; d2.write_text("demo")
os.environ["ELOGO_ORTAM_KILIDI"] = str(d2)
print("V5", "OK" if f(True) == 6 else "NO")
d2.write_text("canli"); print("V6", "OK" if f(True) == 0 else "NO")
# V7 — canlı DEĞİLSE kilit hiç sorulmaz
os.environ["ELOGO_ORTAM_KILIDI"] = "/olmayan/yol"
print("V7", "OK" if f(False) == 0 else "NO")
PY
)"
for t in V1 V2 V3 V4 V5 V6 V7; do
  s="$(printf '%s\n' "$cikti" | grep "^$t " || true)"
  case "$s" in "$t OK") ok "$t";; "") no "$t — çıktı YOK";; *) no "$t — $s";; esac
done
# ── V8/V9 · 🔴 BAĞ — kilit ÜRETİM YOLUNDAN gerçekten soruluyor mu ────────────
# NİÇİN SONRADAN EKLENDİ (2026-09-09): yukarıdaki yedi vaka kapının KARARINI ölçüyordu,
# DEVREDE olduğunu değil. `_main` içindeki `ortam_kilidi_dogrula(n.canli)` satırı
# silinseydi yedisi de yeşil kalırdı — kapı-sınavının "yer-kaydırma" mutasyonu tam
# bunu yakaladı. Aşağısı komut satırı yolundan geçer: kapı devreden çıkarsa KIRMIZI.
cikti2="$(python3 - <<PZ 2>/dev/null
import os, sys, tempfile
from pathlib import Path
sys.path.insert(0, "$K")
import elogo_gonder

ev = tempfile.mkdtemp()
kilit = Path(ev) / "kilit"; kilit.write_text("demo")
os.environ["ELOGO_ORTAM_KILIDI"] = str(kilit)
xml = Path(ev) / "belge.xml"; xml.write_text("<Invoice/>", encoding="utf-8")

# V8 — kilit 'demo' derken --canli istenirse ÜRETİM YOLU durmalı (rc=6)
rc = elogo_gonder._main([str(xml), "--canli"])
print("V8", "OK" if rc == 6 else f"NO(rc={rc})")

# V9 — kilit 'canli'ye çevrilince aynı çağrı kilitten GEÇMELİ (yanlış-RED yok).
kilit.write_text("canli")
rc = elogo_gonder._main([str(xml), "--canli"])
print("V9", "OK" if rc != 6 else "NO(hala kilitte)")
PZ
)"
for t in V8 V9; do
  s="$(printf '%s\n' "$cikti2" | grep "^$t " || true)"
  case "$s" in "$t OK") ok "$t · BAĞ: kilit üretim yolundan soruluyor";; "") no "$t — çıktı YOK";; *) no "$t — $s";; esac
done

echo "── kilit_varsayilan: geçen=$g düşen=$d"
[ "$d" -eq 0 ]
