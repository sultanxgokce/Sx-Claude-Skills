#!/usr/bin/env bash
# kurtarici-kapali.test.sh — "kurtarıcı KAPALI" işareti ÇALIŞTIRILARAK ölçülür (hermetik: tmux/claude/whatsapp sahte, ağ yok).
#
# Niçin (Sultan kararı 16 Eki 2026, gorev_01M51QW6F3Z35G6GQJMTPWFF61): filo genelinde kurtarıcı ajanlar kapanacak, yalnız code
# kutusununki kalacak. Ama bekçi her dakika onar.sh'ı koşturur ve K0 adım 4 kurtarıcıyı geri açar; durum.sh de "yok" deyip
# düzeni bozuk gösterir, merdiven K2'de olmayan ajana komut yazar. Üç betik işareti aynı yerden (ortak.sh kurtarici_kapali)
# okur: onar.sh açmaz/kapatır · durum.sh "kapalı" basar ve sağlam sayar · kademe.sh K2'yi atlar, K3 iletisi insanı işaret eder.
#
# Sahte tmux: oturumlar $T/oturum/<ad> dosyalarıdır; dosya içeriği o oturumun "pane pid"idir (varsa). kill-session dosyayı
# siler ve $T/tmux.log'a yazar. "Canlı Claude" = argv0'ı claude olan uyuyan bir süreç (claude_pid süreç ağacına bakar).
set -u
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gecen=0; kalan=0
kapi() { if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
T=$(mktemp -d); D="$T/durum"; mkdir -p "$D" "$T/bin" "$T/proje" "$T/oturum"
temizle() { [ -n "${CPID:-}" ] && kill "$CPID" 2>/dev/null; rm -r -- "$T" 2>/dev/null; }
trap temizle EXIT

# ── sahte tmux ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
cat > "$T/bin/tmux" <<EOF
#!/usr/bin/env bash
O="$T/oturum"; L="$T/tmux.log"
ad() { local a="\$1"; a="\${a#=}"; a="\${a%%:*}"; printf '%s' "\$a"; }
case "\$1" in
  has-session) shift; [ "\$1" = -t ] && shift; [ -f "\$O/\$(ad "\$1")" ] ;;
  new-session) while [ \$# -gt 0 ]; do [ "\$1" = -s ] && { : > "\$O/\$2"; echo "new-session \$2" >> "\$L"; }; shift; done ;;
  kill-session) shift; [ "\$1" = -t ] && shift; rm -f "\$O/\$(ad "\$1")"; echo "kill-session \$(ad "\$1")" >> "\$L" ;;
  list-panes) while [ \$# -gt 0 ]; do [ "\$1" = -t ] && { f="\$O/\$(ad "\$2")"; [ -f "\$f" ] && cat "\$f"; }; shift; done; echo ;;
  show) echo /bin/bash ;;
  display) echo bash ;;
  new-window) echo %9 ;;
  send-keys) echo "send-keys \$*" >> "\$L" ;;
  *) exit 0 ;;
esac
EOF
# sahte claude (K1 başsız · K0 başlatma): hemen döner; sahte whatsapp yok — haber ortak.sh üstüne yazılır (aşağıda)
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/bin/claude"
chmod +x "$T/bin/tmux" "$T/bin/claude"

