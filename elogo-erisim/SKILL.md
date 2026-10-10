---
name: elogo-erisim
type: agent
version: 1.7.0
description: e-Logo (Logo e-Fatura entegratörü) işlerini PANELE GİRMEDEN, saf SOAP WS ile yapar: UBL-TR satış/iade belgesi KUR (ağsız · kontörsüz · kuruş kapılı), fatura durumu sorgula, e-Arşiv PDF/UBL indir, demo ya da canlı ortama bağlan, belgeyi GÖNDER. 🔴 Gönderim DÖRT kapıdan geçer ve varsayılan KURU KOŞUMdur: ortam kilidi fail-closed (tanınmayan değer → rc=6) · alıcı etiketi zorunlu, irsaliye kutusu reddedilir (rc=7) · tarihli insan onayı beyanı (rc=3) · kuruş kapısı BİREBİR, tolerans parametresi YOK. Belge üretildikten sonra ÜRÜN KAPISI belgenin kendisini yeniden sınar. Sır-hijyenik: kimlik kasadan gelir, değer basılmaz. Gövde ŞİRKETSİZDİR — ünvan/VKN/etiket kutu-yerel türevden çağrı parametresi olarak gelir.
---

# e-Logo Erişim

> e-Fatura/e-Arşiv işlerini Sultan'a tekrar tekrar giriş sordurmadan yap.
> Kanon reçete: `erisim-skill-fabrikasi/recipes/elogo.md`. Omurga: ../cloudflare-erisim/SKILL.md.

## Çoklu KDV — kalem başına oran (2026-08-25)

Kalem listesi iki biçim kabul eder; **karışık liste de kabul edilir ama sessiz değildir**:

```python
("Malzeme", "1000.00")        # varsayılan oran
("Malzeme", "1000.00", 10)    # kalemin KENDİ oranı
```

UBL katmanı bunu **zaten** destekliyordu (`Kalem.kdv_orani` + oran→grup sözlüğü);
üst katman tek oran alıyordu. Yani yetenek vardı, **çağrılmıyordu** — *"yazılmış ≠
bağlanmış"*ın kendi veri modelimizin içindeki hâli.

Kaç kalemin varsayılana düştüğü **stderr'e yazılır**: oran vermeyi unutmak gerçek bir
hatadır ve varsayılan onu sessizce yutardı.

### Ürün kapısına iki yeni kontrol
- **Satır oranı:** belgedeki `Percent`, girdideki oranla eşleşmeli; ve satır KDV'si o
  oranın gerektirdiği tutar olmalı. *Tutar-eşitliği, oran-doğruluğunu kanıtlamaz* —
  satır tutarı ve KDV'si doğruyken `Percent` yanlış olabilir, belge o hâlde kendi içinde
  tutarsızdır ve reddi bize dönene kadar hiçbir kapı itiraz etmezdi.
- **Belge vergi grupları:** her grubun KDV'si, o orandaki **kalem KDV'lerinin toplamı**
  olmalı; oran kümesi girdiyle birebir aynı olmalı.

### 🔴 Ve bir kuruş dersi — kapının ilk sürümü gerçek faturada patladı
Grup kontrolünü önce `matrah × oran` diye yazdım. İlk gerçek fatura kuru provasında:

```
8297,57 + 1175,74 + 5036,22 = 14509,53
kalem başına yuvarlanmış KDV toplamı = 2901,90   ← canlıda kesildi, KABUL EDİLDİ
grup matrahı × %20                   = 2901,91   ← 1 kuruş fazla
```

Yuvarlama **kalem başına** yapılır (fiş paketiyle aynı yöntem); toplayıp yuvarlamak başka
sonuç verir. `topla()`'nın kendi notunda bu yazılıydı — kapıyı yazarken **kendi notumu
ihlal ettim**.

🔴 **Sınav bunu yakalamadı, çünkü fikstürüm gerçeğin kolay hâlini seçmişti**
(`1000,00 × %20 = 200,00`, yuvarlama farkı üretmiyor). Kusuru **kuru prova** buldu.
**Ders: fikstür gerçeğin kolay hâlini seçerse, sınav kolay soruyu sorar.**
O sayılar artık sınavda regresyon vakası (`Ç5b`).

**Kanıt:** `scripts/coklu_kdv.test.sh` → **17 kapı**. Üç mutasyon (sil · no-op ·
yer-kaydırma) üçü de kırmızı yakar; belge düzeyi iki ayrı bozulmayla ayrı ayrı sınanır
(grup oranı · grup tutarı).


## Şahıs (TCKN) + iletişim — `cac:Contact` · `cac:Person` (2026-08-25)

Şahsa e-Arşiv kesmenin ön şartı. Kimlik tarafı zaten çalışıyordu (11 hane → `TCKN`,
10 hane → `VKN`); eksik olan iki bloktu.

`Taraf` dört yeni alan taşır — hepsi **isteğe bağlı**, verilmezse blok **hiç yazılmaz**
(boş etiket, yokluktan kötüdür): `telefon` · `eposta` · `ad` · `soyad`.

| verilen | üretilen |
|---|---|
| `telefon` / `eposta` | `cac:Contact` → `cbc:Telephone` · `cbc:ElectronicMail` |
| `ad` / `soyad` | `cac:Person` → `cbc:FirstName` · `cbc:FamilyName` |

**Biçim sınanır, VARLIK sınanmaz.** Bozuk e-posta/telefon reddedilir; **yokluk reddedilmez**.
Gerekçe: bu alanların UBL-TR'de zorunlu olup olmadığını **ölçmedik**, ve ölçmediğimiz bir
kuralı dayatmak, kapıyı kanıttan değil tahminden kurmaktır. Bozukluk ise ayrı: *yok olan
e-posta bellidir, bozuk olan doğru sanılır.*

### 🔴 SIRA — bir [ANLATI] iddiası, ölçüm DEĞİL
UBL **katı sıralıdır**; yanlış sıra belgeyi reddettirir. Üretilen sıra:
`PartyIdentification → PartyName → PostalAddress → PartyTaxScheme → Contact → Person`

Elimizde **UBL-TR XSD'si yok** ve e-Logo'ca kabul edilmiş bir **şahıs belgesi de yok**.
Yani bu sıra bugün **doğrulanamadı**; kaynağı standart bilgisi.

🔴 **İlk gerçek şahıs faturasından ÖNCE `GetDocumentPreView` ile doğrulanmalıdır.**
O doğrulama yapılana kadar bu blok *"çalışıyor"* **sayılmaz**.

`sahis.test.sh` (**17 kapı**) yalnız **kodun bu sırayı ürettiğini** kilitler —
e-Logo'nun onu **kabul ettiğini** değil. Bu ayrım bilerek yazıldı: kendi ürettiğimizi
kendi niyetimize karşı doğrulamak, zincirin öteki ucunu sormamaktır.
Üç mutasyon (sil · no-op · **yer-kaydırma**) üçü de kırmızı yakar — yer-kaydırma
tam da sıra bozulmasını ölçer.


