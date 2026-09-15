#!/usr/bin/env bash
# link-coz sınavı — AĞSIZ. Şablon çözümü, kutuya-özel öncelik ve "uydurma yok" sözleşmesi.
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=0; K=0
kapi(){ if [ "$2" = "$3" ]; then G=$((G+1)); printf '  ✓ %s\n' "$1";
        else K=$((K+1)); printf '  ✗ %s\n     beklenen: %s\n     görülen : %s\n' "$1" "$2" "$3"; fi; }
TMP="$(mktemp -d)"; trap 'find "$TMP" -type f -delete 2>/dev/null; rmdir "$TMP" 2>/dev/null' EXIT

cat > "$TMP/taban.yaml" <<'YAML'
dosya:   "https://{kutu}.mmepanel.com/?folder=/config/projects/{kutu}"
pencere: ""
yayin:   ""
yayin_akar: "https://akar.mukarnas.net"
YAML
coz(){ LINK_TABAN="$TMP/taban.yaml" bash "$KOK/link-coz.sh" "$1"; }

kapi "L1 filo-geneli şablon çözülür ve {kutu} yerine geçer" \
  "https://tellal.mmepanel.com/?folder=/config/projects/tellal" "$(coz 'mmepanel://tellal/dosya/x/y.md')"
kapi "L2 kutuya-özel şablon filo-genelini EZER" \
  "https://akar.mukarnas.net" "$(coz 'mmepanel://akar/yayin/p17')"
kapi "L3 şablonu boş tür UYDURULMAZ — ham link basılır" \
  "mmepanel://tellal/yayin/p1" "$(coz 'mmepanel://tellal/yayin/p1')"
kapi "L4 tanımsız tür ham basılır (kapalı küme dışı sessizce çözülmez)" \
  "mmepanel://akar/bilinmeyen/z" "$(coz 'mmepanel://akar/bilinmeyen/z')"
kapi "L5 hazır https olduğu gibi geçer" \
  "https://ornek.com/a" "$(coz 'https://ornek.com/a')"
kapi "L6 mmepanel olmayan girdi olduğu gibi geçer" "duz-metin" "$(coz 'duz-metin')"
kapi "L7 taban dosyası yoksa çökmez, ham basar" "mmepanel://akar/dosya/x" \
  "$(LINK_TABAN="$TMP/yok.yaml" bash "$KOK/link-coz.sh" 'mmepanel://akar/dosya/x')"
kapi "L8 çok parçalı hedef korunur (yol içindeki / kaybolmaz)" \
  "https://akar.mmepanel.com/?folder=/config/projects/akar" "$(coz 'mmepanel://akar/dosya/a/b/c.md')"

printf '\ngeçti=%s · kaldı=%s\n' "$G" "$K"
[ "$K" -eq 0 ]
