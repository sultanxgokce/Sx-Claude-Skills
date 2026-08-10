---
name: layiha
version: 1.13.1
description: Bir konuyu kapsamlı ARAŞTIR, kalıcı bir tasarım-dokümanına (layiha) SABİTLE, inşayı SONRAYA bırak — kayıt-defterine işle, Sultan'a sabit-formatta teslim et + geri-dönüş-kolu bırak. İnşa bitince BAĞIMSIZ-AJAN (MÜHÜRDAR) tescili gerekir: "insa-edildi ≠ tescilli". "araştır inşayı sonra yaparız · bunu dökümana sabitle · layiha çıkar · aktif/tescil-bekleyen layihaları listele · bu haftaki layihalar" tetiğinde. GLOBAL (tüm container'lar).
allowed-tools: Bash, Read, Write, Edit, Agent, AskUserQuestion
---

# /layiha — araştır → kalıcı sabitle → inşayı sonraya bırak (+ kayıt-defteri)

> **Ad:** *layiha* (Osmanlıca لايحه) = bir mesele üzerine hazırlanıp karar-merciine sunulan yazılı rapor/tasarı.
> **GLOBAL skill** — her container'da çalışır; defter **per-container** (İ1: container'lar birbirinin layihasını görmez).

> **Bu skill çağrıldığında sen LAYİHACI'sın** (layiha iş-akışı sahibi meta-personası). Kimliğin & kanunların:
> `_agents/layihaci/AGENT.md` — **varsa önce onu oku** (Nexus-merkezi kayıt; izole-container'da dosya yoksa bu skill
> talimatları kimliğini taşır — kimlik-boşluğu değil). Manuel-meta persona: **cwd-hook YOK**, yalnız `/layiha` ile
> aktive; `author=` provenance-SINIFI (persona-adı DEĞİL), persona registry'de yaşar. Rolün: SERDAR'ı
> meta-katiplikten kurtarmak (araştırmayı sahiplen → sabitle → teslim et → tescile sevk et).

**Ne zaman:** Sultan "bunu araştır ama inşayı sonra yaparız / kapsamı net olsun şimdilik" dediğinde; VEYA
"aktif layihaları/bu haftakini listele" dediğinde. Amaç: iş **kaybolmasın** + Sultan'ın önüne tek-tuşla-devam gelsin.

## Değişmezler
- **SALT-ARAŞTIRMA — İNŞA YOK.** Doküman kod/host'a dokunmaz.
- **Kanıtsız-yeşil YASAK** (firsthand dosya:satır/URL). **Provenance-dürüstlüğü**: alt-ajan yaptıysa
  "kendi altımda araştırma alt-ajanı koşturdum" de; persona-adıyla sunma (ağır+persona-hafıza→gerçek-oturum).
- **Kayıp-riski panzehiri:** doküman ASLA yalnız untracked kalmaz → 3-kanal + **kayıt-defteri** zorunlu.

## MOD 1 — YENİ LAYİHA (araştır → sabitle → teslim)

### 0 · Kapsam (kısa)
konu · neden şimdi-inşa-değil · bakılacak mevcut-parçalar · efor (default yüksek). Slug = ASCII-kebab.

🔴 **HÜCRE — Sultan'a SOR, tahmin etme (L66/NİZAM, Sultan-direktifi 2026-08-08):**
*"AI ajan bana 'hangi tip ilişki' diye sormalı, gerekirse yenisini eklemeyi önerebilmeli —
free/kenarsız çalışmıyoruz."* Bu iş hangi **NİZAM hücresinde** çalışacak? İki eksen DİKTİR:

| Eksen | Soru | Değerler |
|---|---|---|
| **SUBSTRAT** | taraflar birbirine nasıl ULAŞIR? | `OTAG` (aynı kutu, canlı pane) · `MIZAN` (ortak araç diski + META havuz) · `MENZIL` (kutu↔kutu röle) · `KAPI` (Sultan yüzeyi) |
| **AKIŞ** | iş hangi rollerden GEÇER? | `DIVAN` (tara→süz→Sultan→inşa→mühür) · `LAYIHA` (araştır→sabitle→teslim→inşa→tescil) · `OLCUM` (üret→kapı→hüküm→ders→kural) |

Cevap adım-2'de `--hucre "<SUBSTRAT> x <AKIŞ>"` olarak deftere geçer (ör. `--hucre "MIZAN x OLCUM"`).

