---
name: ui-tasarim-akisi
type: agent
version: 0.3.2
description: >
  UI/arayüz tasarım işinin ZORUNLU akış kapısı. Bir ürünün ekranlarını tek tek değil dizi
  hâlinde tasarlatır: ürün niyeti → sayfa envanteri → kullanıcı senaryoları (tık bütçesi) →
  ÇEKİRDEK+MARKA sözleşmesi → Claude design promptu → devam promptuyla kalan sayfalar +
  her sayfadan sonra üç denetim. "UI işi · arayüz · ekran tasarla · sayfa tasarımı ·
  frontend görünüm · panel · layout · stil · tema · bileşen" tetiğinde çağrılır.
  🔴 `/frontend-design` ile BİRLİKTE zorunludur (Sultan direktifi) — biri ötekinin yerine
  GEÇMEZ: bu akış senaryo/sayfa-dizisi katmanı, `/frontend-design` görsel-dil katmanı.
  Proje-bağımsız · GLOBAL (tüm kutular).
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [ui, tasarim, akis, prompt, kalfa]
---

# UI tasarım akışı — sayfa dizisi üretme metodu

## Ne işe yarar

Bir ürünün ekranlarını **tek tek değil, dizi hâlinde** tasarlatır. Tek ekran tasarlatmak kolaydır;
zor olan ikinci ekranın birinciye benzemesidir. Bu akış onu garanti eder.

Tasarım **Claude design'da** üretilir. Bu metot orada üretilecek promptu kurar — tasarımı kendisi
üretmez, ürettirmeye çalışmaz.

## Ne zaman başlatılır

Bir üründe **birden çok ekran** tasarlanacaksa. Tek ekranlık iş için ağırdır.
Ön koşul yok — "ürün tam netleşmedi" hâli akışın **dışında** değil, **Durak 0**'ıdır.

## Beş durak — sıra değişmez

| # | Durak | Çıktı | Bitti sayılma kanıtı |
|---|---|---|---|
| **0** | **Ürün niyeti** | `tasarim/urun-niyeti.md` — 5 kapalı soru + iskelet | Her sorunun `Kendi cümlem:` satırı **dolu** (araç boş bırakılmışsa prompt üretmez) |
| 1 | **Sayfa envanteri** | Hangi ekranlar var, her biri hangi işi bitiriyor | Envanterdeki her satırda "bitirdiği iş" tek cümleyle yazılı |
| 2 | **Kullanıcı senaryosu** | Sayfa başına: ne görünür, nereye tıklanır, **kaç tıkta biter** | Her ekranın kartında `Tık bütçesi:` satırı dolu |
| 3 | **Tasarım promptu** | İlk sayfanın promptu — dili kuran sayfa | Sözleşme ve estetik yön prompta **birebir** girmiş |
| 4 | **Devam promptu** | Sonraki her sayfa için prompt | Önceki sayfanın HTML'i gömülü; eksikse üretim **durur** |

**Durak atlanmaz.** Niyet olmadan envanter yazılamaz (hangi ürün?), envanter olmadan senaryo
yazılamaz (hangi ekran?), senaryo olmadan prompt yazılamaz (ne çizilecek?), ilk sayfa olmadan
devam promptu üretilemez (neyin dilini sürdürecek?).

**Durak 0 niçin var (ölçüldü):** bir tam tasarım turu — 16 saat, 4 ekran — yalnız bu konuşma
yapılmadığı için çöpe gitti. Kanonda "ürün biliniyor olmalı" diye bir *cümle* vardı; çıktısı
olmadığı için denetlenemiyordu. Artık çıktısı bir dosya, kapısı da mekanik: `Kendi cümlem:`
satırı boşsa prompt üretilmez. Şık seçmek yetmez — **şık insan için, cümle tasarımcı için**;
modelin okuyacağı bağlam şıkta değil cümlede taşınır.

## Tutarlılık nasıl sağlanır — üç katman, üçü de gerekli

1. **Sözleşme** — *ne kullanılacak*. İki parçadır (aşağıda): filo geneli **ÇEKİRDEK** kurallar +
   kutunun **MARKA** değerleri (renk, tipografi, ölçek, sözlük eklemeleri). Ölçülebilir.
2. **Önceki sayfanın HTML'i** — *fiilen ne olmuş*: devam promptuna olduğu gibi gömülür.
3. **Bileşen adı denetimi** — çıktıdaki `<!-- bilesen: Ad -->` işaretleri grep'lenir; sözlük dışı
   ad yakalanır.

Yalnız sözleşme verilirse model bileşenleri her sayfada yeniden yorumlar. Yalnız HTML verilirse
neyin kasıtlı neyin tesadüf olduğunu bilemez. **İkisi birden verilir.**

