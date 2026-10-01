#!/usr/bin/env bash
# canli-sayfa 1.1.0 kuralının AYRI AYRI iddiaları + kuralı uygulayan kokpit koduyla (Nexus #1100) çapraz eşleşme
set -uo pipefail
K=/config/projects/_wt/Sx-Claude-Skills-canli-sayfa-kokpit-kurali/canli-sayfa/SKILL.md
J=/config/projects/_wt/Nexus-kokpit-sayfa-ici/_agents/handoff/kokpit-prototip/kokpit.js
kalan=0
iddia(){ if eval "$2" >/dev/null 2>&1; then echo "✓ $1"; else echo "✗ $1"; kalan=$((kalan+1)); fi; }
iddia "I1 sürüm 1.1.0" "grep -qE '^version: 1\.1\.0$' $K"
iddia "I2 tetik: Sultan canlı UI/sayfa istediğinde (açıklamada)" "sed -n '1,15p' $K | grep -q 'CANLI bir UI'"
iddia "I3 yayın/erişim yeri kokpit Canlı sayfalar menüsü" "grep -q 'kokpit.mmepanel.com/#/sayfalar' $K"
iddia "I4 *.mmepanel.com satırı → kokpitin içinde" "grep -E '^\| \`\*\.mmepanel\.com\`' $K | grep -q 'kokpitin içinde'"
iddia "I5 *.mukarnas.net ve başka alan → ayrı sekme" "grep -E '^\| \`\*\.mukarnas\.net\`' $K | grep -q 'ayrı sekmede'"
iddia "I6 sunucu yükümlülüğü: X-Frame-Options yasak, frame-ancestors kokpit" "grep -E '^\| \`\*\.mmepanel\.com\`' $K | grep -q 'X-Frame-Options' && grep -q \"frame-ancestors 'self' https://kokpit.mmepanel.com\" $K"
iddia "I7 bayat durum notu (1.0.0 menü yok) kalktı" "! grep -q 'Durum (sürüm 1.0.0)' $K"
iddia "I8 Sultan'ın 1 Eki sözü verbatim kırpık" "grep -q 'Eğer domain' $K && grep -q 'ayrı sekmede açılabilir' $K"
iddia "X1 kokpit kodu aynı kuralı uygular: mmepanel.com → içeride" "grep -q \"k.endsWith('.mmepanel.com')\" $J"
iddia "X2 kokpit kodu: kokpitin kendisi gömülmez" "grep -q \"k!=='kokpit.mmepanel.com'\" $J"
iddia "X3 kokpit kodu: başka alan target=_blank" "grep -q 'target=\"_blank\" rel=\"noopener noreferrer\" aria-label=\"\${h(x.ad)} sayfasını aç (ayrı sekmede)\"' $J"
echo "SONUÇ: $((11-kalan)) geçti · $kalan kaldı"; exit $kalan
