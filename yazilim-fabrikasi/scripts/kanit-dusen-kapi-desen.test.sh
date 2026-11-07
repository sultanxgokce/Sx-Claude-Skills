#!/usr/bin/env bash
# kanit-dusen-kapi-desen.test.sh — kanit.py DUSEN_KAPI_RE kabuk + pytest + node + vitest düşüşünü tanır (görev …JVTZZ1)
# KUR=<kanit.py yolu> ile başka bir kopya sınanabilir (mutasyon ölçümü için).
D="$(cd "$(dirname "$0")" && pwd)"; KANIT="${KANIT:-$D/kanit.py}"; G=0; K=0
_ok(){ G=$((G+1)); echo "  ✓ $1"; }; _kal(){ K=$((K+1)); echo "  ✗ $1"; }
_dene() { # _dene <ad> <1=yakalanmalı|0=yakalanmamalı> <satır>
  local r; r=$(KANIT="$KANIT" LINE="$3" python3 -I - <<'PY'
import os, importlib.util
sp = importlib.util.spec_from_file_location("kanit", os.environ["KANIT"]); m = importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
print(1 if m.DUSEN_KAPI_RE.search(os.environ["LINE"]) else 0)
PY
)
  [ "$r" = "$2" ] && _ok "$1 (=$r)" || _kal "$1 (beklenen $2, çıkan $r)"; }
echo "════ düşen kapı deseni: kabuk, pytest, node, vitest ════"
_dene "D1 kabuk '✗ H1 ...'"            1 "  ✗ H1 hedef kapı düştü"
_dene "D2 kabuk 'FAIL H1'"              1 "FAIL  H1 hedef türü görev"
_dene "D3 pytest 'FAILED t.py::a'"      1 "FAILED t.py::test_a - AssertionError"
_dene "D4 pytest '1 failed, 3 passed'"  1 "=== 1 failed, 3 passed in 0.12s ==="
_dene "D5 node 'not ok 1'"              1 "not ok 1 - kapı düştü"
_dene "D6 node '✖ ad'"                  1 "✖ kapı adı (3.2ms)"
_dene "D7 vitest '× ad'"                1 "   × kapı adı 4ms"
_dene "D8 'KALAN: 2' kabuk"             1 "KALAN: 2"
_dene "D9 'N kaldı' kabuk"              1 "── SONUÇ: 58 geçti · 3 kaldı ──"
echo "── yanlış pozitif yok (geçen çıktı yakalanmamalı) ──"
_dene "N1 pytest '3 passed'"            0 "=== 3 passed in 0.12s ==="
_dene "N2 pytest '0 failed'"            0 "=== 0 failed, 3 passed ==="
_dene "N3 node 'ok 1'"                  0 "ok 1 - kapı geçti"
_dene "N4 vitest '✓ ad'"                0 "   ✓ kapı adı 4ms"
_dene "N5 kabuk '0 kaldı'"              0 "── SONUÇ: 58 geçti · 0 kaldı ──"
_dene "N6 düz ad 'ok'"                  0 "H1 hedef türü görev hedef okuma"
_dene "N7 'failedsafe' alt dize"        0 "failedsafe etkin"
echo; echo "SONUÇ: $G geçti · $K kaldı"; [ "$K" = 0 ]
