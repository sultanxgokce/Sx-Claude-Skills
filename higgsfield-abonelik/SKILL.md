---
name: higgsfield-abonelik
type: tool
version: 1.0.0
description: Higgsfield ULTRA aboneliğinden üretim yapar (API anahtarı DEĞİL, CLI/OAuth yolu). 31 görsel + 30 video modeli — API yolunda 404 dönen seedance_2_5, nano_banana_pro, flux_2, gpt_image_2 dahil. Krediyi göstergeden değil DEFTERDEN okur, üretimden önce fiyat sorar, kredi tavanı fail-closed'dur. "higgsfield abonelik · abonelikten üret · kredi ne kadar kaldı · seedance 2.5 · hangi modeller var · CLI yolu" tetiğinde.
allowed-tools: Bash, Read
---

# higgsfield-abonelik — abonelik cüzdanından üretim

> **Bu skill neden var:** Higgsfield'a iki ayrı kapıdan girilir ve ikisi **ayrı cüzdandan**
> yer. API anahtarı yolu bir kredi havuzunu, Ultra aboneliği bambaşka bir havuzu kullanır.
> Aylardır aboneliğe ajandan erişilemiyordu; resmi kapı **Higgsfield CLI**'dır ve
> kullanım şartlarının 11.13'ü bu istemcileri açıkça meşru sayar — gri alan değil.
> Ölçülmüş fark: API yolunda **2** görsel modeli, CLI yolunda **31**.

## 🔴 ZORUNLU KALİTE LİSTESİ — her mekân karesinde TEK TEK sorulur

*(Sultan direktifi 2026-09-06. Bu bölüm tavsiye değil **kapı**dır: bir kare teslim
edilmeden önce aşağıdaki dokuz kalemin hepsi tek tek sorulmuş olmalı.)*

**Niçin zorunlu:** üç tur boyunca "dağınıklığı kaldır" diye baktım ve her turda Sultan
bir eksik daha gösterdi. Kusur modelde değildi — **benim sayımımdaydı**. Göz "iyi
görünüyor" der ve durur; **liste durmaz**. Sultan on saniyede dört bölge işaretliyor,
çünkü bakmıyor **arıyor**.

| # | Kalem | Ne sorulur |
|---|---|---|
| 1 | **Kadraj ve perspektif** | 🔴 **İKİ AYRI KUSUR, biri ötekini düzeltmez.** (a) **Balık gözü** — merceğin eğriliği, düz çizgi yay gibi çıkar → `lenscorrection`. (b) **Keystone** — kameranın eğikliği, **düşey çizgiler paralel kalmaz** → `perspective`. İç mekânda **düşeyin düşey olması netlikten de ışıktan da önce gelir**; göz önce onu fark eder. `kadraj-duzelt.sh --k1 <balıkgözü> --dikey <keystone>` |
| 2 | **Işık** | Pencere patlamış mı, köşeler çökmüş mü, renk sıcaklığı tutarlı mı? |
| 3 | **Aydınlatma armatürü** | Çıplak/uyumsuz ampul var mı? Avize eksik mi? *(→ §sınır)* |
| 4 | **Zemin kaplaması / halı** | Halı desen ve renk olarak mekânla uyumlu mu? Kırışık/eğri mi? |
| 5 | **Tekstil** | Perde, örtü, kırlent düzgün mü? Örtü sarkık/leke var mı? |
| 6 | **Mobilya oturuşu** | Ankastre boşluğuna tam oturmuş mu (buzdolabı/fırın)? Kapaklar kapalı mı? Koltuk açık kalmış mı? |
| 7 | **Görünen eşya** | Şişe, kablo, priz, etiket, mıknatıs, kişisel eşya, cam dolap içi görünen yığın |
| 8 | **Kişi ve kişisel veri** | Yansıma dahil kişi · belge · telefon numarası · plaka |
| 9 | **Seri tutarlılığı** | Bu kare setteki ötekilerle aynı dilde mi? Tek başına kalmış/kopuk duran var mı? |

