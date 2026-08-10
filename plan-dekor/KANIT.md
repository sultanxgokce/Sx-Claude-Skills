# plan-dekor — KANIT DEFTERİ

> Kural: kanıtsız "çalışıyor" YASAK. Her satır **kırpılmamış komut çıktısı + RC** taşır.

## K-001 · Kapı-regresyon tam koşu (v0.1.0 · 2026-08-06)

```
$ bash kapi-testi.sh
── plan-dekor kapı testleri ──
[1] Mutlu yol
  ✓ mobilya (demo daire)                       rc=0
  ✓ ciz (mobilyalı, tema modern)              rc=0
  ✓ ciz (mobilyasız)                          rc=0
  ✓ denetle (üretilen aday temiz)             rc=0
  ✓ revize (geçerli — mobilya sil)          rc=0
[2] Fail-closed kapıları (RC 1 + dosya YAZILMAMALI)
  ✓ zorunlu program sığmıyor                rc=1
  ✓ sığmayan → çıktı yok                dosya yazılmadı
  ✓ sığmayan + --kismi-kabul de kırmızı   rc=1
  ✓ tek oda sığmazsa kısmi de yok           dosya yazılmadı
  ✓ kaynaksız kural-seti reddedilir           rc=3
  ✓ kaynaksız kural → çıktı yok          dosya yazılmadı
  ✓ revize çakışma üretir                  rc=1
  ✓ çakışan revize → çıktı yok         dosya yazılmadı
  ✓ revize oda dışına taşır               rc=1
  ✓ oda-dışı revize → çıktı yok        dosya yazılmadı
  ✓ olmayan model                              rc=1
  ✓ eksik argüman                             rc=2
  ✓ bilinmeyen komut                           rc=2
  ✓ olmayan tema                               rc=3
[3] Determinizm (aynı girdi → aynı sha256)
  ✓ yerleşim determinizmi                     sha256 eşit
  ✓ çizim determinizmi                        sha256 eşit
[4] Kabul kriteri — SUIT ODA döşendi mi (kapı yayı boş)
  ✓ suit oda döşendi                         yatak + gardırop yerleşti
[5] Metrik defteri
  ✓ her koşu metrik bastı                    18 satır

geçen: 23 · kalan: 0
SONUC: GECTI
```
RC=0.

## K-002 · Kurulum duman testi

```
$ bash kur.sh
── plan-dekor kur ──
✓ node v22.23.1
✓ plan-motor: /config/.claude/skills/plan-dekor/../plan-motor
✓ sharp (PNG) hazır
✓ duman testi geçti (25937 bayt SVG)
── hazır: node /config/.claude/skills/plan-dekor/cli.mjs ──
```
RC=0.

## K-003 · AHÎ manifest kapısı

```
$ bash /config/.claude/skills/ahi/scripts/ahi.sh check plan-dekor
✓ /config/.claude/skills/ahi/../plan-dekor/ahi.manifest.yaml — geçerli (tier=kalfa, name=plan-dekor)
```
RC=0.

## K-004 · Tek komut uçtan uca (`akis`)

```
$ node cli.mjs akis --model demo/ornek-daire.json --cikti-dizin teslim2 --adet 3 --tema emlak-kontrast
✓ 3 yerleşim adayı → .../teslim2/yerlesim.json
  odalar: 7 döşendi · 0 sığmadı · 0 programsız
✓ .../teslim2/aday-01.svg (+png)
✓ .../teslim2/aday-02.svg (+png)
✓ .../teslim2/aday-03.svg (+png)
✓ .../teslim2/KOKEN.md
📏 plan-dekor@0.1.0 · akis · 10462 ms · $0 · rc=0
```
RC=0. **Ölçülen: 7 odalı 90 m² daire, 3 aday, SVG+PNG+köken beyanı = 10.5 saniye, $0.**

## K-005 · Kabul kriteri (Sultan'ın somut isteği: boş SUIT ODA döşensin)

`demo/ornek-daire.json` içindeki `suit` odası (18.0 m²) mobilyasız tanımlıdır. Üretilen aday-1:

```
suit:
   Çift Kişilik Yatak       200x160
   Gardırop                  60x200
   Komodin                   40x 45
   Komodin                   45x 40
   Şifonyer                 100x 45
   Çalışma Masası           120x 60
   Berjer                    85x 80
```
`denetle` RC=0 → çakışma yok · oda dışına taşma yok · **kapı kanadı süpürme alanı boş** ·
açıklık önü açık. Kapı-testi [4] bunu her koşuda yeniden ölçer.

---

# BULGULAR (ölçülerek bulunan kusurlar ve düzeltmeleri)

## B-001 · Sembol, beyan edilen kutusunun DIŞINA çiziyordu (düzeltildi, v0.1.0)
`masa` sembolü sandalyeleri `y=-38` ve `y=d+6`'ya, yani mobilyanın beyan edilen kutusunun dışına
çiziyordu. Sonuç: **çakışma denetimine girmeyen alan işgali** — çizim, modelin rezerve ettiğinden
fazlasını iddia ediyordu. İlk render'da mutfak masasının sandalyeleri komşu mobilyaya biniyordu.
→ Sandalyeler kutunun İÇİNE alındı; tabla derinliği sandalye payı kadar daraltıldı.
→ Değişmez olarak `SKILL.md`'ye yazıldı: *çizim, modelin ölçtüğünden fazlasını iddia edemez.*

## B-002 · Mobilya duvar gövdesinin içine yerleşiyordu (düzeltildi, v0.1.0)
Oda döngüsü duvar **eksenlerinden** geçer; duvar kalınlığının yarısı odanın "içinde" görünür.
Yerleştirici mobilyayı eksene yaslıyordu → mobilya duvarın içine giriyor, çizimde duvar altında
kalıyor ve **kullanılabilir alan şişiyordu** ("sığdı" iddiası yalan olurdu; 25 cm dış duvarda oda
başına 12.5 cm kayıp).
→ İç yüze (eksen + kalınlık/2) yaslanacak şekilde düzeltildi.

## B-003 · Kombinatorik patlama — tam ızgara enumerasyonu (düzeltildi, v0.1.0)
İlk tasarım her mobilyayı 4 yön × 10 cm tam ızgarada tarıyordu. **Ölçüldü:** 450×400 cm odada
7200 aday/mobilya; iç içe döngüde koşu **>2 dakikada timeout** oldu (RC 143).
→ Yerleşim tipine göre ayrıştırılmış enumerasyon: duvara dayalı mobilya yalnız duvar boyunca
kayar (1B), serbest mobilya kaba ızgarada (30 cm) taranır; ilk mobilyanın adayları
(yön × ana-duvar) **karar kovalarına** indirgenir, her kovadan yalnız en iyisi iç döngüye girer.
→ **Ölçülen sonuç: 7 odalı daire, 3 aday = 3.0-4.0 saniye.** Mimari gerçeğe de bu daha yakındır.

## B-004 · İlk opsiyonel mobilya iki kez yerleşiyordu (düzeltildi, v0.1.0)
Zorunlu listesi boş olan odalarda (antre/hol) ilk mobilya `ilk` olarak yerleştirilip sonra
opsiyonel döngüsünde TEKRAR yerleştiriliyordu. **Ölçüldü:** antrede 2 portmanto.
→ `ilk` hangi listeden geldiyse oradan düşülüyor.

## B-005 · Sığmayan oda varken yine de dosya yazılıyordu (düzeltildi, v0.1.0)
Zorunlu programı sığmayan oda, sessizce atlanıp kalan odalarla dosya yazılıyordu — **fail-closed
deliği**. Kapı-testi bunu ilk koşuda yakaladı (`beklenen 1, gelen 0` + "dosya yazılmış").
→ Varsayılan artık RC 1; bilinçli kısmi teslim için AÇIK `--kismi-kabul` kolu eklendi. Hiçbir oda
döşenemediyse `--kismi-kabul` de geçmez.

