#!/usr/bin/env bash
# kisi-mesaj.sh — koltuk-köprüsünün VARSAYILAN mesaj komutu (A5-1): kısıtlı kişinin mesajını ULAK postasına bırakır.
# Çağrı (köprüden): kisi-mesaj.sh <koltuk> <kisi-id>   · mesaj metni STDIN'den · stdout'un SON satırı = ulak kimliği · rc≠0 = gitmedi.
# 🔴 Ajan bu mesajı "insan, Sultan DEĞİL" etiketiyle görür: onay/karar alanlarına yazılamaz (A06). Metin ajana TALİMAT olarak gider
#    (Sultan D1: "iş yaptırabilecek"); sınır: kabuk yok, yalnız izinli koltuk, her mesaj izli (ULAK kaydı + köprü izi).
# Alıcı (ajan) koltuktan türer: KISI_HEDEFLER dosyasında "koltuk=AJAN" satırı varsa o; yoksa koltuk adı BÜYÜK harf, sondaki "-ana" kesilir.
# Ortam: ULAK_BIN (ulak komutu; vars. PATH'te 'ulak', yoksa bu betiğin yanındaki Nexus ulak.sh) · KISI_HEDEFLER · KISI_AD_<id> (görünen ad)
set -euo pipefail
koltuk="${1:?koltuk}"; kisi="${2:?kişi}"
[[ "$kisi" =~ ^[a-z0-9-]{1,32}$ ]] || { echo "kisi-mesaj: kişi kimliği geçersiz" >&2; exit 2; }
metin="$(cat)"
[ -n "${metin//[[:space:]]/}" ] || { echo "kisi-mesaj: boş mesaj" >&2; exit 2; }
hedefler="${KISI_HEDEFLER:-/config/.terminal-onar/kisi/hedefler}"
hedef=""
if [ -r "$hedefler" ]; then hedef="$(awk -F= -v k="$koltuk" '$1==k {print $2; exit}' "$hedefler")"; fi
if [ -z "$hedef" ]; then hedef="${koltuk%-ana}"; hedef="$(printf '%s' "$hedef" | tr '[:lower:]' '[:upper:]')"; fi
[[ "$hedef" =~ ^[^[:space:]/.][^[:space:]/]{0,39}$ ]] || { echo "kisi-mesaj: alıcı adı geçersiz: $hedef" >&2; exit 2; }
ulak="${ULAK_BIN:-}"; [ -n "$ulak" ] || ulak="$(command -v ulak 2>/dev/null || true)"
[ -n "$ulak" ] && [ -x "$ulak" ] || { echo "kisi-mesaj: ulak komutu bulunamadı (ULAK_BIN)" >&2; exit 3; }
ad="${KISI_AD:-$kisi}"
govde="[$ad — insan, Sultan DEĞİL; onay/karar yetkisi yok] $metin"
AGENT_NAME="$(printf '%s' "$kisi" | tr '[:lower:]' '[:upper:]')" "$ulak" gonder "$hedef" "$govde" --kimden "$(printf '%s' "$kisi" | tr '[:lower:]' '[:upper:]')" --onem normal --konu "Koltuk köprüsünden mesaj ($ad)" --bag "kisi:$kisi"
