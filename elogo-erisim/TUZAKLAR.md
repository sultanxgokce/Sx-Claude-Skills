# e-Logo — ÖLÇÜLMÜŞ TUZAKLAR

> **Bu dosya niçin var:** 2026-08-21/22 gecesinde e-Logo hattı sıfırdan kuruldu. Karşılaşılan
> her engel **ölçülerek** çözüldü; hiçbiri tahmin değil. Aşağıdakiler o gecenin bedelidir.
> Yeni bir ajan bu yeteneği aldığında **önce burayı okur** — aynı duvarlara yeniden çarpmasın.
>
> 🔴 **ŞİRKETSİZ:** burada firma adı, VKN, cari, adres, kimlik GEÇMEZ. Bu dosya 16 kutunun
> ortak gördüğü raftadır. Şirkete özel her şey kutu-yerel türevde yaşar.
>
> **Ekleme kuralı:** her satır ya ölçülmüştür ya kaynaklıdır. "Muhtemelen" yazma.

---

## 1 · SOAP'ın üç değişmezi — yanlışı KİMLİK HATASI gibi görünür

| # | tuzak | belirti | doğrusu |
|---|---|---|---|
| 1 | `Login` sarmalayıcısı `tempuri`de ama **alt alanlar başka ad-alanında** | *"Hatalı kullanıcı adı veya şifre"* | alt alanlar `…/eFaturaWebService` |
| 2 | Alan sırası | aynı hata | alfabetik: `appStr · passWord · source · userName · version` (appStr/source/version BOŞ) |
| 3 | Varsayılan Python `User-Agent` | **403 · error code 1010** | tarayıcı-benzeri UA şart (Cloudflare bot engeli) |

🔴 İlk ikisi **kimlik hatası gibi görünür** ve insanı şifre avına çıkarır. Şifreyi suçlamadan
önce zarfı kontrol et. (Bu gece tam bu yüzden bir saat kaybedildi.)

**Metot adı:** `CheckGibUser` — küçük `b`. Üreticinin **kendi belgesi tutarsız**
(`CheckGIBUser` 2, `CheckGibUser` 5 kez). Otorite **WSDL**'dir; yanlış ad sessizce fault verir.

---

## 2 · Belgede olması ZORUNLU dört şey (hepsi reddedilerek öğrenildi)

Gönderim denemesi altı kez reddedildi; her ret bir sonrakini söyledi:

| # | e-Logo'nun cevabı | eksik olan |
|---|---|---|
| 1 | "e-Belge görsel tasarım içermelidir." | XSLT parametresi yok |
| 2 | "Kayıtlı müşterinin tanımlı xslt bilgisine ulaşılamadı." | hesapta tasarım yok → **belgeye göm** |
| 3 | "'IssueDate' … expected: 'CopyIndicator'" | `cbc:CopyIndicator` + **`cbc:UUID` (ETTN)** |
| 4 | "'TaxTotal' has incomplete content … 'TaxSubtotal'" | belge düzeyinde **oran-bazlı KDV dökümü** |
| 5 | "Numara (cbc:ID) … 16 karakter olmalıdır" | numara boş bırakılamaz |
| 6 | — | ✅ Başarılı |

**UBL eleman sırası KATIDIR:** `ID → CopyIndicator → UUID → IssueDate`. Sıra bozulursa hata
*içerikte* aranır; oysa sebep sıradadır.

**Paketleme:** UBL doğrudan gitmez → **zip → base64 → MD5**.
🔴 MD5 **zip'in ham baytları** üstünde alınır, base64 metni üstünde DEĞİL. Ve **MD5**'tir, SHA değil.

---

## 3 · İki gönderim yolu — numara kuralları FARKLI

| yol | çağrı | numarayı kim verir |
|---|---|---|
| Taslak | `SendDraftDocument` | **e-Logo** (portaldeki "sıra numarası ver") |
| Doğrudan | `SendDocument` | **DÜZENLEYEN — yani biz** |

Doğrudan gönderimde `cbc:ID` **boş bırakılamaz**: 16 karakter = 3 serbest + 4 yıl + 9 rakam
(`ABC2026000000001`).

🔴 **"Taslak OLUŞTUR" diye bir çağrı YOKTUR.** Ölçüldü: `SendDocument` + `DOCUMENTTYPE=DRAFTINVOICE`
→ **`BadRequest (Geçersiz docType parametresi)`**. Belgede `DRAFTINVOICE` üç yerde geçer, üçü de
okuma/gönderme tarafıdır. **Taslak portalde doğar.**