✅ **`belirsiz` MEŞRU CEVAPTIR.** Hiçbir hücreye oturmuyorsa `--hucre belirsiz` yaz — bu bir hata
değil, **yeni-tip arzının ham maddesidir**. Uydurma bir hücreye sıkıştırmak işi yanlış kutuya sokar;
ölçüldü. Küme-dışı bir ad yazarsan defter kaydı REDDEDER (rc=2) — küme kapalıdır, ama genişletme
kapılıdır: yeni tip gerekiyorsa Sultan'a **öner**.

⚠️ Boş bırakmak ≠ `belirsiz`: boş "hiç sorulmadı" (bilgisizlik), `belirsiz` "bakıldı, oturmadı" (bilgi).

### 1 · Araştırmayı dispatch et
Varsayılan = SERDAR-altı araştırma alt-ajanı (Agent `general-purpose`, `model:opus`, `run_in_background`).
Prompt kalıbı (ZORUNLU): *"Araştırma alt-ajanısın, persona değilsin. SALT-ARAŞTIRMA — İNŞA YOK, host'a dokunma.
Her iddia firsthand dosya:satır. [1] problem-doğrulama [2] mevcut-parça envanteri [3] gap-listesi [4]
tasarım-seçenek+ÖNERİ [5] fazlama(additive/INERT) [6] açık Sultan-kararları [7] risk+panzehir. Dokümanı
`_agents/spec/<slug>-DESIGN.md`'e YAZ (başlık: 'Statü: SALT-ARAŞTIRMA — İNŞA YOK'), commit ETME. 12-15 satır
özet döndür."* Ağır+persona-hafıza→gerçek-oturum (aile-dispatch).

### 2 · Dönünce — 3-KANAL + DEFTER (ZORUNLU)
1. **git-durable:** origin/main worktree → doc kopyala → commit (scopeless `docs: <konu> araştırma DESIGN`) →
   PR → `scripts/wait-ci.sh <#> &` → yeşil → merge → worktree temizle.
2. **memory-topic:** `project_<slug>.md` + MEMORY.md pointer + RESUME-TETİK cümlesi.
3. **defter:** `append-note.sh` özet + resume.
4. **KAYIT-DEFTERİ (YENİ):** `bash <skill-dizini>/scripts/layiha-defteri.sh ekle --slug <slug> --konu "<konu>"
   --dokuman "<yol>" --pr "#<PR>" --resume "<resume-cümlesi>" --isteyen "Sultan|<AJAN>" [--yetki "<beyan>"]
   --hucre "<SUBSTRAT> x <AKIŞ>|belirsiz"`
   → durum=insa-bekliyor.
   ⚠️ **`--hucre` YAZ** (L66): adım-0'da sorduğun hücre buraya geçer. Verilmezse kayıt yazılır ama
   uyarı basılır ve hücre BİLİNMİYOR kalır — hücre-başına iş hacmi ölçülemez, katalog körleşir.
   ⚠️ **`--isteyen` YAZ** (K2): bu alan boş kalırsa kayıt "isteyeni bilinmeyen" olur — Sultan'ın
   istediği iş ile ajanın kendi açtığı iş defterde ayırt edilemez. Boş bırakmak `ajan` demek DEĞİLDİR;
   tahmin edilmez, "bilinmiyor" olarak durur ve süzgeçte ayrıca sayılır.
   ⚠️ `--konu` **"\<Kısa Ad (2-3 kelime)\> — \<detay\>"** biçiminde yazılır; baştaki Kısa Ad, adım-3'teki
   **LAYİHA İLANI**'nda kullanılan adla BİREBİR aynı olmalı (ilan ↔ defter ↔ liste tutarlılığı).

### 3 · Sultan'a TESLİM — **LAYİHA İLANI** (SABİT FORMAT, birebir · Sultan-direktifi 2026-07-23)

Sultan bu bloğu **kopyalayıp not defterine yapıştırır** → tek parça, kendi-kendini-açıklayan, jargonsuz olmalı.
Tek bir ``` kod-bloğu içinde ver (kopyalanabilirlik şartı). Şablon:

````
```
📋 LAYİHA <KOD> · <Kısa Ad (2-3 kelime)>
tarih: <YYYY-MM-DD> · durum: inşa bekliyor

<Sultan-dilinde AÇIKLAMA PARAGRAFI — 3-6 cümle, jargonsuz, düz Türkçe.
Şu üç soruyu yanıtlasın: (1) sorun neydi, (2) araştırma ne buldu / ne öneriyor,
(3) yapılırsa ne değişir. Kısaltma/kod-adı kullanma; kullanırsan parantezle açıkla.>

