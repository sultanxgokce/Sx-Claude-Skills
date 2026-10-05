---
name: gun-ortasi
description: Gün ortası planı — sabahki plan (ya da günün işleri) erken bittiğinde "elde kalan iş var mı?" sorusunu ÖLÇEREK cevaplar; kalan işi dağınık kaynaklardan (plan çıpası, kartlar, konum çapaları, bağımsız göz raporları, gelen kutusu) bulup doğrular ve süzer; kalmadıysa kutunun ana hedeflerine bağlı, ölçülmüş bir boşluğu kapatan 2-3 geliştirme fikri önerir ve Sultan'ın seçimiyle günün ikinci yarısını planlar. Tetik: "/gun-ortasi", "plan bitti ne yapalım", "iş kaldı mı", "gün ortası planı", "yapacak iş kalmadıysa ne geliştirelim".
version: 1.0.1
---

# /gun-ortasi — gün ortası planı (ölç → doğrula → süz · yoksa fikir → sun → çıpa → icra)

## Niçin var (Sultan-direktifi 2026-10-02)

*"Bizim /gunluk-plan komutumuz var ama bazen yaptığımız plan gün ortasında veya sabah tüm
işler bitiyor. Yapılacak iş kaldı mı, kaldıysa onları araştırıp bulması, kalmadıysa da genel
amaç ve hedeflerimize yönelik katma değeri yüksek fikirler ve geliştirmeler yapmamızı planlayacak
bir gün ortası planı skill'i lazım."*

`/gunluk-plan` günü AÇAR; `/gun-ortasi` günün ikinci yarısını açar. Gün ortasında listeler boşalmış
GÖRÜNÜR, oysa kalan iş çoğu zaman dağınıktır: inceleme notlarında, konum çapalarının "açık" satırlarında,
okunmamış mektuplarda. Bu beceri onları toplar; gerçekten hiçbir şey kalmadıysa HEDEFE bağlı fikir üretir.

## 🔴 Değişmezler

**`/gunluk-plan` SKILL.md'deki değişmezlerin TAMAMI aynen geçerlidir** (ölçmeden madde yok · yeni defter yok ·
A06 · Sultan-dili · kapasite dürüstlüğü · kuyrukta iş varken durma · ÇIPA ÖNCE COMPACT SONRA). Buraya
KOPYALANMAZ — kopya ilk değişiklikte bayatlar. Bu becerinin EKLERİ:

1. **Aday ≠ iş.** `kalan.sh` ADAY listesi basar. Her aday plana girmeden **hâlâ açık mı** diye kodda /
   son commit'te / son raporda doğrulanır (ADIM 2). Kapanmış adayı plana yazmak = hafızadan madde.
2. **"Ölçemedim" ≠ "iş yok".** Bir kaynak ölçülemediyse (#OZET'te `?`) "kalan iş yok" denmez; söylenir.
3. **Fikir hedefe VE ölçüme bağlanır.** Her fikir hedef dosyasından bir satıra ve bu turda ölçülmüş bir
   sinyale bağlanır. İkisinden biri yoksa o fikir değil dilektir, yazılmaz.
4. **Gün ortası kapasitesi:** en çok 3 madde (günün yarısı kaldı); fikir en çok 3.

## ADIM 1 — ÖLÇ (dokuz kaynak, tek komut)

```bash
bash /config/.claude/skills/gun-ortasi/scripts/kalan.sh                  # pencere: son 3 gün
GUN_ORTASI_GUN=7 bash /config/.claude/skills/gun-ortasi/scripts/kalan.sh # daha geniş pencere
```

| # | Kaynak | Ne arar |
|---|---|---|
| 1 | BUGÜNÜN plan çıpası (`gunluk-plan/cipa.sh oku`) | `- [ ]` ve `- [~]` maddeler; başka günün çıpası sayılmaz |
| 2 | fabrika kartları | açık kart (tıkandı = tavanda karar verilmiş → ayrı sayılır) |
| 3 | konum çapaları (`*-durum.md`, son N gün) | açık / kalan / ayrı kart / SARI / SIRADA satırları |
| 4 | bağımsız göz — her işin SON raporu | `BAGIMSIZ-GOZ-kor-*.md` ya da fabrika `DENETIM-*.json`; 5·E değilse ya da kapanmamış bulgu varsa |
| 5 | gelen kutusu | okundu kaydında TAM adıyla olmayan her mektup |
| 6 | layiha defteri | inşa bekleyen aktif layiha |
| 7 | Sultan'ın kapısı | Sultan'ı bekleyen kart |
| 8 | hedef dosyaları | ANA-HEDEF.md · CLAUDE.md "Amaç" (fikirlerin bağlanacağı yer) |
| 9 | ortam | dal · commit'siz dosya · açık PR |

Son satır: `#OZET cipa_acik= cipa_kapali= kart= tikandi= capa_acik= goz_acik= gelen= layiha= kapimda= commitsiz= pr= olcemedim=`
— ölçülemeyen alan `?`'dir, `0` değil. Kutuya özgü düzen (ör. `0-teslimat/`) yoksa o bölüm "ölçemedim" basar.
`goz_acik`: md raporunda BULGU başına, DENETIM json'da RAPOR başına sayılır (json bulgu listesi taşımaz).
Çıpada `- [-]` = geri alınmış madde: açık da kapalı da sayılmaz.

## ADIM 2 — DOĞRULA (aday → gerçek iş)

1–5. bölümlerdeki her aday için TEK soru: **bugün hâlâ açık mı?**
- Kod/sınav adayı: ilgili dosyada `grep`; işin sonraki commit'leri (`git log --oneline -- <dosya>`).
- İnceleme bulgusu: aynı işin daha sonraki raporu/commit'i "kapandı" diyor mu? (Araç yalın "KAPANDI"yı
  zaten düşürür; "KISMEN KAPANDI" açık kalır.)
