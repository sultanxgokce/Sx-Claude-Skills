#!/usr/bin/env python3
"""oda.py — kutu–oda modeli: oda iskeleti, ortak ayardan oda ayarı üretimi, doğrulama, yazma kancası.

Karar belgesi: Nexus _agents/handoff/kutu-oda-kararlari-20261027.md (karar 9). Görev: gorev_01M5YHE18D38W4AHJM65VPXA9W.
  yeni <depo> <oda> --reis <koltuk> --hedef "..." --olcu "..."   oda klasörü iskeleti + ayar üretimi
  uret <depo>                                                   ortak ayardan HER odanın .claude/settings.json'unu üretir (idempotent)
  dogrula <depo>                                                iskelet + ayar tazeliği + hafıza ayrılığı (rc 0 temiz · 1 bulgu · 3 ölçülemedi)
  yol <depo> <oda>                                              açılış cwd'si: odanın mutlak klasörünü basar (koltuk başlatıcı `cd $(oda.sh yol …)` ile açar)
  kanca <oda_dizini> <ortak_json>                               PreToolUse kancası: stdin JSON, rc 2 = blok
  cekirdek-yaz <depo> <yol> --neden "<tek cümle>" [--siparis gorev_<kimlik>] [--dosya <kaynak>]
                                                                çekirdek ortak dosyaya TEK yazım yolu (Oda modeli 5 D4): içerik --dosya ya da stdin;
                                                                kim = DEFTER_JETON_YOL jetonundan (defter /ben), beyan değil; jetonsuz süreç ret

Depo düzeni:  <depo>/.claude/oda-ortak.json (ortak kaynak) · <depo>/<oda>/{CLAUDE.md, oda.json, hafiza/, .claude/{settings.json,skills,agents}}
"""
import fcntl
import fnmatch
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

ODA_AD = re.compile(r'^[a-z0-9][a-z0-9-]{0,40}$')
UTD = 'utf-8'
VARSAYILAN_ORTAK = {
    'izin': {'allow': [], 'deny': []},
    'ortak_veri': [],
    'cekirdek_komutlar': [],
}
YASAK_ODA_ANAHTAR = ('hooks', 'autoMemoryDirectory')   # üreticiye ait: oda-özel parça bunları ezemez
KANCA_ESLES = 'Write|Edit|MultiEdit|NotebookEdit|Bash'


def hata(msg, rc=1):
    print(msg, file=sys.stderr)
    sys.exit(rc)


def oku_json(yol):
    with open(yol, encoding=UTD) as f:
        return json.load(f)


