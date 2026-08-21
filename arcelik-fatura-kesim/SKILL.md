---
name: arcelik-fatura-kesim
version: 0.1.0
description: Arçelik'ten gelen fiş/iade/malzeme-iade paketleri için HANGİSİNE fatura kesilir, hangisine KESİLMEZ kararını verir ve kalem eşlemesini kurar. 🔴 EN KRİTİK KURAL - İADE FİŞ PAKETİ'ne fatura KESİLMEZ (kesilirse ZARAR EDİLİR); adı "Malzeme İade" olan mail ise TERSİNE düz fatura olarak kesilir - isim yanıltır, tip belirler. Kesimden önce "daha önce kesildi mi" kontrolü ZORUNLUDUR. Bilinmeyen tip -> KESME, SOR (fail-closed). "Arçelik'ten kesilecek fatura var mı · fiş paketi faturası · hangi paketi keselim · bu mail kesilir mi" tetiğinde ZORUNLU çağrılır.
---

# arcelik-fatura-kesim — hangi pakete fatura kesilir, hangisine KESİLMEZ

**Kademe:** Kalfa · **Doğum:** 2026-08-22, MUHASİP · **Kaynak:** Sultan'ın sözlü kuralları + firsthand ölçüm
**Girdi:** `arcelik-mail-erisim` (paketleri getirir) · **Çıktı hattı:** `elogo-erisim` (belgeyi kurar)

> Sultan'ın talimatı: *"gelen kesmemiz gereken Arçelik'ten fatura var mı diye sorduğumda bu kural
> her zaman hatırlanacak."* Bu dosya o hatırlamanın kendisidir. Soru sorulduğunda **önce burayı oku.**

## 🔴🔴 KURAL 1 — İADE FİŞ PAKETİ'NE FATURA KESİLMEZ

| Mail konusu | Karar |
|---|---|
| `ARCELIK A.S. FIS PAKETI DOKUMU` | ✅ **FATURA KESİLİR** |
| `ARCELIK A.S. IADE PAKETI DOKUMU` | 🔴 **KESİLMEZ — ASLA** |

### KAYNAK (MUAVİN'in haklı itirazı üzerine, 2026-08-22): kural nereden geliyor?
**Kaynak = Sultan, sözlü talimat, 2026-08-22 sohbeti.** Doğrudan alıntı:
> *"iade fiş paketi bizim keseceğimiz bir fatura değildir o yüzden onu ezgeçiyorsun … onu
> kesinlikle almıyorsun **yoksa zarar ederiz** bu çok önemli bir bilgi asla unutmaman lazım"*

**Bu kural ÖLÇÜMLE doğrulanmadı — beyandır.** Ayrımı bilerek yazıyorum: ölçülmüş bir şey gibi
sunmak, MUAVİN'in dediği gibi bir gün *"bu neden böyle?"* sorusuna cevapsız bırakır.
İş gerekçesi (muhtemel): iade paketi bizim **alacağımızı azaltan** bir düzeltmedir, bizim
kestiğimiz bir satış değil — dolayısıyla ona fatura kesmek olmayan bir satışı faturalamaktır.
🔴 **Bu gerekçe MUHASİP'in çıkarımıdır, Sultan'ın beyanı değildir** — mali müşavir teyidi alınmalı.
Teyit gelene kadar **kural aynen yürürlüktedir**: beyan yeterli sebeptir, gerekçe onu güçlendirir.

**Niçin ciddi:** parasal ve geri alınamaz.
"Kesilecek fatura var mı?" sorusuna verilen cevaba iade paketi **KARIŞTIRILAMAZ** — sayıya da girmez.

## 🔴 KURAL 2 — İSİM YANILTIR, TİP BELİRLER

**`Malzeme İade`** başlıklı mail → adında "iade" geçer ama **DÜZ FATURA olarak KESİLİR.**
Kural 1'deki "iade" yasağı **yalnız `IADE PAKETI DOKUMU`** içindir.

⚠️ Bu iki kural birbirinin tuzağıdır. Naif bir "iade" kelime araması **iki yönde de yanılır**:
iade paketini kesip zarar ettirir, ya da malzeme iadesini atlayıp fatura kaçırır.
**Karar konunun TİPİNE göre verilir, içinde geçen kelimeye göre DEĞİL.**

