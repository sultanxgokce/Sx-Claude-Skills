#!/usr/bin/env bash
# sinav-cocuk.test.sh — sinav-cocuk.mjs: sınav hangi yolla biterse bitsin açtığı süreç kapanır.
#   C-normal çıkış · C-hata yakalanmamış hata · C-sinyal TERM (zaman aşımı); her birinde alt süreç de kapanır (süreç grubu)
#   Mutant M1: kapatma devre dışı (SINAV_COCUK_KAPATMA=0) → çocuk açık kalır. Çocuk: işaretli `sleep`.
# kabuk-testleri: sure=120
set -uo pipefail
IS="sinav-cocuk-isaret-$$"
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'sonlandir; python3 -I -c "import shutil,sys;shutil.rmtree(sys.argv[1],ignore_errors=True)" "$T"; true' EXIT
G=0; K=0
sonlandir() { pkill -f "# $IS" 2>/dev/null; for f in "$T"/*.pid; do [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null; rm -f "$f"; done; for f in "$T"/*.dir; do [ -f "$f" ] && python3 -I -c "import shutil,sys;shutil.rmtree(sys.argv[1],ignore_errors=True)" "$(cat "$f")"; done; true; }
g() { if [ "$1" -eq 0 ]; then G=$((G+1)); echo "  ✓ $2"; else K=$((K+1)); echo "  ✗ $2"; fi; }
# canlı sayısı: işaretli bash + onun başlattığı sleep (pid dosyasından, kill -0)
sayi() { local n=0 p; n=$(pgrep -fc "# $IS" 2>/dev/null || true); [ -n "$n" ] || n=0
  for f in "$T"/*.pid; do [ -f "$f" ] || continue; p="$(cat "$f")"; kill -0 "$p" 2>/dev/null && n=$((n+1)); done
  for f in "$T"/*.dir; do [ -f "$f" ] || continue; [ -d "$(cat "$f")" ] && n=$((n+1)); done; echo "$n"; }

# senaryo <ad> <js gövdesi>: çocuk aç, gövdeyi koş, sonra çocuk sayısını yaz
kos() {
  cat >"$T/$1.mjs" <<EOF
import { cocukBaslat, gecici } from '$HERE/sinav-cocuk.mjs';
import { writeFileSync } from 'fs';
const c = cocukBaslat('bash', ['-c', 'sleep 300 & echo \$! > $T/$1.pid; wait # $IS'], { stdio: 'ignore' });
writeFileSync('$T/$1.dir', gecici('sinav-cocuk-dizin-'));
await new Promise((r) => setTimeout(r, 600));
$2
EOF
  node "$T/$1.mjs" >/dev/null 2>&1; echo $?
}
bekle0() { for _ in $(seq 1 20); do [ "$(sayi)" = 0 ] && return 0; sleep 0.2; done; return 1; }

for kip in normal hata sinyal; do
  case $kip in
    normal) js='process.exit(0);';;
    hata)   js='throw new Error("sınav ortasında çöktü");';;
    sinyal) js='process.kill(process.pid, "SIGTERM"); await new Promise((r) => setTimeout(r, 2000));';;
  esac
  kos "$kip" "$js" >/dev/null
  bekle0; g $? "C-$kip: çıkıştan sonra çocuk, alt süreci ve geçici dizin KALMADI"
  sonlandir
done

echo "── mutant M1: kapatma devre dışı → çocuk kalmalı (yani sınav bunu YAKALAR)"
export SINAV_COCUK_KAPATMA=0; kos mut 'process.exit(0);' >/dev/null; unset SINAV_COCUK_KAPATMA; echo "  (mutant sonrası çocuk: $(sayi))"
if bekle0; then g 1 "M1 yakalanmadı: kapatma kapalıyken de çocuk kalmadı (sınav körü körüne yeşil)"; else g 0 "M1 yakalandı: kapatma kapalıyken çocuk ve dizin açık kaldı"; fi
sonlandir

echo "SONUÇ: geçti=$G kaldı=$K"
[ "$K" -eq 0 ]
