---
name: hafta-kapanis
description: Haftanın kapanış kapısı (Pazar, Sultan) — yazmaz, ÖLÇER; protokol eksiksiz koşmadıysa hafta kapanmaz. K1 aktif ajanların kutu retrosu var ve geçerli · K2 merkez retrosu var, her ders görev defterine D1 damgasıyla girmiş · K3 kutu önerileri süzülmüş (retro suzum) · K4 haftanın kaçış/tıkanma kayıtları MERKEZ.md'de yazılı bir derse bağlı · K5 Sultan onayı D1 biçimli (araç YAZMAZ, var mı diye ölçer — A06). Çıktı _agents/handoff/retro/<hafta>/KAPANIS.md; açık haftaları listeler. Tetik: "/hafta-kapanis", "haftayı kapat", "hafta kapandı mı", "açık hafta var mı".
version: 1.0.0
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
5. Renkler fabrikayla aynı: 0 KAPANDI · 5 ONAY BEKLİYOR (K1-K4 yeşil, onay yok) · 1 AÇIK (kırmızı var) ·
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
| K5 onay | KAPANIS.md `_sultan_onay:` D1 biçimli — **tam satır** eşleşmesi (baş/son çapalı; kuyruk metni biçimsiz) | KAPANIS.md (insan yazar) |

Kapanmayan hafta: KAPANIS.md kırmızı kapıları adlarıyla basar; eksikler ilgili ajana görev olur, ertesi gün
yeniden ölçülür. `retro.py` çözümü: `--retro-py` · `HAFTA_KAPANIS_RETRO_PY` · kardeş dizin (`../retro/scripts`) ·
`~/.claude/skills/retro/scripts/retro.py`.

## Kanıt

`scripts/hafta-kapanis.test.sh` — 68 kapı hermetik (mktemp depo · sabit tarih) + 6 mutant kopya üstünde (görev D1
denetimi kalkınca biçimsiz damga geçer · K4 eksik denetimi kalkınca damgasız tıkanma geçer · onay D1 denetimi
kalkınca "onaylandı" haftayı kapatır · bozuk kart sessiz atlanınca sarı kaybolur · D1 tam eşleşmesi gevşeyince
kuyruklu onay kapatır · yazılı-ders denetimi kalkınca var olmayan derse bağ geçer — altısı da ısırıyor). Sınav `retro.py` ister; yoksa **rc=3 ÖLÇÜLEMEDİ** basar,
sahte yeşil vermez (bağ: `retro` becerisi önce birleşir).

## Sınırlar (dürüst)

- K5 "Sultan onayı" bir **beyandır**; araç imzayı doğrulayamaz, biçimini ve varlığını ölçer. Eşik-üstü sınıf değil
  (hafta kapanışı geri alınabilir), sohbet damgası yeter (L73 K1-K4).
- K4 kaçış defteri ajan alanı taşımaz; damga kutu geneline yapılır.
- Cuma/Pazar zilleri bu becerinin dışında (cloudtop `crontab-abc`, MİRAHUR).
