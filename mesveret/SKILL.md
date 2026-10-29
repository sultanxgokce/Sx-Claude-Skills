---
name: mesveret
type: agent
version: 0.1.0
description: >
  Meşveret Seansı — Sultan tek komutla reisle bulgu toplama seansı açar. Seans madde madde, sabit ve emojili bir
  şablonla ilerler (A sen anlat · B ben önereyim · C etkileşimli gidelim); her madde kaydedilince Sultan'a önemi
  (1-3) sorulur ve kayıt Bulgu Havuzu'na (merkezî görev defteri, "havuz" durumu) düşer. Sabah Hasat'ı bu kayıtlardan
  görev doğurur. "/mesveret", "bulgu toplayalım", "meşveret seansı" tetiğinde; Hasat tazelik denetimi KURU dediğinde
  günlük plan bu seansı önerir. Kuzey Yıldızı Madde 1.2 (Sultan, 29 Eki 2026).
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [sultan, bulgu, havuz, hasat, seans, kuzey-yildizi]
---

# /mesveret — Meşveret Seansı

## Niçin var (Sultan, 29 Ekim 2026 — Kuzey Yıldızı 1.2)
> "Sultan tek bir kısa komutla reisle bulgu toplama seansı başlatır. Seans standart, emojili, sabit bir şablonla
> madde madde ilerler. Madde kaydedilince Sultan'a önemi sorulur (1-3). Sonra 'Madde 2'ye geçelim' denir."

Geliştirme veri toplamakla başlar. Bulgular tek yerde (Bulgu Havuzu) tek biçimde birikmezse Hasat boşa döner.
Bu beceri o birikimin **Sultan'ın ağzından** gelen kolunu açar.

## Terimler (çevrilmez — Kuzey Yıldızı sözlüğü)
**Meşveret Seansı** · **Bulgu Havuzu** · **Hasat** · **Nişan Paneli** · **Puanlama Turu**

## Değişmezler
1. **Şablon sabittir.** Her madde aynı üç şıkla açılır; reis şablonu değiştirmez, kısaltmaz.
2. **Önem Sultan'ındır (A06).** Reis önemi uydurmaz; Sultan'ın söylediği sayı, sözüyle birlikte kayda aktarılır
   (`--onem N --soz "<verbatim ≤15 kelime>"`). Söz yoksa önem yazılmaz, "önem sorulmadı" kalır.
3. **Tek havuz.** Kayıt merkezî görev defterine `havuz` durumuyla düşer (`bulgu.sh yaz`); ikinci bir defter
   açılmaz. Kayıt notunda seans kimliği ve madde numarası durur — Hasat kaynağı bulur.
4. **Seans diskte yaşar.** Her madde yazıldığı anda seans dosyasına işlenir; bağlam dolsa da seans kaybolmaz
   (`mesveret.sh durum` kaldığı yeri söyler).
5. **Ölçemezse yazmaz.** Bulgu Defteri bu kutuda kurulu değilse (`bulgu.sh` rc 3) madde kaydedilmez, Sultan'a
   söylenir; "yazdım" denmez.

## Akış (reis böyle yürütür)

### 0 · Başlat
```bash
bash /config/.claude/skills/mesveret/scripts/mesveret.sh basla [--oda <oda>] [--konu "<tek satır>"]
```
Çıktı seans kimliği (`mes_<tarih>-<kısa>`). Reis Sultan'a tek satır: *"Meşveret seansı açıldı. Madde 1'den başlıyoruz."*

### 1 · Madde şablonu (her maddede AYNEN)
```
🔎 **Madde N'i çalışıyoruz**
A) Sen anlat · B) Ben önereyim · C) Etkileşimli gidelim
```
- **A)** Sultan anlatır; reis Sultan-dilinde tek başlık + 2-3 cümle not çıkarır, Sultan'a okur.
- **B)** Reis kendi gözlemlerinden (defter · sürtünme raporu · son hatalar) bir bulgu önerir; Sultan kabul/düzeltir.
- **C)** Etkileşimli: reis Nişan Paneli'ni önerir (canlı ekranı işaretle, görüntüyü düşür) — panel yoksa Sultan ekran
  görüntüsünü `0-Gelen`'e bırakır, reis yolunu `--gorsel` ile kayda bağlar.

