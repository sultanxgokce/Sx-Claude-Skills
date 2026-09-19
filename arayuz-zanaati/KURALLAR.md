# Arayüz zanaatı — ayrıntılı kurallar ve hazır CSS parçaları
[D] = kaynak sayfası açılıp okundu · [B] = sayfa açılamadı, değer teyitsiz · işaretsiz = çıkarım/öneri.

## 1. Aralık
- [D] Bootstrap: `$spacer 1rem`; .25 · .5 · 1 · 1.5 · 3 rem. Atlassian: taban 8; 0–8 bileşen içi, 12–24 kart içi, 32–80 sayfa düzeni. GOV.UK: büyük boşluk dar ekranda küçülür, küçük sabit kalır.
- [D] Every Layout "Stack": margin iki komşunun ilişkisidir, öğeye değil bağlama yazılır.
```css
:root{ --s1:4px; --s2:8px; --s3:12px; --s4:16px; --s5:24px; --s6:32px; --s7:48px; --s8:64px; --s9:96px; }
.field > * + * { margin-block-start: var(--s2); }   /* etiket → kutu → yardım */
.form  > * + * { margin-block-start: var(--s5); }   /* alan → alan */
.form  > .group + .group { margin-block-start: var(--s7); }
```
- [D] Varsayılan margin'leri sıfırla, boşluğu tek yönde ver (Bootstrap Reboot, Josh Comeau reset).

## 2. Hizalama ve ızgara
- [D] Bootstrap kırılma: 576 · 768 · 992 · 1200 · 1400; max-width sorgusunda 575.98 (kesirli genişlik). Kap: 540 · 720 · 960 · 1140 · 1320. Oluk 24 px.
- [D] Satır uzunluğu 45–75 karakter; `max-inline-size: 66ch`.
- [D] Form tek sütun (Baymard, NN/g); istisna mantıksal bağlı kısa alanlar. Birincil düğme formun sol kenarında (GOV.UK). Kutu genişliği beklenen girdi uzunluğunu söyler.
- Optik: kenarlıksız düğmenin metni kenara hizalanır, dolgusu dışarı taşırılır. Tablo hücre dolgusu = kart dolgusu.

## 3. Form denetimleri
```css
:root{ --ctl-h:44px; --ctl-px:14px; --r-ctl:10px; }
input,select,button,.btn{ box-sizing:border-box; min-height:var(--ctl-h); padding:0 var(--ctl-px);
  font:inherit; line-height:1.25; border:1px solid var(--border); border-radius:var(--r-ctl); }
textarea{ padding:10px var(--ctl-px); }
```
- [D] web.dev giriş formu: hedef ≥ 44×44; yazı ≥ 16 px; etiket üstte; `autocomplete="username" / "current-password" / "new-password"`; şifre "göster" düğmesi; gönderince düğme kilitlenir; e-posta/şifre iki kez sorulmaz.
- [D] Yer tutucu etiket değildir (NN/g yedi zarar). Yardım metni etiketle kutu arasında tek cümle. Hata: etiketin altında, kutunun üstünde, metin + renk + çizgi; etiketi yankılar; yalnız etkileşimden sonra; alanlar temizlenmez (GOV.UK, USWDS).
- [D] Zorunlu/isteğe bağlı açıkça yazılır (Baymard). Sıfırla düğmesi konmaz (NN/g). Devre dışı düğmeden kaçın (GOV.UK).
- [D] İç içe yarıçap (Cloud Four): `.kart{--r:16px;--p:8px} .kart>.ic{border-radius:calc(var(--r) - var(--p))}`
- "ya da" ayırıcı (yaygın kalıp):
```css
.ya-da{display:flex;align-items:center;gap:12px;color:var(--soluk);font-size:.8125rem;margin-block:24px}
.ya-da::before,.ya-da::after{content:"";flex:1;height:1px;background:var(--border)}
```
- Dış hesapla giriş düğmesi: birincil düğmeyle aynı boy, genişlik, yarıçap; çerçeveli ikincil görünüm; simge 18–20 px solda. Sağlayıcı logosu yeniden renklendirilmez (marka kılavuzunu teyit et).

