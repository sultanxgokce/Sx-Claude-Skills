# BULGULAR — plan-motor

> **Kanal:** SEDİR (tüketici) ekler · TELLAL/MEDDAH (sahip) kapatır.
> Her bulgu: ne oldu · nasıl görüldü · neden sessiz kaldı · durum.
> Kural: **kapatma iddiası kanıtsız kabul edilmez** — kapatan, çıktıyla gösterir.

## B-001 · Öz-denetim "her odanın kapısı var mı" kontrolünü yapmıyor
- **Açan:** SEDİR · **Tarih:** 2026-08-03 · **Durum:** ✅ **KAPANDI** (MEDDAH, 2026-08-04 · v1.1.0)
- **Kapanış kanıtı (kırpılmamış koşu, `demo/b001-ornek.json` = bulgunun sentetik eşi: 7 hacim, 1 kanat):**
  ```
  $ node cli.mjs dogrula --model demo/b001-ornek.json
  ⚠ oda salon: hiç kapı kanadı yok (1 geçiş boşluğu var) — B-001; ayrıntı için: denetle
  ⚠ oda mutfak: hiç kapı kanadı yok (1 geçiş boşluğu var) — B-001; ayrıntı için: denetle
  (… 6 odanın 6'sı da yakalandı; kanatlı tek hacim "hol" uyarı ALMADI — yanlış-pozitif yok)
  ✓ geçerli (7 oda, 10 duvar, 11 açıklık; 6 uyarı) · rc=0
  ```
- **Uygulanan davranış** (planlandığı gibi): `dogrula` UYARIR, RC değişmez (fail-closed
  YAPILMADI — meşru istisna: geçiş boşluğu, niş, açık plan). Ayrıntılı denetim:
  `denetle --kural-seti kural-seti/TR-PAIY-2026.json` → `SAKUL.B001.kapi_kanadi` kuralı.
  Sapma notu: "ciz DÜŞÜK-GÜVEN işareti" yerine uyarı-kanalı seçildi — `guven` alanını
  otomatik değiştirmek beyan-tolerans yarıçapını da değiştirirdi (yan etkisiz çözüm tercih edildi).
- **Ne oldu:** Bir planda yedi hacmin yedisinde de duvar ağzı vardı ama **tek kapı
  kanadı** çiziliydi. Motor hata vermedi; çizim yanlış *göründü*.
- **Neden sessiz kaldı:** Bu, KANIT.md'deki kalıcı dersin sınıfına giriyor —
  *"yanlış çizim hata vermez, sadece yanlış görünür."* Kanat yokluğu geometrik
  olarak geçerli bir çizimdir; yalnız mimari olarak yanlıştır.
- **Kabul (MEDDAH):** Mimari-kural-tabanının **ilk tuğlası** olarak alındı.
- **Planlanan davranış:** her hacmin en az bir kapı **kanadı** olmalı (duvar ağzı
  yeterli değil). İhlalde `dogrula` uyarır, `ciz` **DÜŞÜK GÜVEN** işaretiyle geçer.
  Fail-closed YAPILMAZ — meşru istisna var (geçiş boşluğu, niş, açık plan).

## B-002 · PNG çıktısı gereksiz büyük — büyük plan tarayıcıda açılamadı
- **Açan:** SEDİR · **Tarih:** 2026-08-04 · **Durum:** ✅ **KAPANDI** (PERGEL, 2026-08-04 · v1.2.1)
- **Ne oldu:** Sultan bir plan paftasını (`Y-yerinde-mutfak.png`, **297 KB**) code-server
  önizlemesinde **açamadı**: *"Bu içerik engellenmiştir."* Dosya sağlamdı (geçerli PNG,
  sha doğru). Aynı oturumda diğer paftalar (116–157 KB) **sorunsuz açılıyordu.**
- **Nasıl görüldü:** Sadece boyut farkı. `--png` çıktısı `sharp(...).png()` varsayılanıyla
  yazılıyor → **truecolor + alfa**. Oysa üretilen şey teknik çizim: duvar grisi, kolon
  siyahı, birkaç vurgu rengi, beyaz zemin. Yani renk sayısı avuç içi kadar.
