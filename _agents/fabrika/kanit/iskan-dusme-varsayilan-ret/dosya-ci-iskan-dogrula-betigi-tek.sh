#!/usr/bin/env bash
# ci-iskan-dogrula.sh — temiz CI makinesinde iskan.test.sh sonucu (ikinci yüzey): kutudaki tek kırmızı
# (baslat-claude) bu PR'ın değil kutunun ortamının mı? CI günlüğünü indirir, iskan bölümünü ayıklar.
# rc=0: iskan.test.sh CI'da ✓ ve "0 kaldı" · rc=1: değil · rc=3: günlük okunamadı.
set -u
RUN="$1"; REPO=sultanxgokce/Sx-Claude-Skills
log="$(gh run view "$RUN" --repo "$REPO" --log 2>/dev/null)" || { echo "günlük okunamadı"; exit 3; }
sha="$(gh run view "$RUN" --repo "$REPO" --json headSha --jq .headSha)"
bolum="$(awk '/── \.\/iskan\/scripts\/iskan\.test\.sh/{f=1} f{print} f&&/(✓|KIRMIZI).*iskan\/scripts\/iskan\.test\.sh/{exit}' <<<"$log" | sed 's/^.*Z //')"
ozet="$(grep -E '== [0-9]+ geçti / [0-9]+ kaldı ==' <<<"$bolum")"
echo "koşu=$RUN · commit=$sha"
echo "iskan özet: $ozet"
grep -E '^ *FAIL' <<<"$bolum" || echo "iskan FAIL satırı: yok"
grep -E 'baslat-claude' <<<"$bolum" | head -3
son="$(tail -1 <<<"$bolum")"; echo "sonuç satırı: $son"
grep -q '✓ ./iskan/scripts/iskan.test.sh' <<<"$son" && grep -q '/ 0 kaldı' <<<"$ozet" && { echo "── HÜKÜM: CI'da iskan.test.sh YEŞİL"; exit 0; }
echo "── HÜKÜM: CI'da iskan.test.sh yeşil DEĞİL"; exit 1
