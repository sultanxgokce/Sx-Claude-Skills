# ÜRETİM DEFTERİ — ŞEMA (G2)

> `uretim/defter.jsonl` — **append-only**, satır başına bir üretim denemesi.
> Yazan: `scripts/defter.sh ekle` (elle düzenleme yapma — alan doğrulaması atlanır).
>
> **Neden var:** Pilotun çıktısı video değil **kanıt**. Bu defter dört işi birden görür:
> §6 bütçe-sayacı · kill-kriteri (a) lip-sync kanıtı · fiyatlama zemini · G5 acı-sayacının veri kaynağı.
> **Kaydedilmeyen üretim yoktur** — sonradan toparlanmaz.

## Alanlar

| Alan | Zorunlu | Tip | Açıklama |
|---|---|---|---|
| `tarih` | oto | ISO-8601 | `defter.sh` basar, elle verilmez |
| `is_id` | ✅ | metin | **bir iş** = bir video hedefi. Aynı işin tekrar denemeleri aynı `is_id`'yi paylaşır. G5 sayacı bunu sayar. |
| `arac` | ✅ | metin | `higgsfield` · `heygen` · `elle` … Araç bir **kolondur** — tarif ondan bağımsızdır (G3). |
| `model` | ✅ | metin | araç içindeki model/preset (`soul` · `avatar-v` · `kling-3` …) |
| `sure_dk` | ✅ | sayı | **insan-emeği** dakikası. Makine bekleme süresi değil — "şak şak hızlı" iddiasının kanıtı budur (G11). |
| `deneme_no` | ✅ | tamsayı ≥1 | bu `is_id` için kaçıncı deneme |
| `tarif_ref` | ✅ | metin | `tarif/` altındaki kartın adı. G5 acı-sayacı bu alandan sayar. |
| `kredi` | ◐ | sayı | araç kredisi (kredi-faturalı araçlarda) |
| `maliyet_usd` | ◐ | sayı | gerçek para (API/abonelik payı) |

> ◐ **MALİYET BEYANI ZORUNLU (F0.4, 2026-08-15 · anayasa §6).** `kredi` ve `maliyet_usd`
> alanlarından **en az biri** her üretim satırında bulunmalıdır; ikisi de yoksa satır **yazılmaz**.
> Üretim bedavaysa **açıkça `maliyet_usd=0`** yazılır — sessiz yokluk ile beyan edilmiş sıfır aynı
> şey değildir. Kural "kredi zorunlu" DEĞİLDİR ve bu bilinçlidir: ölçüldüğünde 12 üretim satırının
> 12'sinde `maliyet_usd` doluydu, `kredi` boştu — para tutuluyordu, kredi birimi tutulmuyordu.
> Yeni kural mevcut 12 satırın hepsini geçirir (geriye dönük yalan üretmez, kapıda sınanıyor).
> Düzeltme/olay satırları muaftır (üretim değildirler).
| `lipsync_notu` | ○ | 1-5 | Türkçe dudak-senkronu kalitesi. **Kill-kriteri (a)'nın tek veri kaynağı** — konuşan videoda boş bırakma. |
| `hook_metni` | ○ | metin | videonun ilk cümlesi (A/B karşılaştırması için) |
| `uyum_ok` | ○ | `evet`/`hayir` | `scripts/uyum-lint.sh` RC=0 verdi mi |
| `yayin_kanali` | ○ | metin | `tiktok` · `meta` · `trendyol` · `portfoy` · `-` |
| `ctr` | ○ | sayı | yayın sonrası tıklama oranı (7-14 gün sonra geri dönülüp eklenir) |
| `not` | ○ | metin | serbest gözlem |

## Kullanım

```bash
# satır ekle (zorunlu 6 alan eksikse REDDEDİLİR)
bash scripts/defter.sh ekle is_id=mmex-kulaklik-01 arac=higgsfield model=soul \
     sure_dk=12 deneme_no=1 tarif_ref=ornek-fotograftan-reklam lipsync_notu=4 kredi=30

# araç-başı özet (bütçe + lip-sync ortalaması + eksik-veri uyarısı)
bash scripts/defter.sh ozet

# acı-sayacı: bu tarif elle kaç KEZ (kaç ayrı iş) yapıldı → G5 kapısı bunu okur
bash scripts/defter.sh sayac ornek-fotograftan-reklam
```

