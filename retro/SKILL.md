---
name: retro
description: Haftalık retro — araç ajanın haftasını ÖLÇER (NOTES · fabrika kartları · bağımsız göz turları · kaçışlar · boşta zilleri), ajan 5 başlığı kendi gözüyle YORUMLAR (ne bitti · nerede zaman kaybettim ölçüyle · hangi araç/kural yavaşlattı · ne öğrendim · merkeze önerim); çıktı _agents/handoff/retro/<YYYY-Www>/<AJAN>.md lint'li. Merkez kipi kutu retrolarını toplar (OK/GEÇERSİZ/EKSİK/ÇALIŞMADI), MERKEZ.md iskeleti kurar; her öneri → gorev_ ya da → RED damgası alır (süzüm kanıtı); görev defterindeki 'havuz' kayıtları da (bulgu.sh havuz-cek köprüsü) aynı damga kuralıyla "Havuz süzümü" bölümüne girer. Tetik: "/retro", "haftalık retro", "haftanın dersleri", "retro yaz", "merkez retrosu".
version: 1.3.0
---

# /retro — haftalık retro (araç ölçer · ajan yorumlar · merkez toplar · süzüm kanıtlanır)

## 🆕 1.3.0 · merkez havuzu da süzer — görev defterindeki 'havuz' kayıtları MERKEZ.md'ye (23 Eki · 11F0Z0 · Sultan D1 21 Eki "Eleme turu + bulgu kapısı")
Bulgular 22 Eki'den beri merkezî Görev Defteri'ne **'havuz'** durumunda düşer (`bulgu` 0.5.0) ve haftalık süzmede görev olur; retro
merkez kipi havuzu görmüyordu → süzüm listesi yalnız kutu önerilerini taşıyor, havuz kayıtları hafta kapanışında hiç sorulmuyordu
(22 Eki anlık sayım: 6 ham kayıt). Artık `merkez` köprüden (`bulgu.sh havuz-cek`, eşleme TEK orada; `RETRO_BULGU_SH` ile değişir,
varsayılan kardeş beceri `<skills>/bulgu/scripts/bulgu.sh`) **durum=ham** kayıtları okur ve MERKEZ.md'ye araç bölümü olarak yazar:
```
## Havuz süzümü — görev defterindeki 'havuz' kayıtları (`bulgu.sh havuz-cek` · durum=ham) · damga: `→ gorev_<kendi id>` (Sırada'ya alınır) ya da `→ RED: <gerekçe ≥10 karakter>`
- gorev_01M5M55BRC0V3G8A200PYTVZV9 · mihenk: PR'da testleri koşan küçük bir iş akışı gerek →
```
Damga kuralı kutu önerisiyle aynıdır; havuzdaki kayıt **kendisi görev** olduğundan `→ gorev_<kendi id>` = Sırada'ya alındı demektir,
`→ RED: <gerekçe>` = havuzda elendi. `suzum` damgasız/biçimsiz havuz satırını **kırmızı** sayar. `--yenile` eski havuz damgalarını
(başlık değişmediyse) ve elle bölümleri korur; başlığı değişen kaydın damgası düşer ve söylenir; havuzdan çıkan (defterde artık
'havuz' olmayan) kaydın satırı düşer ve söylenir. **Köprü ölçemezse** (jeton yok · defter ulaşılamadı · köprü dosyası yok) `merkez`
MERKEZ.md'yi **yazmaz**, `◻ ÖLÇÜLEMEDİ … (0 havuz DEĞİL)` basar, rc 3 — sessiz "0 havuz" yok (K01). Bozuk köprü satırı sayılır ve
notta söylenir. `suzum` havuz satırlarını MERKEZ.md'den okur (köprüyü çağırmaz); bölüm yoksa (1.3.0 öncesi dosya) uyarır, geriye
dönük kırmızıya çevirmez. Kanıt: `retro.test.sh` T6h2 · T12a-z3 · T13a-m + mutant M16-M19 (köprü çağrısı silinince · ham süzgeci
kalkınca · köprü yokluğu boş listeye çevrilince · damga denetimi kalkınca — dördü de ısırıyor).

