#!/usr/bin/env bash
# el-defteri.test.sh — hermetik sınav (sahte depo + sahte NOTES.md + sahte gorev.sh).
# E1 defter yoksa rc 3 ve "el defteri yok" (uydurmaz) · E2 bugünkü ÇIPA bulunur · E3 son KONUM satırı basılır
# E4 --n son N satır · E5 açık işler: koltuğun satırları gelir, iptal/bitti elenir · E6 gorev.sh yoksa "ölçülemedi", rc 0
# E7 çıktı tavanı (≤45 satır) · mutant: defter-yok rc 3 → 0 olursa E1 kırmızı
set -uo pipefail
export LC_ALL=C.UTF-8   # Türkçe karakterli ad/desen: C yerelinde sed y// ve grep -w bozulur (CI/kutu yerelinden bağımsız)
HERE="$(cd "$(dirname "$0")" && pwd)"; R="${EL_BETIK:-$HERE/el-defteri.sh}"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null; find "$HERE" -maxdepth 1 -name ".mutant-el-$$-*" -delete 2>/dev/null' EXIT
G=0; K=0
ok() { if [ "$2" -eq 0 ]; then G=$((G+1)); echo "  ✓ $1"; else K=$((K+1)); echo "  ✗ $1 ${3:-}"; fi; }

SIMDI=1793264400   # 2026-10-29 09:00 UTC → gün 2026-10-29
mkdir -p "$T/depo/_agents/bani" "$T/bin"
cat > "$T/depo/_agents/bani/NOTES.md" <<'EOF'
# BÂNİ defteri

## ÇIPA 2026-10-28
- [BÂNİ 28 Eki 17:12] eski not 1
- [BÂNİ 28 Eki 17:30] ⚓ KONUM eski: #1 bekliyor

## ÇIPA 2026-10-29
- [BÂNİ 29 Eki 08:00] not a
- [BÂNİ 29 Eki 08:10] ⚓ KONUM 29 Eki: iş duzen, PR yok, sıradaki sınav
- [BÂNİ 29 Eki 08:20] not c
- [BÂNİ 29 Eki 08:30] not d
EOF
cat > "$T/bin/gorev.sh" <<'EOF'
#!/bin/sh
[ "$1" = liste ] || exit 1
printf 'gorev_1  code  acik   -  -  BÂNİ   iş bir\n'
printf 'gorev_2  code  iptal  -  -  BÂNİ   iptal iş\n'
printf 'gorev_3  code  bitti  -  -  BÂNİ   biten iş\n'
printf 'gorev_4  code  acik   -  -  SERDAR başkasının işi\n'
printf 'gorev_5  code  calisiliyor - - BÂNİ   iş beş\n'
printf 'gorev_6  code  acik   -  -  BÂNİCİK alt dize tuzağı\n'
EOF
chmod +x "$T/bin/gorev.sh"
kos() { DUZEN_SIMDI=$SIMDI DUZEN_GOREV_SH="$T/bin/gorev.sh" bash "$R" --depo "$T/depo" "$@"; }

kos --ajan YOKTUR >"$T/o1" 2>"$T/e1"; rc=$?; ok "E1 defter yoksa rc 3 + 'el defteri yok' (uydurmaz)" "$([ $rc -eq 3 ] && grep -q 'el defteri yok' "$T/e1" && [ ! -s "$T/o1" ] && echo 0 || echo 1)" "→ rc=$rc $(head -c120 "$T/e1")"
O="$(kos --ajan BÂNİ)"; rc=$?
ok "E2 bugünkü ÇIPA bulunur (rc 0)" "$([ $rc -eq 0 ] && grep -q '## ÇIPA 2026-10-29 (defterde var)' <<<"$O" && echo 0 || echo 1)" "→ rc=$rc"
KB="$(sed -n '/^## Son KONUM/,/^## Son [0-9]/p' <<<"$O")"
ok "E3 son KONUM bölümünde en yeni KONUM var, eskisi yok" "$(grep -q 'KONUM 29 Eki: iş duzen' <<<"$KB" && ! grep -q 'KONUM eski' <<<"$KB" && echo 0 || echo 1)"
O3="$(kos --ajan BÂNİ --n 2)"
ok "E4 --n 2 son iki satır (not c, not d) gelir; not a gelmez" "$(grep -q 'not c' <<<"$O3" && grep -q 'not d' <<<"$O3" && ! grep -q 'not a' <<<"$O3" && echo 0 || echo 1)"
ok "E5 açık işler: BÂNİ'nin acik+calisiliyor satırları; iptal/bitti, SERDAR ve alt dize (BÂNİCİK) yok" "$(grep -q 'iş bir' <<<"$O" && grep -q 'iş beş' <<<"$O" && ! grep -q 'iptal iş' <<<"$O" && ! grep -q 'biten iş' <<<"$O" && ! grep -q 'başkasının' <<<"$O" && ! grep -q 'alt dize' <<<"$O" && echo 0 || echo 1)"
O6="$(DUZEN_SIMDI=$SIMDI DUZEN_GOREV_SH="$T/yok/gorev.sh" bash "$R" --depo "$T/depo" --ajan BÂNİ)"; rc=$?
ok "E6 gorev.sh yoksa 'ölçülemedi' yazar, rc 0 (defter yine basılır)" "$([ $rc -eq 0 ] && grep -q 'ölçülemedi' <<<"$O6" && grep -q 'not d' <<<"$O6" && echo 0 || echo 1)" "→ rc=$rc"
S=$(wc -l <<<"$O"); ok "E7 çıktı tavanı ≤45 satır (ölçülen $S)" "$([ "$S" -le 45 ] && echo 0 || echo 1)"

if [ -z "${EL_BETIK:-}" ]; then
  echo "── mutasyon"
  mut() { local M="$HERE/.mutant-el-$$-$1"; python3 -I - "$R" "$M" "$2" "$3" <<'PY' || { ok "mutant $1: desen tutmadı" 1; return; }
import sys; s=open(sys.argv[1],encoding='utf-8').read(); o=s; s=s.replace(sys.argv[3],sys.argv[4]); assert s!=o; open(sys.argv[2],'w',encoding='utf-8').write(s)
PY
    local o; o="$(EL_BETIK="$M" bash "$0" 2>&1)"; ok "mutant '$1' → $4 kırmızı" "$(grep -q "✗ $4 " <<<"$o" && echo 0 || echo 1)" "→ $(grep -E '✗' <<<"$o" | head -2)"; }
  mut defter-yok-yesil 'uydurulmadı)" >&2; exit 3; }' 'uydurulmadı)" >&2; exit 0; }' E1
  mut iptal-elenmez "grep -Ev '\\b(iptal|bitti)\\b' | " "" E5
fi
echo "== $G geçti · $K düştü =="; [ "$K" -eq 0 ]
