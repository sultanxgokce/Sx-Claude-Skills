#!/usr/bin/env python3
"""oda-dagit.py — odasız görevi ATANAN koltuğun ekip-kaydı odasına eşler (Kuzey Yıldızı 3.6: tek defter, oda süzgeci; süzgecin anlamlı olması için veri).

Ne yapar (yalnız defterin KENDİ uçlarından — kapılar atlanmaz; KURU koşu varsayılan, --uygula ile yazar):
  · Bitmemiş (acik · havuz · sira-bende · bekliyor · calisiliyor · onay-bekliyor) ve odası BOŞ görevleri alır (dolu odaya DOKUNMAZ).
  · Görevin ATANAN koltuğunu ekip kaydında (aile-registry.yaml `- id:` + `oda:`) bulur; o koltuğun odası varsa görev o odaya yazılır.
    Atanan yok / kayıtta yok / odası yok → görev 'eşlenemedi' listesinde kalır, UYDURULMAZ.
  · --kutu <kutu> ile tek kutuya daralır (varsayılan: jetonun gördüğü bütün görevler).
  · Yazım düz PATCH {oda} — odasız görevde ilk canlı değerdir, çatışma açmaz (dolu oda zaten dışarıda).
  · --uygula için --beklenen N (eşlenecek görev sayısı N değilse hiçbir şey yazılmaz) ve --geri-al <dosya.jsonl> (yazmadan ÖNCE id+eski+yeni listesi diske iner) ZORUNLU.
  · İkinci koşu 0 değişiklik yapar (idempotent). Ekip kaydı: GOREV_EKIP_KAYDI (varsayılan Nexus aile-registry.yaml).
rc: 0 tamam · 1 bir yazım reddedildi · 2 argüman/izin reddi · 3 ölçülemedi (jeton/uç/ekip kaydı)
"""
import json, os, re, sys, unicodedata, urllib.request, urllib.error
from collections import Counter

UC = os.environ.get('DEFTER_UC', 'http://cloudtop-defter:8791')
JY = os.environ.get('DEFTER_JETON_YOL', '/config/defter-jeton')
KAYIT = os.environ.get('GOREV_EKIP_KAYDI', '/config/projects/Nexus/_agents/handoff/aile-registry.yaml')
BITMEMIS = {'acik', 'havuz', 'sira-bende', 'bekliyor', 'calisiliyor', 'onay-bekliyor'}
args = sys.argv[1:]
UYGULA = '--uygula' in args
def _deger(bayrak):
    if bayrak not in args: return None
    i = args.index(bayrak)
    return args[i + 1] if i + 1 < len(args) else ''
KUTU = _deger('--kutu'); GERI_AL = _deger('--geri-al'); BEK = _deger('--beklenen')
for a in args:
    if a.startswith('--') and a not in ('--uygula', '--kutu', '--geri-al', '--beklenen'):
        print(f'REDDEDİLDİ: bilinmeyen bayrak {a}'); sys.exit(2)
if KUTU == '' or GERI_AL == '' or BEK == '':
    print('REDDEDİLDİ: --kutu / --geri-al / --beklenen değer ister'); sys.exit(2)
BEKLENEN = None
if BEK is not None:
    try: BEKLENEN = int(BEK)
    except ValueError: print('REDDEDİLDİ: --beklenen bir sayı ister'); sys.exit(2)
if UYGULA and BEKLENEN is None:
    print('REDDEDİLDİ: --uygula için --beklenen <sayı> zorunlu (izin bir sayıyadır; sayı tutmazsa yazılmaz)'); sys.exit(2)
if UYGULA and not GERI_AL:
    print('REDDEDİLDİ: --uygula için --geri-al <dosya.jsonl> zorunlu (yazmadan önce görev kimliği + eski + yeni değer listelenir)'); sys.exit(2)

try: J = open(JY, encoding='utf-8').read().strip()
except OSError: print(f'ÖLÇÜLEMEDİ: jeton okunamadı ({JY})'); sys.exit(3)
if not J: print('ÖLÇÜLEMEDİ: jeton boş'); sys.exit(3)

def iste(metot, yol, govde=None):
    r = urllib.request.Request(UC + yol, method=metot, headers={'x-defter-jeton': J, 'content-type': 'application/json'},
                               data=json.dumps(govde, ensure_ascii=False).encode() if govde is not None else None)
    try:
        with urllib.request.urlopen(r, timeout=15) as c: return c.status, json.loads(c.read().decode() or '{}')
    except urllib.error.HTTPError as e:
        try: return e.code, json.loads(e.read().decode() or '{}')
        except Exception: return e.code, {}
    except Exception as e:
        return 0, {'hata': str(e)}

