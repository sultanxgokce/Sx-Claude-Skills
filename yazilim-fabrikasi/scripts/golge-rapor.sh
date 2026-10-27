#!/usr/bin/env bash
# golge-rapor.sh — "birleştirirdim" kayıtlarını GERÇEK sonuçla karşılaştırır (TCBXPP: 1 hafta sonunda sahte yeşil sayısı).
#
# Her kayıt için PR'ın gerçek akıbeti sorulur: birleşti · kapandı (birleşmeden) · hâlâ açık · geri alındı (birleşmiş + sonradan "Revert" PR'ı).
# SAHTE YEŞİL = kapı "geçti" dedi ama PR birleşmeden kapandı ya da birleştikten sonra geri alındı. Açık olan henüz hüküm DEĞİLDİR.
# Ölçülemeyen kayıt (gh yok, depo bilinmiyor, liste tavana dayandı) yeşil sayılmaz: "ölçülemedi" diye ayrı sayılır.
#
# Kullanım: golge-rapor.sh [--gun N]        (varsayılan 7 gün)
# Ortam:   FABRIKA_GOLGE_DEFTER · GOLGE_GH (gh yerine sahte araç — sınav) · GOLGE_TAVAN (varsayılan 1000)
# rc: 0 rapor basıldı · 3 hiçbir kayıt ölçülemedi / defter okunamadı
set -uo pipefail
GUN=7
while [ $# -gt 0 ]; do case "$1" in --gun) GUN="$2"; shift 2 ;; *) echo "✗ tanınmayan argüman: $1" >&2; exit 2 ;; esac; done
DEFTER="${FABRIKA_GOLGE_DEFTER:-$HOME/.claude/fabrika/golge-birlestirme.jsonl}"
[ -f "$DEFTER" ] || { echo "✗ golge defteri yok ($DEFTER) — henüz kayıt yazılmamış; ÖLÇÜLEMEDİ" >&2; exit 3; }
GH="${GOLGE_GH:-gh}"; TAVAN="${GOLGE_TAVAN:-1000}"

# Depo başına bir kez: birleşmiş+kapanmış+açık PR'lar ve "Revert" PR'ları (tek liste; tavan okuması olay değil tavandır).
KAYITLAR="$(python3 - "$DEFTER" "$GUN" <<'PY'
import json,sys,datetime
d,gun=sys.argv[1:]; sinir=datetime.datetime.now().astimezone()-datetime.timedelta(days=int(gun))
for s in open(d,encoding="utf-8"):
    try: r=json.loads(s)
    except Exception: continue
    try: z=datetime.datetime.fromisoformat(r["zaman"])
    except Exception: continue
    if z>=sinir: print(json.dumps(r,ensure_ascii=False))
PY
)"
[ -n "$KAYITLAR" ] || { echo "golge raporu ($GUN gün): kayıt yok — 'birleştirirdim' üreten iş olmamış"; exit 0; }

REPOLAR="$(printf '%s\n' "$KAYITLAR" | python3 -c "import sys,json;print('\n'.join(sorted({json.loads(l).get('repo') or '' for l in sys.stdin if l.strip()})))")"
TMP="$(mktemp -d)"; trap 'rm -r -f "$TMP"' EXIT
i=0
while IFS= read -r repo; do
  i=$((i+1))
  [ -n "$repo" ] || continue
  if J="$($GH pr list --repo "$repo" --state all --limit "$TAVAN" --json number,state,title,body,mergedAt 2>/dev/null)" && [ -n "$J" ]; then
    printf '%s' "$J" > "$TMP/$(printf '%s' "$repo" | tr '/' '_').json"
  fi
done <<< "$REPOLAR"

printf '%s\n' "$KAYITLAR" > "$TMP/kayit.jsonl"

# Liste tavana dayandıysa (büyük depo) listeden hüküm VERİLMEZ; kaydın PR'ı numarasıyla tek tek sorulur (view) ve geri alma
# PR'ı numarayla aranır. Tek PR sorusu tavana takılmaz; alınamayan kayıt yine "ölçülemedi" kalır (yeşil sayılmaz).
python3 - "$TMP" "$TAVAN" > "$TMP/tekil.txt" <<'PY'
import json,sys,os
tmp,tavan=sys.argv[1],int(sys.argv[2]); gor=set()
for l in open(os.path.join(tmp,"kayit.jsonl"),encoding="utf-8"):
    if not l.strip(): continue
    k=json.loads(l); r=k.get("repo") or ""; pr=str(k.get("pr") or "")
    f=os.path.join(tmp,r.replace("/","_")+".json")
    if not (r and pr.isdigit() and os.path.exists(f)): continue
    try:
        if len(json.load(open(f,encoding="utf-8")))>=tavan and (r,pr) not in gor: gor.add((r,pr)); print(r,pr)
    except Exception: pass
