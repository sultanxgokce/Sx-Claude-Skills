---
name: arcelik-fatura-kesim
version: 0.2.0
description: Arçelik'ten gelen fiş/iade/malzeme-iade paketleri için HANGİSİNE fatura kesilir, hangisine KESİLMEZ kararını verir ve kalem eşlemesini kurar. 🔴 EN KRİTİK KURAL - İADE FİŞ PAKETİ'ne fatura KESİLMEZ (kesilirse ZARAR EDİLİR); adı "Malzeme İade" olan mail ise TERSİNE düz fatura olarak kesilir - isim yanıltır, tip belirler. Kesimden önce "daha önce kesildi mi" kontrolü ZORUNLUDUR. Bilinmeyen tip -> KESME, SOR (fail-closed). "Arçelik'ten kesilecek fatura var mı · fiş paketi faturası · hangi paketi keselim · bu mail kesilir mi" tetiğinde ZORUNLU çağrılır.
---

# arcelik-fatura-kesim — hangi pakete fatura kesilir, hangisine KESİLMEZ

**Kademe:** Kalfa · **Doğum:** 2026-08-22, MUHASİP · **Kaynak:** Sultan'ın sözlü kuralları + firsthand ölçüm
**Girdi:** `arcelik-mail-erisim` (paketleri getirir) · **Çıktı hattı:** `elogo-erisim` (belgeyi kurar)

> Sultan'ın talimatı: *"gelen kesmemiz gereken Arçelik'ten fatura var mı diye sorduğumda bu kural
> her zaman hatırlanacak."* Bu dosya o hatırlamanın kendisidir. Soru sorulduğunda **önce burayı oku.**

## 🔴🔴 KURAL 1 — İADE FİŞ PAKETİ'NE FATURA KESİLMEZ

| Mail konusu | Karar |
|---|---|
| `ARCELIK A.S. FIS PAKETI DOKUMU` | ✅ **FATURA KESİLİR** |
| `ARCELIK A.S. IADE PAKETI DOKUMU` | 🔴 **KESİLMEZ — ASLA** |

### KAYNAK (MUAVİN'in haklı itirazı üzerine, 2026-08-22): kural nereden geliyor?
**Kaynak = Sultan, sözlü talimat, 2026-08-22 sohbeti.** Doğrudan alıntı:
> *"iade fiş paketi bizim keseceğimiz bir fatura değildir o yüzden onu ezgeçiyorsun … onu
> kesinlikle almıyorsun **yoksa zarar ederiz** bu çok önemli bir bilgi asla unutmaman lazım"*

**Bu kural ÖLÇÜMLE doğrulanmadı — beyandır.** Ayrımı bilerek yazıyorum: ölçülmüş bir şey gibi
sunmak, MUAVİN'in dediği gibi bir gün *"bu neden böyle?"* sorusuna cevapsız bırakır.
İş gerekçesi (muhtemel): iade paketi bizim **alacağımızı azaltan** bir düzeltmedir, bizim
kestiğimiz bir satış değil — dolayısıyla ona fatura kesmek olmayan bir satışı faturalamaktır.
🔴 **Bu gerekçe MUHASİP'in çıkarımıdır, Sultan'ın beyanı değildir** — mali müşavir teyidi alınmalı.
Teyit gelene kadar **kural aynen yürürlüktedir**: beyan yeterli sebeptir, gerekçe onu güçlendirir.

**Niçin ciddi:** parasal ve geri alınamaz.
"Kesilecek fatura var mı?" sorusuna verilen cevaba iade paketi **KARIŞTIRILAMAZ** — sayıya da girmez.

## 🔴 KURAL 2 — İSİM YANILTIR, TİP BELİRLER

**`Malzeme İade`** başlıklı mail → adında "iade" geçer ama **DÜZ FATURA olarak KESİLİR.**
Kural 1'deki "iade" yasağı **yalnız `IADE PAKETI DOKUMU`** içindir.

### 🔴 KURAL 2b — TÜR YETMEZ, KALEM YAPISI DA BELİRLENİR (2026-09-03)

**Ölçülmüş hata:** yukarıdaki cümle *"düz fatura kesilir"* diyordu ve **kalem yapısını
söylemiyordu**. 2026-09-02'de `FGW2026000000009`, bir malzeme iade belgesi için `SATIS`
tipinde ve **belgedeki 11 malzeme kalemiyle** kesildi. O belge
*"karşı tarafa 11 kalem MAL SATTIK"* diye okunur — oysa iade işlemidir. Sultan yakaladı.

