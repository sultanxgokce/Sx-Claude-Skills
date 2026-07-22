#!/usr/bin/env bash
# layiha-defteri.sh — layiha kayıt-defteri (ekle · durum · liste + zaman-filtresi)
#
# NE: Her layiha (araştır→sabitle→sonraya-bırak) bu deftere BİR satır düşer. "aktif tümünü
#     listele / bugünü / bu haftayı / bu hafta bitmemişleri" filtreleriyle önizleme verir;
#     her satır yapıldı/yapılmadı durumu taşır.
#
# DEFTER KONUMU (per-container — İ1 yalnız-yerel; container'lar birbirinin layihasını GÖRMEZ):
#   1) $LAYIHA_DEFTER (env override)  2) <repo-kökü>/_agents/handoff/layiha-defteri.jsonl (varsa)
#   3) $HOME/.claude/layiha-defteri.jsonl (fallback — repo-dışı/izole)
#
# Kullanım:
#   layiha-defteri.sh ekle --slug S --konu "..." --dokuman "yol" [--pr "#N"] [--resume "cümle"] [--tarih YYYY-MM-DD]
#   layiha-defteri.sh durum <slug> <insa-bekliyor|insa-ediliyor|insa-edildi>
#   layiha-defteri.sh liste [--aktif(default) | --bugun | --hafta | --hafta-bitmemis | --hepsi] [--porcelain]
# Çıkış: 0 OK · 2 girdi/ortam hatası
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then echo "HATA: python3 yok." >&2; exit 2; fi

_ledger() {
  if [ -n "${LAYIHA_DEFTER:-}" ]; then printf '%s' "$LAYIHA_DEFTER"; return; fi
  local root
  if root=$(git rev-parse --show-toplevel 2>/dev/null) && [ -d "$root/_agents/handoff" ]; then
    printf '%s' "$root/_agents/handoff/layiha-defteri.jsonl"
  else
    printf '%s' "$HOME/.claude/layiha-defteri.jsonl"
  fi
}
LEDGER="$(_ledger)"
CMD="${1:-liste}"; shift || true

export LAYIHA_LEDGER="$LEDGER"
export LAYIHA_ARGS_JSON=""

# argümanları JSON'a topla (python'a güvenli aktar)
python_args() {
  python3 - "$@" <<'PY'
import sys, json
d={}; a=sys.argv[1:]; i=0
while i < len(a):
    k=a[i]
    if k.startswith("--"):
        key=k[2:]
        if i+1 < len(a) and not a[i+1].startswith("--"):
            d[key]=a[i+1]; i+=2
        else:
            d[key]=True; i+=1
    else:
        i+=1
print(json.dumps(d))
PY
}

case "$CMD" in
  ekle)
    ARGS="$(python_args "$@")"
    LAYIHA_ARGS_JSON="$ARGS" python3 - <<'PY'
import os, json, io, sys
led=os.environ["LAYIHA_LEDGER"]; a=json.loads(os.environ["LAYIHA_ARGS_JSON"])
for req in ("slug","konu","dokuman"):
    if not a.get(req): sys.stderr.write("HATA: --%s zorunlu\n"%req); sys.exit(2)
import subprocess
tarih=a.get("tarih") or subprocess.check_output(["date","+%F"]).decode().strip()
rec={"slug":a["slug"],"konu":a["konu"],"tarih":tarih,"durum":a.get("durum","insa-bekliyor"),
     "dokuman":a["dokuman"],"pr":a.get("pr",""),"resume":a.get("resume",""),"not":a.get("not","")}
os.makedirs(os.path.dirname(led), exist_ok=True)
# aynı slug varsa güncelle (idempotent), yoksa ekle
lines=[]
if os.path.exists(led):
    with io.open(led,encoding="utf-8") as f: lines=[l for l in f if l.strip()]
out=[]; found=False
for l in lines:
    try: r=json.loads(l)
    except: out.append(l); continue
    if r.get("slug")==rec["slug"]: out.append(json.dumps(rec,ensure_ascii=False)+"\n"); found=True
    else: out.append(l if l.endswith("\n") else l+"\n")
