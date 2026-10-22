#!/usr/bin/env bash
# kabuk-sekmesi-mutasyon.sh — el kabuğu kurallarını tek tek öldürür; kabuk-sekmesi.test.sh (ve Y6b için sunucu.test.mjs) KIRMIZI olmalı.
#   Yerinde koşar (defter-gecit/mutasyon.sh deseni): her deneme dosyanın yedeğini alır, sınavdan sonra GERİ KOYAR; çıkışta da geri konur.
#   Kopya kullanılmaz: kapı sınavı kopya dizinde açılmıyor (ölçüldü). Önce pozitif kontrol. Kart kabuk-sekmesi.
set -u
D="$(cd "$(dirname "$0")/.." && pwd)"
YEDEK=""; geri() { [ -n "$YEDEK" ] && [ -f "$YEDEK.mutyedek" ] && mv "$YEDEK.mutyedek" "$YEDEK"; YEDEK=""; }; trap geri EXIT INT TERM
gecti=0; dusen=0
kos() { if [ "$1" = kapi ]; then (cd "$D/kapi" && timeout 300 node sunucu.test.mjs >/dev/null 2>&1); else (timeout 300 bash "$D/scripts/kabuk-sekmesi.test.sh" >/dev/null 2>&1); fi; }
if kos sh && kos kapi; then echo "  ✓ pozitif kontrol: dokunulmamış kopya YEŞİL"; else echo "  ✗ pozitif kontrol KIRMIZI — ölçüm geçersiz"; exit 1; fi
dene() {  # dene <ad> <dosya> <eski> <yeni> <sh|kapi>
  YEDEK="$D/$2"; cp "$YEDEK" "$YEDEK.mutyedek"
  python3 - "$D/$2" "$3" "$4" <<'PY' || { echo "  ✗ $1 — desen tutmadı"; dusen=$((dusen+1)); geri; return; }
import sys; p,e,y=sys.argv[1:]; s=open(p,encoding='utf-8').read()
if s.count(e)!=1: sys.exit(1)
open(p,'w',encoding='utf-8').write(s.replace(e,y))
PY
  if kos "$5"; then echo "  ✗ $1 — kural öldü ama sınav YEŞİL"; dusen=$((dusen+1)); else echo "  ✓ $1 — sınav KIRMIZI"; gecti=$((gecti+1)); fi
  geri
}
O=scripts/ortak.sh
dene "KM1 var olanı yeniden kurar (öldürür)" $O '  tmux_var "$KABUK_TMUX" && { printf ok' '  tmux kill-session -t "=$KABUK_TMUX" 2>/dev/null; false && { printf ok' sh
dene "KM2 kurulamama her dakika günlüğe yazılır" $O '[ "$(cat "$DURUM_DIZ/kabuk.son" 2>/dev/null)" = hata ] || gunluk' 'gunluk' sh
dene "KM3 kabuk proje dizininde açılmaz" $O 'tmux new-session -d -s "$KABUK_TMUX" -c "$PROJE"' 'tmux new-session -d -s "$KABUK_TMUX" -c /' sh
dene "KM4 bekçi kabuğu kurmaz" scripts/bekci.sh 'kabuk_kur >/dev/null 2>&1 || true' 'true' sh
dene "KM5 kabuk sağlık ölçüsüne girer" scripts/durum.sh 'tmux_var "$ANA_TMUX" && D[ana_tmux]=ok || D[ana_tmux]=yok' 'tmux_var "$ANA_TMUX" && D[ana_tmux]=ok || D[ana_tmux]=yok; tmux_var "$KABUK_TMUX" || D[kabuk]=yok' sh
dene "KM6 kabuk gizlenir (Sultan göremez)" scripts/koltuk-bagla.sh 'gizli() { case "$1" in ttyd-*|kapi-*|' 'gizli() { case "$1" in *-kabuk|ttyd-*|kapi-*|' sh
dene "KM7 kadroda altyapı sayılmaz (kapatılabilir)" kapi/kadro.mjs "  if (a.endsWith('-kabuk')) return 'el kabuğu';" '' sh
dene "KM8 kalkan yok sayılır (sınav gerçek sunucuya sızar)" $O '  [ -n "${TO_KABUK_YOK:-}" ] && return 0' '' sh
dene "KM9 kapı kabuk bayrağını vermez" kapi/sunucu.mjs 'kabuk: k.ad === KABUK_TMUX,' 'kabuk: false,' kapi
echo "mutasyon: $gecti öldü (sınav kırmızı) · $dusen kaçtı"; [ "$dusen" -eq 0 ]