> 🔴 **Ben o boşluğu "belgedeki kalemleri aynen yaz" diye doldurdum. Bu ÖLÇÜM DEĞİL,
> VARSAYIMDI.** Kural belgenin TÜRÜNÜ söyleyip KALEM YAPISINI söylemiyorsa **eksiktir**;
> eksiği doldurmak bir tahmindir ve tahminin parasal belgede yeri yoktur.

**Sultan'ın kuralı (birebir):**
> *"satış kalemlerini gireceksen iade olarak kesmen lazım, satış olarak gireceksen
> malzeme iade olarak girmen lazım tek kalem olarak"*

| Belge | Fatura tipi | Kalem yapısı |
|---|---|---|
| `FIS PAKETI DOKUMU` | SATIS | kalem **türü** başına (Malzeme · Nakliye · İşçilik · Yan Ödeme) |
| `MALZEME IADE` — yol (a) | **IADE** | kalem kalem yazılır · **referans fatura ZORUNLU** |
| `MALZEME IADE` — yol (b) | SATIS | **TEK KALEM** (örn. "Malzeme İade") |
| `EK GARANTI IADE` | IADE | referanslı, tek kalem |

🔴 **Üçüncü yol YOKTUR.** İade niteliğindeki belge SATIŞ tipinde kesiliyorsa kalem
tek olmak zorundadır.

**Makine kapısı:** `elogo-erisim` → `belge_turu_kapisi()`. `mmex_fatura.py`'de
`belge_turu` beyanı **ZORUNLU** — beyan edilmezse kapı sessizce geçerdi, yani
"kapı var ama çağrılmamış" olurdu. Kanıt: `belge_turu.test.sh` **13 kapı**,
**5 mutasyon** (kapı no-op · çağrı silinmesi · tanınmayan tür · dayanak yolu ·
kapının kuruş kapısından sonraya kayması) — beşi de kırmızı.

⚠️ Bu iki kural birbirinin tuzağıdır. Naif bir "iade" kelime araması **iki yönde de yanılır**:
iade paketini kesip zarar ettirir, ya da malzeme iadesini atlayıp fatura kaçırır.
**Karar konunun TİPİNE göre verilir, içinde geçen kelimeye göre DEĞİL.**

## Tip tablosu — tanınan her şey

| Tip | Konu deseni | Karar | Not |
|---|---|---|---|
| **fiş paketi** | `FIS PAKETI DOKUMU` | ✅ KES | asıl iş; genelde perşembe 1–2 adet |
| **iade paketi** | `IADE PAKETI DOKUMU` | 🔴 **KESME** | genelde perşembe 1 adet; zarar sebebi |
| **malzeme iade** | `Malzeme İade` | ✅ KES (düz fatura) | isim tuzağı — Kural 2 |
| **Bizpuan ödül** | `BİZPUAN ÖDÜL FATURA TALEBİ` | ✅ **KES** (Sultan 2026-09-05) | tek kalem · aşağıya bak |
| **aylık iskonto** | `… Ayı İskonto Fatura Talebi` | ✅ **KES** (Sultan 2026-09-05) | tek kalem · aşağıya bak |
| **klima montaj prim** | `KLİMA MONTAJ DESTEK PRİM FATURA TALEBİ` | ✅ **KES** (Sultan 2026-10-14) | tek kalem · aşağıya bak · ilk: `FGW…035` 24.290,62 |
| **ek garanti iade** | `EK GARANTI IADE DOKUMU` | ⏸ **KURAL YOK → SOR** | ölçüldü 27.08, aşağıya bak |
| **uyarı maili** | `Düzenlenmeyen`, `Hatırlatma` | ⏭ atla | fatura değil, hatırlatma |
| **fatura talebi** | `fatura talebi` | ⏸ SOR | ayrı akış olabilir |
| **tanınmayan** | — | 🔴 **KESME, SOR** | fail-closed |

### ⏸ `EK GARANTI IADE DOKUMU` — ölçüldü, kural BEKLİYOR (2026-08-27)

Konu satırında "IADE" geçer ama **Kural 1'in yasağı bunu KAPSAMAZ** — o yasak yalnız
`IADE PAKETI DOKUMU` içindir. Ölçülen (4 belge, firsthand):

