---
name: maas-kapisi
type: agent
version: 0.1.0
description: >
  Aylık maaş ödemesinin önündeki makine kapısı. Muhasebeciden gelen BORDRO (PDF) ile Garanti
  Bankası MAAŞ YÜKLE dosyasını (TGB xlsx) kişi kişi, kuruşu kuruşuna karşılaştırır; fark varsa
  onay akışını DURDURUR. Temizse WhatsApp "BORDRO & MAAŞ" grubuna standart onay metnini üretir,
  bankaya gidecek e-posta taslağını hazırlar. Her ayın her dosyasını sha256'lı, geri-getirilebilir
  arşive alır. "bordro kontrol", "maaş dosyası karşılaştır", "şu ayın bordrosunu getir" tetiğinde.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [maas, bordro, garanti, puantaj, arsiv, kvkk, kapi]
status: v0.1-pilot
---

# maas-kapisi — bordro ↔ banka maaş dosyası kapısı

**NE-DİR:** Para hareketi başlatan bir zincirin önündeki tek makine kontrolü. Bugüne kadar
bordro ile banka dosyası **gözle** karşılaştırılıyordu; ilk koşuda 41 sayfalık Temmuz
bordrosunda **7.000 TL'lik tek-hane hatası** ve **kişi sayısı çelişkisi** çıktı.

**DEĞİŞMEZ:** Sessiz-yanlış yasak. Bir alan okunamıyorsa, bir sayfa ayrıştırılamıyorsa,
bir beyan hesaplanmamışsa → **KIRMIZI**. "Muhtemelen sorun yok" diye geçmez.

## Komutlar

```bash
MK=/config/.claude/skills/maas-kapisi/scripts/mk.sh

bash $MK al 2026-07 <dosya...>     # sınıfla (İÇERİKTEN) + NFC-normalize + sha256 + arşivle
bash $MK kontrol 2026-07           # karşılaştırma motoru → rapor (md+json). çıkış 2 = KIRMIZI
bash $MK ozet 2026-07              # gruba gidecek standart onay metni (KIRMIZI ise üretmez)
bash $MK istisna 2026-07 <kod> "<kisi>" "<gerekce>"   # Sultan-onaylı meşru sapma
bash $MK bildir 2026-07            # onay metnini üretir (gruba YAZMAZ)
bash $MK bildir 2026-07 --merkeze  # metni merkeze (s01) bırakır — gruba MERKEZ basar
bash $MK mail-taslak 2026-07       # banka e-postasının içeriği (GÖNDERMEZ)
bash $MK teyit 2026-07 --metin-dosya <banka-mail.txt> [--kanit <ss.png>]
                                   # bankanın ALDIĞI dosya, kontrolden GEÇEN dosya mı?
bash $MK yedekle 2026-07           # ayın arşivini pCloud'a aynala
bash $MK getir 2026-07 [tur]       # arşivden dosya + sha256 doğrulaması
bash $MK durum                     # tüm aylar envanteri
```

Türler: `bordro` · `maas-yukle` · `puantaj` · `pdks`.
Çıkış kodları: `0` temiz · `1` eksik/bulunamadı · `2` KIRMIZI ya da kullanım hatası.

## Akış (kim neyi açar)

```
1. dosyalar WhatsApp grubuna düşer → indirilir → al
2. kontrol   → KIRMIZI ise DUR, Sultan'a bildir
   (meşru sapma varsa → istisna ... → kontrol yeniden)
3. bildir    → onay metni üretilir
4. bildir --merkeze → metin s01'e bırakılır, GRUBA MERKEZ BASAR
5. Fahri Bey gruptan onay yazar                     [insan kapısı]
6. mail-taslak → içerik üretilir
7. Sultan fahrigokce@gmail.com'dan GÖNDERİR         [para talimatı = insanda]
8. teyit     → banka teyit e-postası gelince ay KAPANIR
```

