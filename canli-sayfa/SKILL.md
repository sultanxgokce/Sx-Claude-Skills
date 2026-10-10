---
name: canli-sayfa
type: tool
version: 1.2.0
description: >
  Sultan bir kutudan ya da ajandan CANLI bir UI, sayfa, pano, ekran, demo ya da rapor sayfası istediğinde
  (tarayıcıdan adresle açılan her şey) uyulacak FİLO KURALI ve onun aracı. Kural (Sultan, 1 Ekim 2026):
  Sultan'ın canlı sayfaları tek yerden yayınlanır ve tek yerden ulaşılır — kokpitin "Canlı sayfalar"
  menüsü (kokpit.mmepanel.com/#/sayfalar). Menü bu becerinin kaydından üretilir: canlıya çıkan her sayfa
  kayda yazılır, kayda girmeyen sayfa Sultan için yoktur. Kendi alan adımızdaki (.mmepanel.com) sayfa
  kokpitin İÇİNDE açılır — sayfanın sunucusu kokpitin çerçevesine izin vermelidir; .mukarnas.net ya da
  başka alandaki sayfa ayrı sekmede açılır. Şu durumlarda kullan: Sultan "canlı bir sayfa / ekran / pano
  istiyorum" dedi · yeni bir canlı adres açtın · var olan sayfanın adı/işi değişti · bir sayfayı kaldırdın ·
  "canlı sayfalarımız neler" diye soruldu · "/canli-sayfa". Kayıtsız canlı sayfa bırakmak kural ihlalidir.
---

# /canli-sayfa — canlı sayfa kuralı ve kaydı

## Kural (bütün kutular, bütün ajanlar)

> **Sultan canlı bir UI ya da sayfa istediğinde o sayfa kokpitin "Canlı sayfalar" menüsünden yayınlanır ve oradan ulaşılır.
> Canlıya çıkan her sayfa kayda girer; kayda girmeyen sayfa Sultan için yoktur.**

Sultan'ın sözü (1 Ekim 2026): *"Sultan canlı bir UI veya page istediğinde burada yayınlanacak veya buradan ulaşılacak. Eğer domain
.mmepanel.com şeklinde ise buraya direk kendinden olarak (tıkladığımda başka bir siteye yönlenmeyecek, bu sayfa içinde açılacak);
eğer .mukarnas.net veya başka domainse ayrı sekmede açılabilir."* İlk istek 29 Eylül: tek menü, yeni sayfa kuruldukça oraya eklenir.
Menüyü elle kimse yazmaz: **menü kayıttan üretilir**, kaydı da sayfayı kuran ajan yazar.

| Sayfanın alanı | Menüde ne olur | Sayfayı kuranın yükümlülüğü |
|---|---|---|
| `*.mmepanel.com` | **kokpitin içinde** açılır (çerçeve, `#/sayfa/…`); "ayrı sekmede aç" izi hep durur | sunucu kokpitin çerçevesini **yasaklamamalı**: `X-Frame-Options: SAMEORIGIN/DENY` koyma; çerçeve korumasını `Content-Security-Policy: frame-ancestors 'self' https://kokpit.mmepanel.com` ile ver |
| `*.mukarnas.net` ve başka alan | ayrı sekmede açılır | — |
| kokpitin kendisi | kokpit ana ekranına götürür | — |

Çerçeveyi yasaklayan sayfa kokpitte **boş** görünür (menü ayrı sekme izini ve sebebi yazar). Bunu bilerek bırakma: kayda yazarken
kendi sunucunun başlığına bak, yasak varsa yukarıdaki satırla değiştir; değiştiremiyorsan (başkasının sunucusu) SERDAR'a yaz.

"Canlı sayfa" = Sultan'ın tarayıcıdan bir adresle açtığı her şey. Kutunun çalışma ekranı (kutuya girilen adres)
bu kaydın konusu değildir; o, kokpitte zaten kutu kartındadır.

## Sultan canlı sayfa istediğinde — dört adım, sıra değişmez

1. **Kur.** Sayfayı kutunun kendi kurallarıyla yap.
2. **Yayına çıkar — önce giriş kapısı, sonra adres.** `.mmepanel.com` adresinde sunucu kokpitin çerçevesine izin versin (üstteki tablo). Kapı arkasında olması gereken sayfa, kapısı kurulmadan
   adres almaz. Adres ve giriş kapısı açmak merkezin işidir: izole kutudaysan kendin açmaya çalışma,
   SERDAR'a istek yaz (kutunun teslimat yolu). Herkese açık olacak sayfa Sultan'ın açık kararını ister.
3. **Kayda yaz.**
   ```bash
   bash /config/.claude/skills/canli-sayfa/scripts/canli-sayfa.sh ekle \
     --adres https://ornek.mmepanel.com --ad "Bulgu Defteri" \
     --ne "Kutulardan gelen bulguların tek listesi" --kutu <kutunun adı> --ekleyen <SENİN ADIN>
   ```
4. **Gör ve söyle.** `canli-sayfa.sh liste` ile kaydı gör; Sultan'a "kokpitte Canlı sayfalar menüsünde" de; adresi de ver.
   Kayıt reddedildiyse sebebini olduğu gibi söyle, "girdi" deme.

Sayfa kalktıysa: `canli-sayfa.sh emekli --adres … --gerekce "…"`. Adı ya da işi değiştiyse aynı adresle yeniden `ekle`.

## Komutlar

| Komut | Ne yapar | rc |
|---|---|---|
| `ekle --adres --ad --ne --kutu --ekleyen [--herkese-acik evet] [--imza "<dize>"]` | adresi ölçer, kurallardan geçirir, kaydı yazar; aynı adres varsa günceller (ilk tarih korunur). `--imza`: sayfanın kendi içeriğinden bir dize (4-80 karakter); 2xx dönen adreste anonim gövde okunur, imza yoksa **giriş ölçülemedi (SARI: ne kapalı ne açık)** — kayıt yazılır, **rc 5** | 0 · 2 kural · 3 canlı değil/ölçülemedi (kayıt yok) · 4 kapısız sayfa onaysız · **5 kayıt yazıldı ama giriş ölçülemedi (sarı, yalnız `--imza`)** |
| `liste [--hepsi] [--json]` | canlı kayıtlar; `--hepsi` emeklileri de; `--json` menünün okuduğu biçim | 0 · 1 bozuk kayıt var |
| `emekli --adres --gerekce` | kaydı silmez, menüden kaldırır | 0 · 1 kayıt yok · 2 |
| `dogrula` | canlı kayıtların hepsini yeniden ölçer: açılmayan ve giriş kapısı değişen sayfayı yazar; giriş ölçülemeyen (sarı) kaydı `△` ile ayrı sayar; kaydı değiştirmez | 0 · 1 sorunlu kayıt var · 5 sorun yok ama sarı kayıt var |

## Kayıt kuralları (araç uygular, geçmeyen kayıt yazılmaz)

| Alan | Kural |
|---|---|
| adres | `https://` ile başlar · düz alan adı · port, soru işareti, `#`, kullanıcı adı REDDEDİLİR (bu parçalar anahtar taşıyabildiği için kayda hiç alınmaz) |
| ad | 1–4 kelime, en çok 40 karakter: Sultan'ın menüde tek bakışta tanıyacağı ad |
| ne | TEK cümle (cümle bitiminden sonra yeni söz başlıyorsa reddedilir), en çok 140 karakter, Sultan'ın okuyacağı dille: dosya yolu, komut, adres, kod imi yok |
| kutu · ekleyen | zorunlu: sayfa kimin, kaydı kim yazdı |
| sır | sır gibi görünen değer reddedilir, değer ekrana basılmaz |

**Giriş kapısı ölçülür, beyan edilmez.** Araç adresi açar: giriş kapısına yönleniyorsa ya da kendi kilidi varsa
`kapalı`, kapısız açılıyorsa `açık` yazar. `açık` çıkan sayfa yalnız `--herkese-acik evet` ile kaydedilir.
Bu bayrak Sultan'ın "bu sayfa herkese açık olsun" kararının karşılığıdır; ajan kendi kararıyla vermez.

**Üçüncü hâl — gövde korumalı (1.2, A314, MÜCESSEM ölçtü):** tarayıcıda betikle yüklenen korumalı sayfa (ör. claude.ai
artifact) anonim isteğe **200 + boş kabuk** döner: kod "açık" der, içerik yoktur. Kapı yalnız koda baksa operatörü iki yanlışa
sıkıştırır (kaydı atla ya da `--herkese-acik evet` yanlış beyanı). Çare: `--imza "<dize>"` — sayfanın **kendi içeriğinden** bir
dize. 2xx'te araç anonim gövdeyi okur: imza **varsa** gerçekten açık (yine `--herkese-acik evet` ister); **yoksa** üçüncü hâl
**giriş `olculemedi` — SARI**: "kapalı" **denmez** (kapının varlığı anonim istekle ölçülemez; yanlış yazılmış bir imza da aynı
sonucu verir, o yüzden bu hâl kapı kanıtı değildir), "açık" da denmez (içerik gelmedi). Sayfa canlı olduğu için **kayıt yazılır**
(kayıtsız canlı sayfa ihlaldir; `giris: olculemedi`, `giris_olcu: govde`) ama komut **rc 5** döner — yeşil değil — ve listede
"GİRİŞ ÖLÇÜLEMEDİ (sarı: gövde korumalı, kapı bilinmiyor)" görünür. Gövde hiç okunamazsa rc 3, kayıt yok.
İmza verilmediyse eski kural aynen (2xx = açık). `dogrula` kayıttaki imzayla yeniden ölçer: imza anonimde görünür olursa
"KAPI DEĞİŞTİ" (sarıdan açığa). İmza sır olamaz (parola/token deseni reddedilir, değer basılmaz).

## Mahremiyet
Kayıt ortak dizindedir, bütün kutular okur. Kayda yalnız **ad, tek cümle, adres** girer. Mahrem bir kutunun
sayfasını kaydederken adı ve cümleyi içerik sızdırmayacak biçimde yaz (müşteri adı, kişi adı, rakam yok).

## Kayıt nerede
`/config/.claude/canli-sayfalar/<adres>.json`, sayfa başına bir dosya. Ortak dizin olduğu için her kutudan
yazılır; sayfa başına dosya olduğu için iki kutu aynı anda yazsa da birbirinin kaydını ezmez. Dosyalar elle
düzenlenmez; bozuk kayıt `liste` ve `dogrula` çıktısında adıyla görünür ve araç onun üstüne yazmaz (delildir, elle incelenir).

## Sınırlar (dürüst)
- Araç sayfayı **kurmaz, adres açmaz, giriş kapısı kurmaz**; yalnız kaydeder ve ölçer.
- Ölçüm, aracın koştuğu kutudan yapılır. Kutu dışarıya çıkamıyorsa kayıt yapılamaz (rc 3); "ölçülemedi"
  "canlı değil" ile aynı sonuca gider ama mesajı ayrıdır.
- `dogrula` kendiliğinden koşmaz; zamanlanması ayrı iştir. Koşmadığı sürece kalkmış bir sayfa menüde kalabilir.
- Kuralı uygulatan bir kilit yoktur: kayıt yazmayan ajanı araç yakalayamaz. Yakalama yolu, merkezdeki adres
  envanteriyle kaydı karşılaştırmaktır (ayrı iş).
- Sınav: `scripts/canli-sayfa.test.sh` (sahte kayıt dizini ve sahte ölçerle; gerçek kayda ve ağa dokunmaz).