- Ek **PDF**'tir (fiş paketlerindeki gibi HTML değil) ve belgenin kendisi
  **"Fatura Kesilecek Bilgiler"** başlığı taşır → fatura **bizden** bekleniyor.
- Belge, faturanın **İADE türünde** kesilmesini ve üzerine **referans fatura numarası +
  tarihi** yazılmasını istiyor (GİB düzenlemesi gerekçesiyle). Yani `ubl_satis` değil,
  `ubl_iade` bölgesi — ve referans alanı bugün hatta bağlı değil.
- Aynı gün aynı dakika **4 ayrı belge** geldi; dördü de ayrı SAP teslimat belge no ve ayrı
  referans fatura taşıyor. **Konuya göre tekilleştirmek dördünü bire indirirdi** (M2 tuzağı).
- 🔴 **Belgenin kendi içi tutarsız:** satır matrahı dolu (örn. 2.834,83) ama özet bloğunda
  `Toplam Matrah (%20) 0,00` yazıyor — KDV ve genel toplam ise dolu. Dördünde de aynı.

🔴 **Kural yok → KESİLMEZ, SORULUR.** Bu satır kararı değil, **ölçümü** kaydeder; ikinci kez
ölçülmesin diye buradadır. Karar Sultan'ındır.

### 🔴 Özet iç tutarlılığı — ÖLÇÜT Sultan tarafından daraltıldı (2026-08-27)

Beceri, Özet'in üç iç eşitliğini sınar. **27.08 paketinde `brüt − indirim = indirilmiş brüt`
ve `Σbrüt = Genel` 1 kuruş kırmızı çıktı** (Malzeme(kdv20) satırı). 20.08'in iki paketi aynı
kapıdan temiz geçmişti → pakete özgü, "Arçelik hep böyle yapar" değil.

Sultan'ın kararı, kendi cümlesiyle:
> *"arçelikteki toplam tutar ile bizim fatura tutuyorsa hiçbir sıkıntı yok sadece dikkatli ol,
> Arçelik'e sormamıza gerek yok, keselim. Fatura ödenecek tutarın bunu tutması önemli."*

**KESİM ÖLÇÜTÜ = Özet'in `Genel` satırı, `İndirilmiş Brüt` sütunu.** O sayı faturanın
**ödenecek** tutarına eşitse yol açıktır. `Brüt` ve `İndirim` sütunları faturaya **girmez**
(kalem birim fiyatı = `Net`), dolayısıyla oradaki kuruş faturayı bozmaz.

🔴 **Daralma neyi KAPSAMAZ:** `net + KDV = indirilmiş brüt` ve `ΣNet / ΣKDV = Genel`
eşitlikleri **aynen sert kalır** — onlar faturaya giren sütunlardır. Kırmızı çıkarlarsa DUR.
Gevşeyen yalnız Brüt/İndirim kolu; ve gevşemesinin sebebi "önemsiz göründü" değil,
**o kolun faturaya bağlı olmaması**.

### 🔴 FATURA TALEBİ tipleri — Bizpuan ödül · aylık iskonto (2026-09-05) · klima montaj prim (2026-10-14)

