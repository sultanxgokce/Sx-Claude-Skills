---
name: frontend-boost
version: 0.5.0
allowed-tools: Bash, Read, Write, Edit
description: Bir sayfanın (karşılama sayfası, ürünün açılış ekranı, sunum kapağı, broşür kapağı) "bunu bir tasarımcı yapmış" dedirtecek biçimde, etkili ama yalın tasarlanması istendiğinde kullan. Tetikleyiciler — "/frontend-boost", "daha efektli ama minimal", "vasat durmasın", "premium görünsün", "landing page", "sahne", "wow etkisi". Formülü, belirteçleri, hazır şablonu, ölçüm araçlarını ve düşülen tuzakları içerir. Her UI ve tasarım işinde frontend-design ile BİRLİKTE çağrılır (Sultan 19 Eyl); sahne formülü yalnız önemli yüzeylerde, 'Devralınan disiplin' bölümü her işte (form, tablo, panel dahil) geçerlidir.
---

# frontend-boost — etkili ama yalın sayfa

**Doğduğu yer (17 Eylül 2026, AKAR):** Sultan açılış sayfası için "sıra dışı, etkili, modern" dedi. İlk teslim ölçümde kusursuzdu
(taşma 0, punto kanonu, hizalı tipografi) ve **reddedildi**: "tam olarak böyle bir şeyden bahsetmedim; daha efektli ama minimalliği
delmeden, bakınca bir tasarımcının elinden çıktığı anlaşılsın." Aynı fikir bu becerideki formülle yeniden çizildi ve cevap şu oldu:
"bayıldım, sonuna kadar git." Ders: **sessiz doğruluk etki değildir.** Etki, tek bir cesur öğeye harcanan ışık, ölçek ve harekettir.

## 🔴 YAMA YASAK — Sultan'ın ikinci dersi (18 Eylül 2026, sabah)
Işık sahnesi ürünün Bugün ekranına kondu, ölçümler yeşildi, Sultan **reddetti**: *"Grafik müthiş olmuş; ama eski sayfanın üzerine koyunca yama gibi durmuş — başka bir sitenin tasarımının bir bölümünü alıp bizimkinin üzerine yerleştirmişsin gibi. Sayfayı bütüncül olarak tasarlaman lazım; tek elden çıkmış gibi olsun. Eski tasarımın yok olmasında sıkıntı yok, gerekirse sıfırdan."*
**Kural (pazarlıksız):**
1. **Yama tasarım işi VERİLMEZ.** "Şu bölümü güzelleştir", "üst kısma sahne koy" diye iş açılmaz. İş birimi **sayfanın tamamıdır**: sahne + altındaki her bölüm (notlar, harita, tablo, dipnot) aynı yazı ailesi, aynı zemin mantığı, aynı aralık ve punto kümesi, aynı hareket kuralı.
2. **Yama TESLİM YASAK.** Sahnesi bitmiş ama altı eski kalan sayfa "hazır" denemez, pakete girmez, yayınlanmaz, Sultan'a gösterilmez. Kaydırınca "başka bir sayfaya geçtim" hissi veren her teslim **reddedilmiş sayılır** — ölçüm yeşil olsa da.
3. **Eski tasarımı korumak bir değer değildir.** Yeni dil sayfanın geri kalanına uymuyorsa geri kalan yeniden çizilir; "eskiyi bozmayalım" gerekçesiyle iki dil bir sayfada bırakılmaz.
4. **Sahnedeki nesne anlamını taşımalı.** Grafik güzel ama neyi saydığı okunmuyorsa ("Ferrari'ye Tofaş direksiyonu") bitmemiştir: eksen, ölçek, gösterge, tek satır açıklama sahnenin parçasıdır.
5. **Kendi ölçütün:** teslimden önce sayfayı en üstten en alta kaydır; iki farklı elin izi görünüyorsa iş bitmemiştir. Bunu kareyle kanıtla (tam boy kare, üç genişlik).

## 🔴 TASARIM ÇITASI — dördüncü kapı (18 Eylül 2026)
Görsel seviye kapısı `tasarim-citasi` becerisidir (referans tasarımcı kütüphanesi + kapı maddeleri). **Referans kütüphanesine erişen kutuda uygulanır** ve teslim mektubuna "çıta kıyası: <örnek> — geçti" satırı yazılır.
**Kütüphaneye erişemeyen kutuda** mektuba "çıta kıyası yapılamadı (kütüphane yok)" yazılır — **sessizce atlanmaz**, "geçti" sayılmaz. Kütüphane yolu `TASARIM_CITASI_KUTUPHANE` ile verilir (ayrıntı o beceride).

