# plan-motor · kanıt defteri

> Kanıtsız-yeşil yasak: buradaki her hüküm kırpılmamış çıktı + çıkış koduyla bağlıdır.
> Ölçüm ortamı: Linux konteyner, node v22.23.2, npm 10.9.8, sudo YOK, gcc YOK, sistem fontu YOK.
> (Proje-özel ölçümler tüketici projede kalır; burada yalnız MOTORUN kanıtı vardır.)

## Yetenek kanıtları

| Yetenek | Nasıl kanıtlandı |
|---|---|
| **DWG okuma** | Üç ayrı gerçek AutoCAD 2018 (AC1032) dosyası, dosyaya özel kod yazılmadan okundu: 214 / 959 / 140 nesne, 5–7 katman, cm birimli. |
| **Okuma güvenilirliği** | Aynı dosya iki bağımsız MIT kütüphaneyle okundu (`@node-projects/acad-ts` ve `dwgdxf`→`dxf-parser`); altı çekirdek entity sınıfının altısı da **birebir aynı** sayımı verdi (695/206/16/1/12/57). |
| **Gösterim kalitesi** | Çıktı, aynı dosyanın AutoCAD'den alınmış PDF çıktısıyla karşılaştırıldı: gri duvar gövdeleri, siyah kolonlar, gerçek kapı yayları, pencere sembolleri — aynı sınıf. |
| **Ölçüm doğruluğu** | Lifting ile çıkarılan oda alanı, çizimin KENDİ metin etiketiyle karşılaştırıldı: en büyük hacimde **27,18 m² ölçüldü ↔ etiket 27**. |
| **Ölçüm tutarlılığı** | Bir plan ve onun revize edilmiş hali ayrı ayrı ölçüldü; toplam alan **79,75 ↔ 80,54 m²** çıktı (fark yalnız kalkan iç duvarlardan) — hayali alan kazancı yok. |
| **Revizyon** | `--duzenle` tarifiyle bir bölme duvarı 70 cm kaydırıldı; iki komşu hacim **20,53→18,60** ve **4,95→6,81 m²** olarak yeniden ölçüldü (toplam korundu). |
| **Determinizm** | Aynı girdi iki koşuda **aynı sha256** SVG üretti. |
| **Fail-closed** | Kapanmayan oda · beyan↔hesap çelişkisi · bayat revizyon · kusurlu render — dördünde de `rc=1` ve **çıktı dosyası oluşmadı** (dosya varlığı ayrıca sınandı). |

## Bulunan üç sessiz kusur sınıfı (hepsi hata VERMEDEN yanlış çizim üretiyordu)

1. **`isClosed` kapanış kenarı düşürülüyordu.** Ölçülen dosyada 153 polyline'ın **74'ü kapalıydı**;
   her birinde son→ilk kenar atlanınca kolon ve duvar gövdeleri bir kenar eksik kaldı, ızgara
   boyaması kolonun *içinden* sızdı. Belirti (odaların birleşmesi) sebebe hiç benzemiyordu;
   kaçak yolu izlenerek bulundu. → `lib/cad-cikar.mjs`, `lib/cad-render.mjs`
2. **`bulge` yok sayılıyordu.** 14 köşe yay taşıyordu (hepsi açıklık katmanında); yayın kirişi
   çizildiği için kapılar üçgen görünüyordu. → `lib/cad-render.mjs:yayKomutu()`
3. **Yüzler işarete göre eleniyordu.** `alan > 0` süzgeci dış duvar bantlarının yarısını sessizce
   düşürüyordu (22 gövde bulunuyordu, gerçekte 29'du). Ölçüt mutlak alana çevrildi.

Ayrıca: *"px_walls'ta bir tane bile kapalı poligon varsa gövde çıkarımını atla"* kuralı yanlıştı —
bir dosyada 47 duvarın 8'i kapalı, 39'u açıktı ve o 39'u dolgusuz bıraktı. Ölçüt **hepsi kapalı mı**
oldu ve öz-denetime kural eklendi.

📌 **Kalıcı ders:** yanlış çizim hata vermez, sadece yanlış görünür. Bu kusur sınıfına karşı tek
savunma kuralı makineye bağlamaktır — `lib/render-denetle.mjs` bu yüzden vardır ve bilerek
bozulmuş çıktılarla sınanmıştır (üç kusurun üçünü de yakaladı).

## Bilinen sınırlar (dürüst)

- **DWG YAZILAMAZ.** Okunur, çizilir, ölçülür; ama DWG üretilemez (DXF üretilir, o da zayıf yol).
- Yalnız eksen-hizalı geometri; eğik/yaylı duvar desteklenmez.
- Lifting yarı-otomatik: yakalanamayan kapı ağzı `ek_muhur` ile elle beyan edilir.
- Katman adları girdi konvansiyonuna bağlı (`BICIM` tablosu) — farklı bir bürodan gelen dosya eşleme ister.
- Üretilen DXF gerçek AutoCAD'de henüz açılıp GÖZLE doğrulanmadı.
- Model ile ham-CAD iki ayrı iç temsildir ve **birbirine bağlı değildir** (bkz. `DEVIR.md` açık soru 1).
