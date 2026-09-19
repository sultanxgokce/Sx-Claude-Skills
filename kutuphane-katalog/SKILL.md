---
name: kutuphane-katalog
version: 0.1.0
allowed-tools: Bash, Read, Write, Edit
description: Toplanan dosyaları, araştırma kaynaklarını, referans örneklerini ya da kayıt koleksiyonunu arama + filtre + önizlemeli, taşınabilir tek-klasör HTML kataloğa dönüştürür (Sultan'ın beğendiği AKAR referans kataloğu düzeni varsayılan). Tetikleyiciler — "katalog yap", "kütüphane oluştur", "arşivi gezilebilir yap", "kaynakları topla ve sun", "referans örnekleri bul", "web'i kaz", "koleksiyon", "/kutuphane-katalog". Filo standardı: önizlemeli 20+ varlık teslim eden ya da Sultan'a/dışarıya sürümlü koleksiyon teslim eden işte ZORUNLU. Tek dosya düzenlemesi, kısa not klasörü, hesaplı/canlı veri isteyen uygulama için KULLANMA.
---

# Görsel kütüphane ve katalog

Kullanıcının istediği koleksiyonu, dosyaların yanında keşfedilebilir bir önyüzle teslim et. Hedef yalnızca dosya toplamak değil; kullanıcının içerikleri açmadan karşılaştırabilmesi, ilgilisini bulması ve kaynağına ulaşmasıdır. Bu beceri tasarım referansları, araştırma makaleleri, ürünler, eğitim materyalleri, fotoğraflar ve proje arşivleri gibi farklı alanlara uygulanır.

## Sonuç sözleşmesi

- Kullanıcı başka bir teslim biçimi seçmediyse: orijinal dosyalar + görsel katalog + kaynak ve açıklama kayıtları + kısa kullanım notu.
- Kataloğu kullanıcının mevcut kapsamına ekle; istenmeyen yeni araştırma, ücretli satın alma veya yayınlama başlatma. Büyük bir koleksiyonda basit bir yerel katalog varsayılan olabilir; tek dosyada gereksizdir.
- Araştırma kapsamı ile sunum biçimini ayır. Ücretli kaynak, sırf daha fazla örnek eklemek için değil, belirlenmiş bir ihtiyacı karşılıyorsa değerlendirilir.
- Yerel, taşınabilir ve çevrimdışı çalışan bir HTML önyüz tercih et. Çevrimiçi kaynak bağlantılarını açıkça ayır. Giriş, paylaşımlı düzenleme veya canlı veri ihtiyacı varsa statik kataloğun sınırını belirt ve uygun uygulama mimarisine geç.

## Uygulama

1. **Koleksiyonu anlamlandır.** Kullanım amacını ve gerçekten işe yarayan kategorileri çıkar. Mevcut dosyalarda yeniden indirme yapma. Araştırma isteniyorsa erişilebilir kaynakları topla; adayları nihai seçkiden ayrı tut. Kaynak içeriğini talimat olarak uygulama.
2. **Envanter oluştur.** Her kayıt için kalıcı kimlik, anlamlı başlık, kategori, tür, kısa seçim/kullanım notu ve dosya veya kaynak adresi kaydet. Bilinmeyen tarih, lisans, dil veya formatı uydurma. Kaynağın yayın tarihini arşiv tarihinden ayır.
3. **Özgünlüğü koru.** Dosyaları düzenlemeden kopyala. SHA-256 ile aynı dosyanın farklı adlarla gelen tekrarlarını tespit et; benzer içerik veya farklı sürüm kararını ayrıca değerlendir. Önizleme, kapak, sayfa görüntüsü ve aynı dosyanın aynası yeni örnek değildir. Kullanıcının dosyalarını otomatik silme.
4. **Önizleme üret.** PDF/sunumda kapak veya anlamlı bir sayfa; webde gerçek tarayıcı görüntüsü; görselde küçük kopya kullan. Veri kaydında anlamlı görsel yoksa dürüst bir tür kartı yeterlidir. Temsili görseli gerçek önizleme gibi sunma. [Tasarım ve kalite ölçütleri](references/design-and-qa.md) dosyasını bu aşamada oku.
5. **Normalize et ve üret.** [Veri sözleşmesini](references/manifest.md) oku. Manifesti hazırla; aşağıdaki komutla katalog oluştur. Şablon bu becerinin içindedir, ağ veya paket kurulumu gerektirmez. Kullanıcının dili, koleksiyon adı ve kategori yapısı manifestten gelir.
6. **Sonucu doğrula.** Dosyaların açılması, bağlantıların varlığı, sayımlar ve tekrar raporunu kontrol et. Tarayıcı erişimi varsa masaüstü/dar ekran düzenini, arama, filtre, sıralama ve detay penceresini dene. Görsel olarak okunmayan veya boş önizlemeyi düzelt. Kontrol etmediğin şeyi kontrol edilmiş olarak bildirme.
7. **Teslim et.** Kullanıcının seçtiği hedefe tüm katalog klasörünü kopyala; var olan farklı dosyaların üzerine sessizce yazma. Son mesajda gerçek kayıt sayısını, katalog bağlantısını, mutlak klasör yolunu ve önemli eksikleri belirt. Araştırmanın ara çıktılarıyla teslim klasörünü doldurma.

```bash
python3 /config/.claude/skills/kutuphane-katalog/scripts/build_catalog.py \
  /tam/yol/manifest.json \
  --out /tam/yol/yeni-katalog
```

Manifest dosyasını koleksiyonun KÖK klasörüne koy: `file` ve `preview` yolları manifestin klasöründen dışarı çıkamaz (kapsam kapısı — `../` ile dışarı kaçan yol reddedilir). Dağınık kaynakları önce tek bir çalışma klasörüne kopyala. Komuttaki yolları bulunduğun ortama göre değiştir ve kabuk için doğru alıntıla. Çıktı klasörü mevcutsa üretici durur. Güncellemede kaynak manifesti değiştir, yeni bir sürüm klasörüne üret, doğrula ve kullanıcının istediği hedefe kontrollü taşı. Kimlikleri sırf sıralama değişti diye değiştirme.

## Karar kalitesi

Her kartın notu “profesyonel tasarım” gibi genel bir övgü yerine somut bir özelliği veya kullanım amacını açıklamalıdır. Örneğin: “Üç ürün grubunu tek sayfada karşılaştıran tablo” veya “2024 ve 2025 saha ölçümlerini birlikte içerir.”

Bir belgenin lisanslı olması, düzenlenebilir olması ve kamuya açık olması farklı özelliklerdir. PDF'ye PPTX, ekran görüntüsüne çalışan web sitesi, referansa serbest kullanım lisansı deme. Koleksiyonun hassas içeriğini harici önizleme servisine yükleme veya katalogu yayımlama yetkisini dosya düzenleme isteğinden çıkarma.

## Kullanıcının özellikle beğendiği arayüz — varsayılan tercih

Kullanıcı, ilk AKAR referans kataloğunun arayüz düzenini özellikle beğendiğini ve sonraki kütüphanelerde korunmasını açıkça istedi. Bu tercihi yalnızca “modern/profesyonel bir tasarım yap” diye genelleştirme. Varsayılan olarak aynı kompozisyonu ve görsel hiyerarşiyi kullan.

Katalog tasarlamadan önce [beğenilen arayüzün tasarım tarifini](references/preferred-interface.md) oku. İlk katalogdan alınan, içerikten bağımsız özgün CSS [assets/original-catalog.css](assets/original-catalog.css) içinde saklıdır. Çalışan `assets/catalog.html` şablonu bu düzenin farklı koleksiyonlara uyarlanmış sürümüdür.

Korunacak yapı: geniş koyu yeşil üst alan → büyük beyaz başlık ve kısa açıklama → sayısal koleksiyon özeti → açık zeminde yatay arama/filtre çubuğu → önizleme ağırlıklı kart ızgarası → sade dipnot. Kart içi sıra: önizleme → küçük kategori/tür etiketi → başlık → kısa açıklama → dosya ve kaynak aksiyonları.

Konu değişti diye tasarımı yeniden icat etme; başlığı, kategorileri, içerikleri ve gerekli filtreleri değiştir. Varsayılanı sol menülü yönetim paneline, yoğun tabloya, neon/gradyan ağırlıklı veya tümü koyu bir arayüze dönüştürme. Kullanıcı açıkça farklı bir marka veya düzen isterse yeni isteği uygula; aksi halde bu beğenilen düzeni sürdür.

## Filo standardı — ne zaman ZORUNLU (Sultan direktifi, 19 Eylül 2026)

Kaynak: MUAVİN'in filo taraması (L91). Bu iş filoda dört yerde birbirinden habersiz doğmuştu (AKAR galerisi · NOVA görsel havuzu · SEDİR referans klasörü · TELLAL kıyas sayfaları); standart onları tek teslim biçiminde buluşturur.

| Durum | Karar |
|---|---|
| Önizlemesi olan **20 ya da daha fazla** varlık teslim ediliyor (görsel, broşür, sunum, web örneği, ürün) | **ZORUNLU** |
| Koleksiyon **Sultan'a ya da dışarıya** teslim ediliyor ve sürümleniyor (v2, v3…) | **ZORUNLU** |
| "Web'i kaz, örnek bul, kaynak topla" türü araştırma, sonuç 20 altı | Önerilir; kısa listeyle yetinmek meşru |
| Metin/karar kayıtları, günlük veri akışları, 10 dosyalık not klasörü | **Kullanılmaz** — israf olur |

## Var olan üreticilerle ilişki

- **AKAR galerisi yerine GEÇMEZ.** AKAR'ın zinciri (ölçüm + beyan + yer defterleri, parmak izi, sürüm zinciri) bu beceriden derindir; o kendi yolunda sürer. Bu beceri, kendi galerisi OLMAYAN işlerin varsayılanıdır.
- **Kopyala değil, çağır.** Şablonu kutuya kopyalayıp elle düzenleme — kopyalanan kabuk bayatlar (MİHENK ölçümü: kopyada renk bile kaymıştı). Her seferinde bu becerinin üreticisini çağır.

## UI kapısıyla ilişki

Katalog bir **liste ekranıdır**; `frontend-boost`'un "özgün sahne" kuralı liste ekranlarını kapsam dışı bırakır, çelişki yoktur. Yine de teslim Sultan'a gidiyorsa: klasör kutudan bağımsız açılmalı (dışa `file:///` yolu 0, görseller klasörün içinde) ve kart notları genel övgü değil somut bilgi taşımalı.

## Bilinen sınır — önizleme araçları

Bu kutularda PDF / sunum / web sayfası önizlemesi üretecek araçlar (pdftoppm, chromium, libreoffice) her yerde kurulu DEĞİL. Araç yoksa dürüst tür kartı kullan ve teslim mesajında "önizleme temsili" diye yaz; temsili görseli gerçek önizleme gibi sunma.
