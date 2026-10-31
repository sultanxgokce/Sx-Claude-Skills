#!/usr/bin/env bash
# ekipc-paritesi.test.sh — paketlenmiş ekipc.sh'in izole kutuda (Nexus deposu YOK) çalıştığı ve Nexus kanoniğiyle eşit çıktı verdiği (Kuzey Hat E · G3.6).
# P1 paket kopyası var, sözdizimi geçerli, ÇİVİLİ md5 ile eşit · P2 izole benimse (--baz, manifestsiz): ELLE bayt-verbatim, marker var
# P3 paket başlığı kimliğe GÖMÜLMEZ · P4 yenile aynı temelde no-op, üretilen bölgeye el değmişse exit 5 · P5 manifest isteyen kipler (derle/--rol) hâlâ reddeder
# P7 ortak temele koltuksuz alt personel bölümü (G3.3) manuel-claude kimliğine gömülür ve paket sürümü 1.6.0+ · P6 Nexus kanoniği varsa: kopya md5'i EŞİT ve aynı persona için üretilen kimlik BAYT-AYNI (kanonik yoksa atlanır, çivili eşitlik P1'de ölçüldü)
set -uo pipefail
export LC_ALL=C.UTF-8
HERE="$(cd "$(dirname "$0")" && pwd)"; PAKET="$(cd "$HERE/.." && pwd)"; E="$HERE/ekipc.sh"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
G=0; K=0
ok() { if [ "$2" -eq 0 ]; then G=$((G+1)); echo "  ✓ $1"; else K=$((K+1)); echo "  ✗ $1 ${3:-}"; fi; }
python3 -c "import yaml" 2>/dev/null || { echo "  ? ÖLÇÜLEMEDİ: PyYAML yok — ekipc çalıştırılamaz (rc 3; yeşil DEĞİL)"; exit 3; }

# ÇİVİLİ md5 — paketleme anında Nexus kanoniğinden (scripts/ekipc.sh) ölçülen değer. Kanonik değişince: kopyala + bu satırı güncelle.
CIVI="b54bddb9196dbe25d9c33f96da9c7558"
b="$(md5sum < "$E" | cut -d' ' -f1)"
bash -n "$E" 2>/dev/null; ok "P1a paketlenmiş ekipc.sh var ve sözdizimi geçerli" "$([ $? -eq 0 ] && [ -f "$E" ] && echo 0 || echo 1)"
ok "P1b paket kopyası çivili md5 ile EŞİT ($CIVI)" "$([ "$b" = "$CIVI" ] && echo 0 || echo 1)" "→ paket $b (kanoniği yeniden kopyala ve çiviyi güncelle)"

# İzole kutu: Nexus yok, manifest yok; katalog betiğin yanındaki cekirdek/. Paket tamamen kopyalanır ki yol çözümü gerçek yerleşimle sınansın.
mkdir -p "$T/kutu/skills"; cp -r "$PAKET" "$T/kutu/skills/duzen"; EK="$T/kutu/skills/duzen/scripts/ekipc.sh"
printf 'insan notu\nkimlik gövdesi\n' > "$T/kimlik.md"; cp "$T/kimlik.md" "$T/ilk.md"
bash "$EK" benimse --dosya "$T/kimlik.md" --baz otonom-ajan --manifest "$T/yok.yaml" --apply >/dev/null 2>&1; rc=$?
ok "P2a izole benimse --baz otonom-ajan (manifestsiz) → rc 0" "$([ $rc -eq 0 ] && echo 0 || echo 1)" "→ rc=$rc"
ok "P2b marker var" "$(grep -q 'ekipc:uretilen:basla' "$T/kimlik.md" && echo 0 || echo 1)"
ok "P2c ELLE bölgesi özgün içeriği bayt-verbatim taşır" "$(python3 - "$T/kimlik.md" "$T/ilk.md" <<'PY'
import sys
y=open(sys.argv[1],encoding="utf-8").read(); o=open(sys.argv[2],encoding="utf-8").read()
a="## ELLE (ekipc dokunmaz)\n\n"; i=y.find(a)
print(0 if i>=0 and y[i+len(a):]==o else 1)
PY
)"
ok "P3 paket başlığı (kaynak: Sx duzen/cekirdek) kimliğe GÖMÜLMEDİ" "$(grep -q 'kaynak: Sx duzen/cekirdek' "$T/kimlik.md" && echo 1 || echo 0)"
cp "$T/kimlik.md" "$T/once-yenile.md"
bash "$EK" yenile --dosya "$T/kimlik.md" --baz otonom-ajan --manifest "$T/yok.yaml" --apply >/dev/null 2>&1; rc=$?
ok "P4a aynı temelde yenile no-op (rc 0, bayt-aynı)" "$([ $rc -eq 0 ] && cmp -s "$T/kimlik.md" "$T/once-yenile.md" && echo 0 || echo 1)" "→ rc=$rc"
sed -i '0,/^## /s//## EL-DEĞMİŞ /' "$T/kimlik.md"; cp "$T/kimlik.md" "$T/eldegmis.md"
bash "$EK" yenile --dosya "$T/kimlik.md" --baz otonom-ajan --manifest "$T/yok.yaml" --apply >/dev/null 2>&1; rc=$?
ok "P4b üretilen bölgeye el değmişse yenile exit 5 ve dosyaya DOKUNMAZ" "$([ $rc -eq 5 ] && cmp -s "$T/kimlik.md" "$T/eldegmis.md" && echo 0 || echo 1)" "→ rc=$rc"
bash "$EK" derle --manifest "$T/yok.yaml" >/dev/null 2>&1; rc=$?
ok "P5a manifest isteyen derle manifest yokken exit 3" "$([ $rc -eq 3 ] && echo 0 || echo 1)" "→ rc=$rc"
bash "$EK" benimse --dosya "$T/ilk.md" --rol X --manifest "$T/yok.yaml" >/dev/null 2>&1; rc=$?
ok "P5b --rol kipi manifest yokken exit 3" "$([ $rc -eq 3 ] && echo 0 || echo 1)" "→ rc=$rc"

