#!/usr/bin/env bash
# karne.sh — puan kalibrasyonu defteri: "puan da bir beyandır". Denetçinin verdiği her sonuç deftere girer;
# sonradan kırılan iş "kırıldı" damgası alır; haftalık soru: "5 alanların kaçı kırıldı?" Sayı yoksa puanlama süstür.
#
# Kullanım:
#   karne.sh yaz <iş> [--depo KÖK]              son DENETIM-*.json'u okur, deftere tek satır ekler (tur · süre · puan · E/H)
#   karne.sh kirildi <iş|PR> --neden "..."      o işi "kırıldı" diye damgalar (kanıt referansı zorunlu: --kanit)
#   karne.sh ozet [--gun N]                     son N günde: kaç iş · 5 alan · kırılan · ortalama tur · tıkanan
# Defter: <depo>/_agents/fabrika/karne.jsonl (append-only; satır silinmez)
set -uo pipefail
_hata() { printf '✗ %s\n' "$*" >&2; }
DEPO="${KANIT_DEPO:-}"
args=(); NEDEN=""; KANIT=""; GUN=7
while [ $# -gt 0 ]; do case "$1" in
  --depo) DEPO="$2"; shift 2 ;; --neden) NEDEN="$2"; shift 2 ;; --kanit) KANIT="$2"; shift 2 ;; --gun) GUN="$2"; shift 2 ;;
  *) args+=("$1"); shift ;; esac; done
# Defter BİRİNCİL depoda (worktree'ler ortak yazar); DENETIM kayıtları çağrıldığı ağaçtan (worktree) okunur.
WT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
[ -n "$DEPO" ] || { c="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" && DEPO="$(dirname "$c")"; }
[ -n "$DEPO" ] || { _hata "depo kökü bulunamadı"; exit 3; }
[ -n "$WT" ] || WT="$DEPO"
DEFTER="$DEPO/_agents/fabrika/karne.jsonl"; mkdir -p "$(dirname "$DEFTER")"
CMD="${args[0]:-}"; HEDEF="${args[1]:-}"

case "$CMD" in
  yaz)
    [ -n "$HEDEF" ] || { _hata "iş adı gerekiyor"; exit 1; }
    DZ="$WT/_agents/fabrika/kanit/$HEDEF"; [ -d "$DZ" ] || DZ="$DEPO/_agents/fabrika/kanit/$HEDEF"
    SON="$(ls "$DZ"/DENETIM-[0-9]*.json 2>/dev/null | sort -V | tail -1)"
    [ -n "$SON" ] || { _hata "$HEDEF için DENETIM kaydı yok — karneye yazacak şey yok"; exit 3; }
    python3 - "$DZ" "$SON" "$DEFTER" "$HEDEF" <<'PY'
import json,sys,os,glob,datetime
dz,son,defter,is_=sys.argv[1:]
d=json.load(open(son)); turlar=sorted(glob.glob(os.path.join(dz,"DENETIM-[0-9]*.json")),key=lambda p:int(p.rsplit("-",1)[1].split(".")[0]))
ilk=json.load(open(turlar[0])); t0=datetime.datetime.fromisoformat(ilk["zaman"]); t1=datetime.datetime.fromisoformat(d["zaman"])
s=d["sonuc"]; gecti=(s["kod_puani"]==5 and s["dogru_sey"]=="E")
satir={"olay":"denetim","is":is_,"pr":d.get("pr",""),"zaman":d["zaman"],"yazan":d["yazan"],"denetci":d["denetci"],
       "tur":d["tur"],"puan":s["kod_puani"],"dogru":s["dogru_sey"],"bulgu":len(s["bulgular"]),"gecti":gecti,
       "sure_dk":round((t1-t0).total_seconds()/60,1),"kirildi":None}
open(defter,"a",encoding="utf-8").write(json.dumps(satir,ensure_ascii=False)+"\n")
print(f"✓ karne: {is_} · tur {d['tur']} · {s['kod_puani']}/5 {s['dogru_sey']} · {'GEÇTİ' if gecti else 'geçmedi'} · {satir['sure_dk']} dk")
PY
    ;;
  kirildi)
    [ -n "$HEDEF" ] && [ -n "$NEDEN" ] && [ -n "$KANIT" ] || { _hata "kirildi <iş|PR> --neden '...' --kanit <PR#|dosya> (bulgu da kanıt ister)"; exit 1; }
    python3 - "$DEFTER" "$HEDEF" "$NEDEN" "$KANIT" <<'PY'
import json,sys,datetime
defter,hedef,neden,kanit=sys.argv[1:]
open(defter,"a",encoding="utf-8").write(json.dumps({"olay":"kirildi","is":hedef,"zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds"),"neden":neden,"kanit":kanit},ensure_ascii=False)+"\n")
print(f"✓ damga: {hedef} KIRILDI — {neden} (kanıt: {kanit})")
PY
    ;;
  ozet)
    [ -f "$DEFTER" ] || { echo "◻ karne defteri yok — henüz denetim geçmemiş"; exit 3; }
    python3 - "$DEFTER" "$GUN" <<'PY'
import json,sys,datetime
defter,gun=sys.argv[1],int(sys.argv[2])
esik=datetime.datetime.now().astimezone()-datetime.timedelta(days=gun)
rows=[json.loads(l) for l in open(defter,encoding="utf-8") if l.strip()]
den=[r for r in rows if r["olay"]=="denetim" and datetime.datetime.fromisoformat(r["zaman"])>=esik]
kir={r["is"] for r in rows if r["olay"]=="kirildi"}|{r.get("pr") for r in rows if r["olay"]=="kirildi"}
son={}  # iş → son satır
for r in den: son[r["is"]]=r
bes=[r for r in son.values() if r["gecti"]]; kirilan=[r for r in bes if r["is"] in kir or r.get("pr") in kir]
tikanan=[r for r in son.values() if not r["gecti"] and r["tur"]>=3]
ort=(sum(r["tur"] for r in son.values())/len(son)) if son else 0
print(f"KARNE · son {gun} gün · iş: {len(son)} · 5+E alan: {len(bes)} · KIRILAN (5 alıp sonradan kırılan): {len(kirilan)} · tıkanan: {len(tikanan)} · ortalama tur: {ort:.1f}")
for r in kirilan: print(f"  ✗ {r['is']} (PR {r.get('pr','')}) — 5 verildi, kırıldı")
if not bes: print("  (5 verilen iş yok — kalibrasyon sorusu henüz sorulamaz)")
PY
    ;;
  *) sed -n '1,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
