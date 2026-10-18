#!/usr/bin/env bash
# bekci.sh — dakikada bir (cron). Düzen sağlamsa hiçbir şey yapmaz; bozuksa merdiveni başlatır.
# Duraklatma: `bash komut.sh duraklat "<sebep>"` (ör. bilerek kapatırken) · `devam`.
set -u
. "$(dirname "$0")/ortak.sh" || exit 3   # kutu adı reddi: ortak.sh sebebi tek satır yazdı → DUR, rc 3 (FSZ30; eskiden unbound variable ile çöküyordu)
# Koşu izi (2.3.0): "kurulu" ile "koşuyor" ayrı şeylerdir (REVAK hata defteri, 29 Eyl–10 Eki: cron süreci 11 gün yoktu, gösterge
# crontab satırına bakıp "ok" diyordu). İz duraklatmadan ÖNCE yazılır: duraklatılmış bekçi de canlıdır.
date +%s > "$DURUM_DIZ/bekci.son" 2>/dev/null
[ -f "$DURUM_DIZ/duraklat" ] && exit 0
# compact kuyruğu doluysa her dakika bir tur: meşgulken kuyruğa alınan koltuk boşalınca /compact gider (kutu-içi zorunlu compact, 2.9.0)
[ -s "${TO_COMPACT_KUYRUK:-$DURUM_DIZ/compact-bekleyen.jsonl}" ] && bash "$BETIK_DIZ/compact.sh" --bekle --uygula >> "$GUNLUK" 2>&1 || true
bash "$BETIK_DIZ/durum.sh" >/dev/null 2>&1 && exit 0
exec bash "$BETIK_DIZ/kademe.sh" --kaynak bekci
