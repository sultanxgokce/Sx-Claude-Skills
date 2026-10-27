---
name: dumen-surucu
description: Ajanın Dümen Chrome'unu (bulut masaüstündeki CDP'li tarayıcı) SÜRMESİNİN tek yolu — Playwright connectOverCDP üstünde eylem kapısı. Her eylemden önce merkezden Dümen kimde okunur; Sultan'da ya da merkez cevapsızsa eylem YAPILMAZ (fail-closed). Parola/SMS/ödeme alanında ajan kendi durur ve nedeni bildirir. İzole dünya dinleyicisi tarih/seçim gibi CDP girdisi üretmeyen değişimleri eylem günlüğüyle eşleştirir. Tetik "Dümen'i sür", "Dümen'de tarayıcı işi", "devral/geri ver".
version: 0.1.2
---

# dumen-surucu — Dümen'i kapıdan sür

Karar belgesi: Nexus `_agents/hezarfen/bilgi-havuzu/dumen-arastirma-20261027/KARAR.md` (Z8E7K7 devral/geri ver · JN1K8K bekçi kör noktası).

## Ne yapar
`scripts/dumen.mjs` → `Dumen.baglan({cdpUrl, merkez})` ajana `goto/fill/selectOption/check/click/press` verir. **Ham `page.evaluate` ve ham CDP verilmez** (`page`/`cdp`/`tarayici` özel alanlardır; `d.page` yoktur). Her eylem:
1. `GET <merkez>/dumen/mod` — `ajan` değilse ya da merkez cevap vermezse **reddedilir**, terminale tek satır: `⏸ Dümen Sultan'da · bekliyorum` (`KapiHata.neden = sultanda | merkez-cevapsiz`).
   - **Mod sultan iken köprü soketi düşer (okuma dahil)**: eylem sırasında gelen bağlantı hatası hata sayılmaz, `sultanda` olur; mod `ajan` olana dek **yeniden bağlanılmaz**. Mod `ajan` olunca bir sonraki eylemde yeniden bağlanır ve sayfa yeniden okunur — Sultan'ın yaptığı eylem ajana aktarılmaz. Mod `ajan` iken soket düşerse sessiz yutulmaz: `baglanti-koptu`. `d.durum()` → `{kopuk, baglanmaSayisi}` (salt-okur).
2. Durma noktası: parola/telefon/tek kullanımlık kod/kart alanı, ödeme sayfasında "Öde/Onayla/Gönder" düğmesi → eylem YAPILMAZ, `POST <merkez>/api/dumen/durak {neden}` (başlık `x-defter-jeton`: `DUMEN_DEFTER_JETON` dosyası ya da `/config/defter-jeton`; değer ASLA yazdırılmaz; yalnız `sifre·sms·odeme`; alan değeri, adres, çerez ASLA; merkez 2xx dememişse `KapiHata.bildirildi=false` ve satır "merkeze İLETİLEMEDİ" der — eylem yine yapılmaz), `⏸ Dümen: … alanında durdum · Dümeni al`.
3. Eylem penceresi kaydedilir; izole dünya dinleyicisi (`input`/`change`, window capture, sayfa betiklerinden önce) olayları toplar. Pencereye düşen olay = ajanın, düşmeyen = **insan ya da sayfa** (`yabanci()`). `isTrusted` ayırıcı DEĞİLDİR (ölçüldü: tarih/seçim false, metin/onay kutusu true, sayfanın sahte olayı false).
4. Parola/OTP/kart alanlarının değeri olay kaydına `<gizli>` olarak girer.

Dinleyici yalnız **kayıt/uyarıdır**: sayfa sahte olay üretip yanlış alarm yaptırabilir; karar kapısı 1-2'dir.

## Kullanım
```js
import { Dumen, KapiHata } from '.../dumen-surucu/scripts/dumen.mjs';
const d = await Dumen.baglan({ cdpUrl: 'http://127.0.0.1:9222', merkez: process.env.DUMEN_MERKEZ });
try { await d.fill('#ad', 'Ayşe'); } catch (e) { if (e instanceof KapiHata) { /* dur; mod ajana dönünce kaldığın yerden sür */ } }
```
`playwright-core` bulunamazsa `DUMEN_PLAYWRIGHT=<playwright-core dizini>`.

## Dürüst sınırlar
- Kapı **ajan tarafındadır** ve disiplinle çalışır: aynı süreçte `playwright-core`'u doğrudan içe aktaran kod kapıyı atlayabilir — gerçek zorlama köprüdedir.
- Kapı **ajan tarafındadır**; Chrome'a giden yolu fiziksel kesen bekçi köprüdedir (BÂNİ B1). İkisi birlikte çift kilit.
- Dinleyici sınavı Chromium headless shell 149 / playwright-core 1.59.1 ile; Dümen'in Chrome 150 / Playwright 1.61'inde yeniden koşulmalı.
- Durma noktası sezgisi (alan türü/ad/ödeme yolu) yanlış negatif verebilir; son savunma bekçide (ağ kapısı).

## Sınav
`bash scripts/dumen.test.sh` — sahte merkez + gerçek headless Chromium, 29 kapı + 10 mutant (fail-open · merkez cevapsız→devam · durma noktası kapalı · durak bildirimi 5xx'i başarı sayar · ham page dışarı açık · parola gizleme yok · jetonsuz bildirim · soket düşünce ham hata · sultan iken yeniden bağlanma · ajan olunca bağlanmama). Chromium yoksa rc 3 ÖLÇÜLEMEDİ.
