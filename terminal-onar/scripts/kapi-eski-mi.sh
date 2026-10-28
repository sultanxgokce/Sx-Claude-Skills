#!/usr/bin/env bash
# kapi-eski-mi.sh — kutu kapısı DİSKTEKİ koddan ESKİ mi çalışıyor? (HADH10 · 28 Eki: kişi terminali yolu /tty-k/ diske inmişti, kapı 23 Eki'den
# beri açıktı → eski kod → Ayşenur'a 404; kurulum bunu hiç ölçmüyordu, SKILL.md'deki "kapı yeniden başlatılmalı" notu kapısız bir kuraldı.)
#
# Ölçü: kapı sürecinin BAŞLAMA anı ⟷ kapı dizinindeki .mjs dosyalarının en yeni değişme anı. Dosya süreçten yeniyse kapı eski kodla çalışıyor.
# (pano.js hariç: onu kapi-yenile.sh SIGHUP'la sıcak tazeler.) Dokunulup içeriği değişmeyen dosya da "eski" gösterir — yanlış alarm yönü güvenli taraf.
# KENDİSİ KAPIYI BAŞLATMAZ: yeniden başlatma açık web terminallerini bir kez koparır; karar ve komut basılır (onar.sh --web-yenile).
# RC: 0 kapı güncel · 1 kapı ESKİ kodla çalışıyor (uyarı basıldı) · 2 ölçülemedi (kapı süreci yok / kod dizini okunamadı)
# ÖLÇÜM: 2026-10-28 10:40 — gerçek node süreciyle dosya-yaşı karşılaştırması, test: kapi-eski-mi.test.sh
set -u
. "$(dirname "$0")/ortak.sh" || exit 3
pid=$(pgrep -u "$(id -u)" -f "node $KAPI_DIZ/sunucu.mjs" 2>/dev/null | head -1)
[ -n "$pid" ] || { echo "kapı süreci bulunamadı (kutu $KUTU) — kodun eski olup olmadığı ÖLÇÜLEMEDİ"; exit 2; }
gecen=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
[[ "$gecen" =~ ^[0-9]+$ ]] || { echo "kapı sürecinin yaşı okunamadı (pid $pid) — ÖLÇÜLEMEDİ"; exit 2; }
basla=$(( $(date +%s) - gecen ))
# pano.js'in dışlanması UZANTIDAN gelir: yalnız '*.mjs' aranır, pano.js bir '.js' dosyasıdır (E5 + mutant M2 bunu kilitler)
en_yeni=$(find "$KAPI_DIZ" -name '*.mjs' -not -path '*/node_modules/*' -not -name '*.test.mjs' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1)
[ -n "$en_yeni" ] || { echo "kapı kod dizininde .mjs bulunamadı ($KAPI_DIZ) — ÖLÇÜLEMEDİ"; exit 2; }
dosya_an=${en_yeni%%.*}; dosya=${en_yeni#* }
if [ "$dosya_an" -gt "$basla" ]; then
  echo "⚠ kapı ESKİ kodla çalışıyor: ${dosya#$KAPI_DIZ/} süreç başlayınca (≈$(( dosya_an - basla )) sn sonra) değişmiş; yeni yollar (ör. /tty-k/) 404 verebilir"
  echo "  yeniden başlat (açık web terminali BİR KEZ kopar): bash $BETIK_DIZ/onar.sh --web-yenile"
  exit 1
fi
echo "kapı güncel: süreç, kod dosyalarından sonra başlamış (pid $pid)"
exit 0