def n(s): return ''.join(c for c in unicodedata.normalize('NFKD', str(s).casefold()) if not unicodedata.combining(c))
def ekip_odalari(yol):
    """koltuk-id (normalize) → oda; yalnız `- id:` bloğundaki `oda:` satırı (gorev.sh _oda_coz ile aynı kural)."""
    try: satirlar = open(yol, encoding='utf-8').read().splitlines()
    except OSError: return None
    m_ = {}; bu = None
    for s in satirlar:
        m = re.match(r'^\s*-\s+id:\s*(\S+)', s)
        if m: bu = n(m.group(1)); continue
        m = re.match(r'^\s+oda:\s*([a-z][a-z0-9-]{1,30})\s*(#.*)?$', s)
        if m and bu and bu not in m_: m_[bu] = m.group(1)
    return m_

ODALAR = ekip_odalari(KAYIT)
if ODALAR is None: print(f'ÖLÇÜLEMEDİ: ekip kaydı okunamadı ({KAYIT})'); sys.exit(3)
if not ODALAR: print(f'ÖLÇÜLEMEDİ: ekip kaydında hiç oda satırı yok ({KAYIT}) — eşleme yapılamaz'); sys.exit(3)

kod, j = iste('GET', '/gorevler')
if kod != 200 or not isinstance(j.get('gorevler'), list): print(f'ÖLÇÜLEMEDİ: defter okunamadı http={kod} {j.get("hata","")}'); sys.exit(3)
G = j['gorevler']
def kutu(g): return g.get('canli', {}).get('kutu') or g.get('ekleyen_kutu', '')
aday = [g for g in G if isinstance(g.get('canli', {}).get('gorev_durumu'), str) and g['canli']['gorev_durumu'] in BITMEMIS
        and not g['canli'].get('oda') and (not KUTU or kutu(g) == KUTU)]
es, yok = [], Counter()
for g in aday:
    at = g['canli'].get('atanan')
    if not isinstance(at, str) or not at.strip(): yok['atanan yok'] += 1; continue
    oda = ODALAR.get(n(at))
    if not oda: yok[f'koltuk kayıtta yok ya da odasız: {at}'] += 1; continue
    es.append({'id': g['id'], 'kutu': kutu(g), 'atanan': at, 'eski': {'oda': None}, 'yeni': {'oda': oda}})
kip = 'UYGULA' if UYGULA else 'KURU (hiçbir şey yazılmaz; yazmak için --uygula --beklenen N --geri-al <dosya>)'
print(f'oda-dagit · {kip} · kutu: {KUTU or "hepsi"} · ekip kaydı: {KAYIT} ({len(ODALAR)} koltuk odalı)')
print(f'odasız bitmemiş görev: {len(aday)} · eşlenecek: {len(es)} · eşlenemeyen: {sum(yok.values())}')
for k, v in Counter((e['kutu'], e['yeni']['oda']) for e in es).most_common(): print(f'  {k[0]}/{k[1]}: {v}')
for k, v in yok.most_common(): print(f'  eşlenemedi · {k}: {v}')
if not UYGULA:
    for e in es[:200]: print(f'  {e["id"]}  {e["kutu"]}  {e["atanan"]:<10} → {e["yeni"]["oda"]}')
    sys.exit(0)
if BEKLENEN != len(es): print(f'REDDEDİLDİ: --beklenen {BEKLENEN} ≠ eşlenecek {len(es)} — hiçbir şey yazılmadı'); sys.exit(2)
try:
    with open(GERI_AL, 'w', encoding='utf-8') as f:
        for e in es: f.write(json.dumps(e, ensure_ascii=False) + '\n')
except OSError as x: print(f'REDDEDİLDİ: geri-alma listesi yazılamadı ({x}) — tek PATCH bile gitmedi'); sys.exit(2)
yazildi, red = 0, []
for e in es:
    k, r = iste('PATCH', f'/kayit/{e["id"]}', {'oda': e['yeni']['oda']})
    if k == 200: yazildi += 1
    else: red.append((e['id'], k, r.get('hata'), r.get('ek')))
print(f'yazıldı: {yazildi}/{len(es)} · geri-alma listesi: {GERI_AL}')
for r in red: print(f'  ✗ {r[0]} http={r[1]} {r[2]} {json.dumps(r[3], ensure_ascii=False) if r[3] else ""}')
sys.exit(1 if red else 0)
