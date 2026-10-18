#!/usr/bin/env bash
# dava-gunluk.sh — Dava Rafı günlük turunun KAPISI (Parça B7). Bekçi her dakika çağırır; tur (kapi/dava-bekci.mjs) günde BİR kez koşar.
# 🔴 Damga (<durum>/dava-bekci.gun) turdan ÖNCE yazılır: tur düşse de (kilit kapıda · koltuklar ölçülemedi) aynı gün yeniden
#    denenmez — dakikada bir tekrar iz kirletir, ertesi gün yeniden dener. Damga YAZILAMAZSA tur KOŞMAZ (yoksa her dakika koşardı).
#    Kuralı olmayan kutuda tur no-op'tur (dava-bekci.mjs "tur yok").
# Ortam: TO_DURUM_DIZ (zorunlu) · TO_PROJE · TO_ANA_TMUX (bekçiden, tura geçer)
#        DAVA_BUGUN (sınav: bugünün tarihi) · DAVA_TUR_KOMUT (sınav: turun yerine koşan komut)
# Sınav: dava-gunluk.test.sh
set -u
D="${TO_DURUM_DIZ:?TO_DURUM_DIZ gerekli}"; BUGUN="${DAVA_BUGUN:-$(date +%F)}"; DAMGA="$D/dava-bekci.gun"
[ "$(cat "$DAMGA" 2>/dev/null)" = "$BUGUN" ] && exit 0
if ! { printf '%s\n' "$BUGUN" > "$DAMGA.yeni" && mv -f "$DAMGA.yeni" "$DAMGA"; } 2>/dev/null; then
  echo "dava turu: damga yazılamadı ($DAMGA) — tur koşmadı" >&2; exit 0
fi
if [ -n "${DAVA_TUR_KOMUT:-}" ]; then bash -c "$DAVA_TUR_KOMUT"
else node "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../kapi/dava-bekci.mjs"; fi
