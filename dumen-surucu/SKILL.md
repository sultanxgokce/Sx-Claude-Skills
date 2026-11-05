---
name: dumen-surucu
description: Ajanın Dümen Chrome'unu (bulut masaüstündeki CDP'li tarayıcı) SÜRMESİNİN tek yolu — Playwright connectOverCDP üstünde eylem kapısı. Her eylemden önce merkezden Dümen kimde okunur; Sultan'da ya da merkez cevapsızsa eylem YAPILMAZ (fail-closed). Parola/SMS/ödeme alanında ajan kendi durur ve nedeni bildirir. İzole dünya dinleyicisi tarih/seçim gibi CDP girdisi üretmeyen değişimleri eylem günlüğüyle eşleştirir. Tetik "Dümen'i sür", "Dümen'de tarayıcı işi", "devral/geri ver". 0.9.0: dosya yükleme (Sultan onaylı) ve indirme, yeni sekme adresi, engel kapatma (çerez/tur/anket), her eylemde sert süre sınırı, kapat garantisi (Dumen.kos), öğe durumu ölçümü ve HATA KATALOĞU — Dümen'de takıldıysan önce bunu oku.
version: 0.9.2
---

# dumen-surucu — Dümen'i kapıdan sür

Karar belgesi: Nexus `_agents/hezarfen/bilgi-havuzu/dumen-arastirma-20261027/KARAR.md` (Z8E7K7 devral/geri ver · JN1K8K bekçi kör noktası).

## 🔴 SERT KURAL — Dümen'de gördüğünü bulguya yaz (Sultan zorunlu kıldı · 2 Kas)
Dümen'i kullanan **her ajan**, kullanırken gördüğü her **hatayı** ve **geliştirme önerisini** Bulgu Havuzu'na yazar: `bash /config/.claude/skills/bulgu/scripts/bulgu.sh yaz …`. Ne kadar çok geri bildirim, o kadar gelişir. Bulgu yoksa "bulgu yok" demek de bir karardır; ama sormadan geçmek ihlaldir. `Dumen.kapat()` her çıkışta tek satır hatırlatma basar (`Dümen bulgu hatırlatması: …`); sınav bu satırı kilitler (D48).

## 🧭 Çalışma disiplini — her Dümen işinde (0.9.0 · kalıcı tecrübe · Sultan 5 Kas)
Bu on kural filoda yaşanmış takılmalardan çıktı (aşağıda HATA KATALOĞU). Betiği yazmadan önce oku.
1. **İşi `Dumen.kos` içinde koş.** Bağlan, işi yap, her koşulda kapat: `await Dumen.kos({ cdpUrl, merkez, dosyaKok }, async (d) => { … })`. Hata, süre dolması ya da süreç sinyali gelse de sekme kapanır. Çıplak `baglan` kullanıyorsan `try { … } finally { await d.kapat(); }` zorunlu.
2. **Hiçbir eylem süresiz değildir.** Tek eylem öğeyi en çok 15 sn bekler (`eylemSureMs`), kapı dahil sert tavan 45 sn (`eylemAzamiMs`; eyleme özel `{ azamiMs }`). Süre kapı dahil **tek bütçedir**. `zaman-asimi` gelince bağlantı bırakılır: yarım kalan eylem sonradan gerçekleşmez; sonraki eylemde yeniden bağlanılır ve sayfa yeniden yüklenir. Sayfanın hâli **bilinmez**: `kare()` ve `adres()` ile ölç, aynı tıklamayı körlemesine yineleme.
3. **Önce ölç, sonra dokun.** Tıklamadan ya da yazmadan önce `ogeDurumu(sel)`: kaç öğe eşleşti, kaçı görünür, o öğe etkin mi. Gizli eşe çözülen seçicide `sel >> nth=<ilkGorunur>` kullan; `etkin: false` ise alan pasiftir, yazma (önce onu açan adımı bul).
4. **Sabit uyku yerine `bekle(sel)`.** Öğe görünene dek bekler, süre dolarsa `false` döner.
5. **Engeli `engelKapat()` ile kaldır**, `force: true` ile delme. `force` örten katmana tıklayabilir; yalnız `ogeDurumu` görünür ve etkin diyorsa ve örtenin zararsız olduğu kareyle görüldüyse kullan.
6. **Dosya indirmek için `indir(sel, hedef)`**: tıklama indirme başlatsa da, dosyayı yeni sekmede açsa da baytları alır. Tarayıcı başka makinededir; "İndirilenler" klasörünü arama, o dosyaya yolun yok.
7. **Dosya yüklemek için `yukle(sel, dosya, { onay })`**: yükleme Sultan onayı ister (aşağıda). Yüklemek göndermek değildir; "Gönder" düğmesi ayrı eylemdir ve müşteriye giden her gönderim kendi onayını arar.
8. **Her adımdan sonra "oldu mu" diye ölç.** İndirdiysen dönen `bayt` ve `tur` değerine bak; yüklediysen sayfada dosya adının göründüğünü `metin()` ile oku; gönderdiysen sonuç satırını oku. Ölçmediğin adım olmuş sayılmaz.
9. **Site engeli ajan hatası olmayabilir.** 403 ya da doğrulama sayfası görürsen çalıştığı bilinen bir siteyi de aç (pozitif kontrol), ikisini birlikte bulguya yaz.
10. **Gördüğünü bulguya yaz** (yukarıdaki sert kural). Bu beceri o bulgularla büyüyor.