## B-006 · Oda etiketi komşu odaya taşıyordu (düzeltildi, v0.1.0)
Metin genişliği katsayısı 0.62 alınmıştı; etiketler BÜYÜK HARF + kalın çiziliyor, bu sınıf DejaVu'da
belirgin daha geniş. **Ölçüldü:** "EBEVEYN BANYO" 250 cm odada yan odaya taşıyordu.
→ Katsayı 0.76'ya çekildi; başlangıç puntosu artık yalnız m²'ye değil **dar kenara** da bağlı.

---

# AÇIK BORÇ

- **Sx-Claude-Skills kanonik kaydı YAPILMADI** — bu izole konteynerden repo görünmüyor.
  Sıfırdan-rebuild bu skill'i geri GETİRMEZ. Kayıt SERDAR'a istek olarak emit edilecek.
  (plan-motor'un da aynı borcu vardı; tekrarlanmaması için burada açıkça kayıtlı.)
- **Faz 3 (raster/görselden dijitalleştirme) yok** — model şu an elle kurulur.
- **Konfor eşikleri sert kural değil** — kaynak araştırması ayrı layihada
  (`_agents/spec/mobilya-esik-kaynagi-ve-ekip-DESIGN.md`).

---

# v0.2.0 · Ölçek çıpası kapısı (2026-08-06)

## K-006 · Çıpa kapısı üç senaryoda ölçüldü

```
$ node cli.mjs cipa --model demo/ornek-daire.json --cipa demo/ornek-cipa.json
  ✓ Suit oda üst duvarı          model     450 cm · beyan     450 cm · sapma %0 (yatay)
  ✓ Salon sol duvarı             model     500 cm · beyan     500 cm · sapma %0 (dikey)
✓ ölçek çıpası geçti (2 çıpa, tavan %3) — model ölçüsü çapraz doğrulandı
📏 plan-dekor@0.2.0 · cipa · 38 ms · $0 · rc=0

$ node cli.mjs cipa --model demo/ornek-daire.json --cipa fixtures/cipa-sapmali.json
  ✓ Suit oda üst duvarı          model     450 cm · beyan     450 cm · sapma %0 (yatay)
  ✗ Salon sol duvarı             model     500 cm · beyan     420 cm · sapma %19.05 (dikey)
✗ ÖLÇEK ÇIPASI KAPISI KIRMIZI — bu model ölçü kanıtı taşımıyor:
  · çıpa "Salon sol duvarı": model 500 cm, beyan 420 cm → %19.05 sapma (tavan %3)
  → Model ölçüsü doğrulanmadan mobilya/çizim aşamasına GEÇME.
📏 plan-dekor@0.2.0 · cipa · 42 ms · $0 · rc=1

$ node cli.mjs cipa --model demo/ornek-daire.json --cipa fixtures/cipa-tek.json
✗ ÖLÇEK ÇIPASI KAPISI KIRMIZI — bu model ölçü kanıtı taşımıyor:
  · en az 2 ölçek çıpası gerekir, 1 verildi — tek çıpa ölçeği DOĞRULAMAZ, yalnız tanımlar
  → Model ölçüsü doğrulanmadan mobilya/çizim aşamasına GEÇME.
📏 plan-dekor@0.2.0 · cipa · 41 ms · $0 · rc=1
```

**Kapının tasarım gerekçesi:** tek çıpaya uymak kolaydır — o ölçüyü tuttururum, gerisi serbest
kalır. İkinci çıpa (tercihen DİK eksende) bağımsız kanıttır: model tutarlıysa ikisi de tutar,
ölçek uydurulmuşsa ikincisi tutmaz. Kapı bunu ölçer, "beyan"a güvenmez.

## K-007 · v0.2.0 tam kapı koşusu
```
geçen: 26 · kalan: 0
SONUC: GECTI
```

---

# v0.3.0 · Bağımsız araştırmanın bulduğu kusurlar (2026-08-06)

Layiha L02 için koşulan **bağımsız araştırma alt-ajanı**, kaynak sorusunu araştırırken bu paketin
kendi kodunda üç kusur buldu. Üçü de gerçekti ve düzeltildi. (Üreten kendi işini denetleyemez —
bu bulgular tam olarak bu yüzden değerli.)

## B-007 · Eşikler KODDA sabitti — plan-motor doktrini ihlali (düzeltildi)
`MB-04`'ün 60 cm bandı `lib/kural.mjs:78`'de, pencere bandının 40 cm'i `:154`'te **kodda sabitti**.
Oysa kuralın tüm varlık sebebi "eşikler motor kodunda YAŞAMAZ, kural-seti verisinden gelir".
Kural JSON'u "sayı taşımıyor" görünüyordu ama sayı vardı — sadece görünmez yerdeydi.
→ `bant_cm` alanı kural verisine taşındı. Motor artık kuralda `bant_cm` yoksa **RC 3 verir ve
eşiği UYDURMAZ**: `kural-seti: MB-04-aciklik-onu "bant_cm" taşımıyor — eşik motorda uydurulamaz`.
→ Kapı-testi: `eşik kodda uydurulamaz (bant_cm yok)` + dosya-yazılmadı kapısı.

## B-008 · Katalogdaki 72 `temiz_alan_cm` sayısı ÖLÜ VERİYDİ (düzeltildi)
`lib/geo.mjs → temizAlanlaBuyut()` tanımlıydı ama **hiçbir yerden çağrılmıyordu**. Yani katalogdaki
her mobilyanın "yanında/önünde şu kadar boşluk kalsın" beyanı yerleşimi hiç etkilemiyordu —
veri duruyordu, iş görmüyordu. Bu, "veri-sürümlü motor" iddiasını sessizce boşa çıkarıyordu.
→ `konforCezasi`'na bağlandı (ELEME değil, skor cezası — sayılar kaynağa bağlanmadığı için).
→ Ölçülen kanıt (yatağın 60 cm yan payına komodin sokulduğunda):
```
ceza: 1.80
notlar: [ "sirkülasyon dar (0 cm < 60): yatak ↔ komodin",
          "yatak temiz-alan payına komodin giriyor",
          "komodin temiz-alan payına yatak giriyor" ]
```
→ Kapı-testi [5] bunu her koşuda ölçer: ceza üretmezse **ÖLÜ VERİ** diye kırmızı verir.
→ Not: mevcut en iyi yerleşim zaten payları koruduğu için demo çıktısı DEĞİŞMEDİ. Düzeltme
   "sonucu güzelleştirmedi", **iddiayı doğru kıldı** — fark budur.

## B-009 · `MB-K-04` YANLIŞ mevzuat maddesi gösteriyordu (düzeltildi)
Pencere önü kalemi `aday_kaynaklar` alanında "PAİY md.28 (doğrudan ışık)" diyordu. Araştırma
firsthand baktı: ilgili madde **md.32/(1)** ve **o madde pencere önünü düzenlemiyor**.
→ Yanlış atıf kaldırıldı, yerine ne olduğu ve neden yanlış olduğu yazıldı.
   Yanlış atıf taşımak, kaynaksızlıktan daha kötüdür: doğrulanmış görünür.

## K-008 · v0.3.0 tam kapı koşusu
```
geçen: 29 · kalan: 0
SONUC: GECTI
```

---

# v0.4.0 · Sahiplik devri + katalog kaynak kapısı (2026-08-06 · Sultan kararı)

## Karar
Yerleştirici + renk/çizim **PERGEL'e devredildi**; kural-seti, ölçen kod ve öz-denetim
sınav tarafında kaldı. Sebep: v0.1.0'da hem sınavı hem cevabı MEDDAH yazmıştı — PERGEL'in var
olma sebebi olan durumun ta kendisi (`_agents/PERGEL/AGENT.md:23-40`).

**Renk neden üretici tarafında:** kuvvetler ayrılığı yalnız *sınavı olan* işlerde anlamlıdır.
Renk doğru/yanlış diye ölçülmez — zevk ve marka işidir. Sınavı olmayan işi üreticiye vermek
ayrılığı bozmaz. Öz-denetim ise sınavdır (çizimi ölçer) → üretici tarafında OLAMAZ.

## K-009 · Katalog kaynak kapısı
Katalog "masum veri" gibi durur ama sınavın gizli parçasıdır. Kapı ölçüldü:
```
$ node -e '... katalogYukle("fixtures/kaynaksiz-katalog.json", ...)'
✓ reddedildi: katalog: cift-yatak-160 kaynak beyanı taşımıyor — ölçü kaynaksız kabul edilmez

$ node -e '... katalogYukle("katalog/mobilya.json", ...)'
✓ kabul: 18 kalem, hepsi kaynaklı
```
18 kalemin hepsi `kademe: "beyan"` ile işaretlendi — *TR piyasasında yaygın ölçü, dış kaynağa
bağlanmadı*. Yükseltme kademeleri: `olculdu` · `standart`. Terfi layiha L02 kapsamında.

**REDDEDİLEN alternatif:** kataloğu SEYYAH'a devretmek. Gerekçe: SEYYAH reklam hattının
kaynak-bulucusudur; ona mobilya ölçüsü araştırtmak iki ilgisiz alanı birbirine bağlardı —
oysa açık olan mimari soru tam olarak onları AYIRMAK. Rol yerine **alan** eklendi
(araştırmanın kendi cümlesi: *"bu bir rolü değil, bir sürüm alanını hak eder"*).

## K-010 · v0.4.0 tam kapı koşusu
```
geçen: 30 · kalan: 0
SONUC: GECTI
```

---

# v0.5.0 · Granülerlik araştırmasının bulduğu iki açık (2026-08-06)

Bağımsız araştırma (`_agents/spec/yetenek-granulerligi-DESIGN.md`) sahiplik matrisinde iki
KIRMIZI açık buldu. İkisi de gerçekti ve kapatıldı.

## B-010 · Kaynak alanı hileyi tek başına kapatmıyordu (AÇIK-2 · düzeltildi)
v0.4.0'ın katalog kaynak kapısı **yetersizdi**: `kaynak.metin` serbest metindir, ölçüyü kırpan
yanına inandırıcı bir gerekçe yazıp geçebilir. Araştırmanın tespiti aynen: *"kaynak alanı + lint
(K1) tek başına yetmez → kural-setinde asgari_boyut_cm bandı (K3) ile birlikte."*
→ `kural-seti/mobilya-TR.json → katalog_bandi.asgari_boyut_cm` eklendi. Bant **sınav
tarafındadır**: üretici (PERGEL) o dosyaya dokunamaz. Kaynak metnine değil **sayıya** bakar.
→ Ölçülen hile senaryosu (`fixtures/hile-uret.mjs` — yatak kırpılır VE kaynak metni de
inandırıcı biçimde güncellenir):
```
$ node fixtures/hile-uret.mjs
hile fixture: cift-yatak-160 → 140x190, kaynak metni de degistirildi

$ node -e '... katalogYukle("fixtures/kirpilmis-katalog.json", ..., kuralSeti)'
✓ reddedildi: katalog: cift-yatak-160 ölçüsü asgari bandın ALTINDA — 140×190 < 150×190.
  Sığdırmak için ölçü kırpılamaz; bant kural-setindedir ve üretici tarafından değiştirilemez.
```
→ Kapı-testi: `asgari boyut bandı`. **Not:** git-diff'e güvenmek işe yaramazdı — araştırmanın
doğru tespiti, `plan-*` dizinleri git deposu DEĞİL (ortak mount).

## B-011 · Öz-denetimde metin taşması kapısı YOKTU (AÇIK-1 · düzeltildi)
`lib/oz-denetim.mjs` "sınav tarafı" sayılmıştı ama sınavın kendisi eksikti: metin taşmasını
denetlemiyordu. plan-motor'da bu kapı VAR (`render-denetle.mjs`). Kanıt: **B-006 tam bu
sınıftandı ve kapıyla değil GÖZLE yakalandı** — kapı olsaydı ilk koşuda düşerdi.
→ Öz-denetim artık çizilen etiketi SVG'den okuyup **yeniden ölçüyor** ve odasının genişliğiyle
karşılaştırıyor. Üreticinin kendi sığdırmasına güvenmez, çıktının kendisini ölçer.
→ Ölçüm tahmindir (±%8) → **uyarı**, fail-closed değil (plan-motor'un aynı gerekçesi).

## Araştırmanın kabul edilen ama UYGULANMAYAN önerisi
*plan-motor'a additive `svg-denetle` alt-komutu ekle, dekor kendi kaba `sigdir` kopyasını
emekliye ayırsın.* Doğru bir öneri — plan-motor'un gerçek DejaVu advance tablosu (`metin-olc.mjs`)
benim tek-katsayılı tahminimden iyi. **Yapılmadı** çünkü plan-motor'u SEDİR canlı kullanıyor
(`DEVIR.md`) ve o pakete dokunmak ayrı bir karar. Layiha L02'ye borç olarak yazıldı.

## K-011 · v0.5.0 tam kapı koşusu
```
geçen: 32 · kalan: 0
SONUC: GECTI
```

---

# v0.6.0 · Determinizm iddiası delikti (2026-08-06)

## B-012 · "Aynı girdi → aynı sha256" yalnız BAYT-aynı girdi için doğruydu (düzeltildi)

Dış-dünya taraması (`_agents/spec/dis-dunya-taramasi-DESIGN.md`), `pascalorg/editor` PR #596'nın
(2026-08-05) *"eşdeğer ama ters sıralı girdi"* determinizm hatasını düzelttiğini buldu ve **aynısını
bizde denedi**. Bulgu firsthand doğrulandı:

```
$ node fixtures/esdeger-girdi-uret.mjs
eşdeğer fixture: duvarlar/odalar/açıklıklar/noktalar sırası ters, geometri AYNI

$ (iki modeli döşe, yerleşimleri karşılaştır)
aynı mı: HAYIR
fark (1 mobilya):
  orijinal: ebeveyn_banyo:kuvet:619,230,75,170,2
  eşdeğer : ebeveyn_banyo:kuvet:530,319,170,75,3
```

Geometrik olarak **birebir aynı** daire; yalnız `duvarlar`/`odalar`/`acikliklar` dizileri ters.
Küvet başka duvara geçiyor. Yani motorun en güçlü iddiası — determinizm — **kapı-testinin ölçtüğü
kadar dardı**: test yalnız bayt-aynı girdiyi iki kez koşuyordu, sınıfın yarısını hiç ölçmüyordu.

**Kök sebep:** adaylar `baglam.duvarlar` dizisinin SIRASIYLA üretiliyor, skor eşitliğinde
"ilk gelen kazanır" uygulanıyordu. Sıralama girdiden geliyordu, motordan değil.

**Düzeltme (üç yerde kanonik sıra):**
1. `lib/yerlesim.mjs → kanonikSirala()` — adaylar (x, y, g, d, yön, id) ile sıralanır; eşitlik
   artık girdi-sırasından bağımsız çözülür.
2. `plaMobilyala` — çıktı yerleşimleri (oda, x, y, mobilya) ile sıralanır.
3. `lib/dekor-svg.mjs` — çizimden önce oda/duvar/açıklık/nokta **id'ye göre** sıralanır; eşdeğer
   model aynı resmi aynı BAYT sırasıyla üretir.

**Ölçülen sonuç:**
```
adaylar (yerleşim) eşit: EVET
SVG sha256 eşit: EVET
farklı alanlar: model_ref   ← beklenen (dosya hangi modelden geldiğini kaydeder)
```

**Kapı-testine kalıcı bağlandı** ([3] bölümü): `eşdeğer girdi → aynı yerleşim` +
`eşdeğer girdi → aynı çizim`. Bir daha sessizce delinemez.

> **Ders:** bir değişmezi ilan etmek onu korumaz; **onu ölçen kapı** korur. Ve kapı, değişmezin
> yalnız kolay yarısını ölçüyorsa, ilan edilen şey ile korunan şey aynı değildir.

## K-012 · v0.6.0 tam kapı koşusu
```
geçen: 34 · kalan: 0
SONUC: GECTI
```