## 🔴 ÜÇ İLKE KAPISI — Sultan'ın üçüncü dersi (18 Eylül 2026, 11:02)
mukarnas.net ana sayfa v14b Sultan'a gitti; sahne şıktı, ölçümler yeşildi. Sultan altı eleştiri döndürdü: *"kesit çizimi amatör yapılmış kötü bir rölöve gibi"*, *"öğeler hizasız ve medya açılmıyor"* (görsel `file:///` yolundaydı, Sultan'ın ekranında siyah kutu), *"'Kurumsal sistemler geliştiriyoruz. Ankara.' amatör oldu, yazı ile arka plan ilişkisi oturmadı"*, *"tüm sayfadaki ifadeler kontrol edilmeli; anlamsız, anlamı düşük, saçma şey yazmamalı; önemli noktalara vurgu"*, *"adım hiçbir yerde geçmesin"*. Sonra kural koydu: **"Kurumsallık, orijinallik ve güçlü anlatım ilkelerinden geçmeyen tasarımlar bana sunulmayacak."**
**Kapı (pazarlıksız — Sultan'a sunmadan önce üçü de "geçti" olmalı; biri kalırsa teslim yok):**
1. **Kurumsallık.** Her öğe bir profesyonelin elinden çıkmış gibi durur. Amatör görünen tek çizim, tek ikon, tek çerçeve sayfayı düşürür: **ustaca yapılamayan öğe sayfaya girmez** (kesit çizilemiyorsa kesit yok; planla aynı elden ikinci plan). Aynı tür öğeler tek çerçeve dili (köşe, çizgi ağırlığı, gölge), tek boşluk ritmi, tek hiza çizgisi. Kişi adı hiçbir yerde; kurum kimliği kurum adıyla.
2. **Orijinallik.** Sayfa tek fikirden çıkmış görünür ve o fikir gövdede de sürer (sahnedeki motif alt bölümlerde iz bırakır). Aynı kahraman iki sayfada kullanılmaz. Şablon kokan kalıp ("… geliştiriyoruz. Şehir.") yok.
3. **Güçlü anlatım.** Her cümle bir iş görür; anlamı düşük, dolgu, "saçma" cümle sıfır. Önemli 3–5 nokta görünür biçimde vurgulanır (boy, yer, mürekkep), gerisi sessiz. Alt cümle başlıkla aynı aileden, aynı hizada, zeminle konumla bağ kurar — küçük gri sans koyu zeminde yüzmez. Metin denetimi ayrı bir göz (yazı sahibi) tarafından satır satır yapılır; sonucu yazılıdır.
**Teslim öncesi zorunlu prova:** hub kopyasını **kutudan bağımsız** aç (geçici klasöre kopyala; `file:///` ve mutlak yol 0; görsel/yazı tipi gömülü), 1440/1360/390 tam boy kareye bak, hiza çizgilerini ölç (metin bloğu ile görsel aynı üst çizgide; dikiş/çizgi görselin üstünden geçmez), sayfada kişi adı 0. Bu üç ilkeden geçtiğini **tek satırla yazıp** teslim et; yazmadan sunulan iş sunulmamış sayılır.

## 🔴 İKİ BECERİ BİRLİKTE ZORUNLU — Sultan'ın dördüncü dersi (19 Eylül 2026)
Sultan: "/frontend-boost ve /frontend-design komutunun ikisi de UI ve tasarım işlerinde zorunlu." ve "frontend-boost içine frontend-design'daki güçlü her şeyi aktar; tasarımı geliştirecek, konseptimizle uyumlu şeyleri aktar, zayıflatacak şeyleri aktarma. frontend-boost öbürünün **daha üst düzey hâli** olacak; her şeyde kullanılmayacak ama önemli yerlerde kullanılacak."
- **Her UI/tasarım işinde** (sayfa, ekran, panel, sunum, broşür, not) işe başlamadan **ikisi de çağrılır**: önce `frontend-design`, sonra `frontend-boost`. Teslim mektubunda satır: "beceriler: frontend-design + frontend-boost çağrıldı".
- **Sahne formülü** (aşağıdaki altı parça) yalnız **önemli yüzeylerde** uygulanır: karşılama, ürünün açılış ekranı, kapaklar, demoda ilk görülen ana ekranlar. Form, tablo, panel gibi çalışma yüzeylerinde sahne kurulmaz; ama aşağıdaki **"Devralınan disiplin"** bölümü ve `arayuz-zanaati` **her işte** geçerlidir.
- Kardeşler: görsel seviye `tasarim-citasi` · zanaat `arayuz-zanaati` · içerik `brosur-hazirlama/ICERIK.md`, `sunum-hazirlama`.

## Devralınan disiplin — frontend-design'ın güçlü yanları (her işte)
**1. Konuya yaslan.** İşe başlamadan üç şeyi yaz: **konu · okur · sayfanın tek işi.** Ayırt edici seçimler konunun kendi dünyasından gelir (malzemesi, araçları, dili). Sayfada **en az bir ayrıntı yalnız bu konuya özgü** olur: gerçek birimleri ve ölçekleri, belge gelenekleri, meslek terimleri (AKAR'da: yenileme günü, beş yıl kapısı, kira yolu, TÜFE ayı). Gerçek içerikle kur; yer tutucu metinle tasarım yapılmaz.
**2. İki geçişli çalışma: önce plan, sonra kod.** Koddan önce kısa **tasarım planı**: renk (4–6 adlı değer) · yazı (yüzler ve rolleri) · yerleşim (tek cümle + kaba tel kafes; sola mı ortaya mı hizalı) · bu sayfayı özgün kılan ilkeler. Sonra **planı brife karşı oku:** "benzer her sayfa için üreteceğim varsayılan bu mu?" Öyleyse o parçayı değiştir, neyi neden değiştirdiğini yaz. Kod ancak bundan sonra, plana sadık kalarak. (Bizde plan = B6 "önce konsept, sonra sayfa".)
**3. Yazı zanaatı.** Bir ya da iki aile; ikiyse **açıkça farklı** (bizde ince serif cümle + grotesk). Boy ölçeği belli ve ona sadık; ağırlık, genişlik, aralık bilinçli. Satır < 80 karakter (gövde ≈ 65); serif gövdeye biraz fazla satır aralığı; başlıkta `text-wrap: balance`. Yazı başlık olarak kullanılıyorsa **kendisi tasarım öğesidir**, içerik taşıyan nötr araç değil.
**4. Yapı bilgidir.** Çerçeve, kenarlık, numara, üst etiket, ayırıcı içerik hakkında **doğru bir şey söylemiyorsa konmaz**. Numaralı işaret (01/02/03) yalnız içerik gerçekten sıraysa. Başlık üstüne gereksiz etiket yok. Kart her şeyin kabı değildir: kenarlık, dolgu, yarıçap, gölge "ayrı nesne" der; role göre harca, her bloğa aynı damgayı vurma.
**5. Cesareti tek yerde harca; sonra bir şey çıkar.** Bir öğe akılda kalan şeydir, çevresi sessiz ve disiplinlidir; brife hizmet etmeyen süs kesilir. Teslimden önce aynaya bak ve **bir aksesuarı çıkar**. Karmaşıklığı vizyonla eşle: sade yönde incelik aralıkta, yazıda, ayrıntıda aranır.
**6. Sayfa dururken de tamdır.** Okunacak her şey yüklenince görünür; bölüm gözlemci beklerken `opacity:0`'da park etmez. İlk hareketsiz kare paylaşılan bağlantının, küçük resmin ve göz gezdiren okurun gördüğüdür. Araç ya da uygulama **gerçekçi çalışır hâlde** açılır (örnek veriyle, açıkça işaretli); boş kabuk hiçbir şey göstermez.
**7. Metin tasarım malzemesidir.** Kullanıcının tarafından yaz: sistemin kuruluşuna göre değil, insanın tanıdığı adla. Etken çatı. Düğme **ne olacağını** söyler ve ad akış boyunca aynı kalır ("Onayla" → "Onaylandı"). Hata özür dilemez, belirsiz kalmaz: ne oldu, nasıl düzelir. Boş ekran eyleme davettir. Her metin öğesi **tek iş** görür. Belirli olan zekice olandan iyidir.
**8. Hareket.** Kullanıcı tetiklemeyen hareket az ve bilinçli: tek düzenli an (bizde formül 6). Her bölümde aşağıdan süzülen giriş ve her kartta hover geçişi "yapay zekâ yaptı" dedirtir. Kullanıcının eylemine cevap veren hareket (açılma, genişleme, onay) neyin değiştiğini gösteriyorsa iyidir.
**9. Kalite tabanı, ilan etmeden.** Dar ekrana kadar duyarlı · klavye odağı görünür · hareket azaltma tercihi sayılır · kontrast yeterli · uyumlu palet. CSS'te seçici özgüllüğüne dikkat: tür seçici (`.bolum`) ile öğe seçici (`.eylem`) birbirinin dolgusunu sessizce iptal eder; kardeş gruplarda boşluğu `gap` versin. Gri seçilmiş olsun: vurguya hafif eğilimli nötr, saf orta gri değil.
**10. Yapay zekâ işi görünümünün bilinen kümeleri** ("Asla" listesine ek; brif açıkça istemedikçe): krem zemin + yüksek kontrast serif + **kiremit/terrakota vurgu** · siyaha yakın zemin + tek asit yeşili ya da al vurgu · gazete düzeni (kıl çizgi, sıfır yarıçap, sık sütun) · mor-mavi geçişli kahraman · "güvenli" diye Inter ya da Space Grotesk · bölüm işareti olarak emoji · her şey ortalı · her şeyde aynı yarıçap ve aynı yumuşak gri gölge · yuvarlak kartta yan vurgu şeridi · küçük veri etiketinde eş aralıklı yazı · "SÖZCÜK — parça" kalıplı etiket.
**11. Denediklerini yaz.** İnsan tasarımcının belleği vardır, hep yeni bir şey dener. Neyi denediğini, neyin beğenilip neyin reddedildiğini not et (AKAR'da `tasarim/referans-kutuphanesi/BEGENI-ANALIZI-*.md`, tasarim-citasi B kuralları).

**Bilerek DEVRALINMAYANLAR (konseptimizi zayıflatır):** "her iş için başkasıyla karıştırılmayacak yeni bir kimlik, yeni palet, yeni yazı ailesi" — bizde kimlik sabittir (sıcak koyu sahne, tek ışık rengi, ince serif cümle + grotesk); özgünlük paleti değil **kahraman nesneyi ve fikri** değiştirerek aranır · "iki temayı da tasarla" — Sultan 19 Eyl: ürün dili tam koyu, açık mod sonra · "kahramanı içeriğe göre boyutla, ekran boyu açılış yapma" — bizde sahne ilk ekranı kaplar, koşul: eylem ilk ekranda (1512×825) · veri birleştirici orta nokta ("Akdeniz · Pazarcık") bizde veri dilidir, yasak sayılmaz; yasak olan onu süs etiketi zinciri yapmaktır.

## Ne zaman, ne zaman değil
| Kullan | Kullanma |
|---|---|
| Karşılama (landing) sayfası · ürünün açılış ekranı (**tamamı** — üst bölüm tek başına yama olur, bkz. YAMA YASAK) · sunum ve broşür kapağı · tanıtım görseli | **Sahne kurma:** form, tablo, ayar, liste, panel ekranları — orada ürünün kendi dili + bu becerinin "Devralınan disiplin" bölümü + `arayuz-zanaati` geçerlidir |
Kural: sayfa başına **tek sahne**. Etki her yere yayılırsa etki olmaktan çıkar.

## Formül — altı parça, hepsi birden
1. **Sahne.** Sayfanın bir bölümü öteki her şeyden ayrılır: ya derin, sıcak-koyu bir zemin (düz siyah değil; iki katmanlı ışık + çok hafif kumlanma)
   ya da nötr bir stüdyo zemini (açık gri, iri ve yumuşak köşeli levhalar). Geri kalan sayfa sakin kalır; karşıtlık dramı üretir.
2. **Tek kahraman nesne.** Sahnede gözün gideceği **bir** şey vardır ve o, konunun kendi dünyasından gelir (AKAR'da: zaman cetveli; karşılamada: havada duran ürün ekranı).
   Hazır ikon, stok çizim, soyut küre **değil**. Nesne gerçek veriyi/ürünü gösterir.
3. **Yazı bir görsel öğedir.** İki uçtan biri: çok iri, geniş ve ağır yazı (nesnenin **arkasında**, yarısı dolu yarısı kontur) **ya da** çok büyük ve **ince** serif bir cümle.
   İkisi aynı sahnede kullanılmaz. Sahne dışındaki metin ürünün olağan ölçeğinde kalır.
4. **Tek ışık, tek vurgu.** Sahnede yalnız **bir** öğe parlar (bir çizgi, bir düğme, iki sayı). Vurgu rengi tektir ve markadan türer. Parıltı/bulanıklık süzgeci **tek öğede**.
5. **Derinlik.** Nesne havada durur: altında bulanık **elips gölge**, hafif perspektif (rotateX 4–8°, rotateY 3–7°), yavaş süzülme (6–8 sn, 10–14 px). Veri grafiğinde derinlik = uzaklaştıkça solma + yukarıdan aşağı sönen dolgu.
6. **Bir açılış anı + bir dokunuş.** Sayfa açılırken **tek** düzenli hareket (≤ 2,6 sn): öğeler bir yönden dalga gibi gelir, sayılar sayarak oturur. Sonra hareket yalnız kullanıcıya cevaptır:
   imleci izleyen eğim, imlecin altında büyüyen çubuklar, okunan değer. Her kartta ayrı efekt **yok**.

## Asla (bunlar ucuz durur, ve "yapay zekâ yaptı" dedirtir)
Mor-mavi geçiş · neon · cam kart yığını · her şeyin aynı yuvarlak kartta durması · ortalanmış dev rakam + küçük etiket · robot/sohbet balonu ·
her bölümde aşağıdan süzülen giriş · düz `#000`/`#111` zemin + asit yeşili · izlemeli BÜYÜK HARF etiketler · bağlantı sonuna "→" · stok 3B küre.
Yapay zekâ varlığı süsle değil **içerikle** gösterilir: sayfa cümleyle konuşur, her sayının dayanağını yazar, bilmediği yerde "eksik veri" der.

## Süreç (sıra değişmez)
1. **Hangi sayfa?** "Açılış sayfası" iki anlama gelir: ürüne girince karşılayan ekran **ya da** herkese açık karşılama sayfası. **Sor, varsayma.** (AKAR'da yanlış varsayım bir tur kaybettirdi.)
2. **Örnek iste.** İnsan "etkili" derken aklında bir görüntü vardır. Beğendiği 2–3 sayfayı/ekran görüntüsünü iste; formülünü **çöz** (neyin iri, neyin parlak, neyin havada olduğu), kopyalama.
   Galeri önerileri: godly.website · land-book.com · awwwards.com · saaslandingpage.com · onepagelove.com. Hazır efektli parçalar: ui.aceternity.com · magicui.design · reactbits.dev · tympanus.net/codrops.
3. **Kahraman nesneyi seç** — konunun dünyasından. Bulamıyorsan henüz konuyu anlamamışsındır.
4. `frontend-design` becerisini çağır (**zorunlu**, her işte); bu beceri onun **üstüne** biner ve güçlü yanlarını "Devralınan disiplin"de taşır. Tasarım planını yaz, brife karşı oku, sonra kodla.
5. **Tek dosya prototip** üret: gömülü yazı tipi, gömülü veri, dış istek 0. Şablon: `sablon/sahne.css` + `sablon/landing-iskelet.html`.
6. **Kendi gözünle bak** (Playwright ile kare al, aç, bak). İlk karede her zaman kusur vardır: kesik etiket, yazının üstüne binen rozet, sert kenarlı ışık.
7. **Ölç:** yatay taşma (1440 · 1280 · 390) · dış istek · `prefers-reduced-motion` altında hareket 0 · kontrast `arac/kontrast-olc.mjs` ile **gerçek zemin pikselinden**.
8. **Hareketsiz görüntü etkiyi taşımaz.** İnsana kareyi **ve** dosyanın kendisini gönder; "bilgisayarda açın, fareyi gezdirin" de.

## Belirteçler (başlangıç değerleri; markaya göre çevir, adları koru)
`sablon/sahne.css` içinde tam hâli. Özet:
- Koyu sahne: `--sahne-1 #120e0a` → `--sahne-2 #241a10` · sıcak bölge `#3a2914` · ışık `--isik #f0cf9c` · ışık havuzu `rgba(isik,.17)` 340×460 elips · kumlanma .09 `overlay`.
- Metin: `--sahne-metin #f4ede2` · `--sahne-soluk #c8bcaa` · ışık havuzuna düşen etiketler `--sahne-soluk-yakin #ded4c4`.
- Stüdyo sahnesi: zemin `#e9e8e4` · mürekkep `#141311` · levhalar 120 px yarıçap, 45° · vurgu kehribar `#e0a040`.
- Büyük cümle: 60 / 52 / 32 px (≥1341 / 721–1340 / ≤720), ince (300), satır aralığı 1,12, harf aralığı −0,02em. **`clamp()` kullanma** — ölçüm araçları göremez; kırılma başına düz değer.
- Dev yazı: 27vw (en çok 420 px), ağırlık 900, genişlik 125, satır aralığı .8; yarısı `-webkit-text-stroke:2px` kontur.
- Hap düğme: koyu zemin, içinde 28 px vurgu renkli yuvarlak ok; üzerine gelince ok 3 px kayar.

## Yazı tipi
- Alışılmış güvenli seçimler yerine konu için seçilmiş aile. AKAR'da: **Archivo** (ölçen; genişlik ekseni 62–125 ile tek aileden hem dar etiket hem dev başlık) + **Literata ince** (konuşan).
- Üründe paket yükü önemliyse **sabit yüz + karakter alt kümesi**: `arac/font-altkume.py` Google Fonts'tan yalnız gereken karakterleri çeker.
  Ölçüldü: 4 yüz değişken **367 KB → 3 sabit yüz 57 KB**. Bedeli: genişlik ve optik boyut eksenleri gider. Karşılama sayfasında (paket derdi yoksa) değişken dosya kalabilir.
- Kutuda `fonttools` olmayabilir; alt küme için Google'ın `&text=` parametresi yeter. Eski tarayıcı kimliğiyle istenirse sabit ağırlıklı `woff` döner.

## Düşülen tuzaklar (hepsi ölçüldü)
| Tuzak | Ne oldu | Panzehir |
|---|---|---|
| Hesapla kontrast | Soluk metin için "≈6,2" dedim; ışık havuzunun içinde gerçek değer **4,3** çıktı | Kontrastı **zemin pikselinden** ölç (`arac/kontrast-olc.mjs`); ışığa düşen etiketlere ayrı, daha açık renk |
| Tam sayfa ekran görüntüsü | `fullPage` çekim 3B dönüşümlü nesneyi ve `clip-path` animasyonlu grafiği **boş** çekti | Önce sayfa boyunu ölç, görünüm alanını o boya getir, normal çekim al |
| Animasyon + yeniden çizim | `innerHTML` ile yeniden çizilen SVG her seferinde açılış animasyonunu baştan oynattı | Açılış sınıfını kapsayıcıya koy, 2,6 sn sonra kaldır |
| CSS özgüllüğü | `.yukleniyor{display:none}` sonradan gelen `.bekle{display:grid}`'e yenildi; iskelet dolu sayfada göründü | Durum sınıflarını `body[data-durum]` altında yaz |
| Gizlenen ebeveyn | Dar ekranda cihazı gizleyince içindeki telefon da gitti | Dar ekranda ebeveyni değil, **çocuğu** gizle |
| Rozet yazının üstünde | Havada duran etiket cümleyi kapattı | Rozetleri nesnenin **kenarına ya da dışına** koy; her genişlikte bak |
| Ölçer kör | Bileşen işareti olmayan dosyada yoğunluk ölçeri hiçbir şey ölçmeden "temiz" dedi | Prototipe de `<!-- bilesen: Ad -->` imlerini koy; ölçerin uyarı satırını oku |
| İkili dosya | Gizlilik kapısı PNG'yi depoya almadı | Kareler hub'a; depoya yalnız künye (ad + sha256) |

## Bitti sayılma ölçütü
- [ ] `frontend-design` + `frontend-boost` çağrıldı (mektupta satır) · konu, okur, tek iş yazılı · tasarım planı brife karşı okundu · bir aksesuar çıkarıldı
- [ ] Hangi sayfa olduğu yazılı · insanın örneği alındı ve formülü çözüldü
- [ ] Tek sahne · tek kahraman nesne · tek parlak öğe · tek açılış anı
- [ ] 1440 · 1280 · 390: yatay taşma 0, kesik metin 0 · dış istek 0 · sayfa hatası 0
- [ ] Hareket azaltma tercihinde hareket 0 · odak halkası görünür
- [ ] Sahnedeki her metin gerçek zemine göre ≥ 5,5 (en açık piksele göre ≥ 4,5)
- [ ] Kareye **kendi gözünle** bakıldı · insana kare **ve** dosya gitti
- [ ] Ürüne girecekse: sahne ayrı bir yüzey olarak reçetelendi (sınırları ölçülebilir), kapı **gevşetilmedi**
- [ ] **Yama değil:** sayfanın tamamı aynı elden (yazı ailesi, zemin, aralık, punto, hareket); tam boy karede tek dil; sahnenin altı eski kalmış sayfa **teslim edilmedi**
- [ ] **Üç ilke kapısı:** kurumsallık (amatör öğe 0, tek çerçeve dili, kişi adı 0) · orijinallik (tek fikir gövdede sürer, kahraman tekrarı 0) · güçlü anlatım (zayıf cümle 0, 3–5 vurgu, yazı sahibi denetimi yazılı) · hub kopyası kutudan bağımsız açıldı, `file:///` 0

## Paket içeriği
`sablon/sahne.css` belirteçler + koyu sahne + stüdyo sahnesi + hap düğme + dev yazı + havada duran nesne ·
`sablon/landing-iskelet.html` çalışan en küçük karşılama sayfası · `arac/kontrast-olc.mjs` piksel tabanlı kontrast (varsayılan seçiciler `.sahne` içindeki `text.ce`, `.gun`, `.okuma span` vb. — kendi sayfana göre seçici listesini değiştir; 1440 açık/koyu · 1280 · 390'da koşar; Playwright yolu kutuya göre ayarlanır) ·
`arac/font-altkume.py` karakter alt kümeli gömülebilir yazı tipi · `komut/frontend-boost.md` eğik çizgi komutu.
Canlı örnekler (AKAR deposu): `tasarim/prototip-acilis/bugun-v2.html` (koyu sahne, veri nesnesi) · `landing.html` (stüdyo sahnesi, havada ürün) · reçete `tasarim/SAHNE-YUZEYI-RECETESI-20260917.md`.

## Referans arşivinden dersler (19-09)

### Broşür arşivinden
Kaynak (AKAR deposu): `tasarim/referans-kutuphanesi/arastirma-20260919/SENTEZ-brosur.md`; örnek numaraları o arşivdendir, arşivi görmeyen kutuda kurallar yine geçerlidir. Basılı/PDF belge kapağı ve sayfası içindir; ekran sahnesi kuralları değişmez.
- **Belge kapağı iki bölge:** metin paneli %35–50 + tek görsel %50–65, metin panelin sol kenarında tek sütun (007, 008, 009, 017). Kapağın ≥ %40'ı boş, en çok dört öge (036/037 %60, 023 %60).
- **Başlık düz zemine oturur:** görsel üstüne yazı yok ya da altında ≥ %85 opak düz zemin (karşı örnek 019 s.1, 016 kapak).
- **Vurgunun dört sabit rolü:** başlık parçası · rakam · etiket · çağrı; sayfa başına ≤ 4 nokta, gövde ve alıntı paragrafında 0 (020, 009, 036, 038). Karşı: 033 s.3, 050 (5+ rol), 018 s.6 (üç renkli 1-2-3).
- **Kural sürer, açıklama (tek vurgu):** 003'te çağrı belgedeki tek kırmızı öge, yani ikinci vurgu; alınmaz. Bizde çağrı belgedeki tek DOLU ışık renkli kutu olarak ayrışır, öteki vurgular çizgi ve yazıdır.
- **Üçüncü taraf renkleri** (logo, rozet) tek renge indirgenir ya da kendi kabında durur (010 kapak, 039 s.2); paleti bozan örnek 035 s.6, 010 s.6.
- **Dev punto olmadan odak:** aynı başlıkta ince + kalın ağırlık karşıtlığı tercih edilir (020, 029, 047); tek sözcüğü renkle vurgulamak üretilmiş sayfa tadı verir (frontend-design uyarısı), yalnız vurgulanan kısım tek başına anlamlıysa (D10). İnce (300) ağırlık yalnız büyük cümlede; gövdede light + gri yasak (019, 022, 040, 014).
- **Formül 5'in basılı karşılığı:** derinlik = gölgeli ekran katmanı (038 büyütülmüş bileşen, 042 üst üste iki ekran). Perspektif eğim basılıda rakamı okunmaz kılar (012 eğik ekran); basılı karede eğim 0.
- **Izgara seçimi:** ekran/görsel kahramansa 45/55 (030, 009 s.6, 017); metin + özet/çağrı ise 2/3 + 1/3, dar sütun yalnız özet, rakam ya da çağrı taşır (042, 049, 055).
- **Yan panel (tek dilim):** sayfada en çok bir farklı zeminli panel, ≤ 1/3, sayfadan sayfaya kenar değiştirir (025 s.2 sol, s.4 sağ); kapanışta tam boy koyu sonuç paneli (023/024 s.5).
- **Kapak–arka kapak aynası (tek dilim):** arka yüz kapağın görsel fikrini ters çevirir (030 s.1 ↔ s.6); B13 "altbilgi de orijinal" ile aynı yönde.
- **"Asla" listesine basılı klişeler:** küre + ağ, dişli, cam bina, çokgen desen, yükselen ok + çubuk, insansı robot, altıgen akıllı şehir, kavisli şerit, maskot (005, 006, 033, 035, 054, 050, 031, 004, 043). 55 örneğin ≥ 21'inde; beş puanlıklar bile bununla puan kaybediyor (003, 020).
- **Kural sürer, açıklama (stok fotoğraf yasağı):** 030'un stok fotoğraf + marka çizgisi bindirmesi ve 007/017'nin gerçek mekân fotoğrafı alınmaz. Bizde kahraman gerçek ürün karesidir (B1); fotoğraf kahraman olmaz.
- **Süs veriyi örtmez:** çizim, maskot, 3B öge ekranın ya da tablonun üstüne binmez, örtüşme 0 (043 s.2, 044 s.3); bilgi taşımayan görsel sayfanın ≤ %15'i (042 sunucu kabini).

### Sunum arşivinden
Sunum yüzeyi (kapak, ayraç, içerik slaytı) için; kaynak (AKAR deposu): `tasarim/referans-kutuphanesi/arastirma-20260919/SENTEZ-sunum.md`. Örnek numaraları referans arşivindeki `sunum-NNN` klasörleridir.
- **D1 Deste ölçek kümesi.** Slayt başlığı / gövde ≥ 2,5 (taban 2,2; 1,8 altı başlık gibi okunmaz); kapak ve ayraçta ≥ 4. Ölçek 1,6'da kalıyorsa ağırlık farkı Regular→Black. (001, 023, 040, 050, 026 s.6 · karşı 035, 032, 024, 036)
- **D3 Kural sürer, açıklama (yazı ailesi).** Yedi ajan "tek aile" dedi; bozan, ikinci ailenin plansız sızması. İki aile kimliğimiz sürer, roller kilitli: serif yalnız kapak/ayraç cümlesi ve başlıkta tek vurgu; gövde, tablo, etiket, dipnot tek grotesk; üçüncüsü (dışa aktarımda Arial) hata. (005 · karşı 042 s.3, 046, 017 s.6, 036)
- **D4 En küçük yazı** slayt yüksekliğinin ≥ %2,5'i, dipnot ≥ %2 (1080 yükseklikte 27 / 22 px). Koyu zeminde gri italik dipnot yok. İyi örneklerin ortak zaafı. (karşı 012 s.3, 013 s.3, 015 s.6, 040 şerit, 045 s.6, 050 s.6)
- **D5 Slayt satırı.** Sütunda ≤ 45 karakter, hiçbir koşulda > 75; sütun ≥ 25 karakter; ortalı gövde ≤ 3 satır; etiket ≤ 3 satıra kırılır. (011, 040 · karşı 010 s.3, 017 s.6, 024 s.6, 036 s.3)
- **D6 Sabit iskelet.** Başlık aynı y'de, tek sol hiza, kenar payı ≥ %5; alt ~40 px yalnız künyenin, hiçbir kutu o kuşağa girmez. İçerik başlıkla aynı sol hizadan başlar. (001, 008, 023, 034 · karşı 028 s.3, 009, 034 s.6)
- **D7 Eş sütun zanaatı** (eş sütun kullanılan yerde): eş kartlarda satır sayısı ±1, rakam taban çizgisi ortak, boş hücre 0 — tutmuyorsa kart sayısı azaltılır; 4×2 yalnız KPI panosunda. (011, 001 s.3, 050 s.3 · karşı 012 s.3, 020 s.6, 046 s.3, 041 s.6)
- **D8 Koyu destede veri.** Panel zeminden ~%8 açık; yalnız anlatılan seri doygun, ötekiler ≤ %30; lejant yok; değer çubuğun üstünde/içinde YATAY; eksen ızgarası yok; grafik başlığı hüküm ya da ölçü + birim. (012 s.6, 013 s.3, 015 s.3, 031 s.3, 045 s.6 · kusur 031 dikey değer, 013 45° etiket, 023 çift bilgi)
- **D9 Tablo.** Yalnız yatay ince çizgi; zebra, dolgu, parıltı yok; değer sütunu kalın ve tek hizada; ≤ 7 satır; bakılacak tek sütun çerçeveyle kutulanır; hücre iç payı ≥ yazı yüksekliğinin yarısı. (019 s.3, 021, 026 s.6, 038 s.6 · karşı 024 s.3, 032 s.6, 036 s.6)
- **D10 Başlıkta vurgu ≤ 3 kelime:** ışık rengi ya da ağırlık karşıtlığı; vurgulu kısım tek başına anlamlı. Gövde metni kalın ya da vurgu renginde yazılmaz. (016 s.6, 019, 020, 034, 014 s.3 · karşı 046 s.3, 008 s.5)
- **D11 Kural sürer, açıklama (tek vurgu).** Süs olarak ikinci renk yasağı sürer; eşik aşan değer için tek uyarı rengi veri kodudur: yalnız o değerde, lejantı aynı slaytta. Olumsuz değer vurgu renginde gösterilmez, griyle yumuşatılmaz; nedeni yanına yazılır. (karşı 029 s.3, 039 s.6 · iyi 038 s.6, 050 s.6)
- **D12 Kapak jesti.** ≤ 3 tipografi kademesi; tek görsel öğe genişliğin ≤ %40'ı (kahraman ürün ekranıysa 45–55), metinle çakışmaz; aynı motif ayraçta büyük ölçekte döner. Kutu içinde başlık, çift logo, beş kademe yok. (015, 019, 022, 040, 042 · karşı 033, 049)
- **D13 Ürün ekranı slaytta.** Okunmuyorsa girmez. Tek özelliği anlatırken gerçek karenin yakın planı, anlatılan öğe tam kontrast, çevresi soldurulmuş; mozaik maketsiz ≤ 6 karo, ≥ 8 px oluk, aynı köşede etiket hapı; ≥ 2× çözünürlük; yükleme/boş durum karesi yok. Kural sürer (B1): 005'in yeniden çizilmiş arayüzü alınmaz, gerçek kare üstünde soldurma. (005 s.6, 027 s.6, 011 s.1, 001 s.2 · karşı 008 s.8, 024 s.1, 003 s.6, 027 s.3)
- **D14 Süs veriyle yarışmaz.** Şemanın arkasında ızgara/ışık huzmesi yok; vurgu şeridi etiket kapatmaz; rakamın arkasına yarım binen hap yok; metin arkasında desen yok. (karşı 015 s.6, 028 s.6, 011 s.6, 036 s.3, 025 s.3)
- **D15 Dışa aktarım denetimi.** Slayt oranı = çıktı oranı (boş bant 0 px) · yazı tipi gömülü · en-boy bozulması 0 · dışa aktarım artığı 0 · PDF'te kesik kart ızgarası 0. (karşı 044, 049, 041 s.3, 042, 036, 001 s.5)

### Kararlar (MÜTEVELLİ, 19 Eylül 13:1x — Sultan yetkiyi verdi: "sen karar ver")
- **Basılı belgede okuma metni AÇIK zeminde (karar: evet).** Ekran ve sahne tam koyu kalır (S1). Basılı broşür, föy, toplantı notunda: kapak, panel ve kapanış bandı koyu; uzun okuma metni açık zeminde; ürün ekranı kesitleri koyu olarak açık zemine çerçeveyle oturur. Tek belgede iki zemin bir kompozisyon kuralıyla bağlanır (aynı yazı ailesi, aynı vurgu rengi, koyu alan ≤ %50) (008 %40, 020 s.1 %52, 047 %26; karşı 033 s.3, 011).
- **Pano slaytında karo ızgarası kabul (karar: evet, sunum-hazirlama S8 ile birlikte).** Sola hizalı, 3–6 karo, rakam / etiket ≥ 2,5 (tercihen 3), künyeli. Sahnede ve kapakta "ortalanmış dev rakam + küçük etiket" yasağı sürer (015, 020, 023, 029, 045 · karşı 039 s.6).
- **İçerik slaytında ≤ 3 eş sütun kabul (karar: evet).** Her sütun gerçek içerik (rakam, sorun, adım) taşırsa; "hazır ikon + başlık" üçlüsü yine düşer; sahnede ve kapakta yasak sürer (`tasarim-citasi` kapı 10 ile aynı karar; 011, 001 s.3, 050 s.3 · karşı 035 s.6).

## Taşınabilirlik (MUAVİN, 2026-09-17 · filo geneli paketleme)
Bu beceri AKAR kutusunda doğdu; araçlar o kutunun yollarına sabitlenmişti. Filo geneline alınırken ölçüldü ve düzeltildi:

| Konu | Eski hâl | Şimdi |
|---|---|---|
| Tarayıcı çalışma-zamanı | `/config/tooling/pw-runtime` **sabit** → başka kutuda "Cannot find module" | env → bilinen adaylar → normal çözümleme; hiçbiri yoksa **rc=3 ÖLÇÜLEMEDİ** |
| Seçiciler tutmazsa | `0 metin` basıp temiz görünüyordu | **rc=3**, "bu sayfa ÖLÇÜLMEDİ, temiz DEĞİL" |
| Özel seçici gizlenmiyordu (19-09) | `FRONTEND_BOOST_SECICILER` ile verilen metin saydam yapılmıyor, yazının kendi pikseli okunuyor, oran **1,00** → sahte ihlal | gizleme = sabit liste ∪ SECICILER; oranı 1,00 kalan kutu **rc=3 ölçülemedi**; tarayıcı başlamazsa da rc=3 (eskiden yığın izi + rc=1) |
| Yazı tipi aracı argümansız | Python yığın izi | düz kullanım iletisi, **rc=2** |

Ayarlar: `FRONTEND_BOOST_PW` (playwright-core yolu) · `FRONTEND_BOOST_PW_LIBS` · `FRONTEND_BOOST_SAHNE` · `FRONTEND_BOOST_SECICILER`.
Çıkış kodları — kontrast: `0` temiz · `1` eşik aşıldı · `2` kullanım · `3` ölçülemedi. Yazı tipi: `0` yazıldı · `1` kaynak/ağ · `2` kullanım.
Sınav: `bash arac/araclar.test.sh` (17 kapı, ağsız; 4'ü tarayıcı ister — tarayıcı yoksa "ölçülemedi" diye ayrı sayılır, geçti sayılmaz; `FRONTEND_BOOST_TEST_KATI=1` ile o durumda rc=3).

🔴 **Tarayıcısı olmayan kutuda kontrast ölçülemez** — bu bir eksiklik değil, dürüst durumdur: araç rc=3 der, sen de
"ölçmedim" dersin. Playwright'ı olan kutu (ör. AKAR) ölçer.

**`frontend-design` eklentisi her kutuda yok:** Sultan'ın 19 Eylül kararıyla her UI işinde zorunludur; eklentinin
bulunmadığı kutuda teslim mektubuna "frontend-design bu kutuda yok — çağrılamadı" yazılır (sessizce atlanmaz) ve beceri
"Devralınan disiplin" bölümüyle kendi başına yürür (NAKKAŞ'ın notu, 0.5.0'da zorunlulukla uzlaştırıldı).
