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
4. **5 ve E değilse adım 2'ye dön:** düzelt → yeniden kanıtla → yeniden gönder.
   - Tavan **3 tur**. İlerleyen işe (puan yükseldi **ve** açık bulgu azaldı) **+1**. **Dört mutlak.**
   - Üçte 5'e ulaşamayan iş "**tıkandı + üç yol**" raporuyla gelir: devam et (gerekçe) · kapsamı daralt · geri al.
     Sonsuz düzelt-kanıtla-gönder döngüsü yasak (3-strike'ın fabrikadaki karşılığı).
5. **Merge:**
   - Kart **sınıf** taşıyorsa (geri alınamaz · para · dış yüzey · yetki) → **Sultan**, `pr-onay` tek soru. Ajan
     onay yazamaz (A06).
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
