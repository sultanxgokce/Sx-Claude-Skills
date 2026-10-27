#!/usr/bin/env python3
"""dugum-bak — bir düğümün iki ucunu tek bakışta gösterir (salt okur · kart dugum-bak · CEZERİ düğümü 03T5RC'nin ölçüm aracı).

  gorev.sh dugum <gorev_id>   → kimlik düğüm görevi (y) ise o düğüm; bekleyen görev (x) ise onu bekleten bütün düğümler.

Her düğüm için: taşıyan (B, y) ve bekleyen (A, x) görevin durumu · SIRA kimde, ne yapmalı (komutuyla) · BAĞ iki tarafa da yazılmış mı.
  BAĞ TAM    açık düğümde x 'bekliyor' + notu 'bekliyor ← <B> düğümü <kod>' · kapanmış düğümde x artık bu düğümü beklemiyor
  BAĞ YARIM  bağ yalnız y'de (ör. protokolden önce kurulmuş düğüm) ya da kapanmış düğüm x'i 'bekliyor'da bırakmış
Girdi: /gorevler cevabı (gorev.sh çeker, jeton bu betiğe girmez) — argv[1] dosya yolu, argv[2] kimlik, argv[3] şimdi (epoch, sınav için).
Çıkış: 0 hepsi TAM · 1 en az bir YARIM · 3 ölçülemedi (görev görünmüyor / bekleyen görev bu jetonla görünmüyor / cevap bozuk) · 2 kullanım.
"""
import json
import re
import sys
import time
from datetime import datetime

DUGUM_RE = re.compile(r'^([a-z][a-z0-9-]{1,30}):(gorev_[A-Za-z0-9]{10,40})$')
KABUL_DK = 120   # protokol 4: teslimden iki saat sonra merkez bekçisi kendiliğinden kabul yazar


def cik(rc, satir):
    print(satir)
    sys.exit(rc)


if len(sys.argv) < 3 or not sys.argv[2].startswith('gorev_'):
    cik(2, 'kullanım: gorev.sh dugum <gorev_id>')
try:
    cevap = json.load(open(sys.argv[1], encoding='utf-8'))
    gorevler = [g for g in cevap['gorevler'] if isinstance(g, dict)]
except Exception as e:
    cik(3, f'ÖLÇÜLEMEDİ defter cevabı okunamadı ({type(e).__name__})')
SIMDI = float(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else time.time()
byId = {g.get('id'): g for g in gorevler}


def canli(g, alan):
    return (g.get('canli') or {}).get(alan)


def degerler(g, alan):
    return [v for v in ((g.get('alanlar') or {}).get(alan) or []) if isinstance(v, dict) and not v.get('duzeltildi')]


def kutu(g):
    return canli(g, 'kutu') or g.get('ekleyen_kutu') or '?'


def bas(g):
    return ((g.get('adlar') or [{}])[0].get('deger') or '')[:70]


def ep(ts):
    try:
        return datetime.fromisoformat(str(ts).replace('Z', '+00:00')).timestamp()
    except ValueError:
        return None


def bag(y):
    m = DUGUM_RE.match(str(canli(y, 'dugum_acar') or ''))
    return (m.group(1), m.group(2)) if m else None


hedef = byId.get(sys.argv[2])
if not hedef:
    cik(3, f'ÖLÇÜLEMEDİ {sys.argv[2]} bu jetonla görünmüyor (yok ya da başka kutunun görevi)')
if bag(hedef):
    dugumler = [hedef]
else:
    dugumler = [g for g in gorevler if bag(g) and bag(g)[1] == hedef['id']]
    if not dugumler:
        cik(0, f'{hedef["id"][-5:]} ({kutu(hedef)}) bir düğüm değil ve onu bekleten düğüm yok.')

rc = 0
for y in dugumler:
    A, xid = bag(y)
    B, kod, yid = kutu(y), y['id'][-5:], y['id']
    hd = canli(y, 'gorev_durumu') or 'acik'
    hali = canli(y, 'dugum_hali') or ''
    print(f"⛓ düğüm {kod} · {B} kutusu taşıyor → {A} kutusu bekliyor · '{bas(y)}'")
    print(f'  taşıyan  ({B}) {yid}  durum: {hd}' + (f' · düğüm: {hali}' if hali else ''))
    x = byId.get(xid)
    if not x:
        print(f'  bekleyen ({A}) {xid}  bu jetonla GÖRÜNMÜYOR')
        print('  bağ: ÖLÇÜLEMEDİ — bekleyen görevi görebilen jetonla bak (merkez görev görme rolü)')
        rc = max(rc, 3)
        continue
    xd = canli(x, 'gorev_durumu') or 'acik'
    xnot = canli(x, 'not') or ''
    print(f'  bekleyen ({A}) {xid}  durum: {xd}' + (f' · not: {xnot[:90]}' if xnot else ''))

    kapali = hali in ('kabul', 'geri') or hd in ('bitti', 'iptal')
    if hali == 'kabul':
        print(f'  sıra: yok — düğüm KABUL edildi, {A} kutusunun işi açıldı')
    elif hali == 'geri' or hd == 'iptal':
        print(f'  sıra: {A} — düğüm GERİ gönderildi; bekleyen iş yeniden {A} kutusunda')
    elif hd == 'bitti':
        print('  sıra: yok — düğüm görevi kapanmış')
    elif hd == 'onay-bekliyor':
        teslim = [ep(v.get('ts')) for v in degerler(y, 'gorev_durumu') if v.get('deger') == 'onay-bekliyor']
        t = next((t for t in reversed(teslim) if t), None)
        kalan = '' if t is None else (f' · {max(0, int((KABUL_DK * 60 - (SIMDI - t)) // 60))} dk içinde cevap yoksa kendiliğinden kabul'
                                      if SIMDI - t < KABUL_DK * 60 else ' · iki saat doldu: merkez bekçisi kendiliğinden kabul yazacak')
        print(f'  sıra: {A} — teslim edildi, kanıta bak: gorev.sh dugum-kabul {yid} "…" ya da gorev.sh dugum-eksik {yid} "<ne eksik>"{kalan}')
    elif hd == 'calisiliyor':
        print(f'  sıra: {B} — üstlenildi, iş sürüyor; bitince: gorev.sh bitti {yid} --kim <AJAN> --kare <yol> --surum <sürüm> | --olcum "önce=N sonra=M" | --belge <yol>')
    else:
        ek = ' (eksik dendi, iş geri döndü)' if hali == 'eksik' else ''
        print(f'  sıra: {B} — henüz üstlenilmedi{ek}: gorev.sh ustlen {yid} --kim <AJAN> --tahmin <dk>  · yapamıyorsan: gorev.sh dugum-geri {yid} "<sebep>"')

    beklenen = f'bekliyor ← {B} düğümü {kod}'
    if kapali:
        if xd == 'bekliyor' and xnot.startswith(beklenen):
            print(f'  bağ: YARIM — düğüm kapandı ama bekleyen iş hâlâ bu düğümü bekliyor görünüyor')
            rc = max(rc, 1)
        else:
            print('  bağ: TAM — düğüm kapandı, bekleyen iş artık bunu beklemiyor')
    elif xd == 'bekliyor' and xnot.startswith(beklenen):
        print(f"  bağ: TAM — iki tarafta da yazılı ('{beklenen}')")
    else:
        print(f"  bağ: YARIM — yalnız taşıyan tarafta; bekleyen işte '{beklenen}' yok (protokolden önce kurulmuş olabilir)")
        rc = max(rc, 1)
sys.exit(rc)