## 🔴 Dayanağın KAYNAĞI — "eşit" ≠ "doğrulandı" (2026-08-25)

Kuruş kapısı **üç** tanıkla çalışır: `topla()` · `urun_kapisi()` · **dayanak**.
İlk ikisi aynı varsayımı paylaşır (`ödenecek = matrah + KDV`); kapıya gücünü veren
**üçüncüsüdür** ve o *dışarıdan* gelir — fiş paketinin gerçek tutarı.

**Dayanak kalemlerden türetilmişse üçüncü tanık YOKTUR:** kapı kendi hesabını kendi
hesabıyla karşılaştırır, birebir eşitlik görür, yeşil yakar — ve **hiçbir şey kanıtlamaz**.

> **Ölçülmüş vaka:** `TEST_FATURA` dayanağı 12,00 · tek kalemi 10,00 → 10 × 1,20 = 12.
> Gerçek faturaların dayanağı fiş paketindendi. **İkisi kodda aynı biçimdeydi** ve kapı
> ikisine de aynı yeşili verdi.

`dayanak_kaynagi` artık **zorunlu beyandır** (`kurus_kapisi` ve `belge_kur`):

| kaynak | anlamı | kapı ne der |
|---|---|---|
| `fis_paketi` | Ana alıcı fiş paketinden okundu | ✅ doğrulandı |
| `insan_beyani` | insan başka bir belgeden okuyup yazdı | ✅ doğrulandı |
| `kalemlerden_turetildi` | kalemlerden hesaplandı | ⏸ **"BU KAPI BU BELGEYİ DOĞRULAMADI"** |

Türetilmiş dayanak **reddedilmez** — fiş paketi olmayan fatura meşrudur. Meşru olmayan,
onun *sessizce yeşil* olmasıdır. Özet `dogrulandi` bayrağını taşır ve **ekrandaki işaret
hükme bağlıdır** (`⏸` vs `✅`) — uyarıyı verip en görünür yerde geri almak, uyarmamaktır.

🔴 **Bu soru mekanik olarak ÖLÇÜLEMEZ, o yüzden sorulur.** Denenebilecek tek sezgi
*"dayanak kalemlerin toplamına eşit mi"* olurdu ve işe yaramaz: fiş paketi durumunda
kalemler **de** fiş paketinden gelir, yani dayanak zaten kalemlerle tutarlıdır. İki hâl
ayırt edilemez. Ölçemediğimiz şeyi ölçüyormuş gibi yapmak, tam da bu kapının kapattığı hata.

### İkinci kör nokta: oranla oynayarak geçirme
Yalnız **toplam** sınanırken, kapı kırmızı yakınca `kdv_orani`'yi değiştirip geçirmek
mümkündü — kapı sayıyı denetler, **niyeti** denetlemez. `dayanak_kirilimi=(matrah, kdv)`
verilirse üç değer birden sınanır: *toplamı tutturan bir oran, doğru fatura demek değildir.*
Kırılım verilmezse kapı bunu **söyler** ("tek-tanık" notu) — sessiz kalmaz.

### stderr sözleşmesi
Kapının insan-uyarıları **stderr**'e gider; `stdout` bu hatta **veri** kanalıdır.
İlk sürüm stdout'a basıyordu ve `kurus.test.sh`'i kırdı (o sınav `GEC`/`RET` ayrıştırıyor).
Daha kötüsü sessiz olabilirdi: uyarı metni beklenen değere benzeseydi **yanlış yeşil** verirdi.

**Kanıt:** `scripts/dayanak.test.sh` → **16 kapı**, hermetik. Üç mutasyon
(sil · no-op · yer-kaydırma) üçü de kırmızı yakar.


## 🔴 ÖNCE BUNU OKU — `TUZAKLAR.md`

Bu yeteneği ilk kez alıyorsan **`TUZAKLAR.md`'yi oku.** İçinde 2026-08-21/22 gecesinde
**ölçülerek** bulunmuş dokuz başlık var: SOAP'ın kimlik-hatası taklidi yapan üç değişmezi ·
belgede zorunlu dört alan (altı ret ile öğrenildi) · iki gönderim yolu ve farklı numara kuralları ·
tarayıcı otomasyonunun **iki sessiz tuzağı** · portalın iki giriş yolu · kontör · ortam kilidi.

Hiçbiri tahmin değil. Okumadan başlarsan aynı duvarlara yeniden çarparsın — ve o duvarların
çoğu **hata mesajı vermiyor**.

## GERÇEK KISIT (dürüstçe söyle)
e-Logo'nun "şifre → API token" akışı YOK — Web Servisi doğrudan **kullanıcı-adı+şifre → `Login` → sessionID**
ile çalışır. Least-privilege = portalda ÖZEL bir "Bağlantı (Web Servis) Kullanıcısı" (alt-kullanıcı) açmak.
⚠️ Login **hesap-kilitlidir** (yanlış deneme sayacı azaltır) → körlemesine şifre deneme YOK.
⚠️ **Kontör sınırlı** → gereksiz WS çağrısı yapma.

## Akış
1. `doctor` — kimlik geçerli mi? Yeşil → Adım 3.
2. Bir-kerelik gizli giriş: `bash scripts/elogo.sh login` → WS Kullanıcı Kodu + Şifre'yi GİZLİ (`read -rs`)
   girer, `Login` ile doğrular, `cortex-access.env`'e (600) yazar. (Ana insan-portal şifresini WS'e KOYMA.)
3. Asıl iş (salt-okur, idempotent):
   - `bash scripts/elogo.sh status <ETTN>`   → fatura durumu
   - `bash scripts/elogo.sh get <ETTN> [f]`  → kesilmiş e-Arşiv **PDF** indir
   - `bash scripts/elogo.sh xml <ETTN> [f]`  → **UBL XML** indir
4. Doğrula: `bash scripts/elogo.sh doctor` (yeşil). Sır YALNIZ cortex-access.env (600) + registry pointer.

## Çalışan referans
🔴 **Firma/cari verisi bu pakette YAZMAZ** (paketleme md.1). Bu dosya 13 kutunun ortak gördüğü
raftadır; buraya bir tüzel kişinin ünvanı ya da VKN'si yazmak, o veriyi ilgisiz kutulara dağıtmaktır.
Ayırt edici test: *"bu satır ikinci bir tüzel kişide de aynı mı kalır?"* — kalmıyorsa buraya YAZILMAZ.

Firma-özel değerler (ünvan · VKN · WS alt-kullanıcı adları · hangi kullanıcıya dokunulmayacağı)
**kasada ve kutu-yerel kayıtta** yaşar:
`secret/<kiracı>/ELOGO_WS_*` (canlı) · `secret/<kiracı>/ELOGO_DEMO_WS_*` (test).
Kanonik pointer: `Nexus/_agents/credentials.yaml → elogo-soap`.