- **Ölçüm (aynı SVG, aynı çözünürlük):**
  ```
  varsayılan (truecolor)  297 KB
  palette:true             92 KB     ← 3,2× küçük, GÖRÜNTÜ BİREBİR AYNI
  palette + 1600px         74 KB
  ```
  Sedir'in 17 plan PNG'si toptan çevrildi: **2740 KB → 1037 KB** (%62 azalma), hiçbirinde
  gözle görülür fark yok.
- **Neden sessiz kaldı:** Motorun *kendi* açısından hata yok — dosya geçerli, öz-denetim
  SVG'ye bakıyor, PNG boyutuna bakan bir kural yok. Kusur ancak **insan dosyayı açamayınca**
  görülüyor. Yine KANIT.md'deki sınıf: çıktı hatalı değil, *kullanılamaz*.
- **Önerilen düzeltme:** `--png` varsayılanı `png({ palette: true, compressionLevel: 9 })`
  olsun (teknik çizim için doğru kodlama). Truecolor gerekiyorsa `--png-truecolor` bayrağı.
  İstersen öz-denetime eşik de eklenebilir: PNG > ~250 KB ise **uyar** (fail-closed değil —
  meşru büyük çizim olabilir).
- ⚠️ **Dürüstlük notu:** "boyut eşiği" bir **çıkarım**, kanıtlanmış değil. Elimde bir
  başarısız (297 KB) ve birkaç başarılı (116–157 KB) veri noktası var; ara değerleri
  denemedim ve proxy/CSP yapılandırmasını bu kutudan göremiyorum. Kesin olan: palet
  kodlamasıyla dosya 3 kat küçülüyor ve görüntü aynı kalıyor — düzeltme her hâlükârda doğru.
- **Sedir'in geçici kapısı:** `sedir/scripts/gorsel-kucult.sh` (motor düzeltince kaldırılacak).

## B-003 · Uzun başlık SVG çerçevesinden taşıyor — öz-denetim yakalamıyor
- **Açan:** MEDDAH (PERGEL FAZ A hakem-denetiminde, gözle görüldü) · **Tarih:** 2026-08-04 · **Durum:** ✅ **KAPANDI** (PERGEL, 2026-08-04 · v1.2.1)
- **Ne oldu:** `uret` ile üretilen bir adayı `ciz` ile çizdim; PNG'ye bakınca başlığın sağ
  kenardan **kesildiğini** gördüm: *"PERGEL üretimi — PERGEL FAZ A yeşil-fixture — 2+1 · 54 r"*
  (metin "54 m² dikdörtgen" diye sürüyor, çerçeve dışında kalıyor).
- **Ölçüm (kırpılmamış):**
  ```
  viewBox="-120 -120 1140 900"     → kullanılabilir genişlik 1140
  başlık: punto 34 · 74 karakter   → kaba genişlik ~1384  >  1140   TAŞIYOR
  alt satır: punto 17 · 53 karakter → ~496   sığıyor
  oda etiketleri (punto 16-26)      → sığıyor
  ```
- **İki taraflı sebep:** ① `lib/svg.mjs` başlığı çerçeveye göre **kırpmıyor/küçültmüyor**;
  ② `uret` uzun bir `ad` üretiyor ve `ciz` başlığı `"PERGEL üretimi — " + ad` diye kuruyor.
  Tek başına ikisi de zararsız, birleşince taşıyor.
- **Neden sessiz kaldı:** `lib/render-denetle.mjs` metin **varlığını** denetliyor, **sığdığını**
  denetlemiyor. Yine KANIT.md'deki kalıcı ders: *"yanlış çizim hata vermez, sadece yanlış görünür."*
  Aynı sınıf hata TELLAL'da bir kez daha yaşandı (video AI-etiketi 720 px'de kesiliyordu) —
  orada çözüm iki satıra bölme + genişliğe göre punto küçültme + taşma koruması olmuştu.
