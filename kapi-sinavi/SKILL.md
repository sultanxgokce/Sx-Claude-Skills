---
name: kapi-sinavi
type: agent
version: 1.0.0
description: >
  Bir KAPININ gerçekten kapı olduğunu kanıtlar. Kapının doğru karar verdiğini değil —
  DEVREDE olduğunu, SINAVININ onu fiilen ölçtüğünü ve son yeşil koşumdan sonra
  DEĞİŞMEDİĞİNİ ölçer. Dört komut: kos · bagli-mi · bayat-mi · mutasyon (sil/no-op/
  yer-kaydırma). 🔴 RC=3 ÖLÇÜLEMEDİ demektir, yeşil değil. Mutasyon gerçek ağaca
  dokunmaz, geçici kopyada koşar. "kapı yazdım / koruma ekledim / bu gate çalışıyor mu"
  tetiğinde; merge kapısından çağrılır.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
---

# kapi-sinavi — "kapı var" demek yetmez

## Niçin var (ölçülmüş, 2026-08-23)

e-Logo hattının derin kazısında **iki bağımsız kol** aynı köke vardı. Bir gecede aynı
hastalığın dört vakası ölçüldü ve **dördü de yeşil görünüyordu**:

| # | Vaka | Görünen | Gerçek |
|---|---|---|---|
| 1 | Tıklama muhafızı | 14/14 sınav geçti | Onu çağıran **tek bir satır yoktu** |
| 2 | İkinci koruma fonksiyonu | Beceri metni onu kanon gösteriyordu | **Hiçbir yerden çağrılmıyordu** |
| 3 | Muhafızın izin listesi daraltıldı | "kapı sıkılaştı" | Sınav güncellenmedi → **13/14 kırmızı**, kimse görmedi |
| 4 | Muhafız alt-dizge eşleştiriyordu | 14 sınav vakası yeşil | **Hiçbiri yakın-kaçış değildi**; tehlikeli düğmeler izin alıyordu |

Ortak kök tek cümle: **kapının VARLIĞI, etkinliğinin kanıtı sayıldı.**
Mevcut sınavlar *"kapı doğru karar veriyor mu"* sorusunu ölçüyordu. Hiçbiri şunları sormuyordu:

> **Bu kapı devrede mi?** · **Bu sınav gerçekten bu kapıyı mı ölçüyor?** · **Bu yeşil ne zamanki koda ait?**

Bu beceri o üç soruyu makineye sordurur.

## Değişmezler

- 🔴 **RC=3 = ÖLÇÜLEMEDİ, YEŞİL DEĞİL.** Ölçemediğimiz kapı "temiz" sayılmaz. `denetle`
  kırmızı yokken ölçülemeyen kalem varsa **3 döner ve ekrana "Bu YEŞİL DEĞİLDİR" basar**.
- 🔴 **Mutasyon gerçek ağaca DOKUNMAZ.** Her mutasyon projenin geçici bir kopyasında koşar.
  Bu bir güvenlik aracıdır; kendi koşumunda risk üretemez. (Sınavta sha ile kilitli.)
- 🔴 **Kapı YAZMAZ, kapı ONAYLAMAZ.** Yalnız ölçer ve bulgu basar. Kırmızıyı açma yetkisi
  bu araçta değildir.
- 🔴 **ANMAK ≠ ÇAĞIRMAK.** Bir adın üretim dosyasında geçmesi onun çağrıldığı anlamına
  gelmez. `.py` dosyaları AST ile ayrıştırılır; yorum/dizge/dokümantasyon sayılmaz.

## Defter — `.kapi/kapilar.json`

```json
{
  "v": 1,
  "kapilar": [
    {
      "ad":       "muhafiz",
      "dosya":    "scripts/muhafiz.py",
      "cagri":    "tiklanabilir_mi",
      "sinav":    "scripts/muhafiz.test.sh",
      "girisler": ["scripts/portal.py"],
      "mutasyon": "python"
    }
  ]
}
```

| Alan | Anlamı | Zorunlu |
|---|---|---|
| `ad` | kapının adı (tekil) | ✅ |
| `dosya` | kapının tanımlandığı dosya | ✅ |
| `cagri` | çağrılması gereken fonksiyon adı | ✅ — yoksa bağlılık ölçülemez |
| `sinav` | kapının sınav dosyası | ✅ — **sınavı olmayan kapı, kapı değildir** |
| `girisler` | kapıyı çağırması BEKLENEN üretim dosyaları | beyan edilmezse `bagli-mi` **3** döner |
| `mutasyon` | mutasyon dili (şimdilik `python`) | varsayılan `python` |

## Komutlar