## YASAK / dikkat
- **Kuyruk-tüketen ops YASAK:** `GetDocument`/`receiveInvoiceDone`/`GetDocumentDone` gelen-fatura kuyruğunu
  tüketip "alındı" işaretler → eski prod cron'unun (b2b_elogo_sync) belgesini kaçırtır. Bu skill onları SUNMAZ.
- Prod'un `…mmebroker` alt-kullanıcısını sıfırlama; Railway'deki eski `ELOGO_WS_*` env'ine yazma (CLAUDE.md §3).
- TASLAK (kesilmemiş, Fatura No boş) faturalar WS'te YOKTUR → `get`/`xml` "NOTFOUND" döner (hata değil).
- Şifre bilinmiyorsa DUR, kullanıcıdan iste — asla brute-force (kilit riski).

---

# 📦 FATURA KESME YETENEĞİ (v1.2.0) — ne HAZIR, ne KAPALI

Bu bölüm 2026-08-21'de eklendi. Amaç: yeteneği kullanacak ajanın **ne yapabileceğini ve
neyi yapamayacağını** kaynağa gitmeden görmesi.

## Katmanlar

| katman | dosya | ağ? | kontör? | geri-alınabilir? |
|---|---|---|---|---|
| **Belge kurucu** | `ubl_iade.py` | ❌ hiç çıkmaz | ❌ yakmaz | ✅ tamamen |
| **Taşıma** | `elogo_soap.py` | ✅ | login yakabilir | ✅ (salt-okur) |
| **Okuma** | `elogo_ws.py` | ✅ | ✅ yakar | ✅ |
| **Gönderme** | — | — | — | 🔴 **YOK · bilerek** |

## Belge kurucu — `ubl_iade.py`
İade faturasının UBL-TR XML'ini kurar. **Ağa çıkmaz, kimlik istemez, kontör yakmaz** →
sınırsız kez bedelsiz koşar.
```
python3 ubl_iade.py denetle <veri.json>   # eksik alanları ADIYLA listeler (RC 2 = eksik var)
python3 ubl_iade.py kur     <veri.json>   # UBL-TR XML üretir (eksikse RC 2 ve XML ÜRETİLMEZ)
```
**Fail-closed:** eksik alanla belge üretilmez. Zorunlu alanlar üreticinin kendi
*"Zorunlu Bilgiler"* belgesinden kalibre edildi (vergi türü `0015` · düzenleyenin vergi dairesi
ve iş adresi zorunlu · muhatapta *"varsa"* → zorunlu değil). Sınav: `ubl_iade.test.sh` (55 kapı).

## ✅ GÖNDERİM ÇALIŞIYOR — 2026-08-22, demo'da üç fatura geçti

`resultCode=1` · refId **55848628** (satış) · **55848629** (satış) · **55848630** (iade).
Üçüncüsü birinciyi dayanak gösteren gerçek bir iade faturasıdır.

### 🔴 İki gönderim yolu — numara kuralı FARKLI
| yol | çağrı | numarayı kim verir |
|---|---|---|
| Taslak | `SendDraftDocument` | **e-Logo** (portalde "sıra numarası ver") |
| Doğrudan | `SendDocument` | **DÜZENLEYEN — yani biz** |

Doğrudan gönderimde `cbc:ID` boş bırakılamaz. Format e-Logo'nun kendi hata metninden:
**16 karakter** = 3 serbest + 4 yıl + 9 rakam (`ABC2026000000001`).
→ `numara_modu="elogo"` bu yolda **çalışmaz**; `numara_modu="verilen"` + `fatura_no` gerekir.
→ "Demo'da tanımlı seri yok" engeli bu yolda **bloklayıcı değildi** — seri tanımı olmadan geçti.
🔴 **Numara üretimi bizim sorumluluğumuz** → mükerrer numara riski gerçek; sayacın nerede
tutulacağı ve portalden elle kesilenlerle çakışmanın nasıl önleneceği **AÇIK SORU**.

### Belgede olması ZORUNLU olan, ölçülerek bulunan dört şey
1. `cbc:CopyIndicator` + **`cbc:UUID` (ETTN)** — UBL sırası katı: `ID → CopyIndicator → UUID → IssueDate`
2. Belge düzeyinde **oran-bazlı KDV dökümü** (`TaxTotal/TaxSubtotal`) — yalnız toplam yetmez
3. **Görünüm şablonu** — hesapta tanımlı yoksa belgeye gömülür (`ubl_xslt.py`)
4. 16 haneli **numara**

Altı denemede altı engel ölçüldü; hiçbiri tahmin edilmedi — her ret bir sonrakini söyledi.
Ayrıntılı tablo: `Nexus/_agents/bilgi/elogo-entegrasyon-bilgisi.md`.

## İKİ FATURA TÜRÜ — satış ⟂ iade (v1.5.0, Sultan direktifi 2026-08-22)

| tür | modül | `InvoiceTypeCode` | zorunlu şerh | dayanak (`BillingReference`) |
|---|---|---|---|---|
| **Satış** (olağan) | `ubl_satis.py` | `SATIS` | — | **YOK** |
| **İade** (alıcı keser) | `ubl_iade.py` | `IADE` | "İADE FATURASIDIR" | **ZORUNLU** (yoksa GİB 1150) |

Gövde ikisinde de **ortaktır** (`ubl_ortak.py`): taraflar, kalemler, kuruş aritmetiği,
KDV türü/oranı/tutarı, numara politikası, XML iskeleti. Ayrıştıkları yer yukarıdaki üç sütun.

🔴 **İki ayrı sınıf, bilerek.** `SatisFaturasi` dayanak alanını **kabul etmez**;
`IadeFaturasi` dayanaksız **kurulmaz**. Böylece "satış sanıp dayanağı atlama" ve
"satışa dayanak ekleyip belgeyi iade gibi gösterme" hataları yapısal olarak imkânsız.
Sınav bu ayrımı iki yönden de kilitler.

🔴 **Ortak gövdeye çıkarma bir refactor'dü ve kanıtlandı:** iade kurucusu 396 → 190 satıra
indi, 55 kapının 55'i yeşil kaldı ve **üretilen XML eski koda göre bayt bayt aynı**
(4730 bayt, `diff` ile doğrulandı). Üçüncü bir kopya açmak yerine çatalın kökü kapatıldı.

Sınavlar: `ubl_satis.test.sh` (**24 kapı**) · `ubl_iade.test.sh` (**55 kapı**).
Toplam paket: **132 kapı** (satış 24 · iade 55 · paketleyici 17 · gönderici 22 · önek 14).

## Taşıma — `elogo_soap.py`
```
python3 elogo_soap.py ELOGO_DEMO    # test ortamı (VARSAYILAN)
python3 elogo_soap.py ELOGO         # canlı
```
Ortam **açıkça** seçilir. Varsayılanı canlı yapmak, bir gün birinin yanlışlıkla gerçek fatura
kesmesi demektir.

