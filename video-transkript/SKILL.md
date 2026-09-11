---
name: video-transkript
type: tool
tier: kalfa
version: 1.0.0
description: >
  YouTube videosunun TAM konuşma metnini getirir. Bu kutuların IP'si YouTube tarafından
  bloklu; istek, çeken tarafın kendi sunucusundan yapılır (Supadata) → bizim IP hiç
  devreye girmez. "videoyu izle · transkriptini çıkar · şu videoyu oku" tetiğinde.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [youtube, transkript, video, altyazi, supadata]
status: v1.0-canli
---

# video-transkript — YouTube videosunun konuşma metni

**NİÇİN VAR (ölçüldü, 11 Eylül 2026):** Sultan bir videoyu okumamı istedi.
**Üç ayrı yoldan** denendi, üçü de düştü:

```
yt-dlp (oynatıcı API)  → "Sign in to confirm you're not a bot"
timedtext ucu (AYRI)   → RequestBlocked ("IP'nizden gelen istekler engelli")
düz sayfa çekimi       → HTTP 200 AMA captionTracks=0 · 14 bot/onay işareti
```

🔴 **Engel YÖNTEMDE değil, BU SUNUCUNUN IP'SİNDE.** Bu yüzden Playwright, Chrome
eklentisi ya da başka bir tarayıcı da çözmez — **tarayıcı değiştirmek IP değiştirmez.**
(Sultan'ın Playwright önerisi mantıklıydı; ölçüm onu çürüttü, tahmin değil.)

**Çözüm sınıfı:** isteği KENDİ sunucusundan yapan servis. Supadata seçildi —
ölçüm: ücretsiz 100/ay · 1 video = 1 kredi · **birim fiyat açıkça yayımlı**.
Rakibi (youtube-transcript.io) jeton→transkript çevrimini yayımlamıyordu;
**ölçülemeyen birim seçilmez.**

⚠️ Kıyaslama İKİ sağlayıcıyla sınırlı (arama bütçesi tükenmişti) — "piyasanın en
iyisi" değil, "ölçülen ikisinin açık ara iyisi". Tıkanırsa daha geniş tarama gerekir.

## Kullanım
```bash
yt-transkript.sh <youtube-url> [dil]   # tam metin stdout'a, ölçüm stderr'e
yt-transkript.sh --durum               # anahtar + servis yoklaması
```
Çıkış kodları: `0 tamam · 2 kullanım · 3 anahtar yok · 4 servis reddetti · 5 altyazı yok`

🔴 **Anahtar argv'ye DÜŞMEZ** (`ps` görmesin) — `/config/.config/supadata.env`'den (0600)
okunup başlığa konur; değer hiçbir koşulda stdout'a basılmaz.

🔴 **ÖLÇÜLEMEDİ ≠ YOK:** anahtar okunamazsa "altyazı yok" demez, *"BİLİNMİYOR"* der.
Servis 200 döndürüp metin boş gelirse bu **sessiz başarı sayılmaz**, hata döner.

## Kanıt (borusuz, çıkış-kodlu)
```
anahtar yok      → 3     geçersiz anahtar → 4     youtube olmayan → 2
argümansız       → 2     gerçek video     → 0  · 54.326 karakter · 8.315 kelime
```
⚠️ İlk ölçümüm **yalancıydı**: çıkış kodlarını `| head` arkasından okumuştum, beşi de
"0" görünüyordu. Borusuz tekrar ölçüldü. (Kendi kuralımıza kendi aracımızda düştük.)
