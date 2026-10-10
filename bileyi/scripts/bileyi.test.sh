#!/usr/bin/env bash
# bileyi.test.sh — bileyinin kapıları. HERMETİK: gerçek havuza, gerçek anahtara DOKUNMAZ.
#
# En değerli kapılar B ve D: ikisi de "ölçemediğine temiz deme" kuralını kilitler.
# Eşiğin dayanağı silinince ya da havuz kaybolunca araç YEŞİL BASMAMALI — çünkü
# eksik veri her zaman "daha az" görünür, yani rahatlatır.
#
# 🔴 Kimlik kapısı ORTAM DEĞİŞKENİYLE sınanmaz: üretim kodunda kimliği ortamdan
#    almak kimlik taklidine kapı açar. Bu yüzden o kapı python içinden, modülün
#    kendi işlevi yama'lanarak sınanır — üretim yüzeyi temiz kalır.
set -uo pipefail
cd "$(dirname "$0")"
B="$PWD/bileyi.py"
GECEN=0; DUSEN=0
kapi() { # kapi <ad> <beklenen-rc> <komut...>
  local ad="$1" bek="$2"; shift 2
  "$@" >/dev/null 2>&1; local rc=$?
  if [[ $rc -eq $bek ]]; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad (rc=$rc, beklenen=$bek)"; fi
}
iceren() { # iceren <ad> <aranan> <komut...>
  local ad="$1" ara="$2"; shift 2
  local out; out="$("$@" 2>&1)"
  if [[ "$out" == *"$ara"* ]]; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad (çıktıda '$ara' yok)"; fi
}
icermeyen() {
  local ad="$1" ara="$2"; shift 2
  local out; out="$("$@" 2>&1)"
  if [[ "$out" != *"$ara"* ]]; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad ('$ara' çıktıda var, olmamalı)"; fi
}

# ── sahte oda kurulumu (gerçek hiçbir şeye dokunmaz)
KOK="$(mktemp -d)"; trap 'rm -r -f "$KOK" 2>/dev/null' EXIT
mkdir -p "$KOK/oda/_agents/handoff" "$KOK/oda/scripts"
HAV="$KOK/oda/_agents/handoff/bulgu-havuzu.jsonl"
py_yaz() { python3 - "$@" ; }
python3 - "$HAV" <<'PY'
import json, sys
from datetime import date
y = sys.argv[1]
bugun = date.today().isoformat()
k = []
# Esigi ASAN gercek bir tekrar: 4 AYRI, ARDISIK OLMAYAN kayitta ayni soz obegi
for i, no in enumerate(("b0001", "b0005", "b0011", "b0030")):
    k.append({"id": no, "tarih": bugun, "baslik": "sahte yesil kapi gecti",
              "sinif": "olcum-korlugu", "gercek": "x"})
# TEK PARTI: ardisik uc kayitta ayni obek -> tekrar SAYILMAMALI
for no in ("b0100", "b0101", "b0102", "b0103"):
    k.append({"id": no, "tarih": bugun, "baslik": "parti ornegi tek olay", "gercek": "y"})
# Sinif alani BOS kayitlar -> kapsama %100 olmasin
for no in ("b0200", "b0201"):
    k.append({"id": no, "tarih": bugun, "baslik": "alakasiz tek seferlik", "gercek": "z"})
with open(y, "w", encoding="utf-8") as f:
    for r in k:
        f.write(json.dumps(r, ensure_ascii=False) + "\n")
PY
: > "$KOK/oda/_agents/handoff/layiha-aday-havuzu.jsonl"
ES="$KOK/esik.json"
python3 - "$ES" <<'PY'
import json, sys
json.dump({"ikili_esik": 4, "sinif_esik": 2, "tavan": 2, "pencere_gun": 30,
           "dayanak": "SAHTE DAYANAK — sinav fiksturu; en az kirk karakter olmali ki kapi gecsin.",
           "dayanak_tarihi": "2026-01-01"}, open(sys.argv[1], "w"), ensure_ascii=False)
PY
ANAH="$KOK/anahtar"
O=(python3 "$B" --depo "$KOK/oda" --esik-dosya "$ES")

echo "A · temel akış"
kapi "A1 eşiği aşan tekrar VAR → rc=0" 0 env BILEYI_ANAHTAR="$ANAH" "${O[@]}" olc --gun 0
iceren "A2 ölçüm ajan kimliğini basar" "ajan=" env BILEYI_ANAHTAR="$ANAH" "${O[@]}" olc --gun 0
iceren "A3 gerçek tekrar bulunur" "sahte yesil" env BILEYI_ANAHTAR="$ANAH" "${O[@]}" olc --gun 0

echo "B · 🔴 eşik dayanağı (ölçmediğine temiz deme)"
python3 -c "
import json,sys; y=sys.argv[1]; d=json.load(open(y)); d['dayanak']=''
json.dump(d, open(y+'.dayanaksiz','w'), ensure_ascii=False)" "$ES"
kapi "B1 dayanaksız eşik → rc=3 ÖLÇEMEDİM (yeşil DEĞİL)" 3 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" --esik-dosya "$ES.dayanaksiz" olc --gun 0
echo 'bu json degil' > "$ES.bozuk"
kapi "B2 bozuk eşik dosyası → rc=2 yapılandırma hatası" 2 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" --esik-dosya "$ES.bozuk" olc --gun 0
kapi "B3 eşik dosyası YOK → rc=3 (eşik UYDURULMAZ)" 3 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" --esik-dosya "$KOK/olmayan.json" olc --gun 0
python3 -c "
import json,sys; y=sys.argv[1]; d=json.load(open(y)); d['ikili_esik']=0
json.dump(d, open(y+'.sifir','w'), ensure_ascii=False)" "$ES"
kapi "B4 eşik 0 ya da negatif → rc=2 (her şey tekrar sayılamaz)" 2 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" --esik-dosya "$ES.sifir" olc --gun 0

