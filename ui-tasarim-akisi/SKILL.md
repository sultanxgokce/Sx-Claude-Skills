---
name: ui-tasarim-akisi
type: agent
version: 0.1.4
description: >
  Bir ürünün ekranlarını sıfırdan tasarlama akışı: sayfa envanteri → kullanıcı senaryoları →
  Claude design promptu → devam promptu ile kalan sayfalar. Proje-bağımsız.
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

1. **Tasarım dili sözleşmesi** — *ne kullanılacak*: renk rolleri, tipografi kademeleri, boşluk
   ölçeği, **bileşen sözlüğü**. Ölçülebilir.
2. **Önceki sayfanın HTML'i** — *fiilen ne olmuş*: devam promptuna olduğu gibi gömülür.
3. **Bileşen adı denetimi** — çıktıdaki `<!-- bilesen: Ad -->` işaretleri grep'lenir; sözlük dışı
   ad yakalanır.

Yalnız sözleşme verilirse model bileşenleri her sayfada yeniden yorumlar. Yalnız HTML verilirse
neyin kasıtlı neyin tesadüf olduğunu bilemez. **İkisi birden verilir.**

Dördüncü bir katman da var ve ölçülemez ama işi belirler: **estetik yön** — karakter, imza öğesi,
hangi hazır kalıba düşülmeyeceği. Sözleşme uyumlu ama ruhsuz ekranlar bu katman olmayınca çıkar.

## Akış

```
0. Ürün niyetini doldur  → sablonlar/urun-niyeti.md → tasarim/urun-niyeti.md
1. Envanter yaz          → sablonlar/sayfa-envanteri.md
2. Her ekrana senaryo    → sablonlar/senaryo-karti.md   (tık bütçesi ZORUNLU)
3. Sözleşmeyi kur        → sablonlar/tasarim-dili.md
4. Estetik yönü yaz      → sablonlar/estetik-yon.md
5. İlk sayfanın promptu  → sablonlar/tasarim-promptu.md
   ↓ Claude design'da koştur, çıkan dosyayı depoya indir
6. Sonraki her sayfa     → sablonlar/devam-promptu.md  (önceki HTML girdi)
   ↓ her sayfadan sonra ÜÇ DENETİM (aşağıda)
```

Promptlar yuvalıdır; `arac/prompt-yap.sh` yuvaları doldurur.
**Sözleşme promptlara kopyalanmaz** — kopya bayatlar, yuva bayatlamaz.

## Sayfa sırası nasıl seçilir

**İlk sayfa dili kurar; en zengin olan seçilir.** İskelet, gezinme, kart dili, durum göstergeleri
orada doğar. Formlar ve listeler ondan türer. Giriş/oturum ekranı **en sona** bırakılır — dili
kurmaz, yalnız tüketir.

## Üç denetim — her sayfadan sonra, atlanmaz

1. **Bileşen tutarlılığı** — çıktıdaki bileşen adları sözlükte var mı, önceki sayfanınkiler
   devralınmış mı, sözlük dışı ad icat edilmiş mi.
   *Yeni ad gerekiyorsa model onu bildirmelidir; bildirilen ad sözleşmeye eklenir ve değişiklik
   günlüğüne yazılır. Sessizce icat edilen ad hatadır.*
2. **Kısıt denetimi** — ürünün kendi yasakları çiğnenmiş mi (çizilmemesi gereken alanlar,
   gösterilmemesi gereken bilgi).
3. **Tık sayımı** — senaryodaki hedef tutmuş mu. Aşım **sessiz geçilmez**: ya tasarım revize
   edilir ya hedef gerekçeyle güncellenir.

**1. ve 2. denetimin mekanik gövdesi + yoğunluk:** `arac/yogunluk-denetle.py <ekran-dizini>`

```
python3 arac/yogunluk-denetle.py --profil-ornek > tasarim/kapi-profili.json   # bir kez
python3 arac/yogunluk-denetle.py tasarim/ciktilar ; echo rc=$?                # her sayfadan sonra
```

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

**Ölçmediğini söyler:** tek-ekran anlamı (manşetin öznesi, görselin bilgi değeri) bu kapının
konusu **değildir** ve çıktı bunu her koşuda yazar. Oraya "temiz" demez, hiç bakmaz.
Kalibrasyon: reddedilmiş bir turun 4 ekranının 4'ünü düşürdü, onaylanmış turun 5 ekranına
dokunmadı. Kapının kendi sınavı: `bash arac/yogunluk-denetle.test.sh` (12 kapı, negatif
fikstürlü — fikstürsüz kapı devreye alınmaz).

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
- Kendi sınavı: `bash arac/yargi-birlestir.test.sh` (14 senaryo, ağsız/hermetik).

**Kalibrasyon (2026-08-07, ön-kayıtlı ölçütlerle):** kör panel, onaylanmış turun bilinen-kusurlu
ekranında insan divanının üç maddesini bağımsız yakaladı; sağlam dört ekrana dokunmadı.
**Yakalayamadığı:** reddedilmiş turun ekranları — çünkü onların kusuru anlam değil yoğunluk
boyutundaydı. İki kapı bu yüzden ayrı: **anlam → yargıç, yoğunluk → makine.**

## Değişmezler

- **Tasarım Claude design'da üretilir.** Bu metot promptu kurar, tasarımı üretmez.
- **Sözleşme ilk sayfadan sonra DONDURULUR.** Renk/tipografi/iskelet değişirse önceki sayfalar
  bayatlar. Yalnız *ekleme* yapılır (bildirilen yeni bileşen gibi).
- **Yarım özellik çizilmez.** Veri modelinde olmayan alan tasarımda görünmez.
- **Kısıt estetiği yener.** Çatışmada ürünün kabul kriterleri kazanır.
- **Kanıtsız bitti yok.** Her denetim çıktısıyla gösterilir; "uyumlu" beyanı yetmez.
- **Kanıtsız kırmızı da yok.** Bir yolun kapalı olduğu, denenmeden ilan edilmez.

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
| `{{TASARIM_DILI}}` | Sözleşme dosyası (araç doldurur) |
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
- Claude design'a **erişim** bu metodun konusu değil. Erişim yoksa promptlar elle yapıştırılır;
  akış aynen çalışır.
- Çıktı biçimi platformun kendi biçimidir. "Tek bağımsız HTML" isteyip bileşen dosyası almak
  aykırılık değil, platformun doğal davranışıdır — denetimler buna göre yazılır.
