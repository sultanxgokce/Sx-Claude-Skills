---
name: gunluk-plan
description: Günün planı — elimizdeki işleri ÖLÇ, katma değer katacakları süz, Sultan-dilinde plan sun, onaydan sonra icra et. Sultan'ın her gün verdiği "işleri analiz et, bugün ne yapalım" isteğinin tek komutlu karşılığı.
version: 1.19.2
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
4. **Sultan dili zorunlu.** Dosya yolu · komut · kod-terimi plan gövdesinde geçmez; kanıt satırında geçebilir.
   Deftere yazılan her maddenin (ADIM 0-b · 0-d) özeti tek cümle ve 80 harften kısadır, adı 5-10 kelimedir; yol, komut ve kod
   terimi ne adda ne özette geçer. Defterin özet kapısı sert kiptedir, kuralı bozan açılışı reddeder (Kuzey Yıldızı G2.1–G2.2, 1.19.1).
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
- **Kimlikli madde ve ikiz kapısı (1.16.0, …GJRBF1T8):** maddede `gorev_…` ya da `görev …XXXXXX` varsa yeni kayıt açılmaz, o kayda `gorev.sh adim` ile "bugünün planında" adımı yazılır (kimlik defterde yoksa ya da son-ek birden çok kayda uyuyorsa ✗, tahmin yok). Kimliksiz maddede açık bir kaydın başlığıyla kelime örtüşmesi ≥ %60 ise **İKİZ OLABİLİR**: yazılmaz, rc 1, maddenin kimliğiyle yazılması istenir. Özet satırı `bağlanan=` ve `ikiz=` sayar. Sınav D21-D25.
- **Ölçemezse yazmaz:** çıpa ya da görev listesi okunamazsa rc 3 — "yazılacak bir şey yok" denmez. 200 karakterden uzun madde başlık değil nottur, reddedilir (kırpılmaz).
- **Onay kapısı (A06/D1):** `--uygula`, Sultan'ın plan onayını GÖRDÜĞÜNÜN referansını ister: `YYYY-MM-DD Sultan: <sonuç> (sohbet · <oturum-ref> · "<≤15 kelime verbatim>" · beyan:<AJAN> · plan:<imza>)`. Tarih BUGÜN, imza o anki planın imzasıdır (kuru koşu "plan-imzası=…" basar); plan onaydan sonra değişirse eski onay düşer. Biçimsiz, eski tarihli ya da başka planın referansında rc 2, deftere hiçbir şey gitmez; onay ÜRETİLMEZ, gördüğün aktarılır. Kuru koşu onaysız çalışır.
- **Aynı gün aynı madde:** açık (onay bekleyen dahil) ya da BUGÜN kapanmış/iptal edilmiş aynı başlıklı görev varsa yazılmaz; eski günlerde kapanmış başlık yeni gün için yeniden açılabilir.
Sınavı: `bash scripts/deftere-yaz.test.sh` (D1-D19, D17b-i, hermetik: sahte gorev.sh).

## ADIM 0-c — HAFTALIK DEĞERLENDİRME (1.9.0 · görev (c): "kutunun son bir haftasını değerlendirip zayıf noktaları merkeze bildirsin")

Haftada bir (Pazartesi sabahı planında) ya da sıra boşken, kutunun görev defterindeki SON 7 GÜNÜ ölç:
```bash
bash /config/.claude/skills/gunluk-plan/scripts/haftalik.sh            # KURU: raporu basar, kimseye yazmaz
bash /config/.claude/skills/gunluk-plan/scripts/haftalik.sh --uygula   # raporu merkeze (varsayılan SERDAR) ULAK ile gönderir
```
- Kaynak tek: `gorev.sh liste` (kutunun kendi görevleri). Yeni defter/havuz KURULMAZ; `--hedef AD` alıcıyı, `--gun N` pencereyi (1-90) değiştirir.
- Zayıf noktalar sayıyla ölçülür: **Z1** son N günde hiç iş kapanmadı ama açık iş var · **Z2** N günden uzundur hareketsiz açık/bekleyen iş (başlıkla, en çok 5) · **Z3** bekleyen iş, yürüyen ve açık işlerden fazla.
- **Ölçemezse "sorun yok" demez:** liste okunamadı ya da boşsa rc 3. Kuru koşu varsayılan; mektup göndermek açık `--uygula` ister.
- Rapor tek yola gider: ULAK mektubu (deftere ayrıca kayıt yazılmaz — yeni defter kurulmaz); zayıf noktayı bildirir, çözmez; merkeze bildirilecek olan budur. Kutu kendi payına düşeni (Z2 işleri) aynı turda ele alır.
Sınavı: `bash scripts/haftalik.test.sh` (H1-H16, hermetik: sahte gorev.sh + sahte ulak.sh).

