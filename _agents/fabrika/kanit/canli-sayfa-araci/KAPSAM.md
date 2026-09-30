# canli-sayfa-araci — kapsam, karar, bilinen sınırlar (2026-09-30 · SERDAR)

## İstek (D1)
2026-09-29 Sultan: kokpitte canlı sayfaların menüsü olsun; sayfa kuruldukça eklensin; kural bütün kutulara öğretilsin,
beceri ve komut olarak global dağıtılsın
(sohbet · session_013fuJSNg65VkgQE4sJsQURS · "bunu bir ai skill ve slash komutuna çevir ve tüm kutulara global dağıt" · beyan:SERDAR)
2026-09-29 Sultan: ortak kayıt dosyalarındaki çakışmada devam edilsin
(sohbet · session_013fuJSNg65VkgQE4sJsQURS · "Devam et, satırımı ekle" · beyan:SERDAR)

## Önceki kartlar
`canli-sayfa-kayit-araci` (PR #253) araç + beceri tanımı + dağıtım kaydını birlikte taşıyordu; dört turda 4/5'te kaldı
(tur 4 tek bulgu: açıklamada tek cümle kuralı denetlenmiyordu). Sultan kararı: ikiye böl
(2026-09-30 Sultan: ikiye böl (sohbet · session_013fuJSNg65VkgQE4sJsQURS · "İkiye böl, yeniden gönder" · beyan:SERDAR)).
Bu kart yalnız **kayıt aracı ve sınavıdır**; beceri tanımı (SKILL.md) ile dağıtım kaydı (catalog · sync-targets)
`canli-sayfa-beceri-kaydi` kartına gitti. Tur 4 bulgusu burada kapatıldı: `ne` alanında cümle bitiminden sonra yeni söz
başlıyorsa rc 2 (sınav T6b, mutasyon 31-32).

Daha önce `canli-sayfa-becerisi` (PR #252) işi üç depoya yayılmış hâliyle tarif ediyordu; tek PR karşılayamadı (denetim tur 1:
2/5). Daraltıldı. Bu kart yalnız **beceri kaynağı ve kayıt aracıdır**. O turun öbür bulguları da işlendi: araç artık
kurulmamış menü hakkında söz vermiyor (sınav T1), beceri metni menünün henüz kurulmadığını açıkça yazıyor, adres
kuralının cümlesi düzeltildi.

## Denetim turları
- **Tur 1 (2/5):** ortak kayıt dosyaları eski bir çalışma kopyasından taşınmıştı; o arada ana dala giren `terminal-onar`
  kaydı silinmiş, güncelleme tarihi gerilemişti. Gerçek hata. Dosyalar ana dalın güncel hâlinden alındı, yalnız
  `canli-sayfa` eklendi; korunumu ölçen betik kanıta girdi.

- **Tur 2 (4/5):** dosya adı üretimi iki ayrı adresi aynı dosyaya düşürebiliyordu (`/a/b` ile `/a_b`) · emeklilik
  gerekçesi süzülmeden kayda yazılıyordu. İkisi de gerçek hata, ikisi de düzeltildi: dosya adı adresten bire bir
  üretiliyor ve başka adresin kaydının üzerine yazılmıyor; gerekçe öbür metinlerle aynı kurallardan geçiyor.

- **Tur 3 (4/5):** değer isteyen seçenek değersiz verilince araç sonsuz döngüye giriyordu. Gerçek hata, düzeltildi
  (sınav T11; sınavdaki her çağrı artık süreyle sınırlı). Aynı turda kendi gözden geçirmemle bir açık daha kapatıldı:
  `dogrula` kayıtları okurken ölçerin girdiyi yutması.

## Denetim turları (bu kart)
- **Tur 1 (4/5 E):** hedef dosyada bozuk (okunamayan) kayıt varsa `ekle` üstüne yazıyordu; delil kaybolabilirdi. Gerçek
  hata, düzeltildi: bozuk hedef başka adresin kaydı gibi korunur, `ekle` ve `emekli` rc 3 ile durur ve elle inceleme
  ister (sınav T9b, mutasyon 33-34).
- **Tur 2 (4/5 E):** okunabilen ama kayıt olmayan hedef (`{}`, adres alanı boş, liste) hâlâ "aynı adres" sayılıp eziliyordu.
  Gerçek hata, düzeltildi: adres alanı düzgün bir metin değilse hedef bozuk sayılır, rc 3 (sınav T9b dört örnek,
  mutasyon 35).
- **Tur 3 (4/5 E):** aynı sayfaya iki kutu aynı anda yazarsa son yazan öbürünü ezebiliyordu; dosya başlığı da "ezmez"
  diyordu (yanlış iddia). Gerçek hata. Sultan: devam, son tur (2026-09-30 Sultan: devam (sohbet ·
  session_013fuJSNg65VkgQE4sJsQURS · "Devam, son tur" · beyan:SERDAR)). Düzeltme: kayıt dosyası başına kilit (flock);
  hedef okuma ve yazma tek kilit altında, `ekle` ve `emekli` ikisi de; kilit beklemesi en çok 10 sn (ayarlanır),
  alınamazsa rc 3. Sınav T9c: kilit tutulurken beklemesiz ekle rc 3, kilit düşünce yazar; altı eşzamanlı yazım hepsi
  rc 0 ve tek sağlam kayıt. Mutasyon 36-38. Kilit dosyası dizinde kalır (silmek yeni yarış açar).

## Bu işte ne var
| Parça | Ne |
|---|---|
| `canli-sayfa/scripts/canli-sayfa.sh` | kayıt aracı: `ekle` · `liste` (`--json` menü biçimi) · `emekli` · `dogrula` |
| `canli-sayfa/scripts/canli-sayfa.test.sh` | sınav, sahte kayıt dizini ve sahte ölçerle |

## Bu işte OLMAYAN (ayrı kartlar, sırayla)
0. **Beceri tanımı ve dağıtım kaydı** (`SKILL.md` · `catalog.json` · `sync-targets.json`): kart `canli-sayfa-beceri-kaydi`.
1. **Kurulum.** Birleştikten sonra beceri ortak beceri dizinine kurulur (yalnız bu beceri; toplu kurulum yapılmaz) ve
   kurulu kopya kaynakla karşılaştırılır.
2. **İlk kayıtlar.** Bugün canlı olan sayfalar kurulu araçla kayda yazılır.
3. **Kokpit menüsü.** Veri toplayıcısı kaydı okur (kart `kokpit-canli-sayfalar-veri`, cloudtop, yapım aşamasında);
   ekran "Canlı sayfalar" görünümünü çizer (Nexus, ayrı kart). Menü canlıya çıkınca beceri metnindeki durum notu kalkar (1.1.0).
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
- **Silme komutu yok.** Kalkan sayfa `emekli` olur; kayıt delil olarak kalır. Bozuk kayıt da delildir: araç üstüne yazmaz.

## Kanıt
| Ölçüm | Ne gösterir |
|---|---|
| sınav | sahte ölçerle bütün kapılar |
| mutasyon | aracın bozuk kopyalarının her biri sınavda kırmızı |
| canlı prova | gerçek ağ ölçümüyle, **geçici** kayıt dizininde ve **kaynak** kopyayla (kurulu kopya ve gerçek kayıt kurulum kartının kanıtıdır): üç gerçek sayfa kayda girdi (giriş: kapalı), olmayan adres rc 3, kapısız sayfa rc 4, `dogrula` yeşil |
| depo kapıları | depo denetimi beceri tanımı olmayan bu dizini kabul ediyor (kayıt ve tanım öbür kartta) |
Sayılar ölçüm dosyalarındadır; belgeye sayı yazılmadı (kanıt yeniden üretildiğinde belge bayatlamasın).

## Bilinen sınırlar
- Kuralı uygulatan kilit yok; kayıt yazmayan ajanı araç yakalayamaz.
- Ölçüm aracın koştuğu kutudan yapılır; dışarı çıkamayan kutuda kayıt yapılamaz.
- "Kapalı" ölçümü iki işarete dayanır: giriş kapısının adresine yönlenme ya da 401/403. Başka bir kapı türü
  (ör. sayfanın kendi giriş formu 200 dönerek) "açık" ölçülür ve onay ister; bu yönde hata güvenli taraftadır.
- Başka bir yere yönlenen sayfa (kapı olmayan yönlenme) `yönleniyor` diye kaydedilir; hedefin kapısı ölçülmez.
- Tek cümle denetimi noktalama işaretine bakar: cümle bitiminden (. ! ? ; …) sonra boşluk ve yeni söz varsa reddeder.
  "vb. sonra" gibi kısaltma bitişleri de reddedilir; ondalık sayı ("2.5") ve sondaki nokta geçer.
- Sır deseni kaba bir ağdır (uzun rastgele dizi, "parola=" gibi kalıplar); kısa bir sırrı yakalamaz. Asıl koruma
  alanların dar olmasıdır (ad, tek cümle, adres).
- Kilit aynı kutu içindeki ve aynı dosya sistemini paylaşan kutular arasındaki eşzamanlı yazımı sıralar; ağ dosya sistemi
  üzerinden kilitleme güvencesi ölçülmedi (bugün ortak dizin tek makinede).
- Kayıt dosyaları ortak dizinde düz dosyadır; bir kutu başka kutunun kaydını değiştirebilir. Kimin yazdığı `ekleyen`
  alanındadır ama doğrulanmaz.
