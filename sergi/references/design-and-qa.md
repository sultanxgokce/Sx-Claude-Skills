# Görsel sistem ve teslim kontrolü

## Kullanıcının sevdiği deneyim

Bu becerinin çıkış noktası, dağınık dosyaları başlık, küçük önizleme, kategori, açıklama ve kaynak bağlantısıyla keşfedilebilir hale getiren yerel katalogdur. Alan değişebilir; kullanıcı önce koleksiyonu tarar, sonra ilginç bulduğu öğeyi açar.

- Başlıkta koleksiyonun amacı; hemen altında veriden hesaplanan kayıt ve kategori sayıları.
- Arama, kategori ve tür filtreleri görünür; sıfır sonuçta açık geri bildirim ve temizleme aksiyonu.
- Kartlarda aynı önizleme yüksekliği; farklı en-boy oranlarını kırpmadan `object-fit: contain` ile koru. Fotoğraf arşivlerinde kırpma gerekiyorsa tam görsele kolay erişim bırak.
- Başlık kısa ama ayırt edici; açıklama somut. Dosya, önizleme ve canlı kaynak bağlantıları ayrı adlandırılır.
- Detay penceresinde tam not, etiket, tarih ve lisans. Bilinmeyen veriyi “bilinmiyor” olarak sun veya gösterme.
- Varsayılan renkler: koyu yeşil `#143c37`, kırık beyaz `#f4f3ef`, açık yeşil `#bae0a3`. Bunlar marka zorunluluğu değildir.
- Sistem fontu, harici font/CDN yok. Küçük ekranda tek kolon. Klavye odağı belirgin, diyalog Escape ile kapanır.

## Gerçek kalite kontrolü

1. Açılmayan dosyayı sağlıklı bir örnek olarak sayma. PDF/sunum için kapak yanında farklı iç sayfalara bak; tamamı incelenmediyse tam inceleme iddia etme.
2. Web görüntüsünün hata sayfası, yüklenme ekranı veya büyük bir çerez penceresi olmadığını kontrol et. Ekran görüntüsü tarihini koru; canlı site sonradan değişebilir.
3. JSON sayımı, katalog kartları ve kopyalanmış asıl dosya sayıları arasındaki farkları açıkla. Yalnızca bağlantı içeren kayıt yerel dosya sayısını artırmaz.
4. Yerel dosya/önizleme bağlantılarını doğrula; bilinmeyen harici URL durumlarını “çalışıyor” diye işaretleme.
5. Tarayıcıda bilinen bir başlıkla arama, en az bir kategori/tür filtresi, sonuç vermeyen arama, sıralama, detay açma ve kapama işlemlerini kontrol et. Masaüstü ve dar ekranda taşma/örtüşme kontrolü yap.
6. Klasör taşınınca çalışmasını doğrula. Ana HTML tek başına gönderilmez; tüm klasör birlikte teslim edilir.
7. Orijinallere dokunulmadığını hash ile, hedefe kopyalama tamamlandıysa hedef kopyaları da karşılaştırarak doğrula.

## Alan uyarlama örnekleri

| Koleksiyon | Yararlı kategori/etiket | Kartta yararlı açıklama |
|---|---|---|
| Yazılım/satış referansları | satış, ürün, yatırımcı, sektör | Anlatım sırası, müşteri kanıtı, karşılaştırma düzeni |
| Araştırma | konu, yöntem, yayın yılı | Araştırma sorusu ve hangi işte kullanılacağı |
| Eğitim | konu, seviye, format | Ön koşul ve kazanım |
| Ürün kataloğu | ürün ailesi, kullanım alanı | Ayırt edici özellik ve doğrulanmış veri |
| Fotoğraf/video | proje, mekan, tarih | Çekimin bağlamı ve dosya kullanım durumu |
| Proje arşivi | müşteri, aşama, teslim türü | Hangi kararı veya teslimatı belgelediği |

Tarihi fiyatları güncel fiyat gibi sunma. Araştırma sonuçlarını yalnızca dosya adına bakarak özetleme. Hassas müşteri/proje verilerini demo veya genel skill paketine ekleme.
