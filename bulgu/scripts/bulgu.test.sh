#!/usr/bin/env bash
# bulgu.test.sh — hermetik: sahte defter yazıcısı (argv'yi kaydeder); gerçek deftere dokunmaz.
# Kapılar: hal komutu doğru argümanla yazıcıya gider · onaylandi reddedilir (A06) · kötü numara/hâl/eksik alan rc 2 · defter yoksa rc 3.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; T="$(mktemp -d)"; trap 'rm -r -- "$T"' EXIT
mkdir -p "$T/kok/bulgu-defteri"; printf '#!/usr/bin/env python3\nimport sys; print("ARGV:" + "|".join(sys.argv[1:]))\n' > "$T/kok/defter-yaz.py"
echo '{"bulgular":[],"sonSayi":0}' > "$T/kok/bulgu-defteri/bulgular.json"
g=0; k=0; ok(){ if eval "$2"; then g=$((g+1)); echo "  ✓ $1"; else k=$((k+1)); echo "  ✗ $1"; fi; }
B="$HERE/bulgu.sh"
o=$(BULGU_KOK="$T/kok" bash "$B" hal S-12 uygulandi --kim MUAVİN --gerekce "PR #1 birleşti" 2>&1); r=$?
ok "H1 hal: yazıcıya 'hal S-12 --hal uygulandi --gerekce … --kim MUAVİN --kok' gider, rc 0" '[ $r -eq 0 ] && [[ "$o" == "ARGV:hal|S-12|--hal|uygulandi|--gerekce|PR #1 birleşti|--kim|MUAVİN|--kok|"* ]]'
o=$(BULGU_KOK="$T/kok" bash "$B" hal S-12 onaylandi --kim MUAVİN --gerekce x 2>&1); r=$?
ok "H2 🔴 'onaylandi' ajan tarafından yazılamaz (A06): rc 2, yazıcı ÇAĞRILMADI" '[ $r -eq 2 ] && [[ "$o" != *ARGV* ]] && [[ "$o" == *A06* ]]'
o=$(BULGU_KOK="$T/kok" bash "$B" hal 12 canli --kim X --gerekce y 2>&1); r=$?
ok "H3 numara S-N değilse rc 2" '[ $r -eq 2 ] && [[ "$o" != *ARGV* ]]'
o=$(BULGU_KOK="$T/kok" bash "$B" hal S-1 bitti --kim X --gerekce y 2>&1); r=$?
ok "H4 bilinmeyen hâl rc 2" '[ $r -eq 2 ]'
o=$(BULGU_KOK="$T/kok" bash "$B" hal S-1 canli --gerekce y 2>&1); r=$?
ok "H5 --kim eksik rc 2" '[ $r -eq 2 ] && [[ "$o" == *"--kim zorunlu"* ]]'
o=$(BULGU_KOK="$T/kok" bash "$B" hal S-1 canli --kim X 2>&1); r=$?
ok "H6 --gerekce eksik rc 2" '[ $r -eq 2 ] && [[ "$o" == *"--gerekce zorunlu"* ]]'
o=$(BULGU_KOK="$T/yok" bash "$B" hal S-1 canli --kim X --gerekce y 2>&1); r=$?
ok "H7 defter kurulu değilse rc 3, hiçbir şey yazılmaz" '[ $r -eq 3 ]'
o=$(BULGU_KOK="$T/kok" bash "$B" yaz "deneme başlık" --kim X 2>&1); r=$?
ok "H8 eski 'yaz' yolu değişmedi (yazıcıya 'yeni --baslik … --kim X --kok')" '[ $r -eq 0 ] && [[ "$o" == "ARGV:yeni|--baslik|deneme başlık|--kim|X|--kok|"* ]]'
echo "bulgu.test: $g geçti · $k kaldı"; [ $k -eq 0 ]