echo "C · 🔴 kapsama dürüstlüğü (vekil ölçüt panzehiri)"
iceren "C1 sınıf alanının kaç kayıtta dolu olduğu basılır" "KAPSAMA" env BILEYI_ANAHTAR="$ANAH" "${O[@]}" olc --gun 0
iceren "C2 körlük YÜZDESİYLE söylenir" "KÖR" env BILEYI_ANAHTAR="$ANAH" "${O[@]}" olc --gun 0
iceren "C3 ölçülmeyen boyut (maliyet) açıkça yazılır" "ÖLÇMEDİĞİM" env BILEYI_ANAHTAR="$ANAH" "${O[@]}" olc --gun 0

echo "D · 🔴 havuz yok / bozuk (eksik veri rahatlatır)"
mkdir -p "$KOK/bos/_agents/handoff"
kapi "D1 havuz YOK → rc=3, 'temiz' DEĞİL" 3 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/bos" --esik-dosya "$ES" olc --gun 0
printf 'bu json degil\n{bozuk\n' > "$KOK/bos/_agents/handoff/bulgu-havuzu.jsonl"
kapi "D2 havuzun TAMAMI bozuk → rc=3" 3 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/bos" --esik-dosya "$ES" olc --gun 0
cp "$HAV" "$KOK/bozukla.jsonl" && printf 'cop satir\n' >> "$KOK/bozukla.jsonl"
mkdir -p "$KOK/oda2/_agents/handoff" && cp "$KOK/bozukla.jsonl" "$KOK/oda2/_agents/handoff/bulgu-havuzu.jsonl"
iceren "D3 bozuk satır SESSİZCE atlanmaz, sayısı basılır" "BOZUK" \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda2" --esik-dosya "$ES" olc --gun 0

echo "E · 🔴 tek parti ≠ tekrar (b0164 dersi)"
iceren "E1 ardışık kimlikli öbek TEK PARTİ işaretlenir" "TEK PARTİ" env BILEYI_ANAHTAR="$ANAH" "${O[@]}" olc --gun 0
kapi "E2 tek-parti ayrımı: ardışık kimlikler yardımcıda yakalanır" 0 python3 -c "
import sys; sys.path.insert(0,'$PWD')
import importlib.util as u
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
assert m.tek_parti_mi(['b0100','b0101','b0102']) is True
assert m.tek_parti_mi(['b0001','b0005','b0011']) is False
assert m.tek_parti_mi(['b0100']) is False            # tek kayit parti degil
assert m.tek_parti_mi(['x','y']) is False            # sayisal degil -> parti sayma
"

echo "E3 · 🔴 SONUÇ kapısı: yalnız tek-parti varsa hüküm TEMİZ olmalı"
mkdir -p "$KOK/parti/_agents/handoff"
python3 - "$KOK/parti/_agents/handoff/bulgu-havuzu.jsonl" <<'PY'
import json, sys
from datetime import date
b = date.today().isoformat()
# TEK gecerli tekrar kaynagi: ardisik kimlikli dort kayit. Baska hicbir obek esigi asmiyor.
k = [{"id": f"b{900+i}", "tarih": b, "baslik": "ardisik parti obegi burada", "gercek": ""}
     for i in range(4)]
k += [{"id": "b0500", "tarih": b, "baslik": "alakasiz biri", "gercek": ""},
      {"id": "b0600", "tarih": b, "baslik": "alakasiz ikisi", "gercek": ""}]
with open(sys.argv[1], "w", encoding="utf-8") as f:
    for r in k: f.write(json.dumps(r, ensure_ascii=False) + "\n")
PY
kapi "E3 yalnız tek-parti tekrarı varsa rc=1 (TEMİZ) — tekrar sayılmaz" 1 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/parti" --esik-dosya "$ES" olc --gun 0
iceren "E3b tek-parti elenince niçini yazılır" "TEK PARTİ sayıldı" \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/parti" --esik-dosya "$ES" olc --gun 0

echo "F · pencere (fail-open panzehiri)"
iceren "F1 pencere havuzu boşaltırsa pencere YOK SAYILIR, sessiz boş dönmez" "pencere" \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" --esik-dosya "$ES" olc --gun 1
kapi "F2 pencere boşken yine ölçüm yapılır (rc=0)" 0 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" --esik-dosya "$ES" olc --gun 1

echo "G · sürtünme yüzeyi: unknown ≠ yok"
iceren "G1 sürtünme aracı yoksa ÖLÇEMEDİM der, 'yok' DEMEZ" "ÖLÇEMEDİM" env BILEYI_ANAHTAR="$ANAH" "${O[@]}" olc --gun 0
icermeyen "G2 'sürtünme yok' diye bir cümle BASMAZ" "sürtünme yok" env BILEYI_ANAHTAR="$ANAH" "${O[@]}" olc --gun 0

