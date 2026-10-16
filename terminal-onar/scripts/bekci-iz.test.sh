#!/usr/bin/env bash
# bekci-iz.test.sh — "kurulu" ≠ "koşuyor": bekçinin koşu izi ve durum.sh'ın ona bakışı ÇALIŞTIRILARAK ölçülür (hermetik).
#
# Niçin (REVAK hata defteri, 29 Eyl–10 Eki 2026; ortak koda 13 Eki taşındı): cron süreci 11 gün yoktu, gösterge crontab
# SATIRINA bakıp "ok" diyordu. Artık bekci.sh her koşuda iz bırakır; durum.sh izi ölçer (5 dk), yalnız onar.sh'ın
# bekçiyi az önce kurduğu 2 dk'lık pencerede izsizliğe göz yumar. tmux/crontab sahte; ağ yok.
set -u
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gecen=0; kalan=0
kapi() { if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
T=$(mktemp -d); D="$T/durum"; mkdir -p "$D" "$T/bin" "$T/proje"
printf '#!/usr/bin/env bash\n[ "$1" = -l ] && cat "%s/crontab.txt" 2>/dev/null; exit 0\n' "$T" > "$T/bin/crontab"
printf '#!/usr/bin/env bash\nexit 1\n' > "$T/bin/tmux"      # oturum yok — bekçi dışındaki parçalar "yok" (konu dışı)
chmod +x "$T/bin/crontab" "$T/bin/tmux"
# 🔴 ortak.sh PATH'in BAŞINA /usr/bin'i koyar → PATH'teki sahte tmux/crontab kaybeder, sınav GERÇEK tmux'a bakar (kurtarici-kapali.test
#    dersi, 16 Eki). Sahteler, ortak.sh'ın KOPYASININ sonunda öne alınır; H1 bunu her koşuda ölçer. Depodaki betikler kopyadan koşar.
M="$T/calisma"; mkdir -p "$M"; cp -r "$KOK/scripts" "$M/"
printf '\nexport PATH="$TO_SAHTE_BIN:$PATH"\n' >> "$M/scripts/ortak.sh"
kos() { # $1 betik · gerisi ortam → durum.sh çıktısı / bekci.sh rc
  env -i PATH="$T/bin:/usr/bin:/bin" TO_SAHTE_BIN="$T/bin" HOME="$T" TO_KUTU=sinav TO_PROJE="$T/proje" TO_DURUM_DIZ="$D" TO_CRONTAB="$T/bin/crontab" \
      TO_BECERI_KOK="$M" CORTEX_ACCESS_ENV="$T/yok.env" TO_KAPI_PORT=1 TO_TTYD_SOKET="$T/yok.sock" "$@"
}
kapi "H1 sahte tmux/crontab ortak.sh'tan sonra da öndedir (gerçek tmux'a DOKUNULMAZ)" "sahte" \
  "$(kos bash -c '. "$TO_BECERI_KOK/scripts/ortak.sh"; [ "$(command -v tmux)" = "$TO_SAHTE_BIN/tmux" ] && [ "$(command -v crontab)" = "$TO_SAHTE_BIN/crontab" ] && echo sahte || echo GERÇEK' 2>/dev/null)"
bekci_hal() { kos "$@" bash "$M/scripts/durum.sh" 2>/dev/null | sed -n 's/^bekçi (dakikalık) *: //p'; }
sinif() { case "$1" in ok) echo ok;; izsiz*) echo izsiz;; durgun*) echo durgun;; yok) echo yok;; *) echo "?$1";; esac; }
simdi() { date +%s; }

