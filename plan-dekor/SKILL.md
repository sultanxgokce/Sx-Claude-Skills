---
name: plan-dekor
type: agent
version: 0.6.0
description: >
  2B kat planını RENKLİ, MOBİLYALI sunum planına çevirir. Boş odalara oda tipine göre mobilya
  YERLEŞTİRİR (kural-tabanlı, deterministik — kapı kanadının süpürme alanı boş kalır, mobilya
  duvara/başka mobilyaya giremez, oda dışına taşamaz), zemin dokusu + oda renkleri + lejant +
  kuzey oku + ölçek çubuğuyla SVG/PNG üretir, doğal-dil revizyonunu yapısal tarifle uygular.
  plan-motor'u CLI sınırından BESTELER (doğrulama/denetim onun kapısından geçer) — mobilya ve
  renk katmanı bu pakete aittir. Fail-closed: zorunlu program sığmazsa ya da render öz-denetimi
  kırmızıysa hiçbir dosya YAZILMAZ. Deterministik ($0, API yok, GPU yok): aynı girdi → aynı sha256.
  "planı renklendir", "renkli kat planı", "boş odaya mobilya koy", "mobilya yerleşimi öner",
  "emlak sunum planı", "planı dekore et" tetiğinde.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [kat-plani, mobilya, yerlesim, renklendirme, sunum, emlak, svg, fail-closed, deterministik]
status: v0.6
---

# plan-dekor — renkli, mobilyalı sunum planı motoru

> **Jenerik motordur: hiçbir projenin iş mantığını bilmez.** Müşteri, fiyat, teklif, marka burada
> YOK — onlar çağıran projenin işidir. plan-motor'un paketleme sözleşmesinin aynısına uyar.

## NE-DİR

Girdi bir **plan-motor model.json**'udur (CAD'den türetilmiş ya da elle kurulmuş). Çıktı:
renkli zemin dokulu, mobilyası yerleştirilmiş, lejantlı **sunum planı** (SVG + PNG) + ayrı bir
`yerlesim.json` katmanı + `KOKEN.md` beyanı.

**İki iş yapar, ikisi de veriyle sürülür:**
1. **Mobilya yerleştirme** — `katalog/mobilya.json` (semboller+ölçüler) × `katalog/program.json`
   (oda tipi → mobilya programı) × `kural-seti/mobilya-TR.json` (kısıtlar).
2. **Renklendirme** — `tema/*.json` (oda-tipi renk + doku + gölge + lejant biçimi).

Eşikler ve renkler **motorda değil veride** yaşar; yeni tema/mobilya eklemek kod değiştirmez.

## Kurulum

```bash
bash "$SKILL_DIR/kur.sh"     # bağımlılık YOK — ortam doğrulaması + duman testi
```
Gereksinim: **node ≥ 22** + **plan-motor** (kardeş skill; `requires: [plan-motor]`).
PNG üretimi plan-motor'un `sharp`'ını kullanır → `bash <plan-motor>/kur.sh` bir kez koşmuş olmalı.

## Komutlar

```bash
node cli.mjs mobilya --model m.json --cikti y.json [--adet 3] [--oda id,id] [--kismi-kabul]
node cli.mjs ciz     --model m.json [--yerlesim y.json] [--aday 1] --cikti p.svg [--png p.png]
                     [--tema modern-sicak|nordik-acik|emlak-kontrast] [--lejant-yok]
node cli.mjs cipa    --model m.json --cipa c.json [--tolerans 3] [--rapor r.json]   # ölçek kapısı
node cli.mjs denetle --model m.json --yerlesim y.json [--rapor r.json]
node cli.mjs revize  --model m.json --yerlesim y.json --degisiklik d.json --cikti yeni.json
node cli.mjs akis    --model m.json --cikti-dizin teslim/ [--adet 3] [--tema T]   # ← tek komut
node cli.mjs temalar · node cli.mjs katalog
```
Çıkış kodları **plan-motor ile aynı**: `0` başarı · `1` doğrulama/fail-closed (çıktı YAZILMAZ) ·
`2` kullanım · `3` iç hata.

