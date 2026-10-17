---
name: hafta-kapanis
description: Haftanın kapanış kapısı (Pazar, Sultan) — yazmaz, ÖLÇER; protokol eksiksiz koşmadıysa hafta kapanmaz. K1 aktif ajanların kutu retrosu var ve geçerli · K2 merkez retrosu var, her ders görev defterine D1 damgasıyla girmiş · K3 kutu önerileri süzülmüş (retro suzum) · K4 haftanın kaçış/tıkanma kayıtları MERKEZ.md'de yazılı bir derse bağlı · K5 Sultan onayı D1 biçimli (araç YAZMAZ, var mı diye ölçer — A06) · K6 haftanın Doğrulat seansları kanon D13'e göre işlenmiş (beceri-pr beyanı + birleşmiş PR; hüküm kanonun oracle'ında, kapı çağırır — Sultan katı kuralı). Çıktı _agents/handoff/retro/<hafta>/KAPANIS.md; açık haftaları listeler. Tetik: "/hafta-kapanis", "haftayı kapat", "hafta kapandı mı", "açık hafta var mı".
version: 1.1.0
---

# /hafta-kapanis — haftanın kapanış kapısı (ölçer, yazmaz; eksikse kapanmaz)

## Niçin var (Sultan 17 Eki 2026 · beyan SERDAR)

"Haftayı kapatma şartı olsun; sistem protokol eksiksiz koşmadıysa haftayı kapatmasın." Retro akışı
(`/retro`: araç ölçer · ajan yorumlar · merkez toplar · süzüm damgalanır) kapısız kalırsa iyi niyete düşer —
bu beceri o kapıdır. Yazılı ama koşmayan kural olmasın diye **salt ölçer**, kendi çıktısı dışında dosya yazmaz.

## 🔴 Değişmezler

1. **Yazmaz, ölçer.** Tek yazdığı dosya `retro/<hafta>/KAPANIS.md`. Kutu retrolarına ve MERKEZ.md'ye dokunmaz;
   `retro.py merkez` MERKEZ.md yazabildiği için **hiç çağrılmaz** — K1 katılımı retro.py'nin saf yardımcılarıyla
   (ölçüm · iz · lint · registry) aynı kuralla sınıflandırır (sınav: MERKEZ.md sha'sı ölçümden sonra aynı).
2. **Sultan onayını ÜRETMEZ (A06).** `_sultan_onay:` satırını insan yazar, Sultan'ın sözünü D1 biçimiyle aktararak:
   `YYYY-MM-DD Sultan: <sonuç> (sohbet · <oturum-ref> · "<≤15 kelime kırpık>" · beyan:<AJAN>)`. Araç satırı okur,
   biçimini ölçer, yeniden ölçümde **korur**; boşsa "(bekliyor…)" yazar, biçimsizse hafta AÇIK kalır.
3. **Aracın kendisi ölçülür.** `retro.py` bulunamazsa K1/K3/K4 ölçülemez → dosya yazılmadan rc=3 ÖLÇÜLEMEDİ.
   "Ölçemedim" ile "kapandı" aynı şey değildir; sarı yeşil sayılmaz.
4. **Açık hafta defteri yok.** Açık haftalar `retro/<hafta>/` dizinlerinden türetilir: KAPANIS.md yok ya da
   `_durum: KAPANDI` değil → açık. İki hafta aynı anda açık olabilir; her biri `--hafta` ile ayrı ölçülür.
5. Renkler fabrikayla aynı: 0 KAPANDI · 5 ONAY BEKLİYOR (K1-K4 + K6 yeşil, onay yok) · 1 AÇIK (kırmızı var) ·
   3 ÖLÇÜLEMEDİ (sarı var, kırmızı yok) · 2 kullanım hatası.

## Kullanım (Pazar, Sultan oturumu; Pazartesi yeniden denenebilir)

```
python3 ~/.claude/skills/hafta-kapanis/scripts/hafta-kapanis.py olc [--hafta 2026-W42] [--kok <depo>] [--ajanlar A,B] [--registry <yaml>]
python3 ~/.claude/skills/hafta-kapanis/scripts/hafta-kapanis.py acik [--kok <depo>]
```

| Kapı | Ne ölçer | Kaynak |
|---|---|---|
| K1 katılım | aktif ajanların kutu retrosu var ve lint geçer (EKSİK/GEÇERSİZ → kırmızı; iz bırakmamış ajan serbest) | retro.py saf yardımcıları (merkez komutu çağrılmaz) |
| K2 dersler | MERKEZ.md `## Dersler`'de ≥1 `M<n>)`; **her** ders `## Görevler`'de `- gorev_<26> · ders M<n> · D1: <D1>` — RED yolu yok: görev olmayacak şey Dersler'e yazılmaz, nota taşınır | MERKEZ.md |
| K3 süzüm | her kutu önerisi `→ gorev_` ya da `→ RED:` damgalı, metin güncel | `retro.py suzum` rc |
| K4 kaçış/tıkanma | haftanın kaçış defteri satırları (anahtar: zaman damgası) + `durum=tikandi` kartları (anahtar: `kart:<iş>`) `## Kaçış ve tıkanma`'da **yazılı bir derse** bağlı: `- <anahtar> → M<n>` (RED yolu yok; M<n> Dersler'de olmalı); **okunamayan kart = SARI** (sessiz atlanmaz) | kaçış defteri · kartlar · MERKEZ.md |
| K6 Doğrulat dersleri | haftanın Doğrulat seans retroları (`retro/dogrulat/<tarih>.md`, tarihi haftanın içinde) **kanon D13**'e göre işlenmiş. **Hüküm kanonun oracle'ındadır** (cloudtop `scripts/dogrulat-retro-kapisi.sh`: `beceri-pr: <depo>#<no>[, …]` beyanı var ve her PR gh'de **birleşmiş**); kapı kuralı yeniden yazmaz, çağırır — **tek ölçüm, ikinci kopya yok**. Kapıya kalan: oracle'ın "son N gün" penceresini ISO haftasına süzmek · işlenmemiş seansı **dersleriyle** (madde no + ders metni) raporlamak, liste **kesilmez** · kırmızı ölçülemeyeni gizlemez · ders bölümü olmayan seans kırmızı. Seans kaydı yoksa yeşil ve bunu söyler; **oracle yok / ölçemedi (rc 2), adında tarih olmayan ya da okunamayan seans dosyası = SARI** | `retro/dogrulat/*.md` · kanon D13 oracle'ı (`--d13` · `HAFTA_KAPANIS_D13` · cloudtop varsayılanı) |
| K5 onay | KAPANIS.md `_sultan_onay:` D1 biçimli — **tam satır** eşleşmesi (baş/son çapalı; kuyruk metni biçimsiz) ve kırpık **≤15 kelime** (karakter sayısı yerine geçmez; aynı kural K2 görev D1'inde) | KAPANIS.md (insan yazar) |

Kapanmayan hafta: KAPANIS.md kırmızı kapıları adlarıyla basar; eksikler ilgili ajana görev olur, ertesi gün
yeniden ölçülür. `retro.py` çözümü: `--retro-py` · `HAFTA_KAPANIS_RETRO_PY` · kardeş dizin (`../retro/scripts`) ·
`~/.claude/skills/retro/scripts/retro.py`.

## Kanıt

`scripts/hafta-kapanis.test.sh` — 118 geçen kontrol: 100 kapı hermetik (mktemp depo · sabit tarih · K6 için oracle'ın ARAYÜZÜNÜ taklit eden sahte betik — kural içermez) + 18 mutant kopya üstünde (görev D1
denetimi kalkınca biçimsiz damga geçer · K4 eksik denetimi kalkınca damgasız tıkanma geçer · onay D1 denetimi
kalkınca "onaylandı" haftayı kapatır · bozuk kart sessiz atlanınca sarı kaybolur · D1 tam eşleşmesi gevşeyince
kuyruklu onay kapatır · yazılı-ders denetimi kalkınca var olmayan derse bağ geçer · kırpık kelime sınırı kalkınca 16 kelimelik onay kapatır · K6: oracle'ın ✗ satırı yok sayılınca işlenmemiş seans geçer · K6 olc'a bağlanmazsa · oracle yokken sessiz geçilirse · adsız rc 2 yeşil sayılırsa · rc 1 adı okunamayınca sessiz geçilirse · '?' satırı yok sayılırsa · kırmızı ölçülemeyeni yutarsa · tarihsiz seans atlanırsa · rapor kesilirse · dersler rapordan düşerse · hafta süzgeci kalkarsa — on sekizi de ısırıyor). Gerçek oracle + gerçek gh ile tümleşik ölçüm PR kanıtındadır). Sınav `retro.py` ister; yoksa **rc=3 ÖLÇÜLEMEDİ** basar,
sahte yeşil vermez (bağ: `retro` becerisi önce birleşir).

## Sınırlar (dürüst)

- K5 "Sultan onayı" bir **beyandır**; araç imzayı doğrulayamaz, biçimini ve varlığını ölçer. Eşik-üstü sınıf değil
  (hafta kapanışı geri alınabilir), sohbet damgası yeter (L73 K1-K4).
- K4 kaçış defteri ajan alanı taşımaz; damga kutu geneline yapılır.
- K6 seansları **kayıttan** görür: retro dosyası yazılmamış bir Doğrulat seansını bu kapı göremez (seansın kendisi
  ayrı bir defterde tutulmuyor). Seans sonu retroyu yazmak SERDAR + MUHAKKİK protokolüdür; kapı yazılanı ölçer.
- K6'nın hükmü kanon D13 oracle'ınındır: beyan biçimi (`<depo>#<no>`, depo **tam adıyla**), PR olmayan numaranın nasıl
  sayıldığı, gh gereksinimi oradan gelir. Oracle bu kutuda yoksa (cloudtop #691 birleşmeden) K6 **sarıdır** — hafta kapanmaz,
  "ölçülemedi" der. PR'ın o dersi gerçekten taşıdığı (içerik eşleşmesi) ölçülmez — bağ, retroyu yazanın beyanıdır.
- Cuma/Pazar zilleri bu becerinin dışında (cloudtop `crontab-abc`, MİRAHUR).
