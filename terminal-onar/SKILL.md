---
name: terminal-onar
description: Bir kutuda Sultan'ın canlı çalışma düzenini (tmux <kutu>-ana'daki Claude konuşması + web terminali + telefon ekranı + kurtarıcı ajan + dakikalık bekçi) KURAR, ÖLÇER ve ONARIR. "/terminal-kur · bu kutuya terminal kur · /terminal-onar · terminal bozuldu · web terminali açılmıyor · oturum kapandı · düzeni yeniden kur" tetiğinde; onarım merdiveni (bekçi / Onar düğmesi) kademe 1-2'de de bu beceriyi çağırır. Bütün kutularda koşar — adlar kutudan türer, hiçbir kutu adı koda gömülü değildir.
version: 2.1.0
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
