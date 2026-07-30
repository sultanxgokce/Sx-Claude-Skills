#!/usr/bin/env bash
# ekip-durum.sh — bu kutudaki ekibin masa durumunu ÖLÇER (onarmaz, yalnız ölçer).
#
# NİÇİN AYRI: `basla` ekranı "3 masa açık · 1'inde Claude yok" diyebilmek için ölçüme
# ihtiyaç duyar. Ölçüm ve ekran ayrı tutuldu ki ekran değişince ölçüm bozulmasın.
#
# ÇIKTI (satır başına bir üye, sekmeyle ayrılmış — makine-okur):
#   <id> \t <tmux-hedef> \t <durum> \t <not>
#   durum ∈ ayakta | kapali | duplike
# Ek olarak son satır: ÖZET \t <ayakta> \t <kapali> \t <duplike>
#
# ⚠️ MASA ≠ OTURUM: tmux masası açık olabilir ama içinde Claude çalışmıyor olabilir.
# Bu betik masayı ölçer; "içinde Claude var mı" ayrı bir sorudur (pane-komutuna bakar).
# Sultan'ın "0/0" şikâyetinin kökü tam bu ayrımın gösterilmemesiydi.
set -u

ROSTER="${EKIP_ROSTER:-}"
if [ -z "$ROSTER" ]; then
  for a in "$PWD/_agents/handoff/aile-registry.yaml" \
           "$PWD/_agents/ekip-os/ekip-registry.yaml" \
           "$PWD/_agents/handoff/ekip-registry.yaml"; do
    [ -f "$a" ] && { ROSTER="$a"; break; }
  done
fi
[ -n "$ROSTER" ] && [ -f "$ROSTER" ] || { echo "EKIP-LISTESI-YOK"; exit 3; }
command -v python3 >/dev/null 2>&1 || { echo "PYTHON-YOK"; exit 2; }
command -v tmux    >/dev/null 2>&1 || { echo "TMUX-YOK"; exit 2; }

CANLI="$(tmux ls -F '#{session_name}' 2>/dev/null || true)"

CANLI_LISTE="$CANLI" python3 - "$ROSTER" <<'PY'
import sys,os,re

def _elle_ayristir(yol):
    """PyYAML'sız asgari ekip-listesi okuyucu.

    NİÇİN VAR: PyYAML her kutuda kurulu DEĞİL. Eskiden import düşünce betik
    'YAML-YOK' basıp exit 2 veriyor, `basla` ekranı da bunu 'bu dizinde ekip
    tanımı yok' diye YANLIŞ tercüme ediyordu — ekip listesi dosyası dururken.
    (Sultan tez kutusunda canlı gördü, 2026-07-30.) Ekip listesi sabit ve sığ
    bir şekle sahip; onu okumak için kütüphaneye ihtiyaç yok.

    Kapsam BİLİNÇLİ olarak dar: `uyeler:`/`members:` altındaki liste öğelerinden
    yalnız `id`/`ad` ve `tmux` alanları. Girinti serbest, değer tırnaklı olabilir,
    satır sonu `#` yorumu atılır. Bundan karmaşık bir şey gerekirse PyYAML yolu
    zaten devrededir.
    """
    uyeler=[]; blokta=False; girinti=None; simdiki=None
    for ham in open(yol, encoding="utf-8", errors="replace"):
        satir=ham.rstrip("\n")
        if not satir.strip() or satir.lstrip().startswith("#"): continue
        if re.match(r'^(uyeler|members)\s*:\s*$', satir.strip()):
            blokta=True; girinti=None; continue
        if not blokta: continue
        bosluk=len(satir)-len(satir.lstrip())
        govde=satir.lstrip()
        # blok bitti mi? (girintisiz yeni üst-anahtar)
        if bosluk==0 and not govde.startswith("- "):
            blokta=False
            if simdiki: uyeler.append(simdiki); simdiki=None
            continue
        yeni_uye=govde.startswith("- ")
        if yeni_uye:
            if girinti is None: girinti=bosluk
            elif bosluk<girinti:   # daha sığ liste → başka bir blok
                blokta=False
                if simdiki: uyeler.append(simdiki); simdiki=None
                continue
            elif bosluk>girinti: continue   # iç-içe liste (kanallar vb.) — atla
            if simdiki: uyeler.append(simdiki)
            simdiki={}; govde=govde[2:].lstrip()
        elif girinti is not None and bosluk<=girinti:
            continue   # üye alanı değil
        if simdiki is None: continue
        m=re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$', govde)
        if not m: continue
        anahtar, deger = m.group(1), m.group(2)
        if anahtar not in ("id","ad","tmux"): continue
        deger=re.sub(r'\s+#.*$', '', deger).strip().strip('"').strip("'")
        if deger: simdiki[anahtar]=deger
    if simdiki: uyeler.append(simdiki)
    return uyeler

canli=[s for s in (os.environ.get("CANLI_LISTE","") or "").splitlines() if s]
try:
    import yaml
    d=yaml.safe_load(open(sys.argv[1])) or {}
    uyeler=d.get("uyeler") or d.get("members") or []
except ImportError:
    uyeler=_elle_ayristir(sys.argv[1])
except Exception as e:
    print("OKUNAMADI\t%s" % str(e).replace("\t"," ")[:120]); sys.exit(2)
ayakta=kapali=duplike=0
kucuk={}
for s in canli: kucuk.setdefault(s.lower(),[]).append(s)
for m in uyeler:
    if not isinstance(m,dict): continue
    uid=str(m.get("id") or m.get("ad") or "?")
    hedef=str(m.get("tmux") or "")
    sess=hedef.split(":")[0] if hedef else ""
    if not sess:
        print(f"{uid}\t-\tkapali\tmasa tanımı yok"); kapali+=1; continue
    esler=kucuk.get(sess.lower(),[])
    if len(esler)>1:
        print(f"{uid}\t{sess}\tduplike\t{len(esler)} kopya: {' '.join(esler)}"); duplike+=1
    elif esler:
        # masa var; içinde Claude çalışıyor mu?
        print(f"{uid}\t{sess}\tayakta\t"); ayakta+=1
    else:
        print(f"{uid}\t{sess}\tkapali\t"); kapali+=1
print(f"ÖZET\t{ayakta}\t{kapali}\t{duplike}")
PY
