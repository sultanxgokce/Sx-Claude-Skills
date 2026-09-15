#!/usr/bin/env bash
# repo-bul sınavı — AĞSIZ. "Global dizine kurulunca kök kayar" tuzağının kapısı.
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=0; K=0
kapi(){ if [ "$2" = "$3" ]; then G=$((G+1)); printf '  ✓ %s\n' "$1";
        else K=$((K+1)); printf '  ✗ %s\n     beklenen: %s\n     görülen : %s\n' "$1" "$2" "$3"; fi; }
TMP="$(mktemp -d)"; trap 'chmod -R u+w "$TMP" 2>/dev/null; find "$TMP" -type f -delete 2>/dev/null; find "$TMP" -depth -type d -empty -delete 2>/dev/null' EXIT
mkdir -p "$TMP/proje/_agents/handoff" "$TMP/proje/derin/daha-derin" "$TMP/projesiz/alt"
: > "$TMP/proje/_agents/handoff/ekip-registry.yaml"

cagir(){ # cagir <cwd> [CLAUDE_PROJECT_DIR]
  ( cd "$1" && CLAUDE_PROJECT_DIR="${2-}" bash -c '. "'"$KOK"'/repo-bul.sh"; repo_bul; printf " rc=%s" $?' )
}

kapi "R1 proje kökünden çağrılınca kökü bulur" "$TMP/proje rc=0" "$(cagir "$TMP/proje")"
kapi "R2 derin alt dizinden yukarı yürüyüp bulur (global kurulumda cwd her yerde olabilir)" \
  "$TMP/proje rc=0" "$(cagir "$TMP/proje/derin/daha-derin")"
kapi "R3 açık ayar geçerliyse o kullanılır (cwd başka yerde olsa da)" \
  "$TMP/proje rc=0" "$(cagir "$TMP/projesiz/alt" "$TMP/proje")"
kapi "R4 açık ayar YANLIŞSA sessizce kabul edilmez — cwd'den arama yapılır" \
  "$TMP/proje rc=0" "$(cagir "$TMP/proje/derin" "$TMP/projesiz")"
kapi "R5 hiçbir yerde kayıt yoksa rc=1 (sahte kök uydurulmaz)" \
  "$TMP/projesiz rc=1" "$(cagir "$TMP/projesiz/alt" "$TMP/projesiz")"

printf '\ngeçti=%s · kaldı=%s\n' "$G" "$K"
[ "$K" -eq 0 ]