echo "── satır yok"
kapi "B1 cron satırı yokken: yok" "yok" "$(sinif "$(bekci_hal)")"
echo "── satır var, iz yok"
printf '* * * * * bash %s/scripts/bekci.sh  # terminal-onar-bekci\n' "$T/proje/.claude/skills/terminal-onar" > "$T/crontab.txt"
kapi "B2 🔴 satır kurulu ama HİÇ koşmamış → izsiz (eski gösterge burada 'ok' derdi)" "izsiz" "$(sinif "$(bekci_hal)")"
echo "$(( $(simdi) - 30 ))" > "$D/bekci.kuruldu"
kapi "B3 onar.sh az önce kurduysa (damga 30 sn) ilk koşu beklenir → ok" "ok" "$(sinif "$(bekci_hal)")"
echo "$(( $(simdi) - 600 ))" > "$D/bekci.kuruldu"
kapi "B4 damga 10 dk eski + iz yok → pencere dolmuş, izsiz" "izsiz" "$(sinif "$(bekci_hal)")"
rm -f "$D/bekci.kuruldu"
echo "── iz var"
echo "$(( $(simdi) - 600 ))" > "$D/bekci.son"
kapi "B5 iz 10 dk eski → durgun (cron süreci ölmüş)" "durgun" "$(sinif "$(bekci_hal)")"
kapi "B5b durgun iletisi kaç dakikadır koşmadığını söyler" "e" "$(bekci_hal | grep -q 'dk koşmadı' && echo e || echo h)"
echo "$(simdi)" > "$D/bekci.son"
kapi "B6 iz taze → ok" "ok" "$(sinif "$(bekci_hal)")"
echo "bozuk" > "$D/bekci.son"
kapi "B7 iz dosyası bozuksa sayı uydurulmaz → izsiz" "izsiz" "$(sinif "$(bekci_hal)")"
rm -f "$D/bekci.son"
kapi "B8 TO_BEKCI_YOK verilince (bekçisiz kurulum) izsiz olsa da ok" "ok" "$(sinif "$(bekci_hal TO_BEKCI_YOK=1)")"
echo "── bekci.sh izi FİİLEN yazıyor mu"
printf 'sınav\n' > "$D/duraklat"
t0=$(simdi); rc=$(kos bash "$M/scripts/bekci.sh" >/dev/null 2>&1; echo $?)
iz=$(cat "$D/bekci.son" 2>/dev/null || echo yok)
kapi "B9 duraklatılmış bekçi de iz bırakır (duraklatılmış ≠ ölü), rc 0" "e" "$([ "$rc" = 0 ] && [[ "$iz" =~ ^[0-9]+$ ]] && [ "$iz" -ge "$t0" ] && echo e || echo h)"
rm -f "$D/duraklat"
kapi "B10 izden sonra durum.sh bekçiyi ok görür" "ok" "$(sinif "$(bekci_hal)")"
echo "── MUTASYON: iz ölçümü eski hâline dönerse kapı ısırır mı"
MU="$T/mut"; mkdir -p "$MU"; cp -r "$M/scripts" "$MU/"
python3 - "$MU/scripts/durum.sh" <<'PY'
import sys,re; p=sys.argv[1]; s=open(p,encoding='utf-8').read()
i=s.index('if [ -n "${TO_BEKCI_YOK:-}" ]; then D[bekci]=ok'); k=s.index('else D[bekci]=ok; fi\n')+len('else D[bekci]=ok; fi\n'); j=s.index('fi\n', k)+3
s=s[:i]+'{ bekci_kurulu || [ -n "${TO_BEKCI_YOK:-}" ]; } && D[bekci]=ok || D[bekci]=yok\n'+s[j:]
open(p,'w',encoding='utf-8').write(s)
PY
rm -f "$D/bekci.son" "$D/bekci.kuruldu"
mhal=$(kos bash "$MU/scripts/durum.sh" 2>/dev/null | sed -n 's/^bekçi (dakikalık) *: //p')
kapi "B11 MUTASYON: eski gösterge iz yokken 'ok' basar → B2 onu yakalıyor (koruma süs değil)" "ok" "$(sinif "$mhal")"
rm -r -- "$T"
echo "bekci-iz.test: $gecen geçti · $kalan kaldı"
[ "$kalan" = 0 ]
