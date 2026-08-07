# Çekirdek sözleşme (filo geneli — pazarlık yok)

*Bu bölüm becerinin içinde yaşar ve her prompta **kendiliğinden** girer. Kutu doldurmaz, seçmez,
kopyalamaz. Aşağıdaki kurallar tek bir renk/font/sayı içermez — onlar markanın işidir.*

Bu ayrımın sebebi ölçülmüş: aynı kural filoda üç ayrı kopyaya bölündüğünde kopyalar bayatladı ve
hangisinin geçerli olduğu görünmez oldu. Kural tek yerde yaşar; **değer** kutuda yaşar.

---

## Ç1 · Çıktı sözleşmesi

1. **Tek dosya.** Dış kaynak yok: CDN, uzak font, ikon kütüphanesi, uzak resim. İkon gerekirse
   satır içi çizim ya da metin işareti.
2. **Betik yalnız görsel durum için** (panel aç/kapa, sekme). Veri çekme, ağ çağrısı, kalıcı
   durum yok.
3. Her bileşenin ilk elemanı `<!-- bilesen: Ad -->` yorumunu taşır (bkz Ç2).
4. **Örnek veriler uydurmadır** ve gerçek kişiyle karışmayacak biçimde işaretlenir. Kişisel
   görünen alanlar maskeli.
5. Ürünün bir durum kümesi varsa **hepsi** örnekte görünür — yalnız mutlu hâl çizilmez.
6. Hedef genişlikte doğru görünür; dar ekran davranışı markanın iskelet bölümünde tanımlıdır.

## Ç2 · İşaret standardı — tutarlılık nasıl grep'lenir

Filoda **tek** işaret vardır: `<!-- bilesen: Ad -->`. İkinci bir işaret sistemi (öznitelik, sınıf
adı, ayrı yorum biçimi) icat edilmez — iki işaret = iki gerçek = drift.

İşaret **süs değil ölçüm yüzeyi**: yoğunluk ve tutarlılık kapıları bu yorumları sayar. İşaretsiz
bir bileşen kapı için **yok** hükmündedir.

Sözlük dışı ad sessizce icat edilmez. Gerçekten yeni bir şey gerekiyorsa model onu **bildirir**,
sonra markanın sözlüğüne eklenir.

## Ç3 · Çekirdek bileşen adları

Hemen her üründe çıkan on ad. Ürünün işi bu adlardan birine uyuyorsa **o ad kullanılır**;
uymuyorsa marka sözlüğüne yeni ad eklenir — eşanlamlı ikinci bir ad açılmaz.

`Gezinme` · `Sayfa Başlığı` · `Liste Satırı` · `Form Alanı` · `Düğme` · `Onay Diyaloğu` ·
`Yan Panel` · `Bilgi Şeridi` · `Boş Durum` · `Durum Rozeti`

## Ç4 · Yoğunluk kuralları (sayı YOK — sayılar markada)

1. **Bir ekranda tek birincil eylem.** İki birincil düğme yan yana konmaz.
2. **Tek dikkat kanalı:** aynı anda tek öğe bağırır. Her şey vurguluysa hiçbir şey vurgulu değildir.
3. **Önem ≠ büyüklük.** Bir öğenin alanı, taşıdığı bilginin değeriyle orantılıdır; dekoratif
   büyütme yasaktır.
4. **Blok türü bütçesi vardır** ve markada sayıyla verilir. Bütçe koşulsuz gövde içindir; koşullu
   yüzeyler (panel, diyalog, varyant) ayrı sayılır.
5. **Yarım özellik çizilmez:** veri modelinde karşılığı olmayan alan tasarımda görünmez.
6. Aynı bilgi iki yerde iki farklı biçimde gösterilmez.

## Ç5 · Kontrast — ÖLÇÜLÜR, tahmin edilmez

Metin/zemin ve her durum rozeti için kontrast oranı **hesaplanır**; erişilebilirlik eşiğinin
(4.5:1) altında kalan renk değiştirilir ve ölçüm sonucu marka dosyasına yazılır.

> "Yeterli görünüyor" bir ölçüm değildir. Ölçülmemiş kontrast, **ölçülmemiş** olarak raporlanır —
> "temiz" olarak değil.

## Ç6 · Dondurma kuralı

Sözleşme **ilk sayfadan sonra dondurulur**. Sonrasında yalnız *ekleme* yapılır (bildirilmiş yeni
bileşen gibi) ve her ekleme markanın değişiklik günlüğüne gerekçesiyle yazılır.

Renk, tipografi ya da iskelet değişirse **önceki sayfalar bayatlar** — o hâlde ya değişiklikten
vazgeçilir ya önceki sayfalar yeniden üretilir. Sessizce ikisinin arasında kalınmaz.