echo "H · kill-switch"
kapi "H1 kapalıyken tam tur rc=4" 4 env BILEYI_ANAHTAR="$ANAH" sh -c \
  "python3 '$B' --depo '$KOK/oda' --esik-dosya '$ES' dur --gerekce 'sinav' >/dev/null && python3 '$B' --depo '$KOK/oda' --esik-dosya '$ES' tur --gun 0"
kapi "H2 🔴 kapalıyken 'olc' YİNE çalışır (ölçüme erişim kesilmez)" 0 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" --esik-dosya "$ES" olc --gun 0
kapi "H3 🔴 kapalıyken 'durum' YİNE çalışır" 0 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" --esik-dosya "$ES" durum
iceren "H4 durum kapalı olduğunu ve gerekçesini söyler" "KAPALI" \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" --esik-dosya "$ES" durum
kapi "H5 açılınca tur yine koşar (kill-switch açıldı)" 0 python3 -c "
import importlib.util as u, io, contextlib, os, subprocess, sys
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
m.kimlik = lambda depo, zorunlu=True: 'sinav-ajani'
os.environ['BILEYI_ANAHTAR'] = '$ANAH'
subprocess.run([sys.executable,'$B','--depo','$KOK/oda','--esik-dosya','$ES','ac','--gerekce','sinav'],
               capture_output=True, env=dict(os.environ))
class N: pass
n=N(); n.depo='$KOK/oda'; n.havuz_depo='$KOK/oda'; n.esik_dosya='$ES'; n.gun=0
n.ikili_esik=None; n.kuru=True
with contextlib.redirect_stdout(io.StringIO()): rc = m.komut_tur(n)
assert rc == 0, rc
"
kapi "H6 'dur' gerekçesiz çağrılamaz" 2 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" --esik-dosya "$ES" dur

echo "I · 🔴 kimlik kapısı (çivili yol / sızıntı panzehiri)"
kapi "I1 🔴 ölçmek için ada gerek YOK — kimlik aracı yoksa da ölçer ve bilinmediğini söyler" 0 python3 -c "
import importlib.util as u, io, contextlib, pathlib
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
m.kimlik = lambda depo, zorunlu=True: ('' if not zorunlu else (_ for _ in ()).throw(m.Durdu('yok',3)))
class N: pass
n=N(); n.depo='$KOK/oda'; n.havuz_depo='$KOK/oda'; n.esik_dosya='$ES'; n.gun=0; n.ikili_esik=None
t=io.StringIO()
with contextlib.redirect_stdout(t): rc = m.komut_olc(n)
cik=t.getvalue()
assert rc == 0, (rc, cik[:300])
assert 'bilinmiyor' in cik, cik[:200]
# Hangi izi okudugunu YOL olarak basmali — odayi secen sey o
assert 'iz:' in cik and 'bulgu-havuzu.jsonl' in cik, cik[:200]
"
kapi "I1b 🔴 YAZMAK için ad ŞART — kimliksiz tur ilerlemez (provenans uydurulamaz)" 0 python3 -c "
import importlib.util as u, io, contextlib
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
def sahte(depo, zorunlu=True):
    if zorunlu: raise m.Durdu('kimlik araci yok', 3)
    return ''
m.kimlik = sahte
class N: pass
n=N(); n.depo='$KOK/oda'; n.havuz_depo='$KOK/oda'; n.esik_dosya='$ES'; n.gun=0
n.ikili_esik=None; n.kuru=False
t=io.StringIO()
try:
    with contextlib.redirect_stdout(t): m.komut_tur(n)
except m.Durdu as e:
    assert e.rc == 3, e.rc
else:
    raise SystemExit(1)
"
kapi "I2 kimlik BOŞ dönerse de rc=3 (boş ad kabul edilmez)" 0 python3 -c "
import importlib.util as u
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
import subprocess
class S: stdout='\n'; returncode=0
m.subprocess.run = lambda *a, **k: S()
import pathlib
m.Path = pathlib.Path
try:
    m.kimlik(pathlib.Path('$KOK/oda'))
except m.Durdu as e:
    assert e.rc == 3, e.rc
else:
    raise SystemExit(1)
" 

