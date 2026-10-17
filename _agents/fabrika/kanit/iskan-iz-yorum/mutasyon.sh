#!/usr/bin/env bash
set -u
W=/config/projects/_wt/Sx-Claude-Skills-iskan-iz-yorum/iskan/scripts
M="$(mktemp -d)"; gecen=0; dusen=0
dene() { local ad="$1" ifade="$2" kapi="$3"; mkdir -p "$M/k"; cp "$W"/iskan.sh "$M/k/"; sed -i "$ifade" "$M/k/iskan.sh"
  cmp -s "$W/iskan.sh" "$M/k/iskan.sh" && { echo "  ✗ $ad — mutasyon UYGULANAMADI"; dusen=$((dusen+1)); return; }
  { echo 'PASS=0; FAIL=0; ok() { PASS=$((PASS+1)); echo "  ok - $1"; }; bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1"; }'; echo "SCRIPT_DIR=$M/k"; sed -n '/^# ── İZ-YORUM/,/^find "\$IZY"/p' "$W/iskan.test.sh"; echo '[ "$FAIL" -eq 0 ]'; } > "$M/t.sh"
  out="$(bash "$M/t.sh" 2>&1)"; rc=$?
  if [ $rc != 0 ] && printf '%s\n' "$out" | grep -q "FAIL - $kapi"; then echo "  ✓ $ad — kapı ölünce sınav KIRMIZI ($kapi)"; gecen=$((gecen+1)); else echo "  ✗ $ad — sınav YEŞİL kaldı ya da $kapi düşmedi (rc=$rc)"; printf '%s\n' "$out" | grep FAIL | head -3; dusen=$((dusen+1)); fi; }
dene "M1 yorum ayıklama kaldırıldı (eski grep -ci davranışı)"            's/sed -E .s\/\^\[\[:space:\]\]\*#\.\*\$\/\/; s\/\[\[:space:\]\]+#\.\*\$\/\/. "\$f" 2>\/dev\/null | grep -ci -- "\$proje"/grep -ci -- "$proje" "$f" 2>\/dev\/null/' "İZ-YORUM-1"
dene "M2 yalnız tam yorum satırı atılır, satır-sonu yorumu sayılır"       's/; s\/\[\[:space:\]\]+#\.\*\$\/\///' "İZ-YORUM-1"
dene "M3 satır-sonu yorumu '#'tan İTİBAREN değil tüm satır atılır (etkin iz gizlenir)" 's/s\/\[\[:space:\]\]+#\.\*\$\/\//s\/.*#.*$\/\//' "İZ-YORUM-3"
dene "M4 harf duyarlı sayım (S02 ≠ s02)"                                  's/grep -ci -- "\$proje"/grep -c -- "$proje"/' "İZ-YORUM-4"
rm -r -f -- "$M"
echo "mutasyon: geçen=$gecen düşen=$dusen"; [ $dusen = 0 ]