> **1.10.1 (27 Eki, görev 0HC75A):** üç betik (`deftere-yaz` · `haftalik` · `tarama-ekle`) görev betiğini tek yerden bulur (`scripts/gorev-yolu.sh`): açık env → cloudtop kanoniği → BU BECERİNİN kendi kopyası (`scripts/gorev.sh` + `dugum-bak.py`) → PATH → `/config/.local/bin`. cloudtop deposunu görmeyen 9 kutuda plan maddeleri deftere yazılamıyordu. Paketlenmiş kopyanın cloudtop kanoniğinden sapmasını `gorev-yolu.test.sh` Y7 yakalar (kanonik her değiştiğinde buraya yeniden kopyalanır).
> **1.11.2 (27 Eki, Oda modeli 5 · görev …39QMC):** paketlenmiş `scripts/gorev.sh` cloudtop kanoniğiyle (6a8e0234) birebir eşitlendi — cloudtop'u görmeyen kutular da sipariş bayraklarını (`ac --oda --isteyen-oda --teslim`, D2) ve `sira` · `catisma` · `hakem` komutlarını (D3a–D3b) kullanır.
> **1.18.0 (30 Eki, MUAVİN Madde 4 · NOVA):** `sirada-bak.sh` koltuk kimliğini ortamda yokken türetir — `--kim` → `GUNLUK_PLAN_AJAN` → `AGENT_NAME` → `AILE_KIMDEN` → tmux oturumu ↔ aile-registry `tmux:` alanı (tek eşleşme; yol `GUNLUK_PLAN_REGISTRY`). Eskiden kimlik boşken betik yine koşuyor, koltuğa atanmış işleri 'başkasının' sayıp Sultan'a 'iş çıkaralım mı' diye sevk ediyordu (NOVA 30 Eki). Türetilemezse ÖLÇÜLEMEDİ rc 3, kimlik uydurulmaz. Sınav X1-X5.
> **1.19.1 (30 Eki, SERDAR · Kuzey Yıldızı G2.1–G2.2):** değişmez 4 "Sultan dili zorunlu" oldu: deftere yazılan madde özeti tek cümle ve 80 harften kısa, adı 5-10 kelime. Betik değişmedi.
> **1.19.2 (30 Eki, BÂNİ · Kuzey Yıldızı G2.6/G14):** paketli `scripts/gorev.sh` cloudtop kanoniğiyle (#1232) yeniden eşitlendi: `gorev.sh ustlen <yeni> --kim <AD> --tahmin <dk> --duraklat <eski>` — yeni işi öne alıp elindekini bırakırken eskiye "öne alınan iş yüzünden" sebebi düşer, kart "Durakladı · …" gösterir. Ajan iki işi paralel yürütebildiği için otomatik değil, açık bayrak.

> **1.17.1 (30 Eki, görev …Y5DY7):** paketlenmiş `scripts/gorev.sh` cloudtop kanoniğiyle (cloudtop #1184 sonrası) yeniden eşitlendi — oda süzgeci (`liste --oda/--odasiz/--kutu`), `oda`, `oda-dagit` (+`scripts/oda-dagit.py`, Y7 kapısı onu da bayt-eşit ister), `bulgu --puan/--gerekce/--gorsel`, `puan`, `gorsel`, `dogan`. Cloudtop'u görmeyen kutular bu komutları ancak bu sürümle görür.

## ADIM 0-d — TARAMA: kod tabanı + web + endüstriden ölçülmüş İŞ ekle (1.10.0 · görev 0HC75A (b): "havuza, günde ≤3")

Sıra boşsa ya da plan bittiyse kutu kendi kod tabanını, ilgili web kaynaklarını ve endüstri örneklerini tarar; bulduğu BİR işi şöyle ekler:
```bash
bash /config/.claude/skills/gunluk-plan/scripts/tarama-ekle.sh --baslik "<tek cümle, Sultan-dilinde>" --kaynak <dosya:satır|https://…> --kanit "<bu turda ölçtüğün>"            # KURU
bash /config/.claude/skills/gunluk-plan/scripts/tarama-ekle.sh … --uygula                                                                   # deftere yazar
```
- **Yeni havuz KURULMAZ:** yazım mevcut görev defterine `bulgu.sh yaz` ile gider (türü özellik); kayıt başlıkta `[tarama] ` işaretini taşır ve günlük tavan bu işaretten SAYILIR.
- **Ölçmeden iş yazılmaz (değişmez 1):** `--kaynak` (dosya:satır ya da https adresi) ve `--kanit` ZORUNLU. `dosya:satır` ise dosya GERÇEKTEN var ve satır dosyanın içinde olmalı (çalışma dizinine ya da mutlak yola göre); `--kanit` en az 20 karakter ve ölçülmüş bir SAYI taşımalı (kaç dosya/satır/ms/adet). `https` kaynağı GERÇEKTEN açılmalı (HEAD, olmazsa 1 baytlık GET; 4xx/5xx → rc 2, ağ yoksa rc 3 — açıldığı doğrulanmadan yazılmaz). **Kanıt ölçüm dosyasına bağlanır (SERDAR 26 Eki):** `dosya:satır` kaynağında kanıttaki HER sayı o dosyanın o satırında birebir (tam sayı olarak) geçmeli ve dosya BUGÜN yazılmış olmalı (ölçüm bu turda); biri tutmazsa rc 1 + sebep. Yani `dosya:satır` bu turda üretilen bir ölçüm çıktısını gösterir. **Dürüst sınır:** betik ölçüm dosyasına bağı doğrular, ölçümün DOĞRULUĞUNU doğrulamaz (dosya ve satırın kendisi yazanın elindedir); `https` kaynağında bağ yalnız adresin açılmasıdır. Kaynak ve kanıt kaydın notuna yazılır, gözle denetlenebilir.
- **Günde en çok 3:** bir kutuda bugün hareketi olan `[tarama] ` kaydı 3'e ulaştıysa dördüncüsü rc 2 ile reddedilir ("yarına"). Tavan SABİTTİR: ortam değişkeniyle ya da argümanla değişmez.
- **İdempotent:** aynı başlık (büyük-küçük harf ve noktalama farkı yok sayılır) defterde açıksa ya da BUGÜN kapandıysa yazılmaz; eski günde kapanmış başlık yeniden açılabilir.
- **Kutu tahmin edilmez:** liste tek kutu gösteriyorsa o, birden çok kutu gösteriyorsa (tümünü gören rol) `--kutu` şart (rc 3).
- **Kutu ≠ jeton kutusu → yazmadan ÖNCE ret (1.15.0, görev …NMAGXX8C):** yazım jetonun kutusuna gider; `--kutu` başka bir kutuysa tavan orada sayılıp kayıt buraya düşerdi ve fark yazımdan SONRA görülüyordu (27 Eki ölçümü: kayıt yanlış kutuya yazıldı, rc 1). Artık `scripts/jeton-kutusu.sh` geçidin `/ben` ucundan jetonun kutusunu sorar; fark → rc 2 (hiçbir şey yazılmaz), sorulamadı → rc 3 ("aynı kutu" sayılmaz). Yazım sonrası geri okuma ikinci çit olarak durur. Sınav T13-T13c. Yazım jetonun kutusuna gider; yazımdan sonra kaydın hangi kutuda göründüğü okunur — sayım yapılan kutudan farklıysa ya da görünmüyorsa rc 1 ve açıkça söylenir.
- **Ölçemezse yazmaz:** görev listesi okunamadı/boşsa ya da ajan kimliği çıkmıyorsa rc 3 — "tavan dolu değil" denmez. Başlık 160 karakteri aşarsa reddedilir (başlık değil nottur; ayrıntı `--kanit`'e).
- Kuru koşu varsayılandır; `--uygula` yalnız yukarıdaki kapıları geçen çağrıyı yazar.
Sınavı: `bash scripts/tarama-ekle.test.sh` (T1-T12b + T4g-T4i, hermetik: sahte gorev.sh + sahte bulgu.sh).

## ADIM 0-e — ÖNCE SIRADA'YA BAK (1.11.0 · görev …VNB2E9, Sultan 27 Eki: "hiçbir kutuda /gunluk-plan şunu yapmıyor")

Plan yazmadan, ADIM 1'den ÖNCE kutunun defterdeki **Sırada** listesine bak — boşuna sıfırdan plan yazma:
```bash
bash /config/.claude/skills/gunluk-plan/scripts/sirada-bak.sh          # Sırada ≥ eşik ise en üstteki işi çalışılıyor yapar ve başlar (KARAR=BAS | KARAR=SOR)
bash /config/.claude/skills/gunluk-plan/scripts/sirada-bak.sh --bak    # yalnız bak, başlama
bash /config/.claude/skills/gunluk-plan/scripts/sirada-bak.sh --taze-gun 14   # havuz tazelik penceresi (varsayılan 7 gün; TAZELIK= satırı)
```
- **MADDE= satırları (1.16.0):** her `ISI=` satırının yanında plan maddesi biçimi basılır — `görev …XXXXXX tamamlanacak: <başlık> (sahip: <sen|başkası>)`; plana bunlar kopyalanır, deftere-yaz kimliği görüp ikiz açmaz (bkz. ADIM 3 madde biçimi).
- **KARAR=BAS** (Sırada ≥ 3, eşik `--esik N` ile kutuya göre ayarlanır): sıradaki işler listelenir (acil önce); varsayılan koşu EN ÜSTTEKİ işi `gorev.sh ustlen` ile üstlenir (`--bak` yalnız bakar ve "başladım" demez). Sultan'a tek cümle: *"Sırada N iş var, en üstteki ile başladım; bugüne almak ister misin?"*
- 🔴 **KARAR=SOR ise ADIM 0-d ZORUNLU (1.13.0, görev 0HC75A, SERDAR 28 Eki):** betik `ZORUNLU=ADIM 0-d tarama …` satırını basar. Sultan'ın cevabı BEKLENMEZ: kutu o turda kod tabanından/webden/endüstriden en az BİR ölçülmüş iş bulur ve `tarama-ekle.sh … --uygula` ile deftere yazar (kaynak + kanıt kapıları ve günde en çok 3 tavanı AYNEN; `tarama-ekle.sh`'ın kuru varsayılanı değişmedi, `--uygula` bu adımın kendi açık bayrağıdır). Bulacak ölçülmüş iş yoksa bunu söyle (uydurma iş yazılmaz); tarama-ekle rc 2/3 verirse sebebi Sultan'a olduğu gibi bildir. Amaç: sıra boşken kutunun defterine açılış üretmek — filo özeti (`filo.sh gunluk-plan-ozet`) kutu başına bugünkü kayıt/[tarama] sayısını bu yüzden gösterir.
- **KARAR=SOR** (Sırada < eşik): Sultan'a üç şıklı TEK soru — *"Bu kutuda planlanmış görev yok (ya da eşikten az: gerçek sayı söylenir). Kendimize iş çıkarma seansı yapalım mı? (1) Sultan'la sohbet ederek (2) Reis kendi başına taransın (önerim: ADIM 0-d) (3) Havuzdan süzelim: Seanslı Hasat"*. Bu dalda betik hiçbir işi üstlenmez.
- **SEANSLI HASAT — üçüncü şık (1.17.0, Kuzey Yıldızı 1.8):** havuzdaki kayıtlar işe dönüşmeden duruyorsa reis onları Sultan'a **tek tek** sunar: *"… kodlu kayıttan … içerikli görevi açıyorum, olur mu?"* Her kayda üç cevap vardır: **kabul** (görev açılır) · **başka sun** (bu kayıt atlanır, sıradaki sunulur) · **düzeltmeyle kabul** (Sultan'ın düzelttiği cümleyle açılır). Kayıt başına tek soru, cevap gelmeden sıradakine geçilmez; Sultan'ın cevabı ajan tarafından ÜRETİLMEZ, gördüğü aktarılır (A06). **Otomatik Hasat** bunun Sultan'sız hâlidir: reis kendisi `hasat.sh ac <id> "<gerekçe>"` ile kaydı sıraya alır (1.19.0: kapıdan geçmeyen kayıt açılmaz; Seanslı Hasat'ta 'kabul' de bu komutla açılır) (yalnız bu koltuğa atanmış ya da sahipsiz havuz kaydı; başkasının kaydı sorulmadan açılmaz). Doğan görev kaydına BAĞLI kalır: `dogan_gorevler` alanı BÂNİ'nin ayrı diliminde geliyor; o gelene dek gerekçe metnine kaynak kaydın kodunu yaz (*"havuz kaydı gorev_…ABC'den Seanslı Hasat ile açıldı"*) ki bağ sonradan kurulabilsin.
- 🔴 **HAVUZ TAZELİĞİ (1.17.0, Kuzey Yıldızı 1.5 · Sultan 29 Eki: "havuzda hasat etmek için yeterli yeni kayıt yoksa, her şey bayatsa, bunu da bir kontrol mekanizması olmalı; en az 1 görev oluşmuşsa taze kayıt eklenmesi tavsiye edilmeli ve günlük plana meşveret seansı önerilmeli"):** betik her koşuda kutunun havuzunu tarihe göre sayar — `HAVUZ_TOPLAM= HAVUZ_TAZE= HAVUZ_BAYAT= HAVUZ_TARIHSIZ= HAVUZ_EN_ESKI_GUN= TAZE_GUN=`. Taze = liste satırındaki `(son: <tarih>)` damgası son `--taze-gun N` gün içinde (varsayılan 7; açılış da bir adımdır, yani "açılmış ya da hareket görmüş"). Havuz boş ya da taze kayıt yok → `TAZELIK=KURU · ÖNERİ=Meşveret seansı (yeni bulgu toplanmalı)` + `TAZELIK_NEDEN=…`: günlük plana **"Meşveret seansı"** maddesi koy ve taze kayıt eklenmesini tavsiye et (`bulgu.sh yaz` / `tarama-ekle.sh`); hasat kuru havuzdan yapılmaz. Taze kayıt varsa `TAZELIK=VAR`. Tarihi okunamayan ya da **gelecekte** görünen (saat kayması/bozuk veri) kayıt taze SAYILMAZ, `HAVUZ_TARIHSIZ=` içine düşer; böyle kayıt varken taze de görünmüyorsa `TAZELIK=ÖLÇÜLEMEDİ` — ne "bayat" ne "var" UYDURULUR (unknown ≠ fail). Hesap hiç çıktı vermezse (python3 yok) yine ÖLÇÜLEMEDİ ve sayılar `-`. Sayım kutu düzeyindedir (`HAVUZDA=` koltuk düzeyinde kalır: ikisi ayrı soruya cevaptır). KARAR'ı değiştirmez; BAS'ta da SOR'da da basılır.
- 🔴 **HASAT KAPISI — "bulgu hâlâ var mı" (1.19.0, Meşveret 30 Eki madde 9, Sultan önem 2 · görev …ZM3PWD):** tazelik (1.17) KAYDIN yaşına bakar; sorun başka bir işle düzelmiş olabilir ve eski bulguya ezbere dalmak boşa iş açar. Bu yüzden havuzdaki bir kayıt göreve çevrilmeden ÖNCE sorunun yaşadığı ölçülür — `scripts/hasat.sh`:
  ```bash
  bash scripts/hasat.sh durum   <gorev_id> [--taze-gun N] [--birlesme YYYY-MM-DD | --yuzey <yol> [--depo <kök>]]   # SALT OKUR: HASAT=OLUR|OLMAZ|ÖLÇÜLEMEDİ
  bash scripts/hasat.sh dogrula <gorev_id> --sonuc var|duzelmis|olculemedi --olcum "<komut ya da dosya>" [--yuzey <dosya|dizin|->] [--sinif olcum|pr|ci|canli|kare] [--soz "<1-2 cümle>"] [--kapandi "PR #N"]
  bash scripts/hasat.sh ac      <gorev_id> "<gerekçe>"     # kapı OLUR ise havuz kaydını sıraya alır (gorev.sh durum … acik)
  ```
  Ölçüm kayda MUHAKKİK'in doğrulama biçimiyle adım olarak düşer: `[doğrulama: var|düzelmiş|ölçülemedi] sınıf=… · tarih=YYYY-MM-DD · yüzey=<mutlak yol|-> · ölçüm: … · <söz>` (tarih= metindedir: aynı metin defterde ikinci kez yazılmaz, tarihsiz yeniden ölçüm sessizce yutulurdu; tarih ve yüzey kullanıcı yazısından ÖNCE durur ve tam parça olarak okunur — ölçüm metnindeki 'tarih=' alanı ezemez). **Kapı OLUR** yalnız: kayıt havuzda · SON doğrulama "var" · en çok `--taze-gun` (vars. 7) gün önce · ilgili yüzeyde doğrulama gününden sonra (ya da aynı gün) birleşme yok. **Yüzey** = sorunun yaşadığı dosya/dizin: `var` yazılırken ZORUNLU (`--yuzey`, mutlak yola çevrilip adıma `yüzey=` olarak yazılır; kod yüzeyi olmayan bulguda açık beyan `--yuzey -`); `durum` bayraksız çağrıldığında SON doğrulama adımından okunur ve son commit günü git'ten ölçülür (`origin/main` — ölçümden önce `fetch`, düşerse ÖLÇÜLEMEDİ; uzak yoksa `HEAD`; `HASAT_DAL` ile değişir); hiç commit'i olmayan ve diskte de bulunmayan yüzey 'birleşme yok' SAYILMAZ (ÖLÇÜLEMEDİ), `dogrula` var olmayan yolu reddeder — böylece `sirada-bak` yolu da birleşmeyi ölçer. `--birlesme YYYY-MM-DD` ya da `--yuzey` bayrağı kayıttakini ezer. Yüzeysiz eski `var` satırı → OLMAZ (yeniden ölç). Doğrulama yok / bayat / ölçülemedi / yüzeyde birleşme → OLMAZ (rc 1) ve yeniden ölçüm. **Düzelmiş** bulgu `--kapandi "PR #N | commit | iş"` ile yazılır ve kayıt *"kendiliğinden kapandı — <iş>"* gerekçesiyle iptal edilir. Tarih okunamıyor, gelecek tarihli ya da git ölçemiyor → ÖLÇÜLEMEDİ (rc 3): "olur" UYDURULMAZ. MUHAKKİK'in görev hükmü (`geçti/kaldı`) bulgu doğrulaması SAYILMAZ. Düzelmiş kapanış defterde reddedilirse aynı komut yeniden koşulur (adım ikinci kez yazılmaz, kapanış yeniden denenir). 🔴 **Sınır:** kapı hat üstündedir (`sirada-bak` + Seanslı Hasat + `hasat.sh ac`); `gorev.sh durum <id> acik` ile doğrudan açılış hâlâ kapısızdır — sunucu tarafı kapı (geçitte havuz→açık geçişinde doğrulama şartı) ayrı iş, reis kararı.
  `sirada-bak.sh` kapıyı iki yerde kullanır: ilk aday havuz kaydıysa (havuz da iştir yolu) `HASAT=` satırını basar ve OLUR değilse **üstlenmez** (`BASLAMADI=… hasat kapısı` + `ZORUNLU=HASAT KAPISI` doğrulama komutu); KARAR=SOR'da havuz doluysa `HASAT_KAPI=` satırı Seanslı Hasat'ta her kayıt için bu sırayı hatırlatır. Kayıt okuma `hasat.sh`'ın içindedir — paket kopyası `gorev.sh`'a fiil eklenmedi (cloudtop kanoniğiyle bayt eş kalır, Y7). Sınavı: `bash scripts/hasat.test.sh` (U1-U5 · D1-D21 · B1-B8 · F0-F2 · Y1-Y15 · A1-A7, hermetik, git yüzeyi geçici depoda) + `sirada-bak.test.sh` H2d · H5-H9 · T2c-T2d · T4e.
- 🔴 **ÜSTLENMEK ≠ BUGÜNE ALMAK (1.13.2, görev QF01BB, SERDAR 28 Eki):** `gorev.sh ustlen` ajanın kendi işidir, kimseden izin istemez ve beklemez; `bugune al` ise Sultan'ın ekrandaki öncelik tıkıdır. İkincisi birincisinin ÖNKOŞULU DEĞİL: ajan 'bugüne alınmadı' diye boşta durmaz. Ölçülen vaka: 24 işlik sırayı görüp 'bugüne alma Sultan'ın' diyerek 29 dk hiçbir işi üstlenmeyen bir koltuk — betik metni 'Başlayıp bugüne alayım mı?' diye izin sorar gibi okunuyordu.
- 🔴 **HAVUZ DA İŞTİR (1.14.0, görev 62640 ders 1-2, SERDAR 29 Eki · Sultan "ilerleme durdu"):** Sırada eşiğin altında kalsa bile bu koltuğa atanmış ya da sahipsiz **havuz** işi varsa betik `KARAR=BAS` der ve `NEDEN=… havuz da iştir` satırını basar: Sultan'a "iş çıkaralım mı" SORULMAZ, ADIM 0-d taraması gerekmez, sıradaki iş (önce Sırada, sonra havuz) üstlenilir. Sırada sayısı ekranın tanımıyla aynı kalır (`SIRADA=`: acik + sira-bende); havuz ayrı sayılır (`HAVUZDA=`). Başkasına atanmış havuz işi sayılmaz. Tur bitince "ne yapayım" diye durma: bekçinin dürtmesine güvenme, `sirada-bak.sh`'ı tekrar koş.
- 🔴 **"Bugüne al" Sultan'ındır.** Defterde `bugun_plani` alanını geçit yalnız Sultan ekranına yazdırır (A06; ajan yazarsa 403). Betik onu YAZMAZ, yalnız ÖNERİR. Yani "bugüne alındı" işareti Sultan'ın tıkıyla gelir; ajanın yaptığı iş "çalışılıyor" ve öneridir.
- **Başkasının işi üstlenilmez (1.11.1):** eşik kutu-düzeyinde sayılır ama başlatma adayı YALNIZ koltuğa atanmış ya da sahipsiz (`-`) iştir; en üstteki iş başkasınındaysa atlanır, hiçbiri uygun değilse `BASLAMADI=yok` basılır ve hiçbir iş üstlenilmez. Sınav S19-S21 bunu sahte listede kilitler.
- **Koltuk adı ↔ defter adı (1.12.0, `kimlik-coz.sh`):** çok kimlikli kutuda koltuk adı (tmux oturumu) ile defterdeki ad ayrışabilir (mihenk: koltuk MOBILYACI, işler NECCAR adına). Eşleme **koltuk başına tablodur** — `koltuk-esleme.tsv` (`<koltuk><TAB><defter adı>`, yalnız ad FARKLIYSA satır; `GUNLUK_PLAN_ESLEME` ile yolu değişir). `kutu-bul.sh`, `deftere-yaz.sh`, `sirada-bak.sh` adı bu tablodan çevirir; tabloda yoksa ad AYNEN kalır, bir koltuk iki ada giderse rc 3 (tahmin yok), bozuk satır atlanır ve söylenir. 🔴 `GUNLUK_PLAN_AJAN`'ı ortak ayara KALICI yazma: sekiz kimlikli kutuda hepsi tek kişi adına yazar. **1.12.1:** tabloya mihenk reisi eklendi (NISANCI → mihenk-ana; reis kendi koltuğunu ölçüp bildirdi, defterde 25 kaydı bu adla duruyor). **1.13.1:** ad karşılaştırması artık ü ö ç ş ğ harflerini de katlar (koltuk MUTEVELLI, defterde MÜTEVELLİ: akar kutusunda 23 iş 'başkasına atanmış' görünüyordu, MÜTEVELLİ 28 Eki ölçtü); tabloya MUTEVELLI → MÜTEVELLİ satırı da eklendi ki `ustlen` defter adıyla yazsın. Sınav Q11-Q13, üç mutant yakalandı.
- **Sırada** = ekranın tanımı: aynı kutuda `acik` ya da `sira-bende` (havuz · tasarlanıyor · bekliyor · çalışılıyor · onay-bekliyor · bitti · iptal SAYILMAZ).
- **Ölçemezse karar vermez:** defter okunamadı ya da kutu çıkmadıysa rc 3 — "Sırada 0" DENMEZ, soru da sorulmaz.
- **Kutu tahmin edilmez (`kutu-bul.sh`):** görev listesi kutuya özel DEĞİLDİR (herkes tüm kutuları görür); "listedeki en sık kutu" hep en kalabalık kutuyu (code) verirdi — menzil'de maddeler yanlış deftere gidecekti. Kutu = o koltuğa ATANMIŞ işlerin kutusu; atanmışı yoksa ya da iki kutu eşitse rc 3 ve `--kutu` istenir (`GUNLUK_PLAN_KUTU` ile de verilir). `deftere-yaz.sh` de aynı yolu kullanır.
- **`deftere-yaz.sh` düzeltmesi (mihenk/s08):** `gorev.sh ekle` artık `--ozet` (Sultan-dili açılış özeti) taşır — geçit özetsiz açılışı 400 `ozet_acilista_gerekli` ile reddediyordu ve üç madde sessizce yazılamıyordu; reddedilen yazımın SEBEBİ artık ekrana basılır. Sınavın sahte `gorev.sh`'ı gerçek kapıyı taklit etmediği için bu hata yeşil sınavın arkasında kalmıştı.
Sınavı: `bash scripts/sirada-bak.test.sh` (K1-K6 · S1-S21 · D1-D3 · Q1-Q13 · H1-H4 · T1-T12 · X1-X5 kimlik türetme tazelik + Seanslı Hasat şıkkı, hermetik). Mutant sınav dosyasında değil kanıttadır: `kanit.py olcum --mutasyon` ile `taze+=1 → taze+=0` bozulunca 7 kapı kırmızı (`_agents/fabrika/kanit/hasat-tazelik-seansli`). + `deftere-yaz.test.sh` (D19-D20).

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

🔴 **Madde biçimi — sırada duran iş kimliğiyle yazılır (1.16.0, görev …GJRBF1T8 · Sultan 29 Eki 11:28: "sırada bekleyen işlerden görev
numarasını alıp şu görev tamamlanacak şeklinde yaz"):** plan maddesi defterde zaten duran bir işse madde **o işin kimliğini taşır**:
`görev …XXXXXX tamamlanacak: <cümle> (sahip: AD)` (son altı karakter yeter; tam `gorev_…` de olur). `sirada-bak.sh` bu satırları hazır basar
(`MADDE=`), çıpaya olduğu gibi kopyalanır. Niçin: 29 Eki'de 5 maddenin 4'ü sırada duran işin **ikizi** olarak açıldı — `deftere-yaz` yalnız
birebir başlığa bakıyordu. Artık kimlikli maddede **yeni kayıt açılmaz**, o kayda "bugünün planında" adımı yazılır; kimliksiz maddede benzer
başlıklı açık kayıt varsa (kelime örtüşmesi ≥ %60) **ikiz uyarısı**: yazılmaz, rc 1, kimliğiyle yazılması istenir. Yalnız defterde olmayan
yepyeni iş kimliksiz yazılır.

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