## Tip tablosu — tanınan her şey

| Tip | Konu deseni | Karar | Not |
|---|---|---|---|
| **fiş paketi** | `FIS PAKETI DOKUMU` | ✅ KES | asıl iş; genelde perşembe 1–2 adet |
| **iade paketi** | `IADE PAKETI DOKUMU` | 🔴 **KESME** | genelde perşembe 1 adet; zarar sebebi |
| **malzeme iade** | `Malzeme İade` | ✅ KES (düz fatura) | isim tuzağı — Kural 2 |
| **BİZ ödül puan** | ödül/puan içerikli | ⏸ **KURAL YOK → SOR** | Sultan "aklında olsun" dedi, karar vermedi |
| **uyarı maili** | `Düzenlenmeyen`, `Hatırlatma` | ⏭ atla | fatura değil, hatırlatma |
| **fatura talebi** | `fatura talebi` | ⏸ SOR | ayrı akış olabilir |
| **tanınmayan** | — | 🔴 **KESME, SOR** | fail-closed |

### Fail-closed değişmezi
Tip **kesin** tanınmıyorsa fatura **KESİLMEZ** ve Sultan'a sorulur. Bir faturayı geç kesmek
telafi edilebilir; **yanlış kesmek edilemez.** "Muhtemelen fiş paketidir" YASAK.

## 🔴 KURAL 3 — KESMEDEN ÖNCE "DAHA ÖNCE KESİLDİ Mİ" (zorunlu, iki katman)

Sultan: *"Bir faturayı kesmeden önce daha önce kesildi mi diye kontrol etmek şart."*
Çift kesim = çift vergi + düzeltme yükü. **İki bağımsız katman, ikisi de yeşil olmalı:**
1. **Yerel kesim defteri** — `kesim-defteri.jsonl` (bu skill tutar): SAP Belge No → fatura no.
   SAP Belge No **birincil anahtardır**; tarih/tutar değil (aynı gün iki paket gelebilir — ölçüldü).
2. **e-Logo'da giden fatura sorgusu** — defter kaybolursa/bayatlarsa tek kanıt kalmasın diye.
Biri bile "kesilmiş" diyorsa → **KESME**, Sultan'a bildir.

⚠️ **Aynı gün, aynı dakika iki ayrı paket gelebilir** — ölçüldü (20.08.2026, iki paket, ardışık
SAP no). Tarihe göre tekilleştirme **YANLIŞ**: birini yutar. Anahtar SAP Belge No'dur.

## Kesim durumu — ÇİZGİ (2026-08-22, Sultan beyanı)
- **20.08.2026 öncesi tüm paketler: KESİLDİ.**
- **20.08.2026 tarihli iki fiş paketi: KESİLMEDİ** → sıradaki iş.
- Bundan sonrası MUHASİP'in: kesimi de takibi de.

## Kalem eşlemesi — Özet HTML → e-Fatura (kuruşu kuruşuna doğrulandı)

Kaynak: paket mailinin `<SAP>_Ozet.html` eki. Fatura **4 kalem** taşır; her kalem **Miktar 1,0**,
**KDV %20**, **iskonto 0,00**.

| Fatura kalemi | Özet satırı | Birim fiyat = |
|---|---|---|
| Malzeme | `Malzeme(kdv20)` | **Net** sütunu |
| Nakliye | `Nakliye` | **Net** sütunu |
| İşçilik | `İşçilik(kdv20)` | **Net** sütunu |
| Yan Ödeme | `Yan Ödeme` | **Net** sütunu |

🔴 **Birim fiyat = Net sütunu** (indirim sonrası, KDV hariç). *Brüt* ya da *İndirilmiş Brüt*
DEĞİL. İndirim faturaya **iskonto olarak girilmez** — Net zaten indirilmiştir; girilirse
indirim iki kez düşer.
**Kanıt:** her kalemde `Net × 0,20` = Özet'in `KDV20` sütunu ve örnek faturanın KDV'si —
iki pakette ve örnek faturada 11 kalemin 11'i tuttu.
**Sıfır satır kalem açılmaz** (ölçüldü: bir pakette Yan Ödeme 0,00 → 3 kalem).
**KDV10 satırları bugüne dek hep 0,00** — sıfırdan farklı çıkarsa **DUR ve SOR**, tek orana indirgeme yanlış fatura üretir.

