---
name: pazaryeri-mesaj
description: NARH'ın (mmex) Dümen'den Amazon Seller Central ve Trendyol partner panelindeki müşteri mesajlarını OKUMASININ, cevap taslağını Sultan'ın onayına SUNMASININ ve yalnız onaylı cevabı GÖNDERMESİNİN tek çerçevesi — "müşteri mesajlarını oku", "mesajlara cevap ver", "Trendyol soruları", "Amazon alıcı mesajı" dendiğinde. Parola/kod yazmaz, onaysız tek mesaj göndermez, müşteri kişisel verisini hiçbir yere yazmaz; Amazon'da gönderme Sultan'ın risk kararına bağlı.
version: 0.1.0
---

# pazaryeri-mesaj — müşteri mesajlarını oku, onayla gönder

**Durum (3 Kas 2026): İSKELET KURULU, GERÇEK SAYFADA ÖLÇÜLMEDİ.** Sayfa haritası (`HARITA.json`) tahminle yazıldı ve `olculdu:false`; seçici
tutmayınca araç **ÖLÇÜLEMEDİ** (rc 3) der, tahmin etmez. İlk gerçek tur NARH'ta (mmex): seçicileri gerçek sayfadan düzelt, `olculdu:true` yap,
ders yaz. Sınav hermetik (sahte paneller + gerçek Chromium + gerçek Dümen sürücüsü): 41 kapı + 13 mutant.

## Niçin var
Görev …ZB3C0Q (Sultan D1 2 Kas: *"NARH giriş için sürekli izin istemez; açık oturumda yürür, kapalıysa tek satır yazar"*). HEZARFEN bıraktı
("Dümen BÂNİ ve MİRAHUR'un işi"); BÂNİ standart yetenek olarak kurdu. Amazon'da cevap gönderme riski (ajan politikası) 2 Kas'ta Sultan'a
soruldu — karar gelene dek Amazon'da **gönderme kapalı**, okuma + taslak açık.

## Değişmezler (pazarlıksız)
- **Onaysız tek mesaj gitmez.** `gonder` Sultan'ın D1 damgasını ister: `YYYY-MM-DD Sultan: onay (<kaynak> · <ref> · "<kırpık>" · beyan:<AJAN>)`,
  tarih BUGÜN, damga metni **o sohbetin kimliğini VE cevabın parmak izini** (`cevap#…`, `taslak` üretir, görev başlığına/notuna girer) anmalı.
  Başka mesajın onayı taşınmaz, dünkü onay yetmez, **onaydan sonra değişen metin gitmez** (göz tur 1). Ajan Sultan'ın sözünü ÜRETMEZ, gördüğünü
  referanslar (A06).
- **Çift mesaj yok (gönderim kilidi):** düğmeye basmadan önce `<kilit dizini>/<pazar>-<sohbet>.json` yazılır; iz doğrulanınca `gonderildi`
  (aynı sohbete ikinci `gonder` rc 2 — yeni cevap yeni taslak+onay ister), doğrulanamazsa `belirsiz` (rc 3 "GÖNDERİLMİŞ OLABİLİR", ikinci deneme
  yalnız `--yeniden "<Dümen'den ne gördüğün>"` ile). Düğmeden ÖNCE sayfada cevabın izi zaten varsa gönderilmez (rc 2). Kilit dizini
  `PAZARYERI_KILIT` (varsayılan `/config/.claude/pazaryeri-mesaj/gonderim`).
