---
name: gorsel-yon
type: workflow
version: 0.4.0
description: >
  Üretilmiş görselle YÖN ARAYIŞI — kanıt üretmez. Nova/mimarlık sitesi gibi iddiası
  "gerçek iş" olan yüzeylerde, üretilmiş görselin nereye girip nereye giremeyeceğini
  KODLA zorlar. "görsel yön · kompozisyon denemesi · zemin dokusu · geçiş dili"
  tetiğinde. Higgsfield hattı; varsayılan KURU-KOŞUM (kredi harcamaz).
---

# gorsel-yon — üretilmiş görsel nereye girer, nereye giremez

## Niçin var

Nova sitesinin tüm iddiası **gerçek iş**. Üretilmiş bir görsel o iddiayı taşıyamaz —
Sultan'ın dairesinin gerçek fotoğrafı ve gerçek çizimi yerine geçemez. Ama yön aramak,
zemin dokusu denemek ve geçiş dilini göstermek üretilmiş görselle **yapılabilir**.

Sorun şuydu: bu ayrım bir belgede yazılıydı, hiçbir kapıda koşmuyordu.

## 🔴 SINIR — ölçüt "üretilmiş mi" DEĞİL, "KANIT konumunda mı"

Bu ayrım aracın çekirdeğidir ve **kodda yaşar**, belgede değil.

> Bir görselin yanında **hafta · çizim · karar** duruyorsa, o görsel **kanıttır** →
> gerçek olmak **zorundadır**. İddia taşımayan yüzey (zemin, geçiş, boşluk) üretilmiş olabilir.

Bu ölçüt "render yasak"tan daha keskin ve **sınanabilir**: zarar üretilmiş piksel değil,
**kanıt yerinde duran üretilmiş görseldir**.

| İzinli alan | Ne demek |
|---|---|
| `yon-arayisi` | kompozisyon/ışık denemesi — **siteye girmez**, atılacak taslak |
| `doku-zemin` | içerik iddiası taşımayan soyut yüzey |
| `hareket-dili` | geçişin nasıl olacağını **gösteren** örnek, içerik değil |

Bu üçünün dışı **reddedilir** (kapalı küme, `--kullanim` zorunlu).

## DÖRT kapı — hepsi fail-closed

🔴 **Dördüncü kapı 2026-10-06'da eklendi ve niçini ölçülmüş bir kaçaktır.** İlk üç kapı
**ÜRETİM** tarafını süzüyordu: ne isteyeceğimizi. Ama **hazır gelen dosya** bu kapıların
hiçbirinden geçmiyordu — ve kaçak tam oradan oldu: 62 kare başka bir araçla üretilip
köprüye düştü, vitrine gidiyordu. Üç ölçüm (iki ajan + ben) "bu dosyalarda meta yok,
kökü belirsiz" dedi; gerçekte **hepsinde üreticinin köken kutusu** vardı ve
`trainedAlgorithmicMedia` diyordu. Yanlış kümede arıyorduk: köken kaydı Exif/metin
parçalarında **değil**, JUMBF kutusunda (PNG `caBX` · JPEG APP11 · WebP `C2PA`).


1. **Kullanım alanı kapısı** — kapalı küme dışı → `rc=1`
2. **Kanıt-konumu kapısı** — istemde `vaka·proje·şantiye·çizim·daire·mahal·portfolyo·referans`
   geçerse → `rc=1`. Vaka görselleri gerçek olmak zorunda.
