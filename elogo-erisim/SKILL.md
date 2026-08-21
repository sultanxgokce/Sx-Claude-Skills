---
name: elogo-erisim
type: agent
version: 1.6.0
description: >
  e-Logo (Logo e-Fatura/e-Arşiv entegratörü) erişimi gereken işleri PANELE GİRMEDEN, saf SOAP WS ile
  yapar: fatura durumu sorgula, kesilmiş e-Arşiv PDF/UBL indir, **iade faturasının UBL-TR belgesini
  KUR** (ağsız/kontörsüz) ve DEMO ortamına bağlan. Kimlik yoksa BİR-KERELİK gizli giriş ister
  (WS kullanıcı+şifre → doğrula → cortex-access.env 600), sonra bir daha sormaz.
  🔴 GÖNDERME KAPALI (bkz "Gönderme kapısı") + KUYRUK-GÜVENLİ + sır-hijyenik.
  (erisim-skill-fabrikasi ürünü.)
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
tags: [elogo, e-fatura, e-arsiv, erisim, platform-access, soap, setup]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# e-Logo Erişim

> e-Fatura/e-Arşiv işlerini Sultan'a tekrar tekrar giriş sordurmadan yap.
> Kanon reçete: `erisim-skill-fabrikasi/recipes/elogo.md`. Omurga: ../cloudflare-erisim/SKILL.md.

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

### Alıcı etiketi (`ALIAS`) — zorunlu değil
Belge s.5: *"Etiket gönderilmezse; alıcının **tek** etiketi varsa belge bu etikete gönderilir.
**Birden fazla** etiketi varsa **hata** üretilir."* → etiketi bilmiyorsak boş bırakmak meşrudur;
hata alırsak sebebini e-Logo söyler.

### Hâlâ ölçülmemiş üç şey (gerçek gönderimden ÖNCE kapanmalı)
1. **Kontör** — servisten sorulamıyor (belgede 0 geçiş, ölçüldü). Sözleşme §7.7: kontör bitince
   belge **alınır ama gönderilemez**. Demo hesabında `Kalan Kontör: 0` görülmüştü.
2. **Tanımlı fatura serisi yok** — demo'da `GetPrefixLastNumberList` **boş liste** döndü.
   Numara neyden atanacağı ölçülmedi.
3. **Alıcının e-Fatura mükellefi olup olmadığı** — `CheckGIBUser` cevaplar ama **VKN elde yok**.
   Mükellef değilse e-Fatura yolu çalışmaz, e-Arşiv gerekir (ve o da 2FA'ya bağlıdır).

## Türev katmanı — her işin kendi eşlemesi
Gövde **şirketsiz ve işsizdir**. Hangi cari, hangi kalem, hangi KDV oranı, hangi dayanak fatura —
bunlar **kutu-yerel** türevde yaşar (`<kutu>/.claude/skills/fatura-<kutu>`), gövdeye yazılmaz.
Türev gövdeyi **yalnız komut satırı sınırından** çağırır; dosya kopyalamak yasaktır (kopya bayatlar).

## Onay kapısı
Geri-alınamaz adım (numara atama + gönderim) **Sultan onayının arkasındadır** (Sultan kararı
2026-08-21). Ajan işin tamamını yapar — veri toplar, belgeyi kurar, provasını geçer — ve orada
durur. Bu, e-Logo'nun kendi *taslak → numara → gönder* dikişine oturur; sonradan eklenmiş bir
fren değildir.
