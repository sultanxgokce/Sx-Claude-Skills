---
name: gorsel-yon
type: workflow
version: 0.2.0
description: >
  Üretilmiş görselle YÖN ARAYIŞI — kanıt üretmez. Nova/mimarlık sitesi gibi iddiası
  "gerçek iş" olan yüzeylerde, üretilmiş görselin nereye girip nereye giremeyeceğini
  KODLA zorlar. "görsel yön · kompozisyon denemesi · zemin dokusu · geçiş dili"
  tetiğinde. Higgsfield hattı; varsayılan KURU-KOŞUM (kredi harcamaz).
---

# gorsel-yon — üretilmiş görsel nereye girer, nereye giremez

## Niçin var

Nova sitesinin tüm iddiası **gerçek iş**. Üretilmiş bir görsel o iddiayı taşıyamaz —
Sultan'ın dairesinin gerçek fotoğrafı ve gerçek çizimi yerine geçemez. Ama yön aramak,
zemin dokusu denemek ve geçiş dilini göstermek üretilmiş görselle **yapılabilir**.

Sorun şuydu: bu ayrım bir belgede yazılıydı, hiçbir kapıda koşmuyordu.

## 🔴 SINIR — ölçüt "üretilmiş mi" DEĞİL, "KANIT konumunda mı"

Bu ayrım aracın çekirdeğidir ve **kodda yaşar**, belgede değil.

> Bir görselin yanında **hafta · çizim · karar** duruyorsa, o görsel **kanıttır** →
> gerçek olmak **zorundadır**. İddia taşımayan yüzey (zemin, geçiş, boşluk) üretilmiş olabilir.

Bu ölçüt "render yasak"tan daha keskin ve **sınanabilir**: zarar üretilmiş piksel değil,
**kanıt yerinde duran üretilmiş görseldir**.

| İzinli alan | Ne demek |
|---|---|
| `yon-arayisi` | kompozisyon/ışık denemesi — **siteye girmez**, atılacak taslak |
| `doku-zemin` | içerik iddiası taşımayan soyut yüzey |
| `hareket-dili` | geçişin nasıl olacağını **gösteren** örnek, içerik değil |

Bu üçünün dışı **reddedilir** (kapalı küme, `--kullanim` zorunlu).

## Üç kapı — hepsi fail-closed

1. **Kullanım alanı kapısı** — kapalı küme dışı → `rc=1`
2. **Kanıt-konumu kapısı** — istemde `vaka·proje·şantiye·çizim·daire·mahal·portfolyo·referans`
   geçerse → `rc=1`. Vaka görselleri gerçek olmak zorunda.
