---
name: soluklan
description: Bağlam dolmadan önce DUR, değerlendir, çıpala, compact'i Sultan'a SOR; sonrasında kaldığın yerden daha iyi bir planla devam et. Sultan'ın "%60'ı geçince compact öner" direktifinin tek komutlu karşılığı — ama yalnız compact değil, bir ara-değerlendirme kapısı.
version: 1.0.0
---

# /soluklan — ara ver, bak, çıpala, devam et

## Niçin var (Sultan-direktifi)

Sultan: *"bağlamı kontrol edecek, %60'ın üstü ise compact yapayım mı diye soracak; evet dersem
görevleri çıpalayıp compact yapacak — ve günlük plan gibi, compact'ten önce ve sonra genel bir
değerlendirme yapıp katma değeri yüksek öneriler sunacak, iş planını gözden geçirip güzel bir
planlama da yapacak."*

Yani bu bir **bakım komutu değil, bir düşünme molasıdır.** Compact onun yalnız bir adımı.
Asıl kazanç şurada: uzun bir oturumun ortasında ajan başını kaldırıp *"ne yapıyorum, neyi
atlıyorum, sıradaki en değerli iş ne?"* diye sorar. Bu soru hiç sorulmazsa oturum, başladığı
işi bitirir ama **doğru işi** bitirip bitirmediğini hiç bilmez.

## 🔴 Değişmezler

1. **ÖLÇEMEDİĞİM ŞEY, BAŞTAN:** bu beceri bağlam doluluğunu **ölçemez**. Onu yalnız ajanın
   kendi göstergesi bilir. Sayı araca **dışarıdan** verilir; verilmezse araç *"ölçemedim"*
   der ve **yeşil basmaz** (çıkış 4). Tahmin edilen doluluk, ölçüm değildir.
2. **ÇIPA ÖNCE, SORU SONRA.** Plan diske yazılmadan öneri **üretilmez** (çıkış 3). Bu iyi
   niyete değil kapıya bağlıdır.
3. 🔴 **BAYAT ÇIPA = ÇIPA YOK.** Dünün çıpası da bir dosyadır. Var olan çıpa aracı yalnız
   *"dosya var mı"* diye bakıyordu; bu beceri **tazeliği** de ölçer (bugünün mü, içinde açık
   madde var mı). Bayat bir çıpayla compact'e girmek, kaybolmayacağını sandığın bir planın
   **bayatını** korumaktır.
4. **A06 — compact'i ajan KENDİ KARARIYLA yapmaz.** Araç öneriyi üretir, soruyu Sultan
   cevaplar. Sessizlik onay değildir; "muhtemelen ister" diye geçilmez.
5. **Sultan-dili.** Sultan'a giden gövdede dosya yolu, komut, kod terimi geçmez.
6. **Yeni defter/havuz KURULMAZ.** Plan var olan çıpada yaşar; ikinci bir plan dosyası
   açmak, ilk değişiklikte ikisini de yalancı yapar.

## AKIŞ

### 1 · ÖNCE DEĞERLENDİR (compact'ten önce, çıpadan önce)

Bu adım atlanırsa komut bir bakım tuşuna döner. Dört soruyu **ölçerek** yanıtla:

| Soru | Nereden ölçülür |
|---|---|
| Ne bitti, ne yarım kaldı? | çıpanın kendisi + bu turda koşulmuş kanıt |
| Kimden cevap bekliyorum, kime cevap borçluyum? | odaların gelen/giden kutuları |
| Sultan'ı fiilen ne bekletiyor? | kapıdaki kartlar |
| Hangi iş **kapanabilir**, hangisi yalnız ilerler? | açık PR'lar ve durumları |

`gunluk-plan` becerisinin ölçüm aracı buradaki işi de görür — **ikinci bir ölçüm aracı yazma.**

### 2 · ÇIPAYI TAZELE

Değerlendirmede ne değiştiyse çıpaya işle. Çıpa **kaynak**tır; ekrandaki özet onun kopyasıdır,
tersi değil. Bir madde kapandıysa kapandı yaz; yarım kaldıysa **nerede** kaldığını yaz —
"yarım" tek başına bir sonraki ajana hiçbir şey söylemez.

### 3 · SIRA TAMAM MI (mekanik kapı)

