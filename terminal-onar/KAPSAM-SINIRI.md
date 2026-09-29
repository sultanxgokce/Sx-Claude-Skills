# Bilinen sınır · canlı kurulum kanıtı YOK (2026-09-29)

Bağımsız göz haklı: kart *"bütün kutularda çalışır"* diyor ama **canlı bir kurulumla
doğrulanmadı.** İddia daraltılıyor; süslenmiyor.

## Neyin kanıtı VAR

- Kapı sınavı 36/36 — **iki ayrı sunucu** ayağa kaldırılıp ölçülüyor: biri taban
  yolunda (`/sedir`), biri köksüz. Yani "taban varken" ve "taban yokken" davranışı
  aynı koşuda karşılaştırılıyor.
- Mutasyon 12/12 — her kapı bozularak kırmızıya döndüğü görüldü.
- Parola, çerez, WebSocket sınırı, önbellek sınırı ve tarayıcı akışı **kutu adından
  bağımsız** ölçülüyor (sınavda kutu `akar` ve `sedir` olarak iki kez koşuyor).

## Neyin kanıtı YOK

- **Gerçek bir kutuya kurulum** (`/terminal-kur` zinciri) hiç koşulmadı.
- SEDİR'in kutusunda ölçülen canlı durum: kök yol `/giris` → **200**, taban yolu
  `/sedir/giris` → **302**. Yani bu paket **oraya kurulu değil**; kutu hâlâ eski
  kök-yollu kapıyı koşuyor.

## Niçin koşulmadı

Kurulum, çalışan terminal oturumlarını kapatır. SEDİR'in kendi sözü (28 Eylül):
*"Pilot geçiş için tetik sende değil bende: parolalar tamamlanınca Sultan'dan saat
alıp 'hazırım' yazacağım."* Tetiği onun elinden almak, açık oturumlarını habersiz
kapatmak olurdu.

## Sonuç

Bu PR **paketi** teslim eder, **kurulumu** değil. "Bütün kutularda çalışır" cümlesi
bugün **sınav kanıtına** dayanır, canlı kurulum kanıtına değil. Canlı kanıt pilot
geçişte üretilecek ve o gün üç yüzeyden ölçülüp yazılacak.
