#!/usr/bin/env bash
# golge-birlestirme.sh — "birleştirirdim" kaydı: otomatik birleştirmenin 1 haftalık YALNIZ-BİLDİRİM aşaması (TCBXPP · Sultan 26 Eki).
#
# Üç kapı yeşil + sınıfsız iş → araç GERÇEKTEN BİRLEŞTİRMEZ; "birleştirirdim" der: yerel deftere satır, görev defterine adım, SERDAR'a zil.
# Hafta sonunda golge-rapor.sh bu satırları gerçek sonuçla karşılaştırır (kapı yeşil dedi ama PR kapandı/geri alındı = SAHTE YEŞİL);
# sahte yeşil sayısı kabul edilebilirse otomatik birleştirme açılır. Sınıflı iş ve kartsız iş KAYIT DIŞIDIR (karar insanındır, A06).
#
# Kullanım: golge-birlestirme.sh <iş> --depo KÖK [--pr N] [--sha SHA]       (birlestirme-kapisi.sh rc0'da çağırır)
# Ortam:   FABRIKA_GOLGE=0 kapatır · FABRIKA_GOLGE_DEFTER (varsayılan ~/.claude/fabrika/golge-birlestirme.jsonl)
#          FABRIKA_GOREV_SH (görev defteri aracı) · FABRIKA_AILE_NOTIFY (zil aracı; "-" = zil yok, sınav kipi)
# rc: her zaman 0 — kayıt kapıyı ASLA bozmaz; sorun stderr'e yazılır (sessiz yutulmaz).
set -uo pipefail
IS=""; DEPO=""; PR=""; SHA=""
while [ $# -gt 0 ]; do case "$1" in
  --depo) DEPO="$2"; shift 2 ;; --pr) PR="$2"; shift 2 ;; --sha) SHA="$2"; shift 2 ;;
  *) [ -z "$IS" ] && IS="$1"; shift ;;
esac; done
[ "${FABRIKA_GOLGE:-1}" = "0" ] && exit 0
[ -n "$IS" ] && [ -n "$DEPO" ] || { echo "⚠ golge-birlestirme: iş adı ve --depo gerekli — kayıt yazılmadı" >&2; exit 0; }
KART="$DEPO/_agents/fabrika/kartlar/$IS.json"
[ -f "$KART" ] || exit 0

# Kart: sınıflı/Sultan'lı iş kayıt dışı; görev kimliği ve depo adı kayda girer.
BILGI="$(python3 - "$KART" <<'PY' 2>/dev/null
import json,sys
k=json.load(open(sys.argv[1]))
if k.get("siniflar") or k.get("sultan"): print("SINIFLI"); raise SystemExit
print("TAMAM\t"+str(k.get("gorev") or "")+"\t"+str(k.get("aldi") or ""))
PY
)"
case "$BILGI" in TAMAM*) ;; *) exit 0 ;; esac
GOREV="$(printf '%s' "$BILGI" | cut -f2)"; ALDI="$(printf '%s' "$BILGI" | cut -f3)"
[ -n "$SHA" ] || SHA="$(git -C "$DEPO" rev-parse HEAD 2>/dev/null || echo bilinmiyor)"
REPO="$(git -C "$DEPO" remote get-url origin 2>/dev/null | sed -E 's#^.*github\.com[:/]##; s#\.git$##')"

DEFTER="${FABRIKA_GOLGE_DEFTER:-$HOME/.claude/fabrika/golge-birlestirme.jsonl}"
mkdir -p "$(dirname "$DEFTER")" 2>/dev/null || { echo "⚠ golge-birlestirme: defter dizini açılamadı ($DEFTER) — kayıt yazılmadı" >&2; exit 0; }
# Aynı (iş, PR, sha) ikinci kez yazılmaz: kapı birden çok koşabilir, her koşu yeni "birleştirirdim" değildir.
if [ -f "$DEFTER" ] && python3 - "$DEFTER" "$IS" "$PR" "$SHA" <<'PY'
import json,sys
d,is_,pr,sha=sys.argv[1:]
for s in open(d,encoding="utf-8"):
    try: r=json.loads(s)
    except Exception: continue
    if r.get("is")==is_ and str(r.get("pr") or "")==pr and r.get("sha")==sha: raise SystemExit(0)
raise SystemExit(1)
PY
then echo "· golge: '$IS' PR #${PR:--} aynı başla zaten kayıtlı — ikinci kayıt yok"; exit 0; fi

python3 - "$DEFTER" "$IS" "$PR" "$SHA" "$REPO" "$ALDI" "$GOREV" <<'PY' || { echo "⚠ golge-birlestirme: defter satırı yazılamadı" >&2; exit 0; }
import json,sys,datetime
d,is_,pr,sha,repo,aldi,gorev=sys.argv[1:]
r={"zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds"),"is":is_,"pr":pr,"sha":sha,"repo":repo,"aldi":aldi,"gorev":gorev}
open(d,"a",encoding="utf-8").write(json.dumps(r,ensure_ascii=False)+"\n")
PY
MSG="birleştirirdim: '$IS'${PR:+ (PR #$PR)}${REPO:+ · $REPO} — 5/E + kapı temiz + sınıfsız; GERÇEKTEN birleştirilmedi (1 hafta yalnız bildirim)"
echo "✓ golge: $MSG"

GS="${FABRIKA_GOREV_SH:-/config/projects/cloudtop/infra/defter-gecit/gorev/gorev.sh}"
if [ -n "$GOREV" ] && [ -x "$GS" ]; then
  bash "$GS" adim "$GOREV" "[birleştirirdim] $MSG" >/dev/null 2>&1 || echo "⚠ golge: görev adımı yazılamadı ($GOREV)" >&2
fi

AN="${FABRIKA_AILE_NOTIFY:-}"
if [ "$AN" = "-" ]; then exit 0; fi
[ -n "$AN" ] || AN="$(command -v aile-notify.sh 2>/dev/null)"
[ -n "$AN" ] || for k in "$DEPO/scripts/aile-notify.sh" /config/projects/Nexus/scripts/aile-notify.sh; do [ -f "$k" ] && { AN="$k"; break; }; done
if [ -z "$AN" ] || [ ! -f "$AN" ]; then echo "⚠ golge zili ATLANDI: aile-notify bulunamadı (FABRIKA_AILE_NOTIFY ile ver)" >&2; exit 0; fi
bash "$AN" SERDAR "golge: $MSG" </dev/null >/dev/null 2>&1 || true   # meşgul koltukta zil kuyruğa girer; rc'ye bakılmaz
exit 0