`tara.py` bu üçünü **📝 FATURA TALEBİ** başlığında ayrı gösterir (SOR'a düşmez, KESİLECEK sayısına da girmez):
tutar gövdede, tarih mailde → kalemi insan okur. Her satırın altında defterdeki **son kesilen** kaydı yazar.
Defter anahtarı: `BIZPUAN-YYYY-MM` · `ISKONTO-YYYY-MM` · `KLIMA-MONTAJ-PRIM-<mail tarihi>`.

Bu iki mail bir **fatura talebidir**: Arçelik tutarı kendisi bildirir, biz o tutara
fatura keseriz. İlk kez 05.09.2026'da kesildi (`FGW…013` 1.035,00 · `FGW…014` 571,12).

| Ne | Nerede |
|---|---|
| Tutar | 🔴 **EK YOK** — tablo **mail gövdesinde** (servis kodu · matrah · KDV · genel toplam) |
| Kalem adı | mailin **AÇIKLAMA** satırı, birebir (örn. `BİZPUAN ÖDÜL` · `2026/08 İskonto Bedeli`) |
| Kalem sayısı | **TEK** |
| Belge tipi | SATIS |

🔴 **TARİH SABİT ve PAZARLIKSIZ.** Arçelik iki mailde de yazıyor: *"Faturanızı mutlaka
31.08.2026 tarihine kesmelisiniz, farklı tarihtekiler reddedilecektir."* Yani fatura
tarihi **mailin geldiği gün değil**, mailde yazan gündür. Geç fark edilse bile o tarih kullanılır.

⚠️ **Bir mail hatırlatmadır, talep değildir:** *"Düzenlenmemiş Görünen … Faturalarınız
Hakkında"* toplu bir listedir ve içinde ONLARCA başka servisin adı geçer. Ondaki
listeye bakıp tutar çıkarmaya çalışma — tutar **talep** mailindedir.

⏸ **ALICI ÖLÇÜLMEDİ:** bu tip daha önce hiç kesilmediği için (89 geçmiş giden faturada
örneği YOK, ölçüldü) alıcı geçmişten doğrulanamadı. Arçelik Pazarlama varsayıldı ve
belge kabul edildi; yine de bu bir **varsayımdır**.

### Fail-closed değişmezi
Tip **kesin** tanınmıyorsa fatura **KESİLMEZ** ve Sultan'a sorulur. Bir faturayı geç kesmek
telafi edilebilir; **yanlış kesmek edilemez.** "Muhtemelen fiş paketidir" YASAK.

## 🔴 KURAL 3 — KESMEDEN ÖNCE "DAHA ÖNCE KESİLDİ Mİ" (zorunlu, iki katman)

Sultan: *"Bir faturayı kesmeden önce daha önce kesildi mi diye kontrol etmek şart."*
Çift kesim = çift vergi + düzeltme yükü. **İki bağımsız katman, ikisi de yeşil olmalı:**
1. **Yerel kesim defteri** — `kesim-defteri.jsonl` (bu skill tutar): SAP Belge No → fatura no.
   SAP Belge No **birincil anahtardır**; tarih/tutar değil (aynı gün iki paket gelebilir — ölçüldü).
2. **e-Logo'da giden fatura sorgusu** — defter kaybolursa/bayatlarsa tek kanıt kalmasın diye.
Biri bile "kesilmiş" diyorsa → **KESME**, Sultan'a bildir.

### 🔴 KURAL 3 ARTIK MAKİNE (2026-09-09) — "hatırlarım" yeterli değildi

**Ölçülmüş boşluk:** kanon *"iki bağımsız katman ZORUNLU"* diyordu; **kodda hiçbiri yoktu.**
`defter.sh` yalnız yeniden-üretim dalında çağrılıyordu. Yani kalkan tamamen insanın her
seferinde elle koşmasına bağlıydı — bir kez unutulsa **çift kesim = çift vergi**.

Artık `mmex_fatura.py` numara VERMEDEN önce `cift_kesim_kapisi()`'nı koşar:

| durum | sonuç |
|---|---|
| defterde "kesildi" | 🔴 DUR |
| defterde "iptal" kaydı | 🔴 DUR — insan kararı |
| defter **okunamadı** | 🔴 DUR — *"kesilmemiş" değil, ÖLÇÜLEMEDİ* |
| e-Logo sorgusu ölçülemedi | 🔴 DUR — tek katmanla kesim yapılmaz |
| e-Logo'da SAP'ı taşıyan fatura var | 🔴 DUR |
| aynı **tutar+alıcı+tarih** üçlüsü var | 🔴 DUR — mükerrer olabilir, insan bakar |

**Atlama bayrağı YOKTUR.** Kuru provada 2. katman sorulmaz (ağa çıkılmaz) ve bu
ekranda **açıkça söylenir** — sessiz atlama, geçmiş sayılmaz.

**Kanıt:** `cift_kesim.test.sh` (**11 kapı**, hermetik — gerçek deftere/hatta dokunmaz).
Dört mutasyon, dördü de kendi kapısını kırmızı yakıyor.

> ⚠️ **Sınavın kendi zayıflığı, kayda geçiyor:** ilk sürümde "gerekçe döndü mü" diye
> bakıyordu ve **katman-1 mutasyonu YAKALANMIYORDU** — kapı kalkınca aynı vaka
> *altyapı* dalından gerekçe üretiyordu. Aynı sonuç, farklı sebep. Gerekçenin
> **içeriği** sınanınca dört kapı ayrıştı.

🔴 **Katman 2 ARTIK GERÇEK (2026-08-28).** Uzun süre "yol yok" sanıldı ve kalkan fiilen tek
bacaklıydı. Yol vardı: `getInvoiceList(begin, end, opType=SEND, dateBy=byISSUEDATE)` → ETTN
listesi, `getInvoice(ETTN)` → belgenin kendisi (numara · tutar · tip · referans · **not**).
Not alanında SAP Belge No yazılı olduğu için eşleştirme tarihe değil **SAP'a** bağlanabiliyor.
Reçete: `elogo-erisim/SKILL.md` → "CANLI KESİM DERSLERİ · D2".
*Ders: "ölçemiyoruz" cümlesi, aracın kendi arayüzü okunmadan söylenmişti.*

⚠️ **Aynı gün, aynı dakika iki ayrı paket gelebilir** — ölçüldü (20.08.2026, iki paket, ardışık
SAP no). Tarihe göre tekilleştirme **YANLIŞ**: birini yutar. Anahtar SAP Belge No'dur.

### 🔴 KURAL 3 KATMAN-2'NİN İKİ KÖR NOKTASI (ölçüldü 2026-09-12)

Katman 2 (`getInvoiceList` + `getInvoice`) eşleştirmeyi **SAP Belge No** ile yapar.
Ölçüldü: iki durumda **"e-Logo'da YOK" cevabı YANLIŞTIR** — fatura vardır, katman görmez.
Bu bir gürültü değil, **para kapısında sahte yeşildir**.

| Kör nokta | Ölçüm | Sonuç |
|---|---|---|
| **Portal serisi (FGF)** SAP'ı nota YAZMAZ | FGF…088-091 notları yalnız *"Yalnız … TL"* taşıyor | SAP aramak o seride **hiçbir şey bulmaz** |
| **e-Arşiv faturaları** `getInvoiceList`'te HİÇ ÇIKMAZ | `FGW…016` (e-Arşiv, 450,00) defterde VAR, 45 günlük giden listede YOK; aynı gün kesilen `FGW…015` (e-Fatura) listede VAR | e-Arşiv yolu katman 2'ye **görünmez** |

**Doğru hüküm:** katman 2 bir SAP'ı bulamazsa sonuç *"kesilmemiş"* DEĞİL,
**"bu seride/bu yolda ölçemedim"**dir. İki telafi yolu ölçüldü:
- **Tutar eşleştirme** — portal serisi için çalışır. 13.08'in iki paketi böyle doğrulandı:
  `…404706012026` → 2.112.224,09 = `FGF…091` · `…404806012026` → 48.463,95 = `FGF…090`.
  *Bu, Sultan'ın "20.08 öncesi hepsi kesildi" beyanını ilk kez ÖLÇÜLMÜŞ hâle getirdi.*
- **e-Arşiv için ayrı uç** — `GetDocumentList` (EARCHIVE; tek-gün + DATEBY). Katman 2'ye
  **henüz bağlı DEĞİL** (açık iş).

⚠️ **Defter ↔ e-Logo mutabakatı da ölçülmelidir.** 2026-09-12 turunda iki yönlü fark çıktı ve
ikisi de açıklanabilirdi: `FGW…010` (400.020,00) e-Logo'da var/defterde yok — Arçelik paketi
değil, ayrı bir alıcıya kesilen fatura (bu defter Arçelik'e özgüdür); `FGW…016` defterde
var/e-Logo'da yok — e-Arşiv kör noktası. **Açıklanamayan bir fark çıkarsa DUR.**

> ⚠️ Bu turda ölçüm aracımın kendisi de bir kez yanlış ayarlandı: defter dosyasını yanlış
> yoldan okudu ve **"defterde 0 kayıt"** dedi; o sayıya dayanarak "şu faturalar defterde yok"
> hükmü verilseydi on beş fatura kayıp sanılacaktı. Gerçek yol
> `~/.config/arcelik-kesim-defteri.jsonl`'dir (`defter.sh` `ARCELIK_KESIM_DEFTERI` ile ezer).
> *Ders: karşılaştırmanın bir tarafı BOŞ çıktıysa önce aracı şüphelen, veriyi değil.*

## 🔴 KURAL 5 — KESİMDEN SONRA DENETİM (2026-08-28, Sultan öz kuralı)

> Sultan: *"fatura kesme işleri önemli, hata yapılmaması gerekir; sürekli sistem iyileştir,
> hatalardan/tecrübelerden öğren, AI skill'e dönüştür ya da geliştir — öz kural bu."*

Kesim **gönderimle bitmez**. Her turdan sonra iki şey yapılır:

**(a) Denetim koşulur** — `MMEx/_agents/fatura/denetim/`. e-Logo'daki **gerçek belge**,
**maildən YENİDEN indirilen** kaynakla karşılaştırılır. Ara ürünlere (yerel XML, fatura
listesi, bu defter) **bakılmaz**: ikisini de o adımlar üretmediği için aradaki kusur görünür.
🔴 **Sıfır bulgu tek başına bir şey söylemez** — hiçbir şey ölçmeyen bir denetim de sıfır verir.
Denetimin kendisi mutasyonla sınanır (tutar · referans · tarih · eksik fatura · VKN · satır KDV).

**(b) Ders kanona yazılır.** Bu turda ne yanlış gitti ya da az kalsın gidiyordu? Bir dahaki
sefere onu **makine mi yakalar, insan mı hatırlar?** İnsan hatırlayacaksa **yanlış cevaptır**
→ kapıya/sınava/skill'e dönüşür. Yeni yetenek doğduysa `ahi` ile skill olur; mevcut skill
eksik çıktıysa **oraya işlenir, ikinci kopya açılmaz**.

**Tur, (a) ve (b) yapılmadan "bitti" sayılmaz.**

## Kesim durumu — ÇİZGİ (güncel: 2026-08-28)
- **20.08.2026 öncesi tüm paketler: KESİLDİ** (Sultan beyanı 2026-08-22).
- **20.08 paketleri: KESİLDİ** — `FGW…001` (17.411,43) · `FGW…003` (1.732.854,62).
- **27.08 fiş paketi: KESİLDİ ve GÖNDERİLDİ** — `FGW…004` · 1.549.822,34 · GİB **1300**.
- **27.08 dört ek garanti iadesi: KESİLDİ ve GÖNDERİLDİ** — `FGW…005-008` · toplam 9.541,20 ·
  dördü de GİB **1300**.
- Denetim koşuldu: **109 kontrol · 0 bulgu** (Kural 5).
- Açık iş **YOK**. Bundan sonrası MUHASİP'in: kesimi de takibi de.

⚠️ **Bu bölüm bayatlar.** Yazılı çizgi ile gerçeğin ayrıştığı ölçüldü (2026-08-27: burada
"20.08'in ikisi kesilmedi" yazıyordu, ikisi de kesilmişti). **Gerçek kaynak defterdir**
(`defter.sh liste`) **ve e-Logo'dur** (Kural 3 katman 2); bu satırlar yalnız özet.

## Kalem eşlemesi — Özet HTML → e-Fatura (kuruşu kuruşuna doğrulandı)

Kaynak: paket mailinin `<SAP>_Ozet.html` eki. Fatura **4 kalem** taşır; her kalem **Miktar 1,0**,
**KDV %20**, **iskonto 0,00**.

| Fatura kalemi | Özet satırı | Birim fiyat = |
|---|---|---|
| Malzeme | `Malzeme(kdv20)` | **Net** sütunu |
| Nakliye | `Nakliye` | **Net** sütunu |
| İşçilik | `İşçilik(kdv20)` | **Net** sütunu |
| Yan Ödeme | `Yan Ödeme` | **Net** sütunu |

🔴 **Birim fiyat = Net sütunu** (indirim sonrası, KDV hariç). *Brüt* ya da *İndirilmiş Brüt*
DEĞİL. İndirim faturaya **iskonto olarak girilmez** — Net zaten indirilmiştir; girilirse
indirim iki kez düşer.
**Kanıt:** her kalemde `Net × 0,20` = Özet'in `KDV20` sütunu ve örnek faturanın KDV'si —
iki pakette ve örnek faturada 11 kalemin 11'i tuttu.
**Sıfır satır kalem açılmaz** (ölçüldü: bir pakette Yan Ödeme 0,00 → 3 kalem).
**KDV10 satırları bugüne dek hep 0,00** — sıfırdan farklı çıkarsa **DUR ve SOR**, tek orana indirgeme yanlış fatura üretir.

### 🔴 DÜZELTME (2026-08-22): "tanımlı seri yok" YANLIŞTI
WS'in `GetPrefixLastNumberList`'i boş döner — ama **panelde ön ek TANIMLI** (Sultan ekranı).
Servisin görmemesi "yok" demek değildi. Aynı şekilde **kontör**: WS'te hiçbir metot sunmuyor,
ama panel sağ üstte **"Kalan Kontör"** yazıyor (gerçek panel 22,5 · demo 0).
**Ders: bir veriyi bir kanal sunmuyorsa, o veri YOK demek değildir — başka kanal ölç.**

### Fatura başlığı (örnek faturadan sabitler)
`Senaryo: TICARIFATURA` · `Fatura Tipi: SATIS` · `Özelleştirme No: TR1.2` ·
Fatura No deseni: `<SERİ><yıl><9 hane>` (seri ön eki kutu-yerel türevde). Alıcı **Arçelik Pazarlama A.Ş.**,
satıcı yetkili servis — **VKN/unvan/adres bu dosyada TUTULMAZ**, kutu-yerel türevde ya da kasada
yaşar (ortak raf = 16 kutu, İ1). *Test: "bu satır ikinci bir tüzel kişide de aynı mı kalır?"*

### Kesim öncesi zorunlu üç çapraz-kontrol (Özet'in kendi aritmetiği)
`brüt − indirim = indirilmiş brüt` · `net + KDV = indirilmiş brüt` · `Σbrüt = Genel`
Biri tutmuyorsa ek bozuk ya da ayrıştırma yanlış → **KESME.**

## Ritim — ne zaman bakılır
Genellikle **perşembe**: 1–2 fiş paketi + 1 iade paketi. Ritim bir **beklenti**dir, kural değil:
"perşembe geldi, demek paket vardır" varsayma; **her zaman ölç.** Paket gelmediyse bu bir ölçümdür.

## Sorulduğunda ne cevaplanır
"Arçelik'ten kesilecek fatura var mı?" → maili tara, tiplere ayır, **kesim defterini kontrol et**, sonra:
- kesilecekler: adet + SAP Belge No + tutar
- **iade paketleri AYRI satırda, "kesilmez" etiketiyle** (sayıya karıştırma — Kural 1)
- tanınmayan/kural-yok olanlar: "SOR" listesi
Ölçemediğine **"yok" deme, "ölçemedim" de.**

## Kullanım

```bash
# "Arçelik'ten kesilecek fatura var mı?" — tek komutluk cevap
python3 scripts/tara.py [taranacak_mesaj_sayısı]     # varsayılan 60

# çift-kesim kalkanı (Kural 3, yerel katman)
bash scripts/defter.sh sor <SAP_BELGE_NO>            # RC0=kesilmemiş · RC1=KESİLMİŞ, DUR
bash scripts/defter.sh yaz <SAP> <FATURA_NO> [tutar] # kesim sonrası işle (üzerine yazmaz)
```
`tara.py` çıktısı dört kümedir: **KESİLECEK** (defterden geçmiş) · **KESİLMEZ** (iade paketleri,
sayıya dahil değil) · **SOR** (fatura/para kokulu ama kuralı olmayan) · ilgisiz (sayı olarak).
`ARCELIK_KESIM_CIZGISI` (varsayılan `2026-08-20`) öncesi paketler Sultan beyanıyla kesilmiş
sayılır ve ayrı satırda **beyan olduğu belirtilerek** raporlanır — sessizce yutulmaz.

### Kanıt — bu skill kendi kuralını gerçekten uyguluyor mu (2026-08-22 firsthand)
7 vakalık tip sınavı **7/7 geçti**; kritik ikisi: `IADE PAKETI DOKUMU → KESME` ve
`Malzeme İade → KES` (isim tuzağına düşmedi). Çift-kesim kalkanı mutasyonla sınandı:
kesilmiş kayda `sor` **RC=1** verdi, `yaz` üzerine yazmayı **reddetti**.
Canlı tarama: 40 mesaj → **2 kesilecek** (20.08.2026) · 6 iade (kesilmez) · 10 sor · 3 çizgi altı.

## Negatif kapsam
Numara atama ve **gönderim MUHASİP'in eli DEĞİL** — Sultan'ın. Bu skill belgeyi **kurar, provasını
geçer ve DURUR**. Canlı ortam (`--canli`) ve `--gercekten-gonder` bu skill'e kapalıdır.
Mail'e yazma fiili yok. Tüzel kişi kimlik bilgisi bu dosyada tutulmaz.

---

## 🔴 TÜRKÇE VARYANTI DESENDE SAYMA — METNİ SADELEŞTİR

**Ölçülmüş kusur (2026-08-23):** tip desenleri Türkçe harf varyantlarını **elle** sayıyordu
(`F[İI]S?`, `[İI]ADE`) ve eksikti — `Ş`, `Ö`, `Ü` hiç yoktu. Sonuç:

| Konu | Eski karar | Doğrusu |
|---|---|---|
| `FİŞ PAKETİ DÖKÜMÜ` | SOR | **KES** ← 🔴 fatura kaçar |
| `Fis Paketi Dokümü` | SOR | **KES** ← 🔴 fatura kaçar |
| `İADE PAKETİ DÖKÜMÜ` | SOR | KESME |

İade paketinin SOR'a düşmesi görece iyi huyludur (kesilmez). **Fiş paketinin SOR'a düşmesi
FATURA KAÇIRIR** — ve SOR listesi "gürültü" bölümüdür, kimse tek tek bakmaz.

**Kural:** konu satırı önce `sadelestir()` ile aksansız-küçük ASCII'ye indirgenir, desenler
o biçime yazılır. ⚠️ `ı` (U+0131) **NFKD ile çözülmez**, elle eşlenir.

Geçmiş tarandı (1000 konu satırı, salt-okur): **eski desenle farklı karar çıkan konu 0** —
kusur gerçekti ama **henüz isabet etmemişti**. İkisi ayrı cümle.

## 🔴 DESEN SIRASI BİR SÖZLEŞMEDİR

`TIPLER` listesinin sırası karar üretir. Sınavda kilitli iki değişmez:

1. **`iade_paketi` · `fis_paketi`'nden ÖNCE** — ikisi de "paketi dokumu" taşır; sıra
   bozulursa iade paketi fiş paketi sayılır ve **kesilir = zarar**.
2. **Paket desenleri (`iade`/`fis`/`malzeme`) `uyari`'dan ÖNCE** — `Hatırlatma: FİŞ PAKETİ
   DÖKÜMÜ` gibi bir konu `uyari`ya düşerse **gerçek bir fatura atlanır**.

## ADLANDIRILMIŞ `ATLA` — "sessizce yut" DEĞİLDİR

Fatura olmayan ama düzenli gelen tipler `SOR`da bırakılmaz; **adıyla** `ATLA`'ya alınır:
`mutabakat` · `odeme_bildirimi` · `lojistik`. Niçin: `SOR` "para kokusu var, kural yok"
bölümüdür; her hafta aynı üç mail oraya düşerse **gerçek bir SOR gürültüde kaybolur**.

⚠️ **`mutabakat` KAPSAM DIŞIDIR, önemsiz DEĞİL.** Cari hesap mutabakatı cevap bekler ve
hatırlatması gelir; ama bu tarayıcının işi "kesilecek fatura var mı"dır. Mutabakat, karşı
tarafın kaydıyla **bizim** kaydımızı karşılaştırma işidir ve o kayıt bizde yoktur —
doğrulanmamış bir "mutabıkız" beyanı mali risktir. *Kapsam dışı olan şey unutulabilir;
bu satır onun kaydıdır.*

## `kesilmis_mi()` ÜÇ DURUMLUDUR — "ölçemedim" ≠ "kesilmiş"

`True` kesilmiş · `False` kesilmemiş · **`None` ÖLÇÜLEMEDİ**.
🔴 Eski hâli `return r.returncode != 0` idi: defter okunamazsa/izin düşerse **"kesilmiş"**
diyordu ve fatura **sessizce düşüyordu** — bir ALTYAPI hatası, bir İŞ KARARINA dönüşüyordu.
`defter.sh` rc sözleşmesi bu yüzden ayrıştırıldı: `0` yok · `1` KESİLMİŞ · `3` iptal kaydı
· `2` kullanım · **`5` ALTYAPI**. Ölçülemeyenler tarama sonunda kırmızı blokta listelenir
ve tarayıcı **rc=4** ile çıkar: *"kesilecek fatura yok" cümlesi ancak defter okunabildiyse
bir şey söyler.*
