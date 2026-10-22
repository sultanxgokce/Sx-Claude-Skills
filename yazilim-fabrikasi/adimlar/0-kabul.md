# 0 · KABUL — iş kartı ve sınıf

İş, kartı yazılmadan başlamaz. Kart dört satırdır ve işin yanında yaşar (PR gövdesinin başı; F3'te araç yazacak):

```
İŞ: <tek cümle, Sultan-dilinde>
KİM İSTEDİ: <Sultan | reis | mektup ref>     KİM ALDI: <ajan>     NE ZAMAN: <YYYY-MM-DD HH:MM>
SINIF: <yok | geri-alınamaz | para | dış-yüzey | yetki>     → BAŞLAMA İZNİ: <gerekmiyor | Sultan (veto)>
KANIT NEREDE OLACAK: <_agents/fabrika/kanit/<iş>/ | ölçüm çifti | kare>
```

## Sınıf — dört soru, biri "evet" ya da "emin değilim" ise BAŞLAMA İZNİ Sultan'a gider (veto penceresi)
1. **Geri alınamaz mı?** (silme · göç · prod veritabanı · yayın geri alınamıyorsa)
2. **Para mı?** (abonelik · ödeme · faturalama · kota satın alma)
3. **Dış yüzey mi?** (müşterinin/dışarının gördüğü sayfa, mesaj, e-posta, marka)
4. **Yetki genişletiyor mu?** (yeni erişim · anahtar · kanca · filo-ortak ayar)

**Şüphede sınıf yukarı.** Yanlış tarafta hata yapılacaksa fazla sormak tarafında yapılır. Canlı vaka (21 Eyl):
görünüm değişikliği "kusur düzeltmesi" sanılıp peşin onayla yayınlandı; Sultan "bozulmuş" dedi.
"Bu dış yüzey mi, iç mi" tereddüdü = dış.

## Sınıflı iş — başlama izni Sultan'ın, kararlar reisin (0.18.0 · Sultan D1 22 Eki 2026)
**Kural metni BURADA yaşar; betik başlıkları ve SKILL tablosu buraya atıf yapar, cümleyi kopyalamaz.**
Sultan'ın sözü (session_01Ge4BawKcUrcm1pdV8WANyF): *"sadece ara kararlar değil birleştirme kararları da reise geçsin çünkü
ciddi sorun yaşıyoruz çok iş takılıyor"*. Ölçüm: bağımsız gözden geçen işler ayda **1.138 saat** bekledi; 22 Eki'de sorulan
12 kararın **12'sinde** Sultan ajan önerisini seçti.
- **Başlama izni Sultan'a gider, iş bekletilmez.** `kart.sh ac` sınıflı kartta `baslama_izni: bekliyor` yazar ve bunu söyler
  (tetik/oda varsa oraya da). İş alanı açılır, iş yürür. İzin bir **VETO PENCERESİ**dir: Sultan `kart.sh sultan-dedi <iş>
  --karar dur` derse kapı birleştirmeyi reddeder, denetçi tur koşmaz, reis durur; `--karar basla` karta işlenir; hiçbir şey
  demezse iş reis kararlarıyla biter. Son basla/dur kazanır (dur = veto, sonraki basla vetoyu kaldırır).
- **Ara kararlar (devam · daralt · geri-al · canlı borç) ve BİRLEŞTİRME kararı kutu reisinindir** — gerekçeli (≥20 karakter),
  `kart.sh reis-dedi` ile karta yazılır (kart = defter; gün sonu özeti oradan üretilir, Sultan'ın veto hakkı oradadır).
  `kart.sh bitti` birleştirme kararını `birlestirme_karari{karar_veren: reis}` olarak karta işler.
- **Dağıtım / canlıya alma Sultan eli olarak KALIR** (sabah paketi, dar anahtar) — bu kuralın dışıdır.
- **A06 korunur:** ajan Sultan adına söz ÜRETMEZ; `sultan-dedi` yine oturum-ref · kırpık · beyan ister. Reis kararı AYRI
  alandır (`reis_kararlari`, sınıflıda `sinifli: true`), hiçbir çıktıda Sultan sözü gibi gösterilmez.
- **Geriye uyum:** eski kart (alan yok) "bekliyor · veto yok" sayılır; eski Sultan devam/daralt/canli-borc kararları geçerli
  kalır ama artık ŞART değildir; `sultan` alanı "sınıflı" anlamına daralır, silinmez.
- **Eski kural (0.17, 21 Eyl–22 Eki):** sınıflı işin ara ve birleştirme kararı Sultan'ındı; ajan `sultan-dedi` olmadan
  daraltamıyor, borç yazamıyor, reis-dedi reddediliyordu. Neden değişti: yukarıdaki ölçüm — işler Sultan'ın kapısında bekledi.

## Sınıfsız iş
Ekipte biter: kanıt + bağımsız göz puanı + damga ile deftere girer; gün sonu özetinde "içeride bitirdiklerimiz"
bölümünde görünür (sınıflı bitenler de orada "reis birleştirdi · izin: …" etiketiyle). Sultan sonradan "bunu bana
sormalıydınız" derse sınıf kuralı o vakayla düzeltilir.

## Tetikli mesaj
**Görev bağı (0.11.0):** iş defterde bir göreve karşılık geliyorsa kartı ona bağla: `kart.sh ac … --gorev gorev_<kimlik> --tahmin <dk>`. Açılışta görev "çalışılıyor" olur, bitince "onay bekliyor", tıkanınca "bekliyor" — Sultan'ın "çalışılıyor" ekranı bunu okur. Bağsız kart o ekrana düşmez.

**Kapsam = teslim birimi** (retro W42 ders M2): kart tek depoda, tek PR'da, bir günde teslim edilecek kadar olsun. `kart.sh ac` cümlede iki depo adı ya da haftalık kapsam görürse UYARIR (red değil) ve depo başına / gün başına kart önerir; uyarı karta da yazılır.

Kart açılınca ilgili odaya `oda-tetik` ile tek satır (var olan hat, L42): "<iş> alındı · sahip <ajan> · sınıf <x>" — sınıflı
işte "· başlama izni bekleniyor (veto penceresi)" eklenir; Sultan'ın tek görünürlüğü bu satır ve gün sonu özetidir.
Kart kapanınca aynı hattan "bitti · kanıt <yol> · puan <n>/5 <E/H>".

## Sahiplik ve tıkanma
- Bir işin tek sahibi olur; sahibi değişirse kart güncellenir (eski sahip yazar, yeni sahip onaylar).
- Tıkanma = 3 mektup cevapsız **ya da** 24 saat ilerlemeyen iş → reis → SERDAR (yalnız kutular-arası) → Sultan.
