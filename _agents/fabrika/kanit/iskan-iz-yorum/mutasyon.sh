#!/usr/bin/env bash
# iskan-iz-yorum mutasyon kanıtı: iskan.sh KOPYASINDA _iskan_etkin_iz bozulur, İZ-YORUM bloğu kopyadan koşar → KIRMIZI olmalı
set -u
W=/config/projects/_wt/Sx-Claude-Skills-iskan-iz-yorum/iskan/scripts
M="$(mktemp -d)"; gecen=0; dusen=0
dene() { local ad="$1" kod="$2" kapi="$3"; mkdir -p "$M/k"; cp "$W"/iskan.sh "$M/k/"
  python3 - "$M/k/iskan.sh" <<PY
import sys; p=sys.argv[1]; s=open(p,encoding='utf-8').read(); o=s
$kod
assert s!=o, 'desen tutmadı'
open(p,'w',encoding='utf-8').write(s)
PY
  [ $? = 0 ] || { echo "  ✗ $ad — mutasyon UYGULANAMADI"; dusen=$((dusen+1)); return; }
  { echo 'PASS=0; FAIL=0; ok() { PASS=$((PASS+1)); echo "  ok - $1"; }; bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1"; }'; echo "SCRIPT_DIR=$M/k"; sed -n '/^# ── İZ-YORUM/,/^find "\$IZY"/p' "$W/iskan.test.sh"; echo '[ "$FAIL" -eq 0 ]'; } > "$M/t.sh"
  out="$(bash "$M/t.sh" 2>&1)"; rc=$?
  if [ $rc != 0 ] && printf '%s\n' "$out" | grep -q "FAIL - $kapi"; then echo "  ✓ $ad — kapı ölünce sınav KIRMIZI ($kapi)"; gecen=$((gecen+1)); else echo "  ✗ $ad — sınav YEŞİL kaldı ya da $kapi düşmedi (rc=$rc)"; printf '%s\n' "$out" | grep FAIL | head -3; dusen=$((dusen+1)); fi; }
dene "M1 yorum hiç ayıklanmaz (break kaldırıldı = eski grep -ci davranışı)"  "s=s.replace('substr(\$0,i-1,1) ~ /[[:space:]]/)) break', 'substr(\$0,i-1,1) ~ /[[:space:]]/)) {}')" "İZ-YORUM-1"
dene "M2 yalnız satır başı yorum atılır, satır-sonu yorumu sayılır"          "s=s.replace('(i==1 || substr(\$0,i-1,1) ~ /[[:space:]]/)', '(i==1)')" "İZ-YORUM-1"
dene "M3 tırnak izlenmez (tırnak içindeki # yorum sanılır)"                  "s=s.replace('{ q=c; t=t c; continue }', '{ t=t c; continue }')" "İZ-YORUM-7"
dene "M4 harf duyarlı sayım (S02 ≠ s02)"                                      "s=s.replace('grep -ci -- \"\$proje\"', 'grep -c -- \"\$proje\"')" "İZ-YORUM-4"
dene "M5 '#' her yerde yorum başlatır (boşluk şartı yok: a#s02 kesilir — etkin iz gizlenir)" "s=s.replace('if (c==\"#\" && (i==1 || substr(\$0,i-1,1) ~ /[[:space:]]/)) break', 'if (c==\"#\") break')" "İZ-YORUM-7"
rm -r -f -- "$M"
echo "mutasyon: geçen=$gecen düşen=$dusen"; [ $dusen = 0 ]