**Yöntem (pazarlıksız):** kareyi **çeyreklere böl**, her çeyrekte dokuz kalemi tek tek sor,
**bulduklarını yaz**, sonra prompt kur. Küçük resimden onay **YASAK** — 600 pikselde şampuan
şişesi görünmez ve ben bunu iki kez öğrendim.

### 🔴 SINIR — neyin değiştirilebileceği ÜRÜNE göre değişir

Aynı düzeltme bir üründe dürüst, ötekinde sahtekârdır. Ayrımı **ne iddia ettiğimiz** kurar:

| | **Emlak tadilat görseli** | **Usta portföyü (Armut)** |
|---|---|---|
| İddia | *"böyle görünebilir"* — öneri, markörle beyan edilir | *"bu işi ben yaptım"* |
| Halı · örtü · kırlent · taşınabilir eşya | ✅ değiştirilebilir | ✅ değiştirilebilir (ustanın işi değil) |
| Kadraj · ışık · perspektif | ✅ serbest | ✅ serbest (fotoğrafçılık) |
| Duvar rengi · fayans · parke · dolap | ✅ değiştirilebilir (markörlü) | 🔴 **ASLA** — teslim edilen işin kendisi |
| **Aydınlatma armatürü / avize** | ✅ değiştirilebilir | 🔴 **YALNIZ mevcut olan iyileştirilir** — olmayan bir avize **eklenemez**, çünkü montajı elektrik işidir ve **yapılmamış bir işi iddia eder** |

🔴 **BİR NESNEYİ KALDIRIRKEN TAŞIYICISINI DA KAYBEDERSİN** *(2026-09-06, ölçüldü)*
*"Sandalyelerdeki örtüleri kaldır"* dedim; model **sandalyeyi de kaldırdı** ve yerinde
boşluk bıraktı. Model "üstündeki şey" ile "altındaki şey"i ayırmıyor.
**Çözüm:** koruyacağın nesneyi **sayıyla ve açıkça** yaz — *"her sandalye kalacak, aynı
sayı, aynı konum; yalnız üzerindeki giysi kalkacak"* — ve `DO NOT INCLUDE` listesine
**"removed chairs, missing furniture, empty gaps where furniture was"** ekle.
**Ve seçim kuralı:** eksik mobilya, duran bir dağınıklıktan **kötüdür**. Biri "burada
bir şey yoktu" der, öteki "burada bir şey vardı ve silindi" der. İkincisi görünür,
birincisi güven kırar.

**Şüphede kalırsan sor:** *"bu kalem müşterinin eşyası mı, benim işim mi?"*
Eşyaysa serbest, işse dokunulmaz.

## Değişmezler