### 🔴 Üç değişmez (silmeden önce oku — üçü de acıyla ölçüldü)
1. **Ad-alanı:** `Login`/`login` sarmalı `tempuri.org`'da, **alt alanlar**
   `schemas.datacontract.org/2004/07/eFaturaWebService`'te. Karıştırırsan sunucu kullanıcı adını
   **hiç görmez** ve *"Hatalı kullanıcı adı veya şifre"* der → **seni kimlik avına yollar.**
2. **Alan sırası alfabetik:** `appStr · passWord · source · userName · version`
   (appStr/source/version **BOŞ**).
3. **Bot engeli:** uç Cloudflare arkasında; varsayılan Python UA ile `403 · error code 1010`.
   Tarayıcı-benzeri `User-Agent` **şart**. Kod bu hatayı yakalar ve *"bu bir kimlik hatası
   DEĞİLDİR"* der.

## Gönderim hattı — `elogo_paket.py` + `elogo_gonder.py`

**2026-08-21'de kapı aralandı.** Önceki sürümde burada üç sebeple "gönderme çağrısı yoktur"
yazıyordu. Arabirim dokümanı geldi ve o sebeplerin **ikisi çürüdü** — dürüstlük gereği
olduğu gibi yazıyorum:

| eski sebep | bugünkü durum |
|---|---|
| "`paramList` anahtarları eksik" | ❌ **çürüdü** — tam liste belgede var, kodda uygulandı |
| "taslak akışı belgesiz" | ❌ **çürüdü** — `SendDraftDocument` belgelendi (`DRAFTINVOICE` + `UUID`) |
| "e-Faturada iptal yoktur" | ✅ **ayakta** — bu yüzden gönderim hâlâ dört kapının arkasında |

### İki dosya, iki risk sınıfı
- **`elogo_paket.py`** — saf hesap: UBL → zip → base64 → **MD5**. Ağsız, şirketsiz, kimliksiz.
  Sınav: `elogo_paket.test.sh` (**17 kapı**). En değerli ikisi özetin *hangi veri üstünde*
  alındığını kilitler — zip'in ham baytları üstünde, base64 metni üstünde değil.
- **`elogo_gonder.py`** — geri alınamaz taraf. `SendDocument` zarfını kurar ve gönderir.
  Sınav: `elogo_gonder.test.sh` (**22 kapı**), tamamı ağsız; ikisi taşıyıcıyı sabote edip
  *"kapı düştüğünde ağa çıkılmıyor mu"* sorusunu fiilen ölçer.

### Dört kapı (hepsi geçilmeden tek bayt gitmez)
1. **Ortam** açıkça seçilir — varsayılan **demo**; canlı `--canli` ister.
2. **Kuru koşum varsayılandır** — `--gercekten-gonder` yoksa zarf kurulur, **ağa çıkılmaz**.
3. **Sultan onayı beyanı** — yer-tutucu ve **tarihsiz** beyan reddedilir.
4. **Paket bütünlüğü** — dört alan dolu, özet 32 hane MD5 (SHA-256 kazası yakalanır).

### 🔴 Yeni e-Arşiv bilerek DESTEKLENMİYOR
`EARCHIVETYPE2` her gönderimde Sultan'ın telefonuna **180 saniyelik bir kod** düşürür
(`Get2FACode`, arabirim dokümanı s.24) — insansız akışa uymaz. Sultan 2026-08-21'de hattın
**e-Fatura** üstüne kurulmasına karar verdi. Bu bir eksiklik değil, bir karardır; kodda
sınavla kilitli.

### Ortam öneki — `--demo` (v1.4.0)
Kimlik değişkenleri ortama göre **ayrı** yaşar: `ELOGO_WS_*` (canlı) ⟂ `ELOGO_DEMO_WS_*` (demo).
Bu ayrım python tarafında baştan vardı; eksik olan kabuk tarafıydı, bu yüzden demo girişi
elle yapılmak zorunda kalıyordu (SERDAR tespiti, 2026-08-21).

```
elogo.sh --demo login      # demo kimliğini gizli al, doğrula, DEMO önekine yaz
elogo.sh --demo doctor     # demo erişimini 3-durum raporla
elogo.sh login             # canlı — davranış DEĞİŞMEDİ
```
🔴 **Varsayılan canlıdır ve öyle kalmalı** — mevcut çağrılar bayt-aynı sürsün diye.
Demo'ya geçmek açık niyet ister. Sınav bunu tersinden de kilitler (`varsayılan DEMO DEĞİL`).

🔴 **Demo yolu `uv`/`zeep` istemez** — saf `python3` üstünde koşar (`elogo_soap.py`). MUHASİP'in
kutusunda ölçülen şey python3'ün varlığıydı; demo girişini uv'ye bağlamak orada işi öldürürdü.
Canlı doğrulayıcı bilerek eski yolunda bırakıldı (iki-kopya çatalı bilinen borç, burada büyütülmedi).

Sınav: `elogo_onek.test.sh` (**11 kapı**). Regresyon kanıtı: bayraksız `doctor` eski dosyayla
**birebir aynı** çıktı ve exit kodunu verdi.

### 🔴 Alıcı etiketi (`ALIAS`) — GERÇEK GÖNDERİMDE ZORUNLU (araç seviyesinde kapılı)
**Kapı eklendi 2026-08-22** (MUAVİN/Sultan): `--gercekten-gonder` varken `--alias` YOKSA
gönderim **rc=7** ile reddedilir. Ayrıca biçim (`urn:mail:` ile başlamalı) ve
**irsaliye kutusu** (`irsaliye` içeren etiket) reddedilir. Kuru koşum etkilenmez.

**Niçin "unutmayalım" yetmedi:** üretici dokümanı der ki *etiket gönderilmezse tek etiketli
alıcıda belge o etikete gider, çok etiketli alıcıda hata üretilir.* Yani **aynı ihmal
alıcıya göre bazen görünür bazen GÖRÜNMEZ** — tek kutulu alıcıda belge **sessizce** gider,
hiçbir uyarı çıkmaz. Bu, hata sınıflarının en kötüsüdür; araç seviyesinde zorunluluk şart.

**Sınav (kırmayı deneyerek, 2026-08-22):** alias yok → **rc=7** · biçimsiz → **rc=7** ·
irsaliye kutusu → **rc=7** · boş string → **rc=7** · kuru koşum alias'sız → **rc=0** (izin). ✅

**Mekanizma kanıtı (demo):** `--alias urn:mail:defaultpk@ornekfirma` ile gönderim
`resultCode=1 · refId=55848718 · Başarılı`. Etiket UBL gövdesine YAZILMAZ; üreticinin
belgelediği yol gönderim parametresidir (`paramList` → `ALIAS=…`).

### Alıcı etiketi (`ALIAS`) — eski not: zorunlu değil
Belge s.5: *"Etiket gönderilmezse; alıcının **tek** etiketi varsa belge bu etikete gönderilir.
**Birden fazla** etiketi varsa **hata** üretilir."* → etiketi bilmiyorsak boş bırakmak meşrudur;
hata alırsak sebebini e-Logo söyler.

