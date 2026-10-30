#!/usr/bin/env bash
# durum-yaz.sh — üye KENDİ durum dosyasını günceller (_agents/durum/<AD>.json, SEMA.md §1).
# Kullanım: durum-yaz.sh --ad AD [--kaynak sultan|eksik|oneri] [--rol "…"] [--bitti "iş" --kayit sha] [--simdi "iş" --link L] [--kuyruk "iş|hedef|link" ...] [--bekliyor "kimden|ne|link" ...] [--temizle-kuyruk]
set -uo pipefail
export TZ=Europe/Istanbul
. "$(dirname "$0")/repo-bul.sh"
REPO="$(repo_bul)"; KUTU="$(basename "$REPO" | sed 's/^cloudtop-//')"
python3 - "$REPO" "$KUTU" "$@" <<'PY'
import sys, json, os, datetime
repo, kutu, *args = sys.argv[1:]
o={}; i=0; kuy=[]; bek=[]; temizle=False
while i < len(args):
    a=args[i]; v=args[i+1] if i+1 < len(args) else ''
    if a=='--ad': o['ad']=v; i+=2
    elif a=='--rol': o['rol']=v; i+=2
    elif a=='--bitti': o['bitti']=v; i+=2
    elif a=='--kayit': o['kayit']=v; i+=2
    elif a=='--simdi': o['simdi']=v; i+=2
    elif a=='--link': o['link']=v; i+=2
    elif a=='--kuyruk': kuy.append(v); i+=2
    elif a=='--bekliyor': bek.append(v); i+=2
    elif a=='--kaynak': o['kaynak']=v; i+=2
    elif a=='--temizle-kuyruk': temizle=True; i+=1
    else: i+=1
ad=o.get('ad')
if not ad: print('--ad zorunlu', file=sys.stderr); sys.exit(2)
d_dir=os.path.join(repo,'_agents','durum'); os.makedirs(d_dir, exist_ok=True); f=os.path.join(d_dir, ad+'.json')
d=json.load(open(f,encoding='utf-8')) if os.path.exists(f) else {'surum':1,'ad':ad,'gorunen_ad':ad,'rol':'','kutu':kutu,'bitirdi':[],'simdi':None,'kuyruk':[],'bekliyor':[],'canli':{'pencere':ad+':0','link':f'mmepanel://{kutu}/pencere/{ad}'}}
now=datetime.datetime.now().astimezone().isoformat(timespec='seconds')
if 'rol' in o: d['rol']=o['rol']
# Sultan 16-09: iş satırı Sultan'ın diliyle başlar — kaynağı söyler (sizin isteğiniz / gördüğüm eksik / kendi önerim), sonra ne yapıldı, neye yarar.
KAYNAK={'sultan':'Sizin isteğiniz: ','eksik':'Gördüğüm eksik: ','oneri':'Kendi önerim: '}
if o.get('kaynak') and o['kaynak'] not in KAYNAK:
    print('UYARI: --kaynak degeri taninmadi: '+o['kaynak']+' (sultan|eksik|oneri) — onek eklenmedi', file=sys.stderr)
onek=KAYNAK.get(o.get('kaynak',''),'')
if not onek and any(k in o for k in ('bitti','simdi')) or (not onek and kuy):
    print('UYARI: --kaynak verilmedi; is satiri oneksiz yaziliyor (sultan-dili.md §3/§5 uyari verir)', file=sys.stderr)
def cumle(m):
    return m if (not onek or any(m.startswith(x) for x in KAYNAK.values())) else onek+m
def ozu(m):   # kaynak önekini soyar: "biten iş = şimdiki iş" kıyası önekten bağımsızdır
    m = m or ''
    for x in KAYNAK.values():
        if m.startswith(x): return m[len(x):]
    return m
if 'bitti' in o:
    o['bitti']=cumle(o['bitti'])
    d['bitirdi']=[{'is':o['bitti'],'zaman':now,'kayit':o.get('kayit'),'kaynak':o.get('kaynak'),'link':(f"mmepanel://{kutu}/kayit/{o['kayit']}" if o.get('kayit') else None)}]+d.get('bitirdi',[])[:29]   # geçmiş: son 30 iş (ayrıntı sayfası)
    # Göz tur 1 (Sx #594): --simdi ve --bitti ayrı çağrılarda farklı (ya da eksik) --kaynak alırsa öneki farklı olur;
    # birebir kıyas biten işi 'şimdi' satırında asılı bırakıyordu. Kıyas önek soyulmuş metinle yapılır.
    if d.get('simdi') and ozu(d['simdi'].get('is'))==ozu(o['bitti']): d['simdi']=None
if 'simdi' in o: d['simdi']={'is':cumle(o['simdi']),'baslangic':now,'link':o.get('link'),'kaynak':o.get('kaynak')}
if temizle: d['kuyruk']=[]
for k in kuy:
    p=(k.split('|')+['','',''])[:3]; d['kuyruk'].append({'sira':len(d['kuyruk'])+1,'is':cumle(p[0]),'hedef':p[1] or None,'link':p[2] or None})
d['bekliyor']=[]
for b in bek:
    p=(b.split('|')+['','',''])[:3]; d['bekliyor'].append({'kimden':p[0],'ne':p[1],'beri':now,'link':p[2] or None})
d['guncelleme']=now
json.dump(d, open(f,'w',encoding='utf-8'), ensure_ascii=False, indent=2); print('yazıldı:', f)
PY
