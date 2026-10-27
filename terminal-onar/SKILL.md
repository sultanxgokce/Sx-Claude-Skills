---
name: terminal-onar
description: Bir kutuda Sultan'ın canlı çalışma düzenini (tmux <kutu>-ana'daki Claude konuşması + web terminali + telefon ekranı + kurtarıcı ajan + dakikalık bekçi) KURAR, ÖLÇER ve ONARIR. "/terminal-kur · bu kutuya terminal kur · /terminal-onar · terminal bozuldu · web terminali açılmıyor · oturum kapandı · düzeni yeniden kur" tetiğinde; onarım merdiveni (bekçi / Onar düğmesi) kademe 1-2'de de bu beceriyi çağırır. Bütün kutularda koşar — adlar kutudan türer, hiçbir kutu adı koda gömülü değildir.
version: 2.32.0
---
# /terminal-onar — canlı düzenin onarıcısı

## 🆕 2.32.0 · Boşta kalmış claude oturumlarını bulan araç artık her kutuda — Nexus'a bağlı değil (27 Eki · gorev …T6YWE6 · SERDAR 13:20)
`scripts/bosta-oturum-tarama.py` yalnız Nexus'taydı (#1340); vekatip gibi izole kutular Nexus'u göremediği için aracı çalıştıramadı (vekatip'te 14 oturum/10 claude, 7 günden uzun boşta 2). Araç buraya taşındı ve kutuda çalışacak biçimde uyarlandı. Kuru koşu varsayılandır: `python3 scripts/bosta-oturum-tarama.py` yalnız listeler; `--zil` kapanıştan bir gün önce haber verir; `--kapat` zilden 24 saat sonra, 7 günden uzun boşta ve soru penceresi yokken kapatır.
- **Muaf (Sultan-eşli) liste:** `OT_MUAF` → `~/.filo/sultan-esli-koltuklar.txt` → Nexus kopyası. Liste **bulunamazsa ya da boşsa `--kapat` hiçbir şey kapatmaz** (rc 3, fail-closed). Kutuya listeyi Sultan'ın kararıyla kutu reisi yazar.
- **Zil kanalı:** `OT_NOTIFY` → yanındaki `aile-notify.sh` → Nexus `aile-notify.sh` → PATH'teki `ulak gonder <OTURUM-BÜYÜK>`. Hiçbiri yoksa `--zil` ölçülemedi der (rc 3); başarısız zil deftere yazılmaz, yani kapatmaya ilerlemez.
- **Dürüst sınır:** `ulak` yedeği oturum adını büyük harfe çevirir (ajan adı varsayımı); kutuda oturum adı ajan adından farklıysa zil ulaşmayabilir — o durumda `OT_NOTIFY` ile kutunun kendi komutu verilir. Soru penceresi tespiti `filo.py` yoksa ekrandaki desenle yapılır (daha kaba).
- **Sınav:** `scripts/bosta-oturum-tarama.test.sh` 29 kapı (Nexus'tan gelen 21 + 8 yeni: muaf yok/boş → kapatma yok, varsayılan `~/.filo` listesi, zil kanalı yok → rc 3, `ulak` yedeği); dört mutant (muaf kapısı yok · zil kapısı yok · `ulak` küçük harf · varsayılan muaf yolu yok) sınavı kırdı. Gerçek kutuda kuru koşu çalıştı.

## 🆕 2.31.0 · Arka plan işi süren koltuk artık "boş" görünmüyor — durum çubuğunun yeni yazımı tanınır (27 Eki · AZWHMF)
Claude Code durum çubuğu arka plan kabuklarını artık `· 7 shells ·` diye yazıyor (`running` kelimesi YOK); 2.7.0'dan beri kalıp yalnız `N shells still running` biçimini arıyordu. Sonuç: arka planda sınav koşan koltuk (BERİD, 24 Eki) panelde "koltuğu boş görünüyor" çıkıyordu. `koltuk_hali` kalıbı iki yazımı da tanır (`N shell(s)` + isteğe `still running`, ardından `·` ya da satır sonu); düz metindeki "1 shell command" sayılmaz. Hâl `dis-olay` olur, ne = `7 shells`; panel metni zaten vardı (⏳ dış olay bekliyor), bekçi davranışı aynı. Yeni yazım yalnız solunda `·` olan durum çubuğu biçiminde tanınır (düz metin "... 2 shells" ve "- 2 shells" sayılmaz). Sınav D13h-l (yeni yazım, tekil, üç negatif); önce eski betikle D13h/i kırmızı.

## 🆕 2.30.0 · Yerli otomatik sıkıştırma eşiği başlatıcıdan — 600k her koltukta, bekçi ölçer (26 Eki · gorev_…880TAK · BERİD)
Sultan: *"600k yani yüzde 60'ın üstünde compact otomatik olsun, tüm filoya; yeni açılacak tüm session'larda açık olsun, standardımız bu
olsun, kontrol mekanizmamız olsun."* SERDAR'ın yolu: ortak `settings.json` 13 kutuda ortak → oraya **yazılmaz**; eşik **oturuma ortamla**
verilir. Ölçüldü (claude 2.1.310 ikilisi): `CLAUDE_CODE_AUTO_COMPACT_WINDOW` ayar dosyasındaki `autoCompactWindow`'un üstüne çıkar,
`600k` biçimini kabul eder, model penceresinden büyükse pencereye kırpılır; ortam varken `/autocompact` değiştiremez (standart bilerek kilitli).
- `ortak.sh` `SIKISTIRMA_ENV` (sabit `600k`; dış ortam/bayrak ezemez — göz tur 1: kaçış kapısı standardı deler); `claude_baslat` tmux'a yazdığı satırda bellek öneğinin ardına koyar —
  ana koltuk ve kurtarıcı aynı yardımcıdan geçer, ikinci başlatma yolu yok. Üye koltukları: Nexus `ekip-ac.sh` (aynı değişken), İSKÂN
  `baslat-claude.sh` şablonu (iskan 0.11.4) — her biri kendi deposunda, kopya kural yok.
- `sikistirma_denetle` (ortak.sh): koşan her `claude` sürecinin ortamını okur — tam `600k` yazımı → açık; başka her değer (`600`, `600000`, `900k`) → **eşiksiz (ortam=…)**, ayar iyi olsa da
  (ortam ayarın üstündedir); ortam yoksa hesabın `settings.json`'unda `autoCompactWindow` 100000–600000 → açık, yoksa/`auto` → eşiksiz.
  Koşan claude yoksa **ölçülemedi** (rc 3), yeşil değil. `bekci.sh` her turda koşar, yalnız sonuç değişince günlüğe yazar (`sikistirma.son`) —
  cloudtop'un saatlik `koltuk-autocompact-denetle.py`'si kendi kutusunu görür, kutu başına ölçüm buradadır.
- Sınav `sikistirma-ortami.test.sh` (K1–K3 yazılan satır · M1 mutant: önek kaldırılınca düşer · B1–B4 bekçi hâlleri, sahte /proc).
- Sınır (dürüst): koşan **eski** oturum ortamı sonradan alamaz — eşik yeni açılışta gelir; bekçi eskiyi "eşiksiz" diye gösterir, yeniden açılış kararı insana kalır.

## 🆕 2.27.0 · Kişi terminali yolu `/tty-k` — kapı ttyd-kisi'ye vekiller, abc ttyd'sine düşmez (26 Eki · görev …A5Y3P · A5-3 · BÂNİ)
Kapı `<taban>/tty-k[/…]` isteklerini (sayfa · `token` · `ws`) **kişi ttyd'sine** (`/run/kisi/<kişi>-ttyd.sock`; kişi adı kurulumdan,
`KAPI_KISI` varsayılan `ayse`; `KAPI_TTYD_KISI_SOKET` ile yol) önekini sıyırarak iletir — ttyd-kisi `-b`'siz koşar, yolları kökten alır.
Kapı köprüyle KONUŞMAZ ve kişiyi tanımaz (bir kutu = bir kişi; izin listesi köprüde). Soket yoksa **502** ("kurulu değil") — abc ttyd'sine
hiçbir koşulda düşmez; `/tty/*` vekili değişmedi. Merkez tarafı (cloudtop 1.90.0): kişiye `/tty*` 403, yalnız `/tty-k` açık.
Sınav `sunucu.test.mjs` TK1–TK7 (girişsiz 401 · kökten yol · abc sayacı 0 · soket yükseltme · /tty/ aynen · soket yokken 502 · abc açık kalır).

## 🆕 2.26.0 · Koltuk köprüsü — kısıtlı kişi için "ham tuş yok, iki güvenli düğme" (26 Eki · görev …A5Y3P · A5-1 · Sultan 12:58)
Ayşenur koltukları izleyebilir, ajana mesaj bırakabilir, menü sorusuna şık seçebilir; **kabuk, kasa, ham tuş yok**. Ayrı Linux kullanıcısı
(`ayse`), ham tuş yazma yolu açıkken hiçbir şeyi korumaz (yazılabilir tmux istemcisi = `abc` kabuğu) — bu yüzden `abc` olarak çalışan bir
**köprü** araya girer, kişi yalnız onun UNIX soketini (`/run/kisi/koprusu.sock`, 0660 abc:ayse) görür. Tasarım: Nexus `_agents/hezarfen/a5-ayse-kullanici-tasarim.md`.
- `scripts/koltuk-koprusu.py` — köprü. Dört kapı, hepsi fail-closed ve izli: (1) `SO_PEERCRED` uid izinli mi · (2) koltuk adı süzgeci (`koltuk-adi.sh` eşi) ·
  (3) koltuk izin listesinde mi (merkez-kisiler.json biçimi: `kisiler[].kutular[KUTU]`) · (4) koltuk şu an görünür mü (`koltuk-bagla.sh --liste`; ölçülemezse "ölçülemedi", boş liste sayılmaz).
  Protokol satır-JSON: `liste · izle · boyut · mesaj · sik`. **"Tuş" diye bir eylem YOKTUR**; bilinmeyen her eylem reddedilir. İzleme `tmux attach -r` (salt okur) ile, girdi akışı atılır.
  Mesaj: temizlenir (denetim karakterleri atılır), 2000 karakter tavanı, 2 sn aralık, her eylemde izin yeniden bakılır. Şık: yalnız koltuk `soru: menu` iken ve **sunulan** şıklardan biri. İz günlüğü (`KOPRU_IZ`) mesaj METNİNİ taşımaz. **İzsiz eylem YOK:** mesaj ve şık eylemden ÖNCE niyet izi yazar (fsync), yazılamazsa `iz-yazilamadi` ile reddeder (göz tur 1). **Şıkta yarış KAPALI (atomik):** doğrulama ve gönderim TEK tmux komutunda (`if-shell -F` + `#{C:…}` ekran araması): soru metni VE seçilen şık satırı ekranda hâlâ görünüyorsa tuş gider, değilse `soru-degisti`. Soru/şık metni tmux biçim dizgisini bozabilecek karakter taşıyorsa koşul kurulamaz ve tuş GİTMEZ (`kosul-kurulamadi`, fail-closed). Dürüst sınır: koşul ekranda metin ARAR; aynı iki metni taşıyan başka bir ekran ayırt edilemez.
- `scripts/kisi-istemci.py` — kişinin terminali (ttyd'nin sabit komutu). `m` mesaj yaz · `1-9` şık · `q` çık; başka her tuş atılır. Ekranın alt satırı durum satırıdır.
- `scripts/kisi-mesaj.sh` — köprünün varsayılan mesaj komutu: ULAK'a "insan, Sultan DEĞİL" etiketiyle bırakır (A06: onay alanlarına yazamaz). Alıcı koltuktan türer (`hedefler` dosyası öncelikli).
- `scripts/kisi-kur.sh` — kutuya kurulum paketi (ttyd'nin TAM yolunu çözer: PATH, `/config/.local/bin`, `TTYD_BIN`; bulamazsa ya da `ayse` çalıştıramazsa kurmadan rc 3 ile durur). **KURU KİP varsayılan** (yalnız basar); `--uygula` KÖK ister ve host/Sultan elindedir. `--kok` kum havuzu. Kutu başına çalışır (medigate, açılacak nöbet kutusu; **code kapsam dışı**).
- `scripts/kisi-sok.sh` — kisi-kur'ın GERİ ALMA eşi. **KURU KİP varsayılan**; `--uygula` KÖK ister. Söker: ttyd-kisi + köprü süreçleri, soketler, `/run/kisi`, istemci kopyası, `ayse` kullanıcı/grubu (uid beklenenle aynıysa ve çalışan süreci yoksa). **DOKUNMAZ:** `izin.json` (Sultan'ın koltuk listesi) ve köprü kütüğü. İdempotent. Sınavı: `kisi-sok.test.sh` (S1-S17b).
- 🔴 **Tasarım düzeltmesi:** tasarım belgesi `ttyd-kisi`yi `-W`'siz (salt okur) yazıyordu; ttyd salt okurken tarayıcı tuşlarını istemciye İLETMEZ, `m`/rakam/`q` ölmez. Doğrusu `-W` AÇIK, güvence ttyd'de değil arkasındaki sürecin **kabuksuz** (`kisi-istemci.py`, nologin `ayse`) olmasındadır; ham tuş köprüde zaten yok.
- Sınavlar (gerçek tmux, gerçek soket, gerçek SO_PEERCRED; 🔴 `TMUX` değişkeni temizlenir — içinden koşulan tmux'ta özel sunucu yerine gerçek sunucuya düşmüştü, ölçüldü): `koltuk-koprusu.test.py` · `kisi-istemci.test.py` · `kisi-mesaj.test.sh` · `kisi-kur.test.sh`; mutantlar `koltuk-koprusu.mutasyon.py`.
- **Dürüst sınırlar:** (a) şık tuşu yalnız rakam gönderir (`KOPRU_SIK_TUS`); Claude Code'un menüsünün rakamla mı seçtiği A5-4 canlı kanıtında ölçülür. (b) Köprü ad dışı kimlik (`k…` adresi) çözmez — o A5-3 (kapı). (c) "Mesaj gönderen ajanı yönlendirir": bu Sultan'ın verdiği yetkidir (D1); sınır kabuk/kasa/izinli koltuk/iz.

## 🆕 2.25.0 · Telefon kipi: `tel.` önekiyle bağlanan telefon masaüstünü DARALTMAZ (26 Eki · gorev_…XQY97Y D4 · Sultan 25 Eki)
Sultan: "terminal mobilde de çalışmalı" ve telefondaki terminal masaüstündeki oturumu daraltmamalı. Bugün telefon terminale hiç
bağlanmıyor (merkez soketi kesiyor), çünkü `window-size smallest` altında telefon bir istemci olarak bağlanınca pencere HERKES
için telefon boyuna iner — gerçek tmux 3.4 ile ölçüldü: 200 sütunluk pencere 50 sütunluk telefon gelince 50'ye düştü
(`koltuk-bagla.sh`'nin bugünkü `window-size latest` ayarı da bunu önlemiyor). Artık adres `?arg=tel.` (ana oturum) ya da
`?arg=tel.<koltuk|kimlik>` ise `koltuk-bagla.sh` öneki ayırır, kalan adı bugünkü kapıların HEPSİNDEN geçirir (süzgeç · gizli ·
beyaz liste · kimlik çözümü) ve tmux'a `-f ignore-size` ile bağlanır: istemci pencere boyu hesabına girmez, aynı ölçümde pencere 200
sütunda kaldı. Önek belirsiz olamaz (koltuk adında nokta yasak). Öneksiz adres ve argümansız yol bayt bayt aynı. Telefonun ekranını
masaüstü genişliğinde açıp yana kaydırmak merkezin işi (cloudtop, ayrı kart). Sınav: `koltuk-bagla.test.sh` T1–T10.

## 🆕 2.24.0 · Ekran adresi ad değil AD DIŞI KİMLİK taşır (24 Eki · gorev_…P4GT2W · SERDAR 12:4x)
Mahrem kutuda (vekatip) oturum adı müvekkil adıdır. Merkez Kadro'da adı kısaltıyordu ama "Aç" bağlantısının adresi
(`/<kutu>/tty/?arg=<ad>`) adı TAM taşıyordu: fareyle üstüne gelince, tarayıcı geçmişinde ve kayıtlarda görünüyordu (canlı ölçüm:
8 satırın 6'sı). Artık kapı her oturuma bir `kimlik` verir ve `ekran` adresini onunla kurar (`/api/koltuklar`, `/api/kadro`,
geri-aç yanıtı). `koltuk-bagla.sh` adresteki kimliği görünür koltuklardan çözer ve AYNI kapılardan (süzgeç · gizli · beyaz liste)
geçirip bağlanır.
- **Kimlik** = `k` + sha256(tuz `\n` ad)'ın ilk 16 onaltılığı. **Tuz** kutuya özel ve gizlidir (`$KOLTUK_TUZ`, varsayılan
  `$HOME/.koltuk-tuz`, 32 onaltılık, kip 600); ilk ihtiyaçta ATOMİK yaratılır (`ln`: aynı anda yaratan süreçler tek tuz okur).
  Tuzsuz düz özet olsaydı ad listesi olan biri kimlikleri deneyerek adı bulurdu.
- **Adla bağlanma sürer** (eski bağlantılar, kutunun kendi telefon ekranı). Kimlik biçiminde ADI olan koltuk adıyla açılır (ad önceliklidir).
- **Bilinmeyen kimlik** → red, oturum açılmaz ve red ekranı koltuk ADLARINI BASMAZ (adres mahrem kutudan geldi). Tuz
  kullanılamazsa kimlik uydurulmaz: kapı `kimlik: null` VE `ekran: null` verir (adres adla KURULMAZ — göz tur 1), kabuk reddeder.
- **Var olan tuz** yalnız: bu kullanıcının · 32 onaltılık · kip 600 (gevşekse ve bizimse 600'e çekilir); başkasının, bozuk biçimli
  ya da dizin olan tuz KULLANILMAZ (iki dilde aynı kural).
- Kabuk (`scripts/koltuk-adi.sh` `koltuk_kimlik`) ve kapı (`kapi/koltuk-kimlik.mjs`) aynı formülü taşır; eşdeğerlik
  `scripts/koltuk-kimlik.test.sh` (32 kapı: 8 adlık derlem · tuz kipi · yarış · tuzsuz · var olan tuzun geçerliği). Bağlanma: `koltuk-bagla.test.sh` K0-K8.
- Kapıyı başlatan bütün sınavlar tuzu geçici yolda tutar (gerçek `$HOME`'a yazmaz).
- Dürüst sınır: kutunun KENDİ telefon ekranı (`genel/uygulama.js`) koltuğu hâlâ adla açar; terminalin içindeki tmux durum
  satırı oturum adını gösterir. Bu sürüm yalnız dışarı verilen adresi değiştirir.

## 🆕 2.23.0 · Koltuğun sorusu kapıdan okunur — tür · metin · şıklar · ne zamandan beri (23 Eki · K1 · gorev_…V6FJPZ Engel kurgusu · SERDAR 14:42)
Kapı bir koltuğun "soru" hâlinde olduğunu biliyordu ama **sorunun kendisini** vermiyordu; Sultan hangi soruyu, hangi şıklarla, ne
zamandan beri bekletildiğini görmek için ajanın ekranına gitmek zorundaydı. Artık `koltuk-bagla.sh --liste` 8. sütunda (ve
`/api/kadro` koltuk kaydında `soru` alanı) hâl **soru** iken tek satır JSON taşır: `tur` (**menu**: en az iki numaralı şık —
cevap şıkkın numarasıyla verilir · **serbest**: şık yok), `metin` (son ⏺ satırından sonraki soru bloğu, ≤300 kod noktası; kutu
çizgileri ve "Enter to select · ↑/↓ to navigate · Esc to cancel" altbilgisi girmez), `siklar` (≤6, her biri ≤80), `beri` (bu
sorunun bu koltukta ilk görüldüğü an — `soru-beri.json` durum dosyası; soru hâlinden çıkan koltuğun kaydı silinir). Çözümleyici
`kapi/soru.mjs`; okunamayan soru uydurulmaz (alan yok) — numaralı şık satırı olup geçerli menü (1'den başlayan en az iki
ardışık şık) çıkmayan ekran da okunamadı sayılır, "serbest" diye sunulmaz (göz #440 tur 2). Salt okur: tmux'a tuş gönderilmez.
- **Sır süzgeci** (`kapi/sir-suz.mjs`): ekran metni kutudan çıkmadan PEM · Bearer · `sk-` · GitHub/Slack/AWS jetonu · JWT ·
  URL parolası · `token=`/`parola=` değeri · tek başına uzun dizgi → `••• gizlendi` (anahtar adı görünür kalır).
- **Yazı kutusu varken soru YOK:** eski kural ekranın son 15 satırında "Do you want to" / "❯ 1." aradığı için ajanın KENDİ
  yazdığı açıklama hâli yanlış "soru" yapıyordu (BÂNİ koltuğu 23 Eki 14:5x). Gerçek soru menüsü açıkken Claude Code yazı kutusunu
  (çizgi · `❯` · çizgi) kaldırır; `yazi_kutusu_var` kutuyu görürse soru verilmez. Kutu ekranın son 60 dolu satırında, satır
  sınırı olmadan aranır (hâl desenleri yine son 15 satırda): uzun çok satırlı taslak kutunun üst çizgisini 15 satırın dışına itiyordu (göz #440 tur 1). Fikstür gerçek ekrandan:
  `scripts/fikstur/ekran-yazi-kutulu-20261023.txt`. Bu düzeltme merkezin "soru sordu" yazısını ve zil bekçisini de doğrultur.
- Sınav: `koltuk-bagla.test.sh` Q1–Q9 + Q3b (Q9 = aynı gerçek ekran eski kuralla yanlış "soru" → önce; Q3b = 20 satırlık taslak) + mutant
  M-kutu · M-sinir · M-pencere · M-suzgec · M-okuma · M-tut; `kapi/soru.test.mjs` S/Z/B/A (menü · serbest · bölge · sır · beri · ayrıştırıcı · kadro gövdesi).
- Dürüst sınır: ajanın sohbet mesajıyla sorup boş istemde beklemesi "soru" hâli değildir (bugün de değil); onu bu sürüm görmez.
  Cevabı koltuğa yazma (K2: hedefli `/api/gonder` + teslim doğrulaması) **ayrı iş**, sınıflı (yetki genişletme).

## 🆕 2.22.0 · Ortam dosyası kapı kabuğunda da KAYNAK ALINMAZ (23 Eki · gorev_…GQ9DY · SERDAR 23:2x)
Kapıyı başlatan tmux kabuğu (onar.sh) ortam dosyasını `set -a; . dosya` ile yüklüyordu; ortak.sh 2.2.2'den beri aynı dosyayı
yalnız AD=değer okuyordu ama kapı kabuğu o okuyucuyu görmüyordu. Gerçek dosyada 303 satırın 135'i AD=değer değil, 6'sı PEM
işareti → kabuk onları komut diye koşturdu, sır parçaları kapi-code ve imglistener bölmelerine düştü (SERDAR ölçtü, temizledi).
Okuyucu artık `scripts/ortam-yukle.sh` (yan etkisiz, tek başına kaynak alınır); ortak.sh onu yanından alır (`OKUYUCU`), kapı
kabuğu `. ortam-yukle.sh; ortam_yukle <dosya>` der. Başka depolar aynı dosyayı kendi PR'larında alır (cloudtop `mobile-start.sh`: cloudtop #811, bu sürümün dışı) — kopya yok.
Sınav `sifre-yukle.test.sh` E7-E9: başlatma komutunda `set -a; .` yok · kabuk okuyucuyu kullanıyor · okuyucu boş ortamda tek
başına çalışır (bozuk satır koşmaz, stderr temiz). Mutasyon: `set -a; .` geri gelirse E7, `. dosya` okuyucuya dönerse E3/E4/E9 kırmızı.

## 🆕 2.21.0 · El kabuğu sekmesi — her kutuda sabit, boş, Claude'suz kabuk (22 Eki · gorev_…GT5BTK · SERDAR 12:32 (3))
Sultan'ın elle komut (sabah paketi, kurtarma) çalıştırabileceği **`<kutu>-kabuk`** tmux oturumu:
- `kabuk_kur` (`ortak.sh`) **yalnız yoksa** kurar: proje dizininde, varsayılan kabukla; Claude başlatılmaz. Var olanı öldürmez, içine yazmaz
  (yarım komut kaybolmaz). Çağıranlar: `onar.sh` adım 1b + **`bekci.sh` her tur** (onar yalnız arızada koşar — tmux bekçisi dersi).
- 🔴 Sağlık ölçüsüne (`durum.sh`) **GİRMEZ**: kabuk eksikliği merdiveni tırmandırıp yeni Claude açtırmasın. Kurulamazsa günlüğe yalnız
  **değişince** yazılır (`$DURUM_DIZ/kabuk.son`). `--web-yenile` yalnız `ttyd-*`/`kapi-*` öldürür → kapı yeniden açılınca kabuk kalır.
- Görünürlük: koltuk listesinde **gizli değil**; kapı `/api/koltuklar`'da `kabuk: true` bayrağı (+ üst düzey `kabuk` adı) verir,
  telefon seçicisinde "kabuk — elle komut". Kadroda **altyapı** ("el kabuğu") → kapat/dondur/emekli uygulanamaz.
- `TO_KABUK_YOK=1`: bekçiyi GERÇEK tmux ile koşturan sınavların kalkanı (ölçüldü: `tmux-bekcisi.test.sh` gerçek sunucuda `sinav-kabuk` açıyordu).
- Sınav: `scripts/kabuk-sekmesi.test.sh` (gerçek tmux, kendi soketi; sarmalayıcı `ortak.sh` PATH'inden SONRA yeniden başa — aksi hâlde gerçek
  sunucuya düşüyordu, ölçüldü; sızma kapısı Y2) · `kapi/sunucu.test.mjs` Y6b.

## 🆕 2.20.0 · Kadro Uzmanlıklar + Terimler kaynağı — iki salt-okur uç (22 Eki · Mühürdarlık G12 · SERDAR 05:10 (A))
Merkezin Kadro sayfasındaki "Uzmanlıklar" ve "Terimler" alt sekmeleri (cloudtop) veriyi **sahibinin kutusundan**, bugünkü vekil yolundan okur:
- `GET /api/kadro/tarif` → `tarif-kaydi` `veri/kadro-tarifleri.json` (uzmanlık · vazife · usul; adımda beceri **kurulu mu** ölçülür) +
  `veri/terim-kaydi.json` (terimler). Yol: `TO_TARIF_DIZIN` (vars. `/config/.claude/skills/tarif-kaydi/veri`), beceri dizini iki üstü (`TO_BECERI_DIZIN`).
- `GET /api/kadro/uzmanlik` → Nexus `agent-registry.json` `personas[]` (yalnız ad + `uzmanliklar[]`) + yanındaki `diploma-defteri.jsonl`.
  Yol: `TO_AJAN_KAYDI` (vars. `/config/projects/Nexus/_agents/orchestration/agent-registry.json`), `TO_DIPLOMA_DEFTERI`.
- 🔴 **Yalnız GET** (başka yöntem 405), girişli (öteki `/api/` uçları gibi). Çıktı **beyaz liste** (`kapi/tarif.mjs`): depo yolları (`kaynak`),
  `kapi_yolu`, persona `location/contact/runtime`, diploma `kanit/kume_sha` yanıta girmez. **Okunamayan kaynak `olc` + `null` döner, boş liste DEĞİL**;
  boş diploma defteri ölçülmüş sıfırdır (`[]`). Kaynağı olmayan kutuda uç çalışır ve "kaynak yok" der.
- Kanıt: `kapi/tarif.test.mjs` 19 kapı (gerçek tarif-kaydi kaydıyla G1-G2 dahil) · `sunucu.test.mjs` KT0-KT3 · `kapi/tarif.mutasyon.sh` 10/10.

## 🆕 2.19.1 · tmux bekçisi her bekçi turunda kurulur (20 Eki · SERDAR 19:3x)
2.19.0 bekçiyi yalnız onar.sh K0'da kuruyordu; onar ise yalnız düzen bozukken koşar → sağlıklı kutulara hiç inmedi (ölçüm 20 Eki,
`_agents/fabrika/kanit/tmux-bekcisi-yayilim/filo-kurulum.sh` · `olcum-filo-kurulum-v2-once.txt`: abc kullanıcısı olan 18 ekip
kutusundan yalnız code'da kurulu; abc'siz 9 altyapı kabı kapsam dışı, ölçülemeyen 0). Artık `bekci.sh` her dakika
duraklatma denetiminden SONRA `tmux_bekcisi_kur`'u çağırır: güncelse sessiz, kurduğunda/güncellediğinde/kuramadığında günlüğe bir
satır; kuramasa da bekçi işine devam eder. **Sınır:** bekçisi duraklatılmış kutuya (20 Eki: mmex · nazir · nova) ve bekçisi
koşmayan kutuya (cloudtop masaüstü) inmez — duraklat "hiçbir şey yapma" demektir. Sınav: `tmux-bekcisi.test.sh` B1-B5 + 4 bozma.

## 🆕 2.19.0 · tmux bekçisi — kutunun canlı sunucusunu içeriden kapatan çıplak kill-server reddedilir (20 Eki · K43HN · SERDAR 17:2x)
**Ölçülen kök neden (OOM değil):** 16-17 Eki code kutusunda aile oturumları 4 kez birlikte öldü (16 Eki 19:44 · 17 Eki 11:01 · 11:26 ·
12:56). `oom_kill` sayacı ölümlerden önce ve sonra 83 — bellek değil. Ölümlerin her biri `dava-resume-olc.sh` çağrısından 30-60 sn sonra:
betik `TMUX_TMPDIR` ile kendi sunucusunu kurduğunu sanıp çıkışta çıplak `tmux kill-server` koşuyordu; tmux istemcisi `$TMUX` doluyken
TMUX_TMPDIR'ı DEĞİL `$TMUX` soketini kullanır → tmux içindeki bir Claude'dan çağrılınca KUTUNUN sunucusu gitti (DERVİŞ 17 Eki ölçtü,
betiğe `unset TMUX` kondu). O düzeltme tek betikti; dört ölümün dördü de betik PR'a girmeden iş alanında koşturulurken oldu, yani CI
denetimi önleyemezdi. Koruma çalışma anında:
- `scripts/tmux-bekcisi.sh` → onar.sh (K0 adım 0) `/config/.local/bin/tmux` olarak kurar (PATH'te `/usr/bin`'den önce; 2.19.1'den
  beri dakikalık bekçi de her turda kurar). YALNIZ şunu reddeder: `$TMUX` dolu + açık soket yok (`-L`/`-S`, kümelenmiş/bitişik biçimler dahil) + komut konumunda
  `kill-server` (tek anlamlı kısaltmaları ve `;` sonrası komut dahil). Ret: iki satır sebep + rc 1, iz `<durum>/tmux-bekcisi.log`
  (çağıran süreç). Geri kalan her çağrı `exec` ile gerçek tmux'a gider — argüman ve çıkış kodu birebir.
- Kasıtlı kapatma: `TMUX_KILL_SERVER_IZIN=1 tmux kill-server` ya da açık soket. `$TMUX` boşken (cron, `docker exec` söküm — iskan.sh)
  hiçbir şey değişmez.
- Kurulum kuralları (`ortak.sh tmux_bekcisi_kur`): canlı crontab kilidiyle aynı — deneme yolunda (PROJE ≠ `/config/projects/<kutu>`)
  canlı yola YALNIZ `TO_TMUX_BEKCI_BIN` ile yazılır (sınavlar onar.sh koşturur) · bozuk tmux asla yerleşmez (yeni kopya önce `-V` ile
  gerçek tmux'a ulaşmalı, sonra atomik yer değiştirir) · hedefte bekçi olmayan dosya varsa dokunulmaz.
- Sınav: `scripts/tmux-bekcisi.test.sh` (37 kapı + 10 bozma; G kapıları GERÇEK tmux'la vakayı yeniden üretir: yalıtılmış "kutu"
  sunucusu, vakadaki komut RET, kutu ve koltuğu yerinde).

## 🆕 2.18.1 · compact kuyruk turu bağlamı ölçülemeyen koltuğa göndermez (18 Eki · kart compact-bekle-olculemeyen-sx · SERDAR 21:5x)
`compact.sh compact-bekle`, koltuğun bağlamı ölçülemediğinde (yüzde `—`) "bu arada compact edilmiş" düşürmesini atlayıp bayat
kaydı boş koltuğa gönderiyordu. Artık gönderilmez: satır "bağlamı ölçülemedi (<neden>) — GÖNDERİLMEDİ, bekliyor" der, kayıt
kuyrukta kalır, deneme/yaş tavanında "bağlamı hiç ölçülemedi" nedeniyle düşer. Aynı kural Nexus `filo.py`'de #1171 (FNX51) ile
birleşti. Kanıt: `compact.test.sh` B7 · B7b.

## 🆕 2.18.0 · Dava Rafı — kapı tarafı (16-18 Eki · Parça B2, SERDAR 16:26 · merkez rafı cloudtop #659 · kilit #362)
Kayıt KÖKÜNDE `dava_kurali: {tavan: 4, gun: 14}` olan kutuda (bugün vekatip; satırı kutunun reisi yazar) kapı Dava Rafı'nı besler.
Kural satırı yoksa hiçbir yanıt değişmez — davasız kutuda raf çizilmez (`dava.test` DV7 · DV33).
- **Dava = kayıtlı satır**, `rol: dava`, `id` = dosya no (YYYY/N, tırnaksız). Alanlar: `tmux` · `arz_adi` (kısa ad) · `session_id` ·
  `cwd`; kapının yazdıkları `son_calisma` (dondururken epoch) · `dondurma: kural` (bekçi dondurdu) · `bagla_ile: true` (E4 ile geldi).
- **`/api/kadro`**: `davalar: {tavan, gun, acik, dondurulacak:[{id, kalan_gun}]}` (yalnız kural varsa) · `bagla: true` · kişide
  `arz_adi` · `son_calisma` · `dondurma` · `bagla_ile` (yalnız kayıtta varsa).
- **`POST /api/kadro/hal`** (aynı uç, aynı kurallar: çerez şart, jeton 403, altyapı 403, süreç içi kuyruk):
  `geri-ac {yer_ac:true}` — açık dava ≥ tavan ise en uzun süredir dokunulmayan açık dava ÖNCE dondurulur; dondurulamazsa HİÇBİR ŞEY
  açılmaz (502). Yanıt `{tamam, oturum, ekran, donduruldu, mesaj}`. · `bagla {oturum, hedef:'dava', dosya_no, kisa_ad}` → kaydın ilk
  dosyasının `uyeler:` sonuna blok; `{…, hedef:'kisi', id}` → kişinin `session_id`'si (önceki `bagla_once`'a). Claude kimliği ve
  dizini oturumun kimlik izinden; tek Claude olmalı. · `bagla-geri-al {id}` → yalnız `bagla_ile: true` kayıt; dava bloğu silinir,
  kişide eski kimlik geri konur — kayıt bayt bayt eski hâl, oturuma dokunulmaz.
- **Günlük tur**: `bekci.sh` → `scripts/dava-gunluk.sh` kapısı → günde BİR kez `kapi/dava-bekci.mjs` (damga `<durum>/dava-bekci.gun` turdan
  önce yazılır: tur düşse de o gün tekrar yok, ertesi gün yeniden; damga yazılamazsa tur koşmaz — `dava-gunluk.test.sh` G1-G6) → `gun` gündür tmux bölmesi kıpırdamayan açık davayı
  dondurur (`dondurma: kural`), iz `kadro-hal.log`. `--kuru` yalnız söyler. Kapı ile bekçi aynı kaydı yazar → süreçler arası
  kayıt kilidi `kilit.mjs` (flock, #362): kapının hal ucu, bekçi turu ve `kadroYaz` AYNI `<proje>/kadro.kilit` dosyasını kilitler; hal ucu
  ve bekçi bütün işlemi (yer aç: dondur + aç) tek kilit altında yapar, içeride kilitsiz `kadroYazKilitAltinda`. Kilit 30 sn'de
  alınamazsa kapı 503, bekçi rc 3 (o gün tur yok); kayıt dokunulmaz (`dava.test` DV32–DV32d).
- **Açma (B10 ölçümü)**: `koltuk-ac` dava satırını `claude --resume <session_id>` ile açar (kayıttaki `cwd`'de). baslat-claude.sh
  KULLANILMAZ: o `claude --session-id <id>` koşar ve konuşması olan kimlikte Claude "Session ID … is already in use" deyip çıkar
  (16 Eki, 2.1.301 ölçüldü). Konuşması olmayan dava açılmaz.
- Sınav: `kapi/dava.test.mjs` (uçtan uca) · `scripts/dava-gunluk.test.sh` (günlük kapı) · `kapi/dava.mutasyon.sh` (12 bozma, her biri kırmızı olmalı) · `koltuk-ac.test.sh` V1-V5.
- Ölçüm betiği `scripts/dava-resume-olc.sh` kendi tmux soketinde koşar ve `$TMUX`'u siler (DERVİŞ 17 Eki: tmux içinden çağrılınca
  `kill-server` kutunun sunucusunu öldürüyordu).

## 🆕 2.17.3 · bekçi satırı kutuya özgü sabit gecikmeyle (18 Eki · kart terminal-onar-bekci-gecikme · SERDAR 15:28)

17 kutunun dakikalık bekçisi her dakikanın tam başında aynı anda kalkıyordu; host'ta dakika başı çalışma kuyruğu 179-191'e
çıkıyordu (filo yavaşladı). Bekçi satırı artık `* * * * * sleep N && …` biçiminde: `N = cksum(kutu adı) % 50 + 5` (5-54 sn),
her kutuda farklı, her kurulumda aynı. Sayı kurulumda hesaplanıp satıra düz rakam olarak yazılır — crontab'da `%` satır sonu
demektir. `;` değil `&&`: canlılık envanteri satırı ilk `;`den keser. Eski gecikmesiz satır bir sonraki onarımda/kurulumda
kendiliğinden yenisine çevrilir (düzeltici aynı işareti tanır). code kutusunda N=10 (cloudtop `crontab-abc` ile aynı).
Sınav: `scripts/bekci-gecikme.test.sh` (15 kapı + 3 mutant). Kutulara iniş: her kutuda kur/onar yeniden (ayrı adım).

## 🆕 2.17.2 · kutu adı reddinde betikler DURUR — tek satır, rc 3 (18 Eki · gorev_01M4ZHH1XXGXM5QHV2YTNFSZ30 · gün planı C)

`ortak.sh` makine kimliğine benzeyen (ya da çözülemeyen) kutu adını doğru reddediyordu, ama onu yükleyen sekiz betik
dönüşe bakmıyordu: akış sürüyor, reddin ardından tanımlanan değişkenlerde çöküyordu — `compact.sh` "DURUM_DIZ: unbound
variable" (15 Eki code kutusu), `bekci`/`kademe` aynı, `durum` ANA_TMUX, `kapi-yenile` KAPI_DIZ, `koltuk-ac` PROJE, `onar`
"gunluk: command not found". Sebep satırı izin altında kayboluyordu. Artık `compact · komut · bekci · durum · kademe ·
kapi-yenile · koltuk-ac · onar` reddi görünce **durur**: tek satır (ortak.sh'ın kendi iletisi: "TO_KUTU ver …"), rc 3, yan
etki yok — `kur.sh`'ın S-11 yoluyla aynı sözleşme. Sınav: `scripts/kutu-red.test.sh` (13 kapı: sekiz betik · yan etki ·
kapsam taraması ve kendi pozitif kontrolü · geçerli adla iki pozitif kontrol; mutantlı).

## 🆕 2.17.1 · bekçi işareti yalnız cron satırının sonunda (17 Eki · kart terminal-onar-bekci-yorum-korur · SERDAR 21:00)

`bekci_kur` canlı crontab'ı düzeltirken metninde `# terminal-onar-bekci` geçen **yorum** satırını bekçi satırı sanıyordu:
kanon `crontab-abc`'nin açıklama yorumu bekçi satırına çevrildi, asıl satır "çift kopya" sayılıp silindi (canlı code kutusu,
17 Eki 20:26). `bekci_kurulu` da asıl satır yokken yorum yüzünden "kurulu" diyebilirdi. Artık `#` ile başlayan satır yorumdur
ve olduğu gibi korunur; işaret yalnız yorum olmayan satırın **sonunda** sayılır (`BEKCI_DESEN` · `ACILIS_DESEN` — düzeltici,
`bekci_kurulu` ve üç varlık denetimi aynı iki desenden okur). Sınav: `scripts/bekci-yorum.test.sh` (16 kapı + 2 mutant;
kanonun gerçek yorum satırlarıyla). Eski davranışlar korunur: çift kopya tekilleşir, eski yollu satır kanoniğe çevrilir.

## 🆕 2.17.0 · kadro kayıt kökü + kapat koruması (17 Eki · gorev_01M554PCYA0HWM6TM4KXY4E72V · SERDAR ACİL)
**Ölçülen hata:** merkez kutusunda (code) Kadro "0 kişi · 8 kayıtsız" gösteriyordu. Kapı kaydı `$PROJE` altında arıyor; code'da
`$PROJE=/config/projects/code` bir iskelet, ekibin kaydı Nexus deposunda → 0 üye; sekiz canlı ajan "kayıtsız oturum" sayıldı ve
satırlarında **tek eylem "Oturumu kapat"** idi.
- **Kutuya özel kayıt ayarı:** `<proje>/.oda/ortam` — kutu adı koda gömülmez, kutu kendi yerinde yazar. SOURCE EDİLMEZ; yalnız izin
  listesi (`AILE_REGISTRY` · `ISKAN_REGISTRY`), yalnız mutlak ve var olan dosya; açık ortam her zaman kazanır; reddedilen satır
  sayılır, içerik basılmaz. Merkez kutusu için:
  ```
  AILE_REGISTRY=/config/projects/Nexus/_agents/handoff/aile-registry.yaml
  ```
- **Kapıya tek yerden:** `ortak.sh` `kapi_kayit_ortami` (TO_PROJE + kayıt yolları, kabuk-kaçışlı) → `onar.sh` kapıyı bununla başlatır;
  kapının çağırdığı koltuk açıcı da aynı kaydı görür.
- **Kapat koruması:** kadro verisinde her kayıtsız oturum `kapatilabilir` taşır (yalnız Claude'suz = sorunlu oturum `true`); kapı,
  içinde Claude çalışan oturuma "kapat" isteğini **409** ile reddeder ve tmux'a dokunmaz — kayıt okunamasa da canlı ajan öldürülmez.
  Merkez sayfası düğmeyi `kapatilabilir:false` satırda gizler (cloudtop, ayrı kart); eski merkezde düğme görünse bile uç reddeder.
- Kanıt: `scripts/oda-ortam.test.sh` (15: izin listesi · ret sayımı · açık ortam · boşluklu yol · **gerçek kapı iskelet kökte önce
  0 çalışan/2 kayıtsız → ayarla 2 çalışan/0 kayıtsız** + 3 mutant) · `kapi/kadro-hal.test.mjs` KH10b/KH12b-d (canlı kayıtsız 409).
- ⚠️ Kurulunca kapı **yeniden başlatılmalı** (bekçi sağlıklı kapıyı yeniden başlatmaz) ve merkez kutusuna `.oda/ortam` yazılmalı.

## 🆕 2.16.0 · çıpa dilbilgisi 1.5.0 (17 Eki · gorev_01M54SCQE08KTG9YERG2BBR604 ek · MUAVİN yaması)
`bugun.mjs` Sx `gunluk-plan/sema/bugun-maddesi.md` ile aynı okur: madde başına **`sahip`** (`(sahip: AD)` metinden ayrılır),
**`kanit`** (`kanıt: <ref>` parçaları nottan ayrılır, birden çoksa ` · ` ile birleşir), **`ertelendi`** durumu (`[-]` + `ERTELENDİ` +
geçerli D1 damgası; D1'siz erteleme **açık** sayılır — damgasız erteleme erteleme değildir). `sayilar()` `ertelendi` sayar;
`/api/bugun` toplamlarında görünür. Eski biçim kırılmaz (alanlar boş). Ortak fikstür kapısı (`gunluk-plan/sema/kapi-uyum.mjs`, T17)
Sx #357'de koşar; burada üç kural sınavı D1-D9 + mutant C4-C6. Panel tarafı (cloudtop) `ertelendi`yi ayrıca gösterir (ayrı kart).

## Bugünün listesi ucu (2.15.0 · 17 Eki · gorev_01M54SCQE08KTG9YERG2BBR604)
Kapı `GET /api/bugun[?tarih=YYYY-MM-DD]` — kutudaki ajanların gün çıpalarını (`_agents/handoff/gunluk-plan-cipa.<ajan>.md`,
`gunluk-plan/cipa.sh` + `gun-ortasi/cipa-ekle.sh` yazar) okur ve yapılandırır: madde (`N)` sabah · `G<n>)` gün ortası · etiketsiz
serbest), durum (`[ ]` açık · `[~]` yarım · `[x]` bitti · `[-]` geri), `→ KAPANDI/YARIM · not` kuyruğu ayrı, metindeki `gorev_…`
kimlikleri havuz bağı. Yeni defter YOK, yazma yolu YOK. Bugüne ait olmayan çıpa listeye girmez (`bugun_degil`), `.yedek.md` ve eski
tek dosya taranmaz, okunamayan dosya `okunamadi`. Merkez (cloudtop terminal-merkez) bunu şeritte "Bugün" yan paneli olarak çizer.
Modül `kapi/bugun.mjs` (salt okur), sınav `bugun.test.mjs` (23 kapı, mutant ×3) + `sunucu.test.mjs` BG1-BG5.

## 🆕 Koltuk → hesap (2.14.0 · 16 Eki · G-BANI-0008 hesap geçişi, senaryo kartı E1 zemini)
`koltuk-bagla.sh --liste` 7. sütun ve `/api/koltuklar` `hesap` alanı: koltuktaki Claude'un **hesap adı** — `kapi` (kapı
şeridi, `ANTHROPIC_BASE_URL` hesabı ezer) · `varsayilan` · `<ad>` (`/config/.claude/hesaplar/<ad>`) · `bilinmiyor:dizin` ·
`bilinmiyor:okunamadi`. Claude'suz koltukta alan yok. Ad, sürecin ortamından (`/proc/<pid>/environ`, yalnız iki değişken) türetilir;
kural Nexus `hesap_kutu.py hesap_adi` ile birebir (sınav H10 iki dili aynı girdilerle karşılaştırır). **Kimlik dosyası hiçbir yolda
açılmaz** (H9 betikte adının bile geçmediğini ölçer). Merkezdeki rozet/çubuk sayıları (cloudtop, dış yüzey) ayrı iş. Sınav: H1–H10.

## 🆕 Pano köprüsü 1.2.0 — Safari'de kopyalama (2.6.3 · 15 Eki, Sultan: "Safari'de metin kopyalanmıyor")
Safari pano yazımını yalnız kullanıcı hareketi İÇİNDE geçirir; tmux seçimi OSC 52 ile geç geldiğinden `writeText`
"request is not allowed by the user agent" ile düşüyordu (Chrome geçiriyordu). Üç ayak: **(1)** sürükleme/çift tık biterken
(`mouseup`) `clipboard.write(ClipboardItem{text/plain: Promise})` eşzamanlı çağrılır, OSC 52 gelince söz çözülür (1,5 sn'de
gelmezse reddedilir, pano değişmez; Chromium'da da aynı yol); **(2)** yazım reddedilirse sağ altta tıklanabilir **Kopyala** düğmesi
(tıklama = hareket, `writeText` o anda geçer); **(3)** Shift+sürükle seçimini `copy` olayında köprü kendisi yazar — odak terminalden
kaçsa da. Sınav `kapi/pano-sinav.mjs` S1–S6 (gerçek ttyd+tmux, Chromium; Safari taklidi: `writeText`/`write` reddi). Kabul: Sultan'ın
Safari'de 10 sn denemesi. ⚠ WebKit bu kutuda açılmıyor (kütüphane eksik); Safari'nin kendisi ölçülmedi.

## Düzen (neyi koruyoruz)
| Parça | Ne | Sağlam sayılma ölçüsü |
|---|---|---|
| konuşma odası | tmux `<kutu>-ana` | oturum var |
| konuşma | `<kutu>-ana` içinde Claude (Sultan'ın ana konuşması) | Claude'un oturum kaydında `tmux=<kutu>-ana:` + süreç canlı |
| web kapısı | `kapi/sunucu.mjs` `:7681` → merkez (`terminal.mmepanel.com/<kutu>/`) — telefon ekranı (PWA), giriş (parola, imzalı çerez), mesaj/foto/tuş/Onar API'si. tmux `kapi-<kutu>` | `<taban>/giris` 200 · `<taban>/` girişsiz 302 |
| terminal | ttyd yalnız UNIX soketinde (`/config/.terminal-onar/ttyd.sock`, TCP portu yok), kapı `<taban>/tty/` altında sunar. tmux `ttyd-<kutu>` | soket `/tty/` 200 |
| kurtarıcı ajan | tmux `<kutu>-kurtarici` içinde ayrı Claude. **Filo genelinde KAPALI** (Sultan 16 Eki 2026; yalnız code kutusununki açık): işaret `/config/.terminal-onar/kurtarici-kapali` (ya da `TO_KURTARICI=0`) varken onar.sh açmaz, açıksa kapatır | işaret varken "kapalı (Sultan 16 Eki)" sağlam sayılır; yoksa aynı ölçü |
| bekçi | crontab `* * * * * if [ -x <proje>/…/bekci.sh ]; then bash <proje>/…/bekci.sh; else TO_KUTU=<kutu> bash /config/.claude/skills/terminal-onar/scripts/bekci.sh; fi  # terminal-onar-bekci` (+ kalıcı kopya `.oda/cron`) | koşu izi ≤5 dk |

code-server terminali ve web terminali **aynı tmux oturumuna** bağlanır → birebir, canlı senkron.
Web terminali `tmux new-session -A` ile açılır: oturum yoksa kendisi kurar, boş ekrana bakmaz.

## Komutlar (hepsi `scripts/komut.sh` üzerinden)
```
bash .claude/skills/terminal-onar/scripts/komut.sh durum [--json]
bash .claude/skills/terminal-onar/scripts/komut.sh onar [--web-yenile]     # kademe 0 = sıfırdan inşa
bash .claude/skills/terminal-onar/scripts/komut.sh merdiven [--arka]       # K0 → K1 → K2 → K3
bash .claude/skills/terminal-onar/scripts/komut.sh duraklat "<sebep>" | devam
bash .claude/skills/terminal-onar/scripts/komut.sh gunluk [N]
bash .claude/skills/terminal-onar/scripts/komut.sh compact [--esik 60] [--koltuk ad] [--uygula] [--json]   # kutu-içi zorunlu compact
bash .claude/skills/terminal-onar/scripts/komut.sh compact-bekle [--uygula]                                # kuyruk turu (bekçi çağırır)
bash .claude/skills/terminal-onar/scripts/komut.sh kapi-yenile [--kuru]   # kapının pano.js'ini BAĞLANTI DÜŞÜRMEDEN tazele (SIGHUP); eski kapı/yoksa onar --web-yenile'ye düşer ve söyler
```
Argüman `onar` ile çağrıldıysan: önce `durum`, sonra `onar`, sonra yine `durum`. Sağlam değilse
günlüğe bak, sebebi bul, `onar --web-yenile` dahil tekrar dene. Sağlam olmadan "bitti" deme.

## Onarım merdiveni (yarıda kalmaz)
1. **K0** `onar.sh` — betik; eksik parçayı kurar, sağlam parçaya dokunmaz. Konuşmayı hep **aynı
   kimlikle** geri açar (`/config/.terminal-onar/ana-oturum`), asla "son oturum"la (aynı klasörde
   başka ajanlar da çalışır; `--continue` yanlış konuşmayı açabilir).
2. **K1** başsız Claude (`claude -p`, 10 dk) — yalnız bu betiklere + okumaya izinli.
3. **K2** kurtarıcı ajan — `/terminal-onar onar` komutu gönderilir, 20 dk izlenir. Kurtarıcı işareti kapalıysa
   bu kademe ATLANIR (günlüğe "kurtarıcı kapalı → MUAVİN/SERDAR'a bildir" düşer).
4. **K3** Sultan'a WhatsApp: "elle bakılmalı" + durum + son günlük; kurtarıcı kapalıysa ileti "kurtarıcı kapalı →
   MUAVİN/SERDAR'a bildir" cümlesini taşır (insan kademesi kutu dışından gelir).

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
`/config/.terminal-onar/` — `gunluk.log` · `ana-oturum` · `kurtarici-oturum` · `kademe.durum` · `duraklat` ·
`kurtarici-kapali` (2.11.0 · işaret: var = kurtarıcı açılmaz/kapatılır; **kutu başına**, reis koyar; code kutusuna KONMAZ;
geri açmak = silmek). Sınav: `scripts/kurtarici-kapali.test.sh` (hermetik + mutasyon). ·
`kapi.pid` + `kapi.pano-sha` (2.12.0 · kapı yazar: SIGHUP'ı tanıyan sürümün imzası ve yüklü pano.js sha'sı; `kapi-yenile` bunlara bakar).
Sultan-onayı: 2026-09-25 (gözetimsiz ajan kademeleri dahil) · 2026-10-16 (filo geneli kurtarıcı kapalı, code hariç).

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

## Koltuk adı süzgeci: tmux'un kuralı + bizim tek tercihimiz (2.4.3 · dilim 5/7, SERDAR 13 Eki ölçtü)
Kapı `/api/koltuklar` adı `^[A-Za-z0-9_-]$` ile süzüyordu → adında `/` olan oturum (vekatip `2026/85`) listeden **düşüyordu**
(17 oturumun 1'i); `koltuk-bagla.sh`'de aynı desen yalnız ATTACH yolundaydı (liste süzmüyordu, bağlanma reddediyordu). Süzgeç indirildi: `:` · `.` (tmux ikisini zaten `_` yapar — ölçüldü) ve kontrol karakterleri (sekme/satır sonu; liste sekmeyle ayrılır) dışında her ad geçerli. **Boşluk arada serbest** (tmux 3.4 `a b` oturumunu açar — ölçüldü; bağımsız göz tur 1: "tmux'un izin verdiği" sözü tutulur), başta/sonda değil (kesilip başka ada dönüşür). Tekil uçta (`/api/koltuk/<kodlu-ad>`) uzunluk sınırı **çözümden sonra** uygulanır: 200 karakterlik `/`'lı ad kodlu hâlde 200'ü aşar. Liste artık `-t ad` kullanmaz: `$1` gibi bir ad `-t '$1:'` ile de `-t '=$1:'` ile de oturum KİMLİĞİ sanılıyor (ölçüldü) → bölmeler bir kez listelenir, ada tam eşleşen oturumun etkin bölme kimliğiyle (`%N`) ölçülür; son etkinlik `list-sessions` eşlemesinden. Bağlanma `attach -t =ad` kaldı. **İlk karakter `$` `@` `%` `=` OLAMAZ**: tmux hedefinde bunlar oturum/pencere/bölme kimliği ve tam-eşleşme önekidir (`$1` adlı koltuk `-t` ile başka oturuma çözülüyordu — ölçüldü). Kural TEK yerde yazılı: kabukta `scripts/koltuk-adi.sh` (koltuk-bagla ve koltuk-ac yükler), kapıda `KOLTUK_AD_DESEN`. Ad HTML'de kaçışlı, adreste `encodeURIComponent` (`?arg=2026%2F85`; ttyd kabuğa **çözülmüş** iletir —
gerçek ttyd+Chromium ile ölçüldü), `/api/koltuk/<kodlu-ad>` yolda çözülür, attach `=ad` tam eşleşme. Güvenlik desenden değil
tmux'un beyaz listesinden (var olan oturum) gelir. Sınav: koltuk-bagla E1-E3 · sunucu SL1-SL4 · **`scripts/koltuk-adi.test.sh`** (23 adlık derlem: kabuk ⟷ kapı aynı hüküm + GERÇEK tmux'ta kabul edilen her ad `=ad` ile kendine çözülür) · **`kapi/koltuk-xss.tarayici.sh`** (gerçek kapı + Chromium: `<img/src=x/onerror=alert(7)>` ve `x"y` adları seçicide metin, alert yok, option değeri = ad). Merkez sayfanın `guv()` süzgeci
(cloudtop) ayrı PR.

## Koltuk aç / yeniden aç / eski sohbete dön — tek tuş (2.4.0 · 13 Ekim, Sultan: "oturum kapandı/bozuldu/silindi — tekrar açmak çok basit, çok sağlam olmalı")
Telefon ekranında **Koltuk** düğmesi → pencere: seçili koltuğun durumu ÜÇ AYRI hâlde (`yok` · `claude-yok` · `takili` · `canli`)
ve tek eylem (Aç / Yeniden aç / Eski sohbete dön). Ölçüm ve iş `scripts/koltuk-ac.sh`'de (`durum <ad>` JSON · `ac <ad> [--eski]`);
kapı yalnız taşır: `GET /api/koltuk/<ad>` · `POST /api/koltuk/<ad>/ac {eski}` (rc 0→200 · 3→202 merdiven · 4→409 kayıtsız · 1→502).
- **Yol (kim açar) — açıcı ve kayıt BİRLİKTE seçilir (2.4.2):** kayıt, koltuğu fiilen açacak betiğin okuduğu dosyadır (tek kaynak).
  **İSKÂN kutusu** (`scripts/baslat-claude.sh` + `iskan-registry.yaml`) → koltuk kayıtlı bir rolün tmux'uysa yeni tmux oturumunda
  `baslat-claude.sh <rol>`, kayıttaki `cwd`'de: ayrılmış kimlik, konuşma varsa ona döner (bu yolda ayrı "Eski sohbete dön" düğmesi
  yok — Aç zaten oraya döner); `TO_BASLAT_BEKLE` (3 sn) sonra oturum yaşamıyorsa "açıldı" DENMEZ (rc 1).
  **Merkez** (`scripts/ekip-ac.sh` DOĞURAN sürüm + `aile-registry.yaml`) → `ekip-ac.sh <ROL>`. Doğuran sürüm YAPISINDAN tanınır:
  argüman çözücüsünde `--resume-if-known)` VE `--dry-run)` kolları satır başında (yorumdaki geçiş sayılmaz; grid sürümü bayrakla
  yoklanmaz, yan etkisi var). Betik rc 0 dese de koltuk oturumu yoksa "açıldı" denmez
  (**tek kanonik kapı:** canlıysa ikinci kopya AÇMAZ; `--eski` → `--resume-if-known`, eski sohbete dönüş; Claude'suz/takılı oturum
  önce kapatılır, sonra doğar). 🔴 İSKÂN kutularındaki **aynı adlı `ekip-ac.sh` başka betiktir** (var olanı tek pencerede toplar,
  oturum doğurmaz, rol almaz) → açıcı SAYILMAZ; sayılsaydı Aç Claude'suz oturumu kapatıp geri getirmezdi. Koltuk **ana** ise →
  `onar.sh` (K0), düşerse merdiven (`kademe.sh`). Hiçbiri değilse → **kayıtsız koltuk AÇILMAZ**, sebebi söylenir: kimliksiz Claude
  başka kimliğe düşer (ölçülmüş vaka); önce işe alma (madde 6).
- **Ölçüldü (13 Eki, 2.4.2 ile düzeltildi):** 2.4.0 notu "`ekip-ac.sh` 3 kutuda" diyordu, yanlıştı. Kutuların kendi proje
  dizininde: **11 kutu İSKÂN** (`baslat-claude.sh` + `iskan-registry.yaml`: akar · enis · huzur · maiset · menzil · nazir · nova ·
  s02 · sedir · tellal · tez; mmex'te host dizininde dosyalar var ama kutunun içinde `MMEx` başka bir bağlamayla örtülü — kutu
  içinden açıcı yok, `yol=yok` doğru), **doğuran `ekip-ac.sh` yalnız merkezde**. 2.4.0 bu 11 kutuda yalnız ana koltuğu açabiliyordu
  (canlı: enis ENIS/MURSIT `rol=""` `yol=yok`). `takili` = Claude var ∧ ekran `TO_TAKILI_SN` (900 s) süredir değişmemiş ∧ soru/girdi
  beklemiyor. 🔴 **Ölçülemeyen koltuk fail-closed:** liste betiği düşer/satır yoksa `olculemedi` — "Claude yok" sanılmaz, zorlasız dokunulmaz (yedek göz tur 3: eski hâl yaşayan oturumu kapatabilirdi). 🔴 **Ana koltuk da aynı kapıdan geçer:** takılı/ölçülemeyen ana koltukta zorlasız rc 5, `--zorla` oturumu kapatır ve onar.sh K0 kayıtlı konuşmaya döner (yedek göz tur 4: eski hâl onar.sh'yi doğrudan çağırıyor, o da "Claude zaten çalışıyor" deyip rc 0 dönüyordu → telefon yanlış "Açıldı" yazıyordu). 🔴 **Takılı = görünüş:** uzun araç koşan sağlam bir Claude da öyle görünür (canlıda ölçüldü: BÂNİ'nin kendi koltuğu) → `ac`
  takılı oturumu zorlasız KAPATMAZ (rc 5 / kapı 428); telefon penceresi önce sorar, onayla `--zorla` gider. (2.4.0: `koltuk-bagla.sh --liste` son-etkinlik alanı hep 0 basıyordu — `display-message -t =ad` bölme hedefi boş döner; `ad:` ile düzeltildi, 2.2.1 hâl düzeltmesinin ikizi.)
- Sınav: `scripts/koltuk-ac.test.sh` (gerçek tmux, sahte ekip-ac: öldür→geri gel · eski sohbet · ikinci kopya yok · kayıtsız ret) ·
  `sunucu.test.mjs` KA0-KA10 · `kapi/tarayici-sinav.mjs` KD1-KD8 + KI1-KI3 · mutasyon M20-M22. 2.4.2: koltuk-ac.test.sh I1-I7 (İSKÂN:
  baslat yolu, üç kaydın birlikte durduğu kutuda iskan kaydı seçilir, düşen baslat "açıldı" dedirtmez) + G1-G2 (grid ekip-ac açıcı değil) + Y1-Y5 (yorumdaki bayrak açıcı yapmaz, tek kol yetmez, oturumsuz rc 0 "açıldı"
  dedirtmez); mutasyon `_agents/fabrika/kanit/koltuk-kayit-okuyucu/mutasyon.sh` KO1-KO11.

## Pano köprüsü — resim yapıştır · seçimi panoya al (2.3.1 · 13 Ekim — ana dalda 2.3.0 REVAK gerilemelerine (#303) gitti, pano köprüsü #304 ile 2.4.0 içinde iner; Sultan: "Cmd+C kopyalamıyor, resmi Cmd+V yapıştıramıyorum")
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

### Yayın kipi — `.defter-yayin` işaretli klasör salt-okur ve kum havuzunda (2.3.0)

REVAK-KURTARICI'nın 12 Ekim tasarımı (ortak koda 13 Ekim'de taşındı — kutuya bağlanırken ezilmişti, bkz. sürüm notu).
Rapor klasöründe **`.defter-yayin`** işareti varsa (defter-sayfasi'nın yayımladığı sayfa) o klasör **yayın kipindedir**:
- her cevap **CSP kum havuzunda** (`sandbox` · opak köken) ve **ağsız** (`connect-src 'none'` · `form-action 'none'`):
  sayfa çizer ama kapıya hiçbir istek atamaz. 🔴 Niçin: rapor kapıyla **aynı kökenden** sunulur; içindeki bir betik
  `/api/gonder`'e ulaşsa tmux'a tuş yazabilirdi.
- yazma yöntemleri **405** (`veri.json` dahil), `HEAD` 200; kokpit çerçevesi (`frame-ancestors`) korunur.
- **işaretsiz klasör bayt bayt eski davranışta** — SEDİR'in `ev/ridvan` sayfaları `veri.json`'u tarayıcıdan PUT'lar;
  kum havuzu onun yazma kolunu keserdi (ölçüldü: ridvan/index.html'de x-kapi PUT var). Bu yüzden kip klasör-başına.
- gizli adlar (`.defter-yayin`, `.gecici`…) **iki kipte de** sunulmaz.

**Rapor dizini kutudan türer (2.3.0):** `TO_RAPOR_DIZ` > kutunun `<proje>/veri/rapor` dizini (varsa) > ortak varsayılan;
`onar.sh` bunu kapıya `KAPI_RAPOR_DIZ` olarak **verir**. 🔴 Gerileme dersi: REVAK sayfaları `projects/revak/veri/rapor`'daydı,
ortak `onar.sh` değişkeni kapıya vermiyordu → kapı ortak varsayılana baktı → canlı sayfa 404 (12-13 Eki).

REVAK'ın kendi sınavlarıyla eşleme (adlar ortak depoda çakışmasın diye değişti; davranış aynı): R1→Y1 · R2→Y2 · R3→Y3 ·
R4→Y4 · R5→Y5 · R6→Y6 · R7→Y7 · R8→Y8 · R9→Y9 · R10→Y10+Y10b · R11→Y15 · (ek: Y12-Y14 SEDİR zırhı, Y13b kök gizli ad);
mutasyon M14(bağ sınırı)→M10/M11 · M15(gizli ad)→M15 · M16(kum havuzu)→M13 · M17(girişin arkasında)→M1 · M18(yazma reddi)→M14.

Kanıt: `kapi/rapor.test.mjs` (**51 kapı**: R serisi + yayın kipi **Y1-Y15**, Y12-Y14 SEDİR gerileme zırhı) ·
`kapi/rapor.mutasyon.sh` (**16 koruma** öldürüldü, 16'sı da sınavı kırmızıya çevirdi — M13-M17 yayın kipi; M16 "işaret
okunmuyor" ve M17 "her klasör yayın" iki yönlü) · `kapi/rapor-kapi.test.sh` (koşucunun gördüğü çağıran — depo kapısı
yalnız kabuk sınavlarını keşfediyor).

## Bekçi koşu izi — "kurulu" ≠ "koşuyor" (2.3.0)

`bekci.sh` her koşuda `<durum>/bekci.son`'a damga bırakır (duraklatmadan ÖNCE: duraklatılmış bekçi de canlıdır).
`durum.sh` bekçiyi **satıra değil ize** göre ölçer: iz ≤5 dk → ok · iz yok → `izsiz(…)` · iz eski → `durgun(N dk koşmadı)`.
Tek istisna: `onar.sh` bekçiyi az önce kurduysa/doğruladıysa (`bekci.kuruldu` damgası ≤2 dk) ilk koşu beklenir — iz
**uydurulmaz**, yalnız pencere açılır; pencere dolunca kırmızı. 🔴 Niçin (REVAK hata defteri, 29 Eyl–10 Eki): cron
süreci **11 gün** yoktu, gösterge crontab satırına bakıp "ok" diyordu. Sınav: `scripts/bekci-iz.test.sh` (12 kapı,
hermetik, sahte crontab/tmux; B11 mutasyon: eski gösterge geri gelince B2 yakalar).

## Boş kabuk koltuk — BOŞ hükmü (2.5.0)

Fark ölçeri (`kapi/koltuk-fark.mjs`, filo: `scripts/koltuk-fark-filo.sh`) artık görünür koltuklarda **BOŞ** hükmü verir: hiçbir
bölmesinde Claude yok **ve** her bölmede yalnız kabuk istemi var, altında hiçbir süreç yok (`koltuk-bagla.sh --bos`, tek kaynak).
Tıklayan boş kabuğa düşer; kirli sayılır (rc 1). Bölme listesi ya da süreç tablosu alınamazsa `--bos` rc 3 → ölçer ÖLÇÜLEMEDİ der (boş liste "temiz" sayılmaz). 🔴 Niçin (SERDAR 14 Eki): 15 koltuk "görünür = temiz" sayılıyordu, DÜŞEN 0.
- **Claude araması alt ağacın tamamında** (derinlik sınırı yok; süreç tablosu alınamazsa ÖLÇÜLEMEDİ): kutuların çoğu ajanı başlatma betiğiyle açar (bölme → `baslat-claude.sh` →
  `claude`); eski arama yalnız çocuk sürece bakıyordu, torun Claude "yok" sayılıyordu (tellal/HAYALI, nova-kesif, huzur-yon).
- **`claude.exe` de Claude'dur** (yerel kurucunun ikilisi; medigate/SAYMAN yanlış "boş" görünüyordu).
- **Boş ≠ Claude'suz:** sunucu/izleme koşan oturum (nova/kesif-ui web sunucusu) boş DEĞİL; geçici adlar (cc-* · dash* · imglistener*) muaf.
- Canlı ölçüm (14 Eki, 5 kutu): ilk koşu (`--kaynak`) BOŞ = medigate 4 · mihenk 4 · tellal 3 · huzur 1 — ikinci yüzeyle (elle süreç ağacı) birebir. Ardından reisler 12'sini kapattı (tellal MEDDAH; medigate + mihenk reis kararıyla MUAVİN); son koşu yalnız huzur-motor1. 🔴 Önce/sonra çifti aynı filo durumunu ölçmez (arada oturum kapandı); kodun etkisi sınavda (F10-F21) ölçülür, canlı çift yalnız gerçek kutuda çalıştığını gösterir.
Sınav: `kapi/koltuk-fark.test.sh` F10-F18 (gerçek süreç ağaçları); mutasyon: alt-ağaç araması · BOŞ hükmü · claude.exe tanıma
ayrı ayrı kaldırılınca sınav kırmızı.

## Bekçi satırı bağsız da yaşar · deneme kopyası canlı crontab'a dokunamaz (2.6.0 · S-9 + S-10)

**Yedek dal (S-9).** Proje-yolu bağı (`<proje>/.claude/skills/terminal-onar`) git'te değil, `kur.sh`'ın kutuya bıraktığı kayıtsız
bir bağdır: depoya yazma yasağı olan kutuda (maiset, 13 Eki) hiç kurulamadı, sıfırdan kurulan her kutuda da kaybolur — satır her
dakika rc 127 ile düşüyor, bekçi "kurulu" görünüyordu. Satır artık önce proje yolunu sınar, yoksa ORTAK yola düşer ve kutuyu **açık
beyanla** söyler (`TO_KUTU=<kutu>`), yani makine-kimliği tuzağına (2.1.1) düşmez. Bağ varsa eski davranış birebir. Açılış satırı
(`@reboot … komut.sh onar`) aynı kalıpta. İşaretleyici değişmedi: `bekci_kurulu` ve cloudtop kanonu (`crontab-abc`) bayt-bayt eşleşir.
Sınav: `kur-bag.test.sh` S9a-c — cron'un koşturacağı komut `sh -c` ile **birebir** koşulur: bağ yokken rc 0 + yedek dal `kutu=sinav`,
bağ varken yalnız proje yolu.

**Canlı crontab kilidi (S-10).** Bir sınav `onar.sh`'ı `TO_PROJE=<geçici>` ile ve `TO_CRONTAB` vermeden koşturdu; `bekci_kur canli`
canlı crontab'daki bekçi satırını `/tmp/tmp.…/proje/…` yoluna çevirdi (code kutusunda iki kez; 14 Eki'de satır çift kopyaydı).
Kural: `PROJE` gerçek kutu yolu (`/config/projects/<kutu>`) değilse canlı crontab'a **yalnız açıkça verilen** `TO_CRONTAB` ile
dokunulur; verilmemişse dokunulmaz ve söylenir ("canlı crontab'a DOKUNULMADI (deneme yolu …)"). Kalıcı kopya (`.oda/cron`) yine
yazılır. İşaretli satır çiftse **tekilleşir**. Sınav: S10a-f (sahte crontab PATH'te hiç çağrılmaz · pozitif kontrol · tekilleşme);
mutasyon: eski `ortak.sh` ile 7 kapı kırmızı.

## Kadro — kayıt ⟂ koltuk tek uçta (2.8.0 · Kadro E1 önkoşul 1+3, gorev_01M4WVHD00GF5MAQD1J7G74RZ4)

Sultan 14 Eki: "kutu içindeki personellerin durumu … düştü ise ayağa kaldırmak". SERDAR'ın 18 kutuluk ölçümü (14 Eki):
39 çalışıyor · 40 kayıtta var oturumu yok · **15 oturum açık içi boş (asıl düşenler)** · 22 kayıtsız. Kapı artık `GET /api/kadro`
ile kutunun personel **kaydını** canlı **koltuklarla** birleştirir (`kapi/kadro.mjs`, yalnız okur):

| Grup | Kural |
|---|---|
| `calisan` | kayıtlı · oturumu var · içinde Claude var (hâl + ne beklediği koltuk listesinden) |
| `dusen` | kayıtlı · oturumu AÇIK · içinde Claude YOK — bekçinin "canlı" saydığı boş kabuk |
| `kayitta-var-calismiyor` | kayıtlı · oturumu yok · kayıt hâli boş/çalışıyor |
| `gecici-emekli` | kaydın `hal:` alanı `gecici` · `yedek` · `emekli` (oturumu olsa da düşen/çalışan sayılmaz) |
| `kayitsiz` | oturum var, kayıtta yok (ana koltuk hariç: o "(kimliği yok)" diye kişilerde durur) |

**Kayıt alanı `hal:`** (önkoşul 1): `calisiyor | gecici | yedek | emekli`; alanı olmayan kişi `bilinmiyor` görünür — hiçbir şey
uydurulmaz; 40 kişiyi "düştü" diye kırmızı basmak yalan alarm olurdu. Kayıt TEK kalır, ikinci liste açılmaz. Kayıt dosyaları
koltuk-ac.sh ile aynı sırada: İSKÂN kutusu `iskan-registry.yaml` (id/tmux) + işaret ettiği `ekip-registry.yaml` (rol/mod/hal — çatışmada
ekip kaydı üstün, tmux İSKÂN'dan);
merkez `_agents/handoff/aile-registry.yaml` (önkoşul 3: merkez kadrosu da aynı uçtan). Proje dizini `TO_PROJE` ya da
`/config/projects/<kutu>` (ortak.sh kuralı). Koltuk listesi ölçülemezse 500 — uydurma kadro yok. Çizim ve eylemler (kaldır ·
bağla · emekli et · personel al) merkez ekranında ve ayrı uçlarda (E1-E4, cloudtop).

## Kutu-içi zorunlu compact (2.9.0 · Sultan 14 Eki · gorev_01M4WYVAWEB3FNM5H0XFDMBAK9 eksik 1)
Sultan: *"bir kutunun reisi o kutudaki tüm ajanları compact yapabilmeli … contexti artmış uzun süredir compact yapmayanları
mutlaka compact yapması gerekiyor."* Merkezdeki `filo.py compact-kurali` (MUAVİN, filo geneli, ssh) bu beceride kutu-içi ikizini bulur:
ssh yok, kayıtlar yerel, tek komut.
- **Ölçü** (`kapi/compact-olc.mjs`, damga icat etmez): bağlam % = son asistan yanıtının kullanımı ÷ pencere; son compact = kayıttaki
  `compact_boundary` (sondan 1 MB bloklarla, tavan 64 MB). Pencere (payda): merkezin `ctx-windows.json` kuralları → ORTAK-MIMARI model
  sözlüğünden gömülü tablo (fable/opus-5 1M · opus-4.8/sonnet 500k · haiku/glm 200k) → eşleşmeyen model 200k **varsayım**, satırda `~%85`.
  (Canlı ders 15 Eki: `[1m]`-siz kayıt 200k sayılınca %226/%398 basıyordu — payda yanlışsa compact kararı da yanlış olur.)
  Koltuk → oturum: `claude_oturumu` (süreç ağacı → sessionId → `<sid>.jsonl`). Kayıt bulunamayan koltuk **ölçülemedi**, tuş gitmez.
- **Karar:** `%` ≥ eşik (60) → "compact gerek". `--uygula`: hâl **boş** → `/compact` (C-u · metin · 0,5 sn · **ayrı** Enter);
  çalışıyor / girdi (taslak var) / dış-olay → **kuyruk** (`compact-bekleyen.jsonl`), tuş gitmez. Bekçi her dakika kuyruk doluysa
  `compact-bekle --uygula` koşar: boşalınca gider; bu arada eşiğin altına inmişse ya da koltuk kapanmışsa düşer; 24 sa / 60 deneme →
  **VAZGEÇİLDİ** (ekrana kırmızı + günlük; sessiz değil). **Tur kilidi** (göz tur 3): tur boyunca `flock`; bekçi ile elle çağrı çakışırsa
  ikinci tur hiçbir koltuğa dokunmadan çıkar ("zaten koşuyor"); kuyruğa ekleme ayrı kısa kilitle, tur ortasında eklenen satır yeniden
  yazımda kaybolmaz (oda-tetik `uyandir` ile aynı desen). Elle `compact --uygula` da **aynı kilidi** alır (göz tur 4): bekçi turu
  koşuyorsa en çok 15 sn bekler, alamazsa ölçümü basar, tuş göndermez (rc 6) — iki yol aynı koltuğa aynı anda gönderemez.
- **Yetki (kapalı-varsayılan):** `--uygula` `AGENT_NAME` ister (kimliksiz ret, rc 5). Reis adı `TO_REIS` ya da `$DURUM_DIZ/reis`
  dosyasından okunur; **bilinmiyorsa kimse uygulayamaz** (rc 5, "kutu reisi BİLİNMİYOR") — reis-dışı ret koşulsuzdur, "dolu kimlik
  yeter" yolu yoktur (göz tur 2). Biliniyorsa yalnız o ad uygular; başkası ölçer. Kuyruk kaydı yazanın adını (`kim`) taşır ve bekçi
  turu onu **her turda aynı kuralla** sınar (reis yok → kayıt düşer; `kim ≠ reis` → düşer), gönderilmeden (göz tur 1). Kurulum: kutu
  reisinin adını `echo <AD> > /config/.terminal-onar/reis` ile yazmak reisin işidir; yazılmadan compact uygulanamaz, yalnız ölçülür.
  MUAVİN'in filo-geneli yetkisi merkezde (`filo.py`), burada değil.
- Sınav: `scripts/compact.test.sh` (35 kapı, hermetik: sahte tmux + sahte kayıt; mutasyon: boş-koltuk kapısı kalkınca taslaklı koltuğa tuş gider → U1 kırmızı).

## Sürüm notları
- **2.32.0 (2026-10-27, MİRAHUR · gorev …T6YWE6):** `bosta-oturum-tarama.py` + sınavı Nexus'tan taşındı; muaf liste/zil kanalı kutuya göre çözülür, muaf listesi yokken `--kapat` rc 3. Ayrıntı yukarıda.
- **2.31.1 (2026-10-27, HEZARFEN · SERDAR 12:40 acil, medigate rc 5):** kişi-kur soket dizini 0750→3770 abc:ayse. `ayse` ttyd soketini 0750 dizinde açamıyordu (bind EACCES, `/tmp/ttyd-kisi.log` sıkı döngüyle saniyede onlarca MB büyüdü); yapışkan bit koprusu.sock'u koruyor, setgid soketi ayse grubuna veriyor. Köprü: abc `ayse` grubuna üye olmadığından `os.chown` EPERM verip köprüyü öldürüyordu → yutulur.
- **2.30.0 (2026-10-26, BERİD · gorev_…880TAK; 2.28.0/2.29.0 BÂNİ kişi-sök/kişi-kur ile aynı gün):** `claude_baslat` satırına `CLAUDE_CODE_AUTO_COMPACT_WINDOW=600k` (`SIKISTIRMA_ENV`, sabit); bekçide `sikistirma_denetle` (ortam tam '600k' → hesap ayarı → eşiksiz; claude yoksa ölçülemedi), yalnız değişince günlük; sınav `sikistirma-ortami.test.sh`.
- **2.27.0 (2026-10-26, BÂNİ · A5-3):** kapıda `/tty-k/*` → ttyd-kisi vekili (kökten yol, soket yoksa 502, abc ttyd'sine düşmez); `KAPI_KISI` · `KAPI_TTYD_KISI_SOKET`.
- **2.26.0 (2026-10-26, HEZARFEN · A5-1):** koltuk köprüsü + kişi istemcisi + mesaj komutu + kuru kipli kurulum paketi; ham tuş eylemi yok; `ttyd-kisi` `-W` düzeltmesi.
- **2.13.2 (2026-10-16, BÂNİ · tarayıcı sınavı artıkları):** `dim-okunur-sinav.mjs` tarayıcıyı `tarayici-bul.mjs` ile bulur (2.13.1 ile aynı kural; eski sabit yol ikilisiz pakette çöküyordu) ve `launch()` hatası ÖLÇÜLEMEDİ. `bekci-iz.test.sh`: sahte tmux/crontab PATH ile veriliyordu ama `ortak.sh` /usr/bin'i öne koyduğu için hiç kullanılmıyordu (ölçüldü: `command -v tmux` gerçek yolu veriyordu) — sınav artık betiklerin KOPYASINI koşturur, kopyanın ortak.sh'ı sahte kutuyu sona ekleyip öne alır, H1 kapısı bunu her koşuda ölçer (kurtarici-kapali.test deseni). Dim sınavına da #347 deseni: bayat kapı portu ön-kontrolü (ÖLÇÜLEMEDİ rc 4) + çıkışta ttyd/kapı/tmux temizliği (launch'ta çöken koşum kapılarını bırakıyordu, ölçüldü); temizlik iki sınavda SIGKILL ve çıkış kancası PORT KONTROLÜNDEN ÖNCE kayıtlı (#347'de kanca sonra kaydediliyordu, rc-4 çıkışı kancasızdı → ttyd kalıyordu; ölçüldü); kanıtta kapılı (önce/sonra bayat süreç 0). Davranış değişikliği yok; sınav dürüstlüğü.
- **2.13.1 (2026-10-16, BÂNİ · tarayıcı sınavı Playwright yolu, SERDAR bulgusu gorev_01M50PZVB1GCVG6D33V1PH96CT):** `pano-sinav.mjs` varsayılan olarak `/config/projects/Nexus/ui/node_modules`'a bakıyordu; orada paket var ama tarayıcı İKİLİSİ indirilmemiş → import geçip launch ÇÖKÜYORDU (rc 1 yığın; rc=4 ÖLÇÜLEMEDİ değil). Yeni `kapi/tarayici-bul.mjs`: adaylar sırayla (`KANIT_PLAYWRIGHT_DIR` → Nexus → nvm global `~/.nvm/versions/node/*/lib/node_modules`, en yeni önce), paketi VE `chromium.executablePath()` ikilisi diskte olan ilki seçilir; hiçbiri yoksa denenen yollar sebebiyle (`paket yok` / `ikili yok — npx playwright install`) ÖLÇÜLEMEDİ rc 4. `chromium.launch()` hatası da ÖLÇÜLEMEDİ. Artık ortam değişkensiz `node pano-sinav.mjs` bu kutuda 34/34. Üçüncü ortam hatasının (15 sn sayfa zaman aşımı) kökü ayrıydı: yarım kalan koşumun kapısı sabit portu (:18795/:18796) tutuyordu, sonraki koşum 200 görüp ölü ttyd soketine gidiyordu → pano-sinav artık koşmadan önce portu yoklar, cevap varsa ÖLÇÜLEMEDİ rc 4 + PID ile kapatma ipucu basar (bayat kapı portu dersi, 15 Eki). Sınav `tarayici-bul.test.mjs` (12; nvm sayısal sıra, G1 ölçülemeyince rc 4; `kapi-sinav.test.sh` ile CI'da — rc 4 sarı). Not: `dim-okunur-sinav.mjs` (#346) aynı eski deseni taşıyor — #346 birleşince aynı bulucuya bağlanır.
- **2.13.0 (2026-10-16, BÂNİ · dim okunurluk, pano köprüsü 1.3.0, Sultan 10:10 karesi nazir-yon, gorev_01M51RVWZXNK25C7GZGZ9MC767):** Claude Code soru satırlarını ve şık açıklamalarını ESC[2m (dim) basar; xterm dim'i rengi yarıya soldurarak çizer ve bunu `minimumContrastRatio`'dan SONRA uygular → "dim + gri-244" koyu temada **2,08:1** (Chromium piksel ölçümü; `minimumContrastRatio=7` bile dim'e işlemiyor — ölçüldü). Çare iki parça: (1) `genel/pano.js` SGR ayrıştırıcıya kanca — dim (2) → ön plan **brightBlack** (SGR 90); 22'de dim'den önceki açık renk (yoksa varsayılan) geri konur; 2'den sonra gelen açık renk kendi kazanır; dim'siz diziye dokunulmaz. (2) `onar.sh` ttyd temasına `brightBlack: #a89f91` (≥7:1). Sonuç: soru satırı **≥ 4,5:1** (gri-244 → 4,7; düz dim → 7). Sınav `kapi/dim-okunur-sinav.mjs` (18; gerçek ttyd+tmux+kapı+Chromium; önce = köprüsüz kapı: sorun ölçülür; piksel kontrast + hücre niteliği; `--kare` ile önce/sonra kare). Kapı yeniden açılmadan canlıya inmez: `komut.sh kapi-yenile` (2.12.0) pano.js'i sıcak tazeler, tema için ttyd'nin yeniden açılması gerekir (`onar.sh --web-yenile`, bağlantı bir kez kopar). Bilinen sınır: dim artık "soluk" değil "ikincil renk"; bold+dim kapanışında 22 bold'u da kapatır (xterm'in kendi davranışı korunur).
- **2.12.0 (2026-10-16, BÂNİ · kapı-yenile, SERDAR 00:5x/10:55):** pano köprüsü (genel/pano.js) kapı açılışında belleğe alınıyordu; yeni pano sürümü diske inince canlı kapı eskiyi sunuyor, tek yol `onar.sh --web-yenile` idi — kapı süreci ölür, Sultan'ın açık web terminali kopar. Artık kapı **SIGHUP**'ta pano.js'i bağlantı düşürmeden yeniden okur (okunamazsa son sağlam kopya sunulur, süreç ölmez, günlüğe düşer); `kapi.pid` ve `kapi.pano-sha` durum dizinine yazılır; `/giris` yanıtı `x-kapi-pano` başlığıyla yüklü sha'yı söyler. `komut.sh kapi-yenile`: disk sha = sunulan sha ise biter; kapı canlı ve `kapi.pid` canlı pid'le EŞLEŞİYORSA SIGHUP gönderir ve başlığın disk sha'sına döndüğünü ≤5 sn ÖLÇER; aksi hâlde (kapı yok · eski sürüm — SIGHUP onu öldürürdü · sha dönmedi · süreç öldü) `onar.sh --web-yenile`'ye düşer ve bunu SÖYLER (bir kez kopar, sonrakiler sıcak). `--kuru` yalnız yolu basar. Sınav: `kapi/kapi-yenile.test.mjs` (13, gerçek süreç: SIGHUP öncesi açılan bağlantı sonrasında da cevap alır; durum dizini yokken kapı kendisi açar; KAPI_PANO=0 başlığı "kapali"; `kapi-sinav.test.sh` ile CI'da) · `scripts/kapi-yenile.test.sh` (18, karar mantığı, köprü kapalıysa tazelenecek şey yok; mutasyon: pid eşleşme kapısı sökülünce eski kapıya SIGHUP gider → X1). Bilinen sınır: kurulu kopyada çalışan ESKİ kapı ilk seferde yine --web-yenile ile yenilenir (bir kez kopma); sonrası sıcak.
- **2.11.0 (2026-10-16, BÂNİ · kurtarıcısız ayarı, Sultan kararı 10:3x, gorev_01M51QW6F3Z35G6GQJMTPWFF61):** filo genelinde kurtarıcı ajanlar KAPANIR, yalnız code kutusununki kalır. Kutu başına işaret `/config/.terminal-onar/kurtarici-kapali` (ya da `TO_KURTARICI=0`): onar.sh K0 adım 4 kurtarıcıyı açmaz, açıksa kapatır (durum işarete yakınsar); durum.sh "kurtarıcı: kapalı (Sultan 16 Eki)" basar ve bunu sağlam sayar ("yok/düştü" demez; işaret var ama oturum açıksa "kapalı-ama-AÇIK" → bozuk, K0 kapatır); kademe.sh K2'yi atlar, K3 iletisine "kurtarıcı kapalı → MUAVİN/SERDAR'a bildir" ekler. Tek kurulum (ortak /config/.claude), işareti reisler kutu kutu koyar — code'da KONMAZ. Sınav `kurtarici-kapali.test.sh` (hermetik; mutasyon: işaret kontrolü sökülünce kırmızı).
- **2.10.1 (2026-10-16, BERİD · Kadro kişi↔oturum eşleşmesi kimlikle — SERDAR 00:4x, Sultan 00:22 karesi, huzur):** eşleşme yalnız tmux adıyla yapılınca ana oturumda çalışan kişi iki satır oluyordu ("oturumu yok" + ana "kimliği yok"). Yeni `kapi/kimlik.mjs` Claude'un süreç başına yazdığı oturum dosyalarını (`<yapılandırma>/sessions/<pid>.json`: sessionId · tmux · ad) okur — yalnız bu kutunun pid alanındaki, yaşayan, programı claude olan süreçler (ortak dizinde başka kutunun dosyası sayılmaz). Sıra: kayıttaki `session_id` (kimlik tanıma kancası yazar) → kullanıcının verdiği Claude adı (`claude -n`) → tmux adı. Kimlik iki oturuma çıkarsa tahmin yapılmaz. Kişi fiilen ana oturumdaysa "altyapı: ana oturum" korumalıdır (dondur/emekli 403). Kimlik izi yoksa davranış eskisidir. Canlı (code kutusu): SERDAR adla, MUHAKKIK ve HENDESE session_id ile bağlandı. Sınav `kapi/kimlik.test.mjs` (18, uçtan uca dahil; mutasyon 9/9; dosya adı = içindeki pid; basamaklar KADRO GENELİNDE sıralı: önce herkes için session_id, sonra kalanlar için ad). Bilinen sınır: kimlik tanıma kancası ana oturumu bir kişiye bağlayamadığında (huzur-ana ≠ huzur-yon) kayda session_id yazmaz → o kutuda kimlik izi yoktur, eşleşme tmux adına düşer.
- **2.10.0 (2026-10-16, BERİD · KADRO E2, Sultan onaylı — SERDAR 00:3x · D1):** Kadro sayfası artık yönetir: `POST /api/kadro/hal` dört eylem — **emekli et · dondur · geri aç · kayıtsız oturumu kapat** (hepsi geri alınabilir). Yazma KAYNAĞA gider (`kapi/kadro-yaz.mjs`, BÂNİ 15 Eki 18:31 ölçümü): elle kayıtta kişinin bloğuna `durum:` + önceki değer `durum_once:`; üretilmiş kayıtta (`ekipc:uretilen` bölgesi) `_agents/ekip-modeli.yaml` + derleyici (`KAPI_EKIPC` ya da kutunun `scripts/ekipc.sh`; yoksa HİÇ yazılmaz, 503). Yeni `hal:` alanı açılmaz. Gerçek ekipc ile ölçülen üç kural: derleyiciye kutunun kendi aile kaydı (`--aile`) verilir, temel katalog derleyicinin kendisidir (`--base-katalog` verilmez), K13 gereği canlı örnek donunca `olcek.adet` bir azalır; derlemenin kayıt DIŞI farkları (bekleyen ortak-temel yayılımı) uygulanmaz, sayısı yanıtta söylenir; kayıt dosyasının İÇİNDE başka kişiye ait bekleyen fark varsa yazım reddedilir (409, hiçbir şey yazılmaz). Geri alma derleyicisizdir: derleme öncesi fotoğraftan bayt bayt. Dondur/emekli oturumu da kapatır (kapatılamazsa kayıt geri alınır; geri alma da düşerse uç 500 ile bunu açıkça söyler); dondurulmuşu geri açmak oturumu `koltuk-ac --eski` ile eski sohbetine döndürür, emekliyi geri açmak yalnız kaydı geri koyar. **Altyapı** oturumları (ana · dash · dashproxy · dashwatch · ttyd-* · kapi-* · *-kurtarici · imglistener*) `/api/kadro`'da ayrı `altyapi` listesindedir (artık kırmızı "boş oturum"/"düşen" değil) ve hiçbir eylem onlara uygulanamaz (403, tmux'a dokunulmaz). Uç yalnız kapı oturumu çereziyle; jeton taşıyan istek 403. Eylemler süreç içi kuyrukla SIRAYLA yürür (yaz → oturumu kapat → gerekirse geri al zinciri bölünmez). Okuyucu: aile dalındaki kutularda (s02 · sedir · nova …) üretilmiş ekip kaydından YALNIZ `durum`, modelden yalnız `durum_once` okunur — rol/tmux ve kişi kümesi değişmez. Her eylem `kadro-hal.log`'a tek satır. Sınav: `kadro-yaz.test.mjs` (26; `--gercek` ile 5 kutunun gerçek kaydının KOPYASINDA gidiş-dönüş bayt eşitliği) · `kadro-hal.test.mjs` (25, uçtan uca: dondur → geri aç, altyapı 403) · `kadro.test.mjs` (30) — üçü de `kapi-sinav.test.sh` ile CI'da. Bilinen sınır: modeli bugün lint-kırmızı olan kutularda (nova · tez · nazir) derleyici reddeder → eylem 502, hiçbir şey yazılmaz.
- **2.9.3 (2026-10-15, BÂNİ · pano köprüsü 1.2.2, Sultan 2. kez "resim yapıştırma çok yavaş", gorev AT9J8305):** Safari WebP kodlayamıyor; küçültme her yapıştırmada önce PNG sonra JPEG olmak üzere İKİ kez kodluyordu. Artık destek bir kez yoklanır, yoksa doğrudan JPEG (tek kodlama). Bildirim adım sürelerini yazar ("küçültme X sn · yükleme Y sn · Z KB"); bir sonraki yavaşlıkta beklemenin küçültmede mi yüklemede (sunucu/ağ) mi olduğu ekrandan okunur. Sınav pano-sinav Y8-Y10.
- **2.9.2 (2026-10-15, BÂNİ · pano köprüsü 1.2.1, Sultan Safari 13:33):** kopyalama Safari'de ÇALIŞIYOR (Sultan ölçtü), ama seçim panoya indikten sonra kırmızı "pano yazımı reddedildi" + Kopyala düğmesi de çıkıyordu: aynı seçim için ikinci yazım (yinelenen OSC 52) hareket dışında reddedilip başarının üstüne uyarı basıyordu. Artık metin az önce (5 sn) indiyse aynı metin için yazım denenmez, ret sessiz geçer; söz yazımı sürerken gelen ret onun sonucunu bekler; düğme yalnız metin gerçekten inmediyse çıkar. Sınav pano-sinav S7/S7b.
- **2.9.1 (2026-10-15, BÂNİ · çalıştırma biti):** `scripts/compact.sh` ve `compact.test.sh` depoya 100644 girmişti; sync-skills duman testi "ÇALIŞTIRILAMAZ (izin yok)" ile düştü (kurulu kopya elle chmod +x ile düzeltildi, yeniden kurulumda tekrar düşerdi). Depoda 100755 yapıldı; aynı sınıftan `scripts/` altındaki 37 başka beceri betiği de düzeltildi (arac/ altındaki 7 dosya ayrı kart); kalıcı kapı depo kökünde `kabuk-biti.test.sh` — çağıranı CI (`lint.yml` "Kabuk sınamaları" her *.test.sh dosyasını keşfedip koşturur).
- **2.9.0 (2026-10-15, BÂNİ · zorunlu compact kutu-içi):** `komut.sh compact` / `compact-bekle` + `kapi/compact-olc.mjs` + bekçi kuyruk turu (yukarıda).
- **2.8.0 (2026-10-15, BÂNİ · Kadro E1 önkoşul):** `GET /api/kadro` (kapi/kadro.mjs: kayıt ayrıştırma + dört grup + kayıtsız + ana);
  kayıt alanı `hal:` tanımlandı. Sınav kadro.test.mjs 20, sunucu.test.mjs KD0-KD6 (97). Koltuk hâli/`ne` 2.7.0'dan gelir.
- **2.7.0 (2026-10-15, BÂNİ · Sultan eki 15 Eki 20:40 — 5. hâl):** koltuk hâline **⏳ `dis-olay` "dış olay bekliyor"**: yazı kutusu boş ama
  ekranda "N shells running" ya da "bekleniyor / bildirim gelince / CI … bekl" kalıbı → ajan çalışıyor sanılmaz, boşta da sayılmaz.
  `--liste` 6. sütun: ne beklediği (yalnız bu hâlde) — **bu beceri yalnız ÖLÇER ve veriyi kapıya verir; görünür çizim (⏳ ikon,
  üstüne gelince "ne bekliyor") terminal-merkez şeridindedir (cloudtop #621), bu PR'ın kapsamı değildir.** Öncelik: soru > çalışıyor > sınırda > girdi > dış olay > boş.
  `kapi/koltuklar.mjs` `ne` alanını taşır. Sınav: koltuk-bagla D1 (6 alan) · D13a-d. Boş kutu ölçümünde U+00A0 boşluk sayılır.
- **2.6.2 (2026-10-15, BÂNİ · gorev_01M4XM9MCBR01PF0S6ETWR2EQD, Sultan 01:45 "kopyalandı yazıyor ama kopyalanmıyor"):** pano köprüsü 1.1.0 — seçimsiz
  **Cmd+C (copy olayı) son tmux seçimini panoya GERİ yazar**; xterm.js'in boş seçimle olayı doldurması önce bizde yakalanır. Bildirim
  "yapışmazsa Cmd+C'ye bas" der. Hermetik ölçümde (Linux Chromium) panonun silindiği DOĞRULANAMADI (copy olayı engellenmemiş, pano
  değişmemiş); Mac Chrome'daki kök neden açık. Kapı: pano-sinav K7 (eski köprüde kırmızı, yeni köprüde yeşil). Son seçim **10 dk**
  tutulur (K7b: bayat seçim panoyu ezmez) — göz tur 1.
- **2.6.1 (2026-10-15, BÂNİ · SERDAR bulgu paketi 3 tekiller S-11 + S-7):** `kur.sh` ortak.sh kutu adını reddedince tek satır
  sebeple durur (rc 3; eskiden 'TTYD_BIN: unbound variable'). Yerel kopya ortak koddan FARKLIYSA bağlama DURUR ve farkı listeler
  (rc 8; REVAK 12 Eki: 863 satırlık sınavlı yerel değişiklik ezilmişti) — bilinçli ezmek `TERMINAL_KUR_FARK_KABUL=1`, kopya yine
  `.eski-*` altında saklanır. Sınav: `kur-bag.test.sh` S7a-d · S11a-b (50 kapı; S11b çıktı TEK satır, S7d diff hatası = ÖLÇÜLEMEDİ → durur); mutasyon: eski kur.sh ile 5 kapı kırmızı.
- **2.6.0 (2026-10-15, BÂNİ · SERDAR bulgu paketi S-9 + S-10):** bekçi/açılış satırı bağ yokken ortak yola `TO_KUTU` ile düşer
  (rc 127 ölümü bitti); deneme kopyası canlı crontab'a dokunamaz (`canli_crontab_izinli`); çift işaretli satır tekilleşir.
  cloudtop kanonu (`infra/cron/crontab-abc`) aynı pakette yeni biçime geçti. Sınav: `kur-bag.test.sh` 44 kapı (S9a-c · S10a-f · K0 kalkan).
- **2.5.0 (2026-10-14, MUAVİN · SERDAR bulgusu):** boş kabuk koltuk BOŞ hükmü + alt ağaçta Claude araması + claude.exe (yukarıda).
- **2.4.4 (2026-10-13, BÂNİ · G-BANI-0007 madde 1 — "sessiz düşürme yok"):** fark ölçeri. `kapi/koltuk-fark.mjs` kutudaki her tmux
  oturumuna tek hüküm verir: görünür · gizli:<neden> · gizli:ad-süzgeci · **DÜŞEN** (gerekçesiz → rc 1). Listede olup tmux'ta olmayan
  (hayalet) da rc 1. Başka adla bağlı istemci (code-server sekmesi `tmux attach -t yenileme` açılmış, oturum sonra `2026/85` olmuş —
  vekatip'teki "YargiYenileme" vakası) bilgi olarak raporlanır. Görünür liste `/api/koltuklar` ile AYNI koddan: ad kuralı + satır
  çözümü `kapi/koltuklar.mjs`'e taşındı (kapı ve ölçer içe alır), gizleme kararı `koltuk-bagla.sh --gizli` (gerekçeli). Filo:
  `scripts/koltuk-fark-filo.sh` (varsayılan yol SALT-OKUR: kurulu kopya; `--kaynak` kurulmamış sürüm için kutunun /tmp'sine geçici açar,
  çıkışta siler — salt-okur değildir, kalıcı yazmaz). Canlı iniş sonrası salt-okur filo ölçümü ayrı adım (kart daraltıldı). İlk tarama 13 Eki:
  terminalli 18 kutu · düşen 0 · hayalet 0; terminalsiz 6 kap (tmux/node yok) ayrı sayılır. Sınav `kapi/koltuk-fark.test.sh` 14 kapı; istemci listesi/komut satırı okunamazsa sessiz değil, sayılır.
- **2.4.3 (2026-10-13, BÂNİ · A357 koltuk adı süzgeci, #308):** adında `/`, arada boşluk ya da emoji olan koltuk listeden düşmez; `/api/koltuklar` ile `/api/koltuk/<ad>` tek kurala bağlandı (`koltuk-adi.sh` ⟷ `KOLTUK_AD_DESEN`), uzunluk iki dilde kod noktası, seçici adı kaçışlı. (Dal 2.4.1 olarak açılmıştı; 2.4.2 önce birleştiği için 2.4.3.)
- **2.4.2 (2026-10-13, BÂNİ · G-BANI-0002/4 ilk dilim — #304'ün kusuru):** Aç, merkez dışındaki 11 İSKÂN kutusunda kayıtlı
  koltuğu "kayıtsız" sanıyordu: `koltuk-ac.sh` yalnız `aile-registry.yaml` okuyordu, bu kutuların açıcısı ise
  `baslat-claude.sh` + `iskan-registry.yaml`. Açıcı ve kayıt artık birlikte seçilir; İSKÂN'daki grid `ekip-ac.sh` açıcı sayılmaz.
  Ekran: İSKÂN koltuğunda "açılınca kendi sohbetine döner", ayrı "Eski sohbete dön" gizli.
- **2.3.0 (2026-10-13, MUAVİN · REVAK gerilemelerinin ortak koda taşınması):** 12 Ekim'de 18 kutuyu ortak beceriye
  bağlarken REVAK-KURTARICI'nın kendi geliştirdiği üç iyileştirme ezildi (canlı "Usta Defteri" sayfası 404 oldu).
  Üçü ortak koda taşındı: (1) rapor dizini kutudan türer ve kapıya verilir; (2) `.defter-yayin` işaretli klasör
  salt-okur + kum havuzu (klasör-başına: SEDİR'in yazan sayfaları eski davranışta); (3) bekçi koşu izi + durum.sh'ın
  ize bakması. 🔴 Ders: **bağlamadan önce fark ölçülür** — kutunun yerel kopyası ortak sürümden YENİ olabilir;
  `.eski-<tarih>` yedeği kurtardı, ölçmeyen kurulum gerilemeyi görmezdi.
- **2.2.2 (2026-10-13, MUAVİN · sır-hijyeni):** `sifre_yukle` erişim ortam dosyasını artık **source etmiyor**; yalnız
  `AD=değer` satırlarını okuyor (`ortam_yukle`, çevreleyen tırnak soyulur, `export` öneki kabul). Niçin: 13 Ekim onarım
  turunda üç kutuda (code 135 · tellal 7 · mmex 1) dosyada ad=değer olmayan satırlar vardı; `. dosya` onları KOMUT gibi
  koşturdu ve "command not found" ile değer parçaları stderr'e düştü. Bozuk satırlar sayılır (`ORTAM_BOZUK_SATIR`), içeriği
  basılmaz. Sınav `sifre-yukle.test.sh` (6 kapı, hermetik); mutasyon: eski source yolu geri gelince E3/E4 kırmızı.