### ~~Hâlâ ölçülmemiş üç şey~~ — ÜÇÜ DE KAPANDI (2026-08-28, canlı kesim)
1. ~~Kontör~~ — Sultan yükledi; canlıda **beş belge** kesintisiz geçti.
2. ~~Tanımlı seri yok~~ — canlıda `FGW` serisi çalışıyor (`FGW2026000000001`…`…008`).
3. ~~Alıcı mükellef mi~~ — `CheckGibUser` **canlıda koşuldu**, aşağıya bak.

## 🔴 e-ARŞİV — mükellef OLMAYAN alıcıya (2026-09-09, CANLI ÇALIŞTI)

e-Fatura **yalnız mükellefe** kesilir; mükellef olmayana **e-Arşiv** gerekir
(belge s.1). Mükelleflik `CheckGibUser` ile ölçülür: **0 etiket → e-Arşiv**.

**Biçim UYDURULMADI** — kendi **12 e-Arşiv faturamızdan** ölçüldü. Farkı yalnız senaryo değil:

| ne | değer |
|---|---|
| `cbc:ProfileID` | **`EARSIVFATURA`** |
| `cbc:IssueTime` | **ZORUNLU** (kök, `IssueDate`'ten SONRA, `InvoiceTypeCode`'dan ÖNCE) |
| ek referans 1 | `ID=gonderimSekli` · `DocumentType=`**`KAGIT`** \| `ELEKTRONIK` |
| ek referans 2 | `ID=duzenlemeTarihi` · `DocumentType=`saat (`HH:MM:SS`) |
| ek referans 3 | `ID=EINVOICE` · `DocumentType=`**`2`** |
| ek referans 4 | XSLT eki (zaten yazılıyordu) — **en sonda** |

Ölçülen 12 belgenin 12'sinde `gonderimSekli = KAGIT`. `ELEKTRONIK`, alıcıya e-posta ile
iletim demektir ve alıcı e-postası ister — o alan bizde yok, bu yüzden varsayılan `KAGIT`.

### Gönderim farkı
```
DOCUMENTTYPE=EARCHIVE          (EINVOICE değil)
```
🔴 **e-Arşivde ETİKET YOKTUR** — alıcı mükellef değildir, posta kutusu da yoktur.
`alias_dogrula` e-Fatura yolunda etiketi **zorunlu** tutar, e-Arşiv yolunda **aramaz**;
etiket verilirse **reddeder** (rc=7): etiketli bir e-Arşiv ya yanlış belge tipi ya yanlış
alıcı demektir. Zarf kurucusu ayrıca etiketi e-Arşiv zarfına **yazmaz** (derinlemesine savunma).
⚠️ Kuru koşumda basılan *"etiket verilmedi…"* satırı e-Fatura metnidir; e-Arşivde yanıltıcıdır.

### Seri
Geçmiş e-Arşivler **FGA** serisinden — o **portalın** serisidir. Servis yolundan FGA
kullanmak **mükerrer numara** riskidir; `FGW` yalnız bizde olduğu için çakışma yapısal
olarak imkânsızdır. FGW ile kesildi ve **kabul edildi** (`resultCode=1`).

### PDF
`getDocumentData(uuid, docType=EARCHIVE, dataType=PDF)` → yine **ZIP** döner, içinde PDF.
`getInvoiceStatus` e-Arşivde **çalışmaz** ("Fatura sistemde bulunamadı") — o metot e-Faturaya aittir.

**Kanıt:** `earsiv.test.sh` (**20 kapı**) — biçim · e-Fatura yolunun REGRESYONU · üç kapı ·
gönderim zarfı ve etiket kuralları. **Beş mutasyon**, beşi de kırmızı.

> ⚠️ **Sınavın zayıflığı, kayda geçiyor:** "e-Arşivde ALIAS yazılsın" mutasyonu ilk turda
> YAKALANMADI — çünkü sınav etiketi `None` veriyordu ve mutasyonlu hâlde de ALIAS
> yazılmıyordu. Etiket VEREREK sınanınca ayrıştı. *Bir kapıyı, kapının bakacağı girdi
> yokken sınamak, kapıyı sınamak değildir.*

## 📄 KESİLMİŞ e-FATURANIN PDF'İ (ölçüldü 2026-09-09)

```
getDocumentData(sessionID, uuid=<ETTN>, docType=EINVOICE, dataType=PDF)
```
`docType`: `EINVOICE · EARCHIVE · APPLICATIONRESPONSE · DESPATCHADVICE · …`
`dataType`: **`UBL · PDF · HTML`**

🔴 **Dönen şey PDF DEĞİL, ZIP'tir** — `fileName` `.zip` uzantılıdır ve baytlar
`PK\x03\x04` ile başlar. İçinde tek bir `.pdf` vardır. Açmadan diske "…pdf" diye yazmak
**bozuk dosya** üretir — ve bunu kimse dosyayı açana kadar fark etmez. Yazmadan önce
baytların `%PDF-` ile başladığı **doğrulanır**.

⚠️ `elogo.sh get` yalnız **e-Arşiv** PDF'i içindir (`getEArchiveInvoicePdfData`);
e-Fatura için yukarıdaki yol kullanılır.

## 🔴 BELGE TÜRÜ ⟂ KALEM YAPISI — `belge_turu_kapisi` (2026-09-03)

İade niteliğindeki bir belge (`malzeme_iade` · `ek_garanti_iade` · `iade_paketi`)
SATIŞ tipinde kesiliyorsa **TEK KALEM** olmalıdır; kalemleri tek tek yazacaksan belge
**İADE** tipinde kesilir ve referans fatura zorunludur. Üçüncü yol yoktur.

Doğuşu bir hatadır: 11 kalemli bir malzeme iadesi SATIS tipinde kesildi ve belge
"karşı tarafa 11 kalem mal sattık" diye okunur oldu. Kanondaki kural türü söylüyor,
**kalem yapısını söylemiyordu**; boşluğu doldurmak ölçüm değil varsayımdı.

🔴 Kapı **kuruş kapısından ÖNCE** koşar: yapısı yanlış belgede tutarın doğruluğu
sorulmaz bile. Sıra sınavda kilitli (O1); kapıyı sonraya kaydırmak 6 kapı kırmızı yakar.
⚠️ `belge_turu` verilmezse kapı **sessizce geçer** → gerçek kesim yolunda
(`mmex_fatura.py`) beyan ZORUNLUDUR, yoksa "kapı var ama çağrılmamış" olur.

## ⏸ TEVKİFAT — DESTEKLENMİYOR, ama artık SESSİZ değil (2026-08-30)

**Ölçüm:** 4 aylık **1.146** gelen e-Fatura tarandı. Sonuç:
- `cac:WithholdingTaxTotal` bloğu **HİÇ YOK**
- `InvoiceTypeCode=TEVKIFAT` **HİÇ YOK** (SATIS 1114 · IADE 23 · ISTISNA 8 · OZELMATRAH 1)
- "Withholding" geçen 39 fatura **YANLIŞ POZİTİF**: kelime `AdditionalDocumentReference`
  içinde bir ETİKET (`[TEV_HES_KDV]` · `[TEV_TAB_IS]`), UBL tevkifat yapısı değil —
  üstelik `[TEV_TAB_IS]` (tevkifata tabi işlem tutarı) **0,00**.

