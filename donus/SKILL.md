---
name: donus
type: agent
version: 1.0.2
description: >
  Tek dönüş sözleşmesi: işi bitiren, tıkanan ya da soru soran ajan TEK komutla döner, işi AÇAN anında uyanır.
  "dönüş yap · görevi bitirdim · G0034 bitti · tıkandım · işi açana haber ver" tetiğinde. Kutuda (izole oda) dönüşü
  doğru adla giden kutusuna bırakır, merkez ≤60 sn içinde alır; merkezde açanı ortak göndericiyle doğrudan çalar.
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
tags: [filo, gorev, donus, zil, teslimat]
---

# /donus — işi açana dönüş (G-BANI-0006)

Sultan (13 Eki): *"dönüş olunca sen otomatik tetiklenmiyorsun ya da işini bitiren ajan sana bilgi geçmiyor"*.
Ölçülen sebepler: kutu dönüşleri yalnız :14/:44'teki kurye turunda taşınıyordu (30+ dk bekleme), zil SERDAR'ın açtığı
işin dönüşünü MUAVİN'e götürüyordu, merkez içi dönüşlerin zili yoktu. Bu beceri tek komut; geri kalanı merkezde.

## Kullanım

```bash
D=/config/.claude/skills/donus/scripts/donus.sh
bash $D G0034 bitti   "ölçüler perdeciye gitti, fiyat bekleniyor"           # /gorev ile açılan iş
bash $D G0034 tikandi "perdecinin numarası yok" --kanit 0-teslimat/giden/x.md
bash $D G0034 soru    "iki seçenekten hangisi?"
bash $D G-BANI-0006 bitti "dönüş zili hazır" --kanit "PR #1122"              # merkez içi iş (G-AJAN-####)
```

`--ben <AD>` gönderen adı (varsayılan `$CLAUDE_AJAN`, yoksa `KUTU`) · `--kime <AD>` açan bulunamazsa · `--kuru` yazmadan göster.

## Ne olur

| Nerede | Ne yapar |
|---|---|
| **Kutu** | `0-teslimat/giden/<BEN>-<NO>-<zaman>.md` yazar (adında numara!). Merkezde `donus-hizli.sh` dakikada 3 tur bütün kutuları TEK salt-okur komutla tarar, yeni dönüşü kuryeyle hemen getirir, zil işi açanı uyandırır. Hedef ≤60 sn; yedek kurye :14/:44. |
| **Merkez** | Dönüşü Nexus giden kutusuna yazar, açanı bulur (G#### → görev defteri `~/.filo/gorev.jsonl` · G-AJAN-#### → görev mektubu), **ortak gönderici** (`aile-notify`, Enter doğrulamalı) ile çalar. |
| **İkisi de** | Durum `~/.filo/gorev-durum.jsonl`'a düşer → `/filo gorevler` "✅ bitti / ⛔ tıkandı / ❓ soru" gösterir. |

## İlk 5 satır sözleşmesi (zil yalnız bunları okur)

```
G0034 · bitti · <tek satır>
# DÖNÜŞ · PEYK → SERDAR · G0034 · bitti
HEDEF: merkez
GOREV: G0034
DURUM: bitti
```

Elle yazacaksan (beceri yoksa): dosya ADINDA numara bitişik dursun (`PEYK-G0034-…`), ilk satır `G0034 · bitti · …`.

## Değişmezler

- **Önce disk, sonra zil.** Dönüş kalıcı işaret olarak yazılır; zil düşerse kaybolmaz, rc 4 ile söylenir.
- **Dönüş açana gider.** /gorev ile açılan işin dönüşü görev defterindeki açana (SERDAR'ın açtığı iş SERDAR'a); düz kutu
  mektupları rol kuralıyla MUAVİN'de kalır.
- **Tek satır.** Ayrıntı ve ek gövdeye girmez; kanıt bir YOLdur. Sır/numara yazılmaz.
- Çıkış: `0` yazıldı (+merkezde zil çaldı) · `2` kullanım · `3` açan bulunamadı (yazıldı; `--kime`) · `4` zil çalamadı (yazıldı).
- **Kip yazılabilirlikle seçilir (1.0.2 · nazir, 30 Eki).** Nexus dosyalarının görünmesi merkez demek değildir: izole kutuda Nexus
  SALT OKUR kopyadır. Merkez kipi yalnız Nexus giden kutusu yazılabilirse; değilse kutu kipi, ve kutu kipinde yazılabilir İLK
  giden kutusu seçilir (salt okur aday atlanır). Hiçbiri yazılamıyorsa rc 2 ve açık hata — elle yedek yol gerekmez.

## Sınav

`bash scripts/donus.test.sh` — 23 kapı (K6 salt okur Nexus → kutu kipi · K7 yazılabilir aday seçimi dahil) (kutu adı merkez deseniyle çapraz denetlenir; açan çözümü; zil düşmesi; biçim kapıları).
Merkez tarafı Nexus'ta: `scripts/donus-hizli.test.sh` · `scripts/oda-cevap-zili.test.sh` (G1-G11).
