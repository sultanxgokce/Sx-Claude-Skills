---
name: frontend-boost
version: 0.3.0
allowed-tools: Bash, Read, Write, Edit
description: Bir sayfanın (karşılama sayfası, ürünün açılış ekranı, sunum kapağı, broşür kapağı) "bunu bir tasarımcı yapmış" dedirtecek biçimde, etkili ama yalın tasarlanması istendiğinde kullan. Tetikleyiciler — "/frontend-boost", "daha efektli ama minimal", "vasat durmasın", "premium görünsün", "landing page", "sahne", "wow etkisi". Formülü, belirteçleri, hazır şablonu, ölçüm araçlarını ve düşülen tuzakları içerir. Sıradan ürün içi ekranlar (form, tablo, ayar) için KULLANMA.
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

## Ne zaman, ne zaman değil
| Kullan | Kullanma |
|---|---|
| Karşılama (landing) sayfası · ürünün açılış ekranı (**tamamı** — üst bölüm tek başına yama olur, bkz. YAMA YASAK) · sunum ve broşür kapağı · tanıtım görseli | Form, tablo, ayar, liste ekranları — orada ürünün kendi tasarım dili geçerlidir |
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
4. `frontend-design` becerisini çağır (renk/yazı/yerleşim planı ve klişe denetimi için); bu beceri onun **üstüne** biner, yerine geçmez.
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
- [ ] Hangi sayfa olduğu yazılı · insanın örneği alındı ve formülü çözüldü
- [ ] Tek sahne · tek kahraman nesne · tek parlak öğe · tek açılış anı
- [ ] 1440 · 1280 · 390: yatay taşma 0, kesik metin 0 · dış istek 0 · sayfa hatası 0
- [ ] Hareket azaltma tercihinde hareket 0 · odak halkası görünür
- [ ] Sahnedeki her metin gerçek zemine göre ≥ 5,5 (en açık piksele göre ≥ 4,5)
- [ ] Kareye **kendi gözünle** bakıldı · insana kare **ve** dosya gitti
- [ ] Ürüne girecekse: sahne ayrı bir yüzey olarak reçetelendi (sınırları ölçülebilir), kapı **gevşetilmedi**
- [ ] **Yama değil:** sayfanın tamamı aynı elden (yazı ailesi, zemin, aralık, punto, hareket); tam boy karede tek dil; sahnenin altı eski kalmış sayfa **teslim edilmedi**

## Paket içeriği
`sablon/sahne.css` belirteçler + koyu sahne + stüdyo sahnesi + hap düğme + dev yazı + havada duran nesne ·
`sablon/landing-iskelet.html` çalışan en küçük karşılama sayfası · `arac/kontrast-olc.mjs` piksel tabanlı kontrast (varsayılan seçiciler `.sahne` içindeki `text.ce`, `.gun`, `.okuma span` vb. — kendi sayfana göre seçici listesini değiştir; 1440 açık/koyu · 1280 · 390'da koşar; Playwright yolu kutuya göre ayarlanır) ·
`arac/font-altkume.py` karakter alt kümeli gömülebilir yazı tipi · `komut/frontend-boost.md` eğik çizgi komutu.
Canlı örnekler (AKAR deposu): `tasarim/prototip-acilis/bugun-v2.html` (koyu sahne, veri nesnesi) · `landing.html` (stüdyo sahnesi, havada ürün) · reçete `tasarim/SAHNE-YUZEYI-RECETESI-20260917.md`.

## Taşınabilirlik (MUAVİN, 2026-09-17 · filo geneli paketleme)
Bu beceri AKAR kutusunda doğdu; araçlar o kutunun yollarına sabitlenmişti. Filo geneline alınırken ölçüldü ve düzeltildi:

| Konu | Eski hâl | Şimdi |
|---|---|---|
| Tarayıcı çalışma-zamanı | `/config/tooling/pw-runtime` **sabit** → başka kutuda "Cannot find module" | env → bilinen adaylar → normal çözümleme; hiçbiri yoksa **rc=3 ÖLÇÜLEMEDİ** |
| Seçiciler tutmazsa | `0 metin` basıp temiz görünüyordu | **rc=3**, "bu sayfa ÖLÇÜLMEDİ, temiz DEĞİL" |
| Yazı tipi aracı argümansız | Python yığın izi | düz kullanım iletisi, **rc=2** |

Ayarlar: `FRONTEND_BOOST_PW` (playwright-core yolu) · `FRONTEND_BOOST_PW_LIBS` · `FRONTEND_BOOST_SAHNE` · `FRONTEND_BOOST_SECICILER`.
Çıkış kodları — kontrast: `0` temiz · `1` eşik aşıldı · `2` kullanım · `3` ölçülemedi. Yazı tipi: `0` yazıldı · `1` kaynak/ağ · `2` kullanım.
Sınav: `bash arac/araclar.test.sh` (11 kapı, ağsız).

🔴 **Tarayıcısı olmayan kutuda kontrast ölçülemez** — bu bir eksiklik değil, dürüst durumdur: araç rc=3 der, sen de
"ölçmedim" dersin. Playwright'ı olan kutu (ör. AKAR) ölçer.

**`frontend-design` eklentisi her kutuda yok:** aşağıdaki süreçte o adım "**varsa** çağır" diye okunur; yoksa beceri
kendi başına yürür (NAKKAŞ'ın notu).