> 🔴 **Sayıya güvenmeden önce ne saydığını ölç.** "39 tevkifatlı fatura" diye rapor
> etseydim, uydurma bir biçimi "ölçülmüş" diye kanona yazacaktım.

**Karar: tevkifat YAZILMADI.** Gerçek örnek olmadan biçim uydurmak, Aşama-2 mandasının
("muhtemelen sorun yok" YASAK) doğrudan ihlalidir. İhtiyaç doğduğunda gerçek bir
tevkifatlı fatura ölçülerek yapılır; oran/kapsam **mali müşavir alanıdır**.

### Ama kapı artık DOĞRU SEBEBİ söylüyor
Kuruş kapısı tevkifatlı dayanakta zaten duruyordu — *"fark 40,00"* diyerek. O cümle
**yanlış onarıma davettir**: insan farkı yuvarlama sanıp dayanağı yükseltir ve
**tevkifatsız yanlış fatura** keser. (Aynı desen ortam kilidinde de görüldü:
doğru durur, yanlış sebep söyler.)

Artık fark, KDV'nin bilinen bir tevkifat oranına (**2·3·4·5·7·9·10 / 10**) tam denk
düşüyorsa kapı bunu söyler, hattın tevkifatı desteklemediğini belirtir ve
*"dayanağı yükseltme, mali müşavire sor"* uyarısını verir.
🔴 Teşhis bir **tahmindir, geçiş sebebi DEĞİLDİR** — belge yine üretilmez.

**Kanıt:** `tevkifat_teshis.test.sh` (**12 kapı**) — yedi oranın yedisi · rastgele farkta
susuyor · ters yönde susuyor · KDV yokken susuyor · teşhis verilse de belge üretilmiyor ·
meşru belge etkilenmiyor. **İki mutasyon:** teşhis kapatılınca 7 kapı kırmızı,
"her farkta konuş" yapılınca ayırt-edicilik kapısı kırmızı.

## 🔴 İSKONTO — `cac:AllowanceCharge` (2026-08-29)

**Biçim UYDURULMADI, ÖLÇÜLDÜ.** 263 gelen e-Fatura tarandı; **240'ında** `AllowanceCharge`
var — istisna değil, standart. Ölçülen gerçek satır: brüt **62,50** · oran **%30** ·
iskonto **18,75** · net **43,75** · KDV **8,75** · ödenecek **52,50**.

| yer | yapı | konum (ÖLÇÜLDÜ) |
|---|---|---|
| **satır** | `ChargeIndicator=false` · `MultiplierFactorNumeric=`**oran** · `Amount=`tutar | `LineExtensionAmount`'tan **sonra**, `TaxTotal`'dan **önce** |
| **belge** | aynı yapı, oran **0**, `Amount=`**toplam** | taraflardan **sonra**, `TaxTotal`'dan **önce** |
| **toplam** | `AllowanceTotalAmount` | `TaxInclusive` ile `Payable` **arasında** |

🔴 **`PriceAmount` BRÜT'tür** (iskonto öncesi), `LineExtensionAmount` iskonto düşülmüştür;
KDV **düşülmüş** matrah üzerinden hesaplanır. `Kalem.birim_fiyat_kurus` bu yüzden brüttür.

**Üst katman biçimleri** (ikinci eleman HER BİÇİMDE iskonto ÖNCESİ tutar):
`(ad, tutar)` · `(ad, tutar, oran)` · `(ad, brüt, oran, iskonto)` · `(ad, brüt, oran, iskonto, iskonto_oranı)`
İskonto yoksa brüt = net → eski çağrılar **aynen** çalışır (regresyon sınavda kilitli).

🔴 **Oran tutarı TÜRETMEZ, SINAR.** `iskonto_orani` verilirse `brüt × oran`, verilen tutarı
açıklamalıdır; açıklamıyorsa belge **kurulmaz**. Türetseydik tek tanık olurdu.

⚠️ **Ana alıcı fiş paketi yolunda iskonto KULLANILMAZ** — Özet'teki indirim `Net` sütununa
zaten işlenmiştir; oraya iskonto eklemek **iki kez düşer**. Bu kapıyla engellenmez
(meşru kullanım ayırt edilemez); disiplinle taşınır.

⏸ [ANLATI] Ölçülen faturalar ayrıca `ChargeIndicator=true` + `Amount=0.00` (artırım) bloğu
yazıyor. **Zorunlu olup olmadığı ölçülmedi**; bizde artırım kavramı yok, yazılmıyor.
e-Logo önizlemesi belgemizi işledi (`resultCode=1`) — ama önizleme **doğrulama değildir**.

### Kanıt — `iskonto.test.sh` (29 kapı)
Fikstür **gerçek faturanın sayılarıdır**, kolay hâl değil. Kalem aritmetiği · oran çapraz
kontrolü · 2/3/4/5'li biçimler · UBL konum ve içerik · iskontosuz REGRESYON (blok hiç
olmamalı) · ürün kapısının 7 bozma denemesi · **bağlantı sınavı** (doğrulama `kur()`
yolundan çağrılıyor mu).

**Yedi mutasyon, yedisi de kırmızı:** matrah iskontoyu düşmesin · satır bloğu yazılmasın ·
belge bloğu yazılmasın · `AllowanceTotalAmount` yazılmasın · **doğrulama bağlantısı
kesilsin** · ürün kapısı 4c no-op · 4d kör.

> 🔴 **Sınav yazarken bir açık buldu:** belge düzeyi `AllowanceCharge/Amount` hiçbir kapıda
> sınanmıyordu — hepsi `AllowanceTotalAmount`'a bakıyordu. İkisi ayrı elemandır ve
> ayrışabilir; belge o hâlde iki yerde iki farklı toplam iskonto yazar. Kapı 4d eklendi.

> ⚠️ **Sınav dosyasının kendi tuzağı:** heredoc TIRNAKSIZ (`$K` genişlesin diye) →
> içine **backtick yazma**; bash onu komut ikamesi sanıp çalıştırır ve `syntax error`
> basar. Sınav yeşil görünürken gürültü gerçekti.

## 🔴 UYGULAMA YANITI (KABUL/RED) — 2026-08-29, ilk canlı RED

**Ne için:** gelen bir **ticari** faturaya kabul/red cevabı. Temel faturada **oluşturulamaz**
(belge s.1). `yanit_hazirla.py` önce ÖLÇER, sonra taslağı basar; gönderim ayrı fiildir.

**Reçete** — belge verisi YOK, datayı e-Logo üretir:
```
DOCUMENTTYPE=CREATEAPPLICATIONRESPONSE · UUID=<gelen faturanın ETTN'i>
APPLICATIONRESPONSE=KABUL|RED · DESCRIPTION=<gerekçe> · ALIAS=<karşı tarafın etiketi>
```
`APPLICATIONRESPONSE` tipi UBL belgesini BİZİM kurmamızı isterdi; `CREATE…` tipinde
şematron uyumu üreticinin sorumluluğunda kalır — bilinçli tercih.

