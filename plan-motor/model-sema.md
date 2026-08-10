# plan-motor · model şeması (v1.1)

## ⚖️ Kanonik temsil kararı (2026-08-03 · DEVIR-CEVAP S4)

**CAD kanoniktir; semantik model ondan TÜRER.** Müşterinin verdiği/beklediği şey CAD'dir ve
doğruluk kanıtı çizimin kendi etiketine karşı ölçülür. Semantik model **türetilmiş, atılabilir
bir görünümdür** — ölçüm ve muhakeme için üretilir, kaynak sayılmaz. **Modelde yapılan revizyon
CAD'e işlemedikçe kanonik kabul edilmez.** (Elle kurulan modellerde — CAD yokken — model tek
temsildir ve aşağıdaki kurallar aynen geçerlidir.)

Aşağıdaki "kaynak-gerçek" ifadesi bu çerçevede okunur: SVG/PNG/DXF **çıktıları** modelden
türetilir, asla elle düzenlenmez.
Desen: köşe(nokta) → duvar → oda grafı; açıklıklar duvara `{duvar, oran}` ile bağlıdır
(react-planner'ın kanıtlanmış Hole deseni) — duvar taşınınca açıklıklar bedavaya taşınır.

## Koordinat düzeni
- Birim **cm**, `1 SVG birimi = 1 cm`. DXF çıktısı INSUNITS=5 (cm).
- `x` sağa, `y` AŞAĞI artar (ekran düzeni — plan görselleriyle aynı). DXF'e yazarken y aynalanır.

## Alanlar

```jsonc
{
  "surum": "1.0",              // zorunlu
  "ad": "Örnek Daire",
  "birim": "cm",               // zorunlu, yalnız "cm"
  "olcek": {                   // zorunlu — ölçünün NEREDEN geldiği beyan edilir
    "kaynak": "tablo|saha|cad",
    "aciklama": "..."
  },
  "noktalar": {                // köşe id → [x, y]
    "n1": [0, 0]
  },
  "duvarlar": [
    { "id": "d1", "bas": "n1", "son": "n2", "kalinlik": 20, "tip": "dis|ic" }
  ],
  "odalar": [
    {
      "id": "salon", "ad": "Salon",
      "dongu": ["n1", "n2", "n3", "n4"],   // kapalı döngü, ≥3 nokta
      "guven": "normal|dusuk",             // dusuk → taramalı çizilir, "saha ölçümü bekliyor"
      "beyan_m2": 27,                       // opsiyonel — hesaplananla çapraz kontrol edilir
      "tip": "oturma_odasi"                 // opsiyonel (v1.1, ŞAKÜL) — kural denetiminin
                                            // ayırt-edicisi. Değerler: oturma_odasi·yatak_odasi·
                                            // mutfak·banyo·wc·hol·antre·balkon·kiler·diger.
                                            // Tanınmayan tip = UYARI (RC değişmez, additive)
    }
  ],
  "acikliklar": [
    {
      "id": "k1", "tip": "kapi|pencere|gecis",
      "rol": "giris",        // opsiyonel (v1.1, ŞAKÜL) — kapının İŞLEVİ: giris·balkon·servis·diger.
                             // Geometriden türetilemez (giriş de balkon kapısı da "dış duvarda
                             // kapı"dır; md.39 eşikleri işleve göre ayrışır). rol'süz kapı,
                             // rol-seçicili kurallarda KÖR NOKTA uyarısı düşürür.
      "duvar": "d1",
      "oran": 0.5,          // duvar boyunca konum (0,1) — bas'tan son'a
      "genislik": 90,        // cm
      "aci_yonu": 1          // kapı kanadının açıldığı taraf: 1 | -1
    }
  ]
}
```

## Fail-closed kuralları (ihlalde RC≠0, HİÇBİR çıktı yazılmaz)
- `birim ≠ cm` · `olcek.kaynak` yok → ölçek doğrulanamaz, üretim yok
- tanımsız nokta/duvar referansı · id tekrarı
- oda döngüsü < 3 nokta ya da alan < 0.25 m² (kapanmamış/dejenere)
- açıklık duvarın dışına taşıyor ya da oran (0,1) dışında
- `beyan_m2` ↔ hesaplanan alan sapması > %5:
  - `guven: normal` → **HATA** (ya geometri yanlış ya beyan — hangisi olduğuna insan karar verir)
  - `guven: dusuk` → uyarı + çizimde tarama ve "saha ölçümü bekliyor" notu

## Mimari denetim (`denetle --model m.json --kural-seti k.json`, v1.1 · ŞAKÜL)

Geometrik doğrulamanın (dogrula) ÜSTÜNE mimari kural katmanı. **Eşikler motor kodunda
YAŞAMAZ** — kural-seti JSON'undan gelir (mevzuat değişince veri güncellenir, kod değil).
Referans set: `kural-seti/TR-PAIY-2026.json` (Planlı Alanlar İmar Yönetmeliği asgarileri,
her kural madde-no + URL taşır; mevzuata dayanmayanlar açıkça "mevzuat maddesi DEĞİL" der).

- Kural şeması: `{id, kaynak, kaynak_url?, surum?, uygulanir, sart:[{olcut,op,deger}], siddet}`
  — `siddet: hata` ihlali RC 1 · `uyari` RC'yi değiştirmez.
- `uygulanir` eşleşmesi `oda.tip` / `aciklik.tip` / `aciklik.dis` / `kapsam:"plan"` üstünden;
  ayırt-edici alan beyan edilmemişse varlık **belirsiz** sayılır ve kural hiç uygulanamadıysa
  KÖR NOKTA uyarısı basılır (sessiz-yeşil yasak).
- Türetmeler (`lib/turet.mjs`): oda↔duvar (aralık + **taraf**: oda duvarın hangi yakasında),
  açıklık↔oda (konum-duyarlı; iç geçit sayılmanın tek yolu **karşıt taraflarda tam iki oda** —
  aynı-taraf/dış-duvar/taraf-bilinmez çiftler `belirsiz`), erişim grafı (belirsiz açıklık kenar
  üretmez, kanat sayımına girmez — fail-closed), dar-kenar (rectilinear gerçek geçit).
- **Yaklaşık ölçüm yön-farkındadır:** eksen-dışı odada dar-kenar bbox ÜST-sınırına düşer;
  üst-sınırla alt-sınır şartını (≥) "geçmek" kanıt değildir → hata-şiddet kuralda
  **DOĞRULANAMADI = İHLAL (RC 1)**; kalmak zaten kesin ihlaldir.
- **KÖR NOKTA koşulsuz raporlanır:** ayırt-edici alanı (oda.tip / aciklik.rol) beyan etmeyen
  varlık, kural başkalarına uygulanmış olsa bile izsiz atlanamaz — uyarı düşer, "geçti sayılmaz".
  (RC'yi değiştirmez: alan beyanı opsiyoneldir, additive söz korunur.)
- Bozuk kural-seti (bilinmeyen ölçüt/op/seçici, kaynaksız kural, id tekrarı) = **RC 1**, sessiz atlama yok.

## Revizyon işlemleri (`revize --degisiklik d.json`)
`nokta_tasi · duvar_tasi · nokta_ekle · duvar_ekle · duvar_sil · oda_ekle · oda_sil ·
oda_guncelle · aciklik_ekle · aciklik_tasi · aciklik_sil`

Örnek — "iç duvarı 40 cm sağa kaydır":
```json
[
  { "islem": "duvar_tasi", "duvar": "d_ic", "dx": 40, "dy": 0 },
  { "islem": "oda_guncelle", "oda": "salon", "beyan_m2": null }
]
```
⚠ Geometriyi değiştiren revizyon, etkilenen odaların `beyan_m2`'sini de ele almak zorundadır
(güncelle ya da `null`'a çek) — yoksa çapraz kontrol kapısı üretimi durdurur. Bu bilinçlidir:
beyan, ölçünün kaynağına bağlı bir iddiadır; geometri değişince iddia kendiliğinden doğru kalamaz.

## Üretim programı (`uret --program p.json`, v1.2 · FAZ A)

Üretimin GİRDİSİ model değil **program**dır: boş sınır + istenen odalar. Çıktı, her biri
`dogrula` + `denetle`'den geçmiş `model.json` adaylarıdır.

```jsonc
{ "ad": "2+1",
  "birim": "cm",                                     // "cm" olmak ZORUNDA
  "sinir": [[0,0],[900,0],[900,600],[0,600]],        // EKSEN-HİZALI rektilineer poligon:
                                                     //   dikdörtgen · L · U (v1.3)
  "giris_kenari": 0,                                 // ops. 0 alt · 1 sağ · 2 üst · 3 sol
                                                     //   ZORUNLUDUR: verilirse giriş oradadır,
                                                     //   yerleşemezse aday elenir
  "duvar_kalinlik": { "dis": 20, "ic": 10 },         // ops. (varsayılan bu)
  "odalar": [                                        // 1..8 oda
    { "id": "salon", "ad": "Salon", "tip": "oturma_odasi",
      "hedef_m2": 22, "min_dar_kenar_cm": 320 }      // min_dar_kenar_cm ops.; kural daha
  ],                                                 //   büyükse KURAL üstündür
  "komsuluk": [["hol","salon"]] }                    // ops. YUMUŞAK istek — puanı etkiler,
                                                     //   kapı olmadan sağlanmış sayılmaz
```

**Fail-closed kapıları (ihlalde RC 1, hiçbir dosya — çıktı dizini bile — yazılmaz):**
- `sinir` eksen-hizalı değil (eğik/yaylı kenar kapsam dışı) ya da > 4 dikdörtgen parçaya ayrılıyor
- oda sayısı < sınır parça sayısı (her parça en az bir oda almalı)
- oda sayısı > 8 · `tip` tanınmıyor · `hedef_m2` ≤ 0 · id tekrarı
- `hedef_m2` kural setinin o tip için asgarisinin **altında** (program tanımı gereği geçemez)
- **SIĞMIYOR:** kural-asgari toplamı ya da hedef toplamı sınır alanını aşıyor; bir odanın
  dar kenar asgarisi sınırın kısa kenarını aşıyor
- Hiçbir aday `dogrula`+`denetle`'yi geçemedi (sahte plan yazmak yerine dürüst kırmızı)

**Üretilen modelin bilinçli seçimleri:**
- `beyan_m2` **yazılmaz** — program hedefi geometrinin gerçeği değildir; beyan yazmak %5
  tolerans kapısına yalan bir iddia sokardı.
- Her odaya `tip`, her kapıya `rol` yazılır (`giris` | `diger`) — beyansız varlık denetimde
  KÖR NOKTA uyarısı düşürür, "geçti" sayılmaz.
- Duvarlar **atomik segment**tir: her segmentin iki yanında ya iki oda (`tip:"ic"`) ya bir oda
  (`tip:"dis"`) vardır — hayalet geçit üretilemesin diye.
- Oda döngüleri eksen-hizalı dikdörtgendir: `dar_kenar_cm` **yaklaşık** ölçüme düşmez.

### Üretilen modelin FAZ B ekleri (v1.3)

```jsonc
{ "ad": "2+1 · A1 — ıslak: gruplu-dis · sirkülasyon: merkezi-hol · zon: ayrik · giriş: alt",
  "mimari_kararlar": {              // ← OPSİYONEL, additive. Yalnız `uret` yazar.
    "islak_cekirdek": "gruplu-dis", //   yok · tekil · dagitik · gruplu-dis · gruplu-ic
    "sirkulasyon": "merkezi-hol",   //   koridorsuz · merkezi-hol · dogrusal-hol · karma-hol
    "zonlama": "ayrik",             //   tek-bolge · ayrik · karisik
    "giris": "alt",                 //   alt · sag · ust · sol · belirsiz
    "yaklasik_olcum": false,        //   true = oda dikdörtgen değil, ölçüm bbox'a düştü
    "kombinasyon": "gruplu-dis|merkezi-hol|ayrik|alt",
    "olcum": "modelden TÜRETİLDİ (beyan değil) — lib/uret-eksen.mjs" } }
```

Bu alan **iddia değil ölçümdür**: `eksenleriOlc(model)` aynı modelden aynı sonucu yeniden
üretir. `dogrula` bu alanı okumaz — eski modeller ve SEDİR akışı etkilenmez (additive).