- Mektup: cevap mı istiyor, bilgi mi?

Kapanmış aday **düşer** (tek satır gerekçe: "kapandı, <commit/rapor>"). Doğrulanamayan aday SARI kalır.

## ADIM 3 — SÜZ (iş KALDIYSA)

`/gunluk-plan` ADIM 2'deki **dört elek** aynen (kapanabilir mi · kilidi açıyor mu · bozuk mu eksik mi ·
Sultan hisseder mi), gerekçeli. Doğrulanmış kalan iş ≥1 ise fikir üretilmez — önce eldeki iş biter.

## ADIM 4 — FİKİR (iş KALMADIYSA)

Ancak doğrulanmış açık iş **sıfırsa** ve ölçülemeyen kaynaklar Sultan'a söylendiyse:

1. 8. bölümden **bugün hâlâ geçerli** 2-3 hedef satırı seç.
2. Her hedef için kutunun kendi ölçümüyle bir **boşluk** bul: "hedef X diyor, ölçü Y gösteriyor".
   Sinyal örnekleri: gece/sabah turlarının son sonuçları · bekçi seyri · kapı paketlerinin kırmızıları ·
   defter büyüme hızı · en sık tekrar eden hata etiketi · hiç kullanılmayan araç · disk/bellek eğilimi.
3. Boşluğu kapatacak **en küçük işi** yaz (günün kalanında kapanabilecek); büyükse ilk dilimini.
4. Her fikre üç şey: **ne** · **neden şimdi** (ölçüm) · **bitince ne değişir** (Sultan-dilinde).

## ADIM 5 — SUN (sabit format, kopyalanabilir)

````
```
🕛 GÜN ORTASI · <YYYY-MM-DD HH:MM>
sabah planı: <N> madde · <N> kapandı · <N> kaldı      (çıpa yoksa: "sabah çıpası yok")
ölçüm: <N> açık kart · <N> aday (<N> doğrulandı, <N> kapanmış çıktı) · <N> okunmamış mektup · ölçülemedi: <liste|yok>

KALAN İŞ (sırayla — yoksa "yok, doğrulandı"):
1. <Sultan-dilinde tek cümle> — <bitince ne değişir> · <kim>

FİKİR (yalnız kalan iş yoksa, en çok 3):
• <ne> — hedef: <hedef satırı> · ölçüm: <sinyal> · bitince: <ne değişir>

SENDE (tek tuşluk):
• <karar/onay> — <niçin sen>

BUGÜN DEĞİL (gerekçesiyle):
• <aday> — <kapandı / büyük / bekliyor: gerekçe>
```
````

Planı sunduktan SONRA ama soruyu sormadan ÖNCE ADIM 6'nın çıpa adımını yap; ardından **tek soru**
(AskUserQuestion): *"Günün kalanında böyle mi ilerleyelim?"* — 2-4 şık, biri `(önerim)`.

## ADIM 6 — ÇIPA (plan sunulur sunulmaz, SORUDAN ÖNCE) ve İCRA