def yaz_json(yol, d):
    os.makedirs(os.path.dirname(yol), exist_ok=True)
    with open(yol, 'w', encoding=UTD) as f:
        json.dump(d, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write('\n')


def ortak_oku(depo):
    yol = os.path.join(depo, '.claude', 'oda-ortak.json')
    d = oku_json(yol)
    for k in ('ortak_veri', 'cekirdek_komutlar'):
        if not isinstance(d.get(k, []), list):
            raise ValueError(f'{k} liste olmalı')
    iz = d.get('izin', {})
    if not isinstance(iz, dict):
        raise ValueError('izin sözlük olmalı')
    return d


def odalar(depo):
    """oda.json taşıyan her birinci düzey klasör bir odadır."""
    out = []
    for ad in sorted(os.listdir(depo)):
        if ad.startswith('.'):
            continue
        if os.path.isfile(os.path.join(depo, ad, 'oda.json')):
            out.append(ad)
    return out


def birlesik(a, b):
    """listeler birleşir (sırayı koruyup tekrarsız), sözlükler özyinelemeli, skaler b kazanır."""
    if isinstance(a, dict) and isinstance(b, dict):
        o = dict(a)
        for k, v in b.items():
            o[k] = birlesik(a[k], v) if k in a else v
        return o
    if isinstance(a, list) and isinstance(b, list):
        return a + [x for x in b if x not in a]
    return b


def oda_ayari(depo, oda, ortak, kanca_betik):
    abs_oda = os.path.join(os.path.abspath(depo), oda)
    ayar = {'permissions': {'allow': list(ortak.get('izin', {}).get('allow', [])), 'deny': list(ortak.get('izin', {}).get('deny', []))}}
    ozel_yol = os.path.join(abs_oda, '.claude', 'settings.oda.json')
    if os.path.isfile(ozel_yol):
        ozel = oku_json(ozel_yol)
        yasak = [k for k in YASAK_ODA_ANAHTAR if k in ozel]
        if yasak:
            raise ValueError(f'{oda}: settings.oda.json şu anahtarları taşıyamaz (üreticiye ait): {", ".join(yasak)}')
        ayar = birlesik(ayar, ozel)
    ayar['autoMemoryDirectory'] = os.path.join(abs_oda, 'hafiza')
    ortak_yol = os.path.join(os.path.abspath(depo), '.claude', 'oda-ortak.json')
    ayar.setdefault('hooks', {})
    ayar['hooks']['PreToolUse'] = [{
        'matcher': KANCA_ESLES,
        'hooks': [{'type': 'command', 'command': 'bash ' + ' '.join(shlex.quote(x) for x in (kanca_betik, 'kanca', abs_oda, ortak_yol))}],
    }]
    return ayar


def kanca_betik_yolu():
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), 'oda.sh')


def uret(depo):
    depo = os.path.abspath(depo)
    ortak = ortak_oku(depo)
    betik = kanca_betik_yolu()
    sonuc = []
    for oda in odalar(depo):
        hedef = os.path.join(depo, oda, '.claude', 'settings.json')
        yeni = oda_ayari(depo, oda, ortak, betik)
        eski = None
        if os.path.isfile(hedef):
            try:
                eski = oku_json(hedef)
            except Exception:
                eski = None
        for alt in ('skills', 'agents'):
            os.makedirs(os.path.join(depo, oda, '.claude', alt), exist_ok=True)   # ayar aynı olsa da iskelet eksiksiz kalır
        os.makedirs(os.path.join(depo, oda, 'hafiza'), exist_ok=True)
        if eski == yeni:
            sonuc.append((oda, 'aynı'))
            continue
        yaz_json(hedef, yeni)
        sonuc.append((oda, 'üretildi'))
    return sonuc


CLAUDE_SABLON = """# {ad} odası — master prompt

**Hedef:** {hedef}
**Ölçü:** {olcu}
**Reis:** {reis} (kalıcı koltuk). Oda yalnız kalıcı koltukla yönetilir.

## Sınırlar
- Kodu yalnız bu klasörde değiştirirsin (`{ad}/`). Başka odanın klasörüne ve depo kökündeki ortak ayara yazma kancası durdurur.
- Ortak veri: okuma serbest, yazma yalnız çekirdeğin komutundan (`.claude/oda-ortak.json` → `cekirdek_komutlar`). Doğrudan yazarsan kanca durdurur.
- Başka odaya iş gerekiyorsa sipariş görevi aç (düğümle), o odanın klasörüne dokunma.
- Kendi hafızan `{ad}/hafiza/`; öteki odanın hafızası sana görünmez.

## Bu dosyayı kim yazar
Bu dosya odanın kuralıdır; reis düzenler. `.claude/settings.json` ise `oda.sh uret` ile ortak ayardan ÜRETİLİR — elle düzenleme; oda-özel ayar `.claude/settings.oda.json`'a yazılır.
"""