if not found: out.append(json.dumps(rec,ensure_ascii=False)+"\n")
with io.open(led,"w",encoding="utf-8") as f: f.writelines(out)
print("OK: layiha kaydı %s (%s)"%("güncellendi" if found else "eklendi", rec["slug"]))
PY
  ;;
  durum)
    SLUG="${1:-}"; YENI="${2:-}"
    [ -n "$SLUG" ] && [ -n "$YENI" ] || { echo "HATA: durum <slug> <insa-bekliyor|insa-ediliyor|insa-edildi>" >&2; exit 2; }
    case "$YENI" in insa-bekliyor|insa-ediliyor|insa-edildi) ;; *) echo "HATA: geçersiz durum: $YENI" >&2; exit 2;; esac
    SLUG="$SLUG" YENI="$YENI" python3 - <<'PY'
import os, json, io, sys
led=os.environ["LAYIHA_LEDGER"]; slug=os.environ["SLUG"]; yeni=os.environ["YENI"]
if not os.path.exists(led): sys.stderr.write("HATA: defter yok: %s\n"%led); sys.exit(2)
out=[]; found=False
with io.open(led,encoding="utf-8") as f:
    for l in f:
        if not l.strip(): continue
        r=json.loads(l)
        if r.get("slug")==slug: r["durum"]=yeni; found=True
        out.append(json.dumps(r,ensure_ascii=False)+"\n")
if not found: sys.stderr.write("HATA: slug bulunamadı: %s\n"%slug); sys.exit(2)
with io.open(led,"w",encoding="utf-8") as f: f.writelines(out)
print("OK: %s → %s"%(slug,yeni))
PY
  ;;
  liste)
    FILT="aktif"; PORC=0
    for arg in "$@"; do case "$arg" in
      --aktif) FILT="aktif";; --bugun) FILT="bugun";; --hafta) FILT="hafta";;
      --hafta-bitmemis) FILT="hafta-bitmemis";; --hepsi) FILT="hepsi";;
      --porcelain) PORC=1;; esac; done
    TODAY="$(date +%F)"; WEEK="$(date +%G-W%V)"
    LAYIHA_FILT="$FILT" LAYIHA_PORC="$PORC" LAYIHA_TODAY="$TODAY" LAYIHA_WEEK="$WEEK" python3 - <<'PY'
import os, json, io, datetime
led=os.environ["LAYIHA_LEDGER"]; filt=os.environ["LAYIHA_FILT"]; porc=os.environ["LAYIHA_PORC"]=="1"
today=os.environ["LAYIHA_TODAY"]; week=os.environ["LAYIHA_WEEK"]
recs=[]
if os.path.exists(led):
    with io.open(led,encoding="utf-8") as f:
        for l in f:
            if l.strip():
                try: recs.append(json.loads(l))
                except: pass
def isoweek(d):
    try:
        y,m,dd=map(int,d.split("-")); iso=datetime.date(y,m,dd).isocalendar()
        return "%d-W%02d"%(iso[0],iso[1])
    except: return ""
def keep(r):
    d=r.get("tarih",""); done=r.get("durum")=="insa-edildi"
    if filt=="hepsi": return True
    if filt=="aktif": return not done
    if filt=="bugun": return d==today
    if filt=="hafta": return isoweek(d)==week
    if filt=="hafta-bitmemis": return isoweek(d)==week and not done
    return True
sel=[r for r in recs if keep(r)]
# sırala: bekleyen önce, sonra tarih tersten
sel.sort(key=lambda r:(r.get("durum")=="insa-edildi", r.get("tarih","")), reverse=False)
DUR={"insa-bekliyor":"⏳ inşa bekliyor","insa-ediliyor":"🔨 inşa ediliyor","insa-edildi":"✅ yapıldı"}
if porc:
    for r in sel:
        print("\t".join([r.get("slug",""),r.get("durum",""),r.get("tarih",""),r.get("konu",""),r.get("resume",""),r.get("dokuman","")]))
    print("#OZET\ttoplam=%d\tfiltre=%s"%(len(sel),filt))
else:
    baslik={"aktif":"aktif (inşa bekleyen) layihalar","bugun":"bugünkü layihalar","hafta":"bu haftaki layihalar","hafta-bitmemis":"bu hafta bitmemiş layihalar","hepsi":"TÜM layihalar"}[filt]
    print("🗂️ LAYİHA DEFTERİ · %s · %d kayıt"%(baslik,len(sel)))
    print("")
    if not sel: print("  (kayıt yok)")
    for r in sel:
        print("  %s  · %s  (%s)"%(DUR.get(r.get("durum"),r.get("durum","")), r.get("konu",""), r.get("tarih","")))
        if r.get("resume"): print("       ↳ devam için: \"%s\" de"%r["resume"])
PY
  ;;
  *) echo "HATA: bilinmeyen komut: $CMD (ekle|durum|liste)" >&2; exit 2;;
esac