`/gunluk-plan` ADIM 0 ile aynı sıra: önce çıpa, sonra soru. Çıpaya önerilen maddeler yazılır; Sultan başka
bir şık seçerse seçilmeyenler **geri alınır** (silinmez — iz kalır, akşam kapanışı sahte açık iş görmez).
Gün ortası maddeleri **`G<n>) metin`** etiketiyle yazılır (zorunlu); geri-al yalnız tam etiket alır (`"G2)"`),
böylece sabahın `1) …` maddelerine dokunamaz. Geri alınmış madde yeniden eklenirse yeniden açılır.
Aynı gün ikinci kez `/gun-ortasi` koşarsa numara **kaldığı yerden sürer** (G3, G4…): aynı etiket başka metinle
reddedilir (rc=2), birden çok maddeyle eşleşen geri-al hiçbirine dokunmaz. Madde metninde `|` kullanılmaz (ayırıcıdır).

```bash
# bugünün çıpası VARSA: sabahki maddelere dokunmadan gün ortası maddelerini ARKASINA ekle
bash /config/.claude/skills/gun-ortasi/scripts/cipa-ekle.sh --plan "G1) … | G2) …"
# Sultan başka şık seçtiyse: seçilmeyen önerileri geri al, seçileni ekle (aynı madde iki kez yazılmaz)
bash /config/.claude/skills/gun-ortasi/scripts/cipa-ekle.sh --geri-al "G2) | G3)"
# çıpa YOKSA (sabah /gunluk-plan koşmadı): gün ortası planı günün çıpası olur
bash /config/.claude/skills/gunluk-plan/scripts/cipa.sh yaz --plan "G1) … | G2) …"
```

`cipa.sh yaz`'ı çıpa VARKEN kullanma — sabahki çıpayı siler. Onaydan sonra maddeleri sırayla yürüt (kutunun
iş hattı geçerlidir); her madde bitince `cipa.sh tazele --madde <n> --durum kapandi --not "<kanıt>"`.
Bağlam eşiği geçerse: `cipa.sh compact-onerisi` (çıpa diskteyse öneri üretir) → Sultan'a sor.
Akşam `/gunluk-plan kapanis` sabah + gün ortası maddelerini birlikte okur.

## Sınırlar / dürüstlük

- Bu beceri iş ÜRETMEZ: kalan işi BULUR; yoksa hedefe bağlı fikir ÖNERİR. Seçim Sultan'ındır.
- `kalan.sh` salt-okurdur. `cipa-ekle.sh` yalnız bugünün çıpasına ekler/geri alır; çıpa yoksa/eskiyse yazmaz (rc=1);
  `cipa.sh` ile aynı kilidi (`gunluk-plan-cipa.md.kilit`) alır, iki araç birbirini bekler — kilit dosyası çıpanın yanında kalıcıdır (cipa.sh'ın tasarımı).
- Dünün çıpasındaki açık maddeler bu becerinin konusu değildir; onları `/gunluk-plan kapanis` ertesi güne taşır.
- `/gunluk-plan kapanis` bugün `- [-]` (geri alındı) durumunu ayrıca tanımıyor; satırın sonundaki "→ GERİ ALINDI" okunur.
- 3. ve 4. bölüm metin taraması yapar: desene uymayan açık iş kaçabilir, desene uyan kapanmış iş görünebilir
  — ADIM 2 bu yüzden zorunludur.
- Sınav: `bash scripts/kalan.test.sh` (hermetik; gerçek kutuya dokunmaz).

## Sürüm notları
- **1.0.1 (2026-10-05, MUAVİN · kurulum turu):** `cipa-ekle.sh` çıpa yolunu **kendisi
  türetmeyi bıraktı**, artık sahibine soruyor (`gunluk-plan/scripts/cipa.sh yol`, aynı gün
  eklenen tek-kaynak komutu). Niçin: `cipa.sh` 2026-10-05'te çıpayı **ajan başına** dosyaya
  taşıdı (b0097); bu betik eski TEK dosyaya yazmaya devam ediyordu — yani ekleme kimsenin
  **okumadığı** bir dosyaya gidiyor ve 1.0.0'da eklenen "ortak kilit" düzeltmesi de fiilen
  ölüyordu (iki araç iki ayrı kilit dosyası; beklemesi gereken ekleme **9 ms**'de geçti).
  Sorulamazsa **fail-closed** (rc=1): tahminle yazmak, sessizce yanlış dosyaya yazmaktır.
  `kalan.test.sh` de sabit yolu bıraktı, yolu araçtan soruyor — sınav kendi varsayımını
  değil aracın davranışını ölçsün. Kurulumdan önce ölçüm: **21 geçti / 8 kaldı**;
  onarımdan sonra **29 geçti / 0 kaldı** (tek kök neden).
- **1.0.0 (2026-10-02, NÂZIR/MÜDÜR):** ilk sürüm — dokuz kaynaklı ölçüm · aday→gerçek iş
  doğrulaması · iş yoksa hedefe bağlı fikir · çıpa ekleme/geri alma · 29 kapı.