echo "J · 🔴 yeni havuz KURULMAZ · A06"
kapi "J1 🔴 araç BULGU havuzuna asla yazmaz (yeni havuz da kurmaz)" 0 python3 -c "
k = open('$B', encoding='utf-8').read()
kod = '\n'.join(l for l in k.splitlines() if not l.lstrip().startswith('#'))
# Bulgu havuzu SALT-OKUNUR olmali: acilis kipi 'a' ya da 'w' ile gecmemeli.
import re
assert not re.search(r'bulgu-havuzu[^\n]{0,80}(open|write_text|\"a\"|\"w\")', kod), 'bulgu havuzuna yazma izi'
# Aday havuzu VAR OLANA eklenir; yoksa KURULMAZ.
assert 'if not aday_yolu.exists():' in kod
assert 'YENİ HAVUZ KURMUYORUM' in k
"
kapi "J2 araç ONAY alanı yazmaz (A06)" 0 python3 -c "
k = open('$B', encoding='utf-8').read()
for yasak in ('sultan_response', 'sultan_cevap', 'onay-cevabi', \"'onay'\"):
    assert yasak not in k, yasak
"
kapi "J3 kimlik ORTAM değişkeninden alınmaz (taklit panzehiri)" 0 python3 -c "
import re
k = open('$B', encoding='utf-8').read()
g = k[k.index('def kimlik'):k.index('def esik_oku')]
assert 'environ' not in g, 'kimlik ortamdan okunuyor — taklide kapi'
"
kapi "J4 süzme yeniden yazılmaz — mucit-suz'e devredilir (SKILL.md'de yazılı)" 0 python3 -c "
m = open('$PWD/../SKILL.md', encoding='utf-8').read()
assert 'mucit-suz' in m
assert 'YENİ HAVUZ KURULMAZ' in m
"

echo "K · 🔴 kill-switch ÜRETİM yolu (bağımsız gözün tur-1 bulgusu, ciddi)"
kapi "K1 ortam değişkeni YOKken varsayılan DOSYA kullanılır (çalışma dizini DEĞİL)" 0 python3 -c "
import os, importlib.util as u, pathlib
for v in ('', '   '):
    os.environ['BILEYI_ANAHTAR'] = v
    s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
    y = m.anahtar_yolu()
    assert y == m.ANAHTAR_VARSAYILAN, f'bos ortamda yol {y} oldu — Path() tuzagi geri gelmis'
os.environ.pop('BILEYI_ANAHTAR')
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
assert m.anahtar_yolu() == m.ANAHTAR_VARSAYILAN
assert m.anahtar_yolu() != pathlib.Path('.'), 'calisma dizini anahtar sanilmis'
"
kapi "K2 ortam değişkeni VERİLİRSE o yol kullanılır" 0 python3 -c "
import os, importlib.util as u, pathlib
os.environ['BILEYI_ANAHTAR'] = '$KOK/x'
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
assert m.anahtar_yolu() == pathlib.Path('$KOK/x')
"

echo "L · eşik ezmesi de kapıdan geçer (tur-1 bulgusu)"
kapi "L1 negatif --ikili-esik → rc=2" 2 env BILEYI_ANAHTAR="$ANAH" "${O[@]}" olc --gun 0 --ikili-esik -5
kapi "L2 sıfır --ikili-esik → rc=2" 2 env BILEYI_ANAHTAR="$ANAH" "${O[@]}" olc --gun 0 --ikili-esik 0
kapi "L3 geçerli ezme çalışır" 0 env BILEYI_ANAHTAR="$ANAH" "${O[@]}" olc --gun 0 --ikili-esik 2

echo "M · 🔴 iki yüzey ÇELİŞİRSE hüküm YOK (tur-1 bulgusu)"
mkdir -p "$KOK/celiski/_agents/handoff"
python3 - "$KOK/celiski/_agents/handoff/bulgu-havuzu.jsonl" <<'PY'
import json, sys
from datetime import date
b = date.today().isoformat()
# Sinif yuzeyi "3 kez tekrar" diyor; kimlikler ARDISIK, yani obur yuzey "tek olay" diyor.
k = [{"id": f"b{700+i}", "tarih": b, "baslik": f"farkli baslik {i} burada", "sinif": "celisen-sinif",
      "gercek": ""} for i in range(3)]
k += [{"id": "b0800", "tarih": b, "baslik": "yalniz bir kere", "gercek": ""}]
with open(sys.argv[1], "w", encoding="utf-8") as f:
    for r in k: f.write(json.dumps(r, ensure_ascii=False) + "\n")
PY
kapi "M1 tüm adaylarda çelişki varsa rc=3 (ne temiz ne kirli)" 3 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/celiski" --esik-dosya "$ES" olc --gun 0
iceren "M2 çelişki işaretlenir ve niçini yazılır" "ÇELİŞKİ" \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/celiski" --esik-dosya "$ES" olc --gun 0

echo "N · 🔴 sınıf kâhini (otonom turun emniyeti)"
SK="$(cd "$(dirname "$B")/.." && pwd)/sinif-kurallari.json"
iceren "N1 güvenli yol → dört sınıf da h" "yetki           = h" \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" kart --is x --hedef "bileyi/scripts/a.py" --kuru
iceren "N2 yetki deseni tutarsa yetki=e" "yetki           = e" \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" kart --is x --hedef "hooks/a.js" --kuru
iceren "N3 🔴 BİLİNMEYEN yol → '?' → SULTAN'A GİDER (şüphede sınıf YUKARI)" "SULTAN'A GİDER" \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" kart --is x --hedef "ui/app/x.tsx" --kuru
iceren "N4 para deseni tutarsa para=e" "para            = e" \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" kart --is x --hedef "bileyi/fatura-x.py" --kuru
python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); d['dayanak']=''
json.dump(d, open(sys.argv[2],'w'), ensure_ascii=False)" "$SK" "$KOK/sk-dayanaksiz.json"
kapi "N5 sınıf kurallarının dayanağı yoksa rc=3 — sınıf UYDURULMAZ" 3 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" kart --is x --hedef "bileyi/a.py" --sinif-dosya "$KOK/sk-dayanaksiz.json" --kuru
kapi "N6 sınıf kuralları dosyası yoksa rc=3" 3 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" kart --is x --hedef "bileyi/a.py" --sinif-dosya "$KOK/yok.json" --kuru

