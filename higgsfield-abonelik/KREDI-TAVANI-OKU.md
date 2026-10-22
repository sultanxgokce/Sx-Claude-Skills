# 🔴 KREDİ TAVANI — pakette ANLATILIYORDU ama TAŞINMIYORDU (7 Eylül, düzeltildi)

## Kusur bendeydi

Bu devir paketini hazırlarken üç ayrı yerde şöyle yazdım: *"kredi tavanı deseni hazır
bekliyor, beş dakikalık iş."* Sonra ölçtüm — **yanlıştı.** Paket tavanı **anlatıyordu**
(skill metninde `bogaz_kredi_tavani` geçiyor) ama **taşımıyordu**: `bogaz.lib.sh` pakette
yoktu, yani o işlev **çağrılamıyordu**.

Yani doktrini devrediyordum, **uygulamayı değil.** Bu paketi alan kutu, tavanın ne olduğunu
okuyup tavansız üretim yapardı — ve en tehlikeli hâl budur: *kuralı bilen ama kuralı
uygulayamayan bir kutu, kuralı hiç duymamış kutudan daha emin hisseder.*

**Eklendi:** `scripts/bogaz.lib.sh` · `scripts/defter.sh` · `DEFTER-SEMA.md`.

## Niçin bu üçü birlikte gider

| Parça | Ne yapar | Olmazsa |
|---|---|---|
| `bogaz_kredi_tavani` | üretimden **önce** öngörülen krediyi tavanla karşılaştırır, aşarsa **çağrı yapılmaz** | havuz sessizce erir |
| `bogaz_defter` | her üretimi deftere yazar; **yazamazsa RC 1** | harcama ölçülmemiş kalır |
| `DEFTER-SEMA.md` | zorunlu alanlar | eksik satır = ölçülemeyen harcama |

## Kullanımı

```bash
. scripts/bogaz.lib.sh

BIRIM=$(bash <adaptor> --birim-kredi)          # ör. flux_kontext -> 1.5, seedance_2_5 -> 32.5
bogaz_kredi_tavani "$BIRIM" "${TAVAN:-50}" "$ADIM_SAYISI" || exit 1
#   ↑ ÇAĞRIDAN ÖNCE. Sonra sormak, parayı harcadıktan sonra bütçeye bakmaktır.
```

Varsayılan tavan **50 kredi**. Tavanı yükseltmek **Sultan-gate**'tir — abonelik kredisi de
bir bütçedir, "zaten ödenmiş" olması onu bedava yapmaz.

## 🔴 Bilmen gereken iki rakam
- Havuz **ortak**: ~2.900 kredi, hepimiz aynı abonelikten yiyoruz.
- **Bir video 32,5 kredi.** Tavansız bir döngü, kimsenin kötü niyeti olmadan gecede yüzlerce
  kredi harcar. Görselde risk küçük (1,5), videoda büyük.

## Ve krediyi göstergeden okuma
`higgsfield account status` **her zaman "3000" diyor — yalan.** Gerçek bakiye
`account transactions` defterinden okunur. Bu ölçüldü; göstergeye bakan bir tavan, tavan değildir.

## `defter.sh` için tek uyarı
Betik defteri **git köküne göre** buluyor (`uretim/defter.jsonl`). Kendi kutunda başka bir
yol istiyorsan `TELLAL_DEFTER=<yol>` ile ver — ama **`/dev/null` verme**: defterin yazıldığını
doğrulayamazsan sayaç, ölçülmemiş bir harcamayı ölçülmüş gibi gösterir.

— MEDDAH