## Dosya yükle · indir · yeni sekme · engel (0.9.0 · NARH fatura vakası)
```js
import { Dumen } from '.../dumen-surucu/scripts/dumen.mjs';
await Dumen.kos({ cdpUrl, merkez, dosyaKok: ['/config/<ajan>/veri'] }, async (d) => {
  await d.goto(siparisAdresi);
  await d.engelKapat();                                             // Escape×3 · çerez Reddet · Turu Geç · anket çerçeveleri
  const f = await d.indir('text=Fatura Görüntüle >> visible=true', '/config/<ajan>/veri/in/fatura.pdf');   // { yol, bayt, tur, kaynak }
  const iz = Dumen.dosyaIzi(f.yol);                                  // dosya#ab12cd34ef → Sultan'a bu izle sor
  // … Sultan onayı geldikten sonra (onayı ÜRETME, gördüğünü aktar):
  await d.yukle('input[type=file]', f.yol, { onay: `${Dumen.bugun()} Sultan: yükle (görev ekranı · gorev_… · "faturayı gönder" · ${iz} · beyan:NARH)` });
});
```
- **`indir(sel, hedefYol)`** sel'e tıklar. Tıklama indirme başlatırsa ya da dosyayı yeni sekmede açarsa baytları **tarayıcının içinden** (oturum çerezleriyle; başka kökende tarayıcının ağ yığınıyla) alır, `hedefYol`'a yazar, kendi açtırdığı sekmeyi kapatır. **0.9.1:** tıklama dosyayı **sayfa içi pencerede** (iframe/embed/object, çoğu zaman geçici `blob:` adresi) açarsa onu da alır (`kaynak: 'gomulu'`); yalnız tıklamadan **sonra** açılan pencere sayılır, önceden açık duran alınmaz. Hiçbiri olmazsa `indirme-yok` (asılmaz; bekleme `olayMs`, varsayılan 15 sn). Boş dosya, dosya yerine gelen **giriş sayfası** (`indirme-sayfa`) ve uzantısıyla uyuşmayan içerik (`indirme-tur`) dosya sayılmaz, diske yazılmaz. Var olan dosya ancak `{ ustuneYaz: true }` ile ezilir.
- **`indirGomulu(sel, hedefYol)`** sayfada **zaten açık** duran penceredeki dosyayı tıklamadan alır (`sel` ana sayfadaki iframe/embed/object, ör. `'iframe[src^="blob:"]'`). Görüntüleyicinin kendi indir düğmesine seçiciyle ulaşılmaz; bu yardımcı ona gerek bırakmaz.
- **`indirAdres(adres, hedefYol)`** adresi bilinen dosyayı aynı yolla alır: http/https ya da **bu sayfanın** `blob:` adresi (blob yalnız onu üreten sayfanın içinden okunur; başka sayfanınki `indirme-okunamadi`).
- **`yeniSekmeAdresi(sel)`** sel'e tıklar, açılan sekmenin adresini döndürür ve o sekmeyi kapatır. `/json/list` okumaya gerek kalmaz.
- **`yukle(sel, dosya, { onay })`** dosyayı alana ekler; `sel` gizli `input[type=file]` olabilir. Sayfada input yoksa ve bir düğme dosya penceresi açıyorsa `{ secici: true }` (sel o düğmedir). Dosya içerik olarak taşınır, tarayıcı uzak makinede olsa da çalışır (50 MB altı).
- **`engelKapat({ cerez, ek, gizle })`** Escape×3; çerez şeridinde **Reddet** (düğme ancak çerez yazılı küçük bir kutunun içindeyse tıklanır: sayfadaki "Reddet" iade ya da talep düğmesine dokunulmaz); "Turu Geç"; anket çerçeveleri gizlenir. `cerez: 'dokunma'` şeride karışmaz; `cerez: 'kabul'` Sultan izni ister (`cerezOnay`). Siteye özel kapatma düğmesi `ek: ['seçici']`, gizlenecek katman `gizle: ['seçici']`. Ödeme sayfasında çalışmaz. Dönen rapor: `{ escape, tiklanan, gizlenen }`.
- **`ogeDurumu(sel)`** → `{ sayi, gorunurSayi, ilkGorunur, gorunur, etkin }` · **`bekle(sel, { durum, azamiMs })`** → `true/false`. İkisi de salt-okurdur.

