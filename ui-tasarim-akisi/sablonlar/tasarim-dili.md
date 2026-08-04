# Tasarım dili sözleşmesi

*Şablon. Ürünün sözleşmesi buradan türetilir; her prompta **birebir** gömülür.*

Bu dosya **ne kullanılacağını** söyler — ölçülebilir, grep'lenebilir. Karakteri kardeş dosya
(`estetik-yon.md`) anlatır.

**Sözleşme ilk sayfadan sonra DONDURULUR.** Sonra yalnız *ekleme* yapılır (bildirilen yeni
bileşen gibi) ve her ekleme değişiklik günlüğüne gerekçesiyle yazılır. Renk/tipografi/iskelet
değişirse önceki sayfalar bayatlar.

---

## 1 · Renk

Renkler **rol** adıyla anılır, değerle değil. Prompt rolleri konuşur; çıktı değeri taşır.

| Rol | Ne için | Değer |
|---|---|---|
| `zemin` | Sayfanın en alt katmanı | {{ }} |
| `yuzey` | Kart, panel, form kutusu | {{ }} |
| `kenar` | Ayırıcı çizgi, kart kenarı | {{ }} |
| `metin` | Ana metin | {{ }} |
| `metin-soluk` | İkincil bilgi, yardım metni | {{ }} |
| `birincil` | Tek birincil eylem | {{ }} |
| `birincil-koyu` | Birincil eylemin üstüne gelince | {{ }} |
| `vurgu` | Seçili öğe, odak halkası | {{ }} |
| `tehlike` | Yıkıcı eylem, hata | {{ }} |
| `uyari-zemin` | Yumuşak uyarı zemini | {{ }} |

**Durum renkleri** (ürünün kendi durum kümesi — varsa):

| Durum | Zemin | Metin |
|---|---|---|
| {{ }} | | |

**Kontrastı ÖLÇ, tahmin etme.** Metin/zemin ve her durum rozeti için oran hesaplanır; erişilebilirlik
eşiğinin (4.5:1) altında kalan renk değiştirilir. Ölçüm sonucu buraya yazılır — "yeterli görünüyor"
bir ölçüm değildir.

---

## 2 · Tipografi

Tek aile: {{ }}. Dış kaynaktan font yüklenmez (yüklenirse sessizce başka bir yazı tipine düşer).

| Kademe | Boyut / satır / ağırlık | Kullanım |
|---|---|---|
| `baslik` | | |
| `altbaslik` | | |
| `govde` | | |
| `kucuk` | | |

Dört kademe yeter; beşincisi icat edilmez.

---

## 3 · Boşluk ve iskelet

Boşluk ölçeği: {{ }} tabanlı, ara değer kullanılmaz.
Köşe yuvarlaklığı: kart {{ }} · düğme/alan {{ }} · rozet {{ }}.
Gölge: yalnız yüzen katmanda (panel, diyalog). Kartlarda gölge değil kenar çizgisi.

**Sayfa iskeleti — her sayfada aynı, kımıldamaz:**

```
{{ISKELET_CIZIMI}}
```

İçerik bölgesi üstünde ince bir başlık şeridi: solda başlık + bağlam gezinmesi, sağda **tek**
birincil eylem. İki birincil düğme yan yana konmaz.
Dar ekran davranışı: {{ }} altında iskelet ne yapar.

---

## 4 · Bileşen sözlüğü

Promptlar bu adlarla konuşur. **Çıktıda her bileşenin ilk elemanı `<!-- bilesen: Ad -->` yorumunu
taşır** — tutarlılık böyle grep'lenir.

Sözlük dışı ad **sessizce icat edilmez**. Gerçekten yeni bir şey gerekiyorsa model onu **bildirir**,
sonra buraya eklenir.

| Ad | Nedir |
|---|---|
| {{ }} | |

Çekirdek olarak hemen her üründe çıkanlar (ada uyuyorsa kullan, uymuyorsa kendi adını koy):
gezinme · sayfa başlığı şeridi · liste satırı · form alanı · düğme (birincil/ikincil/sessiz) ·
onay diyaloğu · yan panel · bilgi şeridi · boş durum mesajı · durum rozeti.

---

## 5 · Çıktı sözleşmesi (her promptun sonunda tekrarlanır)

1. Tek dosya; dış kaynak (CDN, font, ikon kütüphanesi, uzak resim) **yok**. İkon gerekirse satır
   içi çizim ya da metin işareti.
2. Betik yalnız görsel durum için (panel aç/kapa, sekme). Veri, ağ çağrısı, kalıcı durum yok.
3. Her bileşen `<!-- bilesen: Ad -->` ile işaretlenir.
4. **Örnek veriler uydurmadır** ve gerçek kişiyle karışmayacak biçimde işaretlenir
   (ör. sabit bir soyad). Kişisel görünen alanlar maskeli.
5. Arayüz dili ve tarih/sayı biçimi: {{ }}.
6. Ürünün durum kümesi varsa **hepsi** örnekte görünür.
7. Hedef genişlikte doğru görünür; dar ekranda §3'teki gibi davranır.

---

## 6 · Yasaklar

Ürünün kendi kısıtlarından gelir — pazarlık yok. Her madde "ne çizilmez" biçiminde yazılır:

- {{ }}
- Yarım özellik çizilmez: veri modelinde olmayan alan tasarımda görünmez.

---

## Değişiklik günlüğü

| Tarih | Ne değişti | Niçin |
|---|---|---|
| | | |
