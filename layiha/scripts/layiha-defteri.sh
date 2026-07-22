#!/usr/bin/env bash
# layiha-defteri.sh — layiha kayıt-defteri (ekle · durum · liste + zaman-filtresi)
#
# NE: Her layiha (araştır→sabitle→sonraya-bırak) bu deftere BİR satır düşer. Her kaydın
#     KODU (L01, L02…) + oluşturulma-tarihi + yapıldı/yapılmadı durumu vardır. "aktif tümünü /
#     bugünü / bu haftayı / bu hafta bitmemişleri listele" filtreleriyle önizleme verir.
#
# DEFTER KONUMU (per-container — İ1 yalnız-yerel; container'lar birbirinin layihasını GÖRMEZ):
#   1) $LAYIHA_DEFTER (env override)  2) <repo-kökü>/_agents/handoff/layiha-defteri.jsonl (varsa)
#   3) $HOME/.claude/layiha-defteri.jsonl (fallback — repo-dışı/izole)
#
# Kullanım:
#   layiha-defteri.sh ekle --slug S --konu "..." --dokuman "yol" [--pr "#N"] [--resume "cümle"] [--tarih YYYY-MM-DD]
#   layiha-defteri.sh durum <kod|slug> <insa-bekliyor|insa-ediliyor|insa-edildi>
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

python_args() {
  python3 - "$@" <<'PY'
import sys, json
d={}; a=sys.argv[1:]; i=0
while i < len(a):
    k=a[i]
    if k.startswith("--"):
        key=k[2:]
        if i+1 < len(a) and not a[i+1].startswith("--"): d[key]=a[i+1]; i+=2
        else: d[key]=True; i+=1
    else: i+=1
print(json.dumps(d))
PY
}

# ortak: id-atama yardımcısı python-içinde tanımlı (max numeric part + 1 → L%02d)

case "$CMD" in
  ekle)
    ARGS="$(python_args "$@")"
    LAYIHA_ARGS_JSON="$ARGS" python3 - <<'PY'
import os, json, io, sys, subprocess
led=os.environ["LAYIHA_LEDGER"]; a=json.loads(os.environ["LAYIHA_ARGS_JSON"])
for req in ("slug","konu","dokuman"):
    if not a.get(req): sys.stderr.write("HATA: --%s zorunlu\n"%req); sys.exit(2)
tarih=a.get("tarih") or subprocess.check_output(["date","+%F"]).decode().strip()
lines=[]
if os.path.exists(led):
    with io.open(led,encoding="utf-8") as f: lines=[l for l in f if l.strip()]
recs=[]
for l in lines:
    try: recs.append(json.loads(l))
    except: pass
def id_num(x):
    try: return int(str(x).lstrip("Ll"))
    except: return 0
def next_id():
    mx=max([id_num(r.get("id","")) for r in recs] + [0])
    return "L%02d"%(mx+1)
# mevcut slug'ın id'sini koru; yoksa yeni id
existing=None
for r in recs:
    if r.get("slug")==a["slug"]: existing=r; break
kod = (existing.get("id") if existing and existing.get("id") else next_id())
rec={"id":kod,"slug":a["slug"],"konu":a["konu"],"tarih":(existing.get("tarih") if existing and not a.get("tarih") else tarih),
     "durum":a.get("durum", existing.get("durum") if existing else "insa-bekliyor"),
     "dokuman":a["dokuman"],"pr":a.get("pr", existing.get("pr","") if existing else ""),
     "resume":a.get("resume", existing.get("resume","") if existing else ""),"not":a.get("not","")}
out=[]; found=False
for r in recs:
    if r.get("slug")==rec["slug"]: out.append(json.dumps(rec,ensure_ascii=False)+"\n"); found=True
    else: out.append(json.dumps(r,ensure_ascii=False)+"\n")
