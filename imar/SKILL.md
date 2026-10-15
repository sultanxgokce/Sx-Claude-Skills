---
name: imar
type: agent
version: 0.1.0
description: >
  ⛩️ İMAR — sıfırdan doğan, henüz olgunlaşmamış bir proje için KENDİ KENDİNE DÖNEN düzen:
  her gün bir tur araştırır, bulduğunu kanıta vurur, fikirleri mercekten geçirir, Sultan'ın
  tek tuşuna sunar, inşa edileni ikinci göze çürüttürür, karneyle ölçer; olgunlaşınca
  DEVRİYE'ye devreder. DEVRİYE bozulmayı önler, İMAR yokluğu doldurur — ikisi kardeştir,
  biri ötekinin yerine geçmez. Şalter KAPALI doğar; kapalıyken hiçbir şey kendiliğinden
  koşmaz. Kutuya özel ne varsa PROFİLDE beyan edilir, betiklerde çivili yol yoktur.
  "/imar", "/imar-kur", "/imar-ac", "/imar-kapat", "/imar-sec" çağrılarında kullanılır.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [imar, kendi-kendine-donen, insansiz-tur, ikinci-goz, karne, olgunluk, profil, kill-switch]
disable-model-invocation: false
---

# ⛩️ İMAR — kendi kendine dönen proje düzeni

## Niçin var (ölçülmüş, uydurulmamış)

Bu düzen MİHENK kutusunda doğdu, 10 gün boyunca orada koştu ve **üç gün kesintisiz insansız**
döndükten sonra Sultan'ın damga ölçütünü doldurdu. Reçete tek dosyaydı ve **12 yerde o kutuya
çiviliydi**: depo yolu, araştırma oturumunun evi, mezarlık dosyası, bildirim başlığı, varsayılan
ajan adı. Çivili bir düzen başka kutuda ya çöker ya da **sessizce yanlış yere yazar** — ikincisi
daha pahalıdır, çünkü yeşil görünür.

Bu beceri o reçeteyi taşınabilir hâle getirir. Taşımanın ölçülebilir tek iddiası şudur:
**başka bir kutuda kurulur ve koşar** — ve o iddianın kapısı `imar-kutu-bagimsizlik.test.sh`'tir.

## DEVRİYE ile ilişkisi (karıştırılmaz)

| | DEVRİYE | İMAR |
|---|---|---|
| sorusu | "bozulma var mı?" | "yokluk nerede?" |
| konusu | olgun, canlı iş | sıfırdan doğan, olgunlaşmamış iş |
| çıkışı | nöbet + alarm | araştırma turu + fikir + ikinci göz + karne |
| devir | — | olgunlaşınca **DEVRİYE'ye** devreder |

İkisi aynı profil ailesini kullanır (bilinmeyen alan = red · zorunlu alan boşsa kurulum yok ·
her ölçümün bir kapısı olur). **İkinci defter kurulmaz:** hâl zinciri Bulgu Defteri'nin üstüne
biner, sözlüğünü çatallamaz.

## 🔴 Değişmezler (pazarlıksız)

1. **Şalter KAPALI doğar.** Kapalıyken hiçbir şey kendiliğinden koşmaz; şalter yok/bozuk = kapalı.
2. **Üreten ≠ yargılayan.** İkinci göz ayrı süreç ve ayrı model; göz **yeşil üretmez** (ayakta
   demek "çürütülemedi" demektir, "doğrulandı" demek değildir).
3. **A06 — insan onayı üretilmez.** `seçildi/onaylandı/öldü` damgası ya puan ≥75 ya Sultan'ın
   kendi satırıdır; ajan satır uyduramaz.
4. **Ölçemediğine yeşil demez.** Her araç "ÖLÇÜLEMEDİ" basar, "yok" demez. Çöküş ve "ölçemedim"
   çıkış kodu **hükümle aynı olamaz** (hüküm 0/1, ölçemedim 3).
5. **Kanıt = kütük + tarih.** "Yaptım" yerine satır gösterilir. Alarm için "200 döndü" **yetmez**,
   cihaz teyidi gerekir — profil onu boş kabul etmez.
6. **Boş gün onurludur.** Konu kapalı ya da sinyal yok → tur boş geçer, dolgu üretilmez.
7. **Kutuya özel hiçbir şey koda çivilenmez.** Yol profilden gelir; profil yoksa araç ölçemediğini
   söyler ve varsayılan **uydurmaz**.