Dördüncü bir katman da var ve ölçülemez ama işi belirler: **estetik yön** — karakter, imza öğesi,
hangi hazır kalıba düşülmeyeceği. Sözleşme uyumlu ama ruhsuz ekranlar bu katman olmayınca çıkar.

## Sözleşme ikiye ayrılır — ÇEKİRDEK ⟂ MARKA

| | **ÇEKİRDEK** (`cekirdek/sozlesme.md`) | **MARKA** (`sablonlar/tasarim-dili.md`'den türetilir) |
|---|---|---|
| Nerede yaşar | beceride, filo geneli | kutuda, ürüne özel |
| Ne taşır | kural: çıktı sözleşmesi · işaret standardı · 10 çekirdek bileşen adı · yoğunluk kuralları · kontrast ölçme yükümlülüğü · dondurma | değer: renkler · font · kademeler · ölçek · iskelet · sözlük eklemeleri · yasaklar |
| Renk değeri | **sıfır** (mekanik kapı: hex/rgb/hsl bulursa koşu rc=2) | hepsi |
| Kim çağırır | **kimse — kendiliğinden girer** | `--dil` |

Çekirdeği atlamak için bayrak **yoktur**: `prompt-yap.sh` onu her promptun sözleşme yuvasına
kendiliğinden, marka dosyasından **önce** koyar. Kutunun kopyalamasına gerek yok — kopyalanan
kural bayatlar (ölçülmüş vaka: `frontend-design` sessizce üç kopyaya ayrılmıştı).

`--dil` birden çok dosya alabilir, `:` ile ayrılır (PATH gibi) — ör. ortak bir aile-markası +
ürünün kendi eklemesi. Tek yol veren eski çağrılar aynen çalışır.

> **Mevcut sözleşmeler için not (dürüstlük):** ayrımdan önce türetilmiş sözleşme dosyaları
> çekirdeğin bazı bölümlerini kendi içinde tekrar ediyor olabilir. Zararsızdır (aynı kural iki kez
> okunur) ama temizlemek iyi olur: kural satırlarını sil, değerleri bırak.

## Akış

```
0. Ürün niyetini doldur  → sablonlar/urun-niyeti.md → tasarim/urun-niyeti.md
1. Envanter yaz          → sablonlar/sayfa-envanteri.md
2. Her ekrana senaryo    → sablonlar/senaryo-karti.md   (tık bütçesi ZORUNLU)
3. MARKA sözleşmesi      → sablonlar/tasarim-dili.md   (çekirdek kendiliğinden eklenir)
4. Estetik yönü yaz      → sablonlar/estetik-yon.md
5. İlk sayfanın promptu  → sablonlar/tasarim-promptu.md
   ↓ Claude design'da koştur, çıkan dosyayı depoya indir
6. Sonraki her sayfa     → sablonlar/devam-promptu.md  (önceki HTML girdi)
   ↓ her sayfadan sonra ÜÇ DENETİM (aşağıda)
```

Promptlar yuvalıdır; `arac/prompt-yap.sh` yuvaları doldurur.
**Sözleşme promptlara kopyalanmaz** — kopya bayatlar, yuva bayatlamaz.

## Çıktıyı geri alma — iki yön ayrı işlerdir

Promptu **göndermek** ve tasarımı **geri almak** aynı iş değildir. Metnin gidişi tıkanırsa insan
yapıştırabilir; ama **dönüş yönü senin işindir** ve insanı dosya taşıyıcısı yapmadan önce sırayı
tüket:

| # | Yol | Ne zaman |
|---|---|---|
| 1 | Araç yüzeyine bak — tasarım platformuna bağlanan bir araç var mı | Her zaman ilk adım |
| 2 | Proje kimliğiyle **doğrudan çek** (dosya listele → içeriği al) | Araç varsa |
| 3 | Kırmızı dönerse **yazma** dene; yetki akışını tekrarlayıp bir kez daha dene | Okuma başarısızsa |
| 4 | Elle taşıma: insan dosyayı kaydeder, sen okursun | **Yalnız 1–3 tükendiyse** |

**Boş liste "kapalı" demek değildir.** Listeleme boş dönerken yazma çalışabiliyor — bu ölçüldü.
Dolaylı bir sinyale bakıp yolun kapalı olduğuna karar verme; **aracı fiilen çağır.**

**Çıktı bir kez çekilmez.** Platform ilk çıktıdan sonra kendini rafine edebiliyor; çektiğin dosya
son sürüm olmayabilir. Bir süre sonra yeniden çek ve karşılaştır.

Elle taşıma meşru bir yedektir ama **varsayılan değildir** — bedeli sana değil insana yazılır.

## Platform tarafındaki tasarım sistemi

Metodun üç tutarlılık katmanı depo tarafındadır (sözleşme · önceki kaynak · bileşen denetimi).
Bir katman daha platform tarafında yaşar: **tasarım sistemi.**

**Her ürün kendi tasarım sistemini açar.** Başka bir ürünün sistemi seçiliyse onun renkleri ve
bileşenleri seninkilerin üstüne biner ve iki dil karışır. Üstelik **bileşen adı denetimi bunu
yakalayamaz** — o yalnız kendi sözlüğüne bakar. Sızıntı sessiz olur.

Doğru hamle *çıkarmak* değil **eklemek**: kendi sistem projeni aç, sözleşmeni ve sayfa
senaryolarını içine koy, her turda onu seç.

Ortak bir hesapta çalışıyorsan: yazma çağrıları proje kimliği alır — yanlış kimlik başka ürünün
sistemine yazar. Kimliği her seferinde doğrula.

## Sayfa sırası nasıl seçilir

**İlk sayfa dili kurar; EN ÇOK TARTIŞILACAK olan seçilir** — "en zengin" değil.

Bu kural ölçümle değişti: bir turda insan oturumundan çıkan **11 maddenin 10'u açılış sayfasına**
aitti (8 karar + 2 tespit; kalan 1 madde ekran değil süreç kararıydı). Diğer **altı ekranın payı: 0**.
Yani açılış, zenginliği için değil *en çok itiraz toplayacağı* için ilk sırada olmalı —
itirazı erken al ki dilin geri kalanı sağlam zemine kurulsun. Zengin ama tartışmasız bir ekran
ikinci sıraya düşer.

İskelet, gezinme, kart dili, durum göstergeleri ilk sayfada doğar; formlar ve listeler ondan
türer. Giriş/oturum ekranı **en sona** bırakılır — dili kurmaz, yalnız tüketir.

## Üç denetim — her sayfadan sonra, atlanmaz

1. **Bileşen tutarlılığı** — çıktıdaki bileşen adları sözlükte var mı, önceki sayfanınkiler
   devralınmış mı, sözlük dışı ad icat edilmiş mi.
   *Yeni ad gerekiyorsa model onu bildirmelidir; bildirilen ad sözleşmeye eklenir ve değişiklik
   günlüğüne yazılır. Sessizce icat edilen ad hatadır.*
2. **Kısıt denetimi** — ürünün kendi yasakları çiğnenmiş mi (çizilmemesi gereken alanlar,
   gösterilmemesi gereken bilgi).
3. **Tık sayımı** — senaryodaki hedef tutmuş mu. Aşım **sessiz geçilmez**: ya tasarım revize
   edilir ya hedef gerekçeyle güncellenir. Sayım elle yapılır (tarayıcı yok), ama **kaydı
   makineye verilir**:

```
bash arac/tik-kaydet.sh tasarim/ciktilar/E1.html G1=3:2 G2=1:1   # hedef:ölçülen
```

**Bu kapı sonradan eklendi ve niçini utandırıcıdır:** Durak 2 tık bütçesini ZORUNLU ilan
ediyordu, ama aşağı akışta hiçbir kapı onu istemiyordu — `prompt-yap.sh` içinde geçen "tık"
kelimelerinin hepsi *"esTİKk"* in içiydi, gerçek referans **sıfırdı**. Yani bu sistemin
başkasında yakaladığı "ölçmediğine temiz der" hatası tam da kendi çekirdeğinde duruyordu.
(Bulan: MÜTEVELLİ/AKAR, 2026-08-07 — beceriyi kullanmadan önce denetleyerek.)

Artık `prompt-yap.sh --onceki` tık ölçümünü de arar:
- ölçüm **yok** → `rc=3` ÖLÇÜLEMEDİ (yoğunluk temiz olabilir; tık *bakılmamıştır*, ikisi ayrı şey)
- ölçüm **bayat** (sayfa ölçümden sonra değişmiş, sha tutmuyor) → `rc=3`
- bütçe **aşılmış** → `rc=1` (bu "bakılamadı" değil, ölçüldü ve kırmızı)

Bayatlık kontrolü asıl saldırı yüzeyidir: eksik artefaktı fark etmek kolay, bir kez ölçülüp
sonra sayfası on kez değişmiş artefaktı fark etmek zordur.

**1. ve 2. denetimin mekanik gövdesi + yoğunluk:** `arac/yogunluk-denetle.py <ekran-dizini>`

```
python3 arac/yogunluk-denetle.py --profil-ornek > tasarim/kapi-profili.json   # bir kez
python3 arac/yogunluk-denetle.py tasarim/ciktilar ; echo rc=$?                # her sayfadan sonra
python3 arac/yogunluk-denetle.py <dizin> --profil <yol> [--cekirdek <yol>]    # yol standart dışıysa
```

> ⚠️ `--profil` **0.3.0'a kadar ölü yoldu**: bayrak eleniyor ama DEĞERİ elenmiyordu, konumsal
> argüman iki sayılıp `rc=2` dönüyordu (sınav kapsamı 0). Onarıldı; `--profil=<yol>` biçimi de
> çalışır ve değeri eksik bayrak sessizce yutulmaz. Dizin düzeni varsayılan yolu tutturmayan
> kutular (ölçülen vaka: AKAR) artık kapıyı koşturabilir.

Niçin gerekli (ölçüldü): sözleşmeye **uyan** beş ekran mekanik kapıdan 5/5 geçti, ardından
insan oturumu 11 madde çıkardı. Eksik boyut renk/tipografi değil **yoğunluk** ve
**ekranlar-arası tutarlılık**tı — ikisi de deterministik ölçülebiliyormuş, kimse ölçmüyordu.

| Kod | Ne ölçer |
|---|---|
| S1 | büyük-sayı bütçesi (yüzey başına) |
| S2 | blok-türü bütçesi (yüzey başına) |
| S3 | tek birincil eylem (koşulsuz olanlar sert) |
| S4/S5 | köşe-yarıçapı ve font kademe kümesi — beşinci kademe icadı |
| X1 | gezinme iskeleti ekrandan ekrana aynı mı |
| X2 | sözlük-dışı bileşen adı (sessiz icat) |
| X3 | ürünün yasak dili |
| X4 | aynı durumun iki farklı yazımı (küme geneli) |

**Kapının çağıranı var — iyi niyete bırakılmadı.** `prompt-yap.sh --onceki <sayfa>` (yani
*devam promptu üretme anı*) önce o sayfayı bu kapıdan geçirir:
kırmızıysa **prompt üretilmez** (`rc=1`), profil yoksa **"ölçülemedi"** der (`rc=3`, "temiz"
demez). Sebep: ölçülmemiş sayfanın üstüne bir sonraki sayfa çizilirse hata bütün diziye yayılır
— zaten bir turu böyle kaybettik. Kapıyı koşturmanın maliyeti saniyeler; kaçırmanın maliyeti tur.

**Sayılar profilden gelir, araçtan değil** — çekirdek kuraldır, değer markadır. Profil yoksa
araç **RC=2** döner; varsayılan uydurup yanlış-yeşil vermez. Profildeki her sayı sözleşmede
yazılı olanla aynı olmalı; sapma driftir.

**Sözlük = ÇEKİRDEK ∪ PROFİL (0.3.0).** X2'nin kabul kümesi artık çekirdeğin Ç3 listesi ile
profilin `sozluk`unun birleşimidir. Niçin: çekirdek prompta kendiliğinden giriyordu ama kapı
yalnız profile bakıyordu; marka şablonu da bilerek *"çekirdeğin on adı zaten geçerlidir, buraya
tekrar yazılmaz"* diyor → **kurala harfi harfine uyan ekran "sessiz icat" ile reddediliyordu.**
Kural değişmedi, kapı kurala uyduruldu. 🔴 Karşılaştırma **tam eşleşmedir, casefold YOK** —
ölçüldü: casefold üç iddiayı birden kırıyor (yüzey ayrımı tam eşlemeye dayanır). Çekirdek
okunamazsa **RC=2**: profil-yalnız'a sessizce düşmek eski yanlış-KIRMIZI'yı geri getirirdi.

**Üç rol artık profilden türetilir (`rol_adlari`, isteğe bağlı).** `Yan panel` (yüzey açar) ·
`Gezinme` (X1 iskeleti) · `Örnek durumlar` (vitrin muafiyeti) araçta **koda gömülü ve
harf-duyarlı** dizgilerdi; hiçbir profilden gelmiyor, hiçbir bekçi ölçmüyordu. Adlandırması
farklı bir kutu (ölçülen vaka: HUZUR'un `NavCubugu`/`SayfaBasligi` yazımı) kendi profilini
yazsa bile yüzey-ayrımı, X1 ve vitrin muafiyeti kırık kalıyordu. Alan vermeyen eski profiller
aynen çalışır (varsayılan = çekirdek yazımı); bilinmeyen bir rol anahtarı **RC=2**'dir —
yazım hatası, ölçülmemiş rol demektir.

**`blok_turu` sessiz atlamaz (sahte-yeşil panzehiri).** Haritanın anahtarı sözlükte yoksa
hiçbir işareti tutamaz; eski kod `if tur:` ile atlıyor, S2 bütçesi hiç ölçülmüyor ve kapı
"temiz" diyordu. Artık: anahtar sözlük dışıysa **RC=2** (yapılandırma hatası, ihlal değil);
harita geçerli ama kümede hiç tutmuyorsa **uyarı** basılır — "temiz" o boyutu kapsamıyor.

**Ölçmediğini söyler:** tek-ekran anlamı (manşetin öznesi, görselin bilgi değeri) bu kapının
konusu **değildir** ve çıktı bunu her koşuda yazar. Oraya "temiz" demez, hiç bakmaz.
Kalibrasyon: reddedilmiş bir turun 4 ekranının 4'ünü düşürdü, onaylanmış turun 5 ekranına
dokunmadı. Kapının kendi sınavı: `bash arac/yogunluk-denetle.test.sh` (35 kapı, negatif
fikstürlü — fikstürsüz kapı devreye alınmaz).

**Çift-yönlü fikstür — hattın giriş şartı.** Her ölçüm hattı hem **KIRMIZI** (yanlışı yakalar)
hem **ALTIN** (doğruyu geçirir) fikstürüyle gelir. Tek yönlü fikstür yalnız katılaşmayı yakalar,
**gevşemeyi yakalamaz**. Sözlük çatalı tam da ALTIN tarafı olmadığı için yıllarca görünmedi.
(Öneri: NAKKAŞ + MÜTEVELLİ, 2026-08-07.)

| Çift | Yeşil yüz | Kırmızı yüz | Neyi kilitler |
|---|---|---|---|
| yüzey/yazım | `fikstur/panel-yesil/` | `fikstur/panel-kirmizi/` | yüzey ayrımı bozulursa yeşil düşer; ad-eşleme gevşerse (casefold) kırmızı yeşile döner |
| sözlük birleşimi | `fikstur/altin/` | `fikstur/birlesim-kirmizi/` | çekirdek adları kabul edilmeli; ne çekirdekte ne markada olan ad **hâlâ X2** olmalı |
| rol türetimi | `fikstur/rol/` + `rol-profili.json` | aynı bayt + `rol-yalin-profili.json` | üç rol koda geri gömülürse yeşil yüz S1+X1+X2 ile düşer |
| sahte-yeşil | `fikstur/temiz/` (harita tutar) | `fikstur/g5-oksuz-profil.json` | ölçülmemiş S2 "temiz" sayılamaz |
| anlam (yargı) | `fikstur/yargi/altin/` | `fikstur/yargi/kirmizi/` | rubrik her ekranı düşürür hâle gelirse ALTIN yakalar |

`fikstur/altin/` **bilerek** çekirdeğin hiçbir adını içermeyen bir marka profiliyle koşar:
birleşim kalkarsa fikstür anında kırmızı yanar. Negatif kanıt sınavda ayrıca ölçülür —
çekirdekten bir ad düşürülünce ALTIN kırmızıya dönüyor mu (yoksa yeşili birleşime borçlu değil,
birleşim süstür).

**Bekçi — çekirdek ⟂ araç tek gerçek:** `python3 arac/cekirdek-sozluk-denetle.py`.
Çekirdek sözleşmedeki (Ç3) her bileşen adı, aracın varsayılan sözlüğünde **harfi harfine**
bulunmalıdır; bulunmazsa RC=1. Niçin var: çekirdek `Yan Panel` yazarken araç `Yan panel`
bekliyordu — çekirdeği harfi harfine uygulayan kutu hem "sözlük-dışı ad" suçlaması yedi hem
paneli ayrı yüzey saydıramadığı için **yanlış kırmızı** aldı (bulan: AKAR/MÜTEVELLİ). Çözüm
harf-duyarsız karşılaştırma **değildi** — o, X4'ün "aynı şeyin iki yazımı = çatal" felsefesini
çürütürdü. Yazım tek; bekçi hizayı ölçer. Ç3 okunamazsa RC=2 (ölçemediğine temiz demez).

## Anlam yargısı — kör panel (G1, yalnız NEGATİF yetki)

Yukarıdaki kapı yoğunluğu ölçer, **anlamı ölçmez**. Anlam için ayrı bir hat var: aynı ekranı
birbirinden habersiz **farklı model ailelerinden** yargıçlara kör olarak puanlatır.

```
bash   arac/yargi-panel.sh --ekran-dir tasarim/ciktilar --sozlesme tasarim/tasarim-dili.md \
       --out .yargi                                           # yargıçları koşar
python3 arac/yargi-birlestir.py --rubrik arac/rubrik/urun-ui-v1.md \
       --yanit .yargi --ekran-dir tasarim/ciktilar ; echo rc=$?  # hükmü verir
```

**Değişmez: `GEÇTİ ⟺ G0 yeşil ∧ G1 kırmızı-değil`.** Yargıç yeşil **üretmez**, yalnız iptal
eder — hiçbir kademede bir modelin "artık iyi" demesi durma koşulu olamaz. Çıkışlar:
`0` kırmızı-değil · `1` RED · `2` çalıştırılamadı/emin-değilim (**yeşil sayılmaz**).

Beş halkanın her biri ölçülmüş bir zaafı kapatır: **parse kapısı** (bozuk çıktı düşer) →
**alıntı kapısı** (ekranda birebir bulunmayan alıntı hükmü düşürür — uydurma kusur/övgü
panzehiri) → **yeter sayı** (ayakta <2 oy → emin-değilim; *bilinmeyen ≠ geçti*) → **medyan**
(ortalama değil; tek aykırı yargıcı yutar) → **kırmızı çizgi** (geçerli-alıntılı tek 0 maddeyi
düşürür; ölçülen hata sahte-yeşildi, asimetri kasıtlı).

- **Yargıç kördür — politika olarak değil, kabiliyet olarak:** araçsız tek-atış tamamlama;
  dosya yazamaz, motorun raporunu göremez, soru soramaz.
- **Rubrik veridir** (`arac/rubrik/`), kod değil: maddeler ve eşikler dosyadan okunur.
  `--muhur <sha256>` verilirse rubrik koşudan sonra değişmişse koşu **reddedilir** — rubriği
  düzenlemek, regresyonu yeniden koşmadan geçerli sayılmaz.
- **Puan imzaya girmez:** çıktıdaki `imza` yalnız düşen madde kimliklerini taşır, sayı taşımaz.
  (Stokastik puan imzaya girseydi döngünün "aynı hata 2 kez" freni hiç yanmazdı.)
- **Kapı sağlıksızsa hüküm ÜRETİLMEZ** (RC=2). Servis arızasını tasarım kusuru sanmak, otonom
  döngünün geri alamayacağı hatadır.
- **tescil bağlantısı:** `--tescil-g G3` verildiğinde `--katman2 G3=GECTI|KALDI|EMIN-DEGILIM:not`
  sözcesini basar; öznel G elle değil mekanik doldurulur.
- **Çekirdek prompta enjekte edilir (0.3.0).** `--sozlesme` kutunun **MARKA** dosyasıdır;
  çekirdek (`cekirdek/sozlesme.md`) filo kuralıdır ve prompta kendiliğinden girer — gerekirse
  `--cekirdek <yol>` ile taşınır, yoksa **RC=2** (yarım sözleşmeyle hüküm istenmez).
  Niçin: panel çekirdeği **hiç** enjekte etmiyordu (`grep -c cekirdek` = 0), rubrik M1 de
  "sözlük-dışı sessiz icat var mı" diye sorduğu için yargıç çekirdeğin on adını tanımsız görüp
  icat sayabiliyordu — **mekanik X2 hatasının birebir LLM ikizi.** İstek gövdesi artık ayrı ve
  sınanabilir bir dosyadadır (`arac/yargi-istek-yap.py`); gömülü heredoc'a hiçbir sınav
  dokunamıyordu, ölçülmeyen yer sessizce bozulur.
- Kendi sınavı: `bash arac/yargi-birlestir.test.sh` (17 senaryo, ağsız/hermetik). Hattın kendi
  fikstürleri: `fikstur/yargi/altin/` (ayakta kalmalı) ⟂ `fikstur/yargi/kirmizi/` (düşmeli).
  İkisi de **mekanik kapıdan rc=0** geçer — böylece bir yargı-kırmızısı kesinlikle anlam
  boyutundandır, yoğunluk bulaşması değildir. (Kırmızı fikstür önceden `fikstur/kirli/`
  içindeydi: çağıranı yoktu ve mekanik kümeye karışıp X1 kirliliği üretiyordu.)
  ⚠️ **Ölçülmeyenin itirafı:** sınavdaki oylar ön-kayıtlı/sentetiktir (CI ağa çıkmaz). Kanıtlanan
  şey zincirin bu fikstürlere verdiği hükümdür; canlı yargıcın onlara fiilen ne verdiği
  ölçülmez — o, kapıya çıkan kalibrasyon koşusunun işidir.

**Kalibrasyon (2026-08-07, ön-kayıtlı ölçütlerle):** kör panel, onaylanmış turun bilinen-kusurlu
ekranında insan divanının üç maddesini bağımsız yakaladı; sağlam dört ekrana dokunmadı.
**Yakalayamadığı:** reddedilmiş turun ekranları — çünkü onların kusuru anlam değil yoğunluk
boyutundaydı. İki kapı bu yüzden ayrı: **anlam → yargıç, yoğunluk → makine.**

## Havuz — öğrenilenin merkeze döndüğü yer

Bir tur biterken öğrenilen şey bugüne kadar hiçbir yere düşmüyordu: kapı kırmızı yanıyor,
düzeltiliyor, **bir sonraki tur aynı hatayı yeniden keşfediyordu.** Havuz o kaybı kapatır.

```
python3 arac/havuz.py ozet                 # merkezî görünüm: en çok hangi kural düşüyor
python3 arac/havuz.py oku --kutu akar      # o kutunun son ölçümleri (ilk sütun: kayıt-id)
python3 arac/havuz.py iptal <kayit-id> --sebep olcmeden-yazildi   # yanlış satırı geçersiz kıl
python3 arac/havuz.py oku --iptaller-dahil # iptal geçmişini de göster
```

**Yanlış satır SİLİNMEZ, ÜSTÜNE YAZILIR.** Havuz salt-eklemedir; ama ölçmeden tahminle yazılmış
bir satır özeti sonsuza dek kirletiyordu (canlı vaka: 4 satır tahminle yazıldı, 2'si yanlış
çıktı; özet gerçeği söylemez oldu). `iptal` eski satıra dokunmaz — yeni bir **mezar-taşı** satırı
ekler. `ozet` ve `oku` varsayılan görünümde ikisini de dışarıda bırakır; geçmiş
`--iptaller-dahil` ile görünür. Görünüm süzer, dosya unutmaz.
`--sebep` **kapalı kümedir**: `olcmeden-yazildi · yanlis-profil · tekrar · test-artigi`.
Serbest metin kabul edilmez (aşağıdaki şema kuralı).

**`profil_sha` (isteğe bağlı, 12 hane):** ölçümün hangi kapı-profiline karşı yapıldığının parmak
izi. Aynı ekran iki profille iki farklı hüküm alır; parmak izi olmadan havuza bakan hangisinin
geçerli olduğunu bilemez ("ölçüm doğru, referans yanlış" vakası). İçerik değil **sha** — kapalı
şema bozulmaz. `ozet`, parmak izi taşımayan ölçüm sayısını dürüstçe basar.

**Çağıranı var — kimse "havuza yaz" demek zorunda değil.** Kayıt, hükmün doğduğu iki anda
kendiliğinden düşer: `prompt-yap.sh --onceki` (yoğunluk ölçümü) ve `yargi-birlestir.py
--havuz-kutu <ad>` (jüri hükmü). Ayrı bir gönüllü adım bırakılsaydı yazılmazdı — bu ailedeki
her gönüllü adım ölçüldü ve yazılmamıştı.

**Havuz kapı DEĞİL, defterdir:** yazılamazsa koşu düşmez, uyarı basılır. Ölçümü bir günlük
tutulamadı diye durdurmak, hastalıktan beter ilaç olurdu.

🔒 **Şema kapalıdır — serbest metin alanı YOKTUR.** Havuz dosyası kutuların **ortak** gördüğü
bir dizinde yaşar; izole bir kutu başkasının satırlarını okuyabilir. Bu yüzden şemada alıntı,
HTML, gerekçe metni, kişi/müşteri adı taşıyacak hiçbir alan yoktur — yalnız kod ve sayı
(`kutu · urun · ekran · kapi · hukum · dusen[] · tur · arac · ts`). Şema dışı anahtar, desene
uymayan değer ya da `dusen` alanına serbest metin → **kayıt reddedilir** (fail-closed).
"Şuraya küçük bir not düşeyim" diye alan eklenmez; eklenirse mahremiyet sınırı sessizce delinir.

**Boş havuz "temiz" demez, "hiç bakılmamış" der — ve çıkış kodu da öyle der.** `ozet` boş
havuzda **RC=3 (ÖLÇÜLEMEDİ)** döner. Metin bunu zaten söylüyordu ama kod `0` diyordu; bir çağıran
için `0` "temiz" demektir. Metin dürüstken kodun yalan söylemesi, sessizliği başarı saymanın
makine hâliydi (bulan: NAKKAŞ, 2026-08-07). **3 ≠ temiz.**

## Değişmezler

- **Tasarım Claude design'da üretilir.** Bu metot promptu kurar, tasarımı üretmez.
- **Sözleşme ilk sayfadan sonra DONDURULUR.** Renk/tipografi/iskelet değişirse önceki sayfalar
  bayatlar. Yalnız *ekleme* yapılır (bildirilen yeni bileşen gibi).
- **Yarım özellik çizilmez.** Veri modelinde olmayan alan tasarımda görünmez.
- **Kısıt estetiği yener.** Çatışmada ürünün kabul kriterleri kazanır.
- **Kanıtsız bitti yok.** Her denetim çıktısıyla gösterilir; "uyumlu" beyanı yetmez.
- **Kanıtsız kırmızı da yok** — ve bunun bir prosedürü vardır, yoksa süs kalır:
  bir yolun kapalı olduğunu söylemeden önce (a) aracı **fiilen çağır**, (b) dolaylı sinyale
  değil çağrının **sonucuna** bak, (c) okuma başarısızsa **yazmayı** dene, (d) hâlâ kırmızıysa
  **hangi çağrının ne döndürdüğünü** yaz. "Bağlanamıyorum" tek başına bir ölçüm değildir.
- **Kural tek yerde yaşar, değer kutuda.** Çekirdek sözleşme kopyalanmaz ve renk/font/sayı taşımaz;
  taşırsa koşu rc=2 ile reddedilir. Atlanabilir kural, kural değildir.

## Parametreler

Şablonlardaki `{{...}}` yuvaları:

| Yuva | Ne |
|---|---|
| `{{URUN_ADI}}` | Ürünün adı |
| `{{URUN_TARIFI}}` | Ne olduğu, 1–2 cümle |
| `{{HEDEF_KULLANICI}}` | Kim, hangi bağlamda, ekrana ne kadar bakabiliyor |
| `{{SAYFA_ENVANTERI}}` | Durak 1 çıktısı |
| `{{SAYFA_SENARYOSU}}` | O sayfanın Durak 2 kartı |
| `{{URUN_NIYETI}}` | Durak 0 çıktısı (araç doldurur; boş cümle satırı varsa DURUR) |
| `{{TASARIM_DILI}}` | ÇEKİRDEK + MARKA sözleşmesi (araç doldurur; çekirdek atlanamaz) |
| `{{ESTETIK_YON}}` | Estetik yön dosyası (araç doldurur) |
| `{{ONCEKI_HTML}}` | Önceki sayfanın HTML'i (araç doldurur) |
| `{{KANONIK_GOREVLER}}` | Tık bütçesi ölçülecek görev listesi |
| `{{KISITLAR}}` | Ürünün kendi yasakları |

## Sınırlar / dürüstlük

- Bu metot ağırlıkla bir **talimat akışı**dır; `arac/` altındaki araçlar dışında kod içermez.
  `prompt-yap.sh` yalnız yuva doldurur; `yogunluk-denetle.py` yalnız ölçer; yargı hattı yalnız
  puanlar — hiçbiri tasarım üretmez.
- `yogunluk-denetle.py` **tarayıcı çalıştırmaz, LLM'e sormaz.** Gerçek tık sayımı, erişilebilirlik
  denetimi ve görsel-kalite yargısı kapsamı dışındadır; bunları "temiz" diye raporlamaz.
- Yargı hattı **kapıya (çok-model geçidine) bağımlıdır**; kapı yoksa/sağlıksızsa RC=2 döner ve
  hüküm üretmez. En az **iki ayrı model ailesi** ister — tek yargıç panel değildir, yeter sayı
  sağlanamaz. Yargıcın hükmü *yeşil değildir*: yalnız mekanik yeşili iptal edebilir.
- Claude design'a **erişim kurmak** bu metodun konusu değil — ama **erişimi denemek** metodun
  işidir. Promptun gidişi elle yapılabilir; çıktının dönüşü önce araçla denenir
  ("Çıktıyı geri alma" sırası). *"Erişimi metoda karıştırma"* maddesi *"erişimi araştırma"*
  diye okunmaz. Erişim gerçekten yoksa promptlar elle yapıştırılır; akış aynen çalışır.
- Çıktı biçimi platformun kendi biçimidir. "Tek bağımsız HTML" isteyip bileşen dosyası almak
  aykırılık değil, platformun doğal davranışıdır — denetimler buna göre yazılır.

## Sürüm geçmişi — çatal kapanışı (L56 · Faz 0)

Bu beceri bir dönem **iki soydan** evrildi ve ikisi de "güncel" göründü:

| Soy | Nerede | Ne getirdi |
|---|---|---|
| kanon `0.1.8` | `Sx-Claude-Skills` (bu depo) | Durak 0 (ürün niyeti) · ÇEKİRDEK⟂MARKA ayrımı · yoğunluk/tık araçları · kör yargı paneli · havuz |
| teslim `0.2.0` | HUZUR kutusu, 2026-08-05 · `Nexus/_agents/handoff/gelen-huzur/` | "Çıktıyı geri alma" sırası · "Platform tarafındaki tasarım sistemi" · kanıtsız-kırmızı prosedürü |

`0.2.1` **ikisinin birleşimidir**; iki soyun da tek özel maddesi taşındı, `0.2.0`'ın
`Sınırlar` maddesi kanonun daha dar hâlini düzeltti. Bundan sonra **tek kopya bu dosyadır** —
kutu-içi teslimler kanona döndüğünde bu tablo bir satır alır.

> Kendi acı dersimiz: `SKILL.md` bu dosyada *"kopya senkron mekanizması olmadan bayatlar
> (ölçülmüş vaka: `frontend-design`)"* diye **yazılıydı** ve beceri buna rağmen çatalladı.
> **Doğru yazılmış uyarı = 0 koruma.** Kopya çıkarmadan önce onu geri getirecek kapıyı kur.