if not found: out.append(json.dumps(rec,ensure_ascii=False)+"\n")
os.makedirs(os.path.dirname(led) or ".", exist_ok=True)
with io.open(led,"w",encoding="utf-8") as f: f.writelines(out)
print("OK: layiha %s %s (%s · %s)"%(rec["id"], "güncellendi" if found else "eklendi", rec["slug"], rec["tarih"]))
PY
  ;;
  durum)
    KEY="${1:-}"; YENI="${2:-}"
    [ -n "$KEY" ] && [ -n "$YENI" ] || { echo "HATA: durum <kod|slug> <insa-bekliyor|insa-ediliyor|insa-edildi>" >&2; exit 2; }
    case "$YENI" in insa-bekliyor|insa-ediliyor|insa-edildi) ;; *) echo "HATA: geçersiz durum: $YENI" >&2; exit 2;; esac
    KEY="$KEY" YENI="$YENI" python3 - <<'PY'
import os, json, io, sys
led=os.environ["LAYIHA_LEDGER"]; key=os.environ["KEY"]; yeni=os.environ["YENI"]
if not os.path.exists(led): sys.stderr.write("HATA: defter yok: %s\n"%led); sys.exit(2)
out=[]; found=False
with io.open(led,encoding="utf-8") as f:
    for l in f:
        if not l.strip(): continue
        r=json.loads(l)
        if r.get("slug")==key or str(r.get("id","")).lower()==key.lower(): r["durum"]=yeni; found=True
        out.append(json.dumps(r,ensure_ascii=False)+"\n")
if not found: sys.stderr.write("HATA: kod/slug bulunamadı: %s\n"%key); sys.exit(2)
with io.open(led,"w",encoding="utf-8") as f: f.writelines(out)
print("OK: %s → %s"%(key,yeni))
PY
  ;;
  liste)
    FILT="aktif"; PORC=0
    for arg in "$@"; do case "$arg" in
      --aktif) FILT="aktif";; --bugun) FILT="bugun";; --hafta) FILT="hafta";;
      --hafta-bitmemis) FILT="hafta-bitmemis";; --hepsi) FILT="hepsi";;
      --porcelain) PORC=1;; esac; done
    TODAY="$(date +%F)"; WEEK="$(date +%G-W%V)"
    # otomatik id-backfill: id'siz eski kayıtlara kod ata (idempotent migrasyon)
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
# id-backfill (kalıcı): id'siz kayıtlara sıralı kod ver
def id_num(x):
    try: return int(str(x).lstrip("Ll"))
    except: return 0
mx=max([id_num(r.get("id","")) for r in recs] + [0]); changed=False
for r in recs:
    if not r.get("id"): mx+=1; r["id"]="L%02d"%mx; changed=True
if changed and recs:
    with io.open(led,"w",encoding="utf-8") as f:
        for r in recs: f.write(json.dumps(r,ensure_ascii=False)+"\n")
def isoweek(d):
    try:
        y,m,dd=map(int,d.split("-")); iso=datetime.date(y,m,dd).isocalendar(); return "%d-W%02d"%(iso[0],iso[1])
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
sel.sort(key=lambda r:(r.get("durum")=="insa-edildi", id_num(r.get("id",""))))
DUR={"insa-bekliyor":"⏳ inşa bekliyor","insa-ediliyor":"🔨 inşa ediliyor","insa-edildi":"✅ yapıldı"}
if porc:
    for r in sel:
        print("\t".join([r.get("id",""),r.get("slug",""),r.get("durum",""),r.get("tarih",""),r.get("konu",""),r.get("resume",""),r.get("dokuman","")]))
    print("#OZET\ttoplam=%d\tfiltre=%s"%(len(sel),filt))
else:
    baslik={"aktif":"aktif (inşa bekleyen) layihalar","bugun":"bugünkü layihalar","hafta":"bu haftaki layihalar","hafta-bitmemis":"bu hafta bitmemiş layihalar","hepsi":"TÜM layihalar"}[filt]
    print("🗂️ LAYİHA DEFTERİ · %s · %d kayıt"%(baslik,len(sel))); print("")
    if not sel: print("  (kayıt yok)")
    for r in sel:
        print("  [%s]  %s  · %s"%(r.get("id","?"), DUR.get(r.get("durum"),r.get("durum","")), r.get("konu","")))
        print("        oluşturuldu: %s%s"%(r.get("tarih","?"), ("  ·  devam: \"%s\" de"%r["resume"]) if r.get("resume") else ""))
PY
  ;;
  *) echo "HATA: bilinmeyen komut: $CMD (ekle|durum|liste)" >&2; exit 2;;
esac
