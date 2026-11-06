---
name: sultan-alarmi
type: agent
version: 0.3.1
description: >
  Bir iş ya da ajan SULTAN yüzünden duruyorsa tek biçimli alarm basar: terminalde kırmızı satır, istenirse telefona bildirim,
  "ne gerekiyor, tek tık" cümlesiyle. Aynı iş için tekrar sınırı (varsayılan 60 dk) ve 3. tekrarda yükseltme vardır.
  Her kullanımdan çıkan ders bu becerinin kendi defterine (DERSLER.md) yazılır; beceri Sx senkronuyla bütün kutulara iner.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [sultan, alarm, bildirim, onay, whatsapp, kalfa]
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
- Terminal satırı kırmızıdır (`NO_COLOR` ile sade). Telefon yalnız `--telefon` ile gider: **WhatsApp** (`whatsapp-gonder`). ntfy çıkarıldı. Başarıda çıktıya `whatsapp: gitti` yazılır (kota-uyari çift mesajı bununla önler).
- `--kuru` telefona GİTMEZ, niyetini söyler. **Sultan ekrandaysa** (`SULTAN_EKRANDA=1`) telefon atlanır; terminal satırı yine basılır.
- **Tekrar sınırı:** aynı iş (adı, büyük/küçük harf farkı yok) `--tekrar-dk` (varsayılan 60) içinde ikinci kez basılmaz, "sustu" der.
- **Yükseltme:** `SULTAN_ALARMI_YUKSELT_N` (varsayılan 3). 3. basışta satır "TEKRAR n — YÜKSELTİLDİ" taşır, mesaj bu işareti taşır.
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

## Günlük istek bütçesi (0.3.0 · SERDAR 6 Kas)
Sultan'a günde en çok **4 istek**. İstek = Sultan'dan tık ya da karar isteyen her şey: kapımda kartı, onay-bekliyor görevi, soru mektubu, WhatsApp sorusu. Bilgi satırı sayılmaz.
```
butce.sh harca --tur kart|onay|soru|wa --ad "<ad>" --sahip <ajan>   rc 0 geçti · rc 10 kuyruğa yazıldı (gönderme)
butce.sh acil  --ad "<ne>" --sahip <ajan>                           yalnız hat durdu · para kaybı · canlı kesinti; tavanı aşar, günde en çok 1
butce.sh durum | butce.sh ozet [--isle] [--onceki]                   bugünkü sayaç · kuyruğun tek özet metni
butce.sh sabah [--kuru]                                             dünkü kuyruğu TEK WhatsApp mesajı olarak Sultan'a gönderir (09:00'da çağrılacak); gidince satırları işler, gitmezse korur (rc 3)
```
- Gün İstanbul günüdür. Tavan dolunca ret yok, **kuyruk**: istek ertesi sabah 09:00 özetinde tek satır gider; sahibine "KUYRUKTA" bilgisi basılır.
- `harca --dis-kuyruk`: çağıranın kendi sabah kuyruğu varsa (ör. `karar-kuyrugu.sh`) taşan istek 'dis-kuyruk' diye kaydedilir, sabah özetine GİRMEZ (çift gönderim olmasın); rc yine 10.
- Aynı gün aynı tür+ad istek bir kez düşer. Acil böyle değildir: her çağrı acil hakkından düşer (günde 1 telefon).
- Bağlı yollar: `kapimda ac` (kart) · `alarm.sh gonder --telefon` (acil hakkı) · `wa-gonder.sh --istek "<ad>"` (WhatsApp sorusu; bayrağı çağıran verir, bilgi mesajı vermez). **Bağlı DEĞİL:** onay-bekliyor görevi (gorev.sh, cloudtop), soru mektubu, `butce.sh sabah`'ın 09:00'da kendiliğinden koşması (cloudtop cron kartı) — o güne dek özeti `butce.sh sabah` ile elle koşturmak gerekir.
- Bütçe betiği okunamazsa istek geçer (fail-open, uyarı basılır): bu bir politika sınırlayıcısıdır, güvenlik kapısı değil.
- Defter dosya-yereldir (konteyner başına `butce.jsonl`); kutular arası tek sayaç yoktur.

## Ders defteri (kullandıkça gelişir)
Her kullanımdan çıkan ders `alarm.sh ders "…"` ile `DERSLER.md`'ye eklenir; sürüm artar; Sx `sync-targets.json` + `catalog.json`
üzerinden bütün kutulara `sync-skills.mjs --skill sultan-alarmi` ile iner (kurulu kopya elle düzenlenmez).

## Sınır / dürüstlük
- `gitti` yalnız WhatsApp geçidi kabul edince yazılır; ntfy 0.2.0'da çıkarıldı (31 Eki: Sultan ntfy kullanmıyor, 22 'gitti' alarm ona ulaşmadı). Sultan'ın okuduğunu bilmez.
- Kanon (ORTAK-MIMARI) "zorunlu" satırı ve her kutunun CLAUDE.md işaretçisi bu beceriden AYRI PR'dır (sınıflı; birleştirme Sultan'ın).
- Sınav: `bash scripts/butce.test.sh` (bütçe) · `bash scripts/alarm.test.sh` (hermetik, sahte curl/defter/saat).