## Değişmezler

- **Append-only.** Satır silinmez, düzeltilmez; yanlışsa `not` alanlı yeni satır eklenir.
- **`sayac` ayrı `is_id` sayar**, satır değil — 1 işi 5 kez denemek "5 kez yaptım" değildir.
- **Sır-değer yazılmaz** (API key, token, müşteri kişisel verisi). Defter META tutar.

---

## Düzeltme kayıtları (append-only'nin dürüstlük kolu) — 2026-07-25

Defter **append-only**: yanlış bir satır **silinmez, değiştirilmez**. Ama olduğu gibi de bırakılmaz —
üstüne bir **düzeltme kaydı** düşülür ve okuyucular bunu hesaba katar.

```bash
# "bu is_id aslında şu işin varyantıydı" (sayaç şişmesini geri alır)
bash scripts/defter.sh duzelt duzeltir=<is_id> ayni_is=<dogru_is_id> sebep="..."
# "bu alanın değeri yanlıştı"
bash scripts/defter.sh duzelt duzeltir=<is_id> alan=<ad> dogru_deger=<v> sebep="..."
```

**Değişmezler:** `sebep` zorunlu · düzeltilen `is_id` defterde **gerçekten** bulunmalı (uydurma
düzeltme yazılamaz) · `sayac` `ayni_is` birleştirmelerini **uygular** (zincirli birleştirme çözülür),
aksi halde kayıt kozmetik kalır ve şişkin sayaç G5 kapısını açık tutmaya devam ederdi.

### Bu mekanizmayı doğuran iki gerçek hata (MEDDAH, 2026-07-23)

| # | Ne oldu | Düzeltme |
|---|---|---|
| **K7** | TEST-A **tek işti** (aynı metin, aynı avatar, yalnız ses değişti) ama 5 ayrı `is_id` yazıldı → `sayac test-a` = 5, G5 terfi kapısı (≥3) **canlı veriyle açıldı**. SEMA'nın kendi değişmezi ihlal edildi: *"1 işi 5 kez denemek '5 kez yaptım' değildir."* | 4 varyant `testa-emre-kadir`'e bağlandı → **sayaç 5 → 1**, kapı kapandı |
| **K8** | 5 satır `uyum_ok=evet` taşıyordu; oysa o satırlar için **hiç `TESLIMAT.md` oluşturulmadı**, yani `uyum-lint` hiç koşmadı. Kalıcı kanıt defterine 5 kez doğru-olmayan uyum beyanı düştü | 5 düzeltme kaydı: `uyum_ok=hayir` — iç ölçümdü, teslimat değildi |

**Kalıcı çözüm (D9) — YAPILDI, 2026-08-15.** `uyum_ok` artık elle yazılamaz:
`uyum-lint.sh <dizin> --makbuz <yol>` makbuzu **yalnız RC=0 yolunda** yazar; `defter.sh`
`uyum_ok=evet`i yalnız makbuzla kabul eder. Makbuz bir **sır değildir**, bu yüzden tek başına
yeterli sayılmaz — `defter.sh` makbuzun gösterdiği dizinde **lint'i yeniden koşar**.
**Hakem makbuz değil, lint'in kendisidir.** Reddedilen durumlar: makbuzsuz · uydurma makbuz ·
bayat makbuz (TESLIMAT.md ya da artefakt makbuzdan sonra değişmiş) · lint'in şu an kırmızı olması.
Dördünde de defter satırı **yazılmaz**. `uyum_ok=hayir` makbuzsuz serbesttir — iç ölçüm meşrudur;
K8'in hatası zaten "hayır demek" değil, "evet demek"ti. Kapı `kapi-testi.sh [2d]`'de 13 iddiayla
sınanıyor ve mutasyon kanıtlı (şart kaldırılınca 7 iddia kırılıyor).