echo "O · 🔴 'tur' FİİLEN iş yapar (tur-1 bulgusu: eskiden ekrana basıyordu)"
mkdir -p "$KOK/havuzsuz/_agents/handoff"
cp "$HAV" "$KOK/havuzsuz/_agents/handoff/bulgu-havuzu.jsonl"
kapi "O1 aday havuzu YOKsa tur rc=3 — yeni havuz KURMAZ" 3 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/havuzsuz" --esik-dosya "$ES" tur --gun 0
kapi "O2 🔴 tur koşar ve ÖLÇÜLEN her tekrar için ayrı aday yazar (işlev düzeyi)" 0 python3 -c "
import importlib.util as u, io, contextlib, json, pathlib, os
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
# 🔴 CLI yerine islev duzeyi: uretim kimligi makineye bagli, sinav olmamali.
#    CI bunu yakaladi — 'hermetik' iddiam yanlisti.
m.kimlik = lambda depo, zorunlu=True: 'sinav-ajani'
os.environ['BILEYI_ANAHTAR'] = '$ANAH'
class N: pass
n=N(); n.depo='$KOK/oda'; n.havuz_depo='$KOK/oda'; n.esik_dosya='$ES'; n.gun=0
n.ikili_esik=None; n.kuru=False
t=io.StringIO()
with contextlib.redirect_stdout(t): rc = m.komut_tur(n)
cik = t.getvalue()
assert rc == 0, (rc, cik[-400:])
y = pathlib.Path('$KOK/oda/_agents/handoff/layiha-aday-havuzu.jsonl')
a = [json.loads(l) for l in y.read_text(encoding='utf-8').splitlines() if l.strip()]
b = [x for x in a if x.get('kaynak') == 'bileyi']
assert b, 'aday yazilmadi'
for x in b:
    assert x['anahtar'] and x['sayi'] and x['kaynak_bulgular'], x
    assert x['bulan'] == 'sinav-ajani', x
    assert 'sürtünme ölçüldü' not in x['baslik'], 'sabit baslik geri gelmis'
d = json.loads(pathlib.Path('$KOK/oda/_agents/fabrika/bileyi-tur.json').read_text(encoding='utf-8'))
assert d['asama'] == 'yazim-bekliyor', d
"
kapi "O7 🔴 TAVAN fiilen keser (rapor metni değil — işlev düzeyi)" 0 python3 -c "
import importlib.util as u, io, contextlib, json, pathlib, os
from datetime import date
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
m.kimlik = lambda depo, zorunlu=True: 'sinav-ajani'
os.environ['BILEYI_ANAHTAR'] = '$ANAH'
kok = pathlib.Path('$KOK/tavan2'); (kok/'_agents/handoff').mkdir(parents=True, exist_ok=True)
b = date.today().isoformat(); kay = []
for grup, obek in enumerate(('alfa beta', 'gama delta', 'epsilon zeta')):
    for i in range(4):
        kay.append({'id': f'f{grup}{i*7}', 'tarih': b, 'baslik': obek + ' burada', 'gercek': ''})
(kok/'_agents/handoff/bulgu-havuzu.jsonl').write_text(
    ''.join(json.dumps(k, ensure_ascii=False)+chr(10) for k in kay), encoding='utf-8')
(kok/'_agents/handoff/layiha-aday-havuzu.jsonl').write_text('', encoding='utf-8')
es = json.load(open('$ES')); es['tavan'] = 1
json.dump(es, open(str(kok/'esik.json'), 'w'), ensure_ascii=False)
class N: pass
n=N(); n.depo=str(kok); n.havuz_depo=str(kok); n.esik_dosya=str(kok/'esik.json')
n.gun=0; n.ikili_esik=None; n.kuru=False
t=io.StringIO()
with contextlib.redirect_stdout(t): rc = m.komut_tur(n)
cik=t.getvalue()
assert rc == 0, (rc, cik[-300:])
yaz = [l for l in (kok/'_agents/handoff/layiha-aday-havuzu.jsonl').read_text(encoding='utf-8').splitlines() if l.strip()]
assert len(yaz) == 1, f'tavan 1 iken {len(yaz)} aday yazildi'
assert 'tavan doldu' in cik
"
kapi "O8 🔴 aynı tekrar İKİ KEZ aday olmaz (işlev düzeyi)" 0 python3 -c "
import importlib.util as u, io, contextlib, json, pathlib, os
from datetime import date
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
m.kimlik = lambda depo, zorunlu=True: 'sinav-ajani'
os.environ['BILEYI_ANAHTAR'] = '$ANAH'
kok = pathlib.Path('$KOK/dedup2'); (kok/'_agents/handoff').mkdir(parents=True, exist_ok=True)
b = date.today().isoformat()
kay = [{'id': f'g{i*5}', 'tarih': b, 'baslik': 'tekil obek burada', 'gercek': ''} for i in range(4)]
(kok/'_agents/handoff/bulgu-havuzu.jsonl').write_text(
    ''.join(json.dumps(k, ensure_ascii=False)+chr(10) for k in kay), encoding='utf-8')