def yeni(depo, oda, reis, hedef, olcu):
    depo = os.path.abspath(depo)
    if not os.path.isdir(depo):
        hata(f'depo yok: {depo}', 2)
    if not ODA_AD.match(oda):
        hata(f'oda adı geçersiz (küçük harf, rakam, tire): {oda}', 2)
    if not (reis and hedef and olcu):
        hata('--reis, --hedef ve --olcu zorunlu (oda = hedef + reis + ölçü)', 2)
    klasor = os.path.join(depo, oda)
    if os.path.exists(klasor):
        hata(f'oda klasörü zaten var: {klasor}', 2)
    ortak_yol = os.path.join(depo, '.claude', 'oda-ortak.json')
    if not os.path.isfile(ortak_yol):
        yaz_json(ortak_yol, VARSAYILAN_ORTAK)
        print(f'ortak ayar yoktu → varsayılan yazıldı: {ortak_yol}')
    os.makedirs(os.path.join(klasor, 'hafiza'))
    yaz_json(os.path.join(klasor, 'oda.json'), {'ad': oda, 'reis': reis, 'hedef': hedef, 'olcu': olcu, 'ek_yazma': []})
    with open(os.path.join(klasor, 'CLAUDE.md'), 'w', encoding=UTD) as f:
        f.write(CLAUDE_SABLON.format(ad=oda, hedef=hedef, olcu=olcu, reis=reis))
    with open(os.path.join(klasor, 'hafiza', 'MEMORY.md'), 'w', encoding=UTD) as f:
        f.write(f'# {oda} odası hafızası\n')
    uret(depo)
    print(f'oda kuruldu: {klasor}')


def dogrula(depo):
    depo = os.path.abspath(depo)
    bulgu = []
    try:
        ortak = ortak_oku(depo)
    except Exception as e:
        print(f'ÖLÇÜLEMEDİ: ortak ayar okunamadı ({e})')
        return 3
    od = odalar(depo)
    if not od:
        print('ÖLÇÜLEMEDİ: depoda hiç oda yok (oda.json taşıyan klasör bulunamadı)')
        return 3
    betik = kanca_betik_yolu()
    hafizalar = {}
    for oda in od:
        k = os.path.join(depo, oda)
        for gerekli in ('CLAUDE.md', 'oda.json'):
            if not os.path.isfile(os.path.join(k, gerekli)):
                bulgu.append(f'{oda}: {gerekli} yok')
        try:
            m = oku_json(os.path.join(k, 'oda.json'))
            if m.get('ad') != oda:
                bulgu.append(f'{oda}: oda.json ad={m.get("ad")!r} klasör adıyla uyuşmuyor')
            for a in ('reis', 'hedef', 'olcu'):
                if not str(m.get(a, '')).strip():
                    bulgu.append(f'{oda}: oda.json {a} boş (oda = hedef + reis + ölçü)')
        except Exception as e:
            bulgu.append(f'{oda}: oda.json okunamadı ({e})')
        ay = os.path.join(k, '.claude', 'settings.json')
        try:
            beklenen = oda_ayari(depo, oda, ortak, betik)
            if not os.path.isfile(ay):
                bulgu.append(f'{oda}: .claude/settings.json yok (oda.sh uret)')
            elif oku_json(ay) != beklenen:
                bulgu.append(f'{oda}: .claude/settings.json ortak ayardan üretilenle AYNI DEĞİL (elle düzenlenmiş ya da bayat; oda.sh uret)')
            hafizalar.setdefault(beklenen['autoMemoryDirectory'], []).append(oda)
        except Exception as e:
            bulgu.append(f'{oda}: ayar üretilemedi ({e})')
        for alt in ('hafiza', os.path.join('.claude', 'skills'), os.path.join('.claude', 'agents')):
            if not os.path.isdir(os.path.join(k, alt)):
                bulgu.append(f'{oda}: {alt}/ klasörü yok (oda.sh uret)')
        if not os.path.isfile(os.path.join(k, 'hafiza', 'MEMORY.md')):
            bulgu.append(f'{oda}: hafiza/MEMORY.md yok')
    for yol, ol in hafizalar.items():
        if len(ol) > 1:
            bulgu.append(f'hafıza ortak: {", ".join(ol)} → {yol}')
    for b in bulgu:
        print(f'  ✗ {b}')
    print(f'oda sayısı={len(od)} bulgu={len(bulgu)}')
    return 1 if bulgu else 0


