#!/usr/bin/env bash
# koltuk-hesap-alani mutasyon kanıtı: betiğin KOPYASI bozulur, sınav kopyadan koşar → KIRMIZI olmalı (iş alanına dokunulmaz)
set -u
W=/config/projects/_wt/Sx-Claude-Skills-koltuk-hesap-alani/terminal-onar/scripts
M="$(mktemp -d)"; trap 'rm -r -f -- "$M"' EXIT
gecen=0; dusen=0
dene() {  # ad · sed ifadesi · beklenen kırmızı kapı
  local ad="$1" ifade="$2" kapi="$3"
  rm -rf "$M/k"; mkdir -p "$M/k"; cp "$W"/*.sh "$M/k/"
  sed -i "$ifade" "$M/k/koltuk-bagla.sh"
  if cmp -s "$W/koltuk-bagla.sh" "$M/k/koltuk-bagla.sh"; then echo "  ✗ $ad — mutasyon UYGULANAMADI"; dusen=$((dusen+1)); return; fi
  out="$(bash "$M/k/koltuk-bagla.test.sh" 2>&1)"; rc=$?
  if [ $rc != 0 ] && printf '%s\n' "$out" | grep -q "✗ $kapi"; then echo "  ✓ $ad — kapı ölünce sınav KIRMIZI ($kapi)"; gecen=$((gecen+1))
  else echo "  ✗ $ad — sınav YEŞİL kaldı ya da $kapi düşmedi (rc=$rc)"; printf '%s\n' "$out" | grep "✗" | head -3; dusen=$((dusen+1)); fi
}
dene "M1 kapı şeridi kuralı silindi (ANTHROPIC_BASE_URL → kapi)"   's/\[ "\$2" = 1 \] && { echo kapi; return; }/:/' H5
dene "M2 okunamadı → varsayilan denir (ölçülemedi = varsayılan yalanı)" 's/echo "bilinmiyor:okunamadi"; return;/echo varsayilan; return;/' H7
dene "M3 kök dışı dizin ad sayılır (basename her yerde)"               's/\[ "\$(dirname "\$n")" = "\$kok" \] && { basename "\$n"; return; }/basename "$n"; return/' H6
dene "M4 hesap hiç ölçülmez (sütun boş kalır)"                        's/hesap="\$(koltuk_hesabi "\$s")"/hesap=""/' H1
dene "M5 Claude'suz koltuğa da hesap yazılır (uydurma)"                  's/else hesap=""; fi/else hesap=varsayilan; fi/' H2
dene "M6 normal_yol .. çözmez (normpath eşdeğerliği kırılır)"            's/if (p=="\.\.") { if (n>0 \&\& y\[n\]!="\.\.") { n-- } else if (!mutlak) { y\[++n\]=p }; continue }/if (p=="..") { y[++n]=p; continue }/' H10
dene "M7 claude_pid bölme komutuna öncelik verir (kabuğun ortamı okunur)"  's/p="\$(altta_claude_pid "\$pid")"; \[ -n "\$p" \] && { echo "\$p"; return 0; }$/:/' H11
echo "mutasyon: geçen=$gecen düşen=$dusen"
[ $dusen = 0 ]