- **Amazon'da gönderme kilidi:** `/config/.claude/pazaryeri-mesaj/amazon-gonderme.json` → `{"gonderme":"acik","karar":"<Sultan D1 damgası>",
  "gecerli_gun":90}` olmadan `gonder amazon:…` rc 2. Karar **süresiz değil**: damga tarihinden `gecerli_gun` (varsayılan 90, en çok 365) sonra
  kapanır, tazelenir. Dosyayı yalnız Sultan'ın kararıyla reis yazar. Trendyol'da kilit yok.
- **Parola / SMS / kod / ödeme alanına ajan yazmaz** (dumen-surucu durma noktası). Oturum kapalıysa rc 10 + "Sultan Dümen'de girsin"; giriş
  sayfasına düşünce başka eylem yok.
- **Dümen Sultan'daysa** okuma da gönderme de yok: rc 20, "⏸ Dümen Sultan'da · bekliyorum"; geri verince komut yeniden koşulur.
- **KVKK:** müşteri adı seçicilerle hiç alınmaz; mesaj gövdesindeki telefon/e-posta/IBAN/kart desenleri `<numara>`/`<e-posta>`/… olur; çıktı
  yalnız terminale ve (taslakta) görev defterine kırpılmış gider. Kare alınmaz, kütük tutulmaz.
- **Sultan'ın sekmesine dokunulmaz:** Dümen'de yeni sekme (dumen-surucu 0.7.0 varsayılanı). **İnsan hızı:** sayfalar arası 2–4 sn rastgele.
- **Yalnız mesaj:** ürün/ilan/sipariş/iade değiştirme, dosya yükleme YOK.
- **Dümen'de gördüğünü bulguya yaz** (Sultan 2 Kas): seçici tutmadı, sayfa değişti, beklenmedik durma → `bulgu.sh yaz …`.

## Akış (NARH · mmex)
```bash
export DUMEN_MERKEZ=<merkez adresi>          # Dümen kimde kapısı; DUMEN_CDP varsayılan http://127.0.0.1:9222
M=/config/.claude/skills/pazaryeri-mesaj/scripts/mesaj.mjs
node $M oku                                   # 1) cevapsız mesajlar: "<pazar>:<sohbet> · "<özet>""  (rc 0 · 10 giriş lazım · 20 Dümen Sultan'da · 3 harita tutmadı)
node $M taslak trendyol:T-77 --metin "<cevap>" --ozet "<müşteri ne sordu>"   # 2) görev defterinde 'sıra sende · karar · onay' kaydı → Sultan'ın ekranı
# 3) Sultan ekranda onaylar / düzeltir / reddeder. Onayı GÖRÜNCE damgayı yaz (sohbet kimliği damgada geçsin):
printf '%s' "<onaylı cevap>" > /tmp/cevap.txt
node $M gonder trendyol:T-77 --metin-dosya /tmp/cevap.txt --onay "2026-11-03 Sultan: onay (görev ekranı · gorev_… · \"gönder T-77\" · beyan:NARH)" --gorev gorev_…
```
Cevap metni **dosyadan** okunur (komut satırı/geçmiş kirlenmez). Gönderim sonrası sayfada cevabın izi aranır; görülmezse rc 3 "dogrulanamadı" —
Dümen'den bak, bulgu yaz.

## Sayfa haritası — `HARITA.json`
Pazar başına: `gelen_kutusu` · `sohbet_adresi` (`{sohbet}` yer tutucu) · `giris_deseni` · `secici.{sohbet_cevapsiz, sohbet_kimlik, son_mesaj, cevap_alani, gonder}`
· `gonderme_karari` (Amazon). Seçici **müşteri adını hedeflemez**. Kimlik sayısı ≠ önizleme sayısı ise harita bu sayfayı tanımıyordur → rc 3.
`PAZARYERI_HARITA=<yol>` ile kutuya özel kopya (ilk turda düzeltilen harita buraya PR'lanır).

## İlk gerçek tur (NARH) — ders yazmadan tur bitmez
1. Dümen'de Sultan oturumları açsın (Amazon + Trendyol); Dümen'i ajana versin. 2. `oku --pazar trendyol` → rc 3 ise gerçek sayfadan seçicileri
HARITA'ya işle (müşteri adı seçicisi YOK), yeniden koş. 3. Bir mesaj için `taslak` → Sultan onayı → `gonder` → izi görüldü mü? 4. Amazon: yalnız
`oku`; `gonder` için Sultan'ın karar dosyası beklenir. 5. Öğrenilen her şey `bulgu.sh yaz` + bu SKILL.md'ye (sürüm +0.0.1).

## Dürüst sınırlar
- Gerçek Amazon/Trendyol sayfalarında **hiç koşmadı**; adresler ve seçiciler üçüncü taraf yazılardan ve genel kalıptan tahmindir.
- Onay kapısı **damga biçimine ve sohbet kimliğine** bakar; Sultan'ın gerçekten onayladığını görev ekranından ajan okur, araç doğrulayamaz (A06:
  ajan beyan eder, `--gorev` ile kayıt adıma düşer, `scripts/onay-parity.sh` örneklem-denetler).
- Dümen kapısı ajan tarafındadır (dumen-surucu dürüst sınırı); zorlama köprüdedir.
- Trendyol tarafında "ürün sorusu" ile "sipariş mesajı" ayrı sayfalar olabilir (Ticimax rehberi); harita ilk turda bölünebilir.

## Sınav
`bash scripts/mesaj.test.sh` — K1–K12 çekirdek (kırpma · damga + parmak izi · Amazon kilidi + süre), O1–O6 okuma (+ seçici alternatifleri) (Dümen + sahte paneller: giriş sayfası, Sultan modu,
harita tutmama), T1–T4 taslak (sahte gorev.sh: sıra sende · karar · onay, maskeli not), G1–G9 gönderme (onaysız · başka sohbet · dünkü · Amazon
kilidi · onaylı Trendyol · Sultan kararlı Amazon · değişmiş metin · ikinci gönderim kilidi · belirsiz gönderim + --yeniden · iz zaten var · Sultan modu
· komut satırı metni). 13 mutant (üçer paralel): onay/parmak izi/damga/karar+süre/giriş/KVKK/harita/kilit/Sultan-modu kapıları gevşeyince sınav
kırmızıya döner. Chromium yoksa rc 3 (ÖLÇÜLEMEDİ).
