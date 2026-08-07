# Rubrik urun-ui v1 — tek-ekran anlam yargısı

<!-- MAKINE: bu satırlar yargi-birlestir.py tarafından okunur; elle biçimi bozma -->
<!-- yeter_sayi: 2 -->
<!-- red_esigi: 3 -->
<!-- kanit_max: 160 -->

> **Yargıç rolü — G1, yalnız NEGATİF yetki.** Bu rubrik yeşil ÜRETMEZ; yeşili İPTAL eder.
> Puanlar ekranı "onaylamaz"; düşürme gerekçesi sayar. Durma koşulu her zaman mekanik kapıdır (G0).
>
> **Kalibrasyon kaydı (2026-08-07):** 9 ekran × 3 canlı çapraz-aile yargıç, ön-kayıtlı ölçütlerle.
> ALTIN kümesinin 4 ekranı ayakta kaldı (yanlış-pozitif yok); ALTIN'ın bilinen-kusurlu ekranı
> **kör koşuda** RED aldı ve insan divanının üç maddesini (manşetin evi · manşetin öznesi ·
> payda görünürlüğü) bağımsız yakaladı — iki farklı panel aynı sonucu verdi.
> **Ölçülen kapsam sınırı:** bu rubrik *anlam* boyutunu yakalar; **yoğunluk ve ekranlar-arası
> tutarlılık** boyutunu yakalamaz — o boyut `yogunluk-denetle.py`'ye (LLM'siz, mekanik) aittir.
> Kalibrasyonda bu ayrım ölçülerek bulundu; rubriği o yöne genişletmek ölçülmeden yapılmaz.

## Ortak kurallar

- Her madde **kapalı soru**dur; cevap 0 / 1 / 2 çapalarından biridir.
- **KANIT ZORUNLU (her madde):** `kanit` alanına ekran dosyasından **harfi harfine, tek parça**
  alıntı (≤160 karakter; üç nokta ile kısaltma YOK, birleştirme YOK). Alıntı dosyada birebir
  bulunamazsa o maddedeki hükmün tamamı geçersiz sayılır.
- `gerekce` tek cümledir; kanıtın neden o puanı gösterdiğini söyler.
- Emin değilsen puanı YÜKSEK tut (2) — şüphe düşürme gerekçesi değildir; yargıç yalnız
  gösterebildiğini düşürür.

## M1 · Bileşen adı ↔ sözlük anlamı

**Soru:** `<!-- bilesen: Ad -->` işaretli bileşenler, adlarının sözlükteki (sözleşme §4)
tanımına davranışça uyuyor mu; sözlük-dışı **sessiz icat** var mı?

- **2** — işaretli bileşenler adlarının tanımıyla örtüşüyor; sözlük-dışı ad yok ya da
  "bildirilen yeni ad" notu taşıyor.
- **1** — TEK bileşende ad-içerik kayması VEYA tek sessiz icat var.
- **0** — birden çok bileşen adının söylediğinden başka bir şey; ya da işaretleme düzeni
  toptan yok sayılmış (hiç `bilesen:` işareti yok).

## M2 · Manşetin öznesi — hizmet mi, borç mu

**Soru:** Sayfanın manşet mesajı (en üstteki özet cümle / sayfa başlığı + bağlam metni)
kullanıcıya **bulgu/sonuç mu sunuyor**, yoksa **görev-borcu mu çıkarıyor**?

- **2** — manşet, sistemin bulduğu şeyi ya da sayfanın işini kullanıcının kazanımı diliyle
  söylüyor; düz operasyon sayfasında işini tek cümlede net söylüyor.
- **1** — karışık: hem bulgu hem görev dili; özne belirsiz.
- **0** — manşet salt görev/borç dilinde ("N iş dikkat istiyor" sınıfı: kullanıcıya iş
  çıkarıyor, yorgunluk hissettiriyor) YA DA sunulacak somut bulgu varken manşet onu gizliyor.

## M3 · Görsel öğenin bilgi değeri

**Soru:** Belirgin görsel öğelerin (renk kodlaması, grafik/çubuk, harita, büyük sayı,
animasyon) **her biri**, bakmadan bilemeyeceğin bir şey söylüyor mu?
(Ölçüt cümlesi: *"grafik bakmadan bilemeyeceğin bir şey söylüyor mu? Söylemiyorsa süstür."*)

- **2** — hepsi bilgi taşıyor.
- **1** — bir öğe süs: zaten bilineni ya da kendiliğinden belli olanı tekrar ediyor.
- **0** — merkezi/baskın bir görsel öğe bilgi taşımıyor — dekorasyon, ya da zaten bilinen
  dağılımı gösteriyor (ör. renk "nerede sorun var" değil "nerede çok kayıt var" diyor).

## M4 · Manşetin evi

**Soru:** Özet/manşet mesajın görsel bir **evi** var mı — zemin, çerçeve ya da ayrık bölge;
"sayfa-özeti nerede bitti, veri nerede başladı" belli mi?

- **2** — net ev; özet ile veri bölgesi ayrımı belirgin.
- **1** — ayrım zayıf; ya da manşet cümlesi hiç yok (yokluk M2'nin işidir, burada 1 ver ve
  gerekçeye "manşet yok" yaz).
- **0** — manşet iki bölge arasında evsiz asılı: zemini, çerçevesi, ayırıcı boşluğu yok.

## M5 · Önem ≠ büyüklük (ve sıra)

**Soru:** En önemli / en acil bilgi, görsel ağırlığı **ve sırası** en yüksek bilgi mi?

- **2** — önem/aciliyet hiyerarşisi ile görsel hiyerarşi ve liste sırası örtüşüyor.
- **1** — ikincil bir kayma var.
- **0** — kritik bilgi (para farkı, yakın son tarih) görsel olarak sıradanlaştırılmış
  (sadelik uygulanırken önemli olan da silikleştirilmiş) YA DA daha acil kayıt daha az
  acilin ALTINA sıralanmış YA DA önemsiz bir şey en büyük basılmış.

## M6 · Dürüstlük vitrini

**Soru:** Ekran, bütünü ve kendi sınırlarını dürüst gösteriyor mu?
Kontrol listesi: **payda görünür mü** (istisnalar "kaçta kaç"; kullanıcı neyin istisnası
olduğunu görüyor mu) · boş/bilinmeyen değer "—" ya da gerekçeyle mi · ŞEMATİK / SENTETİK /
ÖRNEK GÖRÜNÜM işaretleri yerli yerinde mi · kanıtsız büyük sayı var mı?

- **2** — hepsi tamam.
- **1** — bir eksik.
- **0** — payda yok (kullanıcı istisnaları görüyor, bütünü göremiyor) YA DA kanıtsız/sahte
  gösterim var.

## Çıktı biçimi (kapalı şema — başka hiçbir şey yazma)

```json
{"maddeler":[
 {"id":"M1","puan":2,"kanit":"<ekrandan harfi harfine alıntı>","gerekce":"<tek cümle>"},
 {"id":"M2","puan":0,"kanit":"...","gerekce":"..."},
 {"id":"M3","puan":2,"kanit":"...","gerekce":"..."},
 {"id":"M4","puan":1,"kanit":"...","gerekce":"..."},
 {"id":"M5","puan":2,"kanit":"...","gerekce":"..."},
 {"id":"M6","puan":0,"kanit":"...","gerekce":"..."}
]}
```