- **Önerilen düzeltme:** `svg.mjs`'te başlık için genişliğe-göre punto küçültme (en uzun satıra
  göre) + gerekirse iki satıra bölme; taban punto altına düşülüyorsa metni kısalt. Öz-denetime
  eşik ekle: tahmini metin genişliği viewBox'ı aşıyorsa **uyar**. Kırpma/küçültme yapılamıyorsa
  fail-closed'a çekmek YERİNE uyarı yeterli (meşru uzun başlık olabilir).
- **Not:** Bu bulgu üretim halkasını **bloke etmiyor** — plan geometrisi ve denetimi doğru,
  yalnız pafta başlığı okunmuyor. FAZ A merge'i bu yüzden durdurulmadı.

---

## Kapanış kayıtları (PERGEL · 2026-08-04 · v1.2.1)

### B-002 kapanışı — `--png` varsayılanı palet kodlama
- **Düzeltme:** `cli.mjs → pngYaz()` tek yerden yazıyor: varsayılan
  `png({ palette: true, compressionLevel: 9 })`. Eski davranış `--png-truecolor` ile duruyor
  (davranış KAYBI yok, yalnız varsayılan değişti). `ciz` ve `goster` yolları aynı fonksiyona bağlı.
- **Ölçüm (bu kutuda, `demo/ornek-uretim/aday-01.json`, kırpılmamış):**
  ```
  truecolor   81 191 bayt   (IHDR renk-tipi 6 = RGBA)
  palet       38 780 bayt   (IHDR renk-tipi 3)      → %47.8, 2.09× küçük
  ```
