#!/usr/bin/env bash
# olc-oda.sh <paket-scripts-dizini> — sınıflı kart, Sultan'a ulaşım yolu YOKKEN (--oda yok, tetik betiği yok) açılıyor mu?
# Beklenen (0.19.0 göz tur 2): kart AÇILMAZ (rc≠0), kart dosyası yazılmaz, "Sultan'a ulaşılamadı" der → bu betik rc 0.
# Eski davranış: rc 0 + kart yazılır + sessiz → bu betik rc 1.
set -uo pipefail
P="$1"; T="$(mktemp -d)"; mkdir -p "$T/depo"
( cd "$T/depo" && git init -q -b main && git config user.email t@t && git config user.name T && echo x > f && git add -A && git commit -qm "chore: ilk" ) >/dev/null 2>&1
export KANIT_DEPO="$T/depo" FABRIKA_TETIK="$T/tetik-yok.sh" FABRIKA_AILE_NOTIFY=- DEFTER_JETON_YOL="$T/jeton-yok"
cd "$T/depo"
O="$(bash "$P/kart.sh" ac olcum-sinifli --is "odasız sınıflı kart ölçümü" --istedi Sultan --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki e 2>&1)"; RC=$?
echo "── kart.sh ac çıktısı (paket: $P) ──"; printf '%s\n' "$O"
echo "── kart.sh rc=$RC"
if [ -f "$T/depo/_agents/fabrika/kartlar/olcum-sinifli.json" ]; then YAZILDI=1; else YAZILDI=0; fi
echo "── kart dosyası yazıldı mı: $YAZILDI"
if grep -q "Sultan'a ulaşılamadı" <<<"$O"; then ULASIM=1; else ULASIM=0; fi
echo "── 'Sultan'a ulaşılamadı' satırı: $ULASIM"
if [ "$RC" -ne 0 ] && [ "$YAZILDI" -eq 0 ] && [ "$ULASIM" -eq 1 ]; then echo "SONUÇ: ulaşım yolu yokken sınıflı kart AÇILMADI (fail-closed)"; exit 0; fi
echo "SONUÇ: ulaşım yolu yokken sınıflı kart açıldı ya da sessiz kaldı"; exit 1
