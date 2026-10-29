<!-- kaynak: Sx duzen/cekirdek · Nexus kopyası bu dosyayı okur -->
# Cevapsız bırakma — filo-ortak muhaberat kuralı

> Sultan, 2026-09-06: *"tüm containerlarda şu gelenek olmalı — bir yerden mesaj geldi mi
> cevapsız bırakmamalı, cevabı tetikle gönderebilmeli."*

## Niçin var (ölçüldü 2026-09-06)
Hat çift yönlüydü, **zil tek yönlüydü**. Merkez bir odaya yazınca oda anında dürtülüyordu;
oda merkeze yazınca paket `_agents/handoff/gelen-<oda>/` altına iniyor ve **kimse
uyandırılmıyordu**. Bugün merkezde 253 birikmiş cevap ölçüldü. Ayrıca odalar cevap
yazabildiklerini bilmiyordu: BEŞİR merkezden mektup alıyor, ama geri yazma yolunu
sormuyordu — çünkü hiçbir kimlik belgesinde yazmıyordu.

## Kural (üç madde, hepsi zorunlu)
1. **Gelen mesaj cevapsız kalmaz.** Sana bir mektup ulaştıysa — gelen kutusuna düştüyse ya
   da pencerene dürtü geldiyse — okuduğunu ve ne yapacağını **yazılı** olarak bildirirsin.
   "Okudum, şu an başka iştey, X saatte dönerim" da geçerli bir cevaptır; **sessizlik değildir**.
2. **Cevap kalıcı kanaldan gider.** Cevabını kendi odanın `0-teslimat/giden/` kutusuna yaz.
   Merkez onu toplar ve **alıcıyı dürter** (`oda-cevap-zili.sh`). Ne zaman: merkezin gelen
   kutusuna düşen tetiğin başlığı `KURYE:` ile başlıyorsa dakika 14 ve 44'teki tetik turu alır
   (en geç 30 dk); tetiksiz ya da ön-eksiz mektup her saat dakika 35'teki süpürmede alınır
   (en geç 60 dk; `oda-kurye-cron.sh --supur`). Kopyan silinmez — kutu dolu görünür, bu
   taşınmadı demek değildir; alındığının kanıtı `0-teslimat/teslimat.log`'daki `merkez-aldi`
   satırıdır. Konuşma penceresine yazıp bırakmak teslim SAYILMAZ.
3. **Başlık adres taşır.** Dosyanın ilk satırı şu biçimdedir:
   `# GÖNDEREN → ALICI — konu`
   Adres yoksa zil **kimseyi dürtmez** ve dosya "adressiz" diye kütüğe düşer. Bu bir biçim
   kaprisi değil: alıcısı belirsiz mektubu herkese dağıtmak, kimseye dağıtmamakla aynı şey.

## Sınır (dürüstlük)
- Zil **taşımaz, silmez, cevap üretmez** — yalnız uyandırır. Kalıcı işaret zaten yerindedir.
- Alıcının penceresi kapalıysa **"ulaştı" denmez**: kütük "ulaşmadı" yazar, dosya yerinde
  durur, bir sonraki turda yeniden denenir. Sahte-yeşil yasaktır.
- Odalar birbirini göremez (İ1). Oda→oda mesaj merkez üzerinden sevk edilir
  (`oda-tetik.sh sevk`); bu zil yalnız **oda→merkez** yönünü kapatır.
