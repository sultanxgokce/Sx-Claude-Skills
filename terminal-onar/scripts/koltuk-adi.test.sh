#!/usr/bin/env bash
# koltuk-adi.test.sh — koltuk adı kuralı İKİ DİLDE TEK: kabuk (koltuk-adi.sh) ⟷ kapı (sunucu.mjs KOLTUK_AD_DESEN) aynı derleme aynı
# hükmü verir · gerçek tmux: kuralın KABUL ettiği her ad gerçekten bir oturum adı olabilir ve '=ad' ile tam eşleşir (ayrı soket,
# canlı oturumlara dokunmaz) · kuralın reddettikleri gerekçeli (boşluk tercih, '.'/':' tmux dönüştürür, '$@%=' önek kimlik).
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; g=0; k=0
kapi(){ if [ "$2" = "$3" ]; then g=$((g+1)); echo "  ✓ $1"; else k=$((k+1)); echo "  ✗ $1 → beklenen [$2] olan [$3]"; fi; }
. "$D/koltuk-adi.sh"
U200="$(printf 'a%.0s' $(seq 1 200))"; U201="${U200}a"
E200="$(printf '😀%.0s' $(seq 1 200))"; E201="${E200}😀"   # astral: JS'te 2 kod birimi, 1 kod noktası
DERLEM=( '2026/85' 'serdar' 'muavin-2' 'a_b' 'ş-ğ' '<img/src=x/onerror=alert(7)>' "o'reilly" 'x"y' '-bas' '/kok' "$U200" 'a b' '😀x' "$E200"
         'a.b' 'a:b' '$1' '@x' '%y' '=z' '' "$U201" "$E201" ' bas' 'son ' $'a\tb' )
BEK=(     1 1 1 1 1 1 1 1 1 1 1 1 1 1   0 0 0 0 0 0 0 0 0 0 0 0 )
# Kapı kuralı artık modülden İÇE ALINIR (metinden ayıklanmaz): sunucu.mjs ve fark ölçeri aynı modülü kullanır.
R="$(cd "$D/../kapi" && node --input-type=module -e '
import { KOLTUK_AD_DESEN as re } from "./koltuklar.mjs";
const a=JSON.parse(process.argv[1]); console.log(a.map(x=>re.test(x)?1:0).join(""))' "$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1:]))' "${DERLEM[@]}")" 2>&1)"
grep -q "from './koltuklar.mjs'" "$D/../kapi/sunucu.mjs" && ! grep -q '^const KOLTUK_AD_DESEN' "$D/../kapi/sunucu.mjs"
kapi "K0 kapı ad kuralını modülden alır (ikinci kopya yok)" "0" "$?"
B=""; for x in "${DERLEM[@]}"; do koltuk_adi_gecerli "$x" && B="${B}1" || B="${B}0"; done
E="$(printf '%s' "${BEK[@]}")"
kapi "K1 kabuk kuralı beklenen hükmü verir (${#DERLEM[@]} ad)" "$E" "$B"
kapi "K2 kapı (koltuklar.mjs KOLTUK_AD_DESEN) kabukla AYNI hükmü verir" "$B" "$R"
S="kadi-sinav-$$"; t=0; f=""
for i in "${!DERLEM[@]}"; do [ "${BEK[$i]}" = 1 ] || continue; n="${DERLEM[$i]}"
  if tmux -L "$S" new-session -d -s "$n" 2>/dev/null && tmux -L "$S" has-session -t "=$n" 2>/dev/null \
     && [ "$(tmux -L "$S" display-message -p -t "=$n:" '#{session_name}' 2>/dev/null)" = "$n" ]; then t=$((t+1)); else f="$f [$n]"; fi
done
tmux -L "$S" kill-server 2>/dev/null
kapi "K3 GERÇEK tmux: kuralın kabul ettiği her ad oturum olur ve '=ad' ile kendisine çözülür${f:+ (düşen:$f)}" "14" "$t"
BC=""; for x in "${DERLEM[@]}"; do ( export LC_ALL=C; koltuk_adi_gecerli "$x" ) && BC="${BC}1" || BC="${BC}0"; done
kapi "K4 çağıranın yerel ayarı C olsa da (cron/ttyd) kabuk aynı hükmü verir — bayt değil karakter sayar" "$B" "$BC"
echo; echo "GEÇEN: $g · KALAN: $k"; [ "$k" = 0 ]
