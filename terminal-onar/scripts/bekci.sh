#!/usr/bin/env bash
# bekci.sh — dakikada bir (cron). Düzen sağlamsa hiçbir şey yapmaz; bozuksa merdiveni başlatır.
# Duraklatma: `bash komut.sh duraklat "<sebep>"` (ör. bilerek kapatırken) · `devam`.
set -u
. "$(dirname "$0")/ortak.sh" || exit 3   # kutu adı reddi: ortak.sh sebebi tek satır yazdı → DUR, rc 3 (FSZ30; eskiden unbound variable ile çöküyordu)
# Koşu izi (2.3.0): "kurulu" ile "koşuyor" ayrı şeylerdir (REVAK hata defteri, 29 Eyl–10 Eki: cron süreci 11 gün yoktu, gösterge
# crontab satırına bakıp "ok" diyordu). İz duraklatmadan ÖNCE yazılır: duraklatılmış bekçi de canlıdır.
date +%s > "$DURUM_DIZ/bekci.son" 2>/dev/null
[ -f "$DURUM_DIZ/duraklat" ] && exit 0
# 2.35.0 (kart kapi-bekci-eski-kod · görev …WHRJ): kapı DİSKTEKİ KODDAN ESKİ çalışıyorsa (kapi-eski-mi rc 1) BİR KEZ tam yeniden başlat
#   (kapi-yenile.sh 2.34.0 kapısı → onar --web-yenile). Ölçüldü 28 Eki: 13 kutuda kapı 5 gün eski kodla açıktı, Kadro düğmesi gelmiyordu;
#   beceri senkronu kodu indirir ama kimse süreci yenilemiyordu. Damga = en yeni .mjs'in mtime'ı; aynı kod için ikinci yenileme YOK
#   (yenileme düşerse damga yazılmaz → bir sonraki dakikada yeniden denenir). Ölçülemiyorsa (rc 2: süreç yok/okunamadı) DOKUNMAZ.
_ke="$(bash "$BETIK_DIZ/kapi-eski-mi.sh" 2>/dev/null)"; _kerc=$?
if [ "$_kerc" = 1 ]; then
  _kod_damga="$(find "$KAPI_DIZ" -name '*.mjs' -not -path '*/node_modules/*' -not -name '*.test.mjs' -printf '%T@\n' 2>/dev/null | sort -rn | head -1)"
  if [ -n "$_kod_damga" ] && [ "$_kod_damga" != "$(cat "$DURUM_DIZ/kapi-kod.son" 2>/dev/null)" ]; then
    gunluk "bekçi: kapı eski kodla çalışıyor → yeniliyor ($(printf '%s' "$_ke" | head -1))"
    if bash "$BETIK_DIZ/kapi-yenile.sh" >> "$GUNLUK" 2>&1; then printf '%s' "$_kod_damga" > "$DURUM_DIZ/kapi-kod.son"; gunluk "bekçi: kapı yenilendi (kod damgası $_kod_damga)"
    else gunluk "bekçi: kapı yenileme DÜŞTÜ (rc $?) — damga yazılmadı, bir sonraki dakikada yeniden denenir"; fi
  fi
fi
# tmux bekçisi (2.19.1): her tur karşılaştırılır, eksik/eski ise kurulur. Onar yalnız arızada koştuğu için 2.19.0 sağlıklı
# kutulara hiç inmiyordu (20 Eki: 18 kutudan yalnız code'da kurulu). Güncelse sessiz; kurulamazsa yazar, bekçi işine devam eder.
# Kurulamayan sonuç (ör. yabancı dosya) her dakika tekrarlanır → yalnız DEĞİŞTİĞİNDE yazılır (göz tur 2: günde 1440 satır olurdu).
_tb="$(tmux_bekcisi_kur)"
if [ "$_tb" != güncel ] && [ "$_tb" != "$(cat "$DURUM_DIZ/tmux-bekcisi.son" 2>/dev/null)" ]; then gunluk "bekçi: tmux bekçisi: $_tb"; fi
# El kabuğu (gorev_…GT5BTK): her tur — onar yalnız arızada koşar, sağlıklı kutuda kabuk eksik kalırdı (tmux bekçisi ile aynı ders).
#   Sağlık ölçüsüne (durum.sh) GİRMEZ: kabuk eksikliği merdiveni tırmandırıp yeni Claude açtırmasın. Yalnız yoksa kurar.
kabuk_kur >/dev/null 2>&1 || true
printf '%s' "$_tb" > "$DURUM_DIZ/tmux-bekcisi.son" 2>/dev/null
# Sıkıştırma eşiği (gorev_…880TAK): koşan her claude ortamında 600k ya da hesap ayarında eşik taşımalı; kutu başına ölçüm burada
# (cloudtop'un saatlik bekçisi yalnız kendi kutusunun süreçlerini görür). Yalnız DEĞİŞTİĞİNDE yazılır (tmux bekçisi dersi).
_sk="$(sikistirma_denetle 2>/dev/null)"
if [ "$_sk" != güncel ] && [ "$_sk" != "$(cat "$DURUM_DIZ/sikistirma.son" 2>/dev/null)" ]; then gunluk "bekçi: sıkıştırma eşiği: $_sk"; fi
printf '%s' "$_sk" > "$DURUM_DIZ/sikistirma.son" 2>/dev/null
# compact kuyruğu doluysa her dakika bir tur: meşgulken kuyruğa alınan koltuk boşalınca /compact gider (kutu-içi zorunlu compact, 2.9.0)
[ -s "${TO_COMPACT_KUYRUK:-$DURUM_DIZ/compact-bekleyen.jsonl}" ] && bash "$BETIK_DIZ/compact.sh" --bekle --uygula >> "$GUNLUK" 2>&1 || true
# Dava Rafı günlük turu (Parça B7): günde BİR kez — kapısı dava-gunluk.sh (damga turdan önce; sınav dava-gunluk.test.sh). Kuralsız kutuda no-op.
TO_PROJE="$PROJE" TO_ANA_TMUX="$ANA_TMUX" TO_DURUM_DIZ="$DURUM_DIZ" bash "$BETIK_DIZ/dava-gunluk.sh" >> "$GUNLUK" 2>&1 || true
bash "$BETIK_DIZ/durum.sh" >/dev/null 2>&1 && exit 0
exec bash "$BETIK_DIZ/kademe.sh" --kaynak bekci