### Dosya kapıları (hepsi fail-closed)
- **İzinli dizin zorunlu:** `baglan({ dosyaKok: [...] })` ya da `DUMEN_DOSYA_KOK=<dizin[:dizin]>`. Verilmezse dosya işi yoktur (`dosya-kok-yok`). İzinli dizin bir git deposunun içindeyse **`.gitignore`'da olmalı**: müşteri dosyası depoya girmez (5 Kas: iki müşteri dosyası yanlışlıkla commit'lendi; önce `git check-ignore <dizin>` ile ölç). Bağlar çözülür; izinli dizindeki bağ dışarıyı gösteriyorsa reddedilir.
- **Sır taşıyabilecek yol hiçbir koşulda geçmez** (`.ssh`, `.env`, `.claude`, jeton, parola, `.pem`, `.key` …: `dosya-yasak`). Tür listesi: pdf, png, jpg, webp, gif, csv, xlsx, xls, txt, zip, xml (`{ turler: [...] }` ile daraltılır). Boyut tavanı 50 MB.
- **Yükleme onayı (A06):** `onay` Sultan onayının D1 damgasıdır, **bugünün tarihini** ve **o dosyanın izini** (`Dumen.dosyaIzi(yol)`) taşır. Onaysız (`onay-yok`), dünkü (`onay-bayat`) ya da başka dosyaya verilmiş (`onay-dosya`) damgayla yükleme yapılmaz. Damgayı ajan üretmez; Sultan'a dosyanın ne olduğunu ve izini gösterip aldığı onayı aktarır.
- Terminale dosya adı yazılmaz (müşteri verisi taşıyabilir): yalnız tür ve bayt. Müşteri dosyası depoya konmaz.
- Öteki kapılar aynen geçerli: Dümen Sultan'dayken okuma da eylem de yok; parola, SMS, kart alanında ve ödeme sayfasındaki "Öde/Onayla/Gönder" düğmesinde durulur.

## Ne yapar
`scripts/dumen.mjs` → `Dumen.baglan({cdpUrl, merkez})` ajana `goto/fill/selectOption/check/click/press` verir. **Ham `page.evaluate` ve ham CDP verilmez** (`page`/`cdp`/`tarayici` özel alanlardır; `d.page` yoktur). Her eylem:
1. `GET <merkez>/dumen/mod` — `ajan` değilse ya da merkez cevap vermezse **reddedilir**, terminale tek satır: `⏸ Dümen Sultan'da · bekliyorum` (`KapiHata.neden = sultanda | merkez-cevapsiz`).
   - **Mod sultan iken köprü soketi düşer (okuma dahil)**: eylem sırasında gelen bağlantı hatası hata sayılmaz, `sultanda` olur; mod `ajan` olana dek **yeniden bağlanılmaz**. Mod `ajan` olunca bir sonraki eylemde yeniden bağlanır ve sayfa yeniden okunur — Sultan'ın yaptığı eylem ajana aktarılmaz. Mod `ajan` iken soket düşerse sessiz yutulmaz: `baglanti-koptu`. `d.durum()` → `{kopuk, baglanmaSayisi}` (salt-okur).
