# ÇALIŞMA HATTI — her iş bu beş adımdan geçer. Adım atlanmaz, sıra değişmez.
<!-- Bu dosya her depoda BİREBİR AYNIDIR. Elle düzenlenmez; kaynak: yazilim-fabrikasi becerisi (sablon/FABRIKA.md).
     Kutuya özel kural buraya değil .claude/skills/ katmanına girer. Denetim: fabrika-kur.sh denetle -->

F=/config/.claude/skills/yazilim-fabrikasi

0. KABUL — iş kartı dört satır: kim istedi · kim aldı · ne zaman · kanıt nerede olacak.
   Sınıf sor: geri alınamaz mı · para mı · dış yüzey mi · yetki genişletiyor mu → biri evet/emin değilsen SULTAN.
   Şüphede sınıf YUKARI. Sınıfsız iş ekipte biter, gün sonu özetine girer. (adım: $F/adimlar/0-kabul.md)

1. İZOLE — `bash $F/scripts/is-alani.sh ac <iş>` → origin/main'den taze alan. Ana dalda ASLA çalışma.
   Başkasının alanına, dalına, kayıtsız işine dokunma. Açık PR'la dosya çakışıyorsa DUR ve sor.
   Çıkarken: kayıtsız iş varsa `kapat` reddeder — kaybetme, commit'le. ($F/adimlar/1-izole.md)

2. İNŞA — yapı kuralına uy: yüzey (niçin/ne zaman) · servis (nasıl) · depo (veriye dokunan tek yer).
   Mimariyi her seferinde yeniden icat etme. Tekrar eden mantık 2. çağıranda servise çıkar, 1.'de değil.
   Sultan'a görünen her metin Sultan-dilinde. Üretilmiş dosyaya elle yazma. ($F/adimlar/2-insa.md)

3. KANITLA — görünüm: önce/sonra kare (gerçekçi veriyle) · akış: kare dizisi ya da video · görünmez: ölçüm çifti.
   "Çalışıyor / yaptım / bitti" kanıt DEĞİLDİR. Ölçemediğin şey SARI'dır, yeşil değil. Komutu boru arkasına koyma.
   Kanıt kutuda kalır (dış yükleme yok). Kanıtsız adım 4 YOK. ($F/adimlar/3-kanit.md)

4. GÖNDER — PR'ı `pr-onay` ile aç. Bağımsız göz: YAZANDAN FARKLI model inceler (Claude ↔ Codex ↔ Fable).
   Puan iki satır: KOD İYİ Mİ 0-5 · DOĞRU ŞEY Mİ E/H (talep ⟷ kanıt yan yana). Bulgu da kanıt ister.
   5 ve E değilse adım 2'ye dön. Tavan 3 tur; ilerleyen işe (puan↑, açık bulgu↓) +1; DÖRT mutlak.
   Tıkanınca: "tıkandı + üç yol" raporu (devam · daralt · geri al). Sonsuz döngü yok.
   Merge: sınıf işi SULTAN; sınıfsız iş kutu reisi → deftere kanıt+puan+damga. ($F/adimlar/4-gonder.md)

Proje kuralları (test · lint · paket yöneticisi): BURAYA YAZILMAZ — deponun kendi dosyasından okunur, tahmin edilmez.
Tıkanma: 3 mektup ya da 24 saat → reis → SERDAR (yalnız kutular-arası) → Sultan.