**D1 · Krediyi GÖSTERGEDEN değil DEFTERDEN oku.**
`account status` üretimden sonra da eski bakiyeyi gösterebilir. İki bağımsız ölçümde
(MUAVİN merkezde, MEDDAH TELLAL'de) gösterge `3000 credits` derken defter `-1.5 spend`
diyordu. **Gerçek harcama `account transactions`'tadır.**

**D1b · 🔴 `not_enough_boost_credits` KOTA DEĞİL, GEÇİCİ MEŞGULİYETTİR.** *(2026-09-02, ölçüldü)*

Video üretimi şu hatayla reddedilebilir:
```
{"error_type":"not_enough_boost_credits","billing_period":"monthly","plan_type":"ultra"}
```
**Bu "krediniz bitti" DEMEK DEĞİLDİR.** Ölçüldü: hata alındığı anda hesapta
**2.996,5 kredi** vardı ve **aynı iş hiçbir şey değiştirmeden yeniden denenince ÜRETİLDİ**.

Adın kendisi ipucu: defterdeki satır **"*Concurrent* Boost Credits"** — yani eşzamanlı
iş kapasitesi. Aynı hesapta başka bir ajan/oturum iş koşuyorsa (bizde HAYALİ koşuyordu)
video isteği bu kapasiteye takılıp reddedilebilir.

🔴 **DOĞRU TEPKİ: ÖNCE YENİDEN DENE.** Ben bunu yapmadım — tek bir hata mesajından
"üçüncü bir havuz var ve tükendi" diye bir teori kurdum, skill'e yazdım, MUAVİN'e
mektup yazdım ve **Sultan'ı gereksiz bir satın almaya yönlendirdim**. Hata mesajının
*kelimesi* ("not enough … credits") kota gibi okunuyordu; ölçüm ise tam tersini söyledi.
**Bir hata mesajının söylediği şey, olan biten şey değildir** — ikisi arasındaki farkı
yalnız ikinci bir deneme gösterir.

**Bakiyeyi öğrenmenin doğru yolu** (CLI'nin `account status`'u güvenilmez, defter
aritmetiği yanıltır): Higgsfield hesap ucu — `balance` → `{"credits":2996.5}`.

**D2 · Bir karşılaştırma turunun İÇİNDE yol değiştirme.** *(Sultan şartı)*
Aynı turda bazı kareleri API'den, bazılarını abonelikten üretirsen ölçüm kirlenir; elde
ettiğin fark sağlayıcı farkı mı yol farkı mı, ayırt edilemez. Yol **tur başında sabitlenir**
ve rapora yazılır. Serbest kullanımda (deneme, keşif, müşteri işi) kısıt yok.

**D3 · Kredi bir bütçedir — ikinci para birimi ikinci kapı ister.**
Abonelik kredisinin marjinal dolar maliyeti gerçekten sıfırdır (abonelik ödendi,
kullanılmayan kredi ay sonunda yanar). Ama "0 dolar" beyan etmek USD tavanını **etkisiz**
bırakır ve **tavansız bir yol, tavanlı bir yoldan tehlikelidir**. Bu yüzden boğaz ayrıca
`bogaz_kredi_tavani` sorar; varsayılan **50 kredi** ve fail-closed.

**D4 · Kanıt durum kodu değil, çıktının varlığıdır.**
`--wait` başarıyla dönebilir ve elde görsel olmayabilir. Adaptör dosyayı arar; yoksa kırmızı.

**D5 · Jeton bir OAuth jetonudur, API anahtarı değil.**
Süresi dolarsa **kendi başına yenileyemezsin** — Sultan'ın tarayıcısından geçer.
Koparsa MUAVİN'e yaz, uydurma.

## Kurulum (bir kez)

```bash
npm i -g @higgsfield/cli
bash /config/.claude/skills/vault-cek/scripts/vault-cek.sh get HIGGSFIELD_CLI_KIMLIK
# 🔴 jeton ÇOK SATIRLI JSON'dur; kabuk env dosyasında 8 satıra bölünür.
#    Satır-tabanlı okuyucu yalnız ilk satırı ("{") alır ve 1 KARAKTER döner.
#    Aşağıdaki kurucu satırları birleştirip parmak iziyle doğrular.
bash /config/.claude/skills/higgsfield-abonelik/scripts/higgsfield-kimlik-kur.sh
higgsfield workspace list && higgsfield workspace set <id>
higgsfield account status        # yeşil: "… ultra plan, 3000 credits"
```

## Günlük kullanım

```bash
higgsfield model list                       # 85 model: 31 image · 30 video · 14 3d · 6 audio
higgsfield model get <model>                # kabul edilen alanlar — BAYRAK UYDURMA, bunu oku
higgsfield generate cost <model> --prompt … # KREDİ HARCAMAZ, üretimden önce sor
higgsfield generate create <model> --prompt … --image <yol> --wait
higgsfield account transactions             # GERÇEK harcama (D1)
```

🔴 **`--output` diye bir bayrak YOKTUR.** `--wait` sonuç URL'sini basar; indirmeyi çağıran
yapar. Bunu uydurup `Error: Unknown params: output` yedim — CLI zaten "hangi alanlar var"
diye sorulabilecek bir komut sunuyor (`model get`), önce onu oku.

## Paket betikleri — mutlak yoldan çağrılır

Beceri `/config/.claude/skills/higgsfield-abonelik/` altına kurulur; betikler **paketin içinde**
(`<beceri>/scripts/`) yaşar ve **mutlak yoldan** çağrılır — çalışma dizinine ya da `$CLAUDE_PROJECT_DIR`'a
bağlı değildir. *(1.0.0 · görev 3DBM27: göreli çağrı başka kutudan koşunca kırılıyordu.)*
Betikler birbirini kendi dizinleri üzerinden bulur (`dirname "${BASH_SOURCE[0]}"`); paket nereye
kurulursa kurulsun iç çağrılar çalışır.

`B=/config/.claude/skills/higgsfield-abonelik/scripts`

| Betik | Ne yapar | Ağa çıkar / kredi harcar mı |
|---|---|---|
| `bogaz.lib.sh` | kaynak alınır (`. $B/bogaz.lib.sh`): kredi tavanı `bogaz_kredi_tavani` (D3), idempotans, fail-closed defter satırı | hayır |
| `higgsfield-kimlik-kur.sh` | kasadaki OAuth jetonunu CLI'nin beklediği dosyaya kurar; bütünlüğü parmak iziyle doğrular, tutmuyorsa YAZMAZ | hayır |
| `kredi-oku.sh` | krediyi göstergeden değil DEFTERDEN okur, çelişkiyi söyler (D1); defter okunamazsa tahmin etmez, reddeder | yalnız okur (`account transactions`) |
| `hf-defter.sh` | Higgsfield harcama defterini sayfalayarak TAM okur (TSV, tek kaynak — 20-satır tavanı dersi) | yalnız okur |
| `kredi-mutabakat.sh` | Higgsfield defteri ↔ bizim defter: hangi harcama bize ait, hangisi sahipsiz | yalnız okur |
| `defter.sh` | üretim defteri: satır ekle / özet / acı-sayacı (şema: `DEFTER-SEMA.md`; yol `TELLAL_DEFTER` ile) | hayır |
| `buyut.sh` | görseli 2K/4K'ya büyütür (`bytedance_image_upscale`, zincirin sonunda bir kez) | **kredi harcar** |
| `filigran-temizle.sh` | ilan fotoğrafından filigranı/ajans logosunu kaldırır, dokunulmayan pikseli birebir korur — 🔴 promptu TELLAL'in `staging-saglayici/flux-kontext-fal.sh`'ından ister; o betik bu pakette YOK | **kredi harcar** |
| `filigran-yama.sh` | AI çıktısını YALNIZ değiştirdiği yerlerde orijinale yamalar (bölge ya da fark maskesi) | hayır (yerel) |
| `girdi-kapisi.sh` | zincire girecek görselin gerçekten fotoğraf olduğunu sınar (ekran görüntüsü giremez) | hayır |
| `kadraj-duzelt.sh` | balık gözü / perspektif / yatay düzeltme — yerel, AI yok | hayır (yerel) |
| `isik-duzelt.sh` | pozlama · patlamış parlak alan kurtarma · netlik — yerel | hayır (yerel) |
| `etiket-gom.sh` | zorunlu görünür AI-etiketini videoya gömer (RG 33297) | hayır (yerel) |
| `yuzsuz-video.sh` | yüz göstermeyen reklam videosu (ürün görseli + seslendirme + altyazı) | hayır (yerel) |
| `ffmpeg-kanit.sh` | ffmpeg "listede var" değil "gerçekten çalışıyor" ölçer | hayır |
| `paket.test.sh` | paket sınavı: kendi dizininden, ağsız, kredisiz; gerçek CLI'yi sahtesiyle gölgeler (`bash $B/paket.test.sh`) | hayır |

## Ölçülmüş fiyatlar (2026-08-28, `generate cost`)

| Model | Kredi | 3000 kredi ile |
|---|---|---|
| `text2image_soul_v2` | 0,12 | ~25.000 kare |
| `flux_2` | 1 | 3.000 |
| **`flux_kontext`** | **1,5** | 2.000 kare · **500 tadilat zinciri** |
| `nano_banana_pro` | 2 | 1.500 |
| `veo3_1_lite` | 8 | 375 video |
| `seedance_2_0_mini` | 12,5 | 240 |
| `seedance_2_0` | 22,5 | 133 |
| **`seedance_2_5`** | **32,5** | **92 video** |
| `gemini_omni` | 24 | 125 |

**Tahmin güvenilir:** `generate cost` 1,5 dedi, defter 3 çağrı için tam **−4,5** yazdı.

🔴 **"Sınırsız" bu yoldan geçmez** — Ultra'nın sınırsız kolu yalnız higgsfield.ai sitesinde
çalışır. Ajandan her üretim krediden düşer.

## TELLAL hattına nasıl bağlı

> 🔴 **Bu bölümde anılan `staging.sh`, `staging-saglayici/flux-kontext-hf.sh` ve `flux-kontext-fal.sh` BU PAKETTE YOK.**
> TELLAL'in boğaz/staging zincirine aittir ve yalnız o depoda koşar (gerekçe: `DEVIR-YOKSAY.txt`).
> Burada yalnız hattın nasıl bağlandığı anlatılır; aşağıdaki komutlar başka kutuda ÇALIŞMAZ — uydurma.

Yetenek **ayrı bir skill değil, boğazın bir adaptörü** olarak yaşar (G6 + C1: altyapıyı
kopyalama). `<TELLAL deposu>/scripts/staging-saglayici/flux-kontext-hf.sh` (bu pakette yok) — yükleme kapısı, idempotans,
tavan, markör ve defter **bedava** gelir.

```bash
# yalnız TELLAL kutusunda — staging.sh bu pakette yok
bash <TELLAL deposu>/scripts/staging.sh --girdi <foto> --is <iş> --stil salon --sinif tadilat \
  --saglayici flux-kontext-hf --tavan-kredi 10 --cikti <dizin>
```

🔴 **Prompt tek kaynaktan gelir:** `flux-kontext-fal.sh --prompt-yaz` (TELLAL zinciri, bu pakette yok). İki yol aynı promptu
kullanır; kopyalansaydı biri değişince bozulma **sessiz** olur ve iki yolun çıktısı
arasındaki fark "sağlayıcı farkı" sanılırdı — oysa prompt farkı olurdu. Karşılaştırmayı
bozan şey tam olarak budur.

**`yol` alanı elle yazılmaz:** defter satırındaki `saglayici` alanı zaten yolu taşır
(`flux-kontext-fal` ↔ `flux-kontext-hf`) ve onu **araç** yazar. Elle yazılan bir alan,
unutulduğu gün sessizce yanlış olur.

## 🔴 MODEL SEÇİMİ — ölçülmüş: `flux_kontext` GERÇEKÇİLİKTE güçlü

**Sultan'ın kendi değerlendirmesi (2026-08-31, D-003 teslimat paketine bakarak):**
> *"fotoğrafın bu şekilde gerçekçi gözükmesi cidden iyi"*

Bu bir tercih değil, **tekrarlanmış bir gözlem**: `flux_kontext` üç ayrı işte de fotoğrafın
**fotoğraf gibi kalmasını** korudu — render/CGI görüntüsüne kaymadı:

| İş | Sonuç |
|---|---|
| Filigran temizliği (4 kare) | bindirmenin altındaki duvar/parke **devam etti**, leke bırakmadı |
| Salon tadilatı (3 adım) | koyu plank zemin + greige duvar + ölçülü mobilya, **geometri korundu** |
| Bölge yamalama | orijinal pikselle yan yana durunca **dikiş belli olmadı** (parlaklık eşitlemesinden sonra) |

**Bu yüzden emlak/mekân işlerinde varsayılan model `flux_kontext`tir.** Gerekçe: bizim
ürünümüzde "güzel görünmek" yetmez, **inandırıcı olmak** gerekir — müşteri o dairede
yaşayacak. Fotogerçekçiliği kaybeden bir çıktı, teknik olarak daha temiz olsa bile
işe yaramaz.

⚠️ **Sınırı da ölçüldü:** `flux_kontext` çıktıyı **1184×880'e düşürür** (girdi ne olursa
olsun). Çözüm modeli değiştirmek değil, `/config/.claude/skills/higgsfield-abonelik/scripts/filigran-yama.sh --bolge` ile bölge
temizliği + tam-boy yamalama. Ayrıntı: TELLAL hattı bölümü.