8. **Kutunun verisi kutuda kalır.** Beceri dizini bütün kutularda ORTAKTIR; defter, kütük, karne,
   mezarlık profilin gösterdiği kutu deposunda yaşar. (Bu kural bir sızıntıyla öğrenildi — aşağıda.)

## Kurulum (tek komut, her adımın kapısı koşar)

```bash
# 1 · profil iskeletini al, doldur
python3 imar/scripts/imar-profil.py ornek > imar-profil.json
# 2 · ölç (kurulumdan ÖNCE; geçersiz profille hiçbir dizin açılmaz)
python3 imar/scripts/imar-profil.py dogrula imar-profil.json
# 3 · kur (şalter KAPALI doğar, crontab'a DOKUNULMAZ)
bash imar/scripts/imar-kur.sh imar-profil.json          # --kuru ile önce kuru koş
# 4 · zamanlayıcı satırını kurulum BASAR; crontab'a Sultan onayıyla eklenir
# 5 · KONU.md gerekçeli yazılır → /imar-ac (Sultan kararı)
```

`alarm.cihaz_teyidi` boşsa profil **reddedilir**: geçidin 200 dönmesi alarmın çalıştığını
kanıtlamaz (abone olunmayan konuya da 200 gelir — ölçülmüş vaka).

## Sınavlar (bu kutuda ÖLÇÜLEN 183 kapı · ATLANAN 1 · hepsi hermetik, çıplak koşulur)

| sınav | kapı | ne ölçer |
|---|---|---|
| `imar.test.sh` | 18 | şalter: fail-closed, kütük, geçişler |
| `imar-defter.test.sh` | 28 | hâl zinciri, A06 kapıları, gerçek deftere sızmama |
| `devir-ayikla.test.sh` | 39 | beş biçim kayması fikstürü, ders kaybı, göz idempotentliği |
| `betik-bekcisi.test.sh` | 19 | üç ölçülmüş tuzak + masumiyet fikstürleri |
| `dersler-brif.test.sh` | 16 | üç başlık ayrımı (ayakta · çürütüldü · ölçülemedi) |
| `imar-ikinci-goz.test.sh` | 26 | gözün kendi sınavı: hükmün kayda ve deftere dönüşü |
| `imar-kutu-bagimsizlik.test.sh` | 30 | 🔴 **beceri MİHENK DIŞINDA bir kutuda kurulur ve koşar** · ilan edilen profil alanı koda BAĞLI mı · sayım dürüst mü |

🔴 **"Hepsi koştu" DENMEZ.** Sınavlar bağımlılık yoksa bazı kapıları *"ATLANDI — ölçülemedi, geçti
sayılmaz"* diye atlar ve süit **yine rc=0** döner; o hâlde toplam "geçti" sayısı tek başına kaç
kapının fiilen koştuğunu söylemez. `imar-sinav-hepsi.sh` bu yüzden **üç sayıyı ayrı** basar:
ölçülen · düşen · **atlanan**. Bu kutuda: ölçülen **183**, atlanan **1**, düşen **0**. Atlanan kapı
yeşil değildir; yalnız kırmızı da değildir — ölçülemedi.

> `imar-defter.test.sh` 29 değil **28** sayar: "gerçek mezarlığa sızıntı" kapısı artık yol
> bildirilmediğinde dürüstçe **atlanır** ve geçti sayılmaz. Eski hâli `/config/projects/mihenk/...`
> diye çiviliydi; başka kutuda o dosya olmadığı için `grep` 0 döner ve kapı **daima yeşil** basardı —
> yani sızıntıyı değil **dosyanın yokluğunu** ölçerdi.

## Taşımanın ortaya çıkardığı kusur (bu beceri onu düzeltti)

`devir-ayikla.test.sh` kendini "hermetik" ilan ediyordu, ama `kutu-eksikleri` defterinin yolunu
**betiğin kendi konumundan** türetiyordu. MİHENK'te o yol gerçek deftere çıkıyordu ve yazma
**sessizce başardı** — bu yüzden on gün kimse görmedi. Kanıt: gerçek defterde A6 fikstürünün satırı
duruyor (`falanca site kutudan okunamıyor`, tur `2026-01-05`). Taşırken yol kırıldı ve kusur
görünür oldu. İki düzeltme: yol profilden gelir (beceri dizinine asla yazılmaz) ve sınav defteri
geçici dizine kurar.

