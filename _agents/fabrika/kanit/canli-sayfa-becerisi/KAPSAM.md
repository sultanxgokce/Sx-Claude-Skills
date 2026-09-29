# canli-sayfa-becerisi — kapsam, karar, bilinen sınırlar (2026-09-29 · SERDAR)

## İstek (D1)
2026-09-29 Sultan: kokpitte canlı sayfaların menüsü olsun; sayfa kuruldukça eklensin; kural bütün kutulara öğretilsin,
beceri ve komut olarak global dağıtılsın
(sohbet · session_013fuJSNg65VkgQE4sJsQURS · "bunu bir ai skill ve slash komutuna çevir ve tüm kutulara global dağıt" · beyan:SERDAR)
2026-09-29 Sultan: ortak kayıt dosyalarındaki çakışmada devam edilsin
(sohbet · session_013fuJSNg65VkgQE4sJsQURS · "Devam et, satırımı ekle" · beyan:SERDAR)

## Bu işte ne var
| Parça | Ne |
|---|---|
| `canli-sayfa/SKILL.md` | filo kuralı: canlıya çıkan her sayfa kayda girer; dört adım; `/canli-sayfa` komutu beceri adından gelir |
| `canli-sayfa/scripts/canli-sayfa.sh` | kayıt aracı: `ekle` · `liste` (`--json` menü biçimi) · `emekli` · `dogrula` |
| `canli-sayfa/scripts/canli-sayfa.test.sh` | sınav, sahte kayıt dizini ve sahte ölçerle |
| `catalog.json` · `sync-targets.json` | beceri kaydı ve dağıtım hedefi (`_global`) |

## Bu işte OLMAYAN (ayrı işler, sırayla)
1. **Kurulum.** Birleştikten sonra beceri ortak beceri dizinine kurulur (yalnız bu beceri; toplu kurulum yapılmaz) ve
   kurulu kopya kaynakla karşılaştırılır.
2. **İlk kayıtlar.** Bugün canlı olan sayfalar kurulu araçla kayda yazılır.
3. **Kokpit menüsü.** Kokpitin veri toplayıcısı kaydı okur, ekran "Canlı sayfalar" görünümünü çizer (cloudtop + Nexus).
4. **Kuralın bütün kutulara duyurulması.** Beceri tanımı ortak dizinde olduğu için her kutunun beceri listesinde görünür;
   ayrıca ortak talimat dosyasına kısa kural satırı ve kutu reislerine duyuru.
5. **`dogrula`nın zamanlanması** ve adres envanteriyle kaydın karşılaştırılması (kayıt yazmayan ajanı yakalama yolu).

## Tasarım kararları
- **Sayfa başına bir dosya, ortak dizinde.** Ortak dizin bütün kutulardan yazılabilir (ölçüldü: beceri dizini ve ayarlar
  aynı dizinde, bütün kutularda ortak). Tek dosya olsaydı kilit gerekirdi ve bozulan tek dosya bütün menüyü götürürdü.
- **Ölçmeden kaydetmez.** "Canlı" bir beyan değil ölçümdür: açılmayan adres kayda girmez (rc 3).
- **Giriş kapısı ölçülür.** Kapısız açılan sayfa yalnız açık onayla kaydedilir (rc 4). Emsal: 25 Eylül'de bir sayfa
  kayıtta "kapı var" derken canlıda kapısız açılıyordu.
- **Adres satırı anahtar taşıyamaz:** soru işareti, `#`, kullanıcı adı, port reddedilir.
- **Silme komutu yok.** Kalkan sayfa `emekli` olur; kayıt delil olarak kalır.

## Kanıt
| Ölçüm | Ne gösterir |
|---|---|
| sınav | sahte ölçerle bütün kapılar |
| mutasyon | aracın bozuk kopyalarının her biri sınavda kırmızı |
| canlı prova | gerçek ağ ölçümüyle, geçici kayıt dizininde: üç gerçek sayfa kayda girdi (giriş: kapalı), olmayan adres rc 3, kapısız sayfa rc 4, `dogrula` yeşil |
| depo kapıları | kayıt ile dağıtım haritası eşleşiyor · sürüm satırı geçerli |
Sayılar ölçüm dosyalarındadır; belgeye sayı yazılmadı (kanıt yeniden üretildiğinde belge bayatlamasın).

## Bilinen sınırlar
- Kuralı uygulatan kilit yok; kayıt yazmayan ajanı araç yakalayamaz.
- Ölçüm aracın koştuğu kutudan yapılır; dışarı çıkamayan kutuda kayıt yapılamaz.
- "Kapalı" ölçümü iki işarete dayanır: giriş kapısının adresine yönlenme ya da 401/403. Başka bir kapı türü
  (ör. sayfanın kendi giriş formu 200 dönerek) "açık" ölçülür ve onay ister; bu yönde hata güvenli taraftadır.
- Başka bir yere yönlenen sayfa (kapı olmayan yönlenme) `yönleniyor` diye kaydedilir; hedefin kapısı ölçülmez.
- Sır deseni kaba bir ağdır (uzun rastgele dizi, "parola=" gibi kalıplar); kısa bir sırrı yakalamaz. Asıl koruma
  alanların dar olmasıdır (ad, tek cümle, adres).
- Kayıt dosyaları ortak dizinde düz dosyadır; bir kutu başka kutunun kaydını değiştirebilir. Kimin yazdığı `ekleyen`
  alanındadır ama doğrulanmaz.