**8. adım niye var:** 7'den sonra zincir KOPUYORDU. Doğrulama arşivdeki dosyaya bakıyor,
gönderim ise insanın elindeki dosyaya — ikisinin aynı olduğunu kimse ölçmüyordu. Yanlış/eski
bir kopya eklense sistem hiçbir şey demezdi. `teyit` bankanın bildirdiği ad+boyut+kurum kodunu
arşivdeki doğrulanmış dosyayla ve **gönderen hesabı** `MAAS_GONDERICI` ile karşılaştırır.
⚖️ Dürüst sınır: banka özet (hash) vermiyor → bu **güçlü tutarlılık kanıtıdır, mutlak kimlik
ispatı değildir**; raporda da böyle yazar.

🔒 **Bu skill'de `send` çağrısı YOKTUR ve eklenmeyecektir.**
🔒 **Gruba doğrudan yazma yolu da YOKTUR** (s01 talimatı 2026-08-07): "BORDRO & MAAŞ" maaş
ödemesini tetikleyen insan-onay kapısıdır; yetki bir kutuya verilirse o kutudaki **her ajan ve
her cron** para zincirine metin düşürebilir. mmex'in geçit izni bilerek yalnız "Sultan"dır —
`403 alici_bu_kutuya_kapali` bir arıza **değil**, sistemin çalışmasıdır.
⛔ Gruba deneme mesajı atmak, grup adresini bulup yapıştırmak, ikinci WhatsApp oturumu açmak
YASAK (geçit `adres_yasak_bu_kutuda` ile reddeder ve "baypas denemesi" olarak kaydeder).

## Kapılar

**Bordro PDF (fail-closed):** sayfa başına bir kişi; net tutar **iki bağımsız yolla** çıkarılır —
(A) `Net Kazanç` ankraji, (B) kayıt devam satırının son parasal alanı. Uyuşmazsa o sayfa KIRMIZI.
Ayrıca PDF'in kendi **TOPLAM** satırı kişilerin toplamıyla karşılaştırılır (üçüncü bağımsız kapı).

**Kırmızı:** tutar farkı (kuruş) · bankada var/bordroda yok · `Σ Tutar ≠ Toplam Tutar` ·
`satır ≠ Toplam Adet` · **beyan alanı formül ve hesaplanmamış** · sıfır/negatif tutar ·
tekrarlanan TCKN · tekrarlanan hesap no · `Ödeme Tipi ≠ M` · tarih biçimi/geçmiş tarih ·
PDF çapraz-doğrulaması kırık.

**Sarı:** bordroda var/bankada yok (`MAAS_EKSIK_KISI=kirmizi` ile sertleştirilir) ·
aynı TCKN'de ad yazım farkı · döviz TL değil · puantaj arşivde yok.

### Puantaj → bordro zinciri (gün kapısı)

Bu olmadan **koca bir hata sınıfı görünmezdi**: muhasebeci birinin gününü yanlış girse bordro
ile banka dosyası birbiriyle mükemmel uyuşur, rapor TEMİZ der, kimse fark etmez.

**Ölçülmüş değişmez (2026-07, 38/38):** `puantaj (Üİ + DZ) == bordro "Eksik Gün"`.
Kırmızı: eşleşen kişide eksik-gün farkı · puantajda olup bordroda karşılığı olmayan ad ·
**puantaj özet sütunları formül ve hesaplanmamış** (aksi halde sıfır sayılırdı — sessiz-yanlış).

⚠️ **Ölçülmeyen dal:** 2026-07'de hiç `DZ` (devamsız) olmadı → DZ'nin bordroda hangi kodla
göründüğü **bilinmiyor**. DZ içeren bir sapma bu yüzden KIRMIZI değil **SARI** verir.
İlk DZ görüldüğünde davranış doğrulanıp sertleştirilmeli.