## 🤖 AJAN PROTOKOLÜ — ezberden değil, buradan koş

Sultan "şu planı renklendir + mobilyasını yerleştir" dediğinde izlenecek NET sıra.
Her adımda: komut → beklenen RC → **kırmızıda ne yapılacağı**. Adım atlanmaz.

| # | Adım | Komut | Kırmızıda (RC≠0) |
|---|---|---|---|
| 1 | **Girdiyi sınıfla** | uzantı: `.dwg/.dxf` → 2a · `.png/.jpg/.pdf` → 2b · `.json` → 3 | bilinmeyen format → Sultan'a sor |
| 2a | **CAD'i say** | `plan-motor oku --dosya x.dxf` → `plan-motor goster --dosya x.dxf --cikar-json g.json` → `python3 <plan-motor>/lib/lifting.py g.json m.json` | çizim kapsam dışı (eğik duvar/etiketsiz oda) → dürüstçe bildir, **uydurma** |
| 2b | **Görselden dijitalleştir** | Görseli oku, `model.json`'u ELLE kur (otomatik vektörleştirme YOK). Görselde yazılı **en az 2 gerçek ölçüyü** çıpa olarak not al | çıpa bulamıyorsan → **DUR**, Sultan'dan bir duvar ölçüsü iste, tahmin etme |
| 2c | **ÖLÇEK KAPISI** (model CAD'den gelmediyse ZORUNLU) | `plan-dekor cipa --model m.json --cipa c.json` | RC 1 → model ölçü kanıtı taşımıyor. **Mobilya/çizim aşamasına GEÇME**, geometriyi düzelt |
| 3 | **Modeli doğrula** | `plan-motor dogrula --model m.json` | geometri hatası → düzelt; **ilerleme YOK** |
| 4 | **Onay al** (model elle/görselden kurulduysa) | `plan-dekor ciz --model m.json --cikti taslak.svg` → Sultan'a göster | "hayır" → 2b/3'e dön |
| 5 | **Mobilya yerleştir** | `plan-dekor mobilya --model m.json --cikti y.json --adet 3` | *sığmadı* → hangi oda + hangi zorunlu mobilya raporda yazılı. Sultan'a sor. **Kendiliğinden `--kismi-kabul` VERME** — o Sultan kararıdır |
| 6 | **Denetle** | `plan-dekor denetle --model m.json --yerlesim y.json` | sert ihlal → aday kullanılmaz |
| 7 | **Renkli çiz** | `plan-dekor ciz --model m.json --yerlesim y.json --cikti p.svg --png p.png --tema T` | öz-denetim kırmızı → dosya yazılmadı; **çıktıyı kırpmadan** bildir |
| 8 | **Paketle** | `plan-dekor akis` 5–7'yi zaten yapar + `KOKEN.md` yazar | — |
| 9 | **Revize döngüsü** | doğal dili tarife çevir → `plan-dekor revize` | ihlal → eski dosya BOZULMADI; ihlali Sultan'a söyle |

**Kısayol — her şey yolundaysa tek komut 5–8'i kapsar:**
```bash
node cli.mjs akis --model m.json --cikti-dizin teslim/ --adet 3 --tema modern-sicak
```

### Doğal dil → revizyon tarifi (adım 9 sözlüğü)

| Sultan der ki | Tarif |
|---|---|
| "yatağı diğer duvara al" | `{"islem":"mobilya_tasi","oda":"suit","mobilya":"cift-yatak-160","dx":…,"dy":…}` |
| "yatağı çevir" | `{"islem":"mobilya_dondur","oda":"suit","mobilya":"cift-yatak-160","adim":1}` |
| "şu berjeri kaldır" | `{"islem":"mobilya_sil","oda":"salon","mobilya":"berjer"}` |
| "buraya çalışma masası koy" | `{"islem":"mobilya_ekle","oda":"suit","mobilya":"calisma-masasi","x":…,"y":…,"yon":1}` |

`yon`: `0`=+x · `1`=+y · `2`=-x · `3`=-y (mobilyanın ÖN yüzünün baktığı yön).

## Fail-closed kapıları (kaçılamaz)

- **Model kapısı plan-motor'undur** — `dogrula` kırmızıysa plan-dekor hiçbir şey yazmaz. Kendi
  doğrulamasını icat etmez (tek-kaynak).
- **Kaynaksız kural reddedilir** — `kural-seti`'nde `kaynak` alanı boş bir kural = RC≠0.
  (Ortak kanon `K01`: ölçmediğin kuralı SERT ilan edemezsin.)
- **Zorunlu program sığmazsa çıktı YAZILMAZ** — sahte yerleşim yazmak motorun disiplinini çürütür.
  Bilinçli kısmi teslim `--kismi-kabul` ile AÇIKÇA istenir; hiçbir oda döşenemediyse o da geçmez.
- **Render öz-denetimi** (`lib/oz-denetim.mjs`) — çizim yazılmadan sınanır: mobilya sayısı
  tutmuyorsa · oda çizimde yoksa · ölçü kaynağı beyanı çıktıda geçmiyorsa · tema kimliği
  damgalanmamışsa · lejant istenip çizilmemişse → **dosya hiç oluşmaz**.
- **Revizyon sonrası kural denetimi zorunlu** — ihlal üretirse eski dosya bozulmaz.
- **Ölçek çıpası kapısı** (`cipa`) — CAD'den gelmeyen modelin ölçüsü bir İDDİADIR. Tek bilinen
  ölçüye uydurmak kolaydır; bu yüzden **en az 2 çıpa** istenir ve biri ötekini **çapraz doğrular**
  (tercihen dik eksenlerde). Sapma > %3 → RC 1. Tek çıpa "ölçeği doğrulamaz, yalnız tanımlar".

## Değişmezler

- **Determinizm:** `Math.random` YOK, zaman-bağımlı davranış YOK. Aynı girdi → aynı sha256
  (kapı-testi bunu ölçer). Çeşitlilik rastgelelikten değil, **ayrık yerleşim kararlarından**
  (yön × ana-duvar kombinasyonu) gelir — plan-motor `uret`'in ilkesiyle aynı.
- **Çizim, modelin ölçtüğünden fazlasını iddia edemez.** Sembol, mobilyanın beyan edilen
  kutusunun dışına çizim yapamaz. (Sandalyeler bir zamanlar kutu dışına çiziliyordu → çakışma
  denetimine girmeyen alan işgali demekti; ölçülüp düzeltildi — `KANIT.md` B-001.)
- **Mobilya duvar gövdesine giremez.** Oda döngüsü duvar EKSENİNDEN geçer; mobilya iç yüze
  (eksen + kalınlık/2) yaslanır. Aksi halde kullanılabilir alan şişer ve "sığdı" yalan olur.
- **Üreten sınavı değiştiremez** (PERGEL doktrini). Sahiplik matrisi (Sultan kararı 2026-08-06):

  | ÜRETİCİ tarafı (PERGEL yazar) | SINAV tarafı (PERGEL dokunamaz) |
  |---|---|
  | `lib/yerlesim.mjs` — mobilya yerleştirici | `kural-seti/mobilya-TR.json` — kısıtlar |
  | `lib/dekor-svg.mjs` · `lib/sembol.mjs` · `tema/*.json` — renk/çizim | `lib/kural.mjs` — ölçen kod |
  | `katalog/*` — **kaynak beyanıyla** düzenlenebilir | `lib/oz-denetim.mjs` — çizimin sınavı |

  Renk/sembol üretici tarafındadır çünkü **sınavı yoktur** (renk doğru/yanlış diye ölçülmez) →
  ayrılığı bozmaz. Öz-denetim sınav tarafındadır: üretici kendi çizimini kendi onaylayamaz.
- **Katalog ölçüsü kaynaksız kabul edilmez.** Her kalem `kaynak: {kademe, metin}` taşır
  (`beyan` · `olculdu` · `standart`); motor kaynaksız kalemi **reddeder**. Sebep yapısal:
  üretici kendi kataloğunu sessizce düzenleyebilirse, sığmayan yatağı 160'tan 140'a çekip
  "sığdı" der — sınavı kimse fark etmeden değiştirmiş olur. Kaynak alanı hileyi **sessiz
  olmaktan çıkarır**: ölçüyü değiştiren kaynağı da değiştirir, o da `git diff`'te görünür.
- **$0 · dış API yok · GPU yok · sır yok.** Motor tamamen yereldir.
- **Additive:** plan-motor'un `model.json` şeması DEĞİŞTİRİLMEZ; mobilya ayrı `yerlesim.json`
  katmanında yaşar, modeli kirletmez.

## 🔴 Kapsam dışı — ve NEDEN (dürüst sınır)

- **Konfor eşikleri sert kural DEĞİL.** Sirkülasyon genişliği · dolap kapak payı · yatak yanı
  boşluk · pencere önü sınırı → `kural-seti/mobilya-TR.json → kaynak_bekleyen` bölümünde durur ve
  **yalnız adayları sıralar, eleme yapmaz.** Sebebi: bu sayıların kaynağı (NKBA/Neufert/TS)
  doğrulanmadı (`plan-motor` ekibi de mobilyayı tam bu yüzden kapsam dışı bırakmıştı).
  Sertleştirmek için ayrı bir layiha açıldı; terfi **Sultan-gate**'tir.
  → Bu yüzden plan-dekor çıktısı **"yönetmeliğe uygunluk belgesi değildir"** ve `KOKEN.md` bunu
  her teslimatta yazar.
- **Otomatik raster vektörleştirme YOK.** Görselden model kurma ELLE yapılır (ajan görseli okur,
  geometriyi yazar); motor bunu doğrulayan **ölçek çıpası kapısını** (`cipa`) sağlar ama piksel
  taramaz. Bu bilinçli: kandırılamaz bir ölçü kapısı, kandırılabilir bir otomatik izleyiciden
  değerlidir.
- Eğik/yaylı duvar · 3B render · DWG yazma · çok-katlı kurgu · bina ölçeği (emsal/TAKS) ·
  AI görüntü üretimi · mobilya tedarik/fiyat: **kapsam dışı** (bkz. `ahi.manifest.yaml → notes`).

## Kapı-kuralı

`lib/*.mjs`, `katalog/*`, `kural-seti/*`, `tema/*` ya da fixture değiştiğinde:
```bash
bash kapi-testi.sh      # "SONUC: GECTI" görmeden commit YOK
```

## Kademe
Kalfa (S2 · paketli). generic-goal: "planlı + paketli + her-projede güvenilir tekrarlanabilir".
Manifest: `ahi.manifest.yaml` · Doğrula: `ahi check plan-dekor` · Kanon: `ahi doctrine`.
Besteler: `plan-motor` (CLI sınırı).

## Geliştirme (KULLANDIKÇA GELİŞTİR — AHÎ §12)
1. Kendi kutunun canlı rafındaki kopyada düzelt.
2. **Sürümü yükselt** (`version:` — davranış-düzeltmesi=patch · yeni yetenek=minor).
   Sürüm yükseltmeden düzenlersen dağıtım aracı dosyaya dokunmaz → düzeltmen sessizce kaybolur.
3. **Kanona döndür** — `Sx-Claude-Skills`'e PR; kutun kanonu görmüyorsa klasörü kuryenin giden
   kutusuna bırak + tek sayfalık devir notu.
4. Dağıtımı doğrula + deftere bir satır düş. Kanıtı `KANIT.md`'ye yaz (kırpılmamış çıktı + RC).