2. Durma noktası: parola/telefon/tek kullanımlık kod/kart alanı, ödeme sayfasında "Öde/Onayla/Gönder" düğmesi → eylem YAPILMAZ, `POST <merkez>/api/dumen/durak {neden}` (başlık `x-defter-jeton`: `DUMEN_DEFTER_JETON` dosyası ya da `/config/defter-jeton`; değer ASLA yazdırılmaz; yalnız `sifre·sms·odeme`; alan değeri, adres, çerez ASLA; merkez 2xx dememişse `KapiHata.bildirildi=false` ve satır "merkeze İLETİLEMEDİ" der — eylem yine yapılmaz), `⏸ Dümen: … alanında durdum · Dümeni al`.
3. Eylem penceresi kaydedilir; izole dünya dinleyicisi (`input`/`change`, window capture, sayfa betiklerinden önce) olayları toplar. Pencereye düşen olay = ajanın, düşmeyen = **insan ya da sayfa** (`yabanci()`). `isTrusted` ayırıcı DEĞİLDİR (ölçüldü: tarih/seçim false, metin/onay kutusu true, sayfanın sahte olayı false).
4. Parola/OTP/kart alanlarının değeri olay kaydına `<gizli>` olarak girer.

Dinleyici yalnız **kayıt/uyarıdır**: sayfa sahte olay üretip yanlış alarm yaptırabilir; karar kapısı 1-2'dir.
5. **Kör nokta uyarısı (0.3.0 · JN1K8K):** `fill`(tarih/renk/aralık)/`selectOption` değeri sayfa JS'iyle yazar, CDP `Input.*` üretmez → köprü bu eylemi GÖRMEZ. Eylem penceresindeki `isTrusted=false` olay için terminale `⚠ Dümen: … köprüde GÖRÜNMEZ` basılır, `uyarilar()` kaydı (`gorulemeyen-eylem`) tutulur. Eylem penceresi dışındaki alan değişimi için `⚠ … DIŞINDA alan değişti` (`yabanci-olay`, olay başına bir kez). Uyarı alan DEĞERİNİ taşımaz. Uyarı (0.5.0) merkeze de gider: `POST /api/dumen/uyari` (kutu jetonu; YALNIZ kod ve sayı — hedef, değer, adres, çerez yok) → Dümen panelinde Sultan-dilinde satır + kütük satırı; eylemi bekletmez, merkez cevap vermezse eylem sürer ve terminale `İLETİLEMEDİ` yazılır. Hâlâ yalnız uyarıdır: köprü tarafında yakalama (CDP çerçeve ayrıştırma) yoktur; merkez imajı 1.123.0'dan önceki sürümde uç yoktur (iletim o zaman 404 ile uyarır).

## Kullanım
```js
import { Dumen, KapiHata } from '.../dumen-surucu/scripts/dumen.mjs';
const d = await Dumen.baglan({ cdpUrl: 'http://127.0.0.1:9222', merkez: process.env.DUMEN_MERKEZ });
try { await d.fill('#ad', 'Ayşe'); } catch (e) { if (e instanceof KapiHata) { /* dur; mod ajana dönünce kaldığın yerden sür */ } }
```
`playwright-core` bulunamazsa `DUMEN_PLAYWRIGHT=<playwright-core dizini>`.