```
bash <bu-dizin>/scripts/soluklan.sh oneri --doluluk <ajanın kendi göstergesi>
```

| Çıkış | Anlamı | Ne yapılır |
|---|---|---|
| 0 | hazır, eşik aşıldı | öneri metnini Sultan'a **olduğu gibi** sun |
| 1 | eşik altı | compact önerme, çalışmaya devam |
| 3 | çıpa yok / bayat / boş / **yaşlı** | **önce çıpayı yaz**, sonra tekrar çağır |
| 4 | doluluk verilmedi | ajan kendi göstergesine bakar; **uydurmaz** |

Eşik varsayılan **%60** (Sultan) ve kural **"üstü"**: tam %60 tetiklemez, %61 tetikler —
Sultan'ın cümlesi *"60'ın üstü ise"*. Çivili değil: `--esik` ya da `SOLUKLAN_ESIK`.
Bozuk eşik/yaş değeri **sessizce 0 sayılmaz**, çıkış 2 ile reddedilir (fail-closed).

### 4 · SOR — tek soru, yığmadan

Araç soruyu üretir; sen **onu** sorarsın. Şıklar 2-4 arası, biri `(önerim)` işaretli.
Burada bir şey daha yap ve bu, becerinin asıl katma değeridir: **soruyla birlikte
"şimdi en değerli iş" önerini de ver.** Sultan compact'e evet derken sıradaki işi de
onaylamış olur; iki tur kazanılır.

### 5 · SONRASI — kaldığın yerden DAHA İYİ devam et

```
bash <bu-dizin>/scripts/soluklan.sh sonrasi
```

Çıpayı **aslıyla** geri basar (özetle değil) ve üç adımı dayatır:

1. **Ortam damgası** — neredeyim, hangi dal, ağaç temiz mi. Compact harness durumunu sıfırlar;
   bayat bağlamla ilk komuta girmek bu filoda ölçülmüş bir hata sınıfıdır.
2. **Çıpayı doğrula** — "açık" damgası bir **iddiadır**, ölçüm değil. Bir madde bu arada
   başkası tarafından kapanmış olabilir.
3. **Yeniden planla** — kapanabilir olanı öne al · kilidi açanı ikinci sıraya · bozuk olanı
   eksik olandan önce koy (bozuk şey yanlış güven üretir) · görünmez altyapı ile Sultan'ın
   ekranında değişen iş arasında seçim gerekiyorsa ikincisini sun.

Çıpa yoksa araç **plan uydurmayı yasaklar** ve "planı kaybettim" demeni ister. Kaybı gizlemek,
kaybın kendisinden pahalıdır.

## Sınırlar / dürüstlük

- Bu beceri **compact'i çalıştırmaz**; onu Sultan başlatır. Araç sırayı ve dürüstlüğü korur.
- Doluluk sayısı ajanın beyanıdır; araç onu doğrulayamaz — bunu her koşuda söyler.
- Çıpa tazeliği **iki** şeye bakar: bugünün mü, ve son `SOLUKLAN_AZAMI_YAS_DK` dakikada
  (varsayılan **240**) dokunulmuş mu. İlk yazımda yalnız tarihe bakıyordu ve "aynı gün
  bayatlamayı yakalayamam" diye **dipnot düşmüştüm** — bağımsız göz haklı olarak itiraz etti:
  *belgelemek onarmak değildir*, ölçülebilir bir şeyi ölçmeyip dipnota yazmak kapıyı süse çevirir.
  Yaş iki yüzeyden okunur (çıpanın kendi damgası + dosyanın değişme zamanı), taze olan kazanır.
- Gerçek sınır şu: araç çıpanın **güncel** olduğunu değil, **dokunulduğunu** ölçer. Bir ajan
  çıpayı anlamsızca tazeleyip kapıyı geçebilir — ikinci yarısı hâlâ 5. adımdaki doğrulamadır.
- Kendi sınavı: `bash scripts/soluklan.test.sh` (41 kapı, hermetik — gerçek çıpaya dokunmaz).
  İki **mutasyon** kapısı: tazelik kapısı öldürülünce bayat çıpa öneri üretir hâle gelir,
  "ölçemedim" kapısı öldürülünce doluluksuz çağrı yeşile döner. Yani korumalar süs değil.
