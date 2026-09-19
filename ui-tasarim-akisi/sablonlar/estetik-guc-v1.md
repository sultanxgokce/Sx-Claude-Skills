# Estetik güç rubriği v1 — "bu ekran ayırt edici mi, şablona mı düştü?"

> Niçin var (ölçüldü, 2026-08-25 · L77): filo'nun bütün UI kapılarında bu soruyu soran
> **tek bir madde yoktu**. `ayırt · özgün · imza · çarpıcı · etkileyici · estetik`
> kelimelerinin rubrikte ve çekirdek sözleşmede eşleşme sayısı: **0**. Akışın kendi metni
> bunu itiraf ediyordu: *"estetik yön — ölçülemez ama işi belirler."*
>
> Bu rubrik o cümlenin ikinci yarısını ciddiye alır. **Çarpıcılığı ölçmez** — ölçemez.
> Ölçtüğü şey: **yargı verildi mi.** Kapı `havuz.py ayirt-kapisi`; yargısız kayıt reddedilir.

## Ne zaman koşar

Her sayfadan sonra, bir sonraki sayfa çizilmeden önce. `prompt-yap.sh` bunu KAPI 6'da
zorlar: önceki sayfa için ayırt-edicilik yargısı yoksa **devam promptu üretilmez**.

Gerekçe kapısıyla (KAPI 5) aynı mantık: *bir sayfadan ders çıkarmadan ikincisini çizmek,
aynı hatayı bütün diziye yaymaktır.* Fark şu: KAPI 5 "kırmızıdan ne öğrendin" diye sorar,
KAPI 6 "bu sayfa kendine benziyor mu" diye.

## İki soru, iki kapalı küme

### 1 · `--klise` — hazır kalıba düştü mü?

Model bir yön SEÇMEZSE **varsayılana** düşer, ve varsayılan konudan bağımsızdır.
Bugün ölçülmüş beş varsayılan:

| değer | ne demek |
|---|---|
| `krem-serif-toprak` | kırık beyaz zemin + serif başlık + toprak tonu vurgu |
| `siyah-neon` | neredeyse siyah zemin + tek parlak yeşil/vermilyon vurgu |
| `gazete-hatti` | kıl payı çizgiler, sıfır köşe yuvarlaklığı, gazete sütunları |
| `mor-gradyan` | beyaz üstünde mor→mavi geçişli hero |
| `merkezli-kart` | her şey ortalanmış, yuvarlak kartlar, aksan şeridi |
| `yok` | hiçbirine düşmedi |

🔴 **Bunlar yasak değil.** Brief açıkça birini istiyorsa doğru cevap odur. Yasak olan,
**seçmeden** oraya düşmek. Bu yüzden alanın adı "yasak" değil "klişe": kayıt tutar, hüküm vermez.

### 2 · `--imza` — sayfanın hatırlanacağı öğe nerede yaşıyor?

Boldluk **tek yere** harcanır; gerisi sessiz durur. Ziyaretçi bir hafta sonra tek bir görüntü
hatırlar — o nerede?

`tipografi` · `malzeme` · `isik` · `oran` · `hareket` · `yerlesim` · `yok`

`yok` meşru bir cevaptır ve **kırmızı demektir**: imzasız sayfa, sözleşmeye uysa bile
başkasının sitesine benzer.

## Hüküm nasıl verilir

- `temiz` — `klise=yok` **ve** `imza≠yok`. Sayfa bir yön seçmiş ve bir yerde cesaret göstermiş.
- `kirmizi` — klişeye düşmüş **ya da** imzasız. `--dusen` ile hangi maddeden düştüğünü yaz.
- `emin-degilim` — meşrudur; ama bir sonraki turda çözülmeli, kalıcı sığınak değildir.

## Sınırlar / dürüstlük

- Bu rubrik **estetik yargı üretmez**, yargının yazılmasını zorunlu kılar. Kimin yargıladığı
  (insan mı ajan mı) ayrı bir konudur ve burada çözülmemiştir.
- Beş klişe **ölçülmüş bir andan** gelir; zamanla değişir. Liste güncellenirse bu dosya ve
  `havuz.py`'deki kapalı küme **birlikte** güncellenir — tek taraflı değişiklik kaydı bozar.
- Kapalı küme bilinçlidir: serbest metin girseydik havuz yine "yorum defteri"ne dönerdi.