# Çalışma kopyası: ortak.sh'ın sonuna sahte haber + sağlam ttyd/kapı eklenir (ağ yok); onar.sh adım 4 bloğu AYRI betiğe çıkarılır
# (K0'ın 1-3. adımları ttyd/parola/kasa ister — konu dışı). Çıkarılan blok DEPODAKİ BAYTLARDIR, yeniden yazılmaz.
hazirla() {  # $1 = hedef dizin
  mkdir -p "$1"; cp -r "$KOK/scripts" "$1/"
  # 🔴 ortak.sh PATH'in BAŞINA gerçek /usr/bin'i koyar (cron için) → PATH'teki sahte tmux/claude kaybeder ve sınav GERÇEK tmux'a
  #    dokunur (ilk koşumda ölçüldü: gerçek 'sinav-kurtarici' oturumu açıldı). Sahte kutu bu yüzden ortak.sh'tan SONRA öne alınır.
  cat >> "$1/scripts/ortak.sh" <<'EOF'
export PATH="$TO_SAHTE_BIN:$PATH"
haber() { printf '%s\n' "$*" >> "$TO_DURUM_DIZ/haber.txt"; }
ttyd_saglam() { :; }; kapi_saglam() { :; }
sleep() { command sleep 0.02; }   # claude_baslat 45×2 sn bekler; sahte Claude hiç doğmaz → bekleme kısaltılır (çağrı sayısı aynı)
EOF
  { echo '#!/usr/bin/env bash'; echo 'set -u'; echo '. "$(dirname "$0")/ortak.sh"'
    sed -n '/^claude_baslat() {/,/^}/p' "$1/scripts/onar.sh"   # adım 4 bu yardımcıyı çağırır (onar.sh'ta tanımlı)
    sed -n '/^# 4 · kurtarıcı ajan/,/^\[ -n "\${TO_BEKCI_YOK/p' "$1/scripts/onar.sh" | sed '$d'; } > "$1/scripts/adim4.sh"
}
say() { local c; c=$(grep -c -- "$1" "$2" 2>/dev/null); echo "${c:-0}"; }   # dosya yoksa 0 (grep -c || echo 0 "0\n0" basar)
# JRCK8J: çalışan claude çözülemezse onar.sh YAZMAZ (K0 DUR); CI'da gerçek claude yok → sahte nvm kökünde geçerli (≥1 MB) bir claude
mkdir -p "$T/nvm-var/v1/bin" "$T/nvm-var/v1/lib"; head -c 2097152 /dev/zero > "$T/nvm-var/v1/lib/claude.exe"; chmod +x "$T/nvm-var/v1/lib/claude.exe"; ln -s ../lib/claude.exe "$T/nvm-var/v1/bin/claude"
M="$T/calisma"; hazirla "$M"
kapi "H0 onar.sh adım 4 bloğu çıkarıldı (kurtarici_kapali dalı içinde)" "e" "$(grep -q 'if kurtarici_kapali; then' "$M/scripts/adim4.sh" && echo e || echo h)"