**Ders:** bir sınavın "hermetik" olduğunu **söylemesi** ölçüm değildir; yazdığı her yolun nereye
çıktığı ölçülmelidir. Sessizce başaran bir yazma, çöken bir yazmadan daha pahalıdır.

## Ölçülmüş dersler (paketi kuran kutu bunları tekrar yaşamasın)

- **Cron dar PATH'te koşar** → `claude` görünmez; betik yolu kendi ekler.
- **"İnsansız mı" tahmin edilmez** (`[ -t 0 ]`/`TERM` yanıltır) → cron satırı `CARK_KAYNAK=cron` verir.
- **Boru arkasında rc kaybolur** → ölçümler çıplak koşulur.
- **Alarm 403 = jeton değil YANLIŞ KONU olabilir**; abone olunmayan konuya 200 almak yeşil görünen arızadır.
- **Sessiz sıfır yasak**: biçim dört kez kaydı, ayıklayıcı "taşındı: 0 ders" deyip sustu, iki günün
  altı dersi kayboldu. Artık ders başlığı görünüp hiçbiri okunamazsa **DERS KAYBI** + tur yarım (rc 2).
- **Çöküşün çıkış kodu hükümle çakışmaz**: çöküş rc=1, "çürüyen var" da rc=1 idi → iki gün
  ölçülmemiş şeye hüküm yazıldı. Beklenmeyen hata artık **3**.
- **Hüküm üreticiye ULAŞMADIYSA gün ÖLÇÜLEMEDİ'dir**: göz damgayı deftere basamadığında "uyarıyor"
  ama hükmün koduyla çıkıyordu; karne o günü kusursuz sayıp sayacı ilerletiyordu. **Uyarı bir kapı değildir.**
- **Göz hükmü ezilmez**: ikinci koşu ayrı dosyaya gider, fark basılır.
- **Bir organ hükmünü tekrar ettiremiyorsa o konuda ÖLÇMÜYOR**: aynı tur üç kez göze verildi, üç
  dersin üçünde hükmü değiştiren şey kanıt değil **koşumun kendisiydi**. 🔴 Gözün tutarlılığı
  ölçülmeden gözün hükmü eşik girdisi yapılmaz.
- **En çok onarılan betik en çok sınav isteyen betiktir**: beş sınav 126 kapı taşıyordu ve ikinci
  gözün kendi sınavı YOKTU — oysa bütün yanlış hükümler o betikten çıkmıştı.
- **Adı tahmin eden araç sessizce yanlış ölçer**: kayıt adını yalnız sahibi bilir → araç **sorar**, türetmez.
- **Ölçmediğin şey büyür**: tek dosyalık demo beş günde %28 büyüdü ve açılış süresi hiç ölçülmemişti.
- **Yazılı kuralın koşan kapısı yoksa kural yoktur**; ve kapıyı kurarken **"masum ne yapar" fikstürü,
  "suçlu ne yapar" fikstüründen önce** yazılır (bekçi ilk koşusunda iki masumu suçladı).
- **Onarılan her kayma FİKSTÜR olur**; mutasyon kapısı korumayı söküp sınavın kırmızıya döndüğünü ölçer.

## İki kapı karıştırılmaz (dürüstlük)

**Damga** "düzen kendi başına dönüyor mu" diye sorar; **olgunluk** "bu iş DEVRİYE'ye devredilebilir
mi" diye sorar. MİHENK'te damga doldu (3/3), olgunluk **dolmadı** (2/4). Yani paket **kurulmaya
hazırdır**, o kutudaki iş ise hâlâ İMAR'dadır. Bu beceri kurulum kapısıdır, olgunluk beyanı değildir.

## Bu beceride olmayan (dürüst sınır)

- `pdf/pdf-metin.mjs` ve `tarayici/*.mjs` **taşınmadı**: `npm install` ile kurulan node bağımlılıkları
  var ve bu kutuda Chromium/ws yok. Onları gerektiren 5 kapı MİHENK'te koşar, burada dürüstçe
  **atlanır** ("ölçülemedi, geçti sayılmaz"). Reçetenin "152 kapı" sayısı o beş kapıyı sayar;
  bu kutuda ölçülen 147'ydi. **Sayı, ölçüldüğü kutuya aittir.**
- Sultan yüzü komutları (`.claude/commands/imar*.md`) kutuya kurulurken üretilir; bu paket onları
  taşımaz çünkü komut dosyaları kutunun kendi `.claude` dizinine aittir.
