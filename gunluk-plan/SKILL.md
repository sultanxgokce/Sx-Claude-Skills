---
name: gunluk-plan
description: Günün planı — elimizdeki işleri ÖLÇ, katma değer katacakları süz, Sultan-dilinde plan sun, onaydan sonra icra et. Sultan'ın her gün verdiği "işleri analiz et, bugün ne yapalım" isteğinin tek komutlu karşılığı.
version: 1.8.0
---

# /gunluk-plan — günün planı (ölç → süz → sun → icra)

## Niçin var (Sultan-direktifi 2026-08-25)

Sultan her gün aynı şeyi uzun uzun yazıyordu: *"elimizdeki işleri analiz et ve bugün yapılacak
katma değer katacak işleri tespit et, bugüne yoğun bir planlama yap, aksiyona geçelim."*
Bu skill onun tek-komutlu karşılığıdır. **Amaç plan yazmak değil, gün sonunda kapanmış iş
bırakmaktır** — plan yalnız oraya giden yoldur.

## 🔴 Değişmezler (ihlal = plan çöp)

1. **Ölçmeden madde yazılmaz.** Her plan maddesinin arkasında bu turda koşulmuş bir komut çıktısı
   olur. Hafızadan/özetten madde üretmek yasak — hafıza bayatlar ([[project_bayat_kayit]]).