(kok/'_agents/handoff/layiha-aday-havuzu.jsonl').write_text('', encoding='utf-8')
class N: pass
n=N(); n.depo=str(kok); n.havuz_depo=str(kok); n.esik_dosya='$ES'; n.gun=0
n.ikili_esik=None; n.kuru=False
with contextlib.redirect_stdout(io.StringIO()): m.komut_tur(n)
n1 = len([l for l in (kok/'_agents/handoff/layiha-aday-havuzu.jsonl').read_text(encoding='utf-8').splitlines() if l.strip()])
t=io.StringIO()
with contextlib.redirect_stdout(t): rc2 = m.komut_tur(n)
n2 = len([l for l in (kok/'_agents/handoff/layiha-aday-havuzu.jsonl').read_text(encoding='utf-8').splitlines() if l.strip()])
cik=t.getvalue()
assert n1 >= 1 and n2 == n1, (n1, n2)
assert rc2 == 1, rc2
assert 'zaten aday' in cik
assert 'TEKRAR YOK' not in cik
"
kapi "O5 kuru tur HİÇBİR ŞEY yazmaz" 0 python3 -c "
import importlib.util as u, io, contextlib, pathlib, os
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
m.kimlik = lambda depo, zorunlu=True: 'sinav-ajani'
os.environ['BILEYI_ANAHTAR'] = '$ANAH'
y = pathlib.Path('$KOK/oda/_agents/handoff/layiha-aday-havuzu.jsonl')
once = y.read_bytes()
class N: pass
n=N(); n.depo='$KOK/oda'; n.havuz_depo='$KOK/oda'; n.esik_dosya='$ES'; n.gun=0
n.ikili_esik=None; n.kuru=True
with contextlib.redirect_stdout(io.StringIO()): m.komut_tur(n)
assert y.read_bytes() == once, 'kuru kosum yazdi'
"

echo "P · 🔴 'devam' birleştirme kilitleri"
kapi "P1 kartsız iş birleştirilmez → rc=3" 3 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" devam --is olmayan-is --dal x
kapi "P1b 🔴 kart BİRİNCİL depoda da aranır (çalışma alanı kartı görmüyordu)" 0 python3 -c "
import importlib.util as u, pathlib, json, io, contextlib, os
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
# 🔴 Fabrika araci da MAKINEYE BAGLI — CI yakaladi. Sahte bir fabrika enjekte edilir.
sf = pathlib.Path('$KOK/sahte-fabrika'); sf.mkdir(parents=True, exist_ok=True)
(sf/'denetci.sh').write_text('#!/usr/bin/env bash'+chr(10)+'echo GEÇTİ'+chr(10), encoding='utf-8')
(sf/'kart.sh').write_text('#!/usr/bin/env bash'+chr(10)+'echo kart'+chr(10), encoding='utf-8')
m.FABRIKA = sf
birincil = pathlib.Path('$KOK/p1b'); (birincil/'_agents/fabrika/kartlar').mkdir(parents=True, exist_ok=True)
(birincil/'_agents/fabrika/kartlar/isX.json').write_text(json.dumps({'is':'isX','siniflar':[],'sultan':False}), encoding='utf-8')
alan = pathlib.Path('$KOK/p1b-alan'); alan.mkdir(parents=True, exist_ok=True)
m.birincil_depo = lambda depo: birincil
m._kos = lambda komut, cwd, zaman=600: (0, 'bileyi/x.py'+chr(10)) if '--name-only' in komut else (0, 'GEÇTİ')
class N: pass
n=N(); n.depo=str(alan); n.is_='isX'; n.dal='d'; n.sinif_dosya=None; n.kuru=True; n.havuz_depo=str(alan)
os.environ['BILEYI_ANAHTAR']='$KOK/acik2'
t=io.StringIO()
with contextlib.redirect_stdout(t): rc = m.komut_devam(n)
cik = t.getvalue()
assert 'kart yok' not in cik, cik
assert rc == 0, (rc, cik[-300:])
"
kapi "P2 kill-switch kapalıyken devam rc=4 (birleştirmez)" 4 env BILEYI_ANAHTAR="$ANAH" sh -c \
  "python3 '$B' --depo '$KOK/oda' dur --gerekce 'sinav kilidi' >/dev/null && python3 '$B' --depo '$KOK/oda' devam --is x --dal y; r=\$?; python3 '$B' --depo '$KOK/oda' ac --gerekce 'sinav' >/dev/null; exit \$r"
kapi "P3 🔴 sınıf YUKARI çıkarsa birleştirme YOK — hem rc hem SEBEP ölçülür" 0 python3 -c "
import importlib.util as u, json, pathlib, io, contextlib, os
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
kok = pathlib.Path('$KOK/yukari'); (kok/'_agents/fabrika/kartlar').mkdir(parents=True, exist_ok=True)
(kok/'_agents/fabrika/kartlar/is1.json').write_text(json.dumps(
    {'is':'is1','siniflar':[],'sultan':False}), encoding='utf-8')
cagrilan = []
def sahte(komut, cwd, zaman=600):
    cagrilan.append(komut)
    return (0, 'hooks/yeni.js\n') if '--name-only' in komut else (0, 'GEÇTİ')
m._kos = sahte
class N: pass
n=N(); n.depo=str(kok); n.is_='is1'; n.dal='d'; n.sinif_dosya=None; n.kuru=False
os.environ['BILEYI_ANAHTAR']='$KOK/acik-anahtar'
t=io.StringIO()
with contextlib.redirect_stdout(t):
    rc = m.komut_devam(n)
cik = t.getvalue()
assert rc == 1, rc
assert 'SINIF YUKARI ÇIKTI' in cik, 'rc=1 geldi ama SEBEP bu degil: ' + cik[-200:]
# Ve en onemlisi: BIRLESTIRME hic denenmemis olmali.
assert not any('merge' in ' '.join(k) for k in cagrilan), 'birlestirme denendi!'
"

