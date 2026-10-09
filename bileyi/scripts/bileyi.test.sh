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
  "python3 '$B' --depo '$KOK/oda' --esik-dosya '$ES' dur --gerekce 'sinav' >/dev/null && python3 '$B' --depo '$KOK/oda' --esik-dosya '$ES' tur"
kapi "H2 🔴 kapalıyken 'olc' YİNE çalışır (ölçüme erişim kesilmez)" 0 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" --esik-dosya "$ES" olc --gun 0
kapi "H3 🔴 kapalıyken 'durum' YİNE çalışır" 0 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" --esik-dosya "$ES" durum
iceren "H4 durum kapalı olduğunu ve gerekçesini söyler" "KAPALI" \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" --esik-dosya "$ES" durum
kapi "H5 açılınca tam tur yine koşar" 0 env BILEYI_ANAHTAR="$ANAH" sh -c \
  "python3 '$B' --depo '$KOK/oda' --esik-dosya '$ES' ac --gerekce 'sinav' >/dev/null && python3 '$B' --depo '$KOK/oda' --esik-dosya '$ES' tur --gun 0"
kapi "H6 'dur' gerekçesiz çağrılamaz" 2 \
  env BILEYI_ANAHTAR="$ANAH" python3 "$B" --depo "$KOK/oda" --esik-dosya "$ES" dur

echo "I · 🔴 kimlik kapısı (çivili yol / sızıntı panzehiri)"
kapi "I1 kimlik aracı yoksa rc=3 — başkasının defterine DÜŞMEZ" 0 python3 -c "
import importlib.util as u
s=u.spec_from_file_location('b','$B'); m=u.module_from_spec(s); s.loader.exec_module(m)
def sahte(depo): raise m.Durdu('kimlik sorulamadi — OLCEMEDIM', 3)
m.kimlik = sahte
class N: pass
n=N(); n.depo='$KOK/oda'; n.esik_dosya='$ES'; n.gun=0; n.ikili_esik=None
try:
    m.komut_olc(n)
except m.Durdu as e:
    assert e.rc == 3, e.rc
else:
    raise SystemExit(1)
# main AYNI durumu 3 cikis koduna cevirmeli — kapi ile cikis kodu arasindaki kablo
assert m.main(['--depo','$KOK/oda','--esik-dosya','$ES','olc','--gun','0']) == 3
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
kapi "J1 araç bulgu/aday havuzuna YAZMAZ (yalnız okur)" 0 python3 -c "
k = open('$B', encoding='utf-8').read()
kod = '\n'.join(l for l in k.splitlines() if not l.lstrip().startswith('#'))
import re
# Yazma yuzeyi YALNIZ kill-switch dosyasi olmali.
yazmalar = re.findall(r'write_text\(|open\([^)]*[\"\\']w[\"\\']', kod)
assert len(yazmalar) == 1, f'beklenmeyen yazma yuzeyi: {len(yazmalar)}'
assert 'anahtar_yolu' in kod
for yasak in ('bulgu-havuzu.jsonl\", \"a\"', 'layiha-aday-havuzu.jsonl\", \"a\"'):
    assert yasak not in kod, yasak
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

echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[[ $DUSEN -eq 0 ]]
