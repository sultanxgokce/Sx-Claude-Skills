# Retro dosyası şeması · 1.0.0

Yol: `_agents/handoff/retro/<YYYY-Www>/<AJAN>.md` — hafta ISO (Pazartesi–Pazar), dosya adı ajanın adı
(başlıktaki adla aksansız eşleşmeli). Merkez dosyası aynı dizinde `MERKEZ.md`, kapanış `KAPANIS.md`
(`/hafta-kapanis` yazar). Lint: `retro.py lint <dosya>`; kural kodları aşağıda.

```
# 🔁 HAFTALIK RETRO · 2026-W42 · BÂNİ                      ← L1 başlık (hafta = dizin, ajan = dosya adı)
_koltuk: bani:0                                             ← L2 imza (beyan; boş olamaz)
_kutu: <hostname>
_yazildi: 2026-10-17T16:40:00+03:00                          ← L2
_arac: retro.py 1.0.0                                        ← L2
_olcum_yenilendi: …                                          ← --yenile yazar (isteğe bağlı)

## Ölçüm (araç yazdı · elle değiştirilmez · `retro.py kutu --yenile` yeniler)     ← L3 blok zorunlu
_aralık: 2026-10-12 → 2026-10-18_

| Kaynak | Değer | Kanıt |                                   ← L3 ≥7 satır; Değer = sayı içerir ya da "ÖLÇÜLEMEDİ: …"
|---|---|---|
| NOTES mesaj satırı | 244 (tarihsiz 0 sayılmadı) | `_agents/bani/NOTES.md` |
| ders / zaman kaybı / tıkanma satırı | 34 | aynı dosya, anahtar kelime |
| kart açılan / bitti / tıkandı | 20 / 16 / 4 | `_agents/fabrika/kartlar` (aldı = ajan) |
| bağımsız göz turu · ortalama tur/kart | 48 · 2.4 | `_agents/fabrika/kanit/*/DENETIM-*.json` |
| kaçış (KUTU GENELİ, ajan ayrımı yok) | 9 | `_agents/fabrika/kacis-defteri.log` |
| boşta bekçisi zili | 2 | `/config/.filo/bosta-bekcisi.log` |
| Sultan-eli adımı | ÖLÇÜLEMEDİ: tanımlı kaynak yok | — |

## 1 · Ne bitti                                              ← L4 beş başlık, her biri ≥1 madde, yer tutucusuz (L7)
- B1) <metin>
## 2 · Nerede zaman kaybettim (ölçüyle)
- Z1) <metin> · ölçü: <sayı birim>                           ← L5 ölçü zorunlu
## 3 · Hangi araç/kural beni yavaşlattı
- A1) <metin>
## 4 · Ne öğrendim
- D1) <metin>                                                ← merkez dersi buna atıf yapar: "BÂNİ D1"
## 5 · Merkeze önerim
- Ö1) <metin>                                                ← L6 en çok 5; damgası MERKEZ.md'de
```

## Madde dilbilgisi

`- <ETİKET><n>) <metin>` — etiket bölüme sabittir (1→B, 2→Z, 3→A, 4→D, 5→Ö), `n` bölüm içinde 1..n sıralı,
metin ≥ 8 karakter, `<…>` ya da `…` yer tutucusu içermez. Z maddesi `· ölçü: <sayı birim>` parçası taşır
(ör. `· ölçü: 2 tur` · `· ölçü: 68 dk`). Serbest alt satır (`  not: …`) sayılmaz, serbesttir.

## Lint kodları

| Kod | Ne ölçer | Niçin |
|---|---|---|
| L1 | başlık biçimi; hafta = dizin adı; ajan = dosya adı | yanlış klasöre düşen retro merkezi yanıltır |
| L2 | `_koltuk` · `_yazildi` · `_arac` dolu | imzasız retro yok (beyan, kanıt değil — dürüst sınır) |
| L3 | ölçüm bloğu var; ≥7 kaynak satırı; her değer sayı ya da `ÖLÇÜLEMEDİ: …` | araç ölçer, ajan yorumlar; sıfır ile ölçülemedi ayrı |
| L4 | 5 başlık var, boş değil, etiket doğru, numaralar sıralı, metin ≥8 | yorum boşsa dosya geçersiz |
| L5 | Z maddesinde `· ölçü:` + rakam | zaman kaybı ölçüsüz yazılmaz |
| L6 | Ö ≤ 5 | kapasite dürüstlüğü |
| L7 | yer tutucu kalmamış | iskelet teslim değildir |

## MERKEZ.md süzüm satırı

`- <AJAN> Ö<n>) <metin> → gorev_<26 karakter>` ya da `→ RED: <gerekçe ≥10 karakter>`.
`retro.py suzum` her kutu önerisinin böyle bir satırı olduğunu ölçer; `merkez --yenile` damgaları korur.
