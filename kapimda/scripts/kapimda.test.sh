#!/usr/bin/env bash
# kapimda.test.sh — yazıcı + 8 lint kapısı + adım motoru HERMETİK sınaması (MABEYN H2 · L38-F3/L39-F1)
# Gerçek ~/.claude/kapimda.md'ye DOKUNMAZ (KAPIMDA_DOSYA ile geçici dosyaya yönlendirilir).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$HERE/kapimda.sh"
gecti=0; dustu=0
ok()   { echo "PASS  $1"; gecti=$((gecti+1)); }
kotu() { echo "FAIL  $1"; dustu=$((dustu+1)); }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

export KAPIMDA_DOSYA="$T/kapimda.md" KAPIMDA_ADIM_DIZIN="$T/adim" KAPIMDA_KILIT="$T/lock"
kos(){ bash "$SUT" "$@"; }
# geçerli kart alanları (jargonsuz, Sultan-dilinde)
G_NE="bana 'kasa erişimi aç' de, adımları önüne koyayım"
G_NICIN="kasa paneline giriş yalnız sende; ajanın oraya erişimi yok"
G_YAP="ekip iki işe de başlayamaz, kutu boşa çalışır"
G_BIT="'kasa bitti' de"

bash -n "$SUT" && ok "G0 sözdizimi" || kotu "G0 sözdizimi bozuk"

# ── K-kapıları: RED yolları ──────────────────────────────────────────────────
kos ac "Test Kart" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$G_YAP" >/dev/null 2>&1
[ $? -eq 1 ] && ok "K1 eksik alan (--bitince yok) → RED" || kotu "K1 eksik alanla açtı"

kos ac "Test Kart" --ne "$G_NE" --nicin-sen "kısa" --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
[ $? -eq 1 ] && ok "K2 'Niçin sen' cümle değil → RED" || kotu "K2 boş-gerekçeyle açtı"

kos ac "Yollu Kart" --ne "şu dosyayı aç: /config/projects/x.sh" --nicin-sen "$G_NICIN" \
   --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
[ $? -eq 1 ] && ok "K5 dosya-yolu → RED (Sultan-dili kalkanı)" || kotu "K5 yol kaçtı"

kos ac "Komutlu Kart" --ne "git push yap sonra bana haber ver" --nicin-sen "$G_NICIN" \
   --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
[ $? -eq 1 ] && ok "K5 komut-terimi → RED" || kotu "K5 komut kaçtı"

kos ac "Cok Is" --ne "panele gir; sonra anahtarı üret ve bana ver" --nicin-sen "$G_NICIN" \
   --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
[ $? -eq 1 ] && ok "K6 çok-eylem → RED (adım-kartına böl)" || kotu "K6 çok-eylem kaçtı"

SAHTE="ghp_$(printf 'a%.0s' $(seq 1 30))"
kos ac "Sirli Kart" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$SAHTE" --bitince "$G_BIT" >/dev/null 2>&1
[ $? -eq 1 ] && ok "K7 sır-deseni → RED" || kotu "K7 sır kaçtı"

kos ac "Uzun Kart" --ne "$(printf 'x%.0s' $(seq 1 300))" --nicin-sen "$G_NICIN" \
   --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
[ $? -eq 1 ] && ok "K8 uzunluk → RED" || kotu "K8 uzunluk kaçtı"

# RED yollarında dosya KİRLENMEDİ mi (fail-closed kanıtı)
[ ! -s "$KAPIMDA_DOSYA" ] || ! grep -q "🚦 SENDE" "$KAPIMDA_DOSYA" 2>/dev/null \
  && ok "RED yolları dosyaya HİÇ yazmadı (fail-closed)" || kotu "RED yolu dosyayı kirletti"

# ── mutlu yol ────────────────────────────────────────────────────────────────
kos ac "Kasa Erisimi" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$G_YAP" --bitince "$G_BIT" \
   --yas "1 gündür bekliyor" --engel "iki iş hiç başlayamadı" >/dev/null 2>&1
[ $? -eq 0 ] && ok "M1 geçerli kart açıldı" || kotu "M1 geçerli kart açılmadı"
grep -qx "🚦 SENDE · Kasa Erisimi" "$KAPIMDA_DOSYA" && ok "M2 çizici sözleşmesi (satır-başı damga)" || kotu "M2 damga formatı yanlış"
grep -q "Niçin sen: $G_NICIN" "$KAPIMDA_DOSYA" && ok "M3 dört alan yazıldı" || kotu "M3 alan eksik"
grep -q "1 gündür bekliyor · iki iş hiç başlayamadı" "$KAPIMDA_DOSYA" && ok "M4 yaş+engel satırı" || kotu "M4 yaş satırı yok"

# çizicinin gerçek grep'i kaç kart görüyor
[ "$(grep -cP '^🚦 SENDE · ' "$KAPIMDA_DOSYA")" -eq 1 ] && ok "M5 basla-çizicisi 1 kart görür" || kotu "M5 çizici sayımı yanlış"