## 4. Durumlar
### Otomatik doldurma (19 Eylül kusurunun tam çözümü)
[D] Chrome iç biçemi `background-color: light-dark(rgb(232 240 254), rgb(70 90 126 / .4)) !important` — doğrudan ezilemez; `color-scheme: dark` bildirilmemişse **açık mavi** gelir (MDN).
```css
:root{ color-scheme: dark; }   /* + <meta name="color-scheme" content="dark"> */
input:-webkit-autofill, input:-webkit-autofill:hover, input:-webkit-autofill:focus,
textarea:-webkit-autofill, select:-webkit-autofill{
  -webkit-text-fill-color: var(--metin); caret-color: var(--metin);
  -webkit-box-shadow: 0 0 0 1000px var(--alan-zemin) inset; box-shadow: 0 0 0 1000px var(--alan-zemin) inset;
  transition: background-color 99999s ease-in-out 0s; border-color: var(--border); }
input:autofill{ box-shadow: 0 0 0 1000px var(--alan-zemin) inset; -webkit-text-fill-color: var(--metin); } /* AYRI kural: tanınmayan seçici bütün listeyi düşürür */
input:-webkit-autofill:focus-visible{ box-shadow: 0 0 0 1000px var(--alan-zemin) inset, 0 0 0 2px var(--odak); }
```
Tuzaklar: `--alan-zemin` **opak** olmalı (saydamsa mavi alttan görünür) · odak halkası da gölgeyle yapılıyorsa birleştir ya da `outline` kullan · kutu içi simge `background-image` ise kaybolur, ayrı öğe yap.
### Ötekiler
- [D] Odak: `:focus-visible{outline:2px solid var(--odak);outline-offset:2px}`; 3:1 kontrast (WCAG 2.4.13, 1.4.11). Koyu temada beyazın %8'i kenarlık 3:1'i geçmez — ölç. Yapışkan başlık odaklanan öğeyi örtmesin: `scroll-padding-top`.
- `overflow:hidden` kap halkayı keser: kaba 3–4 px dolgu ya da negatif offset.
- Yükleniyor: düğme genişliği değişmez; iskelet gerçek içerikle aynı yükseklikte. Boş durum: başlık + tek cümle + tek eylem.

## 5. Koyu tema
- [D] `color-scheme` dört şeyi değiştirir: tuval, kaydırma çubuğu, form denetimleri, yazım çizgisi. `accent-color` onay kutusu, radyo, kaydırıcıyı boyar.
- [D] web.dev: dört yüzey kademesi (L ≈ %10/15/20/25); saf siyah/beyaz yalnız uçta; renk doygunluğu düşer; metin L %65–85. Koyuda gölge zayıf: 1 px kenarlık + bir kademe açık yüzey daha güvenilir.
- [D] Kontrast: metin 4,5:1; büyük metin 3:1. İnce ağırlık koyuda daha zor okunur: gövde 400–500. `-webkit-font-smoothing: antialiased` açık yazıyı inceltir; bilinçli karar.
- Açık zeminli görsel/ekran karesine 1 px kenarlık.

## 6. Tipografi
- Boy ölçeği 6–8 kademe (12/14/16/20/24/32/48); hiyerarşi boy + ağırlık + tonla. [D] Satır aralığı birimsiz 1,5–1,65; başlıkta sıkı. Büyük başlıkta −0,01…−0,02em; büyük harf küçük etikette +0,04…+0,08em.
- [D] `font-variant-numeric: tabular-nums`; `text-wrap: balance` (başlık), `pretty` (paragraf). Font kayması: `font-display`, yedek fonta `size-adjust`; gömülü fontta `document.fonts.ready` sonrası ölç.
- [D] `text-transform` dile duyarlı: `lang="tr"` yoksa i→I. Sınama dizgisi: "İIıi ŞşĞğ ÇçÖöÜü" — başlıkta, düğmede, büyük harf etikette.

## 7. Tarayıcı tuzakları
- [D] `min-height:100vh; min-height:100dvh;` · iOS: input < 16 px odakta yakınlaştırır · `appearance:none` + `font:inherit` · `scrollbar-gutter: stable`.
- [D] Sticky çalışmaz: atada `overflow:hidden` (çare `clip`), `top` yok, öğe kaptan büyük, flex/grid stretch (çare `align-self:start`), kaydırma kabının yüksekliği yok.
- [D] Yığın bağlamı yaratanlar: opacity<1, transform, filter, fixed/sticky, will-change. Bileşen kökünde `isolation:isolate`; z-index adlı katmanlardan. [D] `backdrop-filter`: atada opacity/filter varsa arkayı görmez; büyük alanda kullanma.
- [D] CLS: görselde ölçü, geç gelen içeriğe `min-height`, animasyonda `transform`. [D] Kesme: `.buyuyen{flex:1;min-width:0}` + `overflow:hidden;text-overflow:ellipsis;white-space:nowrap`. `overflow-wrap:break-word`.
- %125 yakınlaştırmada 1 px çizgiler eşitsiz kalınlaşabilir; gözle bak.