# ───────────── kanca ─────────────
def cozumle(yol, cwd):
    if not os.path.isabs(yol):
        yol = os.path.join(cwd, yol)
    return os.path.realpath(yol)


def icinde(yol, kok):
    kok = os.path.realpath(kok)
    return yol == kok or yol.startswith(kok + os.sep)


def glob_uyar(rel, desenler):
    for d in desenler:
        if fnmatch.fnmatch(rel, d) or (d.endswith('/**') and (rel == d[:-3] or rel.startswith(d[:-2]))):
            return True
    return False


YONLENDIR = re.compile(r'(?:^|[^<>&0-9])(?:\d?>>?|&>>?|>\|)\s*("[^"]+"|\'[^\']+\'|[^\s;&|<>()]+)')
TEE = re.compile(r'\btee\b((?:\s+-[a-zA-Z]+)*)\s+((?:"[^"]+"|\'[^\']+\'|[^\s;&|<>()]+)(?:\s+(?:"[^"]+"|\'[^\']+\'|[^\s;&|<>()]+))*)')
SEDI = re.compile(r'\bsed\b[^;&|\n]*?\s-i\S*\s+(?:(?:-e|-f)\s+\S+\s+|\'[^\']*\'\s+|"[^"]*"\s+)?((?:"[^"]+"|\'[^\']+\'|[^\s;&|<>()]+)(?:\s+(?:"[^"]+"|\'[^\']+\'|[^\s;&|<>()]+))*)')
CPMV = re.compile(r'\b(?:cp|mv|install|ln)\b((?:\s+(?:"[^"]+"|\'[^\']+\'|[^\s;&|<>()]+))+)')
ZINCIR = re.compile(r'\s*(?:&&|\|\||;|\||\n)\s*')


def tirnak_sil(s):
    if len(s) >= 2 and s[0] == s[-1] and s[0] in '"\'':
        return s[1:-1]
    return s


def bash_hedefleri(komut, yalniz_yonlendirme=False):
    """Bash parçasındaki yazma HEDEFLERİ (best-effort: yönlendirme, tee, sed -i, cp/mv/install/ln son argüman)."""
    hed = []
    for m in YONLENDIR.finditer(komut):
        hed.append(tirnak_sil(m.group(1)))
    if yalniz_yonlendirme:
        return hed
    for m in TEE.finditer(komut):
        hed += [tirnak_sil(x) for x in re.findall(r'"[^"]+"|\'[^\']+\'|[^\s;&|<>()]+', m.group(2))]
    for m in SEDI.finditer(komut):
        hed += [tirnak_sil(x) for x in re.findall(r'"[^"]+"|\'[^\']+\'|[^\s;&|<>()]+', m.group(1))]
    for m in CPMV.finditer(komut):
        argv = [tirnak_sil(x) for x in re.findall(r'"[^"]+"|\'[^\']+\'|[^\s;&|<>()]+', m.group(1))]
        argv = [a for a in argv if not a.startswith('-')]
        if len(argv) >= 2:
            hed.append(argv[-1])
    return hed


def bash_cekirdek_mi(parca, cekirdek, cwd, depo):
    """Parça gerçekten çekirdeğin komutu mu? Tanımdaki dosya-yolu tokenları depo köküne göre çözülür; komuttaki karşılığı
    cwd'ye göre çözülüp realpath ile EŞİT olmalı (oda içinde aynı adlı sahte betik çekirdek sayılmaz)."""
    try:
        tok = shlex.split(parca)
    except ValueError:
        return False
    for c in cekirdek:
        try:
            ct = shlex.split(c)
        except ValueError:
            continue
        if not ct or len(tok) < len(ct):
            continue
        eslesti = True
        for t, k in zip(tok, ct):
            kdosya = os.path.join(depo, k)
            if os.path.isfile(kdosya):
                if cozumle(t, cwd) != os.path.realpath(kdosya):
                    eslesti = False
                    break
            elif t != k:
                eslesti = False
                break
        if eslesti:
            return True
    return False


