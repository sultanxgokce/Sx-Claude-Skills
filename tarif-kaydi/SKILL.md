---
name: tarif-kaydi
type: tool
version: 0.1.0
description: >
  Kadro tariflerinin ve terim kaydının TEK KOPYASI (Sultan D1 21 Eki S8: tarifler beceri deposunda, her kutuya iner):
  uzmanlık, vazife ve usul tarifleri (kadro-tarifleri.json) ve terim kaydı (terim-kaydi.json), bir de bunları şema
  sürüm 2'ye karşı sınayan bekçi (kadro-denetle.py). Şu durumlarda kullan: "Mühürdarlık uzmanlığı neleri taşır",
  "usulün hangi adımı Sultan'ın eli", "kapı ile kapımda aynı şey mi" gibi bir terimi ya da kadro ilişkisini
  arıyorsan · bir uzmanlık, vazife, usul ya da terim eklerken/değiştirirken · kadro verisinin şemaya uyduğunu doğrularken.
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
tags: [kadro, terim, uzmanlik, muhurdarlik, veri]
---

# tarif-kaydi — kadro tarifleri ve terim kaydı

Veri becerisidir: komut çalıştırmaz, okunur. **İkinci kopya yazma**; ekran ve ajanlar buradan okur.

| Dosya | İçerik |
|---|---|
| `veri/kadro-tarifleri.json` | `uzmanliklar[]` · `vazifeler[]` · `usuller[]` (adım türü kapalı küme `beceri · kapi · sultan_eli`) |
| `veri/terim-kaydi.json` | bir terim = bir anlam; aynı kelimenin iki anlamı iki kayıt (`kapı` yedi kayıt) |
| `scripts/kadro-denetle.py` | bekçi: şema sürüm 2 kuralları (kapalı kümeler, iki yönlü bağlar, kaynak yolları …) |
| `scripts/kadro-denetle.test.sh` | bekçinin kendi sınavı: altın + bozulmuş kopyalar + mutasyonlar (46 kapı) |

Şemanın tamamı: Nexus `_agents/spec/terminoloji-kadro-tasarim/tasarim/veri-semasi.md` (§2-§7 alanlar, §10 bekçi).

## Bekçi

```bash
python3 scripts/kadro-denetle.py            # rc 0 temiz · 1 kırmızı · 3 ölçülemedi
python3 scripts/kadro-denetle.py --siki     # sarı da rc=1 yapar
bash scripts/kadro-denetle.test.sh          # bekçinin sınavı
```

Üç renk: **kırmızı** (kural çiğnenmiş) · **sarı** (bakılamadı ya da henüz yazılmadı; temiz DEĞİL) · **rc 3** (dosya yok, katalog boş:
ölçülemedi). `NEXUS_KOK` / `CLOUDTOP_KOK` okunamazsa o kaynaklar sarı "ölçülemedi" olur, yeşil sayılmaz.

## Değişiklik kuralları

- Kayıt eklerken `sema_surumu: 2`, `durum: aday` yaz. **`onayli` işaretini ajan koymaz** (A06); onay Sultan'ın ya da terimin sahibinin elindedir.
- `karistirilan` iki yönlüdür: A, B'yi sayıyorsa B de A'yı sayar; bekçi tek yönlü bağı kırmızı sayar.
- Sultan adı verilmiş şeyin adını değiştirme: `Sicil`, `Ders çıkarma`, `Mühürdar`, `Sultan eli` (S9, S13). Vazife kimliği `kalibrasyon` şema dışıdır.
- Kapı adımının betiği henüz yoksa `kapi_yolu: null` yaz (sarı görünür); yol uydurma, dosya yoksa kırmızıdır.
- Beceri adımı katalogda olmayan bir `beceri_id` taşımaz (sarı).

## Dürüst sınır

Bekçi **biçimi ve bağları** denetler; bir terimin anlamının doğru olduğunu ya da bir usulün işe yaradığını denetlemez.
Bugünkü veride dört sarı durur: `tescil-teslim-sina` adım 1-2, `tatbikat-bozuk-is` adım 2 ve `ders-cikarma-kacirma` adım 1 kapıları
henüz yazılmadı (`kapi_yolu: null`); yazılınca yolları buraya girer. Sınav kümesi (`sinav.kume`) boştur, Mühürdarlık `planli` kalır.