echo "S · 🔴 sürtünme yüzeyi ADAY HATTINA girer (tur-3 bulgusu, ciddi)"
kapi "S1 rapor tablosu ayrıştırılır ve eşiği aşanlar aday olur" 0 python3 -c "
import importlib.util as u
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
rapor = chr(10).join([
  '=== baslik ===',
  '  SINIF              OLAY  OTURUM  TREND',
  '  dosya-bulunamadi     25       4    ^',
  '  destructive-blok     30       4    ^',
  '  commit-lint reddi     3       2    v',
  '  auto-mode izin-reddi    4       1    ^',
  '  --- TOPLAM 62 olay / 5 oturum',
  '  En son ornekler:',
  '    dosya-bulunamadi x Nexus x 2026-10-09 x tetik',
])
a = m.surtunme_ayristir(rapor, 10)
ad = {x['tekrar']: x['sayi'] for x in a if '_atlanan' not in x}
assert ad == {'dosya-bulunamadi': 25, 'destructive-blok': 30}, ad
a2 = [x for x in m.surtunme_ayristir(rapor, 3) if '_atlanan' not in x]
ad2 = {x['tekrar'] for x in a2}
assert 'commit-lint reddi' in ad2, ad2
assert 'auto-mode izin-reddi' in ad2, ad2
assert not any('Nexus' in t for t in ad2), ad2
"
kapi "S2 ayrıştırılamayan satır SESSİZCE atlanmaz, sayılır" 0 python3 -c "
import importlib.util as u
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
rapor = '  SINIF  OLAY  OTURUM  TREND\n  bozuk satir burada\n  iyi-sinif  20  3  ^\n  --- TOPLAM\n'
a = m.surtunme_ayristir(rapor, 10)
atl = [x for x in a if '_atlanan' in x]
assert atl and atl[0]['_atlanan'] == 1, a
"
kapi "S3 eşiği aşmayan sürtünme sınıfı aday OLMAZ" 0 python3 -c "
import importlib.util as u
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
rapor = '  SINIF  OLAY  OTURUM  TREND\n  az-olan  2  1  v\n  --- TOPLAM\n'
a = [x for x in m.surtunme_ayristir(rapor, 10) if '_atlanan' not in x]
assert a == [], a
"
iceren "S4 ölçüm çıktısı sürtünme eşiğini yazar" "olay ≥" env BILEYI_ANAHTAR="$ANAH" "${O[@]}" olc --gun 0

mkdir -p "$KOK/surt/_agents/handoff" "$KOK/surt/scripts"
cat > "$KOK/surt/scripts/friction-report.sh" <<'FR'
#!/usr/bin/env bash
echo "  SINIF              OLAY  OTURUM  TREND"
echo "  cokca-olan           42       6    ^"
echo "  --- TOPLAM 42 olay"
FR
chmod +x "$KOK/surt/scripts/friction-report.sh"
python3 - "$KOK/surt/_agents/handoff" <<'PY'
import json, sys, pathlib
from datetime import date
d = pathlib.Path(sys.argv[1]); b = date.today().isoformat()
# Havuzda esigi asan HICBIR tekrar yok -> tek aday kaynagi SURTUNME olmali.
kay = [{'id': f'e{i}', 'tarih': b, 'baslik': f'bambaska kelimeler {i} burada', 'gercek': ''} for i in range(3)]
(d/'bulgu-havuzu.jsonl').write_text(''.join(json.dumps(k, ensure_ascii=False)+chr(10) for k in kay), encoding='utf-8')
(d/'layiha-aday-havuzu.jsonl').write_text('', encoding='utf-8')
PY
kapi "S5 🔴 SONUÇ: sürtünme sınıfı FİİLEN aday olur (yardımcı değil, HAT ölçülür)" 0 python3 -c "
import importlib.util as u, io, contextlib, json, pathlib, os
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
# 🔴 İşlev düzeyi: üretim kimliği makineye bağlı, SINAV olmamalı (CI yakaladı).
m.kimlik = lambda depo, zorunlu=True: 'sinav-ajani'
os.environ['BILEYI_ANAHTAR'] = '$ANAH'
kok = pathlib.Path('$KOK/surt')
class N: pass
n=N(); n.depo=str(kok); n.havuz_depo=str(kok); n.esik_dosya='$ES'; n.gun=0
n.ikili_esik=None; n.kuru=False
t=io.StringIO()
with contextlib.redirect_stdout(t): rc = m.komut_tur(n)
assert rc == 0, (rc, t.getvalue()[-400:])
a = [json.loads(l) for l in (kok/'_agents/handoff/layiha-aday-havuzu.jsonl').read_text(encoding='utf-8').splitlines() if l.strip()]
yuz = {x['yuzey'] for x in a}
assert 'surtunme' in yuz, f'surtunme yuzeyi adaya GIRMEDI: {yuz}'
x = [k for k in a if k['yuzey'] == 'surtunme'][0]
assert x['sayi'] == 42, x
assert x['kaynak_bulgular'] == ['surtunme:cokca-olan'], x
"