## 🔴 PROMPT DERSLERİ — bir adım tutmuyorsa İKİ ayrı sebep olabilir

Beş yüzey adımı, aynı kareye, aynı gün koşuldu. **İki farklı kök neden çıktı** ve ikisini
ayırt etmek önemli — yanlış olanı düzeltirsen kredi yakar, sonuç değişmez.

### Ders 1 · YOK ETME, YERİNE NE GELECEĞİNİ TARİF ET

| Yazım | Prompt | Sonuç |
|---|---|---|
| 1. | *"**Remove** the pipes and continue the wall"* | **2/5** |
| 2. | *"**Fit** a smooth unbroken wall with clean white skirting"* | **4/5** ✅ |

Tek değişiklik fiildi. Aynı ailenin daha önce ölçülmüş hâli: filigranda *"watermark'ı
kaldır"* yerine *"altındaki odayı devam ettir"* yazmak işe yaramıştı.
**Modele silmeyi değil, koymayı söyle.**

### Ders 2 · TEK ÇAĞRI TEK İŞ — fiili düzeltmek yetmez

`pencere-radyator` adımı **iki iş** yapıyordu (pencere + radyatör). Fiili "KOY" kalıbına
çevirdim, **hiç değişmedi** — yani sorun fiil değildi.

| Adım | Sonuç |
|---|---|
| `pencere-radyator` (birlikte, "temizle") | 2/5 |
| `pencere-radyator` (birlikte, "koy") | **2/5** — fiil düzeltmesi işe yaramadı |
| `pencere` (tek iş) | **4/5** ✅ |
| `radyator` (tek iş) | **4/5** ✅ |

