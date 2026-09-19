---
name: tasarim-citasi
version: 0.1.0
allowed-tools: Bash, Read, Write, Edit
description: Sultan'ın referans tasarımcı kütüphanesi = ekibin kalite çıtası. Her tasarım teslimi (site, karşılama, ürün sahnesi, sunum/broşür kapağı) bu çıtanın altındaysa reddedilir; frontend-boost ve üç ilke kapısının üstüne dördüncü kapı.
---

# tasarım-çıtası — "Bu seviyenin altında iş çıkarmayın"

**Doğduğu yer (18 Eylül 2026, 12:15–12:4x, AKAR):** mukarnas.net ana sayfası üç turda (v14, v14b, v14c) Sultan'dan geçemedi: *"daha iyi ama hâlâ zayıf; yarım kalmış gibi; mimari planlar hâlâ eksik ve kötü."* Sultan bir tasarımcının işlerini referans verdi ve kuralı koydu:

> **"Sizin tasarım kalitenizin seviyesi bu olacak. Bu tasarım seviyesi kalitesinin altında iş çıkarmayın."** — herkese, katı kural.

## Kütüphane
- **Yol:** `TASARIM_CITASI_KUTUPHANE` ortam değişkeni; verilmezse varsayılan hub yolu `/config/evraklar/Sultan/1-Calisma/AKAR/tasarim-referans`. Aşağıda `$KUT` bu yoldur.
- Kareler: `$KUT/kareler/<video>/iyi/kirpik/` — **yalnız iyi örnekler**. Videolar kötü↔iyi karşılaştırır; kötü ve belirsiz kareler `_ayiklanan/` altında kalır, hiçbir zaman örnek diye gösterilmez (Sultan 12:4x).
- Çözümleme ve çıta maddeleri: AKAR deposunda `tasarim/referans-kutuphanesi/KUTUPHANE.md`. O depoyu görmeyen kutuda kapı maddeleri bu dosyadadır; örnek adları kareler klasöründen okunur.
- Yeni kaynak (AKAR'da): `scripts/referans-kare-cikar.sh <video>` → gözle etiketle → KUTUPHANE.md'ye satır. Başka kutu yeni kaynak eklemez; AKAR'a iletir.
- 🔴 **Erişim önce ölçülür:** `test -d "${TASARIM_CITASI_KUTUPHANE:-/config/evraklar/Sultan/1-Calisma/AKAR/tasarim-referans}/kareler"`. Klasör yoksa ya da boşsa (hub'ı görmeyen izole kutu) kıyas **yapılamaz**: teslim mektubuna **"çıta kıyası yapılamadı (kütüphane yok)"** yazılır — "geçti" yazılmaz, satır sessizce atlanmaz. Kapının öteki maddeleri (2–10) kütüphanesiz de uygulanır.

## Kapı (teslimden ÖNCE, üç ilke kapısıyla birlikte; biri düşerse teslim yok)
1. **Yan yana bak.** Teslim karesini kütüphaneden en yakın iyi örneğin yanına koy (aynı genişlik). "Bunlar aynı seviyede mi?" sorusuna dürüstçe **evet** diyemiyorsan bitmemiştir. Bunu kanıt dizinine tek görsel olarak koy (`cita-kiyas.png`).
2. **Kahraman nesne gerçek görünümlü mü?** Örnek çizim, şema, yer tutucu, "temsili" görsel kahraman olamaz. Ürün ekranı gerçek kare; mekân için gerçek iş ya da gerçek görünümlü sahne. Ustaca yapılamayan öğe sayfaya girmez.
3. **Tek vurgu rengi, nesneyle aynı.** İkinci vurgu, gradyan süs, üç renkli kutu → düş.
4. **Yazı sahnenin öğesi.** Dev başlık nesneyle ilişkili (arkasından geçer, filigran olur, nesneye bağlanır); küçük açıklama ince çizgiyle nesneye dokunur. Serbest duran paragraf sahneye giremez.
5. **Derinlik var, süs yok.** Gölge/ışık/kaide/filigran nesneye hizmet eder. Düz beyaz boşluk "temiz" değil, boş sayılır.
6. **Kanıt kartları tek çerçeve dili.** Aynı yarıçap, aynı zemin, aynı köşe yerleşimi; bir kart farklıysa hepsi yeniden.
7. **Az söz.** Sahnede 1 başlık + 1 satır + 1 eylem. Kaydırınca hikâye açılır, ama her bölüm başladığını **bitirir** (cümle → kanıt → eylem).
8. **Yedi viewport, çakışma sıfır, eylem ilk ekranda.** (Yedinci: **1512×825** — Sultan'ın MacBook Chrome penceresi; 18 Eylül 16:07 sahnedeki düğme katın altında kaldı. Sahnenin tek eylemi her masaüstü boyutunda ilk ekranda görünür; ölçüm satırı "düğme alt kenarı / viewport yüksekliği".) Sahne öğeleri görselin kendi koordinatına bağlanır, viewport'a değil. Teslim 1440×900 · 1440×1100 · 1536×864 · 1920×1080 · 1280×720 · 390×844 tam boy karelerle ve "kesişen metin/kart çifti = 0" ölçümüyle gelir (18 Eylül 14:46: 1440×900'de kusursuz sahne Sultan'ın daha yüksek penceresinde dağıldı — tablet havada, başlık kesik → "hiç olmamış").
9. **Tek dil.** Sahne koyu ise gövde de koyu; koyu→açık ya da açık→koyu geçiş yok (Sultan üç kez reddetti: bugun-v3, Yön A, Bugün v4). Bentler sahnenin nesne diliyle kompakt kartlar; üç sütuna yayılmış boşluklu bent yok.
10. **Kötü tarafın işaretlerinden biri varsa** (stok fotoğraf, eşit kutular, ortalı düz başlık, kart yığını, "biz en iyiyiz" dili) teslim yok.

## Beğeniden çıkan kurallar (18 Eylül 2026 — kanıtlı; çözümleme AKAR deposunda `tasarim/referans-kutuphanesi/BEGENI-ANALIZI-20260918.md`)
Aynı gün yedi ret ve üç beğeni ("bu görüntüye bayıldım" Konsept A · "harika, logo" Konsept B geometrisi · "ciddi gelişme" Bugün v5). Beğenilenlerin ortak paydası kuraldır:
- **B1 Kahraman gerçek ve bizim.** Ürünün gerçek ekranı fiziksel nesne gibi (derinlik, cam, ışık) ya da kendi kimliğimizden üretilmiş geometri. Örnek çizim, temsili plan, stok görsel → ret ("amatör rölöve").
- **B2 Tek ışık = tek fikir.** Sahneyi bağlayan tek ışık/çizgi; o çizgi ürünün bir gerçeğinden çıkar (Bugün çizgisi). Süs ışığı değil, anlam taşıyan ışık.
- **B3 Slogan yok, iş var.** "…geliştiriyoruz / …üzerine çalışıyoruz / Ankara." kalıbı amatör sayıldı. Sahnedeki tek satır ürünün yaptığı işi söyler.
- **B4 Bölüm bitirir.** Cümle → kanıt → eylem. Vaat edilen iki alan varsa ikisi de kanıtlı; biri boşsa "yarım kalmış".
- **B5 Teknik alınır, sahne alınmaz.** Referanstan tek kahraman, tek ışık, dev yazı arkada, kanıt küçük/eşit, tek palet öğrenilir; konu bizim işimiz (yazılım şirketi). Taklit "alakasız" diye döner.
- **B6 Önce konsept, sonra sayfa.** Tek kare, iki konsept, Sultan seçer; tam sayfa seçilen konseptten. Tam sayfa turu konseptsiz açılmaz.
- **B7 Bölüm bölüm düzelt.** Ret gelince sayfayı baştan çizmek yerine bölüm notlarıyla tek tur; ama yama yasağı sürer (sayfa bütün olarak yeniden teslim edilir).
- **B8 Sol hat tek, ritim sıkı.** Kahraman ve bölümler aynı sol çizgide; bölüm araları iplik/ray ritmine bağlı, "boşluklu" değil.
- **B9 Reis iki yükseklikte kendi bakar.** Ölçüm yeşili kalite değildir; bakılmadan giden her sürüm döndü.
- **B11 Süs işareti anlam taşır ya da kalkar.** Dev kelimenin sonundaki ışık renkli nokta "anlamsız kaldı" (Sultan 16:07). Vurgu öğesi sayfanın fikrine (iplik, ışık) bağlı değilse süs sayılır.
- **B12 Başlık gövdeyi ezmez.** İri serif üç satıra kırılınca "çok kaba" (Sultan 16:08). Bölüm başlığı en çok iki dengeli satır, ince ağırlık; dev punto yalnız sahnede.
- **B13 Altbilgi de orijinal olur.** Düzgün ama her sitede olan kapanış ("sol başlık + sağ künye") "daha orijinal gözükmeli" (Sultan 16:09). Kapanış sayfanın kendi fikriyle biter.
- **B14 Yan yana iki başlık yarışmaz; cümle sayfanın fikrine bağlanır.** Karşılama v3: gerçek ekranın manşetinin yanında aynı aile/aynı puntoda düz beyaz üç satır "font rötuşu gerek, daha orijinal, harmonik" (Sultan 21:34). Sahnedeki cümle: iki dengeli satır, ana fikir ışık renginde, ürün karesindeki başlıkla açık hiyerarşi, sayfanın ışık ailesinden tek bağ.
- **B15 Alt yazı okura konuşur, atölyeye değil.** "Mukarnas geometrisi, kendi üretecimizden; tek ışık, tek malzeme." → "anlamı zayıf, amaçsız" (Sultan 21:44). Görselin **nasıl yapıldığı** iç dildir; alt yazı görselin okur için **ne anlama geldiğini** söyler ya da hiç olmaz.
- **B10 Beğenilen iş galeriye, motif marka varlığına.** Seçilmeyen konseptin güçlü parçası (B'nin geometrisi) marka varlığı olarak saklanır ve seçilen konseptte motif olur.

## Kim, ne zaman
- Tasarım başı ve tasarım teslim eden herkes (AKAR'da: NAKKAŞ tasarım başı · SEYYAH kod · BEŞİR film/sunum · ARZUHALCİ kapak metni): teslim mektubunda **"çıta kıyası: <örnek adı> — geçti"** satırı (ya da kütüphanesiz kutuda **"çıta kıyası yapılamadı (kütüphane yok)"**) olmadan reis'e gitmez; reis de o satır olmadan Sultan'a sunmaz.
- Bu beceri `frontend-boost` ve onun ÜÇ İLKE KAPISI'nın üstüne biner; onları gevşetmez.

**B16 · Ayıklama karakteri silebilir (Sultan 19 Eyl, ayrıntı ekranları üçüncü tur: "ikinci tura göre bozulma var… bitmiş profesyonel duruyor diyemiyorum").** Uzun bir "şunu çıkar, bunu yumuşat" listesi ekranı temizlemez, **silikleştirir**: net kenar soluk dolguya, güçlü kahraman küçük satıra dönünce hiyerarşi düzleşir. Kural: (a) her rötuş turunda önceki turla yan yana bakılır ve her kalem için "ne kazandık" kadar **"ne kaybettik"** yazılır; karakter kaybı varsa kalem geri alınır; (b) "bitmiş, profesyonel" hissi **kararlılıktan** gelir: net kenar, doğal genişlikte alan, belirgin tek odak, yeterli kontrast — yumuşatmadan değil; (c) iki tur üst üste "biraz daha" dönüyorsa tek çizgide rötuşa devam edilmez: **taban olarak beğenilen tura dönülür ve 2–3 varyant yan yana** sunulur, olgun örneklere bakılır; (d) reisin "geçti"si Sultan'ın gözü değildir — belirsiz karede "geçti" yerine iki seçenek götürülür.

## Kardeş beceriler (Sultan 19 Eyl)
Çıta **görsel seviyeyi** söyler. **Zanaat** (aralık, form, durumlar, otomatik doldurma, koyu tema, tarayıcı tuzakları) `arayuz-zanaati`'ndedir ve her sayfa işinde birlikte koşulur. **İçerik**: broşür için `brosur-hazirlama/ICERIK.md`, sunum için `sunum-hazirlama`. Sıra: içerik planı → tasarım (çıta) → zanaat bakışı (altı hâl) → teslim.

## Referans arşivinden dersler (19-09)

### Broşür arşivinden
Kaynak (AKAR deposu): `tasarim/referans-kutuphanesi/arastirma-20260919/SENTEZ-brosur.md` (55 kurumsal broşür/föy; sayılar göz kararı).
- **Basılı iş için kıyas adayları:** görsel 009, 036, 039, 042 · yapı 020, 030 · güvence 010, 037, 041 · içerik 025, 008. "Çıta kıyası" satırı basılı işte bunlardan biriyle yazılabilir.
- **Hiçbir referans kusursuz değil:** beş puanlık 13 örneğin 7'sinde son okuma lekesi, 8'inde görülen karelerde ürün ekranı yok. B5 basılı işte de geçerli: her örnekten tek teknik alınır.
- **Ayrışma alanımız:** 55 örnekte okunur ürün ekranı 5, okunmaz 10, kalanında yok (dört dilimin ortak tespiti). Madde 2 basılı işte ayırt edicidir; kıyasta "ekran basılı boyda okunuyor mu" ayrı sorulur.
- **Kıyasa dört sayı eklenir:** ana başlık/gövde oranı (≥ 3×) · sayfa kelimesi (130–200) · gövde satırı (45–70 karakter) · sayfadaki vurgu noktası (≤ 4). Referans aralıkları 020, 039, 009, 041'den.
- **Madde 10'a basılı "kötü taraf" işaretleri:** cihaz maketi · fotoğraf üstü başlık · light gri gövde · tamamı büyük harf başlık · her sayfada çoklu düğme + sosyal ikon · boş arka kapak · üç yazı ailesi · anlamsız renk kodu (040, 019, 035, 048, 028, 006).
- **Madde 6 içeriği de kapsar:** dizideki her kart aynı yapıda; biri rakamsızsa hepsi yeniden (023/024/025 "DAYS", 032 ve 048 tablo hücreleri, 046 üç madde imi).
- **Tek biçim imzası (iki dilim):** belge boyunca ≥ 3 sayfada aynı biçim (017 çeyrek daire, 020 tek yuvarlak köşe, 041 kâğıt, 042 sol panel). AKAR'da imza B2'nin ışık çizgisidir (kuruma göre değişir); ikinci imza eklenmez, köşe dili yalnız ekran kırpmalarında.
- **Çizim kullanılıyorsa tek aile:** 023/024/025 ve 011 belge boyunca tek çizim dili; 028 s.3'te üç çizim dili tek sayfada dağılıyor. "Ustaca yapılamayan öğe girmez" kuralı sürer.
- **Kural sürer, açıklama (madde 5 "düz beyaz boşluk boş sayılır"):** madde 5 sahne içindir. Basılı okuma sayfasında dağıtılmış boşluk çıta işareti (041, 045, 038/039, 001 %55); boş sayılan, sayfa sonunda yığılan (012 %40, 013 %60, 035 %80) ya da dekorla doldurulan (014, 015) boşluktur.
- **B12'ye kanıt, değişiklik yok:** dar sütunda 7 satıra kırılan başlık merdiven olur (017 s.3); üç satırlık başlık sınırda (023 kapak). ≤ 2 dengeli satır kuralı yerinde.
- **Ölçüm yeşili kalite değildir (B9) referansta da doğrulandı:** 006 şablon olarak kusursuz tutarlı ve dilimin en zayıfı; 053 görsel olarak sıradan ama güven kurgusuyla 4 puan. İskelet ile zanaat ayrı ölçülür.

### Sunum arşivinden
50 kurumsal deste; kaynak (AKAR deposu): `tasarim/referans-kutuphanesi/arastirma-20260919/SENTEZ-sunum.md`. Numaralar referans arşivindeki `sunum-NNN` klasörleridir (46'sında yalnız 1/3/6. sayfa görüldü).
- **Ç-1 Kural sürer, açıklama (kapı 9 "tek dil").** Dört ajan "koyu kapak, açık içerik" gördü; referanslarda da en zayıf duranlar zemini karıştıranlar (043, 033, 035). Baştan sona koyu çıta örneklerinin koşulu: panel zeminden az açık, punto iri, slaytta yoğun tablo yok (> ~20 hücre → ek). (001, 012, 014, 015, 020, 031 · karşı 044)
- **Ç-3 Kural sürer, açıklama (kapı 2 / B1).** 005'in yeniden çizilmiş iskelet arayüzü yüksek puan aldı; B1 kazanır: gerçek kare, odak gerçek karenin üstünde soldurmayla kurulur. Eğik maket içinde okunmayan ekran kötü taraf işaretidir. (005 s.6, 011 s.1 · karşı 024 s.1, 008 s.8)
- **Ç-4 Sunum için çıta kıyası örnekleri** (teslim satırında adıyla): koyu sistem 012, 031, 001 · rakam ve künye 023, 029 · satış yayı ve kapak 011 · ekran gösterimi 027 s.6, 011 s.1 · fotoğrafsız tipografik sistem 050.
- **Ç-5 Kötü taraf işaretlerine sunum klişeleri:** gece şehri/ağ noktaları, tel kafes küre, gökdelen, devre kartı, avuçta dünya, tablete dokunan el, parçacık ağı dokusu, yapboz + gülümseyen yönetici, üretilmiş jenerik manzara, maskot, sahte arayüz taklidi. Biri varsa teslim yok. (033, 036, 037, 039, 049, 035, 022 s.6, 042 s.6, 032, 025, 044)
- **Ç-6 İkon sınavı.** Aynı ikon N kez, farklı roller için aynı piktogram, klişe dünya/kupa, başlıkta emoji → düş. Sekiz sayfa sıfır ikonla çıta olunuyor. (011, 050 · karşı 009, 024 s.6, 017 s.6, 043)
- **Ç-7 Kapak paleti içerikte yaşar;** şema renkleri palet dışına çıkamaz; aynı logonun iki rengi olmaz. Vurgu logodaki/üründeki tek noktadan türer. (031, 034 · karşı 030 s.6, 033 s.6, 035, 032, 044, 002)
- **Ç-8 Tek görsel imza iki ölçekte.** Markadan/üründen türemiş tek biçim kapakta ayrıntıyı işaretler, ayraçta sayfayı taşar, iç sayfada iz bırakır; süs köşeden köşeye gezmez. (022 s.1/s.3, 040, 042, 038 · karşı 041)
- **Ç-9 Boşluk odakla sayılır** (kapı 5'i ölçüler). Ana akışta ≥ %40 boş iyi; odaksız %60–70 boş "terk edilmiş alan". Ölçüt: tek belirgin odak · başlık–içerik arası ≤ içerik yüksekliğinin %30'u · metafor görseli genişliğin ≥ %60'ı. (011, 040, 014 · karşı 024 s.6, 030 s.3, 035 s.6, 018 s.6, 036 s.6)
- **Ç-10 Çizim başlığı birebir çizmiyor ve kanıt taşımıyorsa girmez;** güzel ama kanıtsız çizim bir slaydı sıfır kanıtla harcar. (iyi 018 s.6 fikri, 008 s.6 · karşı 020 s.3, 002 s.6, 039 s.3)
- **Ç-11 Rakam sahnesi.** Rakam etiketinin ≥ 2,5 katı, vurgu yalnız rakamda, etiket nötr; neyin rakamı olduğu söylenmeyen büyük rakam süs sayılır ve düşer; rakam panosuna slogan kutusu girmez. (015 s.3, 023 s.6, 045 s.6 · karşı 020 s.6 "10 üzeri n", 012 s.3 "1 Platform", 039 s.6)
- **Ç-12 Yer tutucu ve şablon artığı = teslim yok:** boş portre, boş logo hücresi, sabit kalmış sayfa no, başka belgenin alt bilgisi, iç sürüm etiketi, işletim sistemi duvar kâğıdı, dev puntoda yazım hatası, iki kez yazılmış satır. (004, 041 s.6, 003, 037, 010, 011 s.4, 005, 021 s.6)
- **Ç-13 Çıta kıyası sayımın yerine geçmez** (B9'un öbür yüzü). Çıta örneklerde bile taşma ve çakışma var; kıyas "geçti" olsa da çakışma 0 · taşma 0 · taban çizgisi ortak sayımı ayrıca koşulur. (011 s.7/s.8, 028 s.3, 008 s.9, 012 s.3)
- **Ç-14 Ton.** Şen portre, maskot, degrade + gölgeli dev başlık, neon kapak temkinli komiteye uymuyor; referanstan yapı alınır, renk ve şenlik alınmaz (B5'in sunum karşılığı). (karşı 004, 025, 040 kapak)
- **Ç-15 Referans duvarı biçimi (referans oluşunca; bugün KURULMAZ):** tek renk, eşit optik yükseklik, eş kutu ya da tek koyu bant, ≤ 12, boş hücre 0; alıntı sola hizalı düz yazı + ince çubuk + kurum adı. (001 s.6–8, 016 s.6, 037 s.3 · karşı 041 s.6, 017 s.6, 004 s.3)

### Kararlar (MÜTEVELLİ, 19 Eylül 13:1x — Sultan yetkiyi verdi: "sen karar ver")
İkisi de kurumdan bağımsızdır (basılı belgede açık okuma zemini · içerik slaytında ≤ 3 eş sütun).
- **Madde 9 "tek dil" basılı belgede GEVŞER (karar: evet; frontend-boost ile aynı).** Ekranda tek dil koyu sürer. Basılı belgede kapak/panel/kapanış koyu, okuma metni açık zeminde; iki zemin aynı yazı ailesi ve aynı vurguyla tek kompozisyon kuralına bağlanır, koyu alan ≤ %50 (008, 020, 036, 047; tamamı koyu 011 en zor sayfa).
- **Kapı 10 "eşit kutular" içerik slaytında GEVŞER (karar: evet).** ≤ 3 eş sütun, her sütun gerçek içerik taşıyorsa; sahnede ve kapakta yasak sürer; "hazır ikon + başlık" üçlüsü düşer (011, 001 s.3, 020 s.6, 050 s.3 · karşı 035 s.6).
