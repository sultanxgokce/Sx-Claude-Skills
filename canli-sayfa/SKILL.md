---
name: canli-sayfa
type: tool
version: 1.0.0
description: >
  Sultan bir kutudan ya da ajandan CANLI bir sayfa istediğinde (tarayıcıdan adresle açılan her şey:
  pano, liste, rapor sayfası, uygulama, tanıtım sayfası) uyulacak FİLO KURALI ve onun aracı.
  Kural: canlıya çıkan her sayfa ortak kayda yazılır; kayıt canlı sayfaların TEK listesidir ve Sultan'ın
  menüsü bu listeden üretilir. Kayıt adresi o an ölçer: açılmayan sayfa
  kayda girmez, giriş kapısı olmadan açılan sayfa onaysız kayda girmez. Şu durumlarda kullan: yeni bir
  canlı adres açtın · var olan sayfanın adı/işi değişti · bir sayfayı kaldırdın · "canlı sayfalarımız
  neler" diye soruldu · "/canli-sayfa". Kayıtsız canlı sayfa bırakmak kural ihlalidir.
---

# /canli-sayfa — canlı sayfa kuralı ve kaydı

## Kural (bütün kutular, bütün ajanlar)

> **Canlıya çıkan her sayfa kayda girer. Kayda girmeyen sayfa Sultan için yoktur.**

Sultan'ın isteği (29 Eylül 2026): canlı sayfalar sürekli kuruluyor, adresleri dağınık kalıyor. Kokpitte tek bir
menü olacak; yeni sayfa kuruldukça oraya eklenecek. Menüyü elle kimse yazmaz: **menü kayıttan üretilir**,
kaydı da sayfayı kuran ajan yazar.

> **Durum (sürüm 1.0.0):** kayıt ve araç hazır. Kokpit menüsü ayrı işte kuruluyor; o iş canlıya çıkana kadar
> kayıt `liste` komutuyla görülür. Sultan'a "menüye eklendi" DEME; "kayda girdi" de.

"Canlı sayfa" = Sultan'ın tarayıcıdan bir adresle açtığı her şey. Kutunun çalışma ekranı (kutuya girilen adres)
bu kaydın konusu değildir; o, kokpitte zaten kutu kartındadır.

## Sultan canlı sayfa istediğinde — dört adım, sıra değişmez

1. **Kur.** Sayfayı kutunun kendi kurallarıyla yap.
2. **Yayına çıkar — önce giriş kapısı, sonra adres.** Kapı arkasında olması gereken sayfa, kapısı kurulmadan
   adres almaz. Adres ve giriş kapısı açmak merkezin işidir: izole kutudaysan kendin açmaya çalışma,
   SERDAR'a istek yaz (kutunun teslimat yolu). Herkese açık olacak sayfa Sultan'ın açık kararını ister.
3. **Kayda yaz.**
   ```bash
   bash /config/.claude/skills/canli-sayfa/scripts/canli-sayfa.sh ekle \
     --adres https://ornek.mmepanel.com --ad "Bulgu Defteri" \
     --ne "Kutulardan gelen bulguların tek listesi" --kutu <kutunun adı> --ekleyen <SENİN ADIN>
   ```
4. **Gör ve söyle.** `canli-sayfa.sh liste` ile kaydı gör; Sultan'a adresi verirken "canlı sayfa kaydına girdi" de.
   Kayıt reddedildiyse sebebini olduğu gibi söyle, "girdi" deme.

Sayfa kalktıysa: `canli-sayfa.sh emekli --adres … --gerekce "…"`. Adı ya da işi değiştiyse aynı adresle yeniden `ekle`.

## Komutlar

| Komut | Ne yapar | rc |
|---|---|---|
| `ekle --adres --ad --ne --kutu --ekleyen [--herkese-acik evet]` | adresi ölçer, kurallardan geçirir, kaydı yazar; aynı adres varsa günceller (ilk tarih korunur) | 0 · 2 kural · 3 canlı değil/ölçülemedi · 4 kapısız sayfa onaysız |
| `liste [--hepsi] [--json]` | canlı kayıtlar; `--hepsi` emeklileri de; `--json` menünün okuduğu biçim | 0 · 1 bozuk kayıt var |
| `emekli --adres --gerekce` | kaydı silmez, menüden kaldırır | 0 · 1 kayıt yok · 2 |
| `dogrula` | canlı kayıtların hepsini yeniden ölçer: açılmayan ve giriş kapısı değişen sayfayı yazar; kaydı değiştirmez | 0 · 1 sorunlu kayıt var |

## Kayıt kuralları (araç uygular, geçmeyen kayıt yazılmaz)

| Alan | Kural |
|---|---|
| adres | `https://` ile başlar · düz alan adı · port, soru işareti, `#`, kullanıcı adı REDDEDİLİR (bu parçalar anahtar taşıyabildiği için kayda hiç alınmaz) |
| ad | 1–4 kelime, en çok 40 karakter: Sultan'ın menüde tek bakışta tanıyacağı ad |
| ne | tek cümle, en çok 140 karakter, Sultan'ın okuyacağı dille: dosya yolu, komut, adres, kod imi yok |
| kutu · ekleyen | zorunlu: sayfa kimin, kaydı kim yazdı |
| sır | sır gibi görünen değer reddedilir, değer ekrana basılmaz |

**Giriş kapısı ölçülür, beyan edilmez.** Araç adresi açar: giriş kapısına yönleniyorsa ya da kendi kilidi varsa
`kapalı`, kapısız açılıyorsa `açık` yazar. `açık` çıkan sayfa yalnız `--herkese-acik evet` ile kaydedilir.
Bu bayrak Sultan'ın "bu sayfa herkese açık olsun" kararının karşılığıdır; ajan kendi kararıyla vermez.

## Mahremiyet
Kayıt ortak dizindedir, bütün kutular okur. Kayda yalnız **ad, tek cümle, adres** girer. Mahrem bir kutunun
sayfasını kaydederken adı ve cümleyi içerik sızdırmayacak biçimde yaz (müşteri adı, kişi adı, rakam yok).

## Kayıt nerede
`/config/.claude/canli-sayfalar/<adres>.json`, sayfa başına bir dosya. Ortak dizin olduğu için her kutudan
yazılır; sayfa başına dosya olduğu için iki kutu aynı anda yazsa da birbirinin kaydını ezmez. Dosyalar elle
düzenlenmez; bozuk kayıt `liste` ve `dogrula` çıktısında adıyla görünür.

## Sınırlar (dürüst)
- Araç sayfayı **kurmaz, adres açmaz, giriş kapısı kurmaz**; yalnız kaydeder ve ölçer.
- Ölçüm, aracın koştuğu kutudan yapılır. Kutu dışarıya çıkamıyorsa kayıt yapılamaz (rc 3); "ölçülemedi"
  "canlı değil" ile aynı sonuca gider ama mesajı ayrıdır.
- `dogrula` kendiliğinden koşmaz; zamanlanması ayrı iştir. Koşmadığı sürece kalkmış bir sayfa menüde kalabilir.
- Kuralı uygulatan bir kilit yoktur: kayıt yazmayan ajanı araç yakalayamaz. Yakalama yolu, merkezdeki adres
  envanteriyle kaydı karşılaştırmaktır (ayrı iş).
- Sınav: `scripts/canli-sayfa.test.sh` (sahte kayıt dizini ve sahte ölçerle; gerçek kayda ve ağa dokunmaz).