def karar(arac, girdi, cwd, oda_dir, depo, ortak, oda_meta):
    """(izin_mi, neden)"""
    hedefler = []
    kabuk = arac == 'Bash'   # kabuk hedeflerinde $DEĞİŞKEN/$(…) çözülemez; dosya aracı yollarında '$' düz karakterdir
    if arac in ('Write', 'Edit', 'MultiEdit'):
        hedefler = [girdi.get('file_path', '')]
    elif arac == 'NotebookEdit':
        hedefler = [girdi.get('notebook_path', '')]
    elif arac == 'Bash':
        komut = girdi.get('command', '') or ''
        for parca in ZINCIR.split(komut):
            if not parca.strip():
                continue
            # yönlendirme hedefleri HER parçada taranır; tee/sed -i/cp/mv hedefleri yalnız çekirdeğin gerçek komutu OLMAYAN parçada
            hedefler += bash_hedefleri(parca, yalniz_yonlendirme=bash_cekirdek_mi(parca, ortak.get('cekirdek_komutlar', []), cwd, depo))
    else:
        return True, ''
    ortak_veri = ortak.get('ortak_veri', [])
    ek = oda_meta.get('ek_yazma', [])
    for h in hedefler:
        if not h or (kabuk and (h.startswith('/dev/') or h.startswith('&') or '$' in h or '`' in h)):
            continue   # belirsiz/değişkenli hedef: best-effort kapsam dışı (belgelenmiş sınır)
        yol = cozumle(h, cwd)
        if not icinde(yol, depo):
            continue
        rel = os.path.relpath(yol, os.path.realpath(depo))
        if glob_uyar(rel, ortak_veri):
            return False, f'{rel}: ortak veri — okuma serbest, yazma yalnız çekirdeğin komutundan: bash {CEKIRDEK_KOMUT} <depo> {rel} --neden "<tek cümle>" [--siparis gorev_<kimlik>] < yeni-icerik{" (ek komutlar: " + ", ".join(ortak.get("cekirdek_komutlar", [])) + ")" if ortak.get("cekirdek_komutlar") else ""}'
        if icinde(yol, oda_dir):
            continue
        if glob_uyar(rel, ek):
            continue
        return False, f'{rel}: bu odanın ({os.path.basename(oda_dir)}/) dışında — kod değişikliği oda klasörüne sınırlı; başka odaya sipariş görevi aç'
    return True, ''


def kanca(oda_dir, ortak_yol):
    ham = sys.stdin.read()
    try:
        girdi = json.loads(ham)
        arac = girdi.get('tool_name', '')
        ti = girdi.get('tool_input', {}) or {}
        cwd = girdi.get('cwd') or os.getcwd()
    except Exception as e:
        print(f'oda-kanca: kanca girdisi okunamadı ({e}) — güvenli tarafta durduruldu', file=sys.stderr)
        return 2
    if arac not in ('Write', 'Edit', 'MultiEdit', 'NotebookEdit', 'Bash'):
        return 0
    try:
        ortak = ortak_oku(os.path.dirname(os.path.dirname(os.path.abspath(ortak_yol))))
        meta = oku_json(os.path.join(oda_dir, 'oda.json'))
    except Exception as e:
        print(f'oda-kanca: ortak ayar/oda.json okunamadı ({e}) — güvenli tarafta durduruldu (oda.sh dogrula)', file=sys.stderr)
        return 2
    depo = os.path.dirname(os.path.dirname(os.path.abspath(ortak_yol)))
    izin, neden = karar(arac, ti, cwd, os.path.realpath(oda_dir), depo, ortak, meta)
    if izin:
        return 0
    print(f'oda-kanca: durduruldu — {neden}', file=sys.stderr)
    return 2


