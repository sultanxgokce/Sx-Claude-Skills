---
name: ui-tasarim-akisi
type: agent
version: 0.1.2
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
Ön koşul: ürünün ne olduğu ve kimin kullanacağı biliniyor olmalı. Bilinmiyorsa önce o konuşulur.

## Dört durak — sıra değişmez

| # | Durak | Çıktı | Bitti sayılma kanıtı |
|---|---|---|---|
| 1 | **Sayfa envanteri** | Hangi ekranlar var, her biri hangi işi bitiriyor | Envanterdeki her satırda "bitirdiği iş" tek cümleyle yazılı |
| 2 | **Kullanıcı senaryosu** | Sayfa başına: ne görünür, nereye tıklanır, **kaç tıkta biter** | Her ekranın kartında `Tık bütçesi:` satırı dolu |
| 3 | **Tasarım promptu** | İlk sayfanın promptu — dili kuran sayfa | Sözleşme ve estetik yön prompta **birebir** girmiş |
| 4 | **Devam promptu** | Sonraki her sayfa için prompt | Önceki sayfanın HTML'i gömülü; eksikse üretim **durur** |

**Durak atlanmaz.** Envanter olmadan senaryo yazılamaz (hangi ekran?), senaryo olmadan prompt
yazılamaz (ne çizilecek?), ilk sayfa olmadan devam promptu üretilemez (neyin dilini sürdürecek?).

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

**Sayılar profilden gelir, araçtan değil** — çekirdek kuraldır, değer markadır. Profil yoksa
araç **RC=2** döner; varsayılan uydurup yanlış-yeşil vermez. Profildeki her sayı sözleşmede
yazılı olanla aynı olmalı; sapma driftir.

**Ölçmediğini söyler:** tek-ekran anlamı (manşetin öznesi, görselin bilgi değeri) bu kapının
konusu **değildir** ve çıktı bunu her koşuda yazar. Oraya "temiz" demez, hiç bakmaz.
Kalibrasyon: reddedilmiş bir turun 4 ekranının 4'ünü düşürdü, onaylanmış turun 5 ekranına
dokunmadı. Kapının kendi sınavı: `bash arac/yogunluk-denetle.test.sh` (12 kapı, negatif
fikstürlü — fikstürsüz kapı devreye alınmaz).

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
| `{{TASARIM_DILI}}` | Sözleşme dosyası (araç doldurur) |
| `{{ESTETIK_YON}}` | Estetik yön dosyası (araç doldurur) |
| `{{ONCEKI_HTML}}` | Önceki sayfanın HTML'i (araç doldurur) |
| `{{KANONIK_GOREVLER}}` | Tık bütçesi ölçülecek görev listesi |
| `{{KISITLAR}}` | Ürünün kendi yasakları |

## Sınırlar / dürüstlük

- Bu metot ağırlıkla bir **talimat akışı**dır; `arac/` altındaki iki araç dışında kod içermez.
  `prompt-yap.sh` yalnız yuva doldurur; `yogunluk-denetle.py` yalnız ölçer — ikisi de tasarım
  üretmez, tasarım hakkında yorum yapmaz.
- `yogunluk-denetle.py` **tarayıcı çalıştırmaz, LLM'e sormaz.** Gerçek tık sayımı, erişilebilirlik
  denetimi ve görsel-kalite yargısı kapsamı dışındadır; bunları "temiz" diye raporlamaz.
- Claude design'a **erişim** bu metodun konusu değil. Erişim yoksa promptlar elle yapıştırılır;
  akış aynen çalışır.
- Çıktı biçimi platformun kendi biçimidir. "Tek bağımsız HTML" isteyip bileşen dosyası almak
  aykırılık değil, platformun doğal davranışıdır — denetimler buna göre yazılır.
