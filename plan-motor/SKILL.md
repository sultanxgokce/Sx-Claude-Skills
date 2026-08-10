---
name: plan-motor
type: agent
version: 1.4.0
description: >
  2B kat-planı motoru. DWG/DXF çizimini OKUR (katman/birim/envanter), KENDİ geometrisiyle
  referans kalitede ÇİZER (goster), üstünden ÖLÇER (oda alanı/duvar/mesafe), doğal-dil
  komutunu yapısal tarife çevirip REVİZE eder (duvar taşı/sil, kapı-pencere ekle), ham
  çizimden semantik oda grafı çıkarır (lifting), mevcut bir planı mimari kural setine
  karşı DENETLER (denetle — oda asgarileri, koridor genişliği, kapı net ölçüsü, erişim,
  doğrudan ışık; eşikler kural-seti VERİSİNDEN gelir, motorda sabit sayı yoktur) ve
  boş bir sınır + oda programından aday yerleşim ÜRETİR (uret, v1.3 — EKSEN-HİZALI
  dikdörtgen/L/U sınır, ≤8 oda; her aday dogrula+denetle'den GEÇMİŞTİR ve hangi MİMARİ
  KARARLARDAN geldiği modelden ölçülerek etiketlenir; program sığmıyorsa dürüst RC 1).
  Dosya-tabanlı tek giriş, fail-closed: ölçek/geometri doğrulanamıyorsa çıktı YAZILMAZ.
  Her koşu süre+maliyet+araç basar.
  "plan çiz", "dwg oku", "kat planı", "duvarı kaydır", "oda alanı ölç", "plan denetle",
  "yönetmeliğe uygun mu", "imar kuralı kontrol", "ruhsata uygun mu", "boş kata plan üret",
  "oda yerleşimi öner" tetiğinde.
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
tags: [cad, dwg, dxf, kat-plani, 2b-cizim, olcum, revizyon, lifting, fail-closed, svg, mimari]
---

# plan-motor — 2B kat-planı motoru

> **Jenerik motordur: hiçbir projenin iş mantığını bilmez.** Oda adları, müşteri, teklif,
> mevzuat eşiği burada YOK — onlar çağıran projenin işidir (MEDDAH paketleme sözleşmesi md.1).

## Kurulum (idempotent, tek komut)

```bash
bash "$SKILL_DIR/kur.sh"       # npm bağımlılıkları + duman testi
```
Gereksinim: **node ≥ 22 + npm + ağ (yalnız kurulumda)**. sudo/Python/sistem-fontu GEREKMEZ
(DejaVu fontu paketle gelir, fontconfig ayarı çalışma anında üretilir).
`node_modules` ~61 MB'dır ve **ortak mount'ta durur** — bir kez kurulur, tüm kutular aynı
kurulumu görür. Yoksa `kur.sh` yeniden kurar (idempotent).

## Komutlar

```bash
node cli.mjs goster  --dosya x.dwg|x.dxf --cikti p.svg [--png p.png] [--baslik "…"] [--alt "…"]
                     [--vurgu v.json] [--duzenle d.json] [--kirp x0,y0,x1,y1] [--cikar-json g.json]
node cli.mjs oku     --dosya x.dwg|x.dxf [--rapor r.json]
node cli.mjs ciz     --model m.json --cikti p.svg [--png p.png] [--dxf p.dxf] [--png-truecolor]
                     [--dwg p.dwg] [--yerlesim y.json]   # v1.4 — AutoCAD DWG yazma
node cli.mjs olc     --model m.json [--oda id | --duvar id | --mesafe n1,n2]
node cli.mjs revize  --model m.json --degisiklik d.json --cikti yeni.json [--rapor fark.json]
node cli.mjs dogrula --model m.json
node cli.mjs denetle --model m.json --kural-seti k.json [--rapor r.json]   # v1.1 — mimari kural denetimi
node cli.mjs uret    --program p.json --kural-seti k.json --cikti-dizin d/ [--adet 3]  # v1.3 — üretim
python3 lib/lifting.py girdi.json cikti.json     # ham çizim → semantik oda grafı
```
Çıkış kodları: `0` başarı · `1` doğrulama/fail-closed (çıktı YAZILMAZ) · `2` kullanım · `3` iç hata.

## DWG yazma (`ciz --dwg`, v1.4)

Gerçek AutoCAD DWG üretir — DXF değil. Format **AC1027** (AutoCAD 2013), birim **cm**
(INSUNITS=5). Bağımlılık `@node-projects/acad-ts` (MIT); Autodesk bulutu, ODA üyeliği ya da
ücretli dönüştürücü **kullanılmaz**, maliyet **$0**.

