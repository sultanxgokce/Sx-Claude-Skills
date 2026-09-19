---
name: arayuz-zanaati
version: 0.1.0
allowed-tools: Bash, Read, Write, Edit
description: Web sayfası ya da uygulama ekranı yazarken, değiştirirken ve denetlerken kullan. Tasarım zevki değil ZANAAT - aralık ölçeği, hizalama, form denetimleri, durumlar (otomatik doldurma dahil), koyu tema tuzakları, tipografi, tarayıcı farkları, tablo kuralları, tutarlılık. "Garip, amatör, tam oturmamış, harmonisiz" görünümü önler. HTML/CSS, form, giriş sayfası, tablo, kart, ekran, prototip geçince çağır.
---

# Arayüz zanaatı — garip durmasın diye bilinmesi gerekenler

**Doğduğu yer (19 Eylül 2026):** Sultan giriş sayfasına baktı: "tasarım iyi; ama kutucuklarda gariplik var, tam uymamış, harmoni olmamış, amatör durmuş." Sebep zevk değildi, zanaattı: Chrome otomatik doldurma kutuları açık maviye boyadı, kutuda iç boşluk yoktu, hap düğmenin yanında keskin köşeli kutu duruyordu, dikey aralıklar eşitsizdi. Biz hep **boş kutuyla** ölçmüştük. Sultan: "Tasarım olarak sormuyorum. Uyum, dikkat edilecek noktalar, CSS, Bootstrap kuralları; bunları bil ki yanlış, tuhaf duracak şeyler yapma."
Görsel yön `tasarim-citasi` ve `frontend-design`'dadır. Bu beceri olgun tasarım sistemlerinin **yazılı, ölçülebilir** kurallarıdır. Dayanak: 38 sayfalık tarama (sonda). Ayrıntı ve CSS parçaları: `KURALLAR.md`. Yayın öncesi bakış: `KONTROL-LISTESI.md`.

## On iki temel kural (ezber)
1. **Tek aralık ölçeği.** `4 · 8 · 12 · 16 · 24 · 32 · 48 · 64 · 96`. Ölçek dışı değer (13, 18, 22 px) yasak. (Bootstrap, Atlassian, GOV.UK aynı mantık.)
2. **Yakınlık.** İlgili öğeler yakın, gruplar uzak: etiket→kutu 8 · kutu→yardım/hata 4–8 · alan→alan 24 · grup→grup 48 · son alan→düğme 24–32. Alan arası boşluk, etiket-kutu boşluğunun **en az üç katı**. Kabın iç dolgusu ≥ içindeki öğe aralığı.
3. **Boşluğu kap dağıtır.** Öğeye tek tek margin yazma; kapsayıcı `> * + *` ya da `gap` ile versin. Eşitsiz dikey ritmin kök çaresi budur.
4. **Tek sol kenar.** Başlık, etiket, kutu, düğme, tablo ilk sütunu aynı x'te başlar. Ölç: `getBoundingClientRect().left` kümesi 1–2 değer.
5. **Düğme ve kutu aynı boyda.** Ortak `--ctl-h` (≥ 44 px), ortak yatay dolgu (12–16 px), ortak yazı boyu. Kutuda iç boşluk **asla sıfır değil**.
6. **Tek yarıçap ailesi.** En çok üç kademe + hap. Hap tek bir bileşen türüne ayrılır; aynı blokta hap düğme ile köşeli kutu yan yana durmaz. İç içe: `iç yarıçap = dış − aralık`.
7. **Her durum tasarlanır ve bakılır:** varsayılan · üstünde · odakta (`:focus-visible`, 2 px, 3:1) · basılı · devre dışı · hata · yükleniyor · **otomatik doldurulmuş** · boş veri · uzun veri.
8. **Koyu temada `color-scheme: dark` şart** (kökte + `<meta name="color-scheme">`). Yoksa kaydırma çubuğu, seçim listesi, takvim, onay kutusu ve otomatik doldurma zemini açık gelir.
9. **Form temelleri.** Etiket üstte ve görünür; yer tutucu etiket yerine geçmez; tek sütun; **sayfada tek birincil düğme**, metni eylemi söyler; hata metni etiketi yankılar, değerler silinmez; `autocomplete` adları doğru; input yazısı ≥ 16 px (iOS yakınlaştırmasın); `font: inherit`.
10. **Tipografi.** 6–8 kademelik boy ölçeği; koyu zeminde ağırlık ≥ 400; rakam sütunlarında `tabular-nums`; başlıkta `text-wrap: balance`; satır ≤ 66 karakter; `lang="tr"` (yoksa "iptal" → "IPTAL"); gömülü fontta İ ı ğ ş ç ö ü glifleri var mı bak.
11. **Tarayıcı tuzakları.** `100vh` yerine `100dvh` yedeğiyle · `scrollbar-gutter: stable` · flex çocuğunda `min-width: 0` (kesme için) · sticky + atada `overflow:hidden` çalışmaz · üst katman **opak** zemin + `isolation: isolate` · görselde `width/height` ya da `aspect-ratio` · hover yalnız `@media (hover:hover)`.
12. **Tablo.** Sayı, tutar, tarih sağa; metin sola; başlık sütunun hizasını alır; boş değer "—"; ya zebra ya çizgi; yapışkan başlık opak; kayan kabın içine not konmaz; dar ekranda kaydırma ya da karta çevirme — içerik gizlenmez.

## Çalışma sırası
1. **Yazmadan önce belirteçler:** aralık 9 · yarıçap 3 + hap · yüzey 4 · metin 3 · kenarlık 2 · süre 2 · adlı z katmanları. Bileşenler yalnız belirteçten beslenir.
2. **Yazarken:** KURALLAR.md'deki hazır parçalar (form alanı yığını, otomatik doldurma bloğu, "ya da" ayırıcı, kesme, iç içe yarıçap).
3. **Bakarken:** KONTROL-LISTESI.md. En az şu **altı hâl** kendi gözünle: otomatik doldurulmuş · hata · boş veri · en uzun veri · %125 yakınlaştırma · klavyeyle gezinme. Yedi viewport zaten `tasarim-citasi` kapı 8.
4. **Ölçülebilenleri ölç** (tarayıcıda betikle): denetim yükseklikleri kümesi · sol kenar kümesi · kullanılan farklı yarıçap/boşluk/yazı boyu sayısı · ölçek dışı px sayısı · `scrollWidth === clientWidth` · kontrast (metin 4,5:1, kenarlık ve odak 3:1) · dokunma hedefi (≥ 24; form ve mobilde ≥ 44).
5. **Teslim mektubuna satır:** "zanaat: altı hâl bakıldı · denetim boyu tek · sol kenar tek · ölçek dışı 0".

## Ölçüm düzeneği uyarısı
Otomatik doldurma Playwright `fill` ile tetiklenmez; boş kutu ölçümü bu kusuru **göstermez**. Kural kaynakta var mı bak, aynı bildirimi geçici sınıfa bağlayıp karesini al, mümkünse gerçek Chrome'da kayıtlı bilgiyle bir kez gözle doğrula. "Ölçüm yeşil" kalite değildir; hâl listesi eksikse yeşilin anlamı yok.