- ⚠️ **SEDİR'in "görüntü BİREBİR aynı" ifadesini düzeltiyorum:** ham piksel karşılaştırdım —
  **bileşenlerin %0.257'si farklı, en büyük sapma 22/255.** Fark kenar yumuşatma (anti-alias)
  ara tonlarının nicemlenmesinden geliyor; gözle ayırt edilemiyor (iki PNG'yi de açıp baktım)
  ama *birebir* değil. Kazanç gerçek, iddia biraz fazlaydı.
- **Kapı:** `kapi-testi.sh` → palet/truecolor boyut oranı ≤ %70 + IHDR renk-tipi 3 ve 6 iddiaları.

### B-003 kapanışı — metin çerçeveye SIĞDIRILIYOR + öz-denetim ölçüyor
- **Yeni:** `lib/metin-olc.mjs` — DejaVu Sans advance tablosundan deterministik genişlik tahmini
  + `sigdir()` (tek satırda küçült → iki satıra böl → taban puntoda kırp, %3 güvenlik payı).
- **Uygulandı:** `lib/svg.mjs` (başlık + ölçü beyanı) **ve** `lib/cad-render.mjs`
  (başlık + altbaşlık) — aynı kusur `goster` yolunda da vardı, o da kapandı.
- **Öz-denetim:** `render-denetle.mjs` artık üretilmiş SVG'nin `<text>` öğelerini AYRIŞTIRIP
  gerçek x/punto/hizalama ile yeniden ölçüyor ve çerçeveyi aşanı **uyarı** olarak bildiriyor.
  Üreticinin punto kararını tekrarlamaz — bozarsa da yakalar. Hata değil uyarı: ölçü bir
  TAHMİN ve meşru uzun başlık olabilir; çizimi bloke etmek yanlış olurdu.
- **Ölçüm:** taşan başlık (74 karakter) punto 34 → **25**'e indi, tek satırda sığdı
  (tahmini genişlik 1413 → 1039, kullanılabilir 1080).
- **Sığan içerikte çıktı BAYT-EŞ:** `demo/ornek-model.json` → `ciz` sha256 hâlâ `3f9bb247…`.
  Düzeltme, zaten sığan hiçbir paftayı değiştirmedi. Bu çıpa artık `kapi-testi.sh`'ta
  **mekanik iddia**dır (önceden yalnız belgede düz metindi).
- **Kapı dogfood'u:** taşan SVG enjekte edilip öz-denetimin UYARDIĞI ayrıca iddia edildi —
  kapının ölü olmadığı kanıtlı (yeşil bir kapı, koşmayan bir kapıdan ayırt edilebilsin diye).
- ⚠️ **Dürüst sınır:** genişlik tahmindir (±%5). Gerçek font metriği çalışma anında yok;
  bilinmeyen karakter varsayılana düşer. Bu yüzden sığdırma güvenlik payıyla çalışır ve
  öz-denetim uyarı üretir, fail-closed değil.

## FAZ B ölçüm notları (PERGEL · 2026-08-04 · v1.3.0) — bulgu değil, KAYIT

Bunlar kusur değil; ileride kimse yeniden keşfetmesin diye bırakılan ölçümlerdir.

### Ö-1 · Bütçe, çeşitliliği kapıdan önce öldürüyordu
Denetim bütçesi (`TAVAN.denetim = 500`) adayları **ön-skorca** en iyiden alıyordu; hepsi aynı
mimari aileden çıkıyordu. Ölçüm: 6 odalı programda 1629 eşsiz yerleşimin **yalnız 24'ünde
(%1.5)** hol tüm odalara komşuydu ve bunların hiçbiri bütçeye giremiyordu → `sirkulasyon`
ekseni tek değere çöküyordu. **Kusur kapıda değil ÖRNEKLEMEDEYDİ.** Düzeltme: bütçe ucuz
geometrik ön-sınıflara bölünüp round-robin dağıtılıyor (`onSinif`, yıldız ön-vekili dâhil).
Sonuç: 6 kombinasyon → **7**, `dogrusal-hol` ortaya çıktı.

### Ö-2 · Alan uyumu FİZİBİLİTE demek değil
L/U'da oda-parça atamaları alan oranı uyumuna göre sıralanıp **en iyi 30'u** deneniyordu.
U sınırda sonuç **SIFIR yerleşim**di: alan oranı en iyi tutan atamalar geometrik olarak
çıkmazdı (400×300 parçaya mutfak+banyo → biri 144 cm, md.29/(1) asgarisi 150). Çalışan
atamalar listenin derinindeydi. Düzeltme: tavan "denenen" değil **"BAŞARILI" atama** üzerinden
sayılıyor. `sakul/fixtures/program-u-sinir.json` bu hatayı kilitler.

### Ö-3 · Slicing, 6 odada MERKEZİ hol üretemiyor (açık sınır)
6 odalı programda `merkezi-hol` (derli toplu, en/boy < 2.5) **hiç** üretilemedi; yıldız
yerleşimlerin hepsinde hol uzun koridor (`dogrusal-hol`) çıktı. 4 odada merkezi-hol çıkıyor.
Bu bir hata değil, **slicing (giyotin) ailesinin yapısal sınırı** gibi görünüyor — ama bunu
KANITLAMADIM, yalnız ölçtüm. Gerçek merkezi hol muhtemelen giyotin-olmayan yerleşim ister;
bir FAZ C konusudur. `rapor.json → gorulen_eksen_degerleri` bu sınırı her koşuda yüzeye çıkarır.

### Ö-4 · DXF round-trip'in KANITLAMADIĞI şey
`ciz --dxf` → `oku` round-trip'i kapıda mekanik: LWPOLYLINE=duvar · ARC=kapı ·
LINE=2×kapı+pencere · TEXT=oda · INSUNITS=5(cm) · 5 AIA katmanı. Bu, **motorun kendi
okuyucusunun kendi yazıcısıyla tutarlı** olduğunu kanıtlar; **gerçek AutoCAD'in dosyayı
açtığını KANITLAMAZ.** O teyit hâlâ açık (`DEVIR.md`) ve Sultan'a kalıyor. "DXF doğrulandı"
demeyin; "round-trip tutarlı, gerçek CAD teyidi bekliyor" deyin.
