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
# Kullanım:  tablo.py <cipa.md>              KUTULU tabloyu bas (Sultan 18 Eki: 'bu tarz bir görünüm istiyorum') · rc 0 · çıpa okunamazsa rc 1
#            tablo.py <cipa.md> --md         düz (markdown) tablo — makine/metin kanalları için
#            tablo.py <cipa.md> --json       ham alanlar
#            tablo.py <cipa.md> --kapanis     açık madde yoksa rc 0; varsa listeyi basar, rc 4
import json, re, sys

MADDE = re.compile(r'^- \[([ ~xX-])\]\s*((G?\d+)\))?\s*(.*)$')         # bugun.mjs MADDE ile AYNI
GOREV = re.compile(r'gorev_[A-Za-z0-9]{10,40}')                          # bugun.mjs GOREV ile AYNI
SONUC = re.compile(r'^(.*?)\s*→\s*([A-ZĞÜŞİÖÇ][A-ZĞÜŞİÖÇ ]{2,})(?:\s*·\s*(.*))?$')
SAHIP = re.compile(r'\s*\(sahip:\s*([^)]+)\)')
# D1 (L73): "YYYY-MM-DD Sultan: <sonuç> (sohbet · <oturum-ref> · "<kırpık>" · beyan:<AJAN>)" — üç parça zorunlu
D1 = re.compile(r'\d{4}-\d{2}-\d{2} Sultan: (.+?) ?\(sohbet · [^·()]+ · "[^"]{1,120}" · beyan:\S+\)')
# 🔴 biçim yetmez (bağımsız göz #357 tur 4 + #366 tur 1): sonuç kısmı KAPALI karar kümesinden biri, TAM eşleşme — cipa.sh ile AYNI küme
KARAR = re.compile(r'(yarına )?ertele(nsin|ndi|yelim|yin)?', re.I)


def ertele_d1(notlar):
    m = D1.search(notlar)
    return bool(m and KARAR.fullmatch(m.group(1).strip()))
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


# Durum işaretleri (Sultan'ın 18 Eki ekran örneği): ✅ kapandı · 🟡 yarım · ⬜ açık · ⏸ ertelendi · ➖ geri alındı
ISARET = {'bitti': '✅', 'yarim': '🟡', 'acik': '⬜', 'ertelendi': '⏸', 'geri': '➖'}


GENIS = set(ISARET.values()) | {'📋'}


def _gen(s):
    # görünür genişlik: durum işaretleri ve emoji 2 hücre (⏸ U+23F8 de dahil — göz #369 tur 1), gerisi 1
    return sum(2 if (ch in GENIS or ord(ch) >= 0x1F000 or 0x2600 <= ord(ch) <= 0x27BF) else 1 for ch in s)


def _hiz(s, w, orta=False):
    bos = w - _gen(s)
    if orta:
        sol = bos // 2; return ' ' * sol + s + ' ' * (bos - sol)
    return s + ' ' * bos


def ozet_satiri(c):
    n = len(c['maddeler']); say = lambda d: sum(1 for m in c['maddeler'] if m['durum'] == d)
    return '%d madde · %d ✅ kapandı · %d 🟡 yarım · %d ⬜ açık' % (n, say('bitti'), say('yarim'), say('acik')) + \
           (' · %d ⏸ ertelendi' % say('ertelendi') if say('ertelendi') else '') + (' · %d ➖ geri' % say('geri') if say('geri') else '')


def tablo_kutu(c, genislik=120):
    satirlar = []
    for i, m in enumerate(c['maddeler'], 1):
        madde = GOREV.sub('', m['metin']).strip() + ''.join(' · görev …%s' % g[-5:] for g in m['gorevler'])
        satirlar.append([str(m['etiket'] or i), madde, m['sahip'] or '—', ISARET[m['durum']], m['kanit'] or '—'])
    bas = ['#', 'Madde', 'Sahip', 'Durum', 'Kanıt']
    w = [max(_gen(r[k]) for r in [bas] + satirlar) for k in range(5)]
    w[3] = max(w[3], 5)
    # madde ve kanıt sütunları toplam genişliğe sığsın: taşanı kısalt (… ile), düşük öncelik kanıt
    sabit = w[0] + w[2] + w[3] + 16
    kalan = max(genislik - sabit, 30)
    if w[1] + w[4] > kalan:
        w[4] = min(w[4], max(12, kalan // 3)); w[1] = kalan - w[4]
    def kirp(s, n):
        # görünür genişliğe göre kes (kod noktasına göre değil — göz #369 tur 2: metinde emoji varsa taşıyordu)
        if _gen(s) <= n:
            return s
        out, w = '', 0
        for ch in s:
            cw = _gen(ch)
            if w + cw > n - 1:
                break
            out += ch; w += cw
        return out.rstrip() + '…'
    cizgi = lambda l, m_, r: l + m_.join('─' * (x + 2) for x in w) + r
    out = [cizgi('┌', '┬', '┐'), '│ ' + ' │ '.join(_hiz(bas[k], w[k], orta=k in (0, 3)) for k in range(5)) + ' │', cizgi('├', '┼', '┤')]
    for r in satirlar:
        r = [r[0], kirp(r[1], w[1]), kirp(r[2], w[2]), r[3], kirp(r[4], w[4])]
        out.append('│ ' + ' │ '.join(_hiz(r[k], w[k], orta=k in (0, 3)) for k in range(5)) + ' │')
    out.append(cizgi('└', '┴', '┘'))
    return '\n'.join(out)


def main(a):
    if not a or a[0].startswith('--'):
        sys.stderr.write('kullanım: tablo.py <cipa.md> [--md|--json|--kapanis]\n'); return 2
    try:
        c = ayristir(open(a[0], encoding='utf-8').read())
    except OSError as e:
        sys.stderr.write('çıpa okunamadı: %s (%s)\n' % (a[0], type(e).__name__)); return 1
    if '--json' in a:
        print(json.dumps(c, ensure_ascii=False, indent=2)); return 0
    print('📋 BUGÜN · %s · %s' % (c['tarih'] or 'tarihsiz', ozet_satiri(c)))
    print(tablo_md(c) if '--md' in a else tablo_kutu(c))
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