kos ac "Kasa Erisimi" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
[ $? -eq 1 ] && ok "K4 aynı ad ikinci kez → RED" || kotu "K4 mükerrer ad açtı"

# ── K3 tavan ────────────────────────────────────────────────────────────────
kos ac "Ikinci Kart" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
kos ac "Ucuncu Kart" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
kos ac "Dorduncu Kart" --ne "$G_NE" --nicin-sen "$G_NICIN" --yapilmazsa "$G_YAP" --bitince "$G_BIT" >/dev/null 2>&1
[ $? -eq 1 ] && ok "K3 tavan-3 aşıldı → RED (sessiz sıraya atmaz)" || kotu "K3 tavanı deldi"
[ "$(grep -cP '^🚦 SENDE · ' "$KAPIMDA_DOSYA")" -eq 3 ] && ok "K3b dosyada tam 3 kart" || kotu "K3b kart sayısı yanlış"

# ── bitti ────────────────────────────────────────────────────────────────────
kos bitti "Kasa Erisimi" >/dev/null 2>&1
[ $? -eq 2 ] && ok "B1 --gerekce yoksa kapatmaz" || kotu "B1 gerekçesiz kapattı"
kos bitti "Kasa Erisimi" --gerekce "Sultan kasada kimliği açtı, blokaj düştü" >/dev/null 2>&1
[ $? -eq 0 ] && ok "B2 kart kapandı" || kotu "B2 kapatma düştü"
grep -q "^✅ KAPANDI .* · Kasa Erisimi" "$KAPIMDA_DOSYA" && ok "B3 KAPANDI damgası + tarih" || kotu "B3 damga yok"
grep -q "kapanış: Sultan kasada kimliği açtı" "$KAPIMDA_DOSYA" && ok "B4 gerekçe yazıldı" || kotu "B4 gerekçe yok"
[ "$(grep -cP '^🚦 SENDE · ' "$KAPIMDA_DOSYA")" -eq 2 ] && ok "B5 açık kart 3→2" || kotu "B5 sayım yanlış"
kos bitti "Olmayan Kart" --gerekce "x" >/dev/null 2>&1
[ $? -eq 1 ] && ok "B6 olmayan kartı kapatmaya çalışınca RC=1 (sessiz başarı yok)" || kotu "B6 hayalet kapatma"

# ── liste + lint ─────────────────────────────────────────────────────────────
kos liste 2>/dev/null | grep -q "Ikinci Kart" && ok "L1 liste açık kartları basar" || kotu "L1 liste yanlış"
kos lint >/dev/null 2>&1; [ $? -eq 0 ] && ok "L2 lint temiz dosyada RC=0" || kotu "L2 lint yanlış kırmızı"

# ── adım motoru ──────────────────────────────────────────────────────────────
kos adim ekle "Ikinci Kart" --yapilacak "panele gir" --nerede "kasa paneli" --bitince "girdim de" >/dev/null 2>&1
kos adim ekle "Ikinci Kart" --yapilacak "yeni kimlik oluştur" --nerede "aynı sayfa" --bitince "oluşturdum de" >/dev/null 2>&1
[ -f "$T/adim/Ikinci Kart.md" ] && ok "A1 adım planı diske yazıldı" || kotu "A1 plan yok"
grep -q "^toplam: 2" "$T/adim/Ikinci Kart.md" && ok "A2 toplam sayacı" || kotu "A2 sayaç yanlış"
OUT="$(kos adim goster "Ikinci Kart" 2>&1)"
printf '%s' "$OUT" | grep -q "adım 1/2" && ok "A3 SIRADAKİ tek adım basıldı" || kotu "A3 adım gösterimi yanlış"
printf '%s' "$OUT" | grep -q "yeni kimlik" && kotu "A4 iki adımı birden bastı (L39 ihlali)" || ok "A4 yalnız TEK adım basıldı"
kos adim ilerle "Ikinci Kart" >/dev/null 2>&1
kos adim goster "Ikinci Kart" 2>&1 | grep -q "adım 2/2" && ok "A5 ilerle sıradakine geçti" || kotu "A5 ilerleme yanlış"
kos adim ilerle "Ikinci Kart" 2>&1 | grep -q "tüm adımlar bitti" && ok "A6 son adımdan sonra TAMAM" || kotu "A6 bitiş yanlış"
kos adim ekle "Yollu Adim" --yapilacak "şu dosyayı düzenle: /config/x.md" --nerede "editör" --bitince "oldu de" >/dev/null 2>&1
[ $? -eq 1 ] && ok "A7 adım metninde yol → RED" || kotu "A7 adımda yol kaçtı"

echo; echo "── SONUÇ: $gecti geçti · $dustu kaldı ──"
[ "$dustu" -eq 0 ]