**Çizim tekniği** — Sultan'ın referans çizimi (`tellal/ss/ornekcizim.dwg`) ölçülerek çıkarıldı;
analiz: `tellal/_agents/spec/REFERANS-CIZIM-ANALIZI.md`.

| Konu | Uygulanan |
|---|---|
| Duvar | Ağın **birleşik gövde konturu** (kapalı polyline). Kalın merkez-hattı **KULLANILMAZ** — uçları düz kesik olduğu için köşede çentik/bindirme bırakıyordu |
| Duvar içi | **KATI dolgu** (poché), **ilişkisiz**, ayrı katman `A-WALL-PATT` — mimar kapatabilsin. Dolgu birleşik halkadan DEĞİL, tek tek duvar dikdörtgenlerinden çizilir → **ada (island) anlambilimine hiç girilmez** |
| Kalem | **Katmanda** yaşar (varlıklar ByLayer). Açıklıklar 0.09 mm, duvar 0.50 mm |
| Metin | `Standard` stili **`Arial.ttf`** (TrueType) + düz `TEXT`. Türkçe **ham** yazılır (`ş ı ğ İ Ş Ğ`); AutoCAD'de gözle doğrulandı. Varsayılan `txt.shx`'te Türkçe glifleri yok — sorun kodlama değil FONT'tu |
| Katman | AIA `A-*`. Referansın `px_*` şeması bir üretici imzasıdır, kopyalanmadı |

⚠️ **Bilinen sınırlar — gizlenmez:**
1. **MTEXT KULLANILMAZ.** acad-ts MText'i yazıyor ve geri okunuyor, ama AutoCAD ekranda
   HİÇ göstermiyor (ham da, satır-içi font kodlu da — ikisi de ölçüldü). Referans çizimin
   MText'leri düzgün göründüğüne göre kusur MText'te değil bizim yazışımızda. Çok satırlı
   metin gerekirse düz `TEXT` satırları kullan.
2. **`ansi31` dolgu modu DOĞRULANMADI.** AutoCAD'de 45° eğik çizgi yerine ızgara çıktı;
   sebep çözülmedi. Varsayılan `solid` (gözle doğrulandı). `yok` ile kapatılabilir.
3. **DWG bayt-deterministik DEĞİLDİR** — başlık zaman damgası taşır, aynı model iki kez
   yazıldığında sha256 farklı çıkar. Motorun "aynı girdi = aynı çıktı" disiplini bu kolda
   **geometri özeti** üzerinden ölçülür (`scripts/dwg-teknik-kapi.mjs ayni`).

Öz-denetim araçları (ikisi de pakete ait — kapı yardımcısı test ettiği paketin içinde yaşar):
```bash
node scripts/dwg-denetle.mjs     <a.dwg> [--json]   # envanter · katman · kod sayfası · kusur
node scripts/dwg-teknik-kapi.mjs teknik <a.dwg>     # çizim tekniği iddiaları
node scripts/dwg-teknik-kapi.mjs ayni <a.dwg> <b.dwg>  # geometri aynılığı (bayt DEĞİL)
```

## Mimari denetim (`denetle`, v1.1)

`dogrula` **geometrik** tutarlılığa bakar (referanslar, kapanma, ölçek beyanı); `denetle`
onun üstüne **mimari yargı** koyar. Eşikler motor kodunda YAŞAMAZ — kural-seti JSON'undan
gelir, böylece mevzuat değişince veri güncellenir, kod değil.

- Hazır kural seti: `kural-seti/TR-PAIY-2026.json` — Planlı Alanlar İmar Yönetmeliği asgarileri
  (11 kural: oda alanları/dar kenarlar · koridor ≥120 · kapı net ≥90/100 · doğrudan ışık ·
  erişim bağlantılılığı · kapı kanadı). Her kural **madde no + mevzuat.gov.tr bağlantısı**
  taşır; mevzuata dayanmayanlar açıkça *"mevzuat maddesi DEĞİL"* der.
- Şema: `{id, kaynak, kaynak_url?, uygulanir, sart:[{olcut,op,deger}], siddet}` —
  `siddet: hata` ihlali **RC 1**, `uyari` RC'yi değiştirmez.
- Modelde iki opsiyonel alan denetimi besler: `oda.tip` (oturma_odasi·yatak_odasi·mutfak·
  banyo·wc·hol·antre·balkon·kiler·diger) ve `aciklik.rol` (giris·balkon·servis·diger).
  **Beyan edilmemişse kural o varlığa uygulanamaz ve KÖR NOKTA uyarısı düşer** — sessizce
  "geçti" sayılmaz.