# P7 (G3.3): manuel-claude ortak temelindeki koltuksuz alt personel bölümü kimliğe gömülür; sürüm ile katalog tutarlı
printf 'persona notu\n' > "$T/man.md"
bash "$EK" benimse --dosya "$T/man.md" --baz manuel-claude --manifest "$T/yok.yaml" --apply >/dev/null 2>&1; rc=$?
ok "P7a izole benimse --baz manuel-claude → rc 0" "$([ $rc -eq 0 ] && echo 0 || echo 1)" "→ rc=$rc"
ok "P7b kimlikte ALT PERSONEL bölümü (alt-ajan-istem.sh göstergesiyle) var" "$(grep -q 'ALT PERSONEL — koltuksuz alt ajan' "$T/man.md" && grep -q 'alt-ajan-istem.sh <AD>' "$T/man.md" && echo 0 || echo 1)"
SV="$(grep -m1 '^version:' "$PAKET/SKILL.md" | awk '{print $2}')"; CV="$(python3 - "$PAKET/.." <<'PY'
import json,sys,os
c=json.load(open(os.path.join(sys.argv[1],"catalog.json"),encoding="utf-8"))
for k in (c if isinstance(c,list) else c.get("skills") or c.get("items") or []):
    pass
t=open(os.path.join(sys.argv[1],"catalog.json"),encoding="utf-8").read(); i=t.find('"id": "duzen"'); j=t.find('"version"',i); print(t[j:].split('"')[3])
PY
)"
ok "P7c SKILL sürümü 1.6.0 ve üstü ($SV)" "$(python3 -c "import sys;v=tuple(int(x) for x in sys.argv[1].split('.'));sys.exit(0 if v>=(1,6,0) else 1)" "${SV:-0.0.0}" && echo 0 || echo 1)"
[ -f "$PAKET/../catalog.json" ] && ok "P7d catalog.json sürümü SKILL ile aynı ($CV)" "$([ "$CV" = "$SV" ] && echo 0 || echo 1)" "→ SKILL $SV ≠ catalog $CV" || echo "  · P7d atlandı: catalog.json paketin yanında yok (kutuya kurulu kopya)"

KAN="${DUZEN_EKIPC_KANONIK:-/config/projects/Nexus/scripts/ekipc.sh}"
if [ -f "$KAN" ]; then
  a="$(md5sum < "$KAN" | cut -d' ' -f1)"
  ok "P6a Nexus kanoniği (canlı) ile md5 EŞİT" "$([ "$a" = "$b" ] && echo 0 || echo 1)" "→ kanonik $a ≠ paket $b (kanonik ilerlemiş: kopyala + çiviyi güncelle)"
  KOK="$(cd "$(dirname "$KAN")/.." && pwd)"
  if [ -d "$KOK/_agents/ekip-os-base" ] && [ -f "$KOK/_agents/ekip-modeli.yaml" ]; then
    cp "$T/ilk.md" "$T/nexus.md"
    bash "$KAN" benimse --dosya "$T/nexus.md" --baz otonom-ajan --apply >/dev/null 2>&1
    cp "$T/ilk.md" "$T/paket.md"; bash "$EK" benimse --dosya "$T/paket.md" --baz otonom-ajan --manifest "$T/yok.yaml" --apply >/dev/null 2>&1
    ok "P6b aynı persona: paket ile Nexus kimliği BAYT-AYNI" "$(cmp -s "$T/nexus.md" "$T/paket.md" && echo 0 || echo 1)"
  else echo "  · P6b atlandı: Nexus katalogu/manifesti bu kutuda yok"; fi
else echo "  · P6 atlandı: Nexus kanoniği bu kutuda yok — çivili eşitlik (P1b) ve izole çalışma (P2-P5) ölçüldü"; fi
echo "== $G geçti · $K düştü =="; [ "$K" -eq 0 ]
