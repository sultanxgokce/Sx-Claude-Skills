---
name: duzen
description: Filo düzen paketi — görev · Bulgu Havuzu · Hasat · oda · el defteri · master prompt çekirdeği; tek kaynak, sürümlü, bütün kutulara ortak kitaplıkla iner. "Serdar kutusundaki düzen tüm kutularda aynı olmalı" (Sultan, 29 Eki 2026) isteğinin paketi. "/duzen", "düzen paketi", "el defteri çıkar", "çekirdek metin", "düzen sürümü / bayat mı" tetiğinde.
version: 1.0.0
---

# /duzen — filo düzen paketi (1.0.0 · iskelet)

## Niçin var (Sultan, 29 Eki 2026 · Kuzey Yıldızı 4.1-4.3)

Sultan'ın sözü: *"Serdar kutusundaki düzen tüm kutularda aynı olmalı; güncellemeler tüm kutularda senkron;
el defterleri ve master promptlar sağlam ve yönetilebilir olsun, güncelleme gelince otomatik gelişsin."*

Yer gerçeği (ölçüldü 29 Eki): bütün kutulara kendiliğinden ulaşan **tek kanal** ortak `/config/.claude` bağıdır
(skills · CLAUDE.md · settings). Master prompt çekirdeği Nexus `_agents/ekip-os-base/` içinde yaşıyordu; izole
kutular (vekatip · mmex · medigate · huma · mihenk · tellal · akar · s02) Nexus'u göremez, bu yüzden çekirdek
metinler işaretçiyle anılıyor ama okunamıyordu. Not aracı `append-note.sh` yalnız 3 kutuda vardı. Alt ajanın
"sıfır bağlam" için el defteri üreticisi yoktu (ÇIRAK elle yapıyordu, MÜŞAVİR'inki eksikti).

Bu paket o boşluğu **tek kaynak + sürüm + ortak kitaplık** üçlüsüyle kapatır: metin ve araç burada yaşar,
`_global` hedefiyle her kutuya aynı kopya iner, sürüm artınca aynı anda hepsinde yenilenir.

## 🔴 Değişmez

**Kopya değil işaretçi; çekirdek metin yalnız burada yaşar.** Kutudaki hiçbir dosya `cekirdek/` metnini kendi
sözcükleriyle yeniden yazmaz — ya bu dizini okur ya `ekipc` ile üretilmiş bölgeye birebir gömer. İkinci kopya
ilk değişimde bayatlar (K02/M01 emsali). `surum.sh denetle` bunu ölçer: gömülü metin çekirdekle birebir
değilse **BAYAT** der.

## Altı başlık — her biri için SAHİP (bu paket yeniden icat etmez, işaret eder)

| Başlık | Ne | SAHİP beceri / yol |
|---|---|---|
| **Görev** | Kutunun işleri tek defterde (`gorev.sh ekle/liste/adim/bitti`); plan maddesi görevin kimliğiyle yazılır | `gunluk-plan` (`scripts/gorev.sh`, `gorev-yolu.sh`) |
| **Bulgu Havuzu** | Kusur/fikir aynı komutla kutunun Bulgu Defteri'ne; **canlı havuz = DEFTER** (SERDAR kararı 30 Eki), jsonl değil | `bulgu` |
| **Hasat** | Gün sonu / hafta sonu toplama; plan adımı 0-d (dünün kalanları) ve 0-e (hasat) | `gunluk-plan` 0-d/0-e · `gun-sonu.sh` (yazilim-fabrikasi) |
| **Oda** | Kutu içinde amacı ayrı odalar, ayar üretimi, yazma kancası; oda kaydı `aile-registry` `oda:` alanında | `oda-kur` + aile-registry `oda:` |
| **Haberleşme** | Tetikleme · not-tutma · ACK · nabız; CLAUDE.md'ye yalnız işaretçi | `federe-os-cekirdek` |
| **Çekirdek** | Master prompt temelleri + durma standardı + cevapsız bırakma kuralı | **bu paketin `cekirdek/`** (aşağıda) |

**Görev:** bir kutuda iş "aklımda" ya da serbest bir .md listesinde durmaz; `gorev.sh` defterine yazılır, planı
oradan okunur, bitince oradan kapanır. Bu paket yeni defter açmaz; `el-defteri.sh` açık işleri oradan okur.

**Bulgu Havuzu:** görülen kusur anında `bulgu` ile deftere düşer (varsayılan `havuz` hâli; haftalık süzmede görev
olur). Bodoslama fix yok, önce kayıt. Canlı havuz defterin kendisidir; eski `bulgu-havuzu.jsonl` okuma yüzeyidir.

**Hasat:** günün kalanı ertesi sabah plana 0-d ile girer, biten iş gün sonu özetine (0-e) araçtan (defterden)
yazılır; elle özet yazılmaz.

**Oda:** aynı kutuda farklı amaçlar (ürün kodu · araştırma · operasyon) ayrı oda klasörü ve ayrı ayar alır;
odanın kaydı aile-registry'de `oda:` ile tutulur, kapı koltuğun odasını oradan okur.

**Haberleşme:** kutular arası zil/ACK/nabız protokolü tek yerde (`federe-os-cekirdek`); kimlik dosyaları
protokolü anlatmaz, oraya işaret eder.

**Çekirdek:** aşağıdaki dört metin. Kimlik dosyaları (`AGENT.md`) bunları `ekipc benimse/yenile` ile üretilen
bölgeye gömer (`<!-- ekipc:uretilen:basla surum= hash= -->` … `bitti`, altı `## ELLE`).

## `cekirdek/` — çekirdek metinler (Nexus `_agents/ekip-os-base/` aynası, içerik birebir)

| Dosya | Ne |
|---|---|
| `cekirdek/manuel-claude-base.md` | Sultan-eşli interaktif Claude personasının ORTAK-TEMEL'i (18 Nexus kimliğinde gömülü) |
| `cekirdek/mudur-base.md` | Kutu reisi (MÜDÜR) temeli (SERDAR'da gömülü) |
| `cekirdek/durma-standardi.md` | Filo-ortak DUR kuralı: Ş2 fiili ∨ 6 eskalasyon sinyali ∨ kutu-🔴 |
| `cekirdek/cevapsiz-birakma.md` | Gelen mesaj/zil cevapsız bırakılmaz kuralı |

Her dosyanın ilk satırı `<!-- kaynak: Sx duzen/cekirdek · Nexus kopyası bu dosyayı okur -->`; gerisi Nexus
kopyasıyla bayt bayt aynıdır. **Nexus `ekip-os-base` bir sonraki adımda bu dizini işaret edecek** (bu PR Nexus
tarafına dokunmaz; o geçiş ayrı iş).

## Araçlar (`scripts/`)

| Araç | Ne yapar | Sınav |
|---|---|---|
| `el-defteri.sh [--ajan AD] [--n 25]` | Koltuğun el defterini tek metin basar: bugünkü ÇIPA · son KONUM · son N not · açık işler (gorev.sh). Alt ajan istemine eklenir. Defter yoksa **"el defteri yok" rc 3** (uydurmaz); gorev.sh yoksa "ölçülemedi" yazar | `el-defteri.test.sh` E1-E7 + 2 mutant |
| `append-note.sh` | Nexus `scripts/append-note.sh`'ın **birebir** kopyası: Read'siz güvenli ekleme, ajan defterinde ÇIPA başlığı + saat damgasını ARAÇ yazar. 19 kutu aynı not aracını alır | `append-note-paritesi.test.sh` P1-P4 (P4 = Nexus kopyasıyla md5 eşitliği) |
| `surum.sh goster` · `surum.sh denetle [--depo KÖK] [--kurulu DİZİN]` | Paket sürümü · kutudaki kurulu sürüm kaynakla aynı mı · `ekipc` işaretli AGENT.md'lerde hash tutuyor mu (EL-DEĞMİŞ) ve gömülü çekirdek birebir mi (BAYAT). **Yalnız raporlar, yazmaz** (`--kuru` varsayılan ve tek kip) | `surum.test.sh` S1-S9 + 2 mutant |

İlk ölçüm (29 Eki, Nexus): ekipc işaretli 18 kimlik → 17 GÜNCEL, 1 BAYAT (HEZARFEN); işaretsiz 18 kimlik
(pakete dahil mi — Sultan kararı).

## Sürüm artınca ne olur

1. Bu dosyadaki `version:` ve `catalog.json` birlikte artar (CI `katalog-surum-hiza` sapmayı kırmızı yapar).
2. Birleşince dağıtım: `node sync-skills.mjs --skill duzen --apply` (`_global` → `/config/.claude/skills/duzen`,
   ortak bağ olduğu için **bütün kutular aynı anda** yeni kopyayı görür). Cron'da DEĞİL — bilinçli (CLAUDE.md
   "sync-skills.mjs cron'da değil"); Sultan isterse ayrı karar.
3. Her kutunun reisine mektup: "duzen vX.Y.Z indi — `surum.sh denetle` koş, BAYAT kimlikleri `ekipc yenile`
   ile tazele." Zil `aile-notify`/POSTANE ile; metin bu paketin sürüm notundan alınır.
4. Denetim: her kutuda `bash /config/.claude/skills/duzen/scripts/surum.sh denetle` → rc 0 güncel · 1 bayat var ·
   3 ölçülemedi. Yeşil beyanla değil rc ile sayılır.

## Sultan kararı bekleyenler (1.0.0 bilerek yapmadı)

- (a) `/config/.claude/CLAUDE.md`'ye "düzen paketi" işaretçi bloğu — o dosya 10 kutuda ortaktır, Sultan-PR.
- (b) Dağıtım cron'u — "sync-skills.mjs cron'da değil" kararı yürürlükte.
- (c) Nexus'taki 18 işaretsiz kimlik pakete dahil mi (ekipc'ye alınsın mı).
