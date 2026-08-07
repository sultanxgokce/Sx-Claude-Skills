# Marka sözleşmesi

*Şablon. Ürünün kendi sözleşmesi buradan türetilir ve her prompta **birebir** gömülür.*

Bu dosya **DEĞER** taşır: renkler, font, kademeler, ölçüler, ürünün kendi adları ve kısıtları.
**KURAL** taşımaz — kurallar filo geneli çekirdek sözleşmede yaşar (`cekirdek/sozlesme.md`) ve
prompta kendiliğinden girer; buraya kopyalanmaz. (Kopyalanan kural bayatlar; ölçülmüş vaka var.)

Karakteri kardeş dosya (`estetik-yon.md`) anlatır.

---

## 1 · Renk değerleri

Renkler **rol** adıyla anılır. Prompt rolleri konuşur; bu tablo değerleri verir.

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

**Ölçülen kontrast** (çekirdek Ç5 gereği — "yeterli görünüyor" ölçüm değildir):

| Çift | Oran | Eşiği geçti mi |
|---|---|---|
| metin / zemin | {{ }} | |
| metin-soluk / zemin | {{ }} | |
| birincil üstü metin / birincil | {{ }} | |

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

## 3 · Boşluk, ölçü ve iskelet

Boşluk ölçeği: {{ }} tabanlı, ara değer kullanılmaz.
Köşe yuvarlaklığı: kart {{ }} · düğme/alan {{ }} · rozet {{ }}.
Gölge: yalnız yüzen katmanda (panel, diyalog). Kartlarda gölge değil kenar çizgisi.

**Yoğunluk bütçesi** (çekirdek Ç4.4'ün bu üründeki sayısı):
koşulsuz gövdede en çok {{ }} blok türü.

**Sayfa iskeleti — her sayfada aynı, kımıldamaz:**

```
{{ISKELET_CIZIMI}}
```

Dar ekran davranışı: {{ }} altında iskelet ne yapar.

---

## 4 · Sözlük eklemeleri

Çekirdeğin on adı (`Gezinme` · `Sayfa başlığı` · `Liste satırı` · `Form alanı` · `Düğme` ·
`Onay diyaloğu` · `Yan panel` · `Bilgi şeridi` · `Boş durum` · `Durum rozeti`) zaten geçerlidir —
buraya **tekrar yazılmaz**. Yalnız bu ürüne özgü, çekirdekte karşılığı olmayan adlar eklenir:

| Ad | Nedir |
|---|---|
| {{ }} | |

---

## 5 · Bu ürüne özgü biçim

Arayüz dili ve tarih/sayı biçimi: {{ }}.
Ürünün durum kümesi (hepsi örnekte görünecek): {{ }}.

---

## 6 · Yasaklar

Ürünün kendi kısıtlarından gelir — pazarlık yok. Her madde "ne çizilmez" biçiminde yazılır:

- {{ }}

---

## Değişiklik günlüğü

Çekirdek Ç6 gereği sözleşme ilk sayfadan sonra dondurulur; her ekleme buraya gerekçesiyle yazılır.

| Tarih | Ne değişti | Niçin |
|---|---|---|
| | | |
