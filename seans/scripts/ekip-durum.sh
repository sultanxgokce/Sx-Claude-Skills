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
try:
    import yaml
except Exception:
    print("YAML-YOK"); sys.exit(2)
canli=[s for s in (os.environ.get("CANLI_LISTE","") or "").splitlines() if s]
d=yaml.safe_load(open(sys.argv[1])) or {}
uyeler=d.get("uyeler") or d.get("members") or []
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
