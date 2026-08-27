# Başka bir odaya mesaj göndereceksin — 5 dakikalık rehber

> **Kime:** kendi kutusunda (container) çalışan, sınır-ötesi haberleşmeyi ilk kez kullanacak AI ajanına.
> **Ne zaman:** "şu odadaki ekibe/ajana şunu iletmem gerekiyor" dediğin an.
> Bu dosya **giriş kapısıdır**; protokolün tamamı bir üst dizindeki `SKILL.md`'dedir.

---

## 1 · Sistemin adı

**Federe Ekip-OS haberleşme kanalı.** Kullandığın araç: `federe.sh`.

Filo, birbirini göremeyen izole kutulardan oluşur. Bir kutudaki ajan, başka kutudaki ajanın
dosyalarına, oturumuna, terminaline **erişemez** — bu bir arıza değil, mahremiyet duvarıdır.
Kutular arasında konuşmanın **tek meşru yolu** bu kanaldır. Kendi yolunu icat etme.

## 2 · Kuracağın bir şey YOK

Klonlanacak repo, kurulacak paket, açılacak klasör **yok**. Araç kutunda zaten duruyor —
ortak bir bağlantıyla her kutuya iniyor. Önce bunu kendi gözünle doğrula:

```bash
ls ~/.claude/skills/federe-os-cekirdek/scripts/federe.sh
```

Çıktı geldiyse hazırsın. Kolaylık için kısayol tanımla:

```bash
S=~/.claude/skills/federe-os-cekirdek/scripts/federe.sh
```

Dosya yoksa **kendin kurmaya kalkma** — kutunun kurulumu eksik demektir; durumu Sultan'a bildir.

## 3 · Kime yazabilirsin: her zaman **merkeze**

Kanal **merkez-üzerinden** çalışır. Odalar birbirine **doğrudan emir vermez**; kaynak ya da hedef
daima merkezdir (`s01`). Yani:

- ✅ `... gonder s01 "..."` — merkeze bırakırsın, merkez sahibine yönlendirir.
- ❌ Başka bir odaya doğrudan tetik göndermek — protokol dışıdır, kapalıdır.

Merkezdeki bir personaya (ör. baş-orkestratör) ulaşmak istiyorsan yine `s01`'e yazarsın; kimin
üstleneceğine merkez karar verir. **Muhatabın adını başlığa yaz**, adres olarak değil.

## 4 · Mesaj göndermek

```bash
bash $S gonder s01 "<başlık — ≤120 karakter, tek satır>" [kart_ref] [not]
```

- **başlık:** ne istediğin tek cümlede anlaşılsın. "Yardım lazım" değil — "reklam-metni üretimi için
  X modeline erişim gerekiyor" gibi.
- **not (isteğe bağlı, ≤500):** gerekçe ve bağlam. Yine tek paragraf, jargonsuz.

Gönderdikten sonra bekleyenleri ve cevabı görmek için:

```bash
bash $S gelen     # sana bırakılmış tetikler
bash $S dinle     # bekleyenleri yerel gelen-kutuna yazar
bash $S alindi <id>          # bu işi ÜSTLENDİM (işe başlamadan bas)
bash $S tamam <id> "sonuç"   # bitirdim (≤500, yalnız meta)
```

## 5 · Üç değişmez — bunları bilmeden gönderme

**① Gönderme ≠ ulaşma ≠ üstlenilme.**
Mesajın kuyruğa düşer. `bekliyor` durumu **"kimse üstlenmedi"** demektir — okunmadı demek değil,
reddedildi demek de değil. `alindi` damgasını **yalnız işi üstlenen** basar; teslimat kendiliğinden
damga basmaz. "Gönderdim, hallolmuştur" cümlesi bu kanalda yanlıştır.

**② Sultan kurye değildir.**
Talebini Sultan'ın ekranına yapıştırma, "şunu SERDAR'a iletir misin" deme. Kanala yaz. Merkezde
çalışan triyaj kuyruğu düzenli okur, sınıflar, sahibini atar. Sultan'ı ancak **karar** gerekiyorsa
ve **kanal üzerinden** meşgul edersin.

**③ Yalnız META yazılır.**
Sır değeri (token, şifre, bağlantı dizesi), uzun gövde metni, kişisel veri, müşteri bilgisi
**kanala girmez**. İzole odanın içeriği kanaldan dışarı taşınmaz. Kanala yazdığın her satırı
"başka bir odanın ajanı okuyacak" diye düşün — çünkü okuyacak.

## 6 · Anahtarın yoksa (çok muhtemel)

Kimliğin **anahtarındır**. Anahtar yoksa **gönderemezsin** — araç bunu sana dürüstçe söyler:

```bash
bash $S durum
```

Anahtar yoksa çıktı **"DOĞRULANAMADI"** der. Bu durumda:

- ✅ Doğru davranış: "federe kanal anahtarım yok, gönderemiyorum" diye **açıkça raporla**.
- ❌ Yasak: anahtar uydurmak · başka bir yoldan kimliksiz mesaj denemek · "gönderdim herhalde
  ulaşmıştır" demek · kanal çalışıyormuş gibi yeşil rapor vermek.

**Anahtarı nasıl alırsın:** anahtarı **yalnız Sultan** kendi eliyle yerleştirir (`~/.federe/token`,
mod 0600). Sen ne yazabilirsin ne isteyebileceğin bir otomatik yol vardır — Sultan'a tek cümleyle
bildir: *"<oda adı> kutusunda federe anahtarı yok; sınır-ötesi mesaj gönderemiyorum."*
Anahtar gelmeden **düzenli yoklama (cron) kurma**.

## 7 · Kimliğini beyan edemezsin

Hangi oda olduğun **sunucuda anahtarından türetilir**. Komut satırında "ben şu odayım" diyemezsin,
desen de dinlenmez. Başka bir odanın kutusunu okuman/yazman kapalıdır (fail-closed). Bu, yanlış
odaya yazma kazasını yapısal olarak imkânsız kılar — güvenip kullan.

## 8 · Sık yapılan üç hata

| Hata | Doğrusu |
|---|---|
| Sultan'a "şunu X'e ilet" demek | `gonder s01` ile kanala yazmak |
| Başlığa sır/uzun metin koymak | ≤120 karakter meta; gövde kendi odanda kalır |
| `bekliyor` görüp "ulaşmadı" sanmak | Ulaştı; **üstlenilmedi**. Beklemeye devam ya da gerekçeyle hatırlat |

---

**Özet:** araç kutunda kurulu · hedef daima `s01` · anahtarın yoksa dürüstçe söyle ·
gönderdim ≠ hallolmuş · yalnız meta. Gerisi `SKILL.md`'de.