### Fatura başlığı (örnek faturadan sabitler)
`Senaryo: TICARIFATURA` · `Fatura Tipi: SATIS` · `Özelleştirme No: TR1.2` ·
Fatura No deseni: `<SERİ><yıl><9 hane>` (örn. seri `FGF`). Alıcı **Arçelik Pazarlama A.Ş.**,
satıcı yetkili servis — **VKN/unvan/adres bu dosyada TUTULMAZ**, kutu-yerel türevde ya da kasada
yaşar (ortak raf = 16 kutu, İ1). *Test: "bu satır ikinci bir tüzel kişide de aynı mı kalır?"*

### Kesim öncesi zorunlu üç çapraz-kontrol (Özet'in kendi aritmetiği)
`brüt − indirim = indirilmiş brüt` · `net + KDV = indirilmiş brüt` · `Σbrüt = Genel`
Biri tutmuyorsa ek bozuk ya da ayrıştırma yanlış → **KESME.**

## Ritim — ne zaman bakılır
Genellikle **perşembe**: 1–2 fiş paketi + 1 iade paketi. Ritim bir **beklenti**dir, kural değil:
"perşembe geldi, demek paket vardır" varsayma; **her zaman ölç.** Paket gelmediyse bu bir ölçümdür.

## Sorulduğunda ne cevaplanır
"Arçelik'ten kesilecek fatura var mı?" → maili tara, tiplere ayır, **kesim defterini kontrol et**, sonra:
- kesilecekler: adet + SAP Belge No + tutar
- **iade paketleri AYRI satırda, "kesilmez" etiketiyle** (sayıya karıştırma — Kural 1)
- tanınmayan/kural-yok olanlar: "SOR" listesi
Ölçemediğine **"yok" deme, "ölçemedim" de.**

## Kullanım

```bash
# "Arçelik'ten kesilecek fatura var mı?" — tek komutluk cevap
python3 scripts/tara.py [taranacak_mesaj_sayısı]     # varsayılan 60

# çift-kesim kalkanı (Kural 3, yerel katman)
bash scripts/defter.sh sor <SAP_BELGE_NO>            # RC0=kesilmemiş · RC1=KESİLMİŞ, DUR
bash scripts/defter.sh yaz <SAP> <FATURA_NO> [tutar] # kesim sonrası işle (üzerine yazmaz)
```
`tara.py` çıktısı dört kümedir: **KESİLECEK** (defterden geçmiş) · **KESİLMEZ** (iade paketleri,
sayıya dahil değil) · **SOR** (fatura/para kokulu ama kuralı olmayan) · ilgisiz (sayı olarak).
`ARCELIK_KESIM_CIZGISI` (varsayılan `2026-08-20`) öncesi paketler Sultan beyanıyla kesilmiş
sayılır ve ayrı satırda **beyan olduğu belirtilerek** raporlanır — sessizce yutulmaz.

### Kanıt — bu skill kendi kuralını gerçekten uyguluyor mu (2026-08-22 firsthand)
7 vakalık tip sınavı **7/7 geçti**; kritik ikisi: `IADE PAKETI DOKUMU → KESME` ve
`Malzeme İade → KES` (isim tuzağına düşmedi). Çift-kesim kalkanı mutasyonla sınandı:
kesilmiş kayda `sor` **RC=1** verdi, `yaz` üzerine yazmayı **reddetti**.
Canlı tarama: 40 mesaj → **2 kesilecek** (20.08.2026) · 6 iade (kesilmez) · 10 sor · 3 çizgi altı.

## Negatif kapsam
Numara atama ve **gönderim MUHASİP'in eli DEĞİL** — Sultan'ın. Bu skill belgeyi **kurar, provasını
geçer ve DURUR**. Canlı ortam (`--canli`) ve `--gercekten-gonder` bu skill'e kapalıdır.
Mail'e yazma fiili yok. Tüzel kişi kimlik bilgisi bu dosyada tutulmaz.