PY
while read -r repo pr; do
  [ -n "$pr" ] || continue
  ad="$(printf '%s' "$repo" | tr '/' '_')_$pr"
  if V="$($GH pr view "$pr" --repo "$repo" --json number,state,title,body,mergedAt 2>/dev/null)" && [ -n "$V" ]; then
    printf '%s' "$V" > "$TMP/view_$ad.json"
    if R="$($GH pr list --repo "$repo" --state all --limit 100 --search "Revert #$pr in:title,body" --json number,state,title,body,mergedAt 2>/dev/null)" && [ -n "$R" ]; then printf '%s' "$R" > "$TMP/rev_$ad.json"; fi
  fi
done < "$TMP/tekil.txt"
python3 - "$TMP" "$TAVAN" <<'PY'
import json,sys,os,re
tmp,tavan=sys.argv[1],int(sys.argv[2])
kay=[json.loads(l) for l in open(os.path.join(tmp,"kayit.jsonl"),encoding="utf-8") if l.strip()]
liste={}; tavanda=set()
for r in {k.get("repo") or "" for k in kay}:
    f=os.path.join(tmp,r.replace("/","_")+".json")
    if r and os.path.exists(f):
        try:
            prler=json.load(open(f,encoding="utf-8")); liste[r]=prler
            if len(prler)>=tavan: tavanda.add(r)
        except Exception: pass
say={"birlesti":0,"acik":0,"kapandi":0,"geri":0,"olculemedi":0}; sahte=[]; goz=[]
for k in kay:
    r=k.get("repo") or ""; pr=str(k.get("pr") or "")
    if not pr.isdigit() or r not in liste: say["olculemedi"]+=1; goz.append(f"  ? {k['is']} — ölçülemedi ({'PR no yok' if not pr.isdigit() else 'liste okunamadı'})"); continue
    if r in tavanda:
        ad=r.replace("/","_")+"_"+pr; vf=os.path.join(tmp,"view_"+ad+".json"); rf=os.path.join(tmp,"rev_"+ad+".json")
        try:
            p=json.load(open(vf,encoding="utf-8")); rev=json.load(open(rf,encoding="utf-8")) if os.path.exists(rf) else None
        except Exception: p=None
        if not p or not isinstance(p,dict) or (rev is None and (p.get("mergedAt") or p.get("state")=="MERGED")):
            say["olculemedi"]+=1; goz.append(f"  ? {k['is']} PR #{pr} — ölçülemedi (liste tavanda, tek PR sorusu da alınamadı)"); continue
        hl=[p]+(rev or [])
    else:
        p=next((x for x in liste[r] if str(x.get("number"))==pr),None); hl=liste[r]
    if not p: say["olculemedi"]+=1; goz.append(f"  ? {k['is']} PR #{pr} — listede yok"); continue
    durum=p.get("state"); birl=bool(p.get("mergedAt")) or durum=="MERGED"
    geri=birl and any((x.get("title") or "").lower().startswith("revert") and re.search(rf"#{pr}\b",(x.get("title") or "")+" "+(x.get("body") or "")) for x in hl)
    if geri: say["geri"]+=1; sahte.append(f"  ✗ {k['is']} PR #{pr} — birleşti, sonra GERİ ALINDI")
    elif birl: say["birlesti"]+=1
    elif durum=="OPEN": say["acik"]+=1
    else: say["kapandi"]+=1; sahte.append(f"  ✗ {k['is']} PR #{pr} — kapı geçti ama PR BİRLEŞMEDEN kapandı")
hukum=len(kay)-say["acik"]-say["olculemedi"]
print(f"golge raporu: {len(kay)} 'birleştirirdim' kaydı · birleşti {say['birlesti']} · geri alındı {say['geri']} · birleşmeden kapandı {say['kapandi']} · hâlâ açık {say['acik']} · ölçülemedi {say['olculemedi']}")
print(f"SAHTE YEŞİL: {len(sahte)} / {hukum} hükme varmış kayıt (açık ve ölçülemeyen hüküm sayılmaz)")
for s in sahte+goz: print(s)
raise SystemExit(3 if kay and say["olculemedi"]==len(kay) else 0)
PY
