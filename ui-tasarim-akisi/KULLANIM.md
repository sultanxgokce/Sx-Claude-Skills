# Bunu yeni buldun — ne yapacaksın

*Bu dosya, metodu ilk kez görecek bir yardımcı için yazıldı. `SKILL.md` metodun kendisidir;
bu dosya ona nasıl başlanacağını anlatır.*

---

## Bu ne işe yarar

Bir ürünün **birden çok ekranını** tasarlatmak için. Tek ekran tasarlatmak kolaydır; zor olan
ikinci ekranın birinciye benzemesidir. Bu akış onu garanti eder ve **grep'lenebilir** biçimde
kanıtlar.

Tasarım Claude design'da üretilir. Bu metot oraya gidecek promptu kurar — tasarımı kendisi
üretmez.

## Ne zaman açılır, ne zaman açılmaz

| Aç | Açma |
|---|---|
| İki ya da daha çok ekran tasarlanacak | Tek ekranlık iş — ağır gelir |
| Ekranlar aynı ürünün parçası, birbirine benzemeli | Birbirinden bağımsız tek seferlik sayfalar |
| Ürünün ne olduğu ve kimin kullanacağı biliniyor | Ürün henüz belirsiz — önce o konuşulur |

## Nerede duruyor

| Katman | Yol | Kim görür |
|---|---|---|
| Canlı ortak raf | `/config/.claude/skills/ui-tasarim-akisi/` | **her kutu** |
| Kutu-yerel raf | `<proje>/.claude/skills/ui-tasarim-akisi/` | yalnız o kutu |

Ortak rafta görüyorsan dağıtım yapılmış demektir; doğrudan kullan. **Ortak rafa elle dosya
koyma** — orası dağıtımın vardığı yer, girdiği yer değil; elle konan ilk senkronda silinir.

## Beş adımda kullanım

### 1 · Envanteri çıkar

`sablonlar/sayfa-envanteri.md` şablonunu doldur.

En kritik karar burada: **ekran sayısı ≠ sayfa sayısı.** Her kalem sayfa mı, panel mi, sekme mi,
akış mı, görünüm mü — baştan yaz. Yazmazsan sonradan her şey ayrı sayfa olur ve ürün şişer.

> Gerçek örnek: bir üründe on altı ekran çıktı ama gezinme üç kalemdi. "Form bir paneldir,
> listenin üstüne açılır" satırı yazıldığı için o iki ekran **tek koşuda** üretildi — bir tur
> kazandırdı.

Açılış ekranı için ayrı bir gösterge paneli **icat etme.** Önce "kullanıcı sıfır tıkla neyi
görmeli" sorularını yaz; çoğu zaman cevapları zaten var olan bir ekrandan okunur.

### 2 · Senaryoları yaz

Her ekran için `sablonlar/senaryo-karti.md` kalıbıyla bir kart.

**`Tık bütçesi:` satırı boş bırakılamaz.** Ölçülebilir tek kalite göstergesi budur. Sayım kuralı
şablonun içinde, tek yerde tanımlı — herkesin aynı şeyi sayması için.

Her kartta **"ne çizilmez"** listesi olsun. Modele ne yapacağını söylemek yetmez; yasakları
yazmazsan alışıldık deseni ekler.

### 3 · Sözleşme ve estetik yönü kur

- `sablonlar/tasarim-dili.md` → **ne kullanılacak**: renkler, kademeler, bileşen sözlüğü.
  Kontrastı **ölç**, tahmin etme.
- `sablonlar/estetik-yon.md` → **neye benzeyecek**: karakter, imza öğesi, hangi hazır kalıba
  düşülmeyeceği.

İkincisi atlanırsa sözleşmeye uyan ama ruhsuz, birbirinin kopyası ekranlar çıkar.