3. **B3 kapısı** — `lüks·altın·mermer·render·3d·fotogerçekçi·stok` → `rc=1`
   (Sultan'ın yasakladığı yön)
4. **Köken kapısı (`koken`)** — DOSYANIN kendi beyanını okur, beyanımıza bakmaz:
   - dosya `trainedAlgorithmicMedia` diyor **ve** yüzey iddia taşıyor (`kanit·vitrin·portfolyo·referans`) → `rc=1`
   - dosya ile **beyan çelişiyorsa** → `rc=1`, ve `celisen_taraf` yazılır:
     **insan beyanı SORULUR, ajan beyanı DÜZELTİLİR** (ikisi aynı ağırlıkta değil; öneri: KALFA/Nova)
   - okuyucu **pozitif kontrolü** geçemezse → `rc=3` ÖLÇEMEDİM. Ölçemediğine temiz demez.
   - hüküm YALNIZ köken kutusunun GÖVDESİNDEN çıkar; kutu dışında geçen beyan metni
     `parca_disi_iz` olarak **kayda geçer ama hüküm vermez** (sahte-pozitif kapısı).
   - biçimi ayrıştırılamayan dosya `okunamadi`'dır — "temiz" değil.
   - **tanımadığım parça** varken bilinen hiçbir kayıt yoksa sınıf `belirsiz-tasiyici`'dir,
     `hic-yok` DEĞİL: bilmediğim bir taşıyıcıyı "köken yok" diye sınıflamak sözlük tuzağının
     ikinci yüzüdür (bağımsız göz tur-2 bunu yakaladı).

🔴 **İMZA KAPISI — İKİ KİP, HANGİSİNDE OLDUĞUNU HER ZAMAN SÖYLER:**

| kip | şart | ne yapar | kayıt |
|---|---|---|---|
| **AÇIK** | `c2pa` kütüphanesi var | manifest **yapısal** okunur: imza + sertifika zinciri doğrulanır, `digitalSourceType` eylem iddiasının İÇİNDEN alınır (bayt arama DEĞİL) | `imza_dogrulandi: evet` + verenin adı |
| **KAPALI** | kütüphane yok ya da `KOKEN_IMZA=kapali` | kutu-gövdesi okuyucusuna düşer; iddia `digitalSourceType` anahtarına **bağlı** olmak zorunda (serbest geçen sözcük iddia sayılmaz) | `imza_dogrulandi: olculemedi` |

🔴 **Sessiz düşüş yasak:** kip her koşuda çıktıya basılır ve kayda geçer. Kipin hükme etkisi
**asimetriktir** ve niçini zarar yönündedir:
- *"üretilmiş → iddia taşıyan yüzeye giremez"* → imza doğrulanmasa da **keser** (temkinli taraf).
- *çelişki* ("dosya şunu diyor, insan bunu dedi") → **yalnız imza doğrulanmışsa keser.**
  Doğrulanmamış bir beyanla bir insanı yanlış-beyanla suçlamak zararın ağır tarafıdır; o hâlde
  uyarı basılır ve "sorulmalı" denir.

**İsteğe bağlı bağımlılık:** `pip install --user c2pa-python` (imzalı kip). Kurulu değilse araç
çalışır ama imzayı ölçmediğini söyler. Sınavın imzalı yüzü `openssl` + `c2pa` ister; ikisi yoksa
o üç kapı **ATLANDI** basar — "geçti" demez.

**Alanlar** (kayda giren): `tur` · `tur_kaynagi` (dosyadan|beyandan) · `imza_dogrulandi` ·
`parca_disi_iz` · `bicim` · `imza_kipi` · `okuma_yolu` · `koken_durumu`
(koken-kutusu-var|meta-var|belirsiz-tasiyici|hic-yok|okunamadi) · `kanit_olabilir` · `celisen_taraf` · artı `ikizlik`
(küme içi ve kümeler arası AYRI sayılır).

**Yön çiti:** her isteme Sultan'ın seçtiği yön (B1/B4/B5) otomatik eklenir ve
**çıkarılamaz** — yumuşak yayılı gündüz ışığı · doğal ahşap + mat antrasit · süs yok ·
telefonda gece okunabilir.

## Kullanım

```
gorsel-yon.sh dogrula                       # anahtar geçerli mi — KREDİ HARCAMAZ
gorsel-yon.sh kullanimlar                   # izinli alanlar
gorsel-yon.sh uret --kullanim doku-zemin --istem "..."          # KURU-KOŞUM
gorsel-yon.sh uret --kullanim doku-zemin --istem "..." --uygula # gerçek üretim (kredi harcar)
```

🔴 **Varsayılan kuru-koşum.** `--uygula` verilmedikçe istek gönderilmez, kredi harcanmaz.

## Ölçülmüş tuzaklar (tekrar düşmemek için)

- **Uç adresi:** taban `platform.higgsfield.ai/<yol>` — **`/v1` ÖNEKİ YOKTUR.**
  `/v1/...` denenirse her şey **405** döner ve "anahtar bozuk" sanılır. Kök neden
  anahtar değil **adrestir** (2026-08-23'te bu tuzağa düşüldü).
- **Anahtar kasada:** `secret/nexus/HIGGSFIELD_API_KEY` (openbao). `.env`'de **yok**.
  Araç `vault-cek get` ile çeker; değer **stdout'a basılmaz**.
- **Kredi-harcamayan sınama:** `GET /requests/<uydurma-uuid>/status` →
  anahtarLA **404**, anahtarSIZ **401**. **Farkı** kimliğin kabul edildiğini kanıtlar.
  Negatif-kontrollü; ölçüm için kredi harcamak gerekmez.

## Sınırlar / dürüstlük

- Bu araç **çarpıcılık üretmez**, çarpıcılık ararken sınırı korur.
- Higgsfield **kıtlık sorununu çözmez**: site tek tamamlanmış işle açılacak. Üretilmiş
  görsel o boşluğu dolduramaz ve doldurmamalı — boşluğun dürüst tasarımı ayrı iştir.
- `dogrula` uç sessizse **rc=3 (ölçemedim)** döner, "anahtar bozuk" DEMEZ.

## Sürüm notları

- **0.1.1 (2026-08-25) — ilk gerçek çağrı ONARILDI.** v0.1.0 gövdeyi `{"params":{"prompt":…,"quality":"1080p"}}`
  diye gönderiyordu; uç `prompt`'u **kökte** ister ve `quality` diye bir alan **yoktur** (sessizce yok sayılır,
  doğrusu `resolution`). Yani `uret --uygula` her çağrıda **422** alacaktı. Fark edilmemişti çünkü araç
  kurulduğu günden beri bir kez bile `--uygula` ile koşulmadı — [[feedback_test_var_kapida_degil]] deseni.
  Kanıt (kredi harcamayan negatif-kontrollü prob, 2026-08-25):
  `{"params":{"prompt":"x"}}` → 422 `loc=["body","prompt"] "Field required"` ·
  aracın YENİ gövdesi yalnız `resolution` kasten bozulunca 422 verdi → öbür alanların hepsi kabul edildi.
  ⚠️ Dürüst sınır: **gerçek bir görsel üretilmedi** (kredi harcanmayacaktı diyemem) — doğrulama
  şema-katmanında bitti; ilk gerçek üretimin kalitesi hâlâ ölçülmedi.
  Üç fail-closed kapı (kullanım alanı · kanıt-konumu · B3 yasak listesi) onarımdan sonra yeniden sınandı: 0/1/1.

- **0.2.0 (2026-08-25) — GAZ KATMANI: araç ilk kez fiilen görsel getiriyor.**
  v0.1 yalnız istek **gönderiyordu**. Uç asenkron çalışır (`{"status":"queued","request_id":…}`);
  bekleyen/indiren hiçbir şey yoktu → üretilen görsele **hiçbir zaman ulaşılamazdı**. Yani onarılan
  422'nin arkasında ikinci bir sessiz duvar varmış. Eklenenler:
  - `bekle <istek-kimliği> [--indir <dizin>] [--azami <sn>]` — durumu yoklar, biter bitmez adresleri
    çıkarır ve indirir. **Süre dolarsa "düştü" DEMEZ** (RC=3, "hâlâ sürüyor olabilir").
  - `defter` — her GERÇEK çağrı `~/.claude/gorsel-yon-defteri.jsonl`'e düşer (alan · adet · istek ·
    durum · fiilen gelen kare). 🔴 **Adet sayar, lira saymaz** — birim kredi maliyeti ölçülemedi.
  - `--sayi 4` artık gerçekten çalışıyor (`batch_size`), `--oran` eklendi (varsayılan 16:9).
  - Kuru-koşum deftere YAZMAZ: kredi harcanmayan çağrı harcama kaydı üretmez.

  **Ölçülmüş ders — soyut istem konu uyduruyor:** *"mat sıva yüzey, dokulu, içerik yok"* denildiğinde
  model boş bir yüzey değil, **ahşap masada bir cihaz** üretti. Soul bir sahne/ürün modelidir; konusuz
  istemi konusuz bırakmaz. Panzehir ölçüldü ve tuttu: istemi **sahneye çıpala** ("empty interior
  corner, bare plaster wall meeting pale oak floor, raking daylight… absolutely no objects no
  furniture no people") → 4/4 kare temiz geldi. Kanıt: istek `8c3fba2b…`, 4 kare, hepsi boş mekân.

## 0.3.0 (2026-08-27 · KATLAMA günü — MİHMANDAR talebi, Sultan-izinli)
- **Yeni kullanım-alanı `kesif-katalog`:** Nova müşteri-keşif katalog matrisi (stil×oda×palet).
  Çit: her kare HER YERDE "ilham/yön" rozetli · kanıt konumuna geçmez · site-yüzeyine sızmaz ·
  karar-kaydında alan tipi ayrık (kanıt-foto ≠ ilham-referans). B3-SİTE-yasağı (lüks/klasik vb.)
  katalog stillerine uygulanmaz — o yasak SİTENİN estetiği içindir, müşteri kataloğu değil.
- **Türkçe-imla deliği kapandı:** yasak-desen artık `şantiye/çizim/öncesi/sonrası…` Türkçe-karakterli
  biçimleri de yakalar (MÜZEYYİN bulgusu + MİHMANDAR kutu-içi probu; negatif-test rc=1 kanıtlı).
- **Anahtar-sırası onarımı:** `_anahtar` önce eldeki `cortex-access.env`i okur; kasa-çekimi
  başarısız diye eldeki anahtar artık çöpe gitmez (Nova vakası: anahtar aynada VARDI, get-fail
  her şeyi düşürüyordu).

## 0.3.1 (2026-08-27 · MİHMANDAR pilot-dönüşü, aynı gün)
- **Pürüz-1 kapandı:** B3-site-yasağı artık KODDA da `kesif-katalog`a uygulanmıyor (tarif-kod
  uyumu; kanıt: katalog+altın rc=0 · site+altın rc=1, iki yönlü çıplak-rc).
- **Pürüz-2 kapandı:** yön-çiti alan-koşullu — site-alanları Sultan-yönünü aynen korur;
  kesif-katalog stil-slotunu serbest bırakan nötr kalite-çiti alır (endüstriyel-hücre
  sulanması ölçülmüştü).

## Kanıt
`bash scripts/koken.test.sh` → **29 kapı**, hermetik (gerçek karelere dokunmaz), çift yönlü
fikstürlü. Beş mutasyon kapısı: PNG kolu körleştirilince K13, JPEG kolu körleştirilince K18, kutu-dışı
iz kaydı susturulunca K19 → `rc=3 ÖLÇEMEDİM`; imza-şartı kaldırılınca K26 doğrulanmamış
çelişkinin RED'e döndüğünü gösterir; yapısal kol koparılınca K27 imzalı dosyanın
`olculemedi`ye düştüğünü gösterir (kol süs değil).
**İmzalı yüz GERÇEK:** sınav kendi sertifikasını `openssl` ile üretir ve `c2pa` ile gerçekten
imzalı bir kare yazar (ağa çıkmaz) — K23 imzayı doğrular, K24 doğrulanmış çelişkinin kestiğini,
K25 imzalı üretilmiş karenin iddia yüzeyine giremediğini ölçer. Yani "temiz" demeyen fail-closed
davranış süs değil, ölçülmüştür. Üç biçim de GERÇEK zincirle sınanır (PNG parça · JPEG APP11
segmenti · WebP RIFF kutusu) — kılık verilmiş bayt dizisiyle değil. K3/K5 tautoloji kapıları: üretilmiş kare
iddiasız yüzeye **girer**, uyuşan beyan **geçer** — yoksa kapı "her şeye kırmızı" olurdu.

**Canlı kalibrasyon (ilk gerçek koşu, 2026-10-06):** 62 kare · 46 ayrı görüntü · küme içi
ikiz 16 · kümeler arası 0 — üç bağımsız ölçümle birebir. Hepsinde köken kutusu
var ve `trainedAlgorithmicMedia` diyor; üretici `gpt-image`, filigran var. Beyan
`gercek+iyilestirme` verilince çelişkilerin **tamamı** yakalandı (`rc=1`), çelişen taraf
`insan` işaretlendi — yani Sultan'a sorulacak, düzeltilmeyecek. (Sultan'ın o beyanı fiilen
22 karelik alt kümeye aitti; kümenin tamamına uygulandığında 62/62 çelişki döner.)

**Sıkı okuyucuyla yeniden ölçüldü (tur-2/tur-3, şema şartı + imza doğrulaması eklendikten
SONRA):** aynı 62 kare · 46 ayrı görüntü · küme içi 16 · kümeler arası 0 — rakamlar birebir
aynı kaldı, yani sıkılaştırma gerçek pozitifleri düşürmedi. Üstelik artık **imza ve sertifika
zinciri de doğrulanıyor**: 62/62 `Valid`, veren **OpenAI OpCo, LLC**, iddia `c2pa.actions.v2`
eyleminin içinden okundu. Yani "dosyanın kendi beyanı" cümlesi artık ölçülmüş bir güven
sınırına dayanıyor, anahtar sözcüğe değil.
