# 4 · GÖNDER — PR, bağımsız göz, puan, dönüş, merge

## Sıra
1. **PR'ı `pr-onay` açar** (var olan kapılar: tip kontrolü · testler · temizlik; marker yalnız kapılar koştuysa).
   Gövde: iş kartı (adım 0) + "Kanıt" başlığı (adım 3 manifesti) + değişen ne, neden.
2. **Bağımsız göz** (`denetci.sh <PR>`, F1; şimdilik elle): **yazandan farklı model** inceler.
   Yazan Claude → Codex (`codex exec`; bu kutuda oturum açık, 22 Eyl ölçüldü) · yazan Codex → Claude ·
   Fable ↔ Claude da geçerli. Dış servis (Greptile) yok — Sultan K1.
   Denetçi üç şey alır: diff · KANIT.json · iş kartı. Kodu **ve** talep ⟷ kanıt kıyasını yapar; kanıt manifestini
   de denetler (elle yazılmış manifest = ret).
3. **Puan iki satır** (`DENETIM.json`):
   - **KOD İYİ Mİ** 0-5: ciddi hata → 2 · uygulama sorunları → "önce bunları çöz" · yalnız rötuş → 5. **5 = üretime hazır.**
   - **DOĞRU ŞEY Mİ** E/H: iş kartındaki talep ile kanıt yan yana. Kod doğru ama yanlış şeyi yapmışsa **H**;
     puan bunu yakalayamaz, bu sütun onun için var (videonun itiraf ettiği ve kapatmadığı delik).
   - `bulgular[]`: her bulgu kanıtlı (satır/kare/ölçüm) — "bulgu da kanıt ister".
   Puan bağlamsaldır: ödeme akışındaki 3 ile bir betikteki 3 aynı değil; puan onay kutusu değil, sinyaldir.
3b. **Canlı kanıt dağıtımdan sonra geliyorsa (cron/servis/sunucu işi, kart `--canli e`):** sıra **birleştir → kur → canlı kayıt**.
   Kapı canlı kaydı birleşmeden önce istiyorsa ve kur adımı birleşmeden sonra/başkasındaysa kilit çıkar. Çıkış **kapıyı gevşetmek değil borcu yazmaktır**:
   `kart.sh canli-borc <iş> --yazan <sahip> --gerekce "…"` → kapı borçla geçer. Sınıflı işte de borcu kartın sahibi (reis) yazar;
   araç reis `canli-borc` kararını borçla birlikte karta işler (0.19.0, kural `0-kabul.md` "Sınıflı iş"); eski Sultan `canli-borc`
   kaydı geçerli sayılır; Sultan vetosu (`izin-durum = dur`) varsa borç yazılmaz. Ajan Sultan adına yazmaz (A06).
   → birleştir → kur → `kanit.sh canli …` (borçtan SONRA, bağlı yeşil) → `kart.sh bitti`. Kart o zamana dek `canli-borclu`dur (bitti değil); `kart.sh borclar` 24 saati aşanı kırmızı gösterir.