🔴 **Numara sorumluluğu:** doğrudan gönderimde numarayı biz ürettiğimiz için **mükerrer numara
riski gerçektir** (portalden elle kesilenlerle çakışma). Portal-yükleme yolunda `cbc:ID` boş
kalır → risk **yapısal olarak yok**. Yolu seçerken bunu bil.

---

## 4 · Tarayıcı otomasyonu — İKİ SESSİZ TUZAK

Logo yüzeyleri **Vaadin/Polymer** ile yazılmış. İki farklı yüzeyde aynı duvar:

| belirti | gerçek sebep | parmak izi |
|---|---|---|
| öğe var ama tıklanamıyor, `inner_text` boş | **font yok** → yükseklik 0 → her şey "gizli" sayılır | `height == 0` |
| `button` araması boş dönüyor, sayfa dolu | **özel bileşen** (`<logo-elements-button>`) | sayfa dolu + arama boş |

🔴 **İkisi de hata mesajı VERMEZ.** Otomasyon sebepsiz başarısız olur, insan "portal değişmiş"
sanır ve yanlış yerde saatler harcar.

**Kural:** öğe adını **varsayma, ölç**. Ve üretilmiş `id`'lere güvenme — `…text-field-7` gibi
sıraya bağlı kimlikler render sırası değişince **başka alanı tutar**; `name`/`placeholder` ile sabitle.

---

## 5 · Portalın İKİ giriş yolu var

Varsayılan sayfa **e-posta** ister. Ama e-Logo'nun verdiği kimlik bir **FİRMA KODU**dur
(belgede "kullanıcı adı" diye geçse de). Doğru giriş şu bağlantının arkasındadır:

> *"Firma Kodu veya Kullanıcı Kodu ile mi giriş yapıyorsunuz? Buraya tıklayınız"*

Açılan sayfada iki sekme: **Ana Hesap** (Firma Kodu + Şifre) · **Kullanıcı**.
→ Varsayılan e-posta formu **yanlış kapıdır**.
→ Kimliği `..._EMAIL` diye adlandırma; içinde firma kodu durur, sonraki okuyan yanılır.

---

## 6 · Kontör ve yetki

- **Kontör servisten SORULAMAZ** (69 operasyon tarandı, 0 eşleşme). Portal/sözleşme işidir.
- Sözleşme §7.7: **kontör bitince belge ALINIR ama GÖNDERİLEMEZ.**
- Kontör **firma (VKN) düzeyindedir**, kullanıcı başına değil.

---

## 7 · Ortam ayrımı — demo ⟂ canlı

Kimlikler ayrı yaşar: `ELOGO_WS_*` (canlı) ⟂ `ELOGO_DEMO_WS_*` (demo).

🔴 **Ortam kilidi:** `~/.config/elogo-ortam` (tek kelime `demo`|`canli`). Kilit `demo` iken canlı
çağrı **reddedilir** (rc=6).
**Sessizce demoya DÜŞÜRMEZ** — o da tehlikeli olurdu: canlı sandığın faturayı demoya gönderir
ve gönderdiğini sanırsın. **İki yön de sessiz olmamalı.**

⚠️ Kilit servis tarafında işler; tarayıcı otomasyonu **ayrıca** ona bakmalıdır.
Risk asimetrisi: serviste yanlış ortam **hata kodu döndürür**, panelde "Gönder"de **dönmez.**

---

## 8 · Genel dersler (bu hatta öğrenildi, her yere uyar)

| ders | nereden çıktı |
|---|---|
| **Dağıtıldı ≠ etkin** | "13 kutuya kuruldu" denmişti; doğrusu "başlatma betiğine eklendi" — o betik konteyner açılışında koşar, yeniden başlamamış kutuda kurulum YOK |
| **Değer doğru ≠ değere ulaşılabiliyor** | prod veritabanı adresi doğruydu ama **iç ağ** adresiydi; kutudan çözülmüyordu |
| **Kayıt varken ölçmeye başlama** | "kasada yazma komutu yok" denmişti; komut vardı ve defterde damgalıydı |
| **Komutu vermeden önce çalıştığını ölç** | çıplak `vault-cek` çağrısı o kutuda `PATH`'te yoktu |
| **Gönderildi ≠ ulaştı** | servis "Başarılı" der; belgenin panelde durduğunu ancak **panele bakan** söyleyebilir |
| **Önce küçük olanı dene** | 1,7 milyonluk belgeyi ilk deneme yapma; aynı şablondan üretilmiş küçüğü önce yükle |

---

## 9 · Kaynaklar
- Kanonik bilgi (şirket verisi dahil, merkezde): `Nexus/_agents/bilgi/elogo-entegrasyon-bilgisi.md`
- Üretici belgesi + aranabilir metni: `Nexus/_agents/bilgi/kaynak/`
- Bu yeteneğin kullanımı: `SKILL.md`