CEKIRDEK_KOMUT = '/config/.claude/skills/oda-kur/scripts/oda.sh cekirdek-yaz'
CEKIRDEK_KAYIT = os.path.join('.claude', 'cekirdek-kayit.jsonl')
SIPARIS_BICIM = re.compile(r'^gorev_[0-9A-Za-z]{10,40}$')


def sha_dosya(yol):
    """Dosya yoksa None; varsa sha256 (önceki sha: yeni dosyada boş kalır, uydurulmaz)."""
    try:
        with open(yol, 'rb') as f:
            return hashlib.sha256(f.read()).hexdigest()
    except FileNotFoundError:
        return None


def defter_kimligi():
    """Kim yazıyor? Ajanın beyanından DEĞİL: DEFTER_JETON_YOL dosyasındaki jetonla defterden (/ben) sorulur.
    Fail-closed: yol değişkeni yok / dosya okunamaz / defter yanıt vermez / ajan kimliği boş → ret. Varsayılan jeton YOK
    (27 Eki: ortak varsayılan jetona düşen koltuklar reis kimliğiyle yazabiliyordu). Jeton değeri hiçbir yere yazılmaz."""
    jy = os.environ.get('DEFTER_JETON_YOL', '')
    if not jy:
        raise PermissionError('DEFTER_JETON_YOL yok: bu süreç defter kimliği taşımıyor — çekirdeğe yazılmaz')
    try:
        with open(jy, encoding=UTD) as f:
            jeton = f.read().strip()
    except OSError:
        raise PermissionError('DEFTER_JETON_YOL okunamadı — çekirdeğe yazılmaz')
    if not jeton:
        raise PermissionError('jeton dosyası boş — çekirdeğe yazılmaz')
    uc = os.environ.get('DEFTER_UC', 'http://cloudtop-defter:8791').rstrip('/')
    try:
        r = urllib.request.Request(uc + '/ben', headers={'x-defter-jeton': jeton})
        with urllib.request.urlopen(r, timeout=10) as y:
            d = json.loads(y.read().decode(UTD))
    except urllib.error.HTTPError as e:
        raise PermissionError(f'defter kimliği doğrulamadı (http {e.code}) — çekirdeğe yazılmaz')
    except Exception:
        raise PermissionError('defter kimliği sorulamadı (ulaşılamıyor/bozuk yanıt) — çekirdeğe yazılmaz')
    ajan = d.get('ajan') if isinstance(d, dict) else None
    kutu = d.get('kutu') if isinstance(d, dict) else None
    if not (isinstance(ajan, str) and ajan.strip() and isinstance(kutu, str) and kutu.strip()):
        raise PermissionError('jetonun ajan kimliği yok (kutu jetonu ayrı koltuğu ayırt etmez) — çekirdeğe yazılmaz')
    return ajan.strip(), kutu.strip()


def git_kok(dizin):
    try:
        c = subprocess.run(['git', '-C', dizin, 'rev-parse', '--show-toplevel'], capture_output=True, text=True, timeout=10)
    except Exception:
        return None
    return os.path.realpath(c.stdout.strip()) if c.returncode == 0 and c.stdout.strip() else None