⚠️ **`T.Gün` denklemi ÇÖZÜLMEDİ.** SGK'nın 30-günlük ay normalizasyonu, ay-ortası giriş ve
resmi tatil çalışması birleşince tek aylık veriden güvenilir formül çıkmadı — **uydurulmadı.**
Gerekirse muhasebeciden alınmalı.

### İsim köprüsü — `_index/roster.json`

Puantajda **TCKN YOK**, yalnız isim var. Bu yüzden puantaj↔bordro eşlemesi isimle yapılır ve
yazım farkları **elle karara bağlanır** (`alias`), puantaj kapsamı dışındaki kişiler ayrıca
listelenir (`puantaj_disi`). Roster'da yazmayan bir fark **tahminle eşleştirilmez, KIRMIZI verir.**

> **Eşleştirme ADA GÖRE DEĞİL, TCKN'ye göre** yapılır. Ad karşılaştırması yalnız rapor içindir
> ve Türkçe harf farkını (`GÖRGİS`↔`GORGİS`) **korur** — NFKD ile aksan düşürmek bu farkı yutardı.

## Arşiv

Kök: `/config/evraklar/IK/05_Maas/<YYYY-MM>/<tur>/<tur>_<YYYY-MM>[_revN].<uzanti>`
(+ `_manifest.json`, `_rapor/`). `MAAS_KOK` ile değiştirilebilir (test için).

- **Sınıflama içerikten** — dosya adına güvenilmez (`TEMMUZ.xlsx` PDKS çıktı).
- **macOS NFD tuzağı:** Mac'ten gelen `...Maaş.xlsx` NFD kodlu; NFC'ye normalize edilmezse
  düz `open()` **FileNotFoundError** verir. `al` bunu üç kademeli çözer.
- **Üzerine yazma YOK** — aynı ay+tür ikinci kez gelirse `_rev2`. **Silme YOK** — kopyalanır.
- `getir` sha256'yı yeniden hesaplar; bozuk/değişmiş dosya sessizce dönmez.

## KVKK / PII

TCKN raporda **`•••1234`**; grup mesajında yalnız toplu rakam (kişi sayısı + tutar).
Mutasyon testinde "üretilen hiçbir metinde tam TCKN yok" kapısı koşar.

## Doğrulama

```bash
MAAS_KOK=<test-kök> uv run --with pypdf --with openpyxl --with xlrd==1.2.0 \
  python /config/.claude/skills/maas-kapisi/tests/mutasyon.py
```
**21 kapı** — temiz taban yalancı-pozitif vermez · 10 dosya-enjeksiyonu (kuruş oynat ·
satır sil · adet boz · toplam boz · beyan formüle çevir · aynı hesap · ödeme tipi ·
hayalet kişi · sıfır tutar · geçmiş tarih) hepsi KIRMIZI · **5 teyit-enjeksiyonu**
(boyut 1 byte · kurum kodu · yanlış hesap · dosya adı · "başarılı" değil) hepsi KIRMIZI ·
bozuk PDF ve eski `.xls` dürüst hata · PII sızıntısı sıfır.

## Bilinen sınırlar

- Yalnız **TGB (Garanti) "Yeni Maaş Dosyası"** şablonunu ve bu muhasebe programının bordro
  PDF'ini tanır. Başka biçim → dürüst hata (sessiz yanlış değil).
- Eski `.xls` (2019-21) **desteklenmez** — `InvalidFileException` ile reddedilir.
- Puantaj→bordro doğrulaması **kapsam dışı** (ayrı zincir).
- `bildir` alıcıyı ADIYLA çözer; grup geçidin sözlüğünde kayıtlı olmalı.

## Kademe (AHÎ)

**Usta** (bileşik): kendi motorunu getirir, ama gönderim/arşiv için
`whatsapp-gonder` · `ik-arsiv` · `pcloud-erisim` skill'lerini **besteler**.
Pîr'e terfi için: pCloud aynalamasının otomatikleşmesi + aylık cron hatırlatıcı +
`ahi promote maas-kapisi`.
