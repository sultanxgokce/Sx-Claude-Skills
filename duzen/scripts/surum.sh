#!/usr/bin/env bash
# surum.sh — düzen paketinin sürüm yüzeyi: paket sürümünü GÖSTERİR, kutudaki kurulumu ve ekipc işaretli kimlikleri DENETLER.
# 1.0.0 yalnız RAPORLAR, hiçbir dosyaya yazmaz (--kuru varsayılan ve tek kip; yazma yolu bu sürümde yok).
#
# Kullanım:
#   surum.sh goster                      → paket sürümü (SKILL.md frontmatter'ındaki version:)
#   surum.sh denetle [--depo KÖK] [--kurulu DİZİN] [--kuru]
#        1) kurulu duzen (varsayılan /config/.claude/skills/duzen) sürümü = kaynak sürümü mü
#        2) <depo>/_agents/*/AGENT.md içinde ekipc işaretli (<!-- ekipc:uretilen:basla … hash= -->) her kimlik:
#           · hash gövdeyle tutuyor mu (tutmuyorsa EL-DEĞMİŞ)
#           · gövdeye gömülü ORTAK-TEMEL metni cekirdek/{manuel-claude-base,mudur-base,otonom-ajan-base}.md ile birebir mi (değilse BAYAT)
#           işaretsiz AGENT.md'ler sayılır, yargılanmaz ("işaretsiz N" — pakete dahil mi kararı Sultan'ın).
# rc: 0 hepsi güncel · 1 bayat/el-değmiş/sürüm farkı var · 2 kullanım · 3 ölçülemedi (ne kurulu kopya ne AGENT.md bulundu)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PAKET="$(cd "$HERE/.." && pwd)"

surum_oku() { sed -nE 's/^[[:space:]]*version:[[:space:]]*["'"'"']?([0-9]+\.[0-9]+\.[0-9]+)["'"'"']?[[:space:]]*$/\1/p' "$1" 2>/dev/null | head -1; }

KOMUT="${1:-}"; shift || true
case "$KOMUT" in
  goster) v="$(surum_oku "$PAKET/SKILL.md")"; [ -n "$v" ] || { echo "surum: SKILL.md'de version yok" >&2; exit 3; }; echo "$v"; exit 0 ;;
  denetle) ;;
  -h|--help|"") sed -n '2,16p' "$0"; [ "$KOMUT" = "" ] && exit 2 || exit 0 ;;
  *) echo "surum: bilinmeyen komut: $KOMUT (goster|denetle)" >&2; exit 2 ;;
esac

DEPO=""; KURULU="${DUZEN_KURULU:-/config/.claude/skills/duzen}"
while [ $# -gt 0 ]; do
  case "$1" in
    --depo) DEPO="${2:-}"; shift 2 ;;
    --kurulu) KURULU="${2:-}"; shift 2 ;;
    --kuru) shift ;;
    --uygula) echo "surum: 1.0.0'da yazma yolu yok — yalnız raporlar (kurulum: node sync-skills.mjs --skill duzen --apply)" >&2; exit 2 ;;
    *) echo "surum: bilinmeyen seçenek: $1" >&2; exit 2 ;;
  esac
done
[ -n "$DEPO" ] || DEPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

KAYNAK="$(surum_oku "$PAKET/SKILL.md")"; SORUN=0; OLCULDU=0
echo "duzen · kaynak sürüm: ${KAYNAK:-?} ($PAKET)"

# 1) kurulu kopya
if [ -f "$KURULU/SKILL.md" ]; then
  OLCULDU=1; KV="$(surum_oku "$KURULU/SKILL.md")"
  if [ "$KURULU" -ef "$PAKET" ]; then echo "  kurulu: $KURULU = kaynağın kendisi (v${KV:-?})"
  elif [ "$KV" = "$KAYNAK" ]; then echo "  kurulu: v${KV:-?} GÜNCEL ($KURULU)"
  else echo "  kurulu: v${KV:-?} ≠ kaynak v${KAYNAK:-?} → BAYAT ($KURULU) · kurulum: node sync-skills.mjs --skill duzen --apply"; SORUN=1; fi
else
  echo "  kurulu: yok ($KURULU) — bu kutuya henüz inmemiş"
fi

# 2) ekipc işaretli kimlikler
export DUZEN_DEPO="$DEPO" DUZEN_CEKIRDEK="$PAKET/cekirdek"
python3 -I - <<'PY'
import glob, hashlib, os, sys
depo=os.environ["DUZEN_DEPO"]; cek=os.environ["DUZEN_CEKIRDEK"]
BASLA="<!-- ekipc:uretilen:basla"; BITTI="<!-- ekipc:uretilen:bitti -->"
def oku(p):
    with open(p,encoding="utf-8") as f: return f.read()
def cekirdek(ad):
    p=os.path.join(cek,ad+".md")
    if not os.path.exists(p): return None
    s=oku(p); L=s.split("\n")
    if L and L[0].startswith("<!-- kaynak: Sx duzen/cekirdek"): L=L[1:]   # paket başlığı Nexus kopyasında yok
    return "\n".join(L).strip()
temeller={a:cekirdek(a) for a in ("manuel-claude-base","mudur-base","otonom-ajan-base","izole-kutu-base","alt-personel-base")}
dosyalar=sorted(glob.glob(os.path.join(depo,"_agents","*","AGENT.md")))
isaretli=0; isaretsiz=0; sorun=0
for p in dosyalar:
    s=oku(p); L=s.split("\n"); b0=b1=None
    for i,l in enumerate(L):
        c=l.strip()
        if c.startswith("# "): c=c[2:]
        if b0 is None and c.startswith(BASLA): b0=i
        elif b0 is not None and c==BITTI: b1=i; break
    if b0 is None or b1 is None: isaretsiz+=1; continue
    isaretli+=1
    import re
    m=re.search(r"hash=([0-9a-f]{64})",L[b0]); stored=m.group(1) if m else ""
    g="\n".join(L[b0+1:b1])+("\n" if b1>b0+1 else "")
    ad=os.path.basename(os.path.dirname(p))
    if hashlib.sha256(g.encode("utf-8")).hexdigest()!=stored:
        print(f"  {ad}: EL-DEĞMİŞ (hash gövdeyle tutmuyor)"); sorun+=1; continue
    temel=next((a for a in temeller if temeller[a] and temeller[a] in g), None)
    if temel: print(f"  {ad}: GÜNCEL ({temel} birebir gömülü)")
    else:
        eski=next((a for a in temeller if f"ekip-os-base/{a}.md" in g), None)
        print(f"  {ad}: BAYAT (gövdedeki ORTAK-TEMEL çekirdekle birebir değil{' · temel: '+eski if eski else ''})"); sorun+=1
print(f"  ekipc işaretli {isaretli} · işaretsiz {isaretsiz} (depo: {depo})")
sys.exit(10 if isaretli else 11) if sorun==0 else sys.exit(1)
PY
rc=$?
case $rc in 10) OLCULDU=1 ;; 11) ;; 1) OLCULDU=1; SORUN=1 ;; *) echo "surum: kimlik taraması çöktü (rc $rc)" >&2; exit 3 ;; esac

[ "$OLCULDU" -eq 1 ] || { echo "  ÖLÇÜLEMEDİ: ne kurulu kopya ne ekipc işaretli AGENT.md bulundu"; exit 3; }
if [ "$SORUN" -eq 0 ]; then echo "SONUÇ: güncel"; exit 0; else echo "SONUÇ: bayat/el-değmiş var (rc 1) — yazmadı, yalnız raporladı"; exit 1; fi
