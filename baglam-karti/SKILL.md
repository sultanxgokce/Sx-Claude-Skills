---
name: baglam-karti
type: agent
version: 1.0.0
description: >
  ENİS bağlam kartı KAYIT DEFTERİ: MAİŞET ya da SERDAR'ın bağlam kartı isteğini ve ENİS'in cevabını taşımadan ÖNCE
  şablona göre doğrular ve Görev Defteri'ne tek adım yazar (Sultan kim, ne zaman, hangi durumla çekim yaptı görür).
  Karar cümlesi ve kart metni kayda yazılmaz. Kayıt yazılamazsa kart dönmez (fail-closed). "bağlam kartı kaydet ·
  bağlam kartı isteği taşı · ENİS cevabını işle" tetiğinde.
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
---

# /baglam-karti — bağlam kartı çekimini kayda düşür, sonra taşı

**Niçin:** ENİS hafıza erişim kurgusunun ÇEKME yolunda (Sultan onayı 17 Eki, gorev `10M`) MAİŞET ya da SERDAR bir karar
için bağlam kartı ister, ENİS anonim 2-3 cümleyle döner. Taşıyıcı oda mektubudur. Şablon (MUAVİN, 18 Eki) "her istek ve
her cevap bir adım, kayıt yazılamıyorsa kart da dönmez" der. Bu araç o cümleyi talimattan araca çevirir.

## Komut

```bash
bash /config/.claude/skills/baglam-karti/scripts/baglam-karti.sh kaydet <mektup.md> [--kuru] [--gorev <gorev_id>]
```

| Mektup | Dosya adı | Kayda düşen adım |
|---|---|---|
| İstek | `<MAISET\|SERDAR>-ENIS-baglam-karti-<YYYYMMDD>-<n>.md` | `istek <YYYYMMDD>-<n> · <İSTEYEN> · ufuk <bugün\|bu hafta> · son an <…>` |
| Cevap | `ENIS-<MAISET\|SERDAR>-baglam-karti-<YYYYMMDD>-<n>.md` | `cevap <YYYYMMDD>-<n> · <İSTEYEN> · durum <verildi\|kapalı\|dayanak yok> · kapı <geçti\|—>` |

Varsayılan kayıt görevi: `gorev_01M557ADY4KHRGS99DQ6E2M0CV`.

## Sıra (taşıyıcı için)

1. `kaydet` → **rc 0** ise mektubu taşı.
2. **rc 1** (jeton yok, defter ulaşılamaz ya da reddetti): taşıma. Kayıt yoksa kart da yok. SERDAR'a yaz.
3. **rc 2** (biçim): taşıma. Yazana geri gönder. Kapıdan geçmemiş kart için ENİS `Durum: kapalı` döner, kart yumuşatılmaz.

## Değişmezler

- 🔴 Karar cümlesi ve kart metni deftere de ekrana da yazılmaz. Sınav bunu ölçer (İ5, C2).
- İsteyen yalnız MAISET ya da SERDAR. Başka ad rc 2.
- `verildi` için `Kapı: geçti` ve dolu `Kart` zorunlu. `kapalı` ve `dayanak yok` kart metni taşımaz.
- Aynı adım ikinci kez yazılmaz (defter tekilleştirir). Yeniden çalıştırmak güvenlidir.
- Jeton `curl --config` ile gider: argv'de ve çıktıda görünmez.

## Ölçmediği (dürüstlük)

- Karar cümlesinde kişi, yer, tarih ya da sağlık terimi olup olmadığını **ölçmez**. O, ENİS'in dış raf kapısının
  (`dis-raf-kapi.sh`) işidir. Bu araç yalnız kaydın biçimini ve fail-closed taşımayı korur.
- Cevabın karşılığı olan isteğin kayıtta olup olmadığına bakmaz.
- SIHHAT/kasa ya da Sultan'ın bayrağı kapalıyken gelen isteklere "kapalı" dönmek ENİS'in işidir. Araç yalnız o cevabı kaydeder.

Sınav: `scripts/baglam-karti.test.sh` (hermetik, sahte defter, 19 kapı).