4. **5 ve E değilse adım 2'ye dön:** düzelt → yeniden kanıtla → yeniden gönder.
   - Tavan **3 tur**. İlerleyen işe (puan yükseldi **ve** açık bulgu azaldı) **+1**. **Dört mutlak.**
   - 🔴 **Tavan SAYILI tura uygulanır** (15 Eki 2026, görev WC3VBZAA). Bir bulgu gerçek olabilir ama bu
     kutuda **ölçülemez/düzeltilemez** olabilir: Sultan'ın Mac'i, canlı yetki, dış hesap, fiziksel cihaz.
     Denetçi onu `agirlik: "kutu-disi"` + `kutu_disi_yuzey` ile yazar; o bulgu **puanı düşürmez** ve
     bulgularının **hepsi** kutu-dışı olan tur **tavandan düşmez**. Ölçülmüş vaka: cloudtop #635 dört
     turunu "canlıda kurulu değil" bulgusuyla yaktı, kod kusursuzdu ve iş hiç ilerlemedi.
     · Muafiyet bedelsiz değil: **yüzey yazılmazsa sınıf `uygulama`ya düşürülür** ve düşürüldüğü kayda
       geçer — "kutuda ölçemedim" etiketi bedava tur kazandırmaz.
     · Muafiyetin karşılığı izlenebilirliktir: bulgular `KUTU-DISI.jsonl`'a (append-only, tekrarsız)
       yazılır ve işin sahibine gider.
     · Muafiyet sınırsız değil: üst üste **2**'den fazla yakmayan tur olursa iş "**kutuda
       ilerletilemiyor**" ile durur (rc=4) — bu bir kod tıkanması değildir ve çaresi "devam" değil
       **yüzeye gitmek**tir. Tavan: `DENETCI_KUTU_DISI_TAVAN`.
   - Üçte 5'e ulaşamayan iş "**tıkandı + üç yol**" raporuyla gelir: devam et (gerekçe) · kapsamı daralt · geri al.
   - **Kapsamı daralt = hattın adımıdır, elle yeni kart/dal/PR açmak değil** (0.8.0, PCP7J): `kart.sh daralt <iş>
     --kalan "<kalan bulgu>" --cumle "<bu PR'ın yaptığı>" --oturum <ref>` → kalan bulgu aynı sahip ve sınıfla yeni karta,
     bu kartın cümlesi daralır, tur sayacı sıfırlanır (aynı dal, aynı PR sürer), kapı daraltma sonrası en az bir 5/E
     tur ister. Daraltma her kartta reis kararıyla kendiliğinden işlenir (sınıflı dahil — 0.19.0; kartta kullanılmamış eski
     bir Sultan `daralt` kararı varsa o tüketilir); vetolu kartta daraltma yok.
   - Göze giden **istemin tamamı** (şablon + kart + kanıt manifesti + ölçüm çıktıları + fark + önceki tur) kırpma
     tetiğini (120 KB) aşıyorsa denetçi kırpıp denetlemez, "**İŞİ BÖL**" der, parça parça bayt basar ve tur yakmaz:
     fark büyükse iş bölünür (daralt), ölçüm şişkinse ölçümler küçültülür; kırpık istemle verilen puan puan değildir
     (PR #329 ve cloudtop #712 dersi — #712'de fark 73 KB'la geçmiş, istem 129 KB olup kırpılmıştı).
     Sonsuz düzelt-kanıtla-gönder döngüsü yasak (3-strike'ın fabrikadaki karşılığı).
5. **Merge:**
   - Kart **sınıf** taşıyorsa da → **kutu reisi** (0.19.0, Sultan D1 22 Eki; kural `0-kabul.md` "Sınıflı iş"): Sultan vetosu
     yoksa (`kart.sh izin-durum` ≠ `dur`) reis birleştirir, `kart.sh bitti` kararı karta yazar; kapının vetoyu ölçmesi ikinci
     kartta (`fabrika-merge-reise-kapi`). Dağıtım / canlıya alma Sultan eli. Ajan onay yazamaz (A06).
   - Sınıfsız iş → **kutu reisi** merge eder; şart: 5 + E + kanıt manifesti + CI yeşil. Deftere `kayit-damgasi`
     ile kanıt+puan+damga; gün sonu özetinde "içeride bitirdiklerimiz". (Geçiş: Nexus'ta ilk iki hafta yine
     Sultan'a sorulur — Sultan 22 Eyl.)
   - CI kırmızı → merge yok, çıplak çıktıyla rapor.
6. **Kapanış:** `is-alani.sh kapat` · kart "bitti" satırı + tetikli mesaj · `karne.sh` (F1) puanı deftere yazar.

## Puan kalibrasyonu — puan da bir beyandır
Denetçinin verdiği her 5 deftere girer (`karne.jsonl`: PR · model · puan · E/H · tarih). O iş sonradan kırılırsa
"kırıldı" damgası. Haftalık soru: **"5 alanların kaçı kırıldı?"** — sayı yoksa puanlama kanıt değil süstür.
Aynı defter tur sayısını ve süreyi tutar; iki hafta sonra "ortalama kaç tur, kaç iş tıkandı, maliyet" Sultan'a gider.

## Çapraz model neden (ve bedeli)
Ajan kendi işini incelemede iyi değildir ("vay be çok iyi olmuş"). Farklı model açıkları görür. Bedeli: her iş en az
iki model koşumu, işi yavaşlatır. Kabul ediyoruz: "yaptım, yaptım" döngüsüne girip haftalar kaybetmektense
baştan biraz yavaş.