```
kapi-sinavi.sh kayit                 defteri doğrula (dosyalar var mı, alanlar tam mı, ad tekil mi)
kapi-sinavi.sh kos      [ad]         sınavı ÇIPLAK koş; yeşilse kapının sha'sını damgala
kapi-sinavi.sh bagli-mi [ad]         kapı fiilen ÇAĞRILIYOR mu (AST tabanlı)
kapi-sinavi.sh bayat-mi [ad]         kapı son yeşil koşumdan sonra değişti mi
kapi-sinavi.sh mutasyon <ad>         sil · no-op · yer-kaydırma — üçü de KIRMIZI yakmalı
kapi-sinavi.sh denetle  [--mutasyon] hepsi, tek RC
```

**Çıkış kodları:** `0` temiz · `1` BULGU · `2` kullanım/ortam · `3` ÖLÇÜLEMEDİ

`denetle` sırası bilinçlidir: **`bayat-mi`, `kos`'tan ÖNCE** koşar. Aksi hâlde `kos` yeni
damgayı yazar ve bayatlık kapısı kendi ölçtüğü şeyi tazeler — hiç ateşlemez. Doğru soru
*"ben geldiğimde bu kapının son yeşil koşumu güncel miydi?"*

## Üç mutasyon sınıfı — her biri farklı bir yalanı yakalar

| Mutasyon | Ne yapar | Sınav yeşil kalırsa ne demektir |
|---|---|---|
| **sil** | kapı fonksiyonu yok edilir | Sınav kapıya **hiç dokunmuyor** |
| **no-op** | kapı hep izin verir | Yalnız **izin** yolu sınanıyor, **ret** yolu sınanmıyor |
| **yer-kaydırma** | kapı durur, **çağrı** kaldırılır | **Bağlantı sınavı yok** — kapı devreden çıksa kimse fark etmez |

Ön koşul: mutasyonsuz hâl yeşil olmalı. **Kırmızıdan kırmızıya geçiş hiçbir şey kanıtlamaz**
→ sınav zaten kırmızıysa `mutasyon` RC=3 döner (ölçüm reddedilir, sahte yeşil üretilmez).

## Sınırlar — dürüstçe

- `bagli-mi` **statik**tir. *"Çağıran yok"* hükmü **kesindir** (0 eşleşme çürütülemez).
  *"Bağlı"* hükmü **yaklaşıktır** — çağıran satır ölü bir kolda olabilir. Bu yüzden
  `girisler` beyan edilmemişse sonuç yeşil değil **ÖLÇÜLEMEDİ** olur.
- `.py` için AST kullanılır (kesin). `.sh/.js/.ts` için satır temelli yaklaşım kullanılır ve
  yorum satırları elenir — **yaklaşıktır**.
- `mutasyon` yalnız Python kapıları için uygulanır; başka dil → RC=3, sessiz yeşil YOK.
- Mutasyon projenin tamamını kopyalar → çok büyük depolarda yavaştır. `denetle` varsayılan
  olarak mutasyon **koşmaz** (`--mutasyon` ile açılır).

## Çağıran kim (bu becerinin kendi kapısı)

Bu beceri gönüllülüğe bırakılmaz — kurulduğu derste tam olarak o hata ölçüldü.
**Çağıranı merge kapısıdır:** bir PR'ın farkı defterde kayıtlı bir kapı dosyasına
dokunuyorsa, `denetle` yeşil (ya da en azından kırmızısız) olmadan merge edilmez.

## Kanıt

`scripts/kapi-sinavi.test.sh` → **28 kapı**, hermetik (gerçek hiçbir depoya dokunmaz, her
vaka kendi geçici fikstür-projesini kurar). Kapsanan negatifler: sınavsız kapı · çift ad ·
bozuk defter · kırmızı sınav · **çağıran yok** · **yalnız yorumda anılıyor** · yanlış giriş
noktası · girişsiz (→3) · damgasız (→3) · bayat kapı · üç mutasyonun yakalanması ·
mutasyonun gerçek ağaca dokunmadığının **sha ile** kanıtı · zaten-kırmızı sınav (→3) ·
`denetle` RC birleştirme kuralı · bilinmeyen komut · olmayan kapı adı.

**Gerçek-veri regresyonu:** araç, canlı `elogo-portal-otomasyon` becerisinin bir kopyasına
koşuldu ve **kurulduğu kusuru yakaladı**: `guvenli_tikla` — yazılmış, beceri metninde kanon
gösterilmiş, **hiçbir yerden çağrılmıyor**.

> ⚠️ Bu regresyon aynı zamanda aracın KENDİ kusurunu ortaya çıkardı: ilk sürüm düz metin
> araması yapıyordu ve `guvenli_tikla` için *"bağlı (1 çağıran)"* dedi — çünkü o ad üretim
> dosyasında yalnız bir açıklama satırında geçiyordu. **Araç, yakalamak için yazıldığı
> hastalığa kendisi yakalandı.** AST'ye geçildi, regresyon sınavı eklendi. Bu satır
> silinmiyor: bir aracın kendi hastalığına yakalanabildiğinin kaydıdır.