### 🔴 YÖN KAPISI — yanıt, BİZE GELEN faturaya verilir (hata avı bulgusu)

**Ölçülmüş açık (2026-08-29):** hattın hiçbir yerinde yön kontrolü YOKTU. Kendi kestiğimiz
`FGW2026000000994`'ün ETTN'i verildiğinde — satıcısı BİZ, alıcısı ana alıcı — taslak sorunsuz
kuruldu; **senaryo kapısı da geçirdi**, çünkü o fatura da ticariydi.
`--gercekten-gonder` eklenseydi **kendi faturamıza red** gönderilecekti.

> **Yön ile senaryo bağımsız iki şeydir.** Biri ötekini yakalamaz; ikisi ayrı kapı ister.

Kapı fail-closed'dır: kendi VKN'miz (`MMEX_BIZ_VKN`, **kutu-yerel**) bilinmiyorsa
belge kurulmaz (`rc=5`). *"Bilmiyorum", "izin var" demek değildir.*

### ⚠️ `getInvoiceList` — aralık **30 GÜNDEN** uzun olamaz (ölçüldü 2026-08-30)
Daha uzun aralık `http=500 · "Başlangıç ve bitiş tarih aralığı 30 günden fazla olamaz!"`
döndürür. **İyi ki hata veriyor:** sessizce kırpsaydı, eksik tarama "bu belge yok"
hükmüne dönüşürdü. Uzun dönem taranacaksa **30 günlük pencerelere bölünür** ve
sonuçlar tekilleştirilir (pencereler kesişebilir).

### 🔴 "Yanıt verilmiş mi" — DOĞRU METOT ve iki körlük

| metot | ne der | hüküm |
|---|---|---|
| `getAppRespStatus` | **her zaman** "Uygulama yanıtı sistemde bulunamadı" | 🔴 **KULLANMA** |
| `getEnvelopeList` + `getApplicationResponse` | yanıt **görünmez** | 🔴 kapsamı dışında |
| `getInvoiceApplicationResponse` | `0` yanıtsız · `2` yanıt VAR · `4` temel (verilemez) | ✅ **BUDUR** |

Değerler **kontrol gruplu** ölçüldü (24-29 Ağustos, 53 gelen fatura): 51'i `4`, biri `0`
(`GID2026000000777`, ticari, cevapsız), biri `2` (RED gönderdiğimiz). Hedef fatura
gönderim ÖNCESİ `0` idi — yani kontrol grubuyla aynı sınıftaydı; yanıt yalnız ona gönderildi
ve yalnız o `0→2` geçti. ⏸ Ölçülmedi: `2`, RED ile KABUL'ü ayırt ediyor mu.

🔴 **Mükerrer kapısı bu metoda bağlıdır.** Eskiden `getAppRespStatus`'a bakıyordu ve o metot
yanıt kaydedildikten sonra bile "yok" dediği için kapı, yanıtlanmış faturayı **yanıtsız
sanardı** → aynı faturaya ikinci yanıt. Firsthand sınandı: ikinci deneme artık `rc=4`.

### Portal karşılığı — göremediğinde buraya bak
`e-Fatura > **Giden Uygulama Yanıtları**`. 🔴 Uygulama yanıtı **"Giden e-Fatura"
listesinde GÖRÜNMEZ** — o liste yalnız faturaları listeler. Yanıt fatura değildir.

> **Ders (acıyla):** yanıtı zarf listesinde arayıp bulamadım ve *doğru olan* ölçümü
> (`=2`, kontrol gruplu) kendi elimle zayıflattım; kayıt portalde duruyordu.
> **Kontrol grubuyla doğrulanmış bir ölçüm, başka bir aracın onu görememesiyle çürütülmez
> — sorgulanacak olan ikinci aracın KAPSAMIDIR.**

### Kanıt — `yanit_hatti.test.sh` (17 kapı, AĞSIZ)
`olc()` monkeypatch'lenir; sınav gerçek e-Logo'ya dokunmaz, kimlik sahtedir.
Kapsanan: yön (3) · senaryo (2) · mükerrer (3) · alias (2) · kuru-koşum ağ-tuzağı (1) ·
zarf kurucusunun kendi doğrulamaları (6, `binaryData` YOKLUĞU dahil).

**Dört mutasyon, dördü de kırmızı:** yön kapısı silindi → Y2 · senaryo no-op → S1/S2 ·
mükerrer silindi → M1/M2/M3 · kimlik-yok kapısı silindi → Y3.

> ⚠️ **Sınavın kendi kusuru, kayda geçiyor:** ilk sürümde 4. mutasyon YAKALANMADI. Y3
> kimliği siliyor ama alıcı VKN'yi normal bırakıyordu; kimlik kapısı kalksa bile
> `biz=""` olup **yön kapısı** aynı `rc=5`'i üretiyordu. Yani Y3, ölçtüğünü sandığı kapıyı
> değil komşusunu ölçüyordu. Alıcı VKN de boşaltılınca iki kapı ayrıştı.
> *Aynı çıkış kodunu iki kapı üretebiliyorsa, sınav hangisini ölçtüğünü bilmiyordur.*

### Etiket
Karşı tarafın **`defaultgb`** kutusu kullanıldı (belge s.11 örneği) ve **çalıştı** —
yanıt portalde doğru alıcıya düştü. ⚠️ `alias_dogrula`'nın hata metni "fatura kutusu için
`defaultpk` kullan" diyor; uygulama yanıtı bağlamında bu yönlendirme **yanlıştır**
(kapı reddetmiyor, yalnız mesajı yanıltıyor).

## 🔴 CANLI KESİM DERSLERİ — 2026-08-28 (beş fatura, GİB'den beşi de `1300`)

Bu bölüm bir tur özeti değil; **her satırı bir kez yanıldığımızın kaydıdır**.
Öz kural (Sultan): *fatura hattında iş bitmiş sayılmaz — dersi kanona yazılana kadar.*

### D1 · `CheckGibUser` — alıcının kaç etiketi var (YENİ, ölçüldü)
`CheckGibUser(sessionID, vknTcknList[])` → her VKN için etiket listesi (`Alias` · `Title` · `Type`).
🔴 **Ana alıcının DÖRT etiketi var** — `defaultpk` · `defaultgb` ·
`defaultirsaliyepk` · `defaultirsaliyegb`. Belge s.5 "tek etiketi varsa oraya gider" diyor;
**burada tek değil** → etiketsiz gönderim **hata verirdi**. Aracın `--alias` zorunluluğu
teoriden değil, bu ölçümden meşrudur. Fatura kutusu **`defaultpk`**'dır (`gb` = gönderici
birim, `irsaliye*` = e-İrsaliye). Değer **kutu-yerel** `MMEX_ALICI_ALIAS`'ta; ortak rafta DEĞİL.