## 8. Tablo
- [D] NN/g: başlık ve ilk sütun sabit; ilk sütun insanın okuyacağı kimlik; satırı izlemeye yardım (çizgi/zebra/üstünde vurgu); düzenleme için yan panel. [D] USWDS: kaydırılabilir kap, mobilde yığılmış düzen, `caption` ve `scope`. [D] Smashing: dar ekranda kaydır / karta çevir / sayfala; içerik gizlenmez.
- Satır 44–52 px; hücre dolgusu 12/16; koyuda zebra farkı L ≈ %2–3; uzun değer tek satır + kesme + `title`; birim başlıkta.

## 9. Tutarlılık
- [D] Palet önceden tanımlanır (8–10 gri, ana/vurgu 5–10 ton); anlık üretilen yakın-aynı renk yasak (Refactoring UI).
- Varyant sınırı: düğme 3 tür × 2 boy; kutu 1 boy. Simge tek aile, tek çizgi kalınlığı, 16/20/24. [D] Dokunma hedefi: WCAG 2.5.8 ≥ 24; form ve mobilde 44–48.

## 10. Amatör görünüm belirtileri → çare
1 otomatik doldurmada açık kutu → §4 bloğu + color-scheme · 2 kutuda iç boşluk yok → dolgu 14, boy 44 · 3 düğme/kutu boyu farklı → ortak `--ctl-h` · 4 hap ile köşeli yan yana → tek `--r-ctl` · 5 iç içe aynı yarıçap → iç = dış − dolgu · 6 eşitsiz dikey aralık → yığın + ölçek · 7 etiket iki kutunun ortasında → 8 / 24 · 8 yer tutucu etiket → görünür etiket · 9 sistem fontlu input → `font:inherit` · 10 varsayılan mavi halka ya da halka yok → `:focus-visible` · 11 halka kırpılıyor → kaba dolgu · 12 birden çok birincil düğme → tek · 13 beyaz kaydırma çubuğu/seçim/takvim → color-scheme · 14 mavi onay kutusu → accent-color · 15 saf siyah + saf beyaz → L %10 / %85 · 16 görünmeyen kenarlık → kontrastı ölç · 17 koyuda 300 ağırlık → ≥ 400 · 18 kart zeminden ayrılmıyor → kenarlık + açık yüzey · 19 sol kenarlar farklı x'te → tek kap dolgusu · 20 sayılar sola → sağa + tabular · 21 başlık son satırında tek kelime → balance · 22 100+ karakter satır → 66ch · 23 "IPTAL" → lang="tr" · 24 ğ/ş başka fonttan → glifleri ekle · 25 yüklenirken sıçrama → ölçü, iskelet · 26 kaydırma çubuğu gelince kayma → scrollbar-gutter · 27 mobilde düğme araç çubuğunun altında → dvh · 28 iOS odakta yakınlaşma → 16 px · 29 uzun değer kabı taşırıyor → min-width:0 · 30 boş tablo yalnız başlık → boş durum · 31 boş hücre → "—" · 32 hata yalnız kırmızı kenarlık → metin · 33 hata verince form sıfırlanıyor → koru · 34 yüklenirken düğme genişliyor → sabit · 35 karışık simge aileleri → tek · 36 yapışkan başlığın altından içerik görünüyor → opak + isolation (p49 dersi) · 37 z-index 9999 yarışı → adlı katman · 38 dokunmatikte yapışan hover → hover sorgusu · 39 13/17/22 px boşluk → belirteç kapısı · 40 "ya da" üstü altı eşitsiz → simetrik margin-block.

## Kaynaklar (19 Eylül 2026; açılıp okunanlar)
Bootstrap 5.3 (spacing, reboot, breakpoints, containers, gutters, form-control) · Atlassian Design (spacing) · GOV.UK Design System (spacing, text input, error message, button) · U.S. Web Design System (text input, table) · Nielsen Norman Group (form boşluğu, yer tutucu, web form, veri tablosu) · Baymard (çok sütunlu form, zorunlu alan) · Every Layout (stack, axioms) · web.dev (giriş formu, autofill, tipografi, renk şeması, görünüm birimleri, CLS, size-adjust) · MDN (:autofill, color-scheme, accent-color, focus-visible, form biçimleme, font-variant-numeric, text-wrap, text-transform, scrollbar-gutter, backdrop-filter) · W3C WCAG 2.2 (kontrast, metin dışı kontrast, odak görünümü, örtülmeyen odak, hedef boyutu) · CSS-Tricks (autofill, iOS 16 px, flex kesme) · Cloud Four (iç içe yarıçap) · Josh Comeau (reset, yığın bağlamı) · Polypane (sticky) · Smashing (okunurluk, tablo kalıpları) · Refactoring UI (palet). **Açılamadı, değerleri teyitsiz:** Material 3, Apple HIG, IBM Carbon, Shopify Polaris.
