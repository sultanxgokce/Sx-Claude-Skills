#!/usr/bin/env bash
# sifre-yukle.test.sh — ortam dosyası SOURCE edilmez: bozuk satır komut gibi koşmaz, değer parçası basılmaz, AD=değer yüklenir.
# Hermetik: geçici dosya; gerçek ortam dosyasına ve kasaya dokunmaz. Mutasyon: eski `. dosya` yolu E3/E4'ü kırmızıya döndürür.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$(mktemp -d)"; trap 'rm -r -- "$T"' EXIT
g=0; k=0; ok(){ if eval "$2"; then g=$((g+1)); echo "  ✓ $1"; else k=$((k+1)); echo "  ✗ $1"; fi; }
cat > "$T/env" <<EOV
# yorum satırı
export DENEME__TERMINAL_SIFRE="gizli deger 123"
TEK_TIRNAK='a=b'
touch $T/KOMUT-KOSTU
iSxHPMLVPabIEtptSO9+Y5PUAABeC7paNmOy+DL8AbmOGr1xDSLs5+YgilxtHPOk
token_type: Bearer
BOS=
EOV
out="$(TO_KUTU=deneme CORTEX_ACCESS_ENV="$T/env" bash -c '
  . "'"$HERE"'/ortak.sh" >/dev/null 2>&1
  ortam_yukle "$ENV_DOSYA"; r=$?
  echo "rc=$r bozuk=$ORTAM_BOZUK_SATIR sifre_uzunluk=${#DENEME__TERMINAL_SIFRE} tek=$TEK_TIRNAK bos=[${BOS-yok}] sifre_var=$(sifre_var_mi && echo 1 || echo 0)"' 2>"$T/err")"
echo "     $out"
ok "E1 AD=değer satırları yüklendi (tırnak soyuldu, export öneki kabul)" '[[ "$out" == *"sifre_uzunluk=15"* && "$out" == *"tek=a=b"* && "$out" == *"bos=[]"* ]]'
ok "E2 parola anahtarı kutu adından türedi ve doldu (sifre_var_mi=1)" '[[ "$out" == *"sifre_var=1"* ]]'
ok "E3 bozuk satır KOMUT gibi KOŞMADI (touch işareti yok)" '[ ! -e "$T/KOMUT-KOSTU" ]'
ok "E4 stderr'e değer parçası/command-not-found düşmedi" '! grep -q "command not found\|iSxHPM" "$T/err"'
ok "E5 bozuk satırlar SAYILDI (3: touch · çıplak değer · token_type), içerik basılmadı" '[[ "$out" == *"bozuk=3"* ]] && ! grep -q "iSxHPM" <<<"$out"'
ok "E6 dosya yoksa rc=1, ortam dokunulmadı" 'TO_KUTU=deneme CORTEX_ACCESS_ENV="$T/yok" bash -c ". \"$HERE/ortak.sh\" >/dev/null 2>&1; ortam_yukle \"\$ENV_DOSYA\"; test \$? -eq 1"'
echo "sifre-yukle.test: $g geçti · $k kaldı"; [ $k -eq 0 ]
