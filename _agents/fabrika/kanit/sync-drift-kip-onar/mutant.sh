#!/usr/bin/env bash
# mutant.sh <ad>: sync-skills.mjs'in geçici kopyasını bozar, sınavı ona karşı koşar. rc 1 yalnız beklenen kapı kırmızıysa.
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"; M="$(mktemp -d)"
cp "$KOK/sync-skills.mjs" "$KOK/sync-skills.test.sh" "$M/"
case "$1" in
  icerik-dali) kapi='S1 icerik' ;;
  yeni-dali)   kapi='S1 yeni' ;;
  kuru-yazar)  kapi='S5 icerik' ;;
  sessiz)      kapi='S4 icerik' ;;
  uyari-yok)   kapi='S3 icerik' ;;
  *) echo "bilinmeyen mutant: $1"; exit 2 ;;
esac
python3 - "$M/sync-skills.mjs" "$1" <<'ESAS'
import sys
p, ad = sys.argv[1:3]; s = open(p, encoding='utf-8').read()
c = 'else { warned++; if (APPLY) sapmisKipOnar(srcDir, dstDir, label); }'
i = s.index(c); j = s.index(c, i + 1)
if ad == 'icerik-dali': s = s[:i] + 'else warned++;' + s[i + len(c):]
elif ad == 'yeni-dali': s = s[:j] + 'else warned++;' + s[j + len(c):]
elif ad == 'kuru-yazar': s = s.replace('if (APPLY) sapmisKipOnar', 'sapmisKipOnar')
elif ad == 'sessiz': s = s.replace('if (onarildi) console.log(`     ⟳', 'if (false) console.log(`     ⟳')
elif ad == 'uyari-yok': s = s[:i] + 'else { if (APPLY) sapmisKipOnar(srcDir, dstDir, label); }' + s[i + len(c):]
open(p, 'w', encoding='utf-8').write(s)
ESAS
cmp -s "$KOK/sync-skills.mjs" "$M/sync-skills.mjs" && { echo "mutant uygulanamadı"; exit 2; }
SUT_DIS="$M/sync-skills.mjs" bash "$M/sync-skills.test.sh" > "$M/out" 2>&1
grep -E '✗|geçti ·' "$M/out"
if grep -q "✗ $kapi" "$M/out"; then echo "YAKALANDI: $kapi"; exit 1; fi
echo "KAÇTI: $kapi"; exit 0
