# DEVİR — `plan-motor` → TELLAL (MEDDAH)

> **Kimden:** SEDİR / MÜDÜR · **Tarih:** 2026-08-03 · **Sultan kararı:** araç sedir'in içinde
> büyümeye devam edemez; global paketlensin, TELLAL geliştirsin, sedir güncel halini otomatik kullansın.
>
> Bu dosya devrin **tamamı** değil, açılışıdır: aşağıda 6 soru var ve cevapları devrin şeklini belirler.
> Cevap gelene kadar sedir motoru **olduğu gibi** kullanmaya devam eder.

---

## 1 · Bu nedir, nereden çıktı

Sultan'ın ev projesinde (SEDİR) somut bir ihtiyaç doğdu: *"autocad, dwg veya herhangi bir çizim
formatı olsun farketmez onu okuyup plan çizip revize edebilmesi lazım, çizim üstünden ölçüm
yapabilmesi lazım."* Kapsamlı bir tarama yapıldı (13 ajan, doğrulamalı): **dört yeteneği birden
(oku/çiz/ölç/revize) veren hazır bir ürün ya da API bulunamadı.** Özellikle *ölçeği bozmadan
revize* etmeyi hiçbiri sunmuyor. Üretken-plan araçlarının public API'si yok; Floorplanner
enterprise-only; Higgsfield raster (ölçü kavramı yok); APS gerçek ama bu ölçek için orantısız.

Bu yüzden motor yazıldı. Bugün itibarıyla **çalışıyor ve kanıtlı** (`KANIT.md`).

**MEDDAH'ın 7 maddelik paketleme sözleşmesi baştan bağlayıcı kabul edildi** ve karşılıkları
`SKILL.md` sonundaki tabloda madde madde işaretli. Motor jeneriktir: sedir'in oda adlarını,
mevzuatını, müşterisini bilmez.

## 2 · Bugün ne yapabiliyor (kanıtlı)

- **OKU** — DWG/DXF: katman, birim, entity envanteri, sınırlar. Üç ayrı gerçek dosyada, dosyaya
  özel kod yazılmadan. İki bağımsız kütüphaneyle çapraz doğrulandı (birebir aynı sayım).
- **GÖSTER** — çizimin kendi geometrisiyle referans kalitede render. AutoCAD PDF çıktısıyla
  karşılaştırıldı, aynı sınıf.
- **ÖLÇ** — ham çizimden semantik oda grafı (lifting: ızgara boyama + kapı-ağzı mühürleme).
  Doğruluk kanıtı: çıkarılan alan, çizimin **kendi etiketiyle** 27,18 ↔ 27 tuttu.
- **REVİZE** — iki yol: (a) `goster --duzenle` ile çizimin kendi geometrisinde nokta revizyon
  (duvar taşı/sil), (b) `revize` ile semantik model üstünde yapısal revizyon + fark raporu.
- **FAIL-CLOSED** — doğrulanamayan hiçbir çıktı yazılmaz. Öz-denetim (`lib/render-denetle.mjs`)
  render'ı yazmadan önce sınar ve **bilerek bozulmuş çıktılarla test edilmiştir.**
- **Ölçüm defteri** — her koşu süre + maliyet-usd + araç@sürüm + rc basar (MEDDAH md.4).

Maliyet: **$0** — her şey yerelde, MIT/Apache lisanslı, dış API yok, anahtar yok.

## 3 · Bugün ne YAPAMIYOR (dürüst liste)

1. **DWG yazma — ✅ ÇÖZÜLDÜ 2026-08-07 (v1.4.0).** (Bu madde eskiden olumsuzdu.) `ciz --dwg` gerçek AC1027 DWG
   yazar; AutoCAD 2027'de gözle doğrulandı: birleşik duvar gövdesi · ANSI31 tarama ·
   kapı boşlukları kesilmiş · ham Türkçe · AIA katmanları. Bağımlılık **MIT**, maliyet **$0**.
   ⚠️ **Yerinde güncelleme (yabancı DWG okuyup üstüne yazma) DOĞRULANMADI** — ayrı madde, bkz. 1b.
1b. **Müşterinin DWG'sini yerinde güncelleyemiyoruz.** Kendi yazdığımız dosya gidiş-dönüşten
   sağlam çıkıyor (doğrulandı), yabancı dosya çıkmıyor. Açık soru olarak kapatıldı.
   > 🔴 Bu satır **07-08'den 08-09'a bayat kaldı** ve gerçek zarar verdi: bir araştırma
   > alt-ajanı buradaki eski olumsuz cümleyi okuyup *"yarım çözüm direktifiyle çelişiyoruz"*
   > sonucuna vardı — ölçüme değil belgeye güvendi. **Yetenek değişince bu dosya AYNI İŞTE
   > güncellenir.** Bu belge ORTAK MOUNT'tadır; buradaki bayat cümle 10 kutuyu yanıltır.
2. Yalnız **eksen-hizalı** geometri. Eğik/yaylı duvar yok.
3. **Katman adları girdi konvansiyonuna bağlı** — başka bir büronun dosyası eşleme ister.
4. Lifting **yarı-otomatik**: bazı kapı ağızları elle beyan edilir (`ek_muhur`).
5. Taranmış (raster) plan desteklenmiyor.
6. **Mimari kural tabanı YOK** — piyes minimumu, mobilya boşluğu, sirkülasyon genişliği,
   "her odanın kapısı olmalı" gibi kurallar yok. Bunlar bir kullanıcı tarafından elle yakalandı.

## 4 · Sahiplik ve senkron — önerilen düzen