- Doğrulanamayan ölçüm yeşil sayılmaz: eksen-dışı odada dar-kenar bbox üst-sınırına düşer;
  üst-sınırla bir alt-sınır şartını "geçmek" kanıt olmadığından hata-şiddet kuralda **ihlal**
  yazılır. Kanıtlanamayan geçit erişim grafına kenar eklemez, kapı kanadı sayılmaz.

## İKİ AYRI İŞ — karıştırma

| İstenen | Komut | Ne çizer |
|---|---|---|
| **mevcut planı GÖSTER** | `goster` | çizimin KENDİ geometrisi (gövdeler, kapı yayları, kolonlar aynen) |
| **mevcut çizimde NOKTA REVİZYON** | `goster --duzenle` | aynı geometri, tarifle düzenlenmiş (duvar taşı/sil) |
| **modelden ÜRET / alternatif** | `revize` + `ciz --model` | semantik modelden; ölçek yapısal olarak korunur |

🔴 Mevcut durumu `ciz --model` ile göstermeye çalışma: çizimde HAZIR duran duvar gövdelerini
oda konturlarından yeniden inşa etmek demektir — kenar taraklanır, oda araları boşalır,
kapılar bozulur. Ölçüm için model doğrudur; **gösterim için çizimin kendisi doğrudur.**

## ⚠️ CAD okurken üç tuzak (yeni format/dosya eklerken oku)

Üçü de **hata vermeden yanlış çizim** üretir; üçü de gerçek dosyada ölçülerek bulundu:

1. **`isClosed`** — kapalı polyline'ın son→ilk kenarı köşe listesinde görünmez. Ölçülen bir
   dosyada 153 polyline'ın 74'ü kapalıydı; atlanınca her kolon/gövde bir kenar eksik kalır,
   dolgu ve boyama içeriden sızar.
2. **`bulge`** — köşedeki bulge o kenarın YAY olduğunu söyler (bulge = tan(θ/4)). Yok sayılırsa
   yayın kirişi çizilir: kapılar üçgene döner. y aynalandığı için SVG'de dönüş yönü ters çevrilir.
3. **Yüz yönü** — düzlemsel yüz dolaşımı iç yüzleri tutarlı yönde vermez. İşarete göre
   (`alan > 0`) elemek dış duvar bantlarının yarısını **sessizce** düşürür; ölçüt mutlak alandır.

## Öz-denetim (fail-closed, kaçılamaz)

### PNG kodlaması (v1.2.1 · B-002)
`--png` varsayılanı **palet** kodlamasıdır: teknik çizimde renk sayısı azdır, dosya ~2-3 kat
küçülür (ölçüldü: 81 KB → 39 KB), görüntü gözle ayırt edilemez (ham piksel farkı %0.26,
en büyük sapma 22/255 — *birebir değil*, ama görünmüyor). Gerçek gradyan/fotoğraf gerekirse
`--png-truecolor` eski davranışı geri verir.

### Metin sığdırma (v1.2.1 · B-003)
Başlıklar çerçeveye sığdırılır (küçült → iki satıra böl → kırp) ve öz-denetim, üretilen SVG'nin
metinlerini **yeniden ölçüp** çerçeveyi aşanı uyarı olarak bildirir. Ölçü bir tahmindir
(`lib/metin-olc.mjs`, DejaVu Sans advance tablosu, ±%5) — bu yüzden uyarı, fail-closed değil.

`lib/render-denetle.mjs` her çizimi **yazılmadan önce** sınar; kusurluysa dosya hiç oluşmaz:
yay varken çıktıda yay yok · açık duvar çizgisi varken gövde dolgusu yok · katman/etiket kaybı ·
viewBox yok · model kaynağı beyan edilmemiş · düşük-güven odası uyarısız çizilmiş.

## Kapsam sınırı (v1)

Eksen-hizalı, katmanlı, oda etiketleri metin olan çizimler. **Desteklenmez:** eğik duvar,
taranmış (raster) plan, etiketsiz oda, **DWG YAZMA** (okur ve çizer, DWG üretemez).

## Üretim (`uret`, v1.2 · FAZ A)

Boş bir sınır + oda programından **aday yerleşim üretir**. Yargı katmanı üreticiden AYRIDIR:
üretici kural-setine dokunamaz, yalnız ona karşı sınanır — geçemeyen aday yazılmaz.

```bash
node cli.mjs uret --program p.json --kural-seti kural-seti/TR-PAIY-2026.json \
                  --cikti-dizin adaylar/ --adet 3
# → adaylar/aday-01.json … + adaylar/rapor.json (skor · elenen sayaçları · enumerasyon istatistiği)
```
Program şeması ve kapıları: `model-sema.md → Üretim programı`.

