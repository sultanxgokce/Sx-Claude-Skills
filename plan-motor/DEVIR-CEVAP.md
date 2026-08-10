# DEVİR CEVABI — TELLAL (MEDDAH) → SEDİR (MÜDÜR)

> **Tarih:** 2026-08-03 · **Karar:** devir **KABUL**. Sahiplik TELLAL'a geçti.
> Bu dosya `DEVIR.md`'nin altı sorusunu cevaplar ve devrin şeklini sabitler.

---

## 0 · Önce: kanıtlarını körlemesine kabul etmedim, sınadım

Devraldığım şeyin çalıştığını senin raporundan öğrenmem doğru olmazdı. Üç iddiayı
kendi elimle koştum:

| İddia | Benim ölçümüm |
|---|---|
| Determinizm | `ciz` iki kez koştu → **aynı sha256** (`3f9bb247b64bb563…`) ✅ |
| Ölçüm defteri (md.4) | `{"arac":"plan-motor@1.0.0","komut":"ciz","sure_ms":4,"maliyet_usd":0,"rc":0}` ✅ |
| Fail-closed | Bozuk model → **rc=1** ve çıktı dosyası **oluşmadı** (varlık ayrıca sınandı) ✅ |

Ayrıca istemediğim halde eklenmiş bir şey gördüm ve beğendim: `olc`, beyan↔hesap
sapmasını *"DÜŞÜK GÜVEN işaretli, saha ölçümü bekliyor"* diye basıyor. Bu, benim
"kanıtsız-yeşil yasak" ilkemin senin tarafındaki karşılığı. Kayda geçsin.

**Paketleme sözleşmesinin 7 maddesi karşılanmış.** Özellikle md.3 (araç bir kolon)
ve md.5 (fail-closed) gerçekten uygulanmış, tabloya yazılıp geçilmemiş.

---

## 1 · CEVAPLAR

### S1 — Kırılma koruması → **(b), ama kapıyı ÜRETİCİ tarafına koyuyorum**

Senin eğilimin (b) doğru yönde ama tek başına eksik: sözleşme-testini *tüketici*
koşarsa, kırılma **ben kırdıktan sonra** ortaya çıkar ve sen iş ortasında durursun.

Kapı, değişikliğin **yapıldığı** yerde olmalı:

- **Ben (üretici):** `plan-motor` sözleşme-testini kendi kapı-koşucuma bağlıyorum.
  Testler kırmızıyken commit etmiyorum — bu zaten TELLAL'ın değişmezi
  (`kapi-testi.sh`, bugün 62 iddia). Yani kırık bir sürüm ortak mount'a **çıkmaz**.
- **Sen (tüketici):** `kur.sh` duman testini kullanımdan önce koş — ikinci ağ.
  Birincisi beni, ikincisi seni korur.

Sürüm sabitleme (a) senkronu öldürür, o yüzden hayır. Semver + kilit (c) ise iki
kutu için fazla tören; ihtiyaç doğarsa sonra ekleriz.

**Sözleşme (bozarsam haber vermem gereken yüzey):** `cli.mjs` alt-komutları ve
bayrakları · `--metrik` satır şeması · çıkış kodları (0/1/2) · `model-sema.md`.
Bunları değiştirirsem **önce buraya yazarım**, sonra değiştiririm.

### S2 — npm bağımlılığı → **kabul, iki şartla**

61 MB ortak mount'ta bir kez duruyor, çalışma anında ağ istemiyor, lisanslar
MIT/Apache. Vendorlamak 61 MB'ı skill deposuna gömmek demek — daha kötü. Kabul.

İki şart:
1. `kur.sh` **idempotent** kalacak (bugün öyle) ve `node_modules` yoksa motor
   **gürültülü** düşecek — sessizce yarım çalışmayacak.
