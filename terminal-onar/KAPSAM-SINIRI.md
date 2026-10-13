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

---
# Pano köprüsü (2.3.0 · 13 Ekim 2026) — neyin kanıtı var, neyin yok

## VAR
- Kapı birim sınavı PN1-PN14 (sahte ttyd: düz · gzip · `</body>`siz · json · sıkıştırılmış · KAPI_PANO=0), mutasyon M14-M19.
- `pano-sinav.mjs`: GERÇEK Chromium + GERÇEK ttyd 1.7.7 + GERÇEK tmux (mouse on · set-clipboard on) + iş alanındaki kapı +
  sahte resim dinleyicisi. Resim yapıştır → yol kabukta · 2600px PNG → 2000px WebP · metin yapıştırma dokunulmamış ·
  OSC 52 (uygulama ve FARE SEÇİMİ) → tarayıcı panosu · Cmd+C ipucu · Shift-sürükle seçimi · köprüsüz olumsuz kontrol ·
  eski/yeni tarayıcı eklentisiyle birlikte yaşama.
- CANLI: `code` kutusunun gerçek ttyd soketi + gerçek tmux + gerçek 8391 dinleyicisi üzerinden (iş alanındaki kapı :17681,
  koltuk `sinav-pano`): dosya gelen kutusuna indi, yol gerçek koltukta, OSC 52 ve fare seçimi panoya indi.

## YOK
- **maiset** (ya da başka bir kutu) üzerinde canlı ölçüm: kurulu kapı ortak dizinden koşar; birleşme + beceri senkronu +
  kapı yeniden başlatma olmadan yeni kod oraya inmez. Birleşmeden sonra ölçülecek.
- Sultan'ın kendi tarayıcısı/Tampermonkey kurulumu: eklenti 0.10 kutuların `.cc-images/` dinleyici kopyasına dağıtılmadan
  tarayıcı eski 0.9'u koşar (ttyd sayfasında yalnız fazladan kırmızı bildirim; köprü yine çalışır).
- Kokpit çerçevesi içinde pano yazma izni (`allow="clipboard-write"`) — kokpit tarafı.

## Birleşme SONRASI doğrulama adımı (üretim kapısı — bu PR'ın yapısal olarak yapamadığı)
Kurulu kapı ortak `/config/.claude/skills/terminal-onar` dizininden koşar (bütün kutular aynı dizini görür); bir kutuya
"deneme" diye kurmak hepsine kurmaktır → birleşmeden önce üretim kapısında ölçüm **yapılamaz**, bu bir eksiklik değil
sınıfın tanımıdır (dış yüzey → karar Sultan'ın). Birleşince sırayla:
1. `node sync-skills.mjs --dry-run` → yalnız `terminal-onar` kur (toplu `--apply --force` YASAK, bkz. known-errors "Beceri senkronu").
2. Mahrem olmayan bir kutuda (maiset) kapıyı yeniden başlat: `komut.sh onar --web-yenile` (ya da bekçi 1 dk içinde).
3. Ölç: `curl -s https://terminal.mmepanel.com/maiset/tty/` (girişli) gövdesinde `data-kapi-pano` VAR mı; sonra
   `_agents/fabrika/kanit/terminal-pano/canli-olcum.mjs` başındaki `P`'yi o kutunun kapısına çevirip koş (C0-C4).
4. Eklenti 0.10'u kutuların `.cc-images/cloudtop-terminal-image.user.js` kopyasına dağıt (cloudtop PR #600 birleşince);
   Sultan'ın tarayıcısı `@updateURL` ile çeker. 0.9 kaldığı sürece ttyd sayfasında fazladan "✗ HTTP 404" bildirimi görünür,
   köprü yine çalışır.
