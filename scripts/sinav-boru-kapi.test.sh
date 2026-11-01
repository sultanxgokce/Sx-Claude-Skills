#!/usr/bin/env bash
# sinav-boru-kapi.test.sh — kapı kalıbı bulur, yazım biçimlerini çevirir, heredoc gövdesine dokunmaz, davranışı korur. "N geçti · M kaldı".
set -uo pipefail
B="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; T="$(mktemp -d)"; temizle() { find "$T" -type f -delete 2>/dev/null; find "$T" -depth -type d -empty -delete 2>/dev/null; }; trap temizle EXIT
G=0; K=0; g() { if [ "$1" -eq 0 ]; then G=$((G+1)); echo "  ✓ $2"; else K=$((K+1)); echo "  ✗ $2"; fi; }
cd "$T"; git init -q .
cat > a.test.sh <<'SH'
set -uo pipefail
yaz() { echo bulundu; sleep 0.2; echo sonraki; }
yaz | grep -q bulundu && echo EVET1
yaz | grep -qF "bulundu" && echo EVET2
yaz | grep --quiet 'bulundu' && echo EVET3
yaz | grep -E -q "bul|yok" \
  && echo EVET4
yaz | grep -q yokboyle || echo HAYIR5
n="$(yaz | grep -c q || true)"; [ "$n" -eq 0 ] && echo SAYAC6
bash -c "set -o pipefail; echo bulundu | grep -q 'bulundu'" && echo DIS7
SH
cat > b.test.sh <<'SH'
yaz | grep -q bulundu
SH
cat > c.test.sh <<'SH'
set -o pipefail
cat <<'E'
yaz | grep -q heredoc-icinde
E
SH
cp c.test.sh c.once; git add .; python3 "$B/sinav-boru-kapi.py" > k.txt; [ $? -eq 1 ]; g $? "S1 kalıp varken rc 1"
[ "$(grep -c '^a.test.sh:' k.txt)" -eq 6 ]; g $? "S2 altı satırın altısı bulunur, sayaç (-c) sayılmaz"
! grep -q '^b.test.sh' k.txt; g $? "S3 pipefail açmayan dosyaya bakılmaz"
! grep -q '^c.test.sh' k.txt; g $? "S4 heredoc gövdesi sayılmaz"
python3 "$B/sinav-boru-kapi.py" --yaz > /dev/null; [ $? -eq 0 ]; g $? "S5 --yaz sonrası rc 0"
bash -n a.test.sh; g $? "S6 çevrilen dosya sözdizimi sağlam"
O="$(bash a.test.sh 2>&1)"; [ "$(printf '%s\n' "$O" | tr '\n' ' ')" = "EVET1 EVET2 EVET3 EVET4 HAYIR5 SAYAC6 DIS7 " ]; g $? "S7 çevrilen dosya aynı sonucu verir, çıktı sızmaz: $O"
! grep -q -- '-q' a.test.sh || ! grep -E '\| *grep.* -q' a.test.sh > /dev/null; g $? "S8 sessiz bayrak kalmadı"
cmp -s c.test.sh c.once; g $? "S9 heredoc gövdesi değişmedi"
echo "sinav-boru-kapi.test: $G geçti · $K kaldı"; [ $K -eq 0 ]