def cekirdek_yaz(depo, yol, neden, siparis, dosya):
    depo_r = os.path.realpath(depo)
    # Ö7: yazım yalnız KUTU deposundan. Kutu deposu = oda-ortak.json'u taşıyan git kökü; ayrı depodaki oda (cwd başka depoda) yazamaz.
    try:
        ortak = ortak_oku(depo_r)
    except Exception as e:
        raise PermissionError(f'{depo}: kutu deposu değil ya da ortak ayar okunamadı ({e})')
    if git_kok(depo_r) != depo_r:
        raise PermissionError(f'{depo}: git kökü değil — kutu deposunun kökü verilmeli')
    cwd_kok = git_kok(os.getcwd())
    if cwd_kok != depo_r:
        raise PermissionError(f'bu süreç kutu deposunda değil (cwd git kökü {cwd_kok or "yok"}, kutu deposu {depo_r}): ayrı depodaki oda çekirdeğe kendi deposundan yazamaz')
    if not neden or len(neden.strip()) < 10:
        raise ValueError('--neden ister (tek cümle, en az 10 karakter)')
    if siparis and not SIPARIS_BICIM.match(siparis):
        raise ValueError('--siparis gorev_<kimlik> biçiminde olmalı')
    hedef = cozumle(yol, depo_r)
    if not icinde(hedef, depo_r):
        raise PermissionError(f'{yol}: kutu deposunun dışında')
    rel = os.path.relpath(hedef, depo_r)
    if not glob_uyar(rel, ortak.get('ortak_veri', [])):
        raise PermissionError(f'{rel}: çekirdek ortak veri değil (ortak_veri globlarına uymuyor) — bu komut yalnız çekirdek dosyalar içindir')
    ajan, kutu = defter_kimligi()
    if dosya:
        with open(dosya, 'rb') as f:
            icerik = f.read()
    else:
        icerik = sys.stdin.buffer.read()
    kyol = os.path.join(depo_r, CEKIRDEK_KAYIT)
    os.makedirs(os.path.dirname(kyol), exist_ok=True)
    os.makedirs(os.path.dirname(hedef), exist_ok=True)
    # Yazım + kayıt TEK işlem (göz tur 1): kilit altında; kayıt dosyası ÖNCE açılır (açılamıyorsa dosyaya dokunulmaz);
    # kayıt satırı yazılamazsa dosya eski içeriğine döndürülür. Kilit aynı çekirdeğe eşzamanlı yazanları sıraya koyar → sha zinciri gerçek sırayı gösterir.
    with open(kyol + '.kilit', 'a') as kilit:
        fcntl.flock(kilit, fcntl.LOCK_EX)
        kf = open(kyol, 'a', encoding=UTD)
        try:
            onceki = sha_dosya(hedef)
            eski = None
            if os.environ.get('ODA_CEKIRDEK_BEKLE_MS'):   # YALNIZ sınav kancası: kritik bölgeyi uzatır, kilit yoksa çakışma kesinleşir
                time.sleep(int(os.environ['ODA_CEKIRDEK_BEKLE_MS']) / 1000)
            if onceki is not None:
                with open(hedef, 'rb') as f:
                    eski = f.read()
            eski_kip = os.stat(hedef).st_mode & 0o7777 if onceki is not None else None
            fd, gecici = tempfile.mkstemp(dir=os.path.dirname(hedef), prefix='.cekirdek-yaz-')
            geri = None
            try:
                with os.fdopen(fd, 'wb') as f:
                    f.write(icerik)
                if eski_kip is not None:
                    os.chmod(gecici, eski_kip)
                    # Geri alma malzemesi DEĞİŞİKLİKTEN ÖNCE hazır olur (göz tur 2): eski dosya sert bağla saklanır — veri yazmaz,
                    # disk/kota dolu olsa da geri dönüş yeniden adlandırmadır. Sert bağ yoksa kopya yine değişiklikten ÖNCE yazılır (hata → dosya değişmeden ret).
                    geri = os.path.join(os.path.dirname(hedef), '.cekirdek-geri-%d' % os.getpid())
                    try:
                        os.link(hedef, geri)
                    except OSError:
                        with open(geri, 'wb') as f:
                            f.write(eski)
                        os.chmod(geri, eski_kip)
                os.replace(gecici, hedef)
            except BaseException:
                for k in (gecici, geri):
                    if k and os.path.exists(k):
                        os.unlink(k)
                raise
            sonraki = sha_dosya(hedef)
            kayit = {
                'zaman': datetime.now(timezone.utc).astimezone().isoformat(timespec='seconds'),
                'kim': ajan, 'kutu': kutu, 'dosya': rel,
                'onceki_sha': onceki, 'sonraki_sha': sonraki, 'neden': neden.strip(),
                'siparis': siparis or None, 'siparissiz': not siparis,
            }
            try:
                kf.write(json.dumps(kayit, ensure_ascii=False, sort_keys=True) + '\n')
                kf.flush()
                os.fsync(kf.fileno())
            except BaseException:
                if eski is None:
                    if os.path.exists(hedef):
                        os.unlink(hedef)
                else:
                    os.replace(geri, hedef)
                raise
            if geri and os.path.exists(geri):
                os.unlink(geri)
        finally:
            kf.close()
    print(f'✓ çekirdek yazıldı: {rel} · kim {ajan} · {(onceki or "yeni")[:12]} → {sonraki[:12]}' + ('' if siparis else ' · SİPARİŞSİZ (çekirdek reisinin nabzında ayrı satır)'))
    return 0