echo "T · 🔴 damga YALNIZ bağlı adayı kapatır (tur-3 bulgusu, ciddi: yanlış kapanış)"
kapi "T1 iki adaydan yalnız BAĞLI olanın kaynakları kapanır" 0 python3 -c "
import importlib.util as u, pathlib, json, io, contextlib
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
kok = pathlib.Path('$KOK/t1'); (kok/'_agents/handoff').mkdir(parents=True, exist_ok=True)
(kok/'_agents/fabrika').mkdir(parents=True, exist_ok=True)
(kok/'_agents/handoff/bulgu-havuzu.jsonl').write_text('{}'+chr(10), encoding='utf-8')
(kok/'_agents/fabrika/bileyi-tur.json').write_text(json.dumps({'asama':'yazim-bekliyor','adaylar':[
    {'anahtar':'ikili:a b','tekrar':'a b','kaynak_bulgular':['b0001','b0002'],'is':'isA'},
    {'anahtar':'ikili:c d','tekrar':'c d','kaynak_bulgular':['b0009']}]}, ensure_ascii=False), encoding='utf-8')
t=io.StringIO()
with contextlib.redirect_stdout(t): m._kapanis_damgasi(kok, 'isA', 'PR #1')
satir=[l for l in (kok/'_agents/handoff/bulgu-havuzu.jsonl').read_text(encoding='utf-8').splitlines() if l.strip()]
d=json.loads(satir[-1])
assert d['kapatilan'] == ['b0001','b0002'], d['kapatilan']
assert 'b0009' not in d['kapatilan'], 'BAGLI OLMAYAN adayin kaynagi da kapatildi — yanlis kapanis'
"
kapi "T2 işe BAĞLI aday yoksa damga ATILMAZ ve sebebi yazılır" 0 python3 -c "
import importlib.util as u, pathlib, json, io, contextlib
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
kok = pathlib.Path('$KOK/t2'); (kok/'_agents/handoff').mkdir(parents=True, exist_ok=True)
(kok/'_agents/fabrika').mkdir(parents=True, exist_ok=True)
(kok/'_agents/handoff/bulgu-havuzu.jsonl').write_text('{}'+chr(10), encoding='utf-8')
(kok/'_agents/fabrika/bileyi-tur.json').write_text(json.dumps({'asama':'yazim-bekliyor','adaylar':[
    {'anahtar':'ikili:a b','tekrar':'a b','kaynak_bulgular':['b0001']}]}, ensure_ascii=False), encoding='utf-8')
t=io.StringIO()
with contextlib.redirect_stdout(t): m._kapanis_damgasi(kok, 'baska-is', 'PR #1')
cik=t.getvalue()
assert 'BAĞLI DEĞİL' in cik, cik
assert 'YANLIŞ KAPANIŞ' in cik
n=len([l for l in (kok/'_agents/handoff/bulgu-havuzu.jsonl').read_text(encoding='utf-8').splitlines() if l.strip()])
assert n == 1, 'damga atilmis olmamali'
"
kapi "T3 tur ancak TÜM adaylar kapanınca kapanır" 0 python3 -c "
import importlib.util as u, pathlib, json, io, contextlib
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
kok = pathlib.Path('$KOK/t3'); (kok/'_agents/handoff').mkdir(parents=True, exist_ok=True)
(kok/'_agents/fabrika').mkdir(parents=True, exist_ok=True)
(kok/'_agents/handoff/bulgu-havuzu.jsonl').write_text('{}'+chr(10), encoding='utf-8')
dy = kok/'_agents/fabrika/bileyi-tur.json'
dy.write_text(json.dumps({'asama':'yazim-bekliyor','adaylar':[
    {'anahtar':'k1','tekrar':'a b','kaynak_bulgular':['b1'],'is':'isA'},
    {'anahtar':'k2','tekrar':'c d','kaynak_bulgular':['b2'],'is':'isB'}]}, ensure_ascii=False), encoding='utf-8')
with contextlib.redirect_stdout(io.StringIO()): m._kapanis_damgasi(kok, 'isA', 'PR #1')
assert json.loads(dy.read_text(encoding='utf-8'))['asama'] == 'yazim-bekliyor', 'tur erken kapandi'
with contextlib.redirect_stdout(io.StringIO()): m._kapanis_damgasi(kok, 'isB', 'PR #2')
assert json.loads(dy.read_text(encoding='utf-8'))['asama'] == 'kapandi', 'tur kapanmadi'
"
kapi "T4 --anahtar verilmezse kart bunu SÖYLER (sessiz kalmaz)" 0 python3 -c "
import importlib.util as u, pathlib, io, contextlib, os
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
sf = pathlib.Path('$KOK/sahte-fabrika2'); sf.mkdir(parents=True, exist_ok=True)
(sf/'kart.sh').write_text('#!/usr/bin/env bash'+chr(10)+'echo kart-acildi'+chr(10), encoding='utf-8')
m.FABRIKA = sf
m.kimlik = lambda depo, zorunlu=True: 'sinav-ajani'
m._kos = lambda komut, cwd, zaman=600: (0, 'kart-acildi')
class N: pass
n=N(); n.depo='$KOK/oda'; n.havuz_depo='$KOK/oda'; n.is_='x'; n.hedef=['bileyi/a.py']
n.cumle=None; n.sinif_dosya=None; n.anahtar=None; n.kuru=False
t=io.StringIO()
with contextlib.redirect_stdout(t): rc = m.komut_kart(n)
cik = t.getvalue()
assert 'kapanış damgası ATILAMAZ' in cik, cik
assert rc == 0, rc
"

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[[ $DUSEN -eq 0 ]]