## Sekme seçimi (0.7.0 · SERDAR/NARH · 2 Kas) — Sultan'ın sekmesine dokunulmaz
Dümen'de ilk sekme çoğu zaman Sultan'ın terminalidir; `goto` onu bozar. Bu yüzden `baglan` seçeneği **`sekme`**:
- **verilmezse / `'yeni'`** → her zaman **YENİ sekme** açılır (varsayılan). İlk sekmeye ve başkasının sekmelerine dokunulmaz.
- **`'ilk'`** → ilk sekme (eski davranış). Yalnız çağıran **açıkça** isterse.
- **string** (adres parçası) ya da **RegExp** → adresi eşleşen sekme; eşleşen yoksa yeni sekme açılır.
- `kapat()` yalnız **kendi açtığı** sekmeyi kapatır; `'ilk'` ya da desenle seçilen sekme kapanmaz. Yeniden bağlanmada aynı sekmeye dönülür (hedef kimliğiyle).
- **Yeniden bağlanma öteki sekmelere dokunmaz (0.7.1 · BENNÂ · 3 Kas):** aranan sekmenin adresi `/json/list`'ten tek sorguyla okunur; kısa CDP oturumu YALNIZ aynı adresli adaylarda kimlik doğrulaması için açılır. Liste okunamazsa ya da sekme kapanmışsa hiçbir eski sekmeye oturum açılmaz; sekme yukarıdaki seçim ilkesiyle (yeni sekme / desen) seçilir. Önce: 4 sekmede 4 oturum; sonra yalnız aranan sekmede (sınav D51-D54).
- Eski çağıranlar (amazon-etiket, gib): çerez/oturum tarayıcı bağlamında ortaktır, yeni sekmede de geçerlidir; ilk sekmeyi gerçekten bekleyen varsa `sekme: 'ilk'` ekler.

## Salt-okur: sayfayı oku, kare al (0.6.0 · SİNAN/VADE 31 Eki · görev …W3ZKKH)
```js
const yazi = await d.metin();            // görünür sayfa yazısı (en çok 20.000 harf); d.metin('#borc-tablosu') yalnız o alan
await d.kare('/tmp/gib.png');            // ekran karesi dosyaya; { tamSayfa: true } bütün sayfa
```
- Aynı **"Dümen kimde"** kapısından geçer: Dümen Sultan'daysa okuma da YOKTUR (`KapiHata.neden = sultanda`), kare dosyası yazılmaz.
- Okuma **eylem değildir**: eylem penceresi açmaz, sayfaya dokunmaz. Okunan metin ya da kare hiçbir kütüğe, merkeze, terminale yazılmaz; yalnız çağırana döner.
- Parola/SMS/kart alanını hedefleyen `metin(sel)` durma noktasına takılır (yazmadaki kapı). `innerText` giriş alanlarının değerini içermez.
- Ne işe yarar: Sultan Dümen'de bir siteye kendisi girer (ör. GİB, resimli güvenlik kodu), Dümen'i ajana verir; ajan yalnız okur, tıklama yalnız gezinmedir.

## Liste okuma (0.8.0 · BÂNİ 3 Kas · pazaryeri-mesaj)
```js
const kimlikler = await d.nitelikler('[data-thread-id].unresponded', 'data-thread-id');   // seçiciye uyan öğelerin niteliği (en çok 50)
const onizlemeler = await d.metinler('.unresponded .message-preview');                   // öğelerin görünür yazısı (en çok 50 × 2000 harf)
const adres = await d.adres();                                                           // sayfa adresi (giriş sayfası tespiti)
```
- Aynı salt-okur kapı: Dümen Sultan'daysa okuma yok; eylem penceresi açılmaz; dönen değer kütüğe/merkeze yazılmaz.
- `nitelikler` hassas nitelik adını (parola/çerez/jeton/kod/kart) **reddeder** (`KapiHata.neden = durak`); `metin()` tek öğe verirken bunlar listeyi verir.