3. **B3 kapısı** — `lüks·altın·mermer·render·3d·fotogerçekçi·stok` → `rc=1`
   (Sultan'ın yasakladığı yön)

**Yön çiti:** her isteme Sultan'ın seçtiği yön (B1/B4/B5) otomatik eklenir ve
**çıkarılamaz** — yumuşak yayılı gündüz ışığı · doğal ahşap + mat antrasit · süs yok ·
telefonda gece okunabilir.

## Kullanım

```
gorsel-yon.sh dogrula                       # anahtar geçerli mi — KREDİ HARCAMAZ
gorsel-yon.sh kullanimlar                   # izinli alanlar
gorsel-yon.sh uret --kullanim doku-zemin --istem "..."          # KURU-KOŞUM
gorsel-yon.sh uret --kullanim doku-zemin --istem "..." --uygula # gerçek üretim (kredi harcar)
```

🔴 **Varsayılan kuru-koşum.** `--uygula` verilmedikçe istek gönderilmez, kredi harcanmaz.

## Ölçülmüş tuzaklar (tekrar düşmemek için)

- **Uç adresi:** taban `platform.higgsfield.ai/<yol>` — **`/v1` ÖNEKİ YOKTUR.**
  `/v1/...` denenirse her şey **405** döner ve "anahtar bozuk" sanılır. Kök neden
  anahtar değil **adrestir** (2026-08-23'te bu tuzağa düşüldü).
- **Anahtar kasada:** `secret/nexus/HIGGSFIELD_API_KEY` (openbao). `.env`'de **yok**.
  Araç `vault-cek get` ile çeker; değer **stdout'a basılmaz**.
- **Kredi-harcamayan sınama:** `GET /requests/<uydurma-uuid>/status` →
  anahtarLA **404**, anahtarSIZ **401**. **Farkı** kimliğin kabul edildiğini kanıtlar.
  Negatif-kontrollü; ölçüm için kredi harcamak gerekmez.

## Sınırlar / dürüstlük

- Bu araç **çarpıcılık üretmez**, çarpıcılık ararken sınırı korur.
- Higgsfield **kıtlık sorununu çözmez**: site tek tamamlanmış işle açılacak. Üretilmiş
  görsel o boşluğu dolduramaz ve doldurmamalı — boşluğun dürüst tasarımı ayrı iştir.
- `dogrula` uç sessizse **rc=3 (ölçemedim)** döner, "anahtar bozuk" DEMEZ.

## Sürüm notları

- **0.1.1 (2026-08-25) — ilk gerçek çağrı ONARILDI.** v0.1.0 gövdeyi `{"params":{"prompt":…,"quality":"1080p"}}`
  diye gönderiyordu; uç `prompt`'u **kökte** ister ve `quality` diye bir alan **yoktur** (sessizce yok sayılır,
  doğrusu `resolution`). Yani `uret --uygula` her çağrıda **422** alacaktı. Fark edilmemişti çünkü araç
  kurulduğu günden beri bir kez bile `--uygula` ile koşulmadı — [[feedback_test_var_kapida_degil]] deseni.
  Kanıt (kredi harcamayan negatif-kontrollü prob, 2026-08-25):
  `{"params":{"prompt":"x"}}` → 422 `loc=["body","prompt"] "Field required"` ·
  aracın YENİ gövdesi yalnız `resolution` kasten bozulunca 422 verdi → öbür alanların hepsi kabul edildi.
  ⚠️ Dürüst sınır: **gerçek bir görsel üretilmedi** (kredi harcanmayacaktı diyemem) — doğrulama
  şema-katmanında bitti; ilk gerçek üretimin kalitesi hâlâ ölçülmedi.
  Üç fail-closed kapı (kullanım alanı · kanıt-konumu · B3 yasak listesi) onarımdan sonra yeniden sınandı: 0/1/1.

- **0.2.0 (2026-08-25) — GAZ KATMANI: araç ilk kez fiilen görsel getiriyor.**
  v0.1 yalnız istek **gönderiyordu**. Uç asenkron çalışır (`{"status":"queued","request_id":…}`);
  bekleyen/indiren hiçbir şey yoktu → üretilen görsele **hiçbir zaman ulaşılamazdı**. Yani onarılan
  422'nin arkasında ikinci bir sessiz duvar varmış. Eklenenler:
  - `bekle <istek-kimliği> [--indir <dizin>] [--azami <sn>]` — durumu yoklar, biter bitmez adresleri
    çıkarır ve indirir. **Süre dolarsa "düştü" DEMEZ** (RC=3, "hâlâ sürüyor olabilir").
  - `defter` — her GERÇEK çağrı `~/.claude/gorsel-yon-defteri.jsonl`'e düşer (alan · adet · istek ·
    durum · fiilen gelen kare). 🔴 **Adet sayar, lira saymaz** — birim kredi maliyeti ölçülemedi.
  - `--sayi 4` artık gerçekten çalışıyor (`batch_size`), `--oran` eklendi (varsayılan 16:9).
  - Kuru-koşum deftere YAZMAZ: kredi harcanmayan çağrı harcama kaydı üretmez.

  **Ölçülmüş ders — soyut istem konu uyduruyor:** *"mat sıva yüzey, dokulu, içerik yok"* denildiğinde
  model boş bir yüzey değil, **ahşap masada bir cihaz** üretti. Soul bir sahne/ürün modelidir; konusuz
  istemi konusuz bırakmaz. Panzehir ölçüldü ve tuttu: istemi **sahneye çıpala** ("empty interior
  corner, bare plaster wall meeting pale oak floor, raking daylight… absolutely no objects no
  furniture no people") → 4/4 kare temiz geldi. Kanıt: istek `8c3fba2b…`, 4 kare, hepsi boş mekân.
