# Kullanıcının beğendiği katalog arayüzü

Bu tarif, kullanıcının açıkça “bu arayüz düzenine bayıldım” dediği ilk AKAR broşür/sunum/web referans kataloğunu korur. Bir örnek stil önerisi değil, bu kullanıcı için varsayılan tasarım tercihidir. Farklı bir talimat gelmediğinde sonraki kütüphanelerde aynı düzeni uygula.

## Ekranın kompozisyonu

```text
┌─────────────────────────────────────────────────────┐
│ KOYU YEŞİL ÜST ALAN                                  │
│ Küçük, harf aralıklı koleksiyon etiketi               │
│ Büyük beyaz başlık                                   │
│ Kısa ve sakin açıklama                               │
│ 55 broşür       50 sunum       50 web sitesi           │
├─────────────────────────────────────────────────────┤
│ Arama alanı                         Kategori filtresi│
├─────────────────────────────────────────────────────┤
│ 155 örnek gösteriliyor                               │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐    │
│ │   ÖNİZLEME   │ │   ÖNİZLEME   │ │   ÖNİZLEME   │    │
│ ├──────────────┤ ├──────────────┤ ├──────────────┤    │
│ │ Tür etiketi  │ │ Tür etiketi  │ │ Tür etiketi  │    │
│ │ Başlık       │ │ Başlık       │ │ Başlık       │    │
│ │ Kısa not     │ │ Kısa not     │ │ Kısa not     │    │
│ │ Dosya Kaynak │ │ Dosya Kaynak │ │ Dosya Kaynak │    │
│ └──────────────┘ └──────────────┘ └──────────────┘    │
│ …                                                   │
├─────────────────────────────────────────────────────┤
│ Sade arşiv/kullanım dipnotu                           │
└─────────────────────────────────────────────────────┘
```

Sayılar örnektir: gerçek koleksiyondan hesapla. İlk katalog üç içerik grubunu sayıyordu; yeni koleksiyonda anlamlı kategori toplamları veya kayıt/kategori/dosya toplamları kullanılabilir. Kolon sayısı ekran genişliğine göre değişir.

## İlk arayüzden ölçüler ve renkler

| Öğe | Beğenilen düzenin değeri |
|---|---|
| Sayfa zemini | Sıcak kırık beyaz `#f4f3ef` |
| Üst alan | Koyu yeşil `#143c37` |
| Ana metin | Koyu, yeşile yakın `#182626` |
| Üst küçük etiket | Açık yeşil `#bae0a3`, 3 px harf aralığı |
| Üst açıklama | Yumuşak açık renk `#d5e4dc`, 1.7 satır yüksekliği |
| Yatay sayfa boşluğu | Ekranın yaklaşık %6'sı |
| Üst alan iç boşluğu | Üstte 54 px, altta 42 px |
| Ana başlık | 32–58 px arasında duyarlı, yaklaşık −2 px harf aralığı |
| İstatistikler | 27 px kalın sayılar, aralarında yaklaşık 35 px |
| Filtre çubuğu | Açık yarı saydam zemin, 20 px dikey boşluk; geniş ekranda üstte sabitlenir |
| Girdi ve seçim alanları | Beyaz, ince kenarlık, 8 px köşe, yaklaşık 12 px iç boşluk |
| Kart ızgarası | Kart başına en az yaklaşık 290 px, 24 px aralık |
| Kart | Beyaz yüzey, ince `#e2e3db` kenarlık, 13 px köşe |
| Önizleme alanı | Yaklaşık 225 px yüksek, `#e8eae5` fon, 14 px iç boşluk |
| Önizleme görüntüsü | Oranları korunur; tamamı görünür; hafif gölge |
| Kart metin alanı | Yaklaşık 20 px iç boşluk |
| Kategori/tür etiketi | 11 px, küçük hiyerarşi, harf aralıklı |
| Kart başlığı | 20 px; açıklamadan belirgin ama üst başlıkla yarışmaz |
| Kart notu | 14 px, sakin gri-yeşil, 1.6 satır yüksekliği |
| Aksiyonlar | Kartın altında; 13 px, ince kenarlı küçük düğmeler |
| Birincil aksiyon | Koyu yeşil dolgu ve beyaz metin |
| İkincil aksiyon | Beyaz zemin, yeşil yazı ve ince kenarlık |
| Yazı tipi | Sistem fontu; harici font bağımlılığı yok |

Ölçüler tasarımın karakterini koruyan başlangıç değerleridir. Dar ekran, uzun başlık veya erişilebilirlik için uyarlanabilir; metin sığsın diye okunamayacak kadar küçültülmez.

## Arayüzün hissi

Sakin, kurumsal, ferah ve önizleme odaklı. Dosya sayısı fazla olsa da görsel gürültü yaratmaz. Koyu üst alan koleksiyona kimlik verir; açık içerik alanı uzun süre taramayı kolaylaştırır. Görseller başroldedir; etiket ve düğmeler ikinci planda kalır.

Kartların farklı dosya oranları nedeniyle dağılmasını önlemek için önizleme alanları eşit yüksekliktedir. Belge kapakları kırpılmaz. Kart gövdeleri esner ve aksiyonlar alta yaslanır. Farklı uzunluktaki başlıklarda da tutarlı bir ızgara elde edilir.

## Değişebilen ve korunacak noktalar

**Konuya göre değiştir:** koleksiyon adı, açıklama, kategori isimleri, sayılar, filtreler, kaynak türleri, kart notları ve önizlemeler. Ek detay penceresi veya sıralama gerekli olduğunda eklenebilir.

**Varsayılan olarak koru:** renk dengesi, geniş boşluklar, büyük üst başlık, yatay araç çubuğu, önizleme ağırlıklı kartlar, kart içindeki bilgi sırası ve sade kaynak/dosya aksiyonları.

**Açıkça istenmedikçe ekleme:** sol menü, çok katmanlı gezinme, gösterişli animasyon, dev ikonlar, dekoratif grafikler, neon renkler, yoğun gölgeler veya kartlar yerine ana görünümü kaplayan veri tablosu.

## Tasarım kontrol sorusu

Teslim öncesinde şunu değerlendir: “Bu katalog, kullanıcının beğendiği ilk arayüzün aynı ailesinden mi görünüyor; yoksa yalnızca arama kutusu ve kart içeren başka bir tasarım mı?” İkinci durumdaysa özgün CSS ve bu tarifle yeniden hizala. Yeni markaya uyarlama istenmişse bu farkı bilinçli olarak uygula.