## 🆕 1.2.0 · kart ve göz ölçüsü kutunun BÜTÜN depolarından (20 Eki · CQ46Y + NFS16 · retro W42 BERİD Ö1 + HENDESE Ö2)
W42 retrosu yalnız çağrıldığı depoyu (Nexus) sayıyordu; ajanın Sx ve cloudtop kartları görünmüyordu (ölçüm: MİRAHUR W42 9 → 46 kart,
HENDESE 5 → 14, BÂNİ 25 → 128). Taranan depolar: `RETRO_DEPOLAR` (':' ayraçlı) verilirse o liste; yoksa `RETRO_DEPO_KOKU` (varsayılan
`/config/projects`) altında `_agents/fabrika/kartlar` olan birincil depolar — izole kutuda bu kutunun kendi depolarıdır, `_wt/…`
çalışma kopyaları sayılmaz, aynı depo bir kez. Göz turları disk ∪ `origin/main` ağacından sayılır: birincil kopya bayat ya da başka
dalda olabilir. Tablonun kanıt sütunu depo başına döker (`Nexus 9/3/2 · Sx-Claude-Skills 4/4/0 · …`). Kaçış defteri hâlâ KOK'tan.

## 🆕 1.1.0 · `doldur` — ajanın yorumunu iskelete araç yazar (20 Eki · KHX56 · retro W42 MİRAHUR Ö1)
`kutu` iskeleti paylaşılan ana ağaca yazar; ana dal kapısı (`ana-dal-kapisi.sh`) o ağaçta Edit/Write'ı reddeder — ajan iskeleti
dolduramıyordu (W42'de MİRAHUR elle kaçışla doldurdu). Kapı GEVŞETİLMEDİ; dolum araca verildi:
```
retro.py doldur <AJAN> --metin <taslak.md>      # ya da --metin -   (stdin)
```
Taslak yalnız `## 1 · …` … `## 5 · …` başlıklarını taşır (scratchpad'de yazılır). Araç: ölçüm bloğu ve imza satırlarını dosyadan
korur, metinde görürse **reddeder** (rc 2 — ajan ölçümü sahteleyemez) · `## 1 · ` öncesi metni yutmaz, reddeder · birleşik sonucu
lint'ler, geçmezse **yazmaz** (rc 1, dosya bayt bayt eski hâli) · geçerse atomik yazar. Aynı metin ikinci kez aynı baytları üretir;
`kutu --yenile` doldurulmuş dosyada çalışmaya devam eder. Kanıt: `retro.test.sh` T10a-r + mutant M8-M10.

## 🆕 1.0.1 · merkez --yenile elle yazılan bölümleri korur (19 Eki · kart retro-merkez-yenile-bolum-koru · gorev_01M58987YSBASEXV1MF7T2GJHP)
1.0.0'da `merkez --yenile` dosyayı iskeletten yeniden basıyor, yalnız süzüm damgalarını taşıyordu: Dersler/Görevler yer
tutucuya dönüyor, Kaçış gibi iskelette olmayan bölümler siliniyordu (19 Eki 01:0x W42 MERKEZ.md yedekten geri kondu).
Artık yalnız araç bölümleri (Katılım · Süzüm) yeniden yazılır; araç dışı her `## ` bölüm olduğu gibi taşınır. Kanıt:
`retro.test.sh` T9a-k + mutant M5.

## Niçin var (Sultan 17 Eki 2026 · beyan SERDAR)

Haftanın dersleri yalnız merkezin yorumuyla değil, **her ajanın kendi gözüyle** merkeze aksın; akış
sistemli olsun ki süzülsün; eksik retro varsa hafta kapanmasın. Ölçüm (17 Eki): ajanların kendi
"ders / zaman kaybı" satırı BÂNİ 11/100 · MUAVİN 1/21 · MİRAHUR 0 · MUHAKKİK 0 · BERİD 0 · HENDESE 0;
retro tamamen SERDAR ölçümüyle yapıldı — **ajan görüşü kanalı yoktu.** Bu beceri o kanaldır.

## 🔴 Değişmezler

1. **Araç ölçer, ajan yorumlar.** Ölçüm bloğunu `retro.py` yazar; elle yazılmış ölçüm bloğu olmayan
   dosya GEÇERSİZ (L3). Yorum satırı boş kalan başlık → dosya GEÇERSİZ (L4).
2. **Ölçemediğini sarı basar.** Kaynak yoksa hücreye `ÖLÇÜLEMEDİ: <sebep>` yazılır, `0` değil (K01).
   Tarihi çözülemeyen NOTES satırı sayılmaz, "tarihsiz N" olarak ayrıca basılır. Kaçış defteri ajan
   alanı taşımaz → sayı **kutu geneli**dir ve öyle etiketlenir. "Sultan-eli adımı" için kaynak yok → sarı.
3. **Zaman kaybı ölçüsüz geçmez.** Her `Z<n>)` maddesi `· ölçü: <sayı birim>` taşır (L5).
4. **Kapasite dürüstlüğü.** Merkeze öneri en çok 5 (L6). Uzun liste öneri değil kaçıştır.
5. **Kutu retrosunu ajan yazar; merkez yazamaz.** Kimin yazdığı **ölçülemez** (aynı git kimliği) —
   `_koltuk:` satırı beyandır, kanıt değil. Bu yüzden kural SERT değil ilkedir; merkez kipi eksik
   dosyayı **üretmez**, `EKSİK` basar ve zil düşürür.
6. **Süzüm damgası mekanik ve METNE bağlı.** Her kutu önerisi MERKEZ.md'de `→ gorev_<26>` (görev defterine girdi) ya da
   `→ RED: <gerekçe ≥10 karakter>` alır. Damgasız öneri = süzülmemiş = `retro.py suzum` kırmızı. Damga satırı öneri
   metnini de taşır: kutu metni sonradan değişirse damga **bayattır** (`suzum` kırmızı, `merkez --yenile` damgayı düşürür) —
   numara aynı kalsa bile eski onay yeni içeriği onaylamış sayılmaz. Damga MERKEZ.md'de yaşar — kutu dosyasına merkez dokunmaz.
7. **Yeni havuz kurulmaz.** Dosyalar `_agents/handoff/retro/<hafta>/`; dersler görev defterine, bulgu
   bulgu kanalına. Hafta kimliği ISO (`YYYY-Www`, Pazartesi–Pazar).

## Kutu kipi — her ajan, Cuma (zil düşer) ya da hafta içinde istediği an

```
python3 ~/.claude/skills/retro/scripts/retro.py kutu <AJAN> --koltuk <tmux hedefi> [--hafta 2026-W42]
#   → _agents/handoff/retro/2026-W42/<AJAN>.md iskeleti: ölçüm tablosu dolu, 5 başlık yer tutuculu
#   (dosya varsa rc=4; ölçümü yenilemek: --yenile — yorum satırlarına DOKUNMAZ)
# 5 başlığı ağaç DIŞINDA bir taslağa yaz (B/Z/A/D/Ö etiketleri, 1..n sıralı; Z'de "· ölçü:" zorunlu; Ö ≤ 5) ve ARACA yazdır —
# paylaşılan ana ağaçta Edit/Write ana dal kapısına takılır (1.1.0):
python3 ~/.claude/skills/retro/scripts/retro.py doldur <AJAN> --metin <taslak.md>   # lint'ten geçmezse yazmaz (rc 1)
python3 ~/.claude/skills/retro/scripts/retro.py lint _agents/handoff/retro/2026-W42/<AJAN>.md
#   rc 0 geçerli · 1 geçersiz (her hata L-koduyla listelenir) · 2 dosya yok
```

Ölçüm kaynakları ve kanıt yolları (kök = depo kökü; `--kok` ya da `RETRO_KOK` ile değişir):

| Kaynak | Nereden | Ne sayılır |
|---|---|---|
| NOTES mesaj satırı | `_agents/<ajan>/NOTES.md` | `[` ile başlayan satır; tarihi üstündeki son açık tarihten devralır |
| ders / zaman kaybı / tıkanma | aynı dosya | anahtar kelime (ders · zaman kayb · zorluk · tıkand · boşa) |
| kart açılan / bitti / tıkandı | `_agents/fabrika/kartlar/*.json` (`aldi` = ajan, aksansız eşleme) | `zaman` / `bitis` hafta içinde |
| bağımsız göz turu | `_agents/fabrika/kanit/<iş>/DENETIM-*.json` | ajanın haftalık kartları için toplam + ortalama |
| kaçış | `_agents/fabrika/kacis-defteri.log` | hafta içi satır — **kutu geneli** |
| boşta zili | `/config/.filo/bosta-bekcisi.log` (`RETRO_BEKCI_LOG`) | ajan adlı satır (TUR özetleri hariç) |
| Sultan-eli adımı | — | ÖLÇÜLEMEDİ (tanımlı kaynak yok) |

İzole kutu: aynı dosya, merkeze federe tetikle (`federe-tetik.sh gonder … retro-kutu`) gider; bu
becerinin işi dosyayı üretmek ve lint'lemektir, taşıma kalıbı ayrı iştir (MUAVİN).

## Merkez kipi — SERDAR, Cumartesi

```
python3 ~/.claude/skills/retro/scripts/retro.py merkez [--hafta 2026-W42] [--ajanlar A,B] [--haric SERDAR] [--yenile]
#   katılım: aile-registry.yaml uyeler (ya da --ajanlar) · her ajan için
#     OK (lint geçti) · GEÇERSİZ (lint kırmızı) · EKSİK (hafta içinde iz var, retro yok → zil) ·
#     ÇALIŞMADI (NOTES/kart izi yok → retro zorunlu değil; ilk hafta kapanabilsin diye)
#   → MERKEZ.md iskeleti: Katılım tablosu · Süzüm listesi (her öneri "→ " boş damgayla) · Havuz süzümü (görev defterindeki
#     durum=ham kayıtlar, `bulgu.sh havuz-cek` köprüsü · 1.3.0) · Dersler · Görevler
#   rc 0 herkes tamam · 1 KIRMIZI: EKSİK/GEÇERSİZ var · 3 SARI: ajan listesi yok (katılım ölçülemez) ya da havuz köprüsü
#     ölçemedi (MERKEZ.md yazılmaz) — fabrika rengiyle aynı
#   --yenile: yalnız ARAÇ bölümlerini (Katılım · Süzüm · Havuz süzümü) yeniden kurar, DAMGALARI KORUR; elle yazılan her ## bölüm
#     (Dersler · Görevler · Kaçış · serbest) olduğu gibi, yazıldığı sırada taşınır (1.0.1 — 1.0.0 bunları siliyordu)
#   RETRO_BULGU_SH=<yol>: havuz köprüsü (varsayılan kardeş beceri bulgu/scripts/bulgu.sh)
python3 ~/.claude/skills/retro/scripts/retro.py suzum [--hafta 2026-W42]
#   her Ö maddesi VE her havuz satırı → gorev_<26> ya da → RED: <gerekçe> aldı mı · rc 0 / 1 kırmızı / 3 SARI: MERKEZ.md yok
```

Merkez akışı: `merkez` → eksik ajana zil (boşta bekçisiyle birleşir) → SERDAR MERKEZ.md'de dersleri yazar
(`M<n>)`, kutu dersine `BÂNİ D2` ile atıf) → Sultan ders ders onaylar → görev defteri → her öneriye ve her havuz
satırına damga (havuz kaydı Sırada'ya alınırsa `→ gorev_<kendi id>`, elenirse `→ RED: …`) → `suzum` yeşil. `/hafta-kapanis` (ayrı beceri, Pazar) `merkez` rc'sini ve `suzum` rc'sini kapı olarak okur.

## Şema

`sema/retro-dosyasi.md` — başlık · imza satırları · ölçüm tablosu · 5 başlık · etiket dilbilgisi · lint kodları
L1–L7 · MERKEZ.md süzüm ve havuz satırı biçimi. Şemayı değiştirmek = o dosyayı ve `lint_metin`'i aynı PR'da değiştirmek.

## Kanıt

`scripts/retro.test.sh` — hermetik kapılar (mktemp depo · sahte NOTES/kart/DENETIM/kaçış/bekçi/registry · sahte havuz
köprüsü `RETRO_BULGU_SH` · sabit tarih `RETRO_BUGUN`) + mutantlar kopya üstünde (L5 kalkınca ölçüsüz Z geçmemeli · kaynak
yokluğu sıfıra çevrilince sarı kaybolmalı · iz ayrımı kalkınca ÇALIŞMADI EKSİK'e dönmeli · metin kıyası kalkınca bayat damga
geçmemeli · havuz köprüsü M16-M19 — hepsi ısırıyor).
Canlı ölçüm (Nexus, 2026-W42): BÂNİ 244 NOTES satırı · 34 ders satırı · 20 kart (16 bitti · 4 tıkandı) · 48 göz turu;
MUAVİN'in NOTES dosyası yok → o hücre ÖLÇÜLEMEDİ.

## Sınırlar (dürüst)

- Ölçüm haftaya göredir ama NOTES satırlarının çoğunda tarih yoktur; devralma kuralı yaklaşıktır ve bunu
  "tarihsiz N sayılmadı" diye yazar. Günlük çıpa başlığı (`## ÇIPA YYYY-MM-DD`) yazan ajanın ölçümü kesin olur.
- `--koltuk` verilmezse `TMUX_PANE_HEDEF` ortamı, o da yoksa boş kalır → lint L2 düşer. Kasıtlı: imzasız retro yok.
- Bu beceri cron zili düşürmez (cloudtop `crontab-abc`, MİRAHUR) ve haftayı kapatmaz (`/hafta-kapanis`).
- Havuz süzümü merkez kipinin işidir ve defter jetonu ister; jetonsuz (izole) kutuda `merkez` rc 3 ÖLÇÜLEMEDİ verir —
  kutu kipi (`kutu` · `doldur` · `lint`) köprüye dokunmaz. `suzum` köprüyü çağırmaz: havuzun o anki hâli değil, MERKEZ.md'ye
  son `merkez --yenile`de yazılan hâli ölçülür (taze çekim = `merkez --yenile`).
