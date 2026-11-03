# Senaryo kartı — pazaryeri-mesaj (NARH · Dümen · Amazon + Trendyol müşteri mesajları)

Bu iş bir komut akışıdır: NARH'ın terminali + Sultan'ın görev ekranı. "Dış yüzey" = müşteriye giden cevap.
Tık sayım kuralı: ui-tasarim-akisi Durak 2 (1 tık = tıklama/dokunma · 1 alan = klavye girişi · 1 komut = terminalde tek satır).

## Kanonik görevler — tık bütçesi

| # | Görev | Kim | Hedef | Gerçekleşen |
|---|---|---|---|---|
| G1 | Yeni müşteri mesajlarını gör (Amazon + Trendyol) | NARH | 1 komut | *(ilk gerçek turda dolar)* |
| G2 | Bir mesaja cevap taslağı yazıp Sultan'a sun | NARH | 1 komut | |
| G3 | Taslağı onayla / düzelt / reddet | Sultan | 1 tık ya da 1 alan | |
| G4 | Onaylı cevabı gönder | NARH | 1 komut | |

### E1 · NARH terminali — mesaj okuma ve gönderme akışı

**Amaç:** Dümen'deki açık satıcı oturumlarından (Amazon Seller Central, Trendyol partner paneli) cevaplanmamış müşteri mesajlarını okumak, cevap taslağını Sultan'ın onayına sunmak ve yalnız onaylı cevabı göndermek.
**Giriş:** NARH koltuğunda tek komut (`mesaj-oku`); Dümen ajanda değilse komut "⏸ Dümen Sultan'da" der ve bekler — açılış ekranından 1 komut.
**İlk bakışta:** (1) kaç cevapsız mesaj var, pazar başına; (2) her mesajın sohbet kimliği (kısaltılmış) ve son mesajın özeti; (3) Dümen'in kimde olduğu; (4) Amazon'da gönderme kapalıysa o uyarı. Müşteri adı, telefon, adres HİÇ görünmez (KVKK).
**Ana akış:** 1. `mesaj-oku` → cevapsız mesajlar listelenir. 2. `taslak <sohbet> "<metin>"` → görev defterine 'sıra sende · onay' kaydı açılır (Sultan'ın görev ekranına düşer). 3. Sultan görev ekranında onaylar (1 tık) ya da düzeltir (1 alan). 4. `gonder <sohbet> --onay <damga>` → Dümen'de cevap alanı doldurulur, gönder düğmesine basılır, defterde sohbet 'cevaplandı' olur.
**Tık bütçesi:** NARH 3 komut (oku · taslak · gönder) + Sultan 1 tık (onay) · mesaj başına. Dümen Sultan'dayken 0 tık (kapı kendiliğinden bekler).
**Kenar durumlar:** cevapsız mesaj yok → "0 cevapsız" satırı, komut 0 ile biter · oturum kapalı (giriş sayfası) → "giriş lazım, Sultan Dümen'de açsın", parola asla yazılmaz · Dümen Sultan'da → bekler, ajan eylemi yapmaz · onay damgası yok ya da başka sohbete ait → gönderme reddedilir (rc 2) · Amazon'da risk kararı yokken `gonder` → reddedilir, taslak durur · sayfa yapısı tanınmadı (seçici bulunamadı) → "ÖLÇÜLEMEDİ" (rc 3), bulgu yazılır.
**Kısıt kancaları:** ajan parola/SMS/kod/ödeme alanına yazmaz · onaysız tek mesaj gitmez · müşteri kişisel verisi hiçbir kütüğe/defter kaydına/kareye girmez (sohbet kimliği + özet yeter) · Sultan'ın sekmesine dokunulmaz (yeni sekme) · insan hızı (3–8 sn aralar, günde tavan) · ürün/ilan/sipariş değiştirme YOK, yalnız mesaj.
