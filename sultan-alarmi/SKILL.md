---
name: sultan-alarmi
type: agent
version: 0.1.1
description: >
  Bir iş ya da ajan SULTAN yüzünden duruyorsa tek biçimli alarm basar: terminalde kırmızı satır, istenirse telefona bildirim,
  "ne gerekiyor, tek tık" cümlesiyle. Aynı iş için tekrar sınırı (varsayılan 60 dk) ve 3. tekrarda yükseltme vardır.
  Her kullanımdan çıkan ders bu becerinin kendi defterine (DERSLER.md) yazılır; beceri Sx senkronuyla bütün kutulara iner.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [sultan, alarm, bildirim, onay, ntfy, kalfa]
---

# /sultan-alarmi — Sultan yüzünden duran iş görünür olsun

## Niçin var (Sultan-direktifi 27 Ekim 2026)
Alarm yalnız SERDAR'ın nöbet isteminde yaşıyordu; başka kutuda yoktu. `sultan-eli` farklı iştir (insan `!` komutu ölçümü),
ajan tıkanması da farklı iş. Sultan: *"kullanmak zorunludur master promptlarında yer alacak ve kullandıkça tecrübelerle
geliştirmek ve global senkron etmek zorunludur."*

## Biçim (tek, değişmez)
`🚨🔴 SULTAN ALARMI — <iş> · <kim duruyor> · <ne gerekiyor, tek tık>`
Üç alan da dolu, tek satır, her biri ≤160 karakter, sır yok. Tek tık = Sultan'ın nereye basacağı ya da hangi satırı yapıştıracağı.

## Komutlar
```
alarm.sh bicim  --is … --kim … --ne …              biçimi doğrular ve basar
alarm.sh gonder --is … --kim … --ne … [--telefon] [--kuru]
alarm.sh tara   [--esik-gun N]                      aday listesi (GÖNDERMEZ)
alarm.sh ders   "<öğrenilen tek satır>"             DERSLER.md'ye tarihli satır
```
- Terminal satırı kırmızıdır (`NO_COLOR` ile sade). Telefon yalnız `--telefon` ile gider: `http://cloudtop-ntfy/alarm` (yazma-yalnız konu).
- `--kuru` telefona GİTMEZ, niyetini söyler. **Sultan ekrandaysa** (`SULTAN_EKRANDA=1`) telefon atlanır; terminal satırı yine basılır.
- **Tekrar sınırı:** aynı iş (adı, büyük/küçük harf farkı yok) `--tekrar-dk` (varsayılan 60) içinde ikinci kez basılmaz, "sustu" der.
- **Yükseltme:** `SULTAN_ALARMI_YUKSELT_N` (varsayılan 3). 3. basışta satır "TEKRAR n — YÜKSELTİLDİ" taşır, telefon önceliği 5 olur.
- **Kütük:** her alarm `~/.cache/sultan-alarmi/kutuk.jsonl`'a yazılır (basıldı/sustu/gitti/atlandı/kuru/hata). "Bildirim kaydı" budur.
- Bildirim gitmediyse (http ≠ 2xx) UYARI basılır ve kütüğe `hata` yazılır; sessiz başarı yoktur.

## Tespit kaynakları (`tara`)
| Kaynak | Durum (0.1.0) | Aday olma koşulu |
|---|---|---|
| kapımda kartları | ölçülür | açık `🚦 SENDE` kartı (devredilmiş `🎯` değil) |
| onay-bekliyor görevler (yaş) | ölçülür | `onay-bekliyor` ve son hareketten ≥ `--esik-gun` (varsayılan 1) gün |
| sabah paketi · Engel paneli · Sultan karar soruları · Sultan-eli bekleyen iş | **ölçülmez** | `tara` bunu her koşuda yazar: bu kaynaklar için "aday yok" hüküm DEĞİLDİR |

`tara` hiçbir kaynağı okuyamazsa rc 3 verir ("aday yok" denmez). Yaşı ölçülemeyen satır `ADAYSIZ|…` diye söylenir, sessizce atlanmaz.

## Eşik (ne zaman alarm?)
Bir ajan ya da iş SULTAN yüzünden duruyorsa: kapıda Sultan kartı, Sultan onayı bekleyen görev, Sultan-eli komut bekleyen iş.
Ajanın kendi tıkanması (kod hatası, başka ajan) alarm DEĞİLDİR. A06: alarm Sultan'ın kararını üretmez, yalnız görünür kılar.

## Ders defteri (kullandıkça gelişir)
Her kullanımdan çıkan ders `alarm.sh ders "…"` ile `DERSLER.md`'ye eklenir; sürüm artar; Sx `sync-targets.json` + `catalog.json`
üzerinden bütün kutulara `sync-skills.mjs --skill sultan-alarmi` ile iner (kurulu kopya elle düzenlenmez).

## Sınır / dürüstlük
- Telefona ulaşıp ulaşmadığını yalnız ntfy'nin http cevabından bilir; Sultan'ın okuduğunu bilmez.
- Kanon (ORTAK-MIMARI) "zorunlu" satırı ve her kutunun CLAUDE.md işaretçisi bu beceriden AYRI PR'dır (sınıflı; birleştirme Sultan'ın).
- Sınav: `bash scripts/alarm.test.sh` (hermetik, sahte curl/defter/saat).