🔴 **Teşhis sırası:** bir adım tutmuyorsa **önce kaç iş yaptığına bak**, sonra fiiline.
Ben ters sırada gittim: fiili düzelttim, tutmayınca "bu model bunu yapamıyor" diye
yazacaktım — oysa model yapabiliyordu, ben iki işi tek cümleye sıkıştırmıştım.

**Çalışan yüzey adımları (hepsi 4/5, her biri 1,5 kredi):**
`supurgelik-tavan` · `boru-gizleme` · `pencere` · `radyator`

## 🔴 MİMARİ DERS — YAMA, ZİNCİRİ YENER (2026-08-31, ölçüldü)

Bir görsele çok sayıda düzeltme uygulamanın **iki yolu** var. Ölçüldü, biri açık ara iyi:

| Yol | Nasıl | Sonuç |
|---|---|---|
| **SERİ ZİNCİR** | adım 1'in çıktısı adım 2'ye girer, 7 adım | **2/5 — sürüklendi** |
| **PARALEL + YAMA** | 4 adım da AYNI tabana koşar, sonra her birinden **yalnız değiştirdiği yer** yamalanır | **4/5 ✅** |

**Sürüklenme neye benziyor:** 7 adımlık zincirde duvar greige'den sıcak beje kaydı,
koltuk rengi değişti, zemin aşırı parladı, oda oranları bozuldu. Mobilyayı sona almak
sürüklenmeyi **değiştirdi ama kaldırmadı** — sıra sorunu değil, **uzunluk** sorunu.

