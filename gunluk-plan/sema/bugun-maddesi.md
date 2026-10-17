# Bugün maddesi — satır dilbilgisi (TEK KAYNAK)

Günün çıpasındaki (`_agents/handoff/gunluk-plan-cipa.<ajan>.md`) her plan satırı bu dilbilgisine uyar.
Bu dosya üç okuyucunun ortak sözleşmesidir:

| Okuyucu | Nerede | Ne yapar |
|---|---|---|
| `/gunluk-plan` | `scripts/tablo.py` (`cipa.sh tablo` · `cipa.sh kapanis`) | sabah tablosu + gün sonu kapısı |
| `/gun-ortasi` | aynı araç (`cipa.sh tablo`) | gün ortası tablosu |
| Kokpit "Bugün" paneli | `terminal-onar/kapi/bugun.mjs` (`/api/bugun`) | panel verisi |

🔴 **Uyum kapısı:** `sema/ornek-cipa.md` → `sema/beklenen.json`. Her okuyucunun sınavı bu fikstürü
koşar. Kural değişince ÖNCE bu dosya ve fikstür değişir, sonra okuyucular; fikstür tutmazsa sınav kırmızıdır.
Niçin: aynı veriyi üç ayrı gözle okuyan üç araç vardı ve yazılı tek kural yoktu (17 Eki ölçümü).

## Satır

```
- [<im>] <etiket>) <metin> (sahip: <AD>) <gorev_…> → <SONUÇ> · <not> · kanıt: <ref>
```

| Parça | Zorunlu mu | Kural |
|---|---|---|
| `<im>` | evet | tek karakter: ` ` açık · `~` yarım · `x` kapandı · `-` geri alındı **ya da** ertelendi. Bu küme **değişmez**: kapının kalıbı bilmediği imi sessizce atlar. |
| `<etiket>` | sabah: `1)` · gün ortası: `G1)` | etiketsiz satır "serbest" maddedir |
| `(sahip: <AD>)` | hayır | maddenin sahibi. Metinden ayrılır, tabloda kendi sütunundadır |
| `gorev_…` | hayır | havuzdaki görev bağı (birden çok olabilir) |
| `→ <SONUÇ>` | tazelenince | `KAPANDI` · `YARIM` · `AÇILMADI` · `GERİ ALINDI` · `ERTELENDİ` (büyük harf) |
| `· <not>` | hayır | serbest not |
| `· kanıt: <ref>` | kapandıysa önerilir | PR numarası, commit ya da var olan dosya |

## Durum

Veri adları (`durum` alanı) kokpit kapısınınkilerle **aynıdır**; tabloda Sultan-dilindeki karşılığı basılır.

| im + sonuç | `durum` | Tabloda | Kapanış kapısı |
|---|---|---|---|
| ` ` | `acik` | açık | 🔴 kapatmaz |
| ` ` + `AÇILMADI` | `acik` | açılmadı | 🔴 kapatmaz |
| `~` | `yarim` | yarım | 🔴 kapatmaz |
| `x` | `bitti` | kapandı | ✓ |
| `-` + `GERİ ALINDI` (ya da sonuçsuz) | `geri` | geri alındı | ✓ (vazgeçildi, iz kalır) |
| `-` + `ERTELENDİ` + geçerli D1 | `ertelendi` | ertelendi | ✓ |
| `-` + `ERTELENDİ`, D1 yok ya da bozuk | `acik` | açık | 🔴 kapatmaz — damgasız erteleme erteleme değildir |

JSON alanları (madde başına): `etiket · tur (sabah|gun-ortasi|serbest) · metin · sahip · durum · sonuc · kanit · not · gorevler[]`.
`metin` görev kimliklerini içinde taşır (kapının eski davranışı); `sahip` ise metinden çıkarılır.

## Erteleme damgası (D1)

Not alanında `D1: YYYY-MM-DD Sultan: <sonuç> (sohbet · <oturum-ref> · "<≤120 harf kırpık>" · beyan:<AJAN>)`.
Ertesi güne taşımanın tek yolu budur. **A06:** araç bu sözü üretmez, yalnız biçimini sınar. Damgayı
ajan, Sultan'ın gerçekten söylediği sözden aktarır; uydurulmuş damga, sahte onayla aynı ihlaldir.