```
TELLAL (MEDDAH) sahibi          /config/.claude/skills/plan-motor/   ← JENERİK MOTOR
   ↑ geliştirir                      (10 kutunun ortak gördüğü yer)
   │
SEDİR tüketici                  sedir/.claude/skills/plan-cizimi/    ← İŞ MANTIĞI
                                sedir/00_ev/model/                     (ev verisi, sedir kuralları)
```

- **Kod tek kopya**, ortak `.claude` mount'unda → TELLAL bir şey değiştirince sedir aynı anda görür.
- **`node_modules` ortak mount'ta** (~61 MB): bir kez kuruldu, tüm kutular aynı kurulumu görür
  (ölçüldü). Kaybolursa `kur.sh` idempotent olarak geri kurar.
- Sedir kendi tarafında yalnız *iş mantığı* tutar: oda adları, mevzuat okuması, ev modeli, ritüel.

⚠️ **Kanonik ev sorunu:** kalfa-kademe skill'in kanonik evi `Sx-Claude-Skills/<ad>/`. Sedir izole
bir kutu, o depoyu **göremiyor**. Yani bugünkü yerleşim çalışır ama **sıfırdan-rebuild bunu geri
getirmez** (evergreen boşluğu). Kaydın Sx-Claude-Skills'e alınması için SERDAR'a istek gerekiyor —
soru 6.

## 5 · SORULAR (cevapları devrin şeklini belirler)

**S1 — Kırılma koruması.** Ortak kopyayı TELLAL geliştirirken sedir aynı anda kullanıyor. Bir
değişiklik sedir'i iş ortasında sessizce bozabilir. Üç seçenek: (a) sedir sürüm sabitler (kendi
kopyasını alır — senkron ölür), (b) sedir her kullanımdan önce sözleşme-testi koşar (`kur.sh`
duman testi zaten var, genişletilebilir), (c) semver + sedir'de sürüm-kilidi dosyası.
**TELLAL hangisini ister?** Benim eğilimim (b): senkron bozulmaz, kırılma sessiz kalmaz.

**S2 — npm bağımlılığı.** Bu, npm bağımlılığı olan **ilk global skill**. 48 skill'in hiçbirinde
`package.json` yok. Kurulumda ağ gerekiyor; ~61 MB ortak mount'ta bir kez duruyor (kutu başına değil — ölçüldü). Filo için kabul edilebilir mi,
yoksa bağımlılıkların paketlenmesi/vendorlanması mı isteniyor?

**S3 — DWG yazma yol haritada mı?** Ticari nişin asıl kapısı bu. Bugün okuyup çizebiliyoruz ama
mimara dosya geri veremiyoruz. Yazma tarafı için aday kütüphaneler var (`@node-projects/acad-ts`
DwgWriter iddiası taşıyor, gerçek dosyayla sınanmadı). **TELLAL bunu üstlenecek mi?**

**S4 — İki temsil borcu (bunu ben yarattım, dürüstçe devrediyorum).** Motorda iki ayrı iç temsil
paralel yaşıyor: semantik model (JSON) ve ham CAD nesneleri. **Birbirine bağlı değiller** —
`--duzenle` ile yapılan değişiklik modele işlemiyor; modeli revize edince çizim kalitesi düşüyor.
Altı ay sonra "hangisi doğru" sorusu çıkar. Biri kanonik seçilmeli: ya CAD ana olur ve model
ondan türer, ya model ana olur ve CAD-kalitesinde render yazılır. **TELLAL hangisini seçer?**

**S5 — Katman eşlemesi.** Katman adları tek bir büronun konvansiyonuna gömülü (`BICIM` tablosu).
TELLAL farklı bürolardan dosya görecek. Eşleme dosyası (`katman-esleme.json`) eklenmeli mi,
yoksa otomatik tanıma mı hedefleniyor?

**S6 — Kayıt ve kurye.** Sedir `Sx-Claude-Skills`'i göremiyor ve federe makine kanalı bu kutuda
token'sız (durum: DOĞRULANAMADI; ayrıca yalnız META taşıyor, kod taşımaz). Bu skill'in kanonik
depoya alınması için SERDAR'a isteği **TELLAL mi açar, sedir mi?**

## 6 · Hata kanalı

Sedir bu motoru gerçek işte kullanmaya devam edecek ve kusur bulmaya devam edecek (bugüne kadar
dördünü buldu, hepsi `KANIT.md`'de). Bulgular nereye gitsin? Öneri: bu dizinde `BULGULAR.md`
tutulsun, sedir ekler, TELLAL kapatır. Sedir'in ilk açık bulgusu şu:

> **B-001:** Öz-denetim "her odanın kapısı çizilmiş mi" kontrolünü yapmıyor. Bir planda yedi
> hacmin yedisinin de duvar-ağzı vardı ama tek kapı kanadı çiziliydi; kusuru insan yakaladı.
> Kontrol edilebilir bir kuraldır ve mimari-kural-tabanının ilk tuğlası olur.

---

## Devir durumu

- [x] Motor `/config/.claude/skills/plan-motor/` altına paketlendi (kod 328 KB)
- [x] `SKILL.md` frontmatter + `ahi.manifest.yaml` (kademe: **kalfa**, install: `_global`)
- [x] `KANIT.md` — motorun kanıtları (proje-özel ölçümler tüketicide kaldı)
- [ ] **TELLAL 6 soruyu cevaplar** ← devir burada bekliyor
- [ ] Kırılma koruması kurulur (S1'in cevabına göre)
- [ ] `Sx-Claude-Skills` kaydı (S6'nın cevabına göre)
- [ ] Sedir tarafı global motora bağlanır ve kendi kopyası kaldırılır
