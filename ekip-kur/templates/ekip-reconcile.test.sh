#!/usr/bin/env bash
# ekip-reconcile.test.sh — koltuk: yok (uyuyan usta) bayrak gürültüsü üretmez + MUTANT
# kabuk-testleri: sure=120
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; G=0; K=0
has() { case "$2" in *"$1"*) return 0;; esac; return 1; }   # düz alt dize (boru arkasında grep -q yok)
ok() { if [ "$2" = 1 ]; then G=$((G+1)); echo "  ✓ $1"; else K=$((K+1)); echo "  ✗ $1  → ${3:-}"; fi; }
kos() { local S="$1" T; T="$(mktemp -d)"; mkdir -p "$T/_agents/handoff"
  cat > "$T/ekip-registry.yaml" <<Y
meta:
  uye_sayisi: 3
  yonetici: ANA
uyeler:
  - id: ANA
    tmux: "ana-yok-oturum:0"
  - id: PERGEL
    ad: PERGEL
    klasor: ustalar/PERGEL
    koltuk: yok
  - id: KUKLACI
    klasor: ustalar/KUKLACI
    koltuk: "yok"   # uyuyan
Y
  O="$(EKIP_REGISTRY="$T/ekip-registry.yaml" bash "$S" --dry-run 2>&1)"
  ok "R1 koltuk:yok üyeler için tmux-alani-parse-edilemedi bayrağı YOK" "$(has 'parse-edilemedi' "$O" && echo 0 || echo 1)" "$O"
  ok "R2 koltuklu ama ölü üye hâlâ bayraklanır (olu-oturum ANA)" "$(has $'olu-oturum\tANA' "$O" && echo 1 || echo 0)" "$O"
  find "$T" -delete; }
kos "$HERE/ekip-reconcile.sh"
echo "SONUÇ: geçti=$G kaldı=$K"; [ "$K" -eq 0 ] || exit 1
M="$(mktemp -d)"; cp "$HERE/ekip-reconcile.sh" "$M/r.sh"
python3 -I -c "import sys;p=sys.argv[1];s=open(p,encoding='utf-8').read();a='if m.get(\"koltuk_yok\") and not sess:';assert s.count(a)==1;open(p,'w',encoding='utf-8').write(s.replace(a,'if False:'))" "$M/r.sh"
G=0; K=0; kos "$M/r.sh" >/dev/null 2>&1; kk=$K; find "$M" -delete
[ "$kk" -gt 0 ] && echo "MUTANT: 1/1 yakalandı" || { echo "MUTANT: kaçtı"; exit 1; }