## Masaüstü (0.2.0 · görev …F9Y2Y) — terminal dahil tüm masaüstü
`scripts/masa.mjs` → `new Masa({ merkez })` ajana `ekranAl / tik / yaz / tus / kaydir / durum` verir; hepsi masaüstü bekçisine (`masa-kopru.py`, `172.30.0.2:9224`) gider. Sözleşme: cloudtop `infra/dumen/SOZLESME.md` §5.
- **Çift kilit:** her çağrıdan önce `GET <merkez>/dumen/mod`; `ajan` değilse/cevapsızsa eylem yapılmaz (`⏸ Dümen Sultan'da · bekliyorum`, `KapiHata.neden = sultanda | merkez-cevapsiz`). Bekçi ayrıca kendi mod dosyasından 423 döner; 423 ve `sultan` iken bağlantı düşmesi **hata değil "sultanda"**. Mod `ajan`a dönünce ajan `ekranAl()` ile sıfırdan okur.
- **Durma noktası ajan tarafında** (masaüstünde alan türü görünmez): `yaz(metin, { alan })` **alan söylenmeden çalışmaz**; alan parola/SMS/kart/IBAN ise, `tik(x, y, { etiket })` etiketi öde/onayla/gönder/sil ise eylem YAPILMAZ, merkeze `durak` gider (`KapiHata.neden = durak`). Tek karakterli `tus` aynı kapıdan geçer (harf harf şifre yazımı delik olmasın).
- Terminal kullanımı: `tus('ctrl+alt+t')` → `ekranAl()` ile terminali gör → `yaz('komut', { alan: 'Terminal' })` → `tus('Return')`.
- Jeton: `/config/dumen-masa-jeton` (ya da `DUMEN_MASA_JETON`), dosyadan okunur, basılmaz. Yazılan metin ve ekran günlüğe girmez.
- Sınav: `bash scripts/masa.test.sh` — sahte merkez + sahte bekçi, 29 kapı + 10 mutant (Chromium gerekmez). **Gerçek ekranda ölçülmedi:** canlı kanıt kurulumdan (Sultan-eli `masa-kopru-kur`) sonra.

## 📕 HATA KATALOĞU — belirti → sebep → ne yap
Yeni bir takılma görürsen buraya satır eklenmesi için bulgu yaz. "Ölçülmedi" yazan sebep tahmindir.

