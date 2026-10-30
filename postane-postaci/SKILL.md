---
name: postane-postaci
type: tool
version: 0.1.0
description: >
  POSTANE postacısının (dakikada bir kutu içi tur: posta defterindeki mesajı alıcı ajanın CANLI Claude oturumuna yerel soketle iletir) bir kutuya kurulması için dosyalar ve kutu betiği.
  Kuru koşu varsayılan; --uygula yalnız izinli 17 ekip kutusundan birinde VE kutu jetonu dar iken (başka kutunun/merkezin ajan kuyruğunu okuyamıyorsa) cron + açma bayrağı yazar.
  "postacı kur · postane teslim bu kutuda çalışmıyor · posta oturuma düşmüyor" tetiğinde. Etkinleştirme Sultan-elidir (/config/sk satırı); bu beceri yalnız dosya ve ölçümü taşır.
---
# postane-postaci — postacıyı bir kutuya taşıyan paket

**Ne:** `scripts/postaci.mjs` (+ `postane.mjs` · `ajan-adlari.mjs` · `ulid.mjs`) cloudtop `infra/postane` dosyalarının BİREBİR kopyasıdır (`scripts/KAYNAK.sha256`). Değişiklik kaynakta (cloudtop) yapılır, buraya taşınır; kopya elle düzenlenmez.
**Kurulum betiği:** `bash scripts/postaci-kutu.sh` (KURU) · `--uygula` · `--kapat`. Sınav: `bash scripts/postaci-kutu.test.sh` (12 kapı, mutantlı).

## Sınırlar (kodda)
1. **İzinli kutu listesi sabit** (17 ekip kutusu); listede olmayan kutuda `--uygula` reddedilir.
2. **Dar yetki şartı:** kutu jetonu merkez ajanı SERDAR'ın kuyruğunu okuyabiliyorsa (200) `--uygula` REDDEDİLİR; ölçülemiyorsa da (yeşil sayılmaz). Çare: host izin dosyasında kutunun jetonuna `ajanlar:[kendi ajanları]` verilir (Sultan-eli).
3. **Geri alma:** `--kapat` (bayrak silinir, cron satırı anında no-op).
4. **Sır değeri basmaz.** Bu beceri etkinleştirme YAPMAZ; kurulumu Sultan-eli `/config/sk/postaci-17-kutu-*.sh` yürütür.

## Dürüst sınır
Soketten yazmak "mesaj alıcının satırına düştü" demektir; gerçek onay alıcının `posta gordum`udur. Ayrıntı: cloudtop `infra/postane/README.md`, `postaci-auth-olcumu.md`.