Öneri: <tek cümle — hangi seçenek ve neden>
Karar bekleyen: <N> soru (dokümanda madde madde)
Doküman: _agents/spec/<slug>-DESIGN.md  (git: #<PR>)
Devam etmek için: "<resume-tetik cümlesi>" de
```
````

**Kurallar:**
- **Kısa Ad = 2-3 kelime**, Sultan'ın defterinde tek bakışta tanıyacağı ad (ör. "PR-Merge Kapısı", "Vault Ölçeklemesi").
  Slug DEĞİL, başlık-cümlesi DEĞİL.
- **Açıklama paragrafı Sultan-dilinde** — `/sultanca` üslûbu geçerli; teknik jargon (INERT, additive, fail-closed,
  parity…) yasak ya da parantez-açıklamalı. Rakam/somut varsa yaz ("6 container'dan 20'ye").
- Blok DIŞINA kısa bir kapanış cümlesi ekleyebilirsin (ör. "sıradaki adım şu"), ama **blok kendi başına tam** olmalı.
- **Ekleyebileceklerin** (değer katıyorsa; katmıyorsa yazma): `Engel:` (varsa neyin beklendiği) · `Bağlı olduğu:`
  (başka layiha kodu) · `Kim inşa eder:` (domain-routing sonucu: infra→NÂZIR · vault→HAZİNEDAR · skill→AHÎ ·
  container→KONAKÇI · genel→icra-motoru).
- Birden çok araştırma → her biri **AYRI ilan bloğu**.

⚠️ İlan, defter-kaydı ve DESIGN-doc'la **tutarlı** olmalı (kod · kısa-ad · resume-cümlesi birebir aynı) — ilan
"pazarlama" değil, kaydın insan-yüzü.

### 4 · İnşa ERTELENİR → sonra BAĞIMSIZ-TESCİL (insa-edildi ≠ tescilli)
Build YALNIZ Sultan resume-cümlesini söyleyince. İnşa BİTİNCE:
```
layiha-defteri.sh durum <kod|slug> insa-edildi --kanit "<ref>"
```
→ kayıt **otomatik tescil-kuyruğuna** girer (`📋 tescil bekliyor`). Her kayıt otomatik bir KOD alır —
`<CELL>-L##` biçiminde (CELL = NİZAM hücre-kimliği, `CELL_ID` env'inden; unset → `s01`, ör. `s01-L37`).
K6 (2026-08-10) öncesi kayıtların öneksiz kodu (`L01`, `L35`…) DEĞİŞMEZ ve aynen tanınmaya devam eder —
`durum` komutu hem eski öneksiz hem yeni önekli kodu ya da slug'ı kabul eder.

⚖️ **KANIT KAPISI (K7 · Sultan-kararı 2026-07-29): "bitti = kanıtlı".** `insa-edildi`'ye geçiş **kanıtsız
REDDEDİLİR** (RC=2 + tek-satır reçete). Bu, defterin (`defter-mailbox.sh durum … --kanit`) en iyi
özelliğiydi ve layihada yoktu: "bitti" demek serbestti, kimse PR/commit/rapor göstermek zorunda değildi.
- Kabul edilen `--kanit` biçimleri: **PR referansı** (`#123` ya da URL) · **commit sha** (≥7 hex) ·
  **MEVCUT bir dosya yolu** (mühür/rapor). Biçimi tutmayan ya da var-olmayan yol **reddedilir**.
- Kanıt kayda `insa_kanit` alanına yazılır; `liste`'de `kanıt:` satırı + porcelain 12. sütunu olarak görünür.
- Diğer geçişler (`insa-bekliyor`, `insa-ediliyor`) kanıt **İSTEMEZ**.
- Geriye-uyum: K7 öncesi kayıtlarda alan **yoktur** → okuma-anında `""` sayılır; **hata yok, göç yok**.

⚖️ **İZİN KAPISI (K7'nin başlangıç-yüzü · Sultan-kararı 2026-08-08): "başlıyorum = izinli".**
Bir kalemi `insa-ediliyor`a almak artık **izin beyanı ister**; izinsiz geçiş **RC=2 ile reddedilir**.
```
layiha-defteri.sh durum <kod|slug> insa-ediliyor --izin "Sultan onayı 2026-08-08"
```
Gerekçe: "bitti = kanıtlı" kuralı vardı, ama bir işin kimin izniyle BAŞLADIĞI hiçbir yere
yazılmıyordu — sonradan "bunu kim başlattı?" diye sorulduğunda defterde cevap yoktu.
Beyan serbest metindir (kapı içeriği değil, VARLIĞINI zorlar); `yok`/`n/a` gibi yer-tutucular reddedilir.

⚖️ **TERS KAYIT (K5): yanlış girilen iddia SİLİNMEZ, geri alınır.**
```
layiha-defteri.sh geri-al <kod|slug> --gerekce "kanıt yanlış PR'a işaret ediyordu"
```
Durum `insa-bekliyor`a döner, kanıt/izin temizlenir, kayıt tescil kuyruğundan çıkar — ama **hiçbir şey
kaybolmaz**: eski durum + eski kanıt + gerekçe kaydın `gecmis` alanına ters-kayıt olarak düşer.
Silmek izi yok eder, ters kayıt izi çoğaltır.
🔴 **Tescil VERDİKTİ verilmiş kayıt geri alınamaz** (`tescilli`/`reddi`/`muaf` → RC=2). Verdikt bağımsız
ajanın hükmüdür; üretici onu geri alamaz — değişmesi gerekiyorsa MÜHÜRDAR'a gidilir.

⚖️ **`insa-edildi` TERMİNAL DEĞİL** — üretici-beyanı. Terminal-başarı = **bağımsız-ajan (MÜHÜRDAR) TESCİL'i**
(Sultan-kararı 2026-07-22 · üreten ≠ doğrulayan). Üretici kendi işini tescil-EDEMEZ.

## MOD 3 — TESCİL (bağımsız-ajan kör-doğrulama kapısı)
İnşa-edildi bir layiha için tescil (MÜHÜRDAR / kör-tescil sahibi yürütür; kör-protokol: DESIGN-doc'u OKUMA,
yalnız SERDAR'ın yazdığı GEREKLILIK + build-worktree'yi taze koş):
```
layiha-defteri.sh tescil <kod|slug> <tescilli|reddi|muaf> [--vites TAM|HAFIF] [--kart k####] \
    [--muhur <MUHUR.md|muhur-ozet.json yolu>] [--ajan AD] [--gerekce "..."]
```
- **TAM** (orta/büyük layiha): normal DİVAN-kartı (k####) → MÜHÜRDAR `/tescil` → GEÇTİ →
  `tescil <kod> tescilli --vites TAM --muhur <yol> --kart <k>`. Script **muhur-ozet.json verdikt=GECTI**
  doğrular + sha256 tutar; **çıplak-flip reddedilir** (sahte-tescil panzehiri).
- **HAFİF** (küçük layiha): `tescil <kod> tescilli --vites HAFIF --gerekce "<tek-G kanıtı>"` (kart-açmadan).
- **reddi** (tescil geçmedi) / **muaf** (Sultan-kararı, tescilsiz-kapat): `--gerekce` ZORUNLU.
- **İzole-container** (MÜHÜRDAR yok): `bekliyor`da AÇIK bırak — sahte-`tescilli` ASLA; merkeze tescil-isteği emit.
- **Kim sevk eder:** **LAYİHACI** (bu persona) GEREKLILIK yazıp kartı açar → **MÜHÜRDAR** kör-koşar (üreten ≠
  doğrulayan; LAYİHACI GEREKLILIK-yazar, tescil-EDEMEZ). LAYİHACI yoksa / izole-container'da SERDAR sevk eder.

## MOD 2 — LİSTELE (önizleme + inşa-durumu + TESCİL-durumu + zaman-filtresi)
Sultan "aktif/tescil-bekleyen layihaları listele / bugünküleri / bu haftakini / bu hafta bitmemişleri göster" deyince:
```
bash <skill-dizini>/scripts/layiha-defteri.sh liste [--aktif(default) | --bugun | --hafta | --hafta-bitmemis | --tescil-bekleyen | --hepsi] \
     [--sultan | --ajan | --isteyeni-bilinmeyen]
```
**KİM EKSENİ (K3):** Sultan "benim istediklerimi göster" deyince `--sultan`; "ajanların kendi
açtıkları" için `--ajan`. Bu eksen zaman/tescil ekseninden **bağımsızdır** — `--aktif --sultan`
birlikte çalışır.
🔴 **Sessiz eleme yok:** `isteyen`i yazılmamış (eski) kayıtlar hiçbir kim-süzgecine düşmez, ama
**kaç tanesinin elendiği ekrana basılır** ve `--isteyeni-bilinmeyen` ile görülür. Süzülmüş bir
listeye bakıp "hepsi bu kadarmış" sanmak, bu defterin en pahalı hatasıydı.
- **--aktif** (default): **terminal-olmayan** tümü — insa-bekleyen + inşa-edildi-ama-**tescilsiz** dahil
  (tescilsiz iş "bitti" SAYILMAZ → aktif kalır; Sultan-ilkesi).
- **--tescil-bekleyen**: inşa-edildi + tescil-kuyruğunda bekleyenler (toplu-tescil görünümü).
- **--bugun** · **--hafta** · **--hafta-bitmemis** · **--hepsi**.
Her satır: **[KOD]** + inşa-durumu (⏳/🔨/🔧 tescilsiz) + konu + **TESCİL** (🏅 tescilli / 📋 bekliyor / ↩ reddi /
⊘ muaf) + oluşturulma-tarihi + "…de" devam-cümlesi. Çıktı zaten Sultan-dili → olduğu gibi bas. Defter boşsa "kayıt yok".

**L24 F4 ile gelen üç değişiklik:**
- **Başlıkta "hangi çekmeceyi açtım" satırı var** (`oda: <ad> · defter: <yol>`). Defter odaya özeldir;
  aynı cümle bir odada yedi satır, başkasında sıfır gösterebilir — **ikisi de doğrudur**. Bu satır o
  yanılgıyı kaynağında keser. Sultan'a listeyi verirken bu satırı da göster.
- **`liste` SALT-OKURDUR.** Artık deftere hiçbir şey yazmaz (eskiden eksik alanları doldurup dosyayı
  baştan yazıyordu — ortak bir dosyada "sadece listeledim" demek yazma-yarışıydı).
- **Tanınmayan bayrak sessizce yutulmaz** → RC=2 + geçerli bayrak listesi. (`--proje Nexus` gibi bir
  yazım eskiden filtresiz listeyi süzülmüş sanmana yol açıyordu.)

## MOD 2b — FİLO GÖRÜNÜMÜ (K3: "evet, yalnız başlıklar")
Sultan "bütün odalardaki layihaları göster / hepsini tek ekranda gör" deyince:
```
bash <skill-dizini>/scripts/layiha-filo.sh [--aktif(default)|--bugun|--hafta|--hafta-bitmemis|--tescil-bekleyen|--hepsi]
```
Her satır: **oda adı** + [KOD] + durum-simgesi + **yalnız başlık**. Devam-cümlesi, doküman yolu ve kart
numarası **bilerek basılmaz** — detay odasında kalır (federe "yalnız-META" deseni).
- **Hiçbir dosyaya yazmaz**, ortak dizine birleşik defter KONMAZ.
- **Görünürlük sınırı dürüstçe basılır:** yalnız bu makineden görünen odalar sayılır; izole
  container'ların defterleri buradan görünmez (İ1) — bu arıza değil, kuralın kendisi.

## Kayıt şeması (L24 F4)
Her kayıt `v` (şema-sürümü) + `proje` (hangi oda) taşır. **İleri-uyum kapısı:** defterde bu araçtan
daha YENİ sürümlü kayıt varsa araç DURUR ve **hiçbir şey yazmaz** — eski bir kurulum yeni şemalı
defteri ezip alan kaybettiremez. Eski sürümsüz kayıtlar okuma-anında `v=1` sayılır; **göç yok**.

## Paket-içi kitaplık — `scripts/hat-yolu.lib.sh` (L24 F1)

Hattın **tek yol-çözüm kapısı**; kardeş paketler (`kasif-tara` · `mucit-suz` · `layiha-fabrikasi`)
`<skill-dizini>/../layiha/scripts/hat-yolu.lib.sh` ile source eder (vendoring YOK, tek-ev).
`hat_root` (worktree-immün, `--git-common-dir` tabanlı) · `hat_onek` (CELL_ID) · `hat_yolu <artefakt>` ·
`hat_tani` (hangi kök/hücre — "hangi deftere bakıyorum" satırı).
**⛔ Ortak-mount fallback'i YOK** (Sultan-kararı K1): git-kökü yoksa `$HOME/.claude/...`'e düşmez,
**RC=2 + reçete** verir — `/config/.claude` 10 container'ın ortak dizinidir, oraya düşen defter İ1'i
geri-alınamaz biçimde deler. Kanıt: `scripts/hat-yolu.test.sh` (21 kapı; G2/G3 bugünkü yollarla
**bayt-aynılık**, G5 worktree-immünlük, G8 İ1 negatif-testi).
**Durum: INERT** — kitaplık tanımlı, henüz hiçbir script onu çağırmıyor; geçiş F2/F3'te yapılacak.

## Sınırlar / dürüstlük
- Skill kod-içermez (talimat + `layiha-defteri.sh` yardımcısı). İnşa-yetkisi VERMEZ; her build Sultan-GO.
- Defter per-container (İ1 yalnız-yerel); fleet-rollup gerekirse ayrı meta-iş.