**Neden yama kazanıyor:** seri zincirde her adım bir öncekinin *tüm* çıktısını yeniden
yorumlar, hatalar birikir. Yamada her adım **aynı temiz tabanı** görür ve ondan yalnız
kendi katkısı alınır — hatalar birikmez, **paralel** koşulabilir, ve maliyet aynıdır
(her adım yine 1 kez çağrılır; yamalama `ffmpeg`, ücretsiz).

```bash
# 4 yüzey adımı AYNI tabana (paralel koşulabilir)
for a in pencere radyator supurgelik-tavan boru-gizleme; do
  bash <TELLAL deposu>/scripts/staging.sh --girdi "$TABAN" --adimlar "$a" --sinif tadilat ... --cikti "out/$a"   # staging.sh bu pakette yok
done
# sonra yalnız değişenleri sırayla yamala (ücretsiz)
bash /config/.claude/skills/higgsfield-abonelik/scripts/filigran-yama.sh "$TABAN" out/pencere/sonra.png adim1.png --esik 14 --genislet 25
...
```

🔴 **Bu, filigran için yazdığım mekanizmanın genelleşmiş hâli:** *"bu adımın değiştirdiği
yeri al, gerisini olduğu gibi bırak."* Filigranda bir bindirmeyi kaldırmak içindi;
burada bir zincirin sürüklenmesini önlüyor. **Aynı alet, iki dert.**

