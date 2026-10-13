---
name: terminal-onar
description: Bir kutuda Sultan'ın canlı çalışma düzenini (tmux <kutu>-ana'daki Claude konuşması + web terminali + telefon ekranı + kurtarıcı ajan + dakikalık bekçi) KURAR, ÖLÇER ve ONARIR. "/terminal-kur · bu kutuya terminal kur · /terminal-onar · terminal bozuldu · web terminali açılmıyor · oturum kapandı · düzeni yeniden kur" tetiğinde; onarım merdiveni (bekçi / Onar düğmesi) kademe 1-2'de de bu beceriyi çağırır. Bütün kutularda koşar — adlar kutudan türer, hiçbir kutu adı koda gömülü değildir.
version: 2.4.0
---
# /terminal-onar — canlı düzenin onarıcısı

## Düzen (neyi koruyoruz)
| Parça | Ne | Sağlam sayılma ölçüsü |
|---|---|---|
| konuşma odası | tmux `<kutu>-ana` | oturum var |
| konuşma | `<kutu>-ana` içinde Claude (Sultan'ın ana konuşması) | Claude'un oturum kaydında `tmux=<kutu>-ana:` + süreç canlı |
| web kapısı | `kapi/sunucu.mjs` `:7681` → merkez (`terminal.mmepanel.com/<kutu>/`) — telefon ekranı (PWA), giriş (parola, imzalı çerez), mesaj/foto/tuş/Onar API'si. tmux `kapi-<kutu>` | `<taban>/giris` 200 · `<taban>/` girişsiz 302 |
| terminal | ttyd yalnız UNIX soketinde (`/config/.terminal-onar/ttyd.sock`, TCP portu yok), kapı `<taban>/tty/` altında sunar. tmux `ttyd-<kutu>` | soket `/tty/` 200 |
| kurtarıcı ajan | tmux `<kutu>-kurtarici` içinde ayrı Claude | aynı ölçü |
| bekçi | crontab `* * * * * … bekci.sh # terminal-onar-bekci` (+ kalıcı kopya `.oda/cron`) | satır var |

code-server terminali ve web terminali **aynı tmux oturumuna** bağlanır → birebir, canlı senkron.
Web terminali `tmux new-session -A` ile açılır: oturum yoksa kendisi kurar, boş ekrana bakmaz.

## Komutlar (hepsi `scripts/komut.sh` üzerinden)
```
bash .claude/skills/terminal-onar/scripts/komut.sh durum [--json]
bash .claude/skills/terminal-onar/scripts/komut.sh onar [--web-yenile]     # kademe 0 = sıfırdan inşa
bash .claude/skills/terminal-onar/scripts/komut.sh merdiven [--arka]       # K0 → K1 → K2 → K3
bash .claude/skills/terminal-onar/scripts/komut.sh duraklat "<sebep>" | devam
bash .claude/skills/terminal-onar/scripts/komut.sh gunluk [N]
```
Argüman `onar` ile çağrıldıysan: önce `durum`, sonra `onar`, sonra yine `durum`. Sağlam değilse
günlüğe bak, sebebi bul, `onar --web-yenile` dahil tekrar dene. Sağlam olmadan "bitti" deme.

## Onarım merdiveni (yarıda kalmaz)
1. **K0** `onar.sh` — betik; eksik parçayı kurar, sağlam parçaya dokunmaz. Konuşmayı hep **aynı
   kimlikle** geri açar (`/config/.terminal-onar/ana-oturum`), asla "son oturum"la (aynı klasörde
   başka ajanlar da çalışır; `--continue` yanlış konuşmayı açabilir).
2. **K1** başsız Claude (`claude -p`, 10 dk) — yalnız bu betiklere + okumaya izinli.
3. **K2** kurtarıcı ajan — `/terminal-onar onar` komutu gönderilir, 20 dk izlenir.
4. **K3** Sultan'a WhatsApp: "elle bakılmalı" + durum + son günlük.

Tek kilit (flock) → iki merdiven aynı anda koşmaz. Merdiven ölürse bekçi bir dakika içinde yeniden
başlatır. Bekçi tetiklediğinde K1/K2 15 dakikada bir defadan sık denenmez.

## Değişmezler
- **Parolasız kapı ASLA açılmaz** (fail-closed; hem onar.sh hem sunucu.mjs reddeder). Parola kasada ve **anahtarın adı kutudan türer**: `<KUTU>__TERMINAL_SIFRE`
  (SEDİR kutusunda `SEDIR__TERMINAL_SIFRE`, AKAR kutusunda `AKAR__TERMINAL_SIFRE`). Sabit ad YAZILMAZ —
  yazılsaydı bir kutunun parolası ötekinin kapısını açardı (bağımsız göz tur 2'de yakalandı).
  (vault-cek). Değer hiçbir dosyaya, günlüğe, sohbete yazılmaz.
- 🔴 **PAROLA ÜÇ YERDE DURUR — biri değişirse HEPSİ BİRDEN değişir.**
  Kutunun kendi rafında (`secret/<kutu>/TERMINAL_SIFRE`) **ve** merkez sayfasının kendi rafında
  bir kopyası bulunur. Merkez kutu rafını okuyamaz (yalıtım iki yönlüdür), bu yüzden kopya
  zorunludur. Birini değiştirip ötekini unutmak **sessiz ayrışma** üretir: kapı doğru
  parolayla açılırken merkez yanlış parolayı dener ve kutu "bozuk" görünür.
  **ÜÇÜNCÜ kopya kutunun kendi ortam dosyasındadır** (kapı parolayı çalışırken oradan okur;
  SEDİR ölçümü, 2026-09-29). Kasadaki değer yenilenince ortam dosyası da yenilenmeli —
  yoksa kasa doğru, kapı eski parolayla açılır ve ayrışma yine sessiz olur.
  Sayının kendisi de bir uyarıdır: aynı sır üç yerde duruyorsa rotasyon kırılgandır.
  Parolayı değiştiren ya da yenileyen kişi ikisini birlikte değiştirmekle yükümlüdür.
- Ana konuşma başka bir yerde canlıysa **ikinci kopya açılmaz** (günlüğe uyarı düşer).
- Bilerek kapatırken önce `duraklat` — yoksa bekçi bir dakika içinde geri açar.
- Sınır: kutunun kendisi çökerse bu düzen de onunla gider; o durumda kurtarma kutu dışından
  (MUAVİN / host) gelir.

## Durum dosyaları
`/config/.terminal-onar/` — `gunluk.log` · `ana-oturum` · `kurtarici-oturum` · `kademe.durum` · `duraklat`.
Sultan-onayı: 2026-09-25 (gözetimsiz ajan kademeleri dahil).

## 🆕 Kurulum — `/terminal-kur` (2.0.0)

```
TERMINAL_KUR_ONAY=sultan-verdi bash <beceri>/scripts/kur.sh
```

Kutuda sırasıyla: ttyd'yi indirir → parolayı kasadan okur → düzeni kurar → bekçiyi kutunun
**kalıcı** cron'una yazar → ölçer → merkeze düşecek satırı basar.

🔴 **Sultan onayı ZORUNLU ve dolanılmaz.** Bu kurulum kutuda bir **dış yüzey** açar ve
gözetimsiz bir onarım kademesi kurar. Claude Code güvenlik sınıflandırıcısı bu iki adımı
bilerek reddediyor ("Expose Local Services" · "Create Unsafe Agents"). Betik onaysız
çalışmayı **denemez**, sebebini söyler ve durur. Gizli yol aranmaz.

🔴 **Parola ÜRETİLMEZ.** Kasada yoksa kurulum durur ve Sultan'ın koşacağı satırları basar.
Sessizce üretilen parola kayıtsız bir sırdır: sıfırdan kurulumda geri gelmez.

🔴 **Host tarafına DOKUNMAZ.** Tünel · Access · merkez kaydı kutu ajanının işi değildir;
betik yalnız merkeze iletilecek satırı basar, onu MUAVİN işler.

## 🆕 Koltuk seçici — her oturum bir koltuk (2.1.0)

Sultan'ın hedefi (12 Ekim): *"tüm kutuları ve içlerinde çalışan claude sessionların terminal akışlarını
terminalde claude kullanır gibi birebir görüp sohbet edebilmem lazım."* Kapı bugüne dek tek oturuma
(`<kutu>-ana`) bağlıydı; oysa kutularda koltuk = tmux oturumu (maiset 5 · tellal 7 · nazir 10 · vekatip 12).

| Parça | Nerede | Ne yapar |
|---|---|---|
| ekran | `/<kutu>/tty/?arg=<oturum>` | ttyd `-a` adresteki `arg`ı komuta son argüman olarak ekler; argümansız → ana oturum (eski davranış bayt bayt aynı) |
| karar | `scripts/koltuk-bagla.sh <ana> <proje> [koltuk]` | **tek kaynak**: ad dar kümeden mi (harf·rakam·`_`·`-`, ≤64) · kutuda **şu an var** mı (`tmux ls`) · gizli değil mi (`ttyd-*` · `kapi-*` · `*-kurtarici` · `imglistener`) — üçünden biri düşerse **red basılır, yeni oturum açılmaz, ana oturuma sessizce düşülmez** |
| seçici | telefon ekranı başlığı (`#koltuk`) | kutudaki koltuklar açılır listede (● = Claude çalışıyor); seçince tam terminal o koltukla açılır; tek koltuk varsa gizli; liste ölçülemezse gizli ("koltuk yok" demez) |
| liste | `GET /api/koltuklar` (girişli) | aynı betiğin `--liste`si: ad · son etkinlik · Claude var mı · ekran adresi; betik düşerse **500 "ölçülemedi"**, boş liste basılmaz |

🔴 **Niçin tek kaynak:** ttyd'nin kabul ettiği ad ile listede görünen ad iki ayrı yerden türeseydi ilk değişiklikte
ayrışırdı. Kapı betiğe sorar, kendisi türetmez; betiğin verdiği bozuk adı da süzer.
🔴 **Adres güvenilmez girdidir:** `BASIRET:0`, `=ad`, `../x`, 70 karakter — hepsi red (tmux hedef sözdizimi giremez).
Birden çok `arg` (belirsiz adres) ve ana oturumun adının **açıkça** verilip kutuda bulunmaması da reddedilir —
yalnız argümansız yol oturum yaratır (bağımsız göz, tur 1).
🔴 **Ölçemediğine "boş" demez** (bağımsız göz, tur 3): tmux listesi alınamazsa `--liste` rc=3 "ölçülemedi" döner, kapı 500 basar;
boş liste yalnız tmux sunucusu hiç yokken doğrudur. Liste alınamazken koltuğa da bağlanılmaz.
Sınav: `scripts/koltuk-bagla.test.sh` (30 kapı, sahte tmux) + kapı `Y1-Y10` + telefon ekranı **gerçek Chromium**
(`kapi/tarayici-sinav.mjs`, 10 kapı, CI dışı — kütüphane yoksa rc=4): seçici · seçince tam terminal `?arg=` ·
yerel bellekteki ad **doğrulanmadan terminale konmaz** (liste gecikirse ana koltukta açılır, liste gelince yeniden kurulur;
geçersiz ad hiçbir anda girmez). Mutasyon: beyaz liste silinince 4 kapı,
gizli süzgeci silinince 1 kapı, kapıda "boş liste" kaçağı 1 kapı, ad süzgeci 2 kapı kırmızıya döner.
🔴 **Dürüst sınır:** `--liste` Claude'u pane komutundan tanır; başka bir kabuğun içine gömülü Claude'u görmeyebilir
(yanlış-negatif). Son etkinlik tmux'un `session_activity` damgasıdır, konuşmanın değil.

## Koltuk türü ve hâli (2.2.0 · dilim 4, Sultan: "düzenli net sade")

`/api/koltuklar` her koltuk için iki alan daha döndürür; ikisi de `koltuk-bagla.sh --liste`'de ölçülür (kapı sormakla yetinir):
- **tür** `ajan` = Claude çalışan oturum · `diger` = geçici/arka plan (`cc-*`, `dash*`, `imglistener*`, `*-kurtarici`) ya da
  Claude'suz oturum (ana dahil — ana'nın önde durması türün değil `ana` bayrağının işi). Merkez varsayılanda ajanları + ana'yı gösterir, diğerleri katlıdır.
- **hâl** son 15 ekran satırından, filo yoklamasıyla AYNI desenler (`Nexus/scripts/filo.py hal()`): `calisiyor` ·
  `soru` · `sinirda` · `girdi` · `bos`; hiçbiri tutmazsa `bilinmiyor` (uydurulmaz); Claude'suz oturumda hâl ölçülmez → `bilinmiyor` (altı değer dışına çıkılmaz). Yalnız SON 15 dolu satır sayılır; soru deseni meşgul izini yener. **2.2.1:** capture-pane hedefi `ad:` (bölme hedefinde `=ad` geçersizdi → canlıda her koltuk 'bilinmiyor' çıkıyordu; sahte tmux artık `=` biçimini reddeder, D5-D12 bu hatayı ısırır).
Eski 3 alanlı betikle kapı alan eklemez (tür/hâl uydurulmaz). Sınav: `koltuk-bagla.test.sh` D1-D12b · `sunucu.test.mjs` Y10.

## Koltuk aç / yeniden aç / eski sohbete dön — tek tuş (2.4.0 · 13 Ekim, Sultan: "oturum kapandı/bozuldu/silindi — tekrar açmak çok basit, çok sağlam olmalı")
Telefon ekranında **Koltuk** düğmesi → pencere: seçili koltuğun durumu ÜÇ AYRI hâlde (`yok` · `claude-yok` · `takili` · `canli`)
ve tek eylem (Aç / Yeniden aç / Eski sohbete dön). Ölçüm ve iş `scripts/koltuk-ac.sh`'de (`durum <ad>` JSON · `ac <ad> [--eski]`);
kapı yalnız taşır: `GET /api/koltuk/<ad>` · `POST /api/koltuk/<ad>/ac {eski}` (rc 0→200 · 3→202 merdiven · 4→409 kayıtsız · 1→502).
- **Yol (kim açar):** kutuda `scripts/ekip-ac.sh` + aile kaydı varsa ve koltuk kayıtlı bir rolün tmux'uysa → `ekip-ac.sh <ROL>`
  (**tek kanonik kapı:** canlıysa ikinci kopya AÇMAZ; `--eski` → `--resume-if-known`, eski sohbete dönüş; Claude'suz/takılı oturum
  önce kapatılır, sonra doğar). Koltuk **ana** ise → `onar.sh` (K0), düşerse merdiven (`kademe.sh`). İkisi de değilse → **kayıtsız
  koltuk AÇILMAZ**, sebebi söylenir: kimliksiz Claude başka kimliğe düşer (ölçülmüş vaka); önce işe alma (madde 6).
- **Ölçüldü (13 Eki):** `ekip-ac.sh` 18 kutunun 3'ünde var (Nexus · huma · mihenk), aile kaydı 8'inde → öteki kutularda yalnız ana
  koltuk açılır, gerisi dürüstçe "kayıtsız" döner. `takili` = Claude var ∧ ekran `TO_TAKILI_SN` (900 s) süredir değişmemiş ∧ soru/girdi
  beklemiyor. 🔴 **Ölçülemeyen koltuk fail-closed:** liste betiği düşer/satır yoksa `olculemedi` — "Claude yok" sanılmaz, zorlasız dokunulmaz (yedek göz tur 3: eski hâl yaşayan oturumu kapatabilirdi). 🔴 **Takılı = görünüş:** uzun araç koşan sağlam bir Claude da öyle görünür (canlıda ölçüldü: BÂNİ'nin kendi koltuğu) → `ac`
  takılı oturumu zorlasız KAPATMAZ (rc 5 / kapı 428); telefon penceresi önce sorar, onayla `--zorla` gider. (2.4.0: `koltuk-bagla.sh --liste` son-etkinlik alanı hep 0 basıyordu — `display-message -t =ad` bölme hedefi boş döner; `ad:` ile düzeltildi, 2.2.1 hâl düzeltmesinin ikizi.)
- Sınav: `scripts/koltuk-ac.test.sh` (gerçek tmux, sahte ekip-ac: öldür→geri gel · eski sohbet · ikinci kopya yok · kayıtsız ret) ·
  `sunucu.test.mjs` KA0-KA10 · `kapi/tarayici-sinav.mjs` KD1-KD5 · mutasyon M20-M22.

## Pano köprüsü — resim yapıştır · seçimi panoya al (2.3.0 · 13 Ekim, Sultan: "Cmd+C kopyalamıyor, resmi Cmd+V yapıştıramıyorum")
Kapı, ttyd'nin HTML sayfasına `kapi/genel/pano.js`'i gömer (`ttydVekil`: yalnız 200 + `text/html` + düz gövde;
JSON · WebSocket · sıkıştırılmış cevap olduğu gibi akar; istemci gzip istediyse eklenmiş gövdeyi kapı sıkıştırır).
- **Yapıştır:** panoda resim varsa `paste` olayı yakalama fazında alınır → 2000px WebP'ye küçültülür (fail-open) →
  `POST <taban>/api/resim` (kutunun 127.0.0.1:8391 dinleyicisine vekil) → dönen yol `window.term.paste()` ile
  terminale yazılır. **Metin yapıştırmaya dokunulmaz** (xterm'in kendi yolu; 2026-08-26 akar regresyonu dersi).
- **Kopyala:** tmux `set-clipboard on` seçimi **OSC 52** ile gönderir; ttyd'nin xterm paketinde bu komutu işleyen
  YOKTU (ölçüldü: pakette `registerOscHandler(52` geçmiyor) → seçim hiçbir yere inmiyordu. Köprü
  `term.parser.registerOscHandler(52, …)` ile metni tarayıcı panosuna yazar; fareyle seçtiğin an "📋 seçim panoya
  kopyalandı". Cmd+C seçimsiz basılınca bir kez ipucu: Shift basılı sürükle → tarayıcı seçimi → Cmd+C.
- **Niçin kapıda, eklentide değil:** ttyd `window.term`'i dışa verir; kapı tabanı bilir; Tampermonkey'siz tarayıcıda,
  kokpit çerçevesinde, merkez yolunda ve doğrudan kutu adresinde aynı sayfa çalışır. Sayfa `<html data-kapi-pano>`
  işareti taşır; tarayıcı eklentisi (`cloudtop-terminal-image.user.js`) bu işareti görünce ttyd sayfasında kendini çeker.
- Kapatma: `KAPI_PANO=0` → vekil eski hâli bayt bayt. Sınav: `sunucu.test.mjs` PN1-PN14 · `pano-sinav.mjs`
  (gerçek Chromium + ttyd + tmux + kapı; kütüphane yoksa rc=4 ÖLÇÜLEMEDİ) · mutasyon M14-M19.
- **Sınır:** tarayıcı panosuna yazmak belge odakta ve izinliyken olur; kokpit başka alandan gömüyorsa çerçeveye
  `allow="clipboard-write"` gerekir (kokpit tarafı, bu beceri değil). OSC 52 "?" sorgusu (panoyu OKUMA) desteklenmez.

## 🔴 Ortak dizinden çağrı = makine kimliği tuzağı (2.1.1 · 12 Ekim canlı dersi)

Beceri `/config/.claude/skills` ortak dizininde yaşar; oradan çağrılınca yol kutuyu söylemez ve ad **kabın rastgele
kimliğine** (12 hex) düşer — 15 kutuda ölçüldü: ttyd yanlış yolda, kapı "bozuk", başsız kurtarıcı doğdu. Artık: (1) böyle bir ad
**fail-closed** reddedilir (`TO_KUTU` ver ya da kutunun yolundan çağır); (2) `kur.sh` kutuya `/config/projects/<kutu>/.claude/skills/terminal-onar → ortak`
bağını kurar — **var olan bağ "var" sayılmaz**: hedefi koşan becerinin gerçek yeriyle karşılaştırılır, yanlış ya da kırıksa
yeniden bağlanır, gerçek eski kopya `.eski-<tarih>` altına alınır (bağımsız göz, tur 1); (3) bekçi/açılış cron satırları
**proje yoluyla** yazılır. Sınav: `kutu-adi.test.sh` K5-K7 (ad çözümü) + `kur-bag.test.sh` B1-B12 — kur.sh kum havuzunda
**çalıştırılarak** ölçülür (sıfırdan · yanlış bağ · kırık bağ · eski kopya · idempotent · cron satırı diskten okunur;
bekçi satırı tek kaynaktan okunur). **Yükseltme göçü (tur 2):** bekçi/açılış satırları `ortak.sh`'ta tek kaynaktır
(`bekci_kur`); işaretleyicili her satır kanonik biçime **yeniden yazılır** — canlıdaki eski ortak-yollu satırlar `.oda/cron`'da
(kur.sh) ve canlı crontab'da (onar.sh) proje yoluna çevrilir, öteki satırlar korunur (B13-B15, crontab sahte dikiş `TO_CRONTAB`).
**Açık beyan muafiyeti (tur 2):** `TO_KUTU` verilmişse makine-kimliği kapısı uygulanmaz — iletinin vaat ettiği çıkış yolu çalışır
(K5c). Mutasyon: tur-1 hâliyle (bağ doğrulamasız, göçsüz) B8/B9/B13/B14 kırmızı.

## Kutudan türeyen adlar (hiçbiri koda gömülü değil)
| Değişken | Varsayılan | Ezmek için |
|---|---|---|
| `KUTU` | çalışma alanından / makine adından | `TO_KUTU` |
| konuşma odası | `<kutu>-ana` | `TO_ANA_TMUX` |
| kapı · terminal | `kapi-<kutu>` · `ttyd-<kutu>` | `TO_KAPI_TMUX` · `TO_TTYD_TMUX` |
| parola anahtarı | `<KUTU>__TERMINAL_SIFRE` | `TO_SIFRE_ANAHTAR` |
| taban yolu | `/<kutu>` | `TO_TABAN` (boş = kök, eski davranış) |

**Niçin tek kaynak:** her adı ayrı ayrı ezilebilir bırakmak da mümkündü; o zaman bir kutuyu
kurmak on değişkeni doğru yazmayı gerektirir ve biri unutulunca kurulum **sessizce başka
kutunun adına** bakardı.

## Taban yolu — merkez sayfanın ön şartı
Merkez (`terminal.mmepanel.com`) kutuları **yol** ile ayırır: `/sedir/` · `/akar/`. Kapı
tabanı bilmek zorundadır; bilmezse döndürdüğü her mutlak yol merkeze gider ve kutuya hiç
ulaşmaz. Taban boş bırakılırsa eski kök davranışı **bayt bayt** aynı kalır.

Kanıt: `kapi/sunucu.test.mjs` (40 kapı, gerçek HTTP + WebSocket) · `kapi/mutasyon.sh` (13/13,
her kapı öldürülünce sınav kırmızıya dönüyor).

## Rapor sayfaları — girişin arkasında küçük statik yüzey
Adres `<taban>/rapor/<ad>/`; dosyalar `KAPI_RAPOR_DIZ` (varsayılan
`/config/.terminal-onar/rapor/<ad>/`) içinden sunulur. **Yeni kapı ya da dış yüzey YOK** —
Access ve kapı parolasının arkasında kalır. Yazılabilen tek dosya `veri.json`: PUT, `x-kapi: 1`
başlığı, geçerli JSON, en çok 1 MB, diske atomik iner. Ad kısıtı `^[a-z0-9-]{1,40}$`.

🔴 **Kaçışın ölçülebilir yarısı — SEMBOLİK BAĞ.** Yol dışına çıkmanın iki yolu var:
*yazım* (`..`) ve *bağ*. Metinsel önek kontrolü yolun yazımına bakar, dosya sisteminin
nereye baktığına değil — ağacın içine konan bir bağ kökün dışını gösterebilir. Bu kapatıldı:
gerçek yol çözülüp (bağlar izlenerek) önek **yeniden** soruluyor. Ve bu yarı HTTP'den
**ölçülebiliyor**: R21-R21d (bağ dosya · gövde sızmaması · bağlı dizin · sağlam dosya hâlâ
sunuluyor). Kontrol öldürülünce kök dışındaki içerik fiilen sızıyor — ölçüldü.

🔴 **Dürüst sınır — M9 (YAZIM kaçışı) ölçülemez.** Yol dışına kaçış kontrolü HTTP üzerinden
**tetiklenemiyor**: adres ayrıştırıcısı `..` ve `%2e%2e` parçalarını kontrole varmadan
sadeleştiriyor, `%2f` ise tek parça ad olarak kalıyor. Mutasyon turu bu korumayı **bilgi**
olarak koşturur ve tura saymaz. Kontrol yine durmalıdır: ayrıştırıcı bir gün değişirse tek
savunma odur. "Ölçemedim" ile "gerek yok" aynı şey değildir.

Kanıt: `kapi/rapor.test.mjs` (**30 kapı**, gerçek süreç + gerçek HTTP) · `kapi/rapor.mutasyon.sh`
(8 koruma öldürüldü, 8'i de sınavı kırmızıya çevirdi) · `kapi/rapor-kapi.test.sh` (koşucunun
gördüğü çağıran — depo kapısı yalnız kabuk sınavlarını keşfediyor).

## Sürüm notları
- **2.2.2 (2026-10-13, MUAVİN · sır-hijyeni):** `sifre_yukle` erişim ortam dosyasını artık **source etmiyor**; yalnız
  `AD=değer` satırlarını okuyor (`ortam_yukle`, çevreleyen tırnak soyulur, `export` öneki kabul). Niçin: 13 Ekim onarım
  turunda üç kutuda (code 135 · tellal 7 · mmex 1) dosyada ad=değer olmayan satırlar vardı; `. dosya` onları KOMUT gibi
  koşturdu ve "command not found" ile değer parçaları stderr'e düştü. Bozuk satırlar sayılır (`ORTAM_BOZUK_SATIR`), içeriği
  basılmaz. Sınav `sifre-yukle.test.sh` (6 kapı, hermetik); mutasyon: eski source yolu geri gelince E3/E4 kırmızı.