| Belirti | Sebep | Ne yap |
|---|---|---|
| Tıklamadan sonra betik onlarca saniye yanıtsız (5 Kas, iki kez, 80-85 sn) | Eylemlerin süre sınırı yoktu; örtülü öğeye tıklama sonsuza dek yeniden deniyordu (kesin kök canlıda ölçülmedi) | 0.9.0: her eylem 15 sn + sert tavan 45 sn. `zaman-asimi` gelince `kare()` ile bak, `engelKapat()`, `ogeDurumu()` |
| Betik yarıda kesildi, sekme açık kaldı | `kapat()` çağrılmadı | `Dumen.kos` kullan; kapat iki kez çağrılabilir, kendi açtırdığı sekmeleri de toplar, bağlantı düşmüşse sekmeyi kimliğiyle kapatır. Kapatılan bağlantı yeniden eylem yapmaz (`kapali`) |
| Olmayan öğede okuma ya da eylem 30 sn bekliyor | Durma noktası ölçümünün süresi uygulanmıyordu | 0.9.0'da düzeldi (1,5 sn). Öğe var mı diye `ogeDurumu(sel).sayi` |
| `indir` `indirme-yok` döndü, oysa dosya ekranda duruyor (Trendyol "Fatura Görüntüle", 5 Kas) | Panel dosyayı sayfa içi pencerede geçici adreste (`blob:`) açıyor: indirme olayı da yeni sekme de yok; indir ikonu görüntüleyicinin kendi çubuğunda | 0.9.1'den beri `indir` bunu kendisi alır. Pencere zaten açıksa `indirGomulu('iframe[src^="blob:"]', yol)`; adres elindeyse `indirAdres(blobAdresi, yol)`. Görüntüleyicinin düğmesine tıklamaya çalışma |
| İndirilen dosya bulunamıyor | Dosya tarayıcının makinesine düşer; ajan kutusundan o diske yol yok, `saveAs` uzak tarayıcıda çalışmaz | `indir(sel, hedef)` ya da `indirAdres(adres, hedef)` |
| "Görüntüle" dosyayı yeni sekmede açıyor | Bağlantı yeni sekme hedefli | `indir(sel, hedef)` yeni sekmeyi de karşılar; yalnız adres gerekiyorsa `yeniSekmeAdresi(sel)` |
| İnen "PDF" aslında giriş sayfası | Oturum düşmüş, site dosya yerine giriş ekranı döndürüyor | `indirme-sayfa` hatası bunu yakalar. Sultan'a tek kez yaz, parolaya dokunma |
| Dosya yüklenemiyor ("PDF seç") | Sürücüde yükleme yoktu | `yukle(sel, dosya, { onay })`; input yoksa `{ secici: true }` |
| Sekmeye ya da düğmeye tıklanmıyor (süre doluyor) | Çerez şeridi, tanıtım turu, anket çerçeveleri örtüyor | `engelKapat()`; siteye özel katman için `ek` ve `gizle` |
| Tıklama "oldu" ama hiçbir şey değişmedi | Metin seçicisi gizli bir eşe çözüldü (Vue/React arayüzlerinde menünün gizli kopyası) | `ogeDurumu(sel)` → `sel >> nth=<ilkGorunur>` ya da seçiciye `>> visible=true` ekle |
| Yazı alanına yazılamıyor | Alan pasif (ör. açık talep varken mesaj kutusu) | `ogeDurumu(sel).etkin`; önce alanı açan adımı (talep düğmesi) yap |
| Özel açılır listede normal tıklama süre aşıyor | Bileşen kendi katmanını çiziyor | Önce `engelKapat()` ve `ogeDurumu()`; yalnız görünür ve etkin ölçüldüyse `{ force: true }` |
| Çok adımlı form yeniden bağlanınca sıfırlanıyor | Yeniden bağlanma sayfayı yeniden yükler (Dümen Sultan'a geçip dönünce) | Formu tek süreçte, tek seferde doldur; `durum().baglanmaSayisi` arttıysa formu baştan ölç |
| `⏸ Dümen Sultan'da` | Dümen insanda | Hata değil. `dumen-bekle.mjs` ile arka planda bekle |
| Bağlanırken "Target page, context or browser has been closed" | Sultan tarayıcıyı yeniden açmış olabilir (kök ölçülmedi) | Bir kez yeniden dene; sürerse bulgu yaz, MİRAHUR'a haber ver |
| Site 403 ya da doğrulama sayfası veriyor | Bazı siteler sunucunun çıkış adresini engelliyor; bir kez de merkez tarayıcı kuralı çıktı | Pozitif kontrol yap (çalışan bir site), ikisini bulguya yaz; ajan hatası sayma |
| `metin()` sayfanın menüsünü de getiriyor | Varsayılan hedef bütün gövde | `metin('<içerik seçicisi>')` |
| Oturum açık mı belli değil | Giriş ekranı gecikmeli gelir | `goto` sonrası `bekle('<içerik seçicisi>')`, `adres()` ile giriş adresine bak |
| İki ajan aynı anda Dümen'de | Ajanlar arası kilit yok | Her ajan kendi sekmesinde kalır (varsayılan yeni sekme); eşzamanlı kullanımı reis koordine eder |
| Masaüstündeki boş pencere kapanınca tarayıcı da kapandı | Ölçüldü (27 Eki); kök çözülmedi | O pencereyi kapatma; gözetmen tarayıcıyı yeniden açar |

## Dürüst sınırlar
- **Canlı ölçüm sınırlı.** 0.9.0 gerçek Dümen'de zararsız denemeyle ölçüldü (5 Kas: adresle indirme, onaysız yükleme reddi, sert süre). 0.9.1'in blob yolu gerçek Dümen'de fikstür sayfasıyla ölçüldü; gerçek Trendyol fatura penceresi ilk vakadır. Sınav headless Chromium 149 / playwright-core 1.59.1 ile koştu. Gerçek Chrome'da PDF yeni sekmede görüntüleyicide açılır (sınav tarayıcısında indirmeye döner); o dal sınavda resimle ölçüldü, PDF görüntüleyicisiyle ölçülmedi. İlk gerçek vaka: Trendyol fatura gönderimi ve etiket indirme.
- Ajan bağlıyken Playwright tarayıcının indirme ayarını değiştirir; Sultan'ın o sırada indirdiği dosyanın İndirilenler'e adıyla düşmeyebileceği kaynaklarda yazıyor, canlıda ölçülmedi (bulgu açık).
- Yükleme onayı bir zorlama kapısıdır, kimlik doğrulaması değildir: damganın gerçekliğini sürücü ölçemez (A06 ajanın sorumluluğudur).
- `engelKapat` bilinen kalıpları tanır (çerez, tur, Qualaroo); tanımadığı katmanda hiçbir şey yapmaz ve rapor boş döner — kareye bak, `ek`/`gizle` ver, bulgu yaz.
- Kapı **ajan tarafındadır** ve disiplinle çalışır: aynı süreçte `playwright-core`'u doğrudan içe aktaran kod kapıyı atlayabilir — gerçek zorlama köprüdedir.
- Kapı **ajan tarafındadır**; Chrome'a giden yolu fiziksel kesen bekçi köprüdedir (BÂNİ B1). İkisi birlikte çift kilit.
- Dinleyici sınavı Chromium headless shell 149 / playwright-core 1.59.1 ile; Dümen'in Chrome 150 / Playwright 1.61'inde yeniden koşulmalı.
- Durma noktası sezgisi (alan türü/ad/ödeme yolu) yanlış negatif verebilir; son savunma bekçide (ağ kapısı).

## Sultan'dayken bekle — geri verince uyan (0.4.0 · görev …9JMK89)
`⏸ Dümen Sultan'da · bekliyorum` satırını görünce BEKLEMEYİ arka plana bırak: Bash'te `run_in_background:true` ile
`node scripts/dumen-bekle.mjs --merkez "$DUMEN_MERKEZ"` (varsayılan: en çok 120 dk, 10 sn aralık; `--azami-dk`, `--aralik-sn`).
Komut yalnız `GET <merkez>/dumen/mod` okur (jeton yok, yazma yok); bekleme sırasında hiçbir şey basmaz; mod `ajan` olunca tek satır `▶ Dümen geri verildi … devam edebilirsin` basıp rc 0 ile biter — arka plan komutunun bitişi seni uyandırır.
Çıkış kodları: **0** ajanda (zaten ya da geri verildi) · **3** süre doldu, Dümen hâlâ Sultan'da (SERDAR'a haber ver ya da yeniden bekle) · **4** merkez art arda 6 okumada cevap vermedi — kimde olduğu bilinmiyor, ÖLÇÜLEMEDİ (devam sayılmaz) · **2** merkez adresi yok.
Merkez ajana doğrudan zil çalamaz (tmux yolu yok); uyanma yolu bu bekleyicidir. Sultan'a süre hatırlatması merkez tarafındadır (cloudtop terminal-merkez), bu beceride değil.

