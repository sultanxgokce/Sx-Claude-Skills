#!/usr/bin/env bash
# Gerçek veri ölçümü: üç deponun origin/main'indeki KUTU-DISI.jsonl defterlerinde (3 Kas 12:05 sonrası, önceki düzeltmenin bittiği an)
# ikinci gelişi eski kural (metin birebir) ve yeni kural (yüzey parçası ortak) kaç işte tanıyor. Yeni kuralın işlevi HEAD'deki denetci.sh'tan
# ÇIKARILIR (kopya değil): betik işlevi dosyadan okur, bulunamazsa rc 3 (ölçülemedi). Depo yoksa o depo atlanır ve söylenir.
set -u
kok="$(git rev-parse --show-toplevel)" || exit 3
python3 - "$kok/yazilim-fabrikasi/scripts/denetci.sh" "${KD_ESIK:-2026-11-03T12:05}" /config/projects/cloudtop /config/projects/Sx-Claude-Skills /config/projects/Nexus <<'PY'
import json, subprocess, sys, re, os
kaynak, esik, depolar = sys.argv[1], sys.argv[2], sys.argv[3:]
s = open(kaynak, encoding='utf-8').read(); i = s.find('def parcalar(y):'); j = s.find('\nkd=[b for b in', i)
if i < 0 or j < 0: print('ÖLÇÜLEMEDİ: parcalar() denetci.sh içinde bulunamadı'); sys.exit(3)
ns = {'re': re}; exec(s[i:j], ns); parcalar = ns['parcalar']
top = cok = eski_t = yeni_t = 0
for depo in depolar:
    if not os.path.isdir(depo): print('atlandı (depo yok): ' + depo); continue
    r = subprocess.run(['git','-C',depo,'ls-tree','-r','--name-only','origin/main','_agents/fabrika/kanit'], capture_output=True, text=True)
    if r.returncode: print('atlandı (okunamadı): ' + depo); continue
    n0 = cok
    for x in [a for a in r.stdout.split('\n') if a.endswith('/KUTU-DISI.jsonl')]:
        sat = [json.loads(l) for l in subprocess.run(['git','-C',depo,'show','origin/main:'+x], capture_output=True, text=True).stdout.split('\n') if l.strip()]
        sat = [k for k in sat if (k.get('zaman') or '') >= esik]
        if not sat: continue
        top += 1; turlar = sorted({k.get('tur') for k in sat})
        if len(turlar) < 2: continue
        cok += 1; e = y = False; gor_ne = set(); gor_y = set()
        for t in turlar:
            bu = [k for k in sat if k.get('tur') == t]
            e = e or any(k.get('ne') in gor_ne for k in bu); y = y or any(parcalar(k.get('yuzey')) & gor_y for k in bu)
            for k in bu: gor_ne.add(k.get('ne')); gor_y |= parcalar(k.get('yuzey'))
        eski_t += e; yeni_t += y
    print('%s: birden çok turda kutu dışı bulgu yazılan iş=%d' % (os.path.basename(depo), cok - n0))
print('eşik %s · kutu dışı defteri olan iş=%d · birden çok turda yazılan iş=%d' % (esik, top, cok))
print('ikinci gelişi tanıyan: eski kural (metin birebir)=%d · yeni kural (yüzey parçası ortak)=%d' % (eski_t, yeni_t))
sys.exit(0 if cok > 0 and yeni_t > eski_t else 1)
PY
