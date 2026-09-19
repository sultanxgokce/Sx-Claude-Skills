# Veri sözleşmesi

Girdi UTF-8 JSON nesnesidir. Zorunlu üst alanlar `title` (metin) ve `items` (kayıt dizisi). İsteğe bağlı: `subtitle`, `collected_at` (arşiv tarihi), `language` (`tr` veya `en`; varsayılan `tr`). Üretici tarih veya kaynak keşfetmez.

Her kayıtta zorunlu:
- `id`: kalıcı ve tekil; ASCII harf/rakam, alt çizgi veya tire; en fazla 80 karakter. Başta harf/rakam.
- `title`, `category`, `kind`, `note`: boş olmayan metinler.
- En az biri: `file` veya `source_url`.

İsteğe bağlı:
- `file`: manifestin bulunduğu klasöre göre yerel dosya yolu. Mutlak yol da kabul edilir; bu, ajanın kullanıcı tarafından yetkilendirilmiş dosyayı seçme sorumluluğunu kaldırmaz.
- `preview`: mevcut PNG/JPEG/WebP/GIF önizleme dosyası. SVG ve HTML önizleme olarak kabul edilmez. Üretici önizleme render etmez.
- `source_url`: yalnızca tam HTTP/HTTPS kaynak adresi.
- `tags`: metin dizisi; aramaya katılır.
- `date`: `YYYY-MM-DD` içerik tarihi; bilinmiyorsa boş bırak.
- `license`: doğrulanmış kısa lisans bilgisi veya “Bilinmiyor”.
- `language`: içeriğin dili; katalog arayüz dilinden bağımsız.

```json
{
  "title": "Araştırma Kütüphanesi",
  "subtitle": "Makale ve saha notları",
  "language": "tr",
  "collected_at": "2026-09-19",
  "items": [{
    "id": "rapor-001",
    "title": "Saha ölçüm raporu",
    "category": "Araştırma",
    "kind": "PDF rapor",
    "note": "İki ölçüm dönemini aynı tabloda karşılaştırır.",
    "file": "dosyalar/rapor.pdf",
    "preview": "onizlemeler/rapor.png",
    "tags": ["ölçüm", "karşılaştırma"],
    "date": "2026-08-01",
    "license": "Bilinmiyor"
  }]
}
```

## Çıktı

- `index.html`: verisi içine gömülü, çevrimdışı katalog; CDN/fetch/server gerektirmez.
- `catalog.json`: taşınabilir, kopyalanmış dosyalara göre normalize envanter.
- `validation.json`: gerçek sayımlar, SHA-256 tekrar grupları, kontrol özeti.
- `items/<id>/original.<uzantı>`: orijinal dosyanın aynı baytlarla kopyası.
- `items/<id>/preview.<uzantı>`: sağlanan önizleme kopyası.
- `items/<id>/source.txt`: başlık, not, kaynak ve özgün dosya adı.
- `KULLANIM.txt`: açma ve taşıma bilgisi.

Aynı dosya birden fazla kayıtta bulunursa üretici dosyaları silmez; `validation.json` içinde bildirir. Nihai örnek sayısını şişirmemek için aynı içerik kayıtlarını ajanın birleştirmesi veya farklı sürüm gerekçesini açıkça belirtmesi gerekir. Aynı kaynağa giden tekrar adresler de raporlanır. Başlıksız, hatalı tarihli, kayıp dosyalı veya geçersiz adresli girdi üretim başlamadan reddedilir.

Üretici yalnızca dosyanın varlığını, yol ve kayıt bütünlüğünü, kopyaların hash eşitliğini doğrular. PDF içeriğini, görsel kalitesini, harici bağlantının çalışmasını veya lisansın doğruluğunu doğrulamaz. Bunlar ajan kontrolüdür.

Birkaç yüz kayıtta statik kartlar yeterlidir. Binlerce büyük görsel veya çok geniş veri için sayfalama/sanal liste, daha küçük önizlemeler ve ayrı arama indeksi düşün. Basit katalog şablonunu her ölçeğe zorla uygulama.