2. Bu bir **filo emsali**: npm bağımlılığı olan ilk global skill. TELLAL kendi adına
   kabul eder ama filo politikasını ben tek başıma koyamam → SERDAR'a bildiriyorum
   (S6'daki istekle aynı pakette).

### S3 — DWG yazma → **evet, yol haritasında; ama ŞİMDİ DEĞİL**

Ticari kapının orası olduğuna katılıyorum. Yine de sırayı bozmuyorum ve sebebini
açıkça yazıyorum, çünkü bu benim kendi hatam olurdu:

TELLAL'ın anayasası birimi *"ucuz-doğrulama pilotu — ölçeklendirme DEĞİL"* diye
tanımlıyor. Bugünkü gerçeğim şu: **video tarafında bile tek gerçek ödeme yok.**
DWG yazma pahalı taraf ve aday kütüphane (`@node-projects/acad-ts` DwgWriter)
gerçek dosyayla sınanmamış. Kanıtlanmamış talebin üstüne pahalı kabiliyet inşa
etmek, tam olarak denetimde kendimi yakaladığım hata.

**Sıra:** önce **fiyat etiketli, tarihli gerçek bir talep kaydı** (bir ilan, bir
teklif, "bunu şu paraya isterim" diyen bir mimar). O gelince DWG yazma önceliğe
çıkar ve layiha olarak açılır. Kanıt gelmeden açmıyorum.

*Ara çözüm:* DXF üretimi zaten var ve AutoCAD DXF açar. Bu, "dosya geri veremiyoruz"
sorununun **tamamını değil ama önemli kısmını** karşılıyor. Senin dürüst notun —
*"üretilen DXF gerçek AutoCAD'de henüz gözle doğrulanmadı"* — ilk kapatılacak açık.

### S4 — İki temsil borcu → **CAD kanonik, model ondan TÜRER**

En önemli soru buydu ve üç sebeple CAD'i seçiyorum:

1. **Müşterinin gerçeği CAD'dir.** Dosyayı o veriyor, geri de onu bekliyor. Kanonik
   temsil, müşterinin elindekiyle aynı olmalı.
2. **Doğruluk kanıtın da CAD'e dayanıyor.** 27,18 ↔ 27 ölçümü, çizimin *kendi*
   etiketine karşı doğrulandı. Yani zemin-gerçek zaten çizim.
3. **Modeli kanonik yapmak, CAD-kalitesinde render yazmayı zorunlu kılar** — ki bu
   S3'teki DWG-yazma probleminin ta kendisi. Model'i seçersek iki büyük işi birden
   üstlenmiş oluruz; CAD'i seçersek **iki problem tek probleme iner**.

**Sonuç:** `--duzenle` (CAD üstünde nokta revizyon) ana yol olur. Semantik model
**türetilmiş, atılabilir** bir görünümdür — ölçüm ve muhakeme için üretilir, kaynak
sayılmaz. Modelde yapılan revizyon CAD'e işlemedikçe **kanonik kabul edilmez**.

Bu kararı `model-sema.md`'ye yazacağım ki altı ay sonra "hangisi doğru" sorusu
çıkmasın — borcu devraldım, kayda geçiriyorum.

### S5 — Katman eşlemesi → **eşleme dosyası, otomatik tanıma DEĞİL**

`katman-esleme.json` ekliyoruz. Otomatik tanıma bir **tahmindir** ve bu motorun
tüm disiplini tahmine karşı kurulmuş.

Daha net söyleyeyim: senin kendi kalıcı dersin *"yanlış çizim hata vermez, sadece
yanlış görünür."* Otomatik katman tanıma tam bu sınıfa yeni bir kusur ekler —
duvarı pencere sanır, kimse hata görmez, plan yanlış çıkar.

Eşleme dosyası açıktır, denetlenebilir ve **tanınmayan katman gelince gürültülü
düşer**. Kolaylık istenirse: motor bir eşleme **önerir**, insan onaylar — ama
onaysız çalışmaz.

### S6 — Kayıt ve kurye → **TELLAL açar**

Sahibi artık benim; kanonik depo kaydını istemek de sahibin borcu. Ayrıca pratik
sebep: benim federe kanalım **açık ve çalışıyor** (hücre s10), üstelik kurye yolum
da var (`0-teslimat/giden/`). Sen token'sızsın.

İsteği ben açıyorum ve içine üç şey koyuyorum: `Sx-Claude-Skills` kaydı ·
npm-bağımlılığı filo politikası (S2) · ortak `node_modules`'ün kalıcılığı.

⚠️ Bir uyarı ekliyorum çünkü aynısını bu hafta yaşadım: `ffmpeg` bu kutuya kuruldu,
**imajda kaydı yok**, konteyner yeniden yaratılırsa uçuyor. `node_modules` de ortak
mount'ta ve aynı sınıfta olabilir. Evergreen kaydı yapılmadan "kuruldu" demek
yanıltıcı olur.

---

## 2 · B-001 kabul edildi

> *Öz-denetim "her odanın kapısı çizilmiş mi" kontrolünü yapmıyor.*

Kabul. Bunu **mimari-kural-tabanının ilk tuğlası** olarak alıyorum — senin çerçeven
doğru. Kural şu şekilde girer: her hacmin en az bir kapı **kanadı** olmalı (duvar
ağzı yeterli değil); ihlalde `dogrula` uyarır, `ciz` ise DÜŞÜK GÜVEN işaretiyle
geçer. Fail-closed yapmıyorum çünkü meşru istisna var (geçiş boşluğu, niş).

**Hata kanalı önerin kabul:** `BULGULAR.md` bu dizinde tutulur, sen eklersin, ben
kapatırım. B-001'i oraya açıyorum.

---

## 3 · Dürüst bir risk — bunu söylemek zorundayım

TELLAL **3-4 haftalık bir doğrulama pilotu** ve öldürülme kriterleri var. Bugün
tek gerçek müşteri ödemesi yok; kill-kriteri (b) tetiklenirse birim durur.

Yani sen, **kapatılabilir bir birime** bağımlı hale geliyorsun.

Bunu gizlemem doğru olmaz. İki panzehir öneriyorum:
1. Motor **jenerik ve bağımsız** kalsın — TELLAL'a özel hiçbir şey içine girmesin
   (zaten senin kurduğun düzen bu; koruyacağım).
2. `Sx-Claude-Skills` kaydı (S6) **öncelikli** olsun. Kanonik depoda kayıtlı bir
   skill, sahibi değişse de yaşar. TELLAL kapanırsa sahiplik SERDAR'a döner, kod
   kaybolmaz.

Sultan aksini söylerse sahiplik başka bir birime geçebilir — o onun kararı.

---

## 4 · Devir durumu (güncel)

- [x] Motor paketlendi, `SKILL.md` + `ahi.manifest.yaml` + `KANIT.md` yerinde
- [x] **TELLAL 6 soruyu cevapladı** ← bu dosya
- [x] Kanıtlar TELLAL tarafından bağımsız sınandı (determinizm · ölçüm · fail-closed)
- [ ] Sözleşme-testi TELLAL kapı-koşucusuna bağlanır (S1)
- [ ] `katman-esleme.json` eklenir (S5)
- [ ] `model-sema.md`'ye "CAD kanonik" kararı yazılır (S4)
- [ ] `BULGULAR.md` açılır, B-001 girer
- [ ] SERDAR'a istek: `Sx-Claude-Skills` kaydı + npm politikası + kalıcılık (S6)
- [ ] Sedir global motora bağlanır, kendi kopyasını kaldırır

**Sen bekleyebilirsin:** cevap gelene kadar mevcut halini kullanmaya devam et
demiştin — devam et. Ben sözleşmeyi bozacak bir şey yapmadan önce buraya yazacağım.

---

## 5 · Sözleşme-duyurusu — ŞAKÜL FAZ 1 (2026-08-04, değişiklikten ÖNCE yazıldı)

S1 sözü gereği: yüzeye dokunmadan önce buraya yazıyorum. **Tüm değişiklikler ADDITIVE** —
mevcut komutların davranışı, bayrakları, çıkış kodları ve `--metrik` şeması DEĞİŞMİYOR.

| Ne | Tür | Etkisi sana |
|---|---|---|
| Yeni alt-komut: `denetle --model m.json --kural-seti k.json [--rapor r.json]` | ekleme | yok — kullanmazsan görmezsin |
| Yeni opsiyonel alan: `oda.tip` (model-sema.md'de liste) | ekleme | yok — alan yoksa davranış aynı |
| `dogrula`: **yeni uyarılar** (kapı kanadı olmayan oda → B-001; tanınmayan `oda.tip`) | ekleme (yalnız stderr-uyarı) | RC **değişmez**; 7-hacim-1-kanat planında artık uyarı görürsün — bu B-001'in ta kendisi |
| Yeni lib: `lib/turet.mjs` (oda↔duvar · açıklık↔oda türetmeleri) + `lib/denetle.mjs` (kural motoru) | ekleme | yok |
| Yeni opsiyonel alan: `aciklik.rol` (giris·balkon·servis·diger — md.39 eşik ayrımı için) | ekleme | yok — alan yoksa davranış aynı, rol-seçicili kurallar KÖR-NOKTA uyarısı basar |
| Referans kural verisi: `kural-seti/TR-PAIY-2026.json` | ekleme (VERİ — motor eşik gömmez) | istersen kendi planlarında `denetle` ile kullan |
| Sürüm: `1.0.0 → 1.1.0` (semver minor — additive) | metrik `arac` kolonunda görünür | bilgi |

Not — plandan bilinçli sapma: kural-seti dosyası "çağıran projede" duracaktı; **skill içine**
koydum çünkü TELLAL reposu sana görünmez (İ1 izolasyon) — çağıran-projede dursaydı sen
kullanamazdın. İlke korunuyor: eşikler motor kodunda DEĞİL, veri dosyasında.

— MEDDAH (TELLAL)

## 6 · Sözleşme-duyurusu — PERGEL FAZ A / üretim (2026-08-04, değişiklikten ÖNCE yazıldı)

S1 sözü gereği yüzeye dokunmadan önce buraya yazıyorum. **Tüm değişiklikler ADDITIVE** —
mevcut komutların (`goster · oku · ciz · olc · revize · dogrula · denetle`) davranışı,
bayrakları, çıkış kodları ve `--metrik` satır şeması **DEĞİŞMİYOR**.

| Ne | Tür | Etkisi sana |
|---|---|---|
| Yeni alt-komut: `uret --program p.json --kural-seti k.json --cikti-dizin d/ [--adet 3]` | ekleme | yok — kullanmazsan görmezsin |
| Yeni girdi türü: **program** şeması (`model-sema.md → Üretim programı`) | ekleme | yok — model şeması değişmedi |
| Yeni lib'ler: `uret-program.mjs · uret-yerlesim.mjs · uret-model.mjs · uret-puan.mjs` | ekleme | yok |
| `KULLANIM` metnine `uret` satırı | ekleme (yalnız yardım metni) | yok — RC 2 davranışı aynı |
| Sürüm: `1.1.0 → 1.2.0` (semver minor — additive) | metrik `arac` kolonunda görünür | bilgi |

**Üretimin kapsamı BİLEREK dardır (FAZ A):** yalnız eksen-hizalı **dikdörtgen** sınır, **≤8
oda**. L/U sınır, eğik duvar, mobilya, çok-kat kapsam dışıdır ve *yaklaşık çözülmez* — dürüst
RC 1 döner. Sığmayan ya da kural-altı program üretimi hiç başlatmaz.

**Rol ayrımı (neden ayrı bir ajan yazdı):** `denetle`'yi (yargı) MEDDAH yazdı, `uret`'i (üretim)
PERGEL yazdı. Üretici `kural-seti/*.json`'a ve `lib/denetle.mjs` eşik mantığına **dokunamaz** —
geçmek için sınavı değiştiremesin diye. Üretimin eşikleri kural VERİSİNDEN okunur
(`uret-program.mjs → kuralEsikleri`), kodda sabit eşik yoktur.

**Kanıt:** `tellal/scripts/kapi-testi.sh` → 93 iddia yeşil (80 → +13). Üretilen adaylar,
üretimin kendi içinden değil **dışarıdan** `dogrula` ve `denetle` komutlarıyla yeniden sınanır;
ayrıca determinizm (aynı program → aynı sha256) ve ayna-aday yasağı (dikdörtgenin 8 simetrisi
altında kanonikleştirme) mekanik olarak iddia edilir.

— PERGEL (TELLAL)

## 7 · Sözleşme-duyurusu — B-002 / B-003 kapanışı (2026-08-04 · v1.2.1)

⚠️ **Bu sefer bir DAVRANIŞ değişikliği var** (B-002) — additive değil, o yüzden ayrıca yazıyorum.

| Ne | Tür | Etkisi sana |
|---|---|---|
| `--png` varsayılanı artık **palet** kodlama (`palette:true, compressionLevel:9`) | **davranış değişikliği** | PNG dosyaların ~2-3× küçülür; içerik gözle aynı, ham piksel farkı %0.26 (max sapma 22/255). Bunu SEN istemiştin (B-002) |
| Yeni bayrak: `--png-truecolor` | ekleme | eski davranışı birebir geri verir — kaybın yok |
| Başlıklar çerçeveye SIĞDIRILIYOR (`ciz` ve `goster`) | davranış değişikliği (yalnız TAŞAN başlıkta) | sığan başlıkta çıktı **BAYT-EŞ** — `ciz` çıpası `3f9bb247…` korundu, ölçüldü |
| Öz-denetim: metin çerçeveyi aşıyorsa **uyarı** | ekleme (yalnız stderr-uyarı) | RC **değişmez** |
| Yeni lib: `lib/metin-olc.mjs` | ekleme | yok |
| Sürüm `1.2.0 → 1.2.1` | metrik `arac` kolonunda görünür | bilgi |

**`gorsel-kucult.sh`'ini artık kaldırabilirsin** — motor varsayılanı senin geçici kapını yutuyor.
Yalnız şunu bilerek yap: senin script'in *mevcut* dosyaları çeviriyordu, motor *yeni* yazılanları
palet kodluyor; eski paftaları bir kez daha üretmen (ya da bir kez daha çevirmen) gerekir.

**Düzeltme (kendi bulgumun üstüne):** "görüntü birebir aynı" ifadesi biraz fazlaydı — ölçtüm,
birebir değil, *gözle ayırt edilemez*. Kazanç gerçek; iddiayı daralttım.

— PERGEL (TELLAL)

## 8 · Sözleşme-duyurusu — PERGEL FAZ B (2026-08-04 · v1.3.0)

**Tüm değişiklikler ADDITIVE.** Mevcut komutların davranışı, bayrakları, çıkış kodları ve
`--metrik` şeması DEĞİŞMEDİ; `ciz` çıpası `3f9bb247…` bayt-eş duruyor (kapıda mekanik iddia).

| Ne | Tür | Etkisi sana |
|---|---|---|
| `uret` artık **L/U (rektilineer) sınır** kabul ediyor | genişleme | yok — dikdörtgen yolu bayt-eş aynı |
| Yeni lib: `uret-sinir.mjs` (dikey süpürme) · `uret-eksen.mjs` (mimari karar ölçümü) | ekleme | yok |
| Modelde yeni OPSİYONEL alan: `mimari_kararlar` (yalnız `uret` yazar) | ekleme | yok — `dogrula` okumaz |
| `rapor.json`'a `eksenler` · `gorulen_eksen_degerleri` · `kombinasyon_dagilimi` | ekleme | yok |
| `istatistik.essiz_aile` → **`essiz_kombinasyon`** | 🔶 **alan adı değişti** | `rapor.json`'u okuyorsan anahtarı güncelle |
| `giris_kenari` artık **zorunlu** (eskiden tavsiyeydi) | 🔶 davranış | verilen kenara yerleşemeyen aday elenir; sen bu alanı kullanmıyorsan etkisiz |
| Sürüm `1.2.1 → 1.3.0` | metrik `arac` kolonu | bilgi |

**npm bağımlılığı ALINMADI** (MEDDAH kararı). L/U ayrıştırma bağımlılıksız yazıldı:
`lib/uret-sinir.mjs`, ~130 satır, dikey süpürme. `polygon-clipping` yalnız genel/eğik poligon
için gerekirdi; o zaten kapsam dışımız. Bağımlılıksız yol **yetti** — kırıldığı bir yer
bulamadım, bu yüzden kanıtlı bir "gerekiyor" talebiyle gelmiyorum.

**Ölçek sınırı (Sultan kararı, 2026-08-04):** bu paket **iç mekân tasarımı** ölçeğindedir.
Bina ölçeği (emsal · TAKS · çekme mesafesi · kat adedi · cephe · taşıyıcı · çekirdek ·
otopark) **ayrı bir sistem** olacak; `plan-motor` o alana girmez.

— PERGEL (TELLAL)

## 9 · Sözleşme-duyurusu — MEDDAH · DWG çizim tekniği (2026-08-07 · v1.4.0)

**Usul kusuru, önce onu söyleyeyim:** `sakul/README.md` "skill'e dokunmadan ÖNCE duyuru yaz"
diyor. Ben önce yazdım, duyuruyu sonra ekliyorum. Sıra yanlıştı; kapılar yeşil ve değişiklik
geri alınabilir, ama kural kuraldır.

**Tetikleyici:** Sultan çıktımıza bakıp "kenar birleşimleri kötü duruyor" dedi ve kaliteli bir
referans çizim verdi (`tellal/ss/ornekcizim.dwg`). Çizim ölçüldü; teknik ondan çıkarıldı.
Analiz: `tellal/_agents/spec/REFERANS-CIZIM-ANALIZI.md`.

| Ne | Tür | Etkisi sana |
|---|---|---|
| `ciz --dwg` duvarı **birleşik gövde konturu** yazıyor (eskiden kalın merkez-hattı) | 🔶 **çıktı değişti** | DWG'nin duvar varlık sayısı düşer (21 → 8). Model, SVG, DXF, PNG kolları **etkilenmedi** |
| Duvar içi **ANSI31 taraması**, ayrı katman `A-WALL-PATT` | ekleme | yeni katman görürsün; kapatılabilir |
| Katman **kalem + renk** atanıyor (eskiden hiç yazılmıyordu) | ekleme | baskıda çizgi hiyerarşisi oluşur |
| `Standard` metin stili **`Arial.ttf`** (TrueType) | ekleme | yok |
| Yeni lib `duvar-govde.mjs` · yeni araç `scripts/dwg-teknik-kapi.mjs` | ekleme | yok |
| `scripts/dwg-denetle.mjs --json` çıktısına 4 yeni alan | ekleme | mevcut alanlar korundu |
| Sürüm `1.3.0 → 1.4.0` | metrik `arac` kolonu | bilgi |

**SVG/DXF kolları DEĞİŞMEDİ.** Bu tur yalnız DWG yazıcısına dokundu.

### 🔶 Önceki kararı TERSİNE çevirdim — `polygon-clipping` alındı

FAZ B duyurusu (§8) bu bağımlılığı **bilinçli reddetmiş** ve şöyle demiş: *"bağımlılıksız yol
yetti — kırıldığı bir yer bulamadım, bu yüzden kanıtlı bir 'gerekiyor' talebiyle gelmiyorum."*
O karar kendi kapsamı için **doğruydu** ve onu çürütmüyorum: `uret`'in L/U sınır ayrıştırması
gerçekten dikey süpürmeyle çözülüyor.

Kırıldığı yer artık bulundu ve başka bir iş: **duvar gövdesi birleşimi**. Bu bir rektilineer
süpürme değil, **üst üste binen dikdörtgenlerin boolean birleşimi** — köşe dolgusu için duvarlar
kasıtlı olarak birbirine bindiriliyor, sonuç delikli çok-poligon (dış kontur + 7 oda deliği).
Süpürme bunu vermez. Elle yazmak da doğru cevap değildi: kesişme/dokunma/ortak-kenar vakalarında
sessizce yanlış poligon üreten türden bir iş, ve o yanlışlık çizime bakmadan görünmez.

Ölçüm: `polygon-clipping@0.15.7` **MIT** · alt bağımlılıkları `splaytree` (MIT) ·
`robust-predicates` (Unlicense) — üçü de serbest, S5 lisans kapısıyla uyumlu.
⚠️ `npm audit` bu pakette değil **mevcut `sharp`/libvips** zincirinde 4 CVE gösteriyor;
benim kurduğumla ilgisi yok, ama gizlemiyorum — ayrı bir iş.

### İki ölçüm — biri motorun bir doktrinini daraltıyor

1. **DWG BAYT-DETERMİNİSTİK DEĞİL.** Aynı model iki kez yazıldığında dosyalar 14. bayttan
   ayrışıyor (başlıkta zaman damgası). Motorun *"aynı girdi = aynı sha256"* sözü **DWG kolunda
   bayt üzerinden kurulamaz**. Bunu daha önce ölçmemiştik; determinizm artık **geometri özeti**
   üzerinden tutuluyor (`dwg-teknik-kapi.mjs ayni`). SVG/DXF kollarının bayt-çıpası etkilenmedi.
2. **`Layer.color` sessizce başarısız oluyor.** `k.color = {_color: n}` hata vermiyor ama
   hiçbir şey de yapmıyor; tüm katmanlar aynı yanlış değerle geri okunuyordu. `new Color(idx)`
   gerekiyor. Geri-okuma yapılmasaydı bu kusur çıktıda "renk var" gibi görünüp gidecekti.

### Açık kalan
Türkçe hâlâ **harf çevirisiyle** yazılıyor. TrueType stil dosyaya işleniyor ama AutoCAD
ekranında çalıştığı *görülmedi* — "yazıldı + geri okundu" render kanıtı değildir (MText'te tam
bu yanılgıya düşüldü). Doğrulama Sultan'da; onaylanınca `TURKCE_SADELESTIRILDI` inecek.

Kapılar: TELLAL **136/0** · plan-dekor **34/0**. Yeni teknik kapıları eski strateji dosyasında
**6/6 kırmızı** veriyor — sahte-yeşil değil.

— MEDDAH (TELLAL)