### 2 · Kaydet
```bash
bash …/mesveret.sh madde <seans> "<başlık Sultan dilinde>" --kim <REİS> --etiket bug|ozellik \
     --not "<2-3 cümle>" [--gorsel <yol>] [--oda <oda>]
```
Kayıt Bulgu Havuzu'na düşer; çıktı görev kimliğidir. Sonra reis **önemi sorar** (tek soru, üç şık):
```
Bu maddenin önemi? 1 (düşük) · 2 (orta) · 3 (yüksek)
```
Sultan cevaplayınca:
```bash
bash …/mesveret.sh onem <seans> <madde-no> --onem <1|2|3> --soz "<Sultan'ın sözü, verbatim>" --oturum <ref>
```
Önem kayda D1 biçiminde adım olarak işlenir (`D1 <tarih> Sultan: önem N (sohbet · <ref> · "<söz>" · beyan:<REİS>)`).
Defter `sultan_onem` alanını alır hâle gelince aynı komut o alanı da yazar (alan yoksa yalnız adım).

### 3 · Devam / Bitir
Reis: *"Madde N+1'e geçelim mi?"* — Sultan "bitti/yeter" deyince:
```bash
bash …/mesveret.sh bitir <seans>
```
Özet basılır: kaç madde · hangi görev kodları · önemi sorulmayan madde sayısı. Reis özeti Sultan'a aynen verir.
Seans dosyası kalır (`~/.cache/mesveret/<seans>.json`); `mesveret.sh liste` geçmiş seansları gösterir.

## Hasat ile bağ
- Günlük planın tazelik denetimi `TAZELIK=KURU` dediğinde öneri **bu seanstır** (gunluk-plan 1.17.0, Kuzey Yıldızı 1.8).
- Hasat, havuzdaki kaydı göreve çevirirken seans kimliğini ve madde numarasını kaynağa yazar (1.5/1.6).

## Komutlar
```
mesveret.sh basla [--oda <oda>] [--konu "…"]           → seans kimliği
mesveret.sh madde <seans> "<başlık>" --kim <AD> --etiket bug|ozellik [--not "…"] [--gorsel <yol>] [--oda <oda>]
mesveret.sh onem  <seans> <madde-no> --onem 1|2|3 --soz "…" --oturum <ref>
mesveret.sh durum <seans>                               → kaçıncı madde, hangileri önemsiz kaldı
mesveret.sh bitir <seans>                               → özet
mesveret.sh liste                                       → seanslar
```
Çıkış kodları: 0 tamam · 2 kullanım · 3 Bulgu Defteri kurulu değil / seans yok · 4 kayıt yazıldı ama önem adımı yazılamadı.

## Sınav
`bash scripts/mesveret.test.sh` — hermetik (sahte `bulgu.sh` ve sahte `gorev.sh`): seans açılır · madde kaydı havuza gider, kimliksiz kayıt reddedilir
gider ve seans dosyasına işlenir · önem sözsüz REDDEDİLİR (A06) · önem sözle D1 adımı yazar · bitir özeti doğru sayar ·
defter kurulu değilse rc 3 ve dosyaya yazılmaz · 1 mutant (madde sayacı bozulunca özet kırmızı).

## Sürüm notları
- **0.1.0 (30 Eki 2026, SERDAR — Kuzey Yıldızı gece inşası):** ilk sürüm. Şablon · kayıt · önem (D1) · özet · hermetik sınav.
  Göz tur 1 düzeltmeleri: havuza işlenmeyen önem seansa da işlenmez (rc 4) · her madde sonrası A/B/C şablonu yeniden açılır · kayıt kimliği okunamazsa madde yazılmaz (rc 3).
  Sınır: Nişan Paneli henüz yok (C şıkkı görüntü yolunu elle alır); `sultan_onem` alanı defterde henüz yok (adım olarak işlenir).