## 🔴 YAMA — BÖLGE mi TAM KARE mi? (2026-09-06, ölçüldü)

Yama iki biçimde koşar ve **yanlışını seçmek görünür dikiş bırakır**:

| Değişikliğin boyu | Doğru yol | Neden |
|---|---|---|
| **Küçük/yerel** (sehpa üstü, kablo, kişi silueti) | `--bolge x:y:g:y` | Maske küçük kalır, garanti güçlüdür |
| **Büyük/kasıtlı** (halı değişimi, oda geneli) | **tam kare + fark maskesi** | Maske DİKDÖRTGENİ değil, **gerçekten değişen yeri** takip eder |

**Ölçüm:** halıyı 1900×1100'lük bir bölgeyle değiştirdiğimde perdenin ortasında **yatay
bir dikiş** kaldı. Tüylenmeyi 25 → 60 → 120 yaptım, **geçmedi** — çünkü dikiş bir kenar
kusuru değil **parlaklık basamağı**ydı: bölge büyüyünce tek bir parlaklık kaydırması
yetmiyor. Aynı işi tam kareye koşup farktan maske çıkarınca **dikiş yok oldu.**

**Kural:** dikdörtgen, değişiklik küçükken doğrudur. Değişiklik büyükse dikdörtgen
*sınırı*nın kendisi kusur üretir — bırak maskeyi **değişikliğin şekli** belirlesin.

## Ölçülmüş A/B (2026-08-28 · D-003-09 salon tadilat, 3 adım)

| | fal.ai (API) | Higgsfield (abonelik) |
|---|---|---|
| maliyet | **$0,12** | **4,5 kredi** (marjinal $0) |
| süre | 45 sn | 58 sn |
| kalite | eşdeğer | eşdeğer |

Aynı model + aynı prompt → aynı sonuç. **Fark cüzdanda, kalitede değil.**
Karar kuralı: abonelik 1 ay sonra yanacaksa **önce onu harca**; ölçüm turları tek yolla koşar (D2).

## Sürüm notları

- **1.0.0 (2026-10-22, SERDAR-alt · görev gorev_01M4ZPG4W4PR6EB1YQ9E3DBM27):** devir dizininden
  (`/config/.claude/TELLAL-BESIR-devir/`) Sx-Claude-Skills'e taşındı. **Neden:** kurulu kopyada yalnız
  SKILL.md vardı, betikler devir dizininde kalmıştı; SKILL.md betikleri göreli yoldan (betik adının önünde yalnız `scripts` dizini) ve
  `$CLAUDE_PROJECT_DIR` yolundan çağırıyordu → başka kutudan koşunca yol kırılıyordu (KALFA/nova geçici
  sarmalla idare ediyordu; MEDDAH kararı 15 Eki: kusur paketin, onarım beceri sahibinin). **Değişen:**
  15 betik paket içi betik dizinine (`<beceri>/scripts/`, içerik değişmedi; betikler arası çağrılar zaten
  `dirname "${BASH_SOURCE[0]}"` tabanlıydı, çevrilen 0) · SKILL.md çağrıları mutlak beceri yolundan ·
  `DEVIR-SINAV.sh` → `<beceri>/scripts/paket.test.sh` (kendi dizininden, ağsız, kredisiz; CI her koşuda
  çalıştırır) · `KREDI-TAVANI-OKU.md`, `DEFTER-SEMA.md`, `DEVIR-YOKSAY.txt` paketle birlikte ·
  `staging.sh` / `flux-kontext-*.sh` pakette YOK (TELLAL staging zinciri; aranıp bulunamadı), metinde
  işaretlendi, uydurulmadı · sync-targets + catalog kaydı (öksüz beceri bırakmak yasak).