> Gerçek örnek: seçilen palet, yapay zekâ tasarımının en yaygın varsayılanına çok yakındı.
> Palet sahibinin bilinçli seçimiydi, tartışılmadı — ama onunla gelen refleks açıkça reddedildi:
> *"serif başlık yok, dergi düzeni yok, sıcaklık zeminde kalır jestte değil."* Bu satır
> yazılmasaydı model editöryel bir açılış sayfası çizerdi; oysa ürün günde onlarca kez açılan
> bir çalışma aracıydı.

### 4 · İlk sayfayı üret

`sablonlar/tasarim-promptu.md`'den kopya çıkar, yuvaları doldur, promptu üret:

```bash
arac/prompt-yap.sh <kopyan.md> --dil <sözleşmen.md> --estetik <estetik-yönün.md>
```

Çıkan metni Claude design'a ver. Çıkan tasarımı **depoya indir**.

**İlk sayfa dili kurar; en zengin ekranı seç.** İskelet, gezinme, kart dili orada doğar. Giriş/
oturum ekranını en sona bırak — dili kurmaz, yalnız tüketir.

### 5 · Sonraki sayfalar

`sablonlar/devam-promptu.md`'den kopya çıkar, senaryoyu doldur:

```bash
arac/prompt-yap.sh <kopyan.md> --onceki <önceki-sayfa> --dil <...> --estetik <...>
```

**Zincir kilitlidir:** önceki sayfa yoksa araç `exit=2` verip durur. Sessizce eksik prompt
üretmez.

---

## Her sayfadan sonra üç denetim — atlanmaz

**1 · Bileşen tutarlılığı**
```bash
grep -o 'bilesen: [A-Za-zğüşıöçĞÜŞİÖÇ]*' <yeni-sayfa> | sort -u
```
Sözlükte olmayan ad var mı? Öncekinin bileşenleri devralınmış mı?

Model yeni bir ad gerektiğini **bildirirse** bu hata değildir — sözleşmeye ekle ve değişiklik
günlüğüne gerekçesini yaz. **Sessizce icat edilen ad** hatadır.

**2 · Kısıt denetimi** — ürünün kendi yasakları çiğnenmiş mi. Çizilmemesi gereken alan, alan
sayısı, gösterilmemesi gereken bilgi.

**3 · Tık sayımı** — senaryodaki hedef tutmuş mu. **Aşım sessiz geçilmez:** ya tasarım revize
edilir ya hedef gerekçeyle güncellenir.

Her denetimin **çıktısını göster**. "Uyumlu" beyanı kanıt değildir.

---

## Bilinmesi gereken üç davranış

**Platform ilk çıktıdan sonra kendini rafine ediyor.** İlk çektiğin dosya son sürüm olmayabilir.
Çıktıyı yeniden çek ve karşılaştır — "bitti mi" diye sormaktan hızlıdır.

**Çıktı biçimi platformun kendi biçimidir.** "Tek bağımsız HTML" isteyip bileşen dosyası almak
aykırılık değil, doğal davranış. Denetimleri buna göre yaz.

**Erişim sorunu ayrı bir iştir.** Platforma bağlanamamak metodu bozmaz: promptlar elle
yapıştırılır, akış aynen çalışır. Bu ikisini birbirine karıştırmak zaman kaybıdır.

---

## Değişmezler

- Tasarım **Claude design'da** üretilir; bu metot promptu kurar.
- **Sözleşme ilk sayfadan sonra dondurulur.** Yalnız ekleme yapılır. Renk/tipografi/iskelet
  değişirse önceki sayfalar bayatlar.
- **Yarım özellik çizilmez.** Veri modelinde olmayan alan tasarımda görünmez.
- **Kısıt estetiği yener.** Çatışmada ürünün kabul kriterleri kazanır.
- **Kanıtsız bitti yok** — ve **kanıtsız kırmızı da yok**: bir yolun kapalı olduğu, denenmeden
  ilan edilmez.

## Bir tam örnek

`ornek/ilk-kullanim.md` — metodun ilk kullanıldığı iş, ölçülmüş çıktılarıyla. Dört ekran üç
koşuda çıktı; ne işe yaradığı ve neyin zaman kaybı olduğu dürüstçe yazılı.