### D2 · `getInvoiceList` + `getInvoice` — "daha önce kesildi mi"nin İKİNCİ katmanı (YENİ)
`getInvoiceList(beginDate, endDate, opType=SEND, sessionID, dateBy=byISSUEDATE)` → ETTN listesi;
`getInvoice(invoiceID, sessionID)` → belgenin **kendisi** (zip → UBL; `<a:Value>` base64).
Böylece giden faturanın numarası · tutarı · tipi · referansı · notu okunabiliyor.
🔴 Bu, `arcelik-fatura-kesim` Kural 3'ün **ölçülemiyor sanılan 2. katmanıdır**. Artık çift-kesim
kalkanı tek bacaklı değil. Ayrıca **arşiv onarımının kaynağıdır**: yerel kopya bozulursa
otorite buradadır (bkz. D5).

### D3 · 🔴 `GetDocumentPreView` BİR DOĞRULAMA KAPISI DEĞİLDİR
İADE tipli bir belgeyi önizlemeye verdik: **`resultCode=1`** ve 141 KB düzgün görsel döndü.
**Aynı belge** `SendDocument`'te **`resultCode=-1`** ile reddedildi (senaryo–tip uyumsuzluğu).
> **"Önizleme geçti" ⇏ "gönderim geçer".** İkisi ayrı kapıdır; önizleme belgeyi *çizer*, *onaylamaz*.

Önizleme yine de değerlidir — görselin İÇERİĞİ okunabilir (biz "İadeye Konu Olan Faturalar ·
AP0… · 13-08-2026" satırının basıldığını böyle kanıtladık). Ama **geçerlilik hükmü vermez.**

### D4 · İADE tipinde senaryo KAPALI KÜMEDİR
e-Logo'nun kendi ret mesajı kümeyi saydı: *"Fatura tipi IADE iken fatura senaryosu sadece
**TEMELFATURA, ILAC_TIBBICIHAZ, YATIRIMTESVIK veya IDIS** olabilir."*
→ `ubl_iade.IADE_SENARYOLARI` + `IadeFaturasi.senaryo = "TEMELFATURA"`; kapı **ağa çıkmadan** yakalar.
⚠️ `sozlukten()` ayrıca düzeltildi: `"TICARIFATURA"` varsayıyordu ve **dataclass varsayılanını
eziyordu** — sınav yakaladı. *İki yerde varsayılan olan bir değerin, hangisinin kazandığını ölç.*
🔴 **İş sonucu, sessiz geçilmesin:** satışta TİCARİ, iadede TEMEL senaryo kullanıyoruz.
TEMEL faturada alıcı **ticari uygulama yanıtı (kabul/red) veremez** — itiraz yolu değişir.
Bu bizim tercihimiz değil, GİB/e-Logo şartıdır; ama bir fark olduğu bilinerek taşınır.

### D5 · Her üretim YENİ `cbc:UUID` doğurur — gönderilmiş belge YENİDEN ÜRETİLMEZ
Belgeleri düzeltip yeniden ürettiğimizde araç **zaten gönderilmiş üç belgeyi de** tazeledi.
UUID değişti → diskteki arşiv, e-Logo'ya fiilen gidenin kopyası olmaktan **çıktı**.
Onarım: otorite `getInvoice` ile e-Logo'dan geri çekildi (üçü de birebir yerine kondu) ve
`mmex_fatura.py`'ye kapı eklendi (kesim defterinde "kesildi" olan SAP yeniden üretilmez).
> **Gönderilmiş belge üretilmez, İNDİRİLİR.** Kaynak hattır, yerel dosya değil.

### D6 · 🔴 Ortam kilidi HİÇ OKUNMUYORDU (`Path("")` tuzağı)
`kilit_yolu or (Path(os.environ.get(K, "")) or <varsayılan>)` yazıyordu.
**`Path("")` boş DEĞİLDİR — `PosixPath('.')`'tır ve TRUTHY'dir.** `or` varsayılana asla
düşmüyor, kilit dosyası hiç açılmıyordu → canlı gönderim varsayılan çağrıda **her zaman**
`rc=6 "kilit okunamadı"` veriyordu, kilit sapasağlam yerinde dururken.
Yön güvenliydi (yanlış gönderim üretmez) ama **kapı, ölçtüğünü sandığı şeyi ölçmüyordu**:
"okunamadı" diyen bir kapı, okumayı hiç denememişti.
⚠️ **Bu bir kez daha görülmüş ve SINAVIN hatası sanılmıştı** (`kilit_yolu=None` geçince
kırılıyordu — `None` varsayılanın ta kendisiymiş). *Ürünün kusuruna bakıp kendi elini suçlama:
"benim testim yanlış" demeden önce, testin geçtiği yolun ürünün varsayılan yolu olup olmadığına bak.*
Kapı: `kilit_varsayilan.test.sh` (**7 kapı**) — mevcut sınav bunu yakalamıyordu, çünkü kilit
yolunu hep **açıkça** veriyordu; kusur ise tam olarak **verilmediğinde** yaşıyordu.
> *Fikstür gerçeğin kolay hâlini seçerse, sınav kolay soruyu sorar.* (Bu dosyada ikinci kez.)

### D7 · Kesim sonrası DENETİM — artık hattın parçası
`_agents/fatura/denetim/`: e-Logo'daki **gerçek** belgeyi, **maildən yeniden indirilen** kaynakla
karşılaştırır. Ara ürünlere (yerel XML, fatura listesi, kesim defteri) **bakmaz** — ikisini de
o adımlar üretmediği için aradaki her kusur görünür. İlk koşum: **5 belge · 109 kontrol · 0 bulgu**,
ve denetimin kendisi **7 mutasyonla** sınandı (yedisi de yakalandı).
İki sessiz tuzağı da orada yazılı: **iki kaynak iki sayı biçimi** kullanıyor (Özet İngiliz
`1,291,518.61` ⟂ PDF Türk `2.834,83` → tek varsayım bir tarafta **1000 kat** hata, sessiz) ve
**eşleştirme sıraya değil SAP'a** bakar (dört ek garanti aynı dakikada, birebir aynı konuyla gelir).

## Türev katmanı — her işin kendi eşlemesi
Gövde **şirketsiz ve işsizdir**. Hangi cari, hangi kalem, hangi KDV oranı, hangi dayanak fatura —
bunlar **kutu-yerel** türevde yaşar (`<kutu>/.claude/skills/fatura-<kutu>`), gövdeye yazılmaz.
Türev gövdeyi **yalnız komut satırı sınırından** çağırır; dosya kopyalamak yasaktır (kopya bayatlar).

## Onay kapısı
Geri-alınamaz adım (numara atama + gönderim) **Sultan onayının arkasındadır** (Sultan kararı
2026-08-21). Ajan işin tamamını yapar — veri toplar, belgeyi kurar, provasını geçer — ve orada
durur. Bu, e-Logo'nun kendi *taslak → numara → gönder* dikişine oturur; sonradan eklenmiş bir
fren değildir.
