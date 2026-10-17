---
name: retro
description: Haftalık retro — araç ajanın haftasını ÖLÇER (NOTES · fabrika kartları · bağımsız göz turları · kaçışlar · boşta zilleri), ajan 5 başlığı kendi gözüyle YORUMLAR (ne bitti · nerede zaman kaybettim ölçüyle · hangi araç/kural yavaşlattı · ne öğrendim · merkeze önerim); çıktı _agents/handoff/retro/<YYYY-Www>/<AJAN>.md lint'li. Merkez kipi kutu retrolarını toplar (OK/GEÇERSİZ/EKSİK/ÇALIŞMADI), MERKEZ.md iskeleti kurar; her öneri → gorev_ ya da → RED damgası alır (süzüm kanıtı). Tetik: "/retro", "haftalık retro", "haftanın dersleri", "retro yaz", "merkez retrosu".
version: 1.0.0
---

# /retro — haftalık retro (araç ölçer · ajan yorumlar · merkez toplar · süzüm kanıtlanır)

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
6. **Süzüm damgası mekanik.** Her kutu önerisi MERKEZ.md'de `→ gorev_<26>` (görev defterine girdi) ya da
   `→ RED: <gerekçe ≥10 karakter>` alır. Damgasız öneri = süzülmemiş = `retro.py suzum` kırmızı.
   Damga MERKEZ.md'de yaşar — kutu dosyasına merkez dokunmaz.
7. **Yeni havuz kurulmaz.** Dosyalar `_agents/handoff/retro/<hafta>/`; dersler görev defterine, bulgu
   bulgu kanalına. Hafta kimliği ISO (`YYYY-Www`, Pazartesi–Pazar).

## Kutu kipi — her ajan, Cuma (zil düşer) ya da hafta içinde istediği an

```
python3 ~/.claude/skills/retro/scripts/retro.py kutu <AJAN> --koltuk <tmux hedefi> [--hafta 2026-W42]
#   → _agents/handoff/retro/2026-W42/<AJAN>.md iskeleti: ölçüm tablosu dolu, 5 başlık yer tutuculu
#   (dosya varsa rc=4; ölçümü yenilemek: --yenile — yorum satırlarına DOKUNMAZ)
# 5 başlığı doldur (B/Z/A/D/Ö etiketleri, 1..n sıralı; Z'de "· ölçü:" zorunlu; Ö ≤ 5), sonra:
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
#   → MERKEZ.md iskeleti: Katılım tablosu · Süzüm listesi (her öneri "→ " boş damgayla) · Dersler · Görevler
#   rc 0 herkes tamam · 1 KIRMIZI: EKSİK/GEÇERSİZ var · 3 SARI: ajan listesi yok (katılım ölçülemez) — fabrika rengiyle aynı
#   --yenile: iskeleti yeniden kurar, mevcut Süzüm DAMGALARINI KORUR
python3 ~/.claude/skills/retro/scripts/retro.py suzum [--hafta 2026-W42]
#   her Ö maddesi → gorev_<26> ya da → RED: <gerekçe> aldı mı · rc 0 / 1 kırmızı / 3 SARI: MERKEZ.md yok
```

Merkez akışı: `merkez` → eksik ajana zil (boşta bekçisiyle birleşir) → SERDAR MERKEZ.md'de dersleri yazar
(`M<n>)`, kutu dersine `BÂNİ D2` ile atıf) → Sultan ders ders onaylar → görev defteri → her öneriye damga
→ `suzum` yeşil. `/hafta-kapanis` (ayrı beceri, Pazar) `merkez` rc'sini ve `suzum` rc'sini kapı olarak okur.

## Şema

`sema/retro-dosyasi.md` — başlık · imza satırları · ölçüm tablosu · 5 başlık · etiket dilbilgisi · lint kodları
L1–L7. Şemayı değiştirmek = o dosyayı ve `lint_metin`'i aynı PR'da değiştirmek.

## Kanıt

`scripts/retro.test.sh` — 70 kapı hermetik (mktemp depo · sahte NOTES/kart/DENETIM/kaçış/bekçi/registry ·
sabit tarih `RETRO_BUGUN`) + 3 mutant kopya üstünde (L5 kalkınca ölçüsüz Z geçmemeli · kaynak yokluğu
sıfıra çevrilince sarı kaybolmalı · iz ayrımı kalkınca ÇALIŞMADI EKSİK'e dönmeli — üçü de ısırıyor).
Canlı ölçüm (Nexus, 2026-W42): BÂNİ 244 NOTES satırı · 34 ders satırı · 20 kart (16 bitti · 4 tıkandı) · 48 göz turu;
MUAVİN'in NOTES dosyası yok → o hücre ÖLÇÜLEMEDİ.

## Sınırlar (dürüst)

- Ölçüm haftaya göredir ama NOTES satırlarının çoğunda tarih yoktur; devralma kuralı yaklaşıktır ve bunu
  "tarihsiz N sayılmadı" diye yazar. Günlük çıpa başlığı (`## ÇIPA YYYY-MM-DD`) yazan ajanın ölçümü kesin olur.
- `--koltuk` verilmezse `TMUX_PANE_HEDEF` ortamı, o da yoksa boş kalır → lint L2 düşer. Kasıtlı: imzasız retro yok.
- Bu beceri cron zili düşürmez (cloudtop `crontab-abc`, MİRAHUR) ve haftayı kapatmaz (`/hafta-kapanis`).
