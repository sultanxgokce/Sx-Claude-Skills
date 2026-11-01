#!/usr/bin/env bash
# ANA_TMUX türetme sınavı (kart terminal-onar-ana-tmux-yonetici · NAZIR bekçi bulgusu, 1 Kas 2026).
# Sözleşme: açık beyan (TO_ANA_TMUX) > ekip kaydındaki meta.yonetici (kutu önekli tmux adı VE oturum canlı) > <kutu>-ana.
# 🔴 GÜVENLİK: tmux sunucusu YALITILMIŞTIR (TMUX_TMPDIR geçici dizin, TMUX boşaltılır) — kutunun canlı sunucusuna oturum açılmaz.
#    (İlk deneme TMUX doluyken oturum açtı ve canlı sunucuya sızdı; bu yüzden her çağrı env -u TMUX ile koşar.)
set -u
gecen=0; kalan=0
kapi(){ if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORTAK="${ORTAK_SH:-$KOK/scripts/ortak.sh}"
T="$(mktemp -d)"; mkdir -p "$T/tm" "$T/p/_agents/handoff" "$T/d"
tm() { env -u TMUX TMUX_TMPDIR="$T/tm" tmux "$@"; }
bitir() { tm kill-server 2>/dev/null; find "$T" -delete 2>/dev/null; }
trap bitir EXIT
ana() {   # [TO_ANA_TMUX değeri] → ortak.sh'ın türettiği ANA_TMUX
  env -u TMUX TMUX_TMPDIR="$T/tm" TO_KUTU=sinav TO_PROJE="$T/p" TO_DURUM_DIZ="$T/d" ${1:+TO_ANA_TMUX=$1} \
    bash -c '. "$1" >/dev/null 2>&1; printf %s "$ANA_TMUX"' _ "$ORTAK"
}
kayit() { printf 'meta:\n  yonetici: %s\n  baska: x\n' "$1" > "$T/p/_agents/handoff/ekip-registry.yaml"; rm -f "$T/p/_agents/handoff/aile-registry.yaml"; }
tm new-session -d -s sinav-yon 'sleep 600' || { echo "tmux yalıtılmış sunucu kurulamadı"; exit 3; }

echo "── ana_tmux_turet"
kayit 'sinav-yon';                         kapi "A1 kayıt yöneticisi canlı oturum → o kullanılır"            sinav-yon "$(ana)"
kayit 'sinav-yon:0   # yorum';             kapi "A2 ':0' son eki ve yorum soyulur"                           sinav-yon "$(ana)"
kayit '"sinav-yon"';                       kapi "A3 tırnaklı değer"                                          sinav-yon "$(ana)"
kayit 'sinav-yon';                         kapi "A4 açık beyan TO_ANA_TMUX kayıttan üstün"                   ozel-ana "$(ana ozel-ana)"
kayit 'sinav-yok';                         kapi "A5 yönetici oturumu canlı DEĞİL → sinav-ana (huzur/sedir/tez durumu)" sinav-ana "$(ana)"
kayit 'DEFTERDAR';                         kapi "A6 yönetici insan adı → sinav-ana"                          sinav-ana "$(ana)"
tm new-session -d -s huzur-yon 'sleep 600'
kayit 'huzur-yon';                         kapi "A7 başka kutu önekli ad (canlı olsa bile) → sinav-ana"      sinav-ana "$(ana)"
rm -f "$T/p/_agents/handoff/ekip-registry.yaml"
kapi "A8 kayıt dosyası yok → sinav-ana" sinav-ana "$(ana)"
printf 'meta:\n  yonetici: sinav-yon\n' > "$T/p/_agents/handoff/aile-registry.yaml"
kapi "A9 yalnız aile-registry varsa ondan okunur" sinav-yon "$(ana)"
printf 'ekip:\n  - yonetici: sinav-yon\n' > "$T/p/_agents/handoff/aile-registry.yaml"
kapi "A10 meta bloğu dışındaki 'yonetici' satırı okunmaz" sinav-ana "$(ana)"
echo "geçen=$gecen kalan=$kalan"
[ "$kalan" = 0 ]
