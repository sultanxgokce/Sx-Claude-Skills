#!/usr/bin/env bash
# Kutu adı REDDİ — ortak.sh'ı yükleyen her betik reddi görünce DURUR mu? (gorev_01M4ZHH1XXGXM5QHV2YTNFSZ30)
#
# Niçin var (ölçülmüş, 18 Eki 2026): ortak.sh makine kimliğine benzeyen kutu adını doğru reddediyor (`return 1`), ama onu
# `. ortak.sh` ile yükleyen sekiz betik dönüşe bakmıyordu: akış sürüyor, ortak.sh'ın reddin ARDINDAN tanımladığı
# değişkenlerde `set -u` ile çöküyordu — compact.sh 'DURUM_DIZ: unbound variable' (15 Eki code kutusu), bekci/kademe aynı,
# durum 'ANA_TMUX', kapi-yenile 'KAPI_DIZ', koltuk-ac 'PROJE', onar 'gunluk: command not found'. Sebep satırı izin
# altında kayboluyordu. kur.sh bunu S-11'de (13 Eki) kendi için kapatmıştı; kardeşleri açık kalmıştı.
# Sözleşme: red → TEK satır (ortak.sh'ın kendi iletisi: "TO_KUTU ver …"), rc 3, yan etki yok.
set -u
gecen=0; kalan=0
kapi(){ if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

T=$(mktemp -d)
# Beceri ORTAK dizindeymiş gibi (projects/ dışında) — yol kutuyu söylemez, makine adı rastgele kimlik (12 Eki canlı vakası)
mkdir -p "$T/ortak/skills/terminal-onar" "$T/bin" "$T/ev"
cp -r "$KOK/scripts" "$T/ortak/skills/terminal-onar/"
S="$T/ortak/skills/terminal-onar/scripts"
printf '#!/usr/bin/env bash\necho 0ee2fa8a0370\n' > "$T/bin/hostname"
# yan etki tanığı: reddedilen betik tmux'a / crontab'a DOKUNMAMALI
for a in tmux crontab; do printf '#!/usr/bin/env bash\necho "%s $*" >> "%s/yan-etki.log"\nexit 0\n' "$a" "$T" > "$T/bin/$a"; done
chmod +x "$T/bin/"*

kos() { # $1 = betik, gerisi argüman → "rc|satır_sayısı|TO_KUTU_var|izli_hata"
  local o rc
  o="$(cd "$T" && env -u TO_KUTU -u TO_PROJE HOME="$T/ev" TO_DURUM_DIZ="$T/durum" PATH="$T/bin:$PATH" bash "$S/$1" "${@:2}" </dev/null 2>&1)"; rc=$?
  printf '%s|%s|%s|%s' "$rc" "$(printf '%s\n' "$o" | grep -c .)" \
    "$(case "$o" in *"makine kimliğine benziyor"*TO_KUTU*) echo e;; *) echo h;; esac)" \
    "$(printf '%s' "$o" | grep -Ec 'unbound variable|command not found|No such file')"
}

echo "── R · makine kimlikli kutu adı: sekiz betik de TEK satır sebeple, rc 3 DURUR"
kapi "R1 compact.sh (FSZ30 vakası: eskiden 'DURUM_DIZ: unbound variable')" "3|1|e|0" "$(kos compact.sh)"
kapi "R2 komut.sh compact --koltuk nakkas (15 Eki tam komut)" "3|1|e|0" "$(kos komut.sh compact --koltuk nakkas)"
kapi "R3 bekci.sh (her dakika koşan bekçi)" "3|1|e|0" "$(kos bekci.sh)"
kapi "R4 durum.sh (eskiden 'ANA_TMUX: unbound variable')" "3|1|e|0" "$(kos durum.sh)"
kapi "R5 kademe.sh" "3|1|e|0" "$(kos kademe.sh)"
kapi "R6 kapi-yenile.sh (eskiden 'KAPI_DIZ: unbound variable')" "3|1|e|0" "$(kos kapi-yenile.sh)"
kapi "R7 koltuk-ac.sh durum x (eskiden 'PROJE: unbound variable')" "3|1|e|0" "$(kos koltuk-ac.sh durum x)"
kapi "R8 onar.sh (eskiden 'gunluk: command not found')" "3|1|e|0" "$(kos onar.sh)"
kapi "R9 reddedilen betikler tmux/crontab'a dokunmadı, durum dizini açmadı (yan etki yok)" "yok|yok" \
  "$([ -s "$T/yan-etki.log" ] && echo var || echo yok)|$([ -e "$T/durum" ] && echo var || echo yok)"
kapi "R10 kapsam tam: ortak.sh'ı yükleyen HER betik (kur.sh hariç — S-11 kendi yolu) bu sınavda" "" \
  "$(cd "$S" && grep -l '^[^#]*\. .*ortak\.sh' *.sh | grep -v -e '\.test\.sh$' -e 'mutasyon\.sh$' | grep -vxE 'compact.sh|komut.sh|bekci.sh|durum.sh|kademe.sh|kapi-yenile.sh|koltuk-ac.sh|onar.sh|kur.sh|ortak.sh' | tr '\n' ' ')"

kapi "R10b R10'un aramasının kendisi ölçüldü: ortak.sh'ı yükleyen 9 betik bulunuyor (8 + kur.sh) — boş sonuç kör aramadan gelmiyor" "9" \
  "$(cd "$S" && grep -l '^[^#]*\. .*ortak\.sh' *.sh | grep -v -e '\.test\.sh$' -e 'mutasyon\.sh$' | grep -c .)"

echo "── P · pozitif kontrol: aynı düzenek, GEÇERLİ kutu adıyla yükleme geçer (red ölçümü kör değil)"
printf '#!/usr/bin/env bash\necho cloudtop-huzur\n' > "$T/bin/hostname"
kapi "P1 koltuk-ac.sh (argümansız) yüklemeyi geçip kendi kullanım satırına varır: rc 2, red YOK" "2|h" \
  "$(kos koltuk-ac.sh | cut -d'|' -f1,3)"
kapi "P2 komut.sh bilinmeyen fiil: yüklemeyi geçer, rc 2, red YOK" "2|h" "$(kos komut.sh bilinmeyenfiil | cut -d'|' -f1,3)"

rm -r -- "$T" 2>/dev/null
echo
echo "SONUÇ: $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ]