2. **Yeni havuz/defter KURULMAZ.** Kaynaklar aşağıda sabittir; sekizincisini icat etme.
3. **A06:** Sultan'ın onayı üretilmez. Plan sunulur, seçimi o yapar.
4. **Sultan-dili.** Dosya yolu · komut · kod-terimi plan gövdesinde geçmez; kanıt satırında geçebilir.
5. **Kapasite dürüstlüğü.** Bir güne 3-5 maddeden fazlası yazılmaz. Uzun liste plan değil, kaçıştır.
6. **Kuyruğunda iş varken durma.** Onaylanan maddeyi bitir, sonra sonrakine geç.
7. **🔴 ÇIPA ÖNCE, COMPACT SONRA.** Bu komut günün en uzun işidir; bağlamı en çok yiyen
   komut bağlam kuralı taşımazsa plan transkriptle birlikte kaybolur. Bu yüzden:
   **plan sunulur sunulmaz çıpa diske yazılır** ve bağlam eşiği geçildiğinde
   **compact ŞİDDETLE ÖNERİLİR** — ama **asla otomatik yapılmaz** (karar Sultan'ın).
   🔴 **Dürüst sınır:** bu beceri bağlam doluluğunu **ölçemez** — onu yalnız ajanın kendi
   göstergesi bilir. Mekanik olarak güvence altına alınan şey **sıradır**: çıpa diskte
   değilse öneri aracı **üretmeyi reddeder** (çıkış 3). Yani "önce yaz, sonra öner"
   iyi niyete değil kapıya bağlıdır.

## ADIM 0-a — KAPSAM: bu kutu mu, tüm filo mu? (yalnız MERKEZDE · S-15, Sultan 14 Ekim 2026)

Sultan'ın bulgusu: SERDAR'da `/gunluk-plan` yalnız merkez kutunun planını çıkarıyordu; Sultan **filonun** gününü istiyor.
Beceri **merkez kutuda** (SERDAR'ın koltuğu) çağrıldığında, ölçmeye başlamadan ÖNCE tek soru sorulur:

> **"Bu kutu mu, tüm filo mu?"** — şıklar: `tüm filo (önerim)` · `bu kutu`

Karar koddadır, metinde değil: **`bash scripts/kapsam.sh [<argüman>]`** → `KAPSAM=filo|kutu|SOR` (+ filo ise koşulacak komutlar). Kural:

| Nerede | Argüman | Sonuç |
|---|---|---|
| merkez (filo motoru var) | yok | **SOR** — tek soru, iki şık: `tüm filo (önerim)` · `bu kutu` |
| merkez | `tüm filo` / `filo` / `hepsi` | filo (soru yok) |
| merkez | `bu kutu` / `kutu` / `kapanis` | kutu (soru yok) |
| kutu (merkez değil) | yok / `bu kutu` / `kapanis` | kutu — soru **sorulmaz**, kutunun planı kendi işidir |
| kutu | `tüm filo` | rc 2 — filo motoru yok, söylenir |
| her yer | başka bir şey | rc 2 — kapsam uydurulmaz |

Merkezde çağrı: **`bash scripts/kapsam.sh --kos [<argüman>]`** — SOR ise soruyu sorar (yukarıdaki iki şık), cevabı argüman olarak yeniden
çağırırsın; filo ise PLAN komutunu koşturur (hiçbir mektup gitmez). **Tam zincir** — mektuplar reislere gider ve ilk özet alınır —
`bash scripts/kapsam.sh --kos --uygula tüm filo`: `--uygula` açık bayraktır (mektup göndermek bir eylemdir; Sultan/SERDAR "tüm filo" dedikten
sonra bu bayrakla koşulur). Dönüşler zille geldikçe `gunluk-plan-ozet` yeniden koşturulur.
Sınavı: `bash scripts/kapsam.test.sh` (K1-K8d, hermetik; merkez/kutu ayrımı ve zincirin icrası sahte filo.sh ile).

**"tüm filo" seçilince — yeni kanal YOK, iki mevcut komut:**
```bash
bash scripts/filo.sh gunluk-plan --hepsi            # PLAN: hangi kutuya hangi reis; reissiz kutu söylenir
bash scripts/filo.sh gunluk-plan --hepsi --uygula   # her kutu reisine mektup: "kendi kutunda /gunluk-plan koş, tek satır dön"
bash scripts/filo.sh gunluk-plan-ozet               # dönüşlerden Sultan'a TEK filo özeti (✅ döndü · ⏳ bekliyor · ⛔ tıkandı · ❓ soru · ⚠️ ölçülemedi)
```
(Nexus deposunda; komutlar `/filo` becerisinde de yazılı.) Her reis **kendi kutusunda bu beceriyi** koşar ve `donus.sh <no> bitti "<tek satır>"`
ile döner; dönüş zili SERDAR'ı uyandırır. Aynı gün aynı kutuya ikinci mektup gitmez (parti = tarih).

**Sultan'a sunum:** merkez kendi planını da ADIM 1-3 ile çıkarır; filo özeti `gunluk-plan-ozet` çıktısıdır, **kutu başına bir satır, aynen**
(reisin cümlesi düzeltilmez, uydurma madde eklenmez). Bekleyen kutu varsa "⏳ N kutu henüz dönmedi" denir; sonra `gunluk-plan-ozet` yeniden.
🔴 Dürüst sınır: özet dönüşlerden gelir; dönmeyen kutunun planı YOKTUR, "herhalde şudur" yazılmaz. Mektup hedefte görülmediyse (⚠️) bu da söylenir.

## ADIM 0 — ÇIPAYI AÇ (plan sunulur sunulmaz, onay beklenmeden)

```bash
bash /config/.claude/skills/gunluk-plan/scripts/cipa.sh yaz --plan "1) … | 2) … | 3) …"
```

Niçin onay beklenmeden: Sultan onayı gecikebilir, bağlam gecikmez. Çıpa planın **diskteki**
hâlidir; compact ya da kesinti olursa plan oradan geri okunur.

🔴 **Bu adım ADIM 5'in yıllarca yazılı ama koşmayan yarısıydı** (ölçüldü 2026-10-02):
belge *"yarım kalanı ertesi günün ölçümüne çıpalar"* diyordu, ama bunu yazan ya da okuyan
tek satır yoktu. Kural vardı, kapısı yoktu.

## ADIM 0-b — MADDELERİ DEFTERE YAZ (1.8.0 · Sultan 26 Eki: "kutular görev defterini kullanmıyor")

Ölçüm (SERDAR, 26 Eki): filo görev üretiminin %93'ü merkezde; 10+ kutu bir haftada deftere hiç yazmadı — kutu işi yapıyor ama Sultan'ın
ekranında "Sırada 0 · Çalışılıyor 0". Çıpa yazıldıktan sonra (yeni defter KURULMAZ, mevcut görev defteri):
```bash
bash /config/.claude/skills/gunluk-plan/scripts/deftere-yaz.sh            # KURU: neyi yazacağını basar
bash /config/.claude/skills/gunluk-plan/scripts/deftere-yaz.sh --uygula --onay "<D1 damgası>"   # çıpadaki açık maddeleri kutunun deftere yazar
```
- Kaynak çıpadır (`- [ ]` satırları); yazım `gorev.sh ekle` ile, kutunun kendi jetonuyla; etiket özellik, aciliyet esnek (`--aciliyet` ile değişir), atanan = sen.
- **İdempotent:** defterde aynı başlıkta açık görev (onay bekleyen dahil) varsa yazılmaz; ikinci koşu çift kayıt açmaz.
- **Ölçemezse yazmaz:** çıpa ya da görev listesi okunamazsa rc 3 — "yazılacak bir şey yok" denmez. 200 karakterden uzun madde başlık değil nottur, reddedilir (kırpılmaz).
- **Onay kapısı (A06/D1):** `--uygula`, Sultan'ın plan onayını GÖRDÜĞÜNÜN referansını ister: `YYYY-MM-DD Sultan: <sonuç> (sohbet · <oturum-ref> · "<≤15 kelime verbatim>" · beyan:<AJAN> · plan:<imza>)`. Tarih BUGÜN, imza o anki planın imzasıdır (kuru koşu "plan-imzası=…" basar); plan onaydan sonra değişirse eski onay düşer. Biçimsiz, eski tarihli ya da başka planın referansında rc 2, deftere hiçbir şey gitmez; onay ÜRETİLMEZ, gördüğün aktarılır. Kuru koşu onaysız çalışır.
- **Aynı gün aynı madde:** açık (onay bekleyen dahil) ya da BUGÜN kapanmış/iptal edilmiş aynı başlıklı görev varsa yazılmaz; eski günlerde kapanmış başlık yeni gün için yeniden açılabilir.
Sınavı: `bash scripts/deftere-yaz.test.sh` (D1-D19, D17b-f, hermetik: sahte gorev.sh).

## ADIM 1 — YER-GERÇEĞİNİ ÖLÇ (yedi kaynak, hepsi zorunlu)

```bash
bash /config/.claude/skills/gunluk-plan/scripts/olc.sh
```

Script yedi kaynağı sırayla basar ve **ölçemediğini "ölçemedim" diye basar** (sessiz atlama yok):

| # | Kaynak | Hangi soruyu yanıtlar |
|---|---|---|
| 1 | layiha defteri (`--aktif`) | araştırması bitmiş, inşası bekleyen ne var |
| 2 | kapımda kartları (`--hepsi`) | Sultan'ı fiilen ne bekletiyor |
| 3 | açık PR'lar + yaşları | yarım bırakılmış iş nerede |
| 4 | federe gelen kutusu (son 7 gün) | başka odalardan ne geldi, cevapsız ne var |
| 5 | görev listesi (`in_progress`) | kendi kuyruğumda ne açık kaldı |
| 6 | **kendi** izim (son satırlar) | dün nerede bıraktım |
| 7 | git durumu (dal · commit'siz · geride) | ortam temiz mi, dallanma güvenli mi |

🔴 **6. kaynak başkasının defterini okutuyordu** (CEZERÎ bildirdi · 2026-10-06): yol çiviliydi
ve hangi ajan koşarsa koşsun ona **SERDAR'ın** izini "dün nerede bıraktım" diye sunuyordu.
İki ayrı zarar: yanlış ize bakan ajan yanlış plan yazar, ve bir ajanın günlük izi onu görmesi
gerekmeyen odalara **sızar**. Artık kimlik **sorulur** (`cipa.sh ajan` — tek kaynak; ölçüm aracı
ortam değişkenine de **bakmaz**, çünkü kimlik sırasının sahibi çıpa aracıdır — ikinci türetme
"tek kaynak" iddiasını çürütürdü), kendi izi aranır (`<ajan>-defter.md` → `<ajan>-konum-*.md`, en yenisi) ve
bulunamazsa **ölçemedim** denir: unknown ≠ başkasının verisi.

## ADIM 2 — SÜZ (dört elek, sırayla)

Ölçülen ham listeyi şu dört elekten geçir. **Eleme gerekçesiz olmaz.**

1. **Kapanabilir mi?** Bugün içinde BİTECEK mi, yoksa yalnız ilerleyecek mi? Kapananı öne al —
   yarım iş ertesi güne faiziyle döner.
2. **Kilidi açıyor mu?** Bu iş bitince BAŞKA kaç iş serbest kalıyor? Zincirin baş halkası
   her zaman tek başına duran bir işten değerlidir.
3. **Bozuk mu, eksik mi?** Bozuk olan (kurulmuş ama çalışmayan, "yeşil görünüp iş yapmayan")
   eksik olandan önce gelir — bozuk şey yanlış güven üretir.
4. **Sultan bunu hisseder mi?** Görünmeyen altyapı işi ile Sultan'ın ekranında değişen şey
   arasında seçim gerekiyorsa ikincisi kazanır ([[project_ana_aks_zemin_once]] dengesi:
   zemin önce ama zemin hep değil).

Elenenler **kayda geçer** ("bugün değil, çünkü …") — sessizce düşen iş kayıp iştir.

## ADIM 3 — SUN (ZORUNLU biçim — Sultan 18 Eki: "bu tarz bir görünüm istiyorum, tabloyu zorunlu gönder")

Plan sunumu **kutulu tablodur**; tablosuz sunum plan sayılmaz. Tabloyu **elle çizme** — çıpayı yazdıktan sonra
`cipa.sh tablo` basar (madde · sahip · durum işareti · kanıt; başlık satırında sayılar). Tek kod bloğu içinde,
bu sırayla, başka bölüm eklemeden:

````
```
📅 GÜNÜN PLANI · <YYYY-MM-DD>
ölçüm: <N> aktif layiha · <N> kart · <N> açık PR · <N> okunmamış mesaj · ölçülemedi: <liste|yok>

📋 BUGÜN · <YYYY-MM-DD> · <N> madde · <N> ✅ kapandı · <N> 🟡 yarım · <N> ⬜ açık      ← cipa.sh tablo çıktısı
┌───┬──────────────────────────────────────────────┬─────────┬───────┬──────────┐
│ # │ Madde                                        │ Sahip   │ Durum │ Kanıt    │
├───┼──────────────────────────────────────────────┼─────────┼───────┼──────────┤
│ 1 │ <Sultan-dilinde tek cümle — bitince ne değişir> │ MUAVİN  │  ⬜   │ —        │
└───┴──────────────────────────────────────────────┴─────────┴───────┴──────────┘

Günün kalanı (en çok 3): 1) … · 2) … · 3) …
Bugün değil: <iş> (<niçin>) · <iş> (<niçin>)
```
````

İşaretler sabittir: ✅ kapandı · 🟡 yarım · ⬜ açık · ⏸ ertelendi (yalnız Sultan D1 ile) · ➖ geri alındı.
Sahip sütunu çıpadaki `(sahip: <AD>)`den, kanıt sütunu `--kanit`ten gelir; "sen" / "ikimiz" de sahip olabilir.
Düz (markdown) biçim yalnız makine/metin kanalı içindir: `cipa.sh tablo --md`. Kokpitin "Bugün" paneli aynı çıpayı
`--json` ile okur; üçü de **aynı** satır dilbilgisini (`sema/bugun-maddesi.md`) kullanır.

**Düğüm (1.7.0, SERDAR 20 Eki F3b):** maddede görev kimliği varsa tablo o görevin düğümünü defterden okur ve
`görev …ABCDE ⛓ mmex …FGHIJ` yazar (bu görev mmex'in bekleyen işini açıyor; altta `⛓ = …` açıklaması). Defter
okunamazsa satır aynen kalır, tablonun altında `ℹ düğüm bağları okunamadı (<sebep>)` yazar; görevi olmayan çıpada
deftere hiç gidilmez. `--json` değişmez (kokpit kapısıyla ortak fikstür). Düğümü açan komut: `bulgu.sh yaz … --dugum`.

🔴 **Niçin zorunlu (ölçüldü 18 Eki):** 1.5.0 düz tabloyu getirmişti ama sunum adımı onu "basılabilir" diyordu,
"zorunlu" demiyordu; ajan sabah eski madde listesini sundu, Sultan ekranda tabloyu göremedi ve iki kez istedi
("tıpkı gün ortası gibi vermedin"). Kural artık açık: **tablo yoksa sunum yok.**

Sonra **tek soru**: *"Böyle mi ilerleyelim, yoksa sıralamayı değiştirelim mi?"*
Şıklar 2-4 arası, biri `(önerim)` işaretli. Yığma yasak — bir mesaj, bir istek.

## ADIM 4 — İCRA

Onaydan sonra maddeleri **sırayla** yürüt. Her madde bitince:
- kayıt-damgası (layiha defteri / kart / CONTEXT — hangisi ilgiliyse)
- `append-note.sh` ile deftere tek satır
- Sultan'ın notlarına tek satır (`[SERDAR]` etiketli, onun ağzından)
- **çıpayı tazele:** `cipa.sh tazele --madde <kimlik> --durum kapandi|yarim --kanit "<PR#|commit|dosya>" [--not "…"]` — kimlik tablodaki etikettir (`3`, `G1`); etiketsiz satırda sıra numarası; aynı etiket iki maddedeyse araç dokunmaz (rc 1)
  (kanıt tablonun kendi sütunudur; kanıtsız "kapandı" tabloda boş kanıtla görünür)

**Bağlam eşiği geçildiyse — madde ortasında bile:**
```bash
bash /config/.claude/skills/gunluk-plan/scripts/cipa.sh compact-onerisi
```
Araç çıpayı diskte görmezse öneri **üretmez** (çıkış 3) — o zaman önce `yaz`/`tazele` koş.
Öneri çıktısını Sultan'a **olduğu gibi** sun ve bekle. Otomatik compact YOK: oturumu
Sultan'ın haberi olmadan kesmek, kazandığı bağlamdan pahalıdır.

Madde ortasında yeni bir bulgu çıkarsa: **bodoslama fixleme** — layihaya yaz, plana dokunma
([[feedback_kesif_layiha_yolu]]).

## ADIM 5 — GÜN SONU (aynı komut, `kapanis` argümanıyla)

`/gunluk-plan kapanis` → `cipa.sh kapanis`: sabah + gün ortası maddelerini **çıpadan** okur, standart
tabloyu basar ve **kapıyı** tutar:

| Çıkış | Anlamı |
|---|---|
| 0 | açık madde yok — gün kapandı |
| 4 | **KAPANIŞ KABUL EDİLMEDİ** — açık / yarım / açılmadı madde var, liste basılır |
| 1 | çıpa yok — ölçemedim (temiz değil) |

🔴 **Sessiz taşıma YOK** (Sultan 17 Eki: *"planlanan işler tamamlanmadan kapanış kabul edilmeyecek"*).
Açık madde için iki yol vardır: kanıtla kapat ya da Sultan'a sor. Sultan "ertele" derse
`cipa.sh tazele --madde <n> --durum ertelendi --d1 "YYYY-MM-DD Sultan: ertele (sohbet · <ref> · \"<kırpık>\" · beyan:<AJAN>)"`.
D1'siz ya da biçimsiz damga reddedilir (rc=2). Biçim yetmez: damganın **sonuç kısmı** ("Sultan: …"
ile "(sohbet" arası) tam olarak bir erteleme kararı olmalıdır: `[yarına ] ertele | ertelensin | ertelendi |
erteleyelim | erteleyin`. "Sultan: bugün görüşelim (…)", "ertele istemiyorum", "ertele mi?" reddedilir.
Sultan'ın kendi sözü kırpıkta (tırnak içi) durur; sonuç yalnız kararın adıdır. Elle yazılmış damgasız
ya da kararsız "ERTELENDİ" satırı tabloda **açık** sayılır. A06: damgayı ajan uydurmaz, Sultan'ın gördüğün sözünü aktarırsın.
Ertesi sabah ertelenen maddeler yeni planın ilk maddeleri olarak yazılır.

## Sınırlar / dürüstlük
- Filo kapsamı (ADIM 0-a) merkezde bir SORUDUR, bir varsayılan değil; "tüm filo" Sultan/SERDAR'ın seçimidir. Kararın kapısı bu becerinin
  `scripts/kapsam.sh`'ında ve sınavı `scripts/kapsam.test.sh`'ta; mektup/dönüş/özet motorunun sınavı Nexus'ta (`scripts/filo.test.py` GP1-GP9 + mutasyon M46-M55).

- Bu skill iş ÜRETMEZ, var olanı süzer. Ölçüm boşsa plan da boştur — uydurma madde yazma.
- Süzme bir yargıdır, mekanik değil; gerekçesi her zaman yazılır ki ertesi gün tartışılabilsin.
- Ölçülemeyen kaynak "yok" sayılmaz, "ölçülemedi" diye basılır (unknown ≠ fail).
- Çıpa, tablo ve kapanış kapısının kendi sınavı: `bash scripts/cipa.test.sh` (60 kapı; T1 ortak fikstür
  `sema/ornek-cipa.md` → `sema/beklenen.json` — kokpit kapısının sınavı da aynı fikstürü koşmalı; hermetik —
  gerçek çıpaya dokunmaz). Ölçüm aracının sınavı: `bash scripts/olc.test.sh` (12 kapı,
  hermetik — sahte bir kök kurar; ağırlık merkezi **sızıntı**: sahte kökte başkasının defteri
  bilerek durur ve hiçbir kimlikte basılmamalıdır; O8 mutasyonu çivili yol geri gelince,
  O10 mutasyonu da ortam kısayolu geri eklenince kimlik taklidinin tuttuğunu gösterir). Fail-closed kapısı öldürülünce iki kapı kırmızıya döner; yani
  koruma süs değil, ölçülmüştür.