kos() { # ortam… betik args → PATH sahte, kutu=sinav, durum dizini $D
  env -i PATH="$T/bin:/usr/bin:/bin" TO_SAHTE_BIN="$T/bin" TO_NVM_KOK="$T/nvm-var" HOME="$T" TO_KUTU=sinav TO_PROJE="$T/proje" TO_DURUM_DIZ="$D" TO_BEKCI_YOK=1 \
      TO_BECERI_KOK="$M" CORTEX_ACCESS_ENV="$T/yok.env" TO_KAPI_PORT=1 TO_TTYD_SOKET="$T/yok.sock" TO_BEKLE_ADIM=0.01 "$@"
}
kapi "H1 sahte tmux gerçekten devrede (gerçek tmux'a DOKUNULMAZ)" "sahte" "$(: > "$T/oturum/sahte-kanit"; kos bash -c '. "$TO_BECERI_KOK/scripts/ortak.sh"; tmux_var sahte-kanit && echo sahte || echo GERÇEK' 2>/dev/null; rm -f "$T/oturum/sahte-kanit")"
kurt_hal() { kos "$@" bash "$M/scripts/durum.sh" 2>/dev/null | sed -n 's/^kurtarıcı ajan *: //p'; }
sifirla() { rm -f "$D/kurtarici-kapali" "$D/gunluk.log" "$D/haber.txt" "$T/tmux.log" "$T"/oturum/*; : > "$T/oturum/sinav-ana"; }
canli_claude() {  # $1 = oturum adı → o oturumda "canlı Claude" varmış gibi (argv0=claude uyuyan süreç)
  bash -c 'exec -a claude sleep 300' & CPID=$!; sleep 0.2; printf '%s\n' "$CPID" > "$T/oturum/$1"
}

echo "── D · durum.sh"
sifirla
kapi "D1 işaret YOK + kurtarıcı yok → 'yok' (eski davranış aynen)" "yok" "$(kurt_hal)"
: > "$D/kurtarici-kapali"
kapi "D2 işaret VAR + kurtarıcı yok → 'kapalı (Sultan 16 Eki)'" "kapalı (Sultan 16 Eki)" "$(kurt_hal)"
kapi "D2b 'düştü/yok' DENMEZ" "0" "$(kurt_hal | grep -c 'yok')"
kapi "D3 --json da aynı sözü taşır" "e" "$(kos bash "$M/scripts/durum.sh" --json 2>/dev/null | grep -q '"kurtarici":"kapalı (Sultan 16 Eki)"' && echo e || echo h)"
rm -f "$D/kurtarici-kapali"
kapi "D4 dosya yerine TO_KURTARICI=0 beyanı da işarettir" "kapalı (Sultan 16 Eki)" "$(kurt_hal TO_KURTARICI=0)"
# Öteki dört parça sağlam yapılır (ana oturumda canlı Claude, ttyd/kapı sahte-sağlam, bekçi TO_BEKCI_YOK) → RC yalnız kurtarıcıya bağlı
canli_claude sinav-ana
rc_yok=$(kos bash "$M/scripts/durum.sh" >/dev/null 2>&1; echo $?)
: > "$D/kurtarici-kapali"
rc_kapali=$(kos bash "$M/scripts/durum.sh" >/dev/null 2>&1; echo $?)
kapi "D5 işaretsiz 'yok' düzeni BOZUK sayar (rc 1) — kontrol" "1" "$rc_yok"
kapi "D6 🔴 işaretli 'kapalı' düzeni SAĞLAM sayar (rc 0) — bekçi merdiveni boşuna tırmandırmaz" "0" "$rc_kapali"
kill "$CPID" 2>/dev/null; CPID=""
canli_claude sinav-kurtarici
kapi "D7 işaret VAR ama kurtarıcı AÇIK → 'kapalı-ama-AÇIK' + bozuk (K0 kapatacak)" "e" \
  "$(h=$(kurt_hal); case "$h" in kapalı-ama-AÇIK*) echo e;; *) echo "h:$h";; esac)"
kill "$CPID" 2>/dev/null; CPID=""

echo "── O · onar.sh adım 4 (çıkarılan blok)"
sifirla; : > "$D/kurtarici-kapali"
kos bash "$M/scripts/adim4.sh" >/dev/null 2>&1
kapi "O1 işaret VAR + oturum yok → yeni oturum AÇILMAZ (tmux new-session çağrılmadı)" "0" "$(say 'new-session sinav-kurtarici' "$T/tmux.log")"
kapi "O1b günlük 'kapalı (Sultan 16 Eki) — açılmadı' der" "1" "$(grep -c 'kurtarıcı kapalı (Sultan 16 Eki) — açılmadı' "$D/gunluk.log")"
: > "$T/oturum/sinav-kurtarici"
kos bash "$M/scripts/adim4.sh" >/dev/null 2>&1
kapi "O2 işaret VAR + oturum AÇIK → KAPATILIR (kill-session)" "1" "$(grep -c 'kill-session sinav-kurtarici' "$T/tmux.log")"
kapi "O2b oturum dosyası gitti (durum işarete yakınsadı)" "h" "$([ -f "$T/oturum/sinav-kurtarici" ] && echo e || echo h)"
kapi "O2c günlük 'açık bulundu, KAPATILDI' der" "1" "$(grep -c 'açık bulundu, KAPATILDI' "$D/gunluk.log")"
sifirla
kos bash "$M/scripts/adim4.sh" >/dev/null 2>&1
kapi "O3 işaret YOK → eski yol: oturum kurulur, Claude başlatılmaya çalışılır" "e" \
  "$(grep -q 'new-session sinav-kurtarici' "$T/tmux.log" && grep -q 'send-keys.*claude' "$T/tmux.log" && echo e || echo h)"
kapi "O3b işaret yokken kill-session YOK" "0" "$(say 'kill-session' "$T/tmux.log")"

echo "── M · kademe.sh (K0 sahte-bozuk, K1 sahte claude, K3 haber dosyaya)"
printf '#!/usr/bin/env bash\nexit 1\n' > "$M/scripts/onar.sh"   # K0 onaramadı → merdiven tırmanır (adım 4 bloğu zaten adim4.sh'ta)
sifirla; : > "$D/kurtarici-kapali"
kos bash "$M/scripts/kademe.sh" --kaynak elle >/dev/null 2>&1; rc=$?
kapi "M1 merdiven K3'e düşer (rc 1)" "1" "$rc"
kapi "M2 K2 ATLANIR: günlük 'K2 kurtarıcı kapalı … MUAVİN/SERDAR'a bildir'" "1" "$(grep -c 'K2 kurtarıcı kapalı (Sultan 16 Eki) → atlandı; MUAVİN/SERDAR' "$D/gunluk.log")"
kapi "M2b kurtarıcıya komut YAZILMAZ (send-keys yok)" "0" "$(say 'send-keys' "$T/tmux.log")"
kapi "M3 K3 iletisi 'kurtarıcı kapalı → MUAVİN/SERDAR'a bildir' taşır" "1" "$(grep -c 'kurtarıcı kapalı → MUAVİN/SERDAR.a bildir' "$D/haber.txt")"
sifirla
kos bash "$M/scripts/kademe.sh" --kaynak elle >/dev/null 2>&1
kapi "M4 işaret yokken K2 denenir (eski davranış: 'kurtarıcı ajan da ayakta değil')" "1" "$(grep -c 'K2 kurtarıcı ajan da ayakta değil' "$D/gunluk.log")"
kapi "M4b işaret yokken K3 iletisinde kapalı notu YOK" "0" "$(grep -c 'kurtarıcı kapalı' "$D/haber.txt")"

echo "── MUTASYON (beklenen KIRMIZI): işaret kontrolü sökülürse kapılar ısırır mı"
MU="$T/mutant"; hazirla "$MU"
python3 - "$MU/scripts/durum.sh" "$MU/scripts/adim4.sh" <<'PY'
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
i=s.index('if kurtarici_kapali; then'); j=s.index('elif kid=$(claude_oturumu')
s=s[:i]+'if kid=$(claude_oturumu'+s[j+len('elif kid=$(claude_oturumu'):]
open(p,'w',encoding='utf-8').write(s)
p=sys.argv[2]; s=open(p,encoding='utf-8').read()
i=s.index('if kurtarici_kapali; then'); j=s.index('elif ! claude_oturumu')
s=s[:i]+'if ! claude_oturumu'+s[j+len('elif ! claude_oturumu'):]
open(p,'w',encoding='utf-8').write(s)
PY
sifirla; : > "$D/kurtarici-kapali"
mhal=$(env -i PATH="$T/bin:/usr/bin:/bin" TO_SAHTE_BIN="$T/bin" TO_NVM_KOK="$T/nvm-var" HOME="$T" TO_KUTU=sinav TO_PROJE="$T/proje" TO_DURUM_DIZ="$D" TO_BEKCI_YOK=1 TO_BECERI_KOK="$MU" \
  CORTEX_ACCESS_ENV="$T/yok.env" TO_KAPI_PORT=1 TO_TTYD_SOKET="$T/yok.sock" bash "$MU/scripts/durum.sh" 2>/dev/null | sed -n 's/^kurtarıcı ajan *: //p')
kapi "X1 MUTANT durum.sh işareti görmez → 'yok' basar (D2 onu yakalar)" "yok" "$mhal"
env -i PATH="$T/bin:/usr/bin:/bin" TO_SAHTE_BIN="$T/bin" TO_NVM_KOK="$T/nvm-var" HOME="$T" TO_KUTU=sinav TO_PROJE="$T/proje" TO_DURUM_DIZ="$D" TO_BEKCI_YOK=1 TO_BECERI_KOK="$MU" \
  CORTEX_ACCESS_ENV="$T/yok.env" TO_KAPI_PORT=1 TO_TTYD_SOKET="$T/yok.sock" TO_BEKLE_ADIM=0.01 bash "$MU/scripts/adim4.sh" >/dev/null 2>&1
kapi "X2 MUTANT onar adım 4 işarete rağmen kurtarıcıyı AÇAR (O1 onu yakalar)" "1" "$(grep -c 'new-session sinav-kurtarici' "$T/tmux.log")"

echo
echo "kurtarici-kapali.test: $gecen geçti · $kalan kaldı"
[ "$kalan" = 0 ]
