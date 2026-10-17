#!/usr/bin/env python3
# tablo.py — günün çıpasını STANDART bugün tablosuna çevirir (madde · sahip · durum · kanıt) ve kapanış kapısını tutar.
#
# 🔴 NİÇİN VAR (gorev_01M54TNAQVP4PJ7M7MGZRPT7A7 · Sultan 17 Eki):
#   (a) Sabah planı ile gün ortası planı bugün listesini iki ayrı biçimde basıyordu; kokpitteki "Bugün"
#       paneli (BÂNİ, terminal-onar kapı/bugun.mjs) aynı çıpayı üçüncü bir gözle okuyordu. Üç okuyucu,
#       tek yazılı kural yoktu. Satır dilbilgisi artık sema/bugun-maddesi.md'de TEKTİR ve bu araç ile
#       kapının ayrıştırıcısı AYNI fikstürle (sema/ornek-cipa.md → sema/beklenen.json) sınanır.
#   (d) "Planlanan işler tamamlanmadan kapanış kabul edilmeyecek" (Sultan). Eski kapanış yarım kalanı
#       sessizce ertesi güne bırakıyordu. Artık açık/yarım madde varsa kapanış rc=4 döner; bir maddeyi
#       ertesi güne taşımanın TEK yolu Sultan'ın "ertele" kararının D1 damgasıdır (A06: damgayı ajan
#       uyduramaz — araç yalnız biçimini sınar, sözün kendisi Sultan'dandır).
#
# Kullanım:  tablo.py <cipa.md> [--json]      tabloyu bas (rc 0) · çıpa okunamazsa rc 1
#            tablo.py <cipa.md> --kapanis     açık madde yoksa rc 0; varsa listeyi basar, rc 4
import json, re, sys

MADDE = re.compile(r'^- \[([ ~xX-])\]\s*((G?\d+)\))?\s*(.*)$')         # bugun.mjs MADDE ile AYNI
GOREV = re.compile(r'gorev_[A-Za-z0-9]{10,40}')                          # bugun.mjs GOREV ile AYNI
SONUC = re.compile(r'^(.*?)\s*→\s*([A-ZĞÜŞİÖÇ][A-ZĞÜŞİÖÇ ]{2,})(?:\s*·\s*(.*))?$')
SAHIP = re.compile(r'\s*\(sahip:\s*([^)]+)\)')
# D1 (L73): "YYYY-MM-DD Sultan: <sonuç> (sohbet · <oturum-ref> · "<kırpık>" · beyan:<AJAN>)" — üç parça zorunlu
D1 = re.compile(r'\d{4}-\d{2}-\d{2} Sultan: (.+?) ?\(sohbet · [^·()]+ · "[^"]{1,120}" · beyan:\S+\)')
# 🔴 biçim yetmez (bağımsız göz #357 tur 4): sonuç kısmı "ertele" kararını taşımalı, olumsuzu değil — cipa.sh ile AYNI kural
ERTELE, ERTELEME = re.compile(r'ertele', re.I), re.compile(r'ertelen?m[eaı]', re.I)


def ertele_d1(notlar):
    m = D1.search(notlar)
    return bool(m and ERTELE.search(m.group(1)) and not ERTELEME.search(m.group(1)))
# Durum adları kokpit kapısının (bugun.mjs DURUM) adlarıyla AYNI: acik · yarim · bitti · geri (+ ertelendi).
# "açılmadı" ayrı durum değildir: açık + sonuç AÇILMADI (tabloda öyle okunur).
ETIKET = {'acik': 'açık', 'yarim': 'yarım', 'bitti': 'kapandı', 'ertelendi': 'ertelendi', 'geri': 'geri alındı'}


def etiket(m):
    return 'açılmadı' if m['durum'] == 'acik' and m['sonuc'] == 'AÇILMADI' else ETIKET[m['durum']]


def ayristir(metin):
    satirlar = metin.split('\n')
    bas = next((s for s in satirlar if 'GÜNÜN PLANI ÇIPASI' in s), '')
    t = re.search(r'(\d{4}-\d{2}-\d{2})', bas)
    maddeler = []
    for s in satirlar:
        m = MADDE.match(s)
        if not m:
            continue
        govde = m.group(4).strip()
        k = SONUC.match(govde)
        bas_kisim, sonuc, kuyruk = (k.group(1), k.group(2).strip(), k.group(3) or '') if k else (govde, '', '')
        parcalar = [p.strip() for p in kuyruk.split(' · ')] if kuyruk else []
        kanit = ' · '.join(p[len('kanıt:'):].strip() for p in parcalar if p.startswith('kanıt:'))
        notlar = ' · '.join(p for p in parcalar if not p.startswith('kanıt:'))
        sh = SAHIP.search(bas_kisim)
        im = m.group(1)
        durum = {' ': 'acik', '~': 'yarim', 'x': 'bitti', 'X': 'bitti', '-': 'geri'}[im]
        if im == '-' and sonuc == 'ERTELENDİ':
            # 🔴 damgasız erteleme ERTELEME DEĞİLDİR: biçimi tutmayan D1 maddeyi açık bırakır
            durum = 'ertelendi' if ertele_d1(notlar) else 'acik'
        etk = m.group(3) or ''
        maddeler.append({
            'etiket': etk, 'tur': 'gun-ortasi' if etk.startswith('G') else ('sabah' if etk else 'serbest'),
            'metin': SAHIP.sub('', bas_kisim).strip(), 'sahip': sh.group(1).strip() if sh else '',
            'durum': durum, 'sonuc': sonuc, 'kanit': kanit, 'not': notlar,
            'gorevler': list(dict.fromkeys(GOREV.findall(govde))),
        })
    return {'tarih': t.group(1) if t else None, 'maddeler': maddeler}


def tablo_md(c):
    s = ['| # | Madde | Sahip | Durum | Kanıt |', '|---|---|---|---|---|']
    for i, m in enumerate(c['maddeler'], 1):
        hucre = lambda x: (x or '—').replace('|', '/')
        madde = GOREV.sub('', m['metin']).strip() + ''.join(' · görev …%s' % g[-5:] for g in m['gorevler'])
        s.append('| %s | %s | %s | %s | %s |' % (m['etiket'] or i, hucre(madde), hucre(m['sahip']),
                                                 etiket(m), hucre(m['kanit'])))
    return '\n'.join(s)


def main(a):
    if not a or a[0].startswith('--'):
        sys.stderr.write('kullanım: tablo.py <cipa.md> [--json|--kapanis]\n'); return 2
    try:
        c = ayristir(open(a[0], encoding='utf-8').read())
    except OSError as e:
        sys.stderr.write('çıpa okunamadı: %s (%s)\n' % (a[0], type(e).__name__)); return 1
    if '--json' in a:
        print(json.dumps(c, ensure_ascii=False, indent=2)); return 0
    print('📋 BUGÜN · %s' % (c['tarih'] or 'tarihsiz'))
    print(tablo_md(c))
    if '--kapanis' in a:
        acik = [m for m in c['maddeler'] if m['durum'] in ('acik', 'yarim')]
        if acik:
            print('\n✗ KAPANIŞ KABUL EDİLMEDİ — %d madde açık:' % len(acik))
            for m in acik:
                print('  • %s %s (%s)' % (m['etiket'] or '-', GOREV.sub('', m['metin']).strip()[:80], etiket(m)))
            print('  Her madde ya kapanır (kanıtla) ya Sultan "ertele" der (D1 damgası). Sessiz taşıma yok.')
            return 4
        print('\n✓ kapanış: açık madde yok (%d madde)' % len(c['maddeler']))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