## Sınav
`bash scripts/dumen-dosya.test.sh` — 0.9.1: sahte merkez + iki sahte site (ikinci köken) + gerçek headless Chromium, 63 kapı + 30 mutant (sayfaya gömülü blob: dosya · önceden açık pencerenin alınmaması · blob adresle indirme · adres türü denetimi · onaysız yükleme · bayat/başka dosyanın onayı · izinli dizin dışı · bağ · sır yolu · giriş sayfasını dosya sayma · tür ölçmeme · başka köken yedeği · açık kalan sekme · her Reddet'e tıklama · onaysız çerez kabulü · ödeme sayfasında engel · sert süre yok · süresiz eylem · kapat/kos sekme bırakır · dosya yolunu yazdırma · kapıda asılma · süre dolunca eylemin kesilmemesi · kapı ve eyleme ayrı süre · kapatılan bağlantının yeniden eylem yapması · bağlantı düşmüşken açık kalan sekme).
`bash scripts/dumen-bekle.test.sh` — sahte merkez + GERÇEK süreç (Sultan'dayken çıkmaz, geri verilince rc 0 ile çıkar), 12 kapı + 9 mutant.
`bash scripts/dumen.test.sh` — sahte merkez + gerçek headless Chromium, 29 kapı + 10 mutant (fail-open · merkez cevapsız→devam · durma noktası kapalı · durak bildirimi 5xx'i başarı sayar · ham page dışarı açık · parola gizleme yok · jetonsuz bildirim · soket düşünce ham hata · sultan iken yeniden bağlanma · ajan olunca bağlanmama). Chromium yoksa rc 3 ÖLÇÜLEMEDİ.
