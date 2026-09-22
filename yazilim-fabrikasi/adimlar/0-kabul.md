# 0 · KABUL — iş kartı ve sınıf

İş, kartı yazılmadan başlamaz. Kart dört satırdır ve işin yanında yaşar (PR gövdesinin başı; F3'te araç yazacak):

```
İŞ: <tek cümle, Sultan-dilinde>
KİM İSTEDİ: <Sultan | reis | mektup ref>     KİM ALDI: <ajan>     NE ZAMAN: <YYYY-MM-DD HH:MM>
SINIF: <yok | geri-alınamaz | para | dış-yüzey | yetki>     → SULTAN'A GİDER: <evet/hayır>
KANIT NEREDE OLACAK: <_agents/fabrika/kanit/<iş>/ | ölçüm çifti | kare>
```

## Sınıf — dört soru, biri "evet" ya da "emin değilim" ise Sultan'a gider
1. **Geri alınamaz mı?** (silme · göç · prod veritabanı · yayın geri alınamıyorsa)
2. **Para mı?** (abonelik · ödeme · faturalama · kota satın alma)
3. **Dış yüzey mi?** (müşterinin/dışarının gördüğü sayfa, mesaj, e-posta, marka)
4. **Yetki genişletiyor mu?** (yeni erişim · anahtar · kanca · filo-ortak ayar)

**Şüphede sınıf yukarı.** Yanlış tarafta hata yapılacaksa fazla sormak tarafında yapılır. Canlı vaka (21 Eyl):
görünüm değişikliği "kusur düzeltmesi" sanılıp peşin onayla yayınlandı; Sultan "bozulmuş" dedi.
"Bu dış yüzey mi, iç mi" tereddüdü = dış.

## Sınıfsız iş
Ekipte biter: kanıt + bağımsız göz puanı + damga ile deftere girer; gün sonu özetinde "içeride bitirdiklerimiz"
bölümünde görünür. Sultan sonradan "bunu bana sormalıydınız" derse sınıf kuralı o vakayla düzeltilir.

## Tetikli mesaj
Kart açılınca ilgili odaya `oda-tetik` ile tek satır (var olan hat, L42): "<iş> alındı · sahip <ajan> · sınıf <x>".
Kart kapanınca aynı hattan "bitti · kanıt <yol> · puan <n>/5 <E/H>".

## Sahiplik ve tıkanma
- Bir işin tek sahibi olur; sahibi değişirse kart güncellenir (eski sahip yazar, yeni sahip onaylar).
- Tıkanma = 3 mektup cevapsız **ya da** 24 saat ilerlemeyen iş → reis → SERDAR (yalnız kutular-arası) → Sultan.