- **Her yazılan aday `dogrula` + `denetle`'den GEÇMİŞTİR** — skor yalnız geçenleri sıralar.
- **Determinist:** `Math.random` yok; aynı program iki kez → aynı sha256. Çeşitlilik
  rastgelelikten değil, ayrık kararlardan (oda sırası · kesim ağacı · kesim yönü) gelir.
- **Bir seçenek = bir MİMARİ KARAR KOMBİNASYONU (v1.3).** Aynı kombinasyonun varyasyonu
  (ayna/kaydırma dâhil) yeni bir seçenek sayılmaz; `--adet 3` istenip 2 kombinasyon bulunursa
  2 yazılır ve fark stderr'a bildirilir. Dört eksen **modelden ÖLÇÜLÜR, beyan edilmez**
  (`lib/uret-eksen.mjs`) — üçüncü taraf aynı modelden aynı etiketi yeniden türetebilir:
  `islak_cekirdek` · `sirkulasyon` · `zonlama` · `giris`. Her eksenin dayanağı `rapor.json`
  içinde yazılıdır; ikisi ölçüm-temelli mimari sonuç, biri PAİY md.29/(3)'ün tanıdığı hol
  hacmine dayanır. Etiket `model.ad` (SVG başlığı) ve `model.mimari_kararlar` alanına damgalanır.
- **`giris_kenari` ZORUNLUDUR, tavsiye değil:** verilmişse giriş o kenardadır; yerleşemiyorsa
  aday elenir. (Yumuşak olduğu sürümde sahte bir çeşitlilik ekseni üretiyordu — ölçüldü.)
- **Bağımlılıksız:** dikdörtgen sınırda slicing kesimi alan oranından doğrudan hesaplanır;
  kısıt çözücü (Cassowary vb.) kurulmadı — gerekirse FAZ B'de kanıtla alınır.

### Sınır biçimi (v1.3 · FAZ B2)
**Eksen-hizalı (rektilineer)** her sınır kabul edilir — dikdörtgen, **L**, **U**. Sınır dikey
süpürmeyle dikdörtgen parçalara ayrılır (`lib/uret-sinir.mjs`, **bağımlılıksız ~130 satır**),
odalar parçalara atanır, her parçada slicing yürür, parçalar arası komşuluk kapılarla bağlanır.
Sınır alanı **poligondan (shoelace)** ölçülür, bbox'tan değil — L sınırda bbox kullanmak
sığmayan programı "sığdı" sanmak olurdu (fail-open).

🔴 **Hâlâ kapsam DIŞI ve "yaklaşık" çözülmez** (dürüst `RC 1`): **eğik/yaylı sınır**,
**> 4 parçaya ayrılan girintili sınır**, **> 8 oda**, eğik duvar, mobilya yerleşimi,
çok-katlı kurgu. Ayrıca **bina ölçeği** (emsal · TAKS · çekme mesafesi · kat adedi · cephe ·
taşıyıcı · çekirdek · otopark) bu skill'in ölçeği DEĞİLDİR — bu paket **iç mekân** ölçeğinde
çalışır (kural seti de PAİY'in iç mekân maddelerinden kuruludur). Program sınıra sığmıyorsa ya da
kural asgarilerinin altında hedef veriyorsa üretim **hiç başlamaz**: sığmayan programa
"sığdım" demek, motorun tüm disiplinini çürütür.
Lifting yarı-otomatiktir: yakalanamayan kapı ağzı girdide `ek_muhur` ile gerekçesiyle beyan edilir.
Katman adları girdi çiziminin konvansiyonuna bağlıdır (`lib/cad-render.mjs → BICIM`).

## Paketleme sözleşmesi uyumu (MEDDAH 7 madde)

| # | Madde | Karşılığı |
|---|---|---|
| 1 | jenerik motor ↔ iş mantığı ayrımı | bu pakette proje verisi/adı yok; demo jeneriktir |
| 2 | tek giriş, dosya-tabanlı sözleşme | `cli.mjs` — girdi dosyası → çıktı dosyası + RC; sohbete bağımsız |
| 3 | araç bir kolon, gövde değil | format başına ayrı `lib/*.mjs`; model hiçbirini bilmez |
| 4 | her koşu ölçüm bassın | `--metrik` defteri + stderr: süre + maliyet-usd + araç@sürüm + rc |
| 5 | fail-closed | doğrulama geçmeden hiçbir çıktı yazılmaz (öz-denetim dahil) |
| 6 | demo + kanıt çifti | `demo/ornek-model.json` → `demo/ornek-plan.{svg,png,dxf}` |
| 7 | sır hijyeni | motor tamamen yereldir, anahtar kullanmaz; dış API eklenirse anahtar dosyadan okunur, log/çıktıya düşmez |

Şema ve revizyon işlemleri: `model-sema.md`. Devir notu ve açık sorular: `DEVIR.md`.
