#!/usr/bin/env bash
# durum-raporu.sh — Sultan standardında personel durum raporu (bkz. ../SEMA.md §3).
# Kaynak: <repo>/_agents/durum/<AD>.json (üye kendi yazar). Dosya yoksa registry + git + sinyal defterinden TÜRETİR ve damgalar.
# Kullanım: durum-raporu.sh [--repo <yol>] [--porcelain]
set -uo pipefail
export TZ=Europe/Istanbul
. "$(dirname "$0")/repo-bul.sh"
REPO="$(repo_bul)"; PORC=0
while [ $# -gt 0 ]; do case "$1" in --repo) REPO="$2"; shift 2;; --porcelain) PORC=1; shift;; *) shift;; esac; done
REG="$REPO/_agents/handoff/ekip-registry.yaml"; DUR="$REPO/_agents/durum"; SIG="$REPO/_agents/handoff/ekip-sinyal.log"
KUTU="$(basename "$REPO" | sed 's/^cloudtop-//')"
LINKCOZ="$(dirname "$0")/link-coz.sh"
coz(){ [ -x "$LINKCOZ" ] && bash "$LINKCOZ" "$1" 2>/dev/null || printf '%s' "$1"; }
[ -f "$REG" ] || { echo "kayıt yok: $REG" >&2; exit 2; }
python3 - "$REG" "$DUR" "$SIG" "$KUTU" "$REPO" "$PORC" "$LINKCOZ" <<'PY'
import sys, json, os, re, subprocess, datetime
reg, dur, sig, kutu, repo, porc, linkcoz = sys.argv[1:8]
def coz(l):
    if not l: return '—'
    if os.path.exists(linkcoz):
        try: return subprocess.run(['bash', linkcoz, l], capture_output=True, text=True, timeout=5).stdout.strip() or l
        except Exception: return l
    return l
# registry: sıra + rol + cwd + tmux (yaml'ı hafif ayrıştır)
uyeler=[]; cur=None
for satir in open(reg, encoding='utf-8'):
    m=re.match(r'\s*-\s*id:\s*(\S+)', satir)
    if m: cur={'ad':m.group(1),'rol':'','cwd':'','tmux':'','durum':''}; uyeler.append(cur); continue
    if cur is None: continue
    for k in ('rol','cwd','tmux','durum','worktree_branch'):
        m=re.match(r'\s*'+k+r':\s*"?([^"#]*?)"?\s*(#.*)?$', satir)
        if m: cur[k]=m.group(1).strip()
uyeler=[u for u in uyeler if u.get('durum')!='pasif']
def cwd_bul(u):
    # kayıtta cwd yoksa: iskan-registry.yaml → _wt/<kutu>-<ad küçük> → repo kökü (uydurma yok, yalnız var olan dizin)
    c=u.get('cwd')
    if c and os.path.isdir(c): return c
    isk=os.path.join(repo,'iskan-registry.yaml')
    if os.path.exists(isk):
        cur=None
        for l in open(isk,encoding='utf-8'):
            m=re.match(r'\s*-\s*id:\s*(\S+)', l)
            if m: cur=m.group(1); continue
            m=re.match(r'\s*cwd:\s*"?([^"#]*?)"?\s*(#.*)?$', l)
            if m and cur==u['ad'] and os.path.isdir(m.group(1).strip()): return m.group(1).strip()
    import glob
    for c in sorted(glob.glob(f'/config/projects/_wt/{kutu}-{u["ad"].lower()}*')):
        if os.path.isdir(c): return c
    return None
def git_son(cwd):
    if not cwd or not os.path.isdir(cwd): return None
    try:
        o=subprocess.run(['git','-C',cwd,'log','-1','--format=%h|%cI|%s'],capture_output=True,text=True,timeout=5).stdout.strip()
        if not o: return None
        h,t,s=o.split('|',2); return {'is':s[:90],'zaman':t,'kayit':h,'link':f'mmepanel://{kutu}/kayit/{h}'}
    except Exception: return None
def sinyal_son(ad):
    if not os.path.exists(sig): return None
    son=None
    for l in open(sig,encoding='utf-8',errors='ignore'):
        p=l.rstrip('\n').split('|')
        if len(p)>=7 and p[3]==ad and p[2] in ('done','waiting','ping'): son=p
    if not son: return None
    return {'tur':son[2],'zaman':son[1],'metin':re.sub(r'^draft-guard:\s*','',son[6])[:120],'link':f'mmepanel://{kutu}/sinyal/{son[0]}'}
simdi=datetime.datetime.now().astimezone().strftime('%Y-%m-%d %H:%M')
def sa(t):
    if not t: return '—'
    try: return datetime.datetime.fromisoformat(t).astimezone().strftime('%d.%m %H:%M')
    except Exception: return t
cikti=[]
if porc!='1': cikti.append(f'DURUM RAPORU · {kutu} · {simdi}')
for i,u in enumerate(uyeler,1):
    ad=u['ad']; f=os.path.join(dur,ad+'.json'); d=None
    if os.path.exists(f):
        try: d=json.load(open(f,encoding='utf-8'))
        except Exception as e: d={'hata':str(e)}
    if d and 'hata' not in d:
        gad=d.get('gorunen_ad',ad); rol=d.get('rol',u['rol']); b=(d.get('bitirdi') or [None])[0]; s=d.get('simdi'); k=d.get('kuyruk') or []; w=d.get('bekliyor') or []; c=d.get('canli') or {}
        kaynak=''
    else:
        gad=ad; rol=u['rol']; b=git_son(cwd_bul(u)); sn=sinyal_son(ad)
        s={'is':(sn['metin'] if sn and sn['tur']!='done' else None),'baslangic':(sn['zaman'] if sn else None),'link':(sn['link'] if sn else None)} if sn else None
        k=[]; w=([{'kimden':'?','ne':sn['metin'],'beri':sn['zaman'],'link':sn['link']}] if sn and sn['tur']=='waiting' else []); c={'pencere':u['tmux'],'link':f'mmepanel://{kutu}/pencere/{ad}'}
        kaynak=' (türetildi — durum dosyası yok)'
    if porc=='1':
        cikti.append('\t'.join([ad, (b or {}).get('is','') or '', (s or {}).get('is','') or '', str(len(k)), str(len(w)), c.get('link','') or '']) ); continue
    cikti.append(f'{i}. {gad} ({rol or "—"}){kaynak}')
    cikti.append(f'   Bitirdi: ' + (f"{b['is']} · {sa(b.get('zaman'))} · {coz(b.get('link'))}" if b else '—'))
    cikti.append(f'   Geçti:   ' + (f"{s.get('is') or '—'} · {sa(s.get('baslangic'))} · {coz(s.get('link'))}" if s else '—'))
    cikti.append('   Önünde:  ' + ('   '.join(f"{j}) {x.get('is')} · {x.get('hedef','—')} · {coz(x.get('link'))}" for j,x in enumerate(k,1)) if k else '—'))
    cikti.append('   Bekliyor: ' + ('   '.join(f"{x.get('kimden','?')} · {x.get('ne')} · {sa(x.get('beri'))} · {coz(x.get('link'))}" for x in w) if w else '—'))
    cikti.append(f'   Canlı:   {coz(c.get("link"))}')
print('\n'.join(cikti))
PY