def main(a):
    a = a[0:1] + a[2:]   # a[1] = sarmalayıcı adı
    if len(a) < 2:
        print(__doc__)
        return 2
    c = a[1]
    if c == 'kanca':
        if len(a) != 4:
            hata('kullanım: oda.sh kanca <oda_dizini> <ortak_json>', 2)
        return kanca(a[2], a[3])
    if c == 'cekirdek-yaz':
        r = a[2:]
        if len(r) < 2:
            hata('kullanım: oda.sh cekirdek-yaz <depo> <yol> --neden "<tek cümle>" [--siparis gorev_<kimlik>] [--dosya <kaynak>]  (içerik --dosya ya da stdin)', 2)
        depo, yol, r = r[0], r[1], r[2:]
        kw = {'--neden': '', '--siparis': '', '--dosya': ''}
        while r:
            if r[0] not in kw or len(r) < 2:
                hata(f'bilinmeyen bayrak: {r[0]}', 2)
            kw[r[0]] = r[1]
            r = r[2:]
        try:
            return cekirdek_yaz(depo, yol, kw['--neden'], kw['--siparis'], kw['--dosya'])
        except PermissionError as e:
            hata(f'✗ RET (yazım yok): {e}', 1)
        except (ValueError, OSError) as e:
            hata(f'✗ RET (yazım yok): {e}', 2)
    if c == 'uret':
        if len(a) != 3:
            hata('kullanım: oda.sh uret <depo>', 2)
        try:
            for oda, d in uret(a[2]):
                print(f'  {oda}: {d}')
        except Exception as e:
            hata(f'üretilemedi: {e}', 1)
        return 0
    if c == 'yol':
        if len(a) != 4:
            hata('kullanım: oda.sh yol <depo> <oda>', 2)
        k = os.path.join(os.path.abspath(a[2]), a[3])
        if not (ODA_AD.match(a[3]) and os.path.isfile(os.path.join(k, 'oda.json'))):
            hata(f'oda yok: {a[3]}', 1)
        print(k)
        return 0
    if c == 'dogrula':
        if len(a) != 3:
            hata('kullanım: oda.sh dogrula <depo>', 2)
        return dogrula(a[2])
    if c == 'yeni':
        if len(a) < 4:
            hata('kullanım: oda.sh yeni <depo> <oda> --reis K --hedef "…" --olcu "…"', 2)
        kw = {'--reis': '', '--hedef': '', '--olcu': ''}
        r = a[4:]
        while r:
            if r[0] not in kw or len(r) < 2:
                hata(f'bilinmeyen bayrak: {r[0]}', 2)
            kw[r[0]] = r[1]
            r = r[2:]
        yeni(a[2], a[3], kw['--reis'], kw['--hedef'], kw['--olcu'])
        return 0
    hata(f'bilinmeyen komut: {c}', 2)


if __name__ == '__main__':
    sys.exit(main(sys.argv))
