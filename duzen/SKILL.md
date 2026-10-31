---
name: duzen
description: Filo düzen paketi — görev · Bulgu Havuzu · Hasat · oda · el defteri · master prompt çekirdeği; tek kaynak, sürümlü, bütün kutulara ortak kitaplıkla iner. "Serdar kutusundaki düzen tüm kutularda aynı olmalı" (Sultan, 29 Eki 2026) isteğinin paketi. "/duzen", "düzen paketi", "el defteri çıkar", "alt ajan istemi üret / alt personele iş ver", "çekirdek metin", "düzen sürümü / bayat mı" tetiğinde.
version: 1.6.1
---

# /duzen — filo düzen paketi (1.6.1 · iskelet + alt ajan istem üreticisi + otonom temel + ekipc üretici)

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
| `cekirdek/otonom-ajan-base.md` | Otonom ajan (ARES · FORGE · GÖZCÜ · HAFIZ · İRFAN · NEDİM · PUSULA) ortak temeli |
| `cekirdek/durma-standardi.md` | Filo-ortak DUR kuralı: Ş2 fiili ∨ 6 eskalasyon sinyali ∨ kutu-🔴 |
| `cekirdek/cevapsiz-birakma.md` | Gelen mesaj/zil cevapsız bırakılmaz kuralı |
| `cekirdek/base-manifest.yaml` | Ortak temel kataloğu: hangi persona/rol hangi metni taşır (`ekipc --baz` bunu okur) |
| `cekirdek/ana-hedef-sablonu.md` | Ana hedef şablonu (Nexus `ekip-os-base` aynası) |
| `cekirdek/federe-inovasyon-charter.md` | Federe inovasyon şartı (Nexus `ekip-os-base` aynası) |

Her dosyanın ilk satırı `<!-- kaynak: Sx duzen/cekirdek · Nexus kopyası bu dosyayı okur -->`; gerisi Nexus
kopyasıyla bayt bayt aynıdır. **Nexus `ekip-os-base` bir sonraki adımda bu dizini işaret edecek** (bu PR Nexus
tarafına dokunmaz; o geçiş ayrı iş).

## Araçlar (`scripts/`)

| Araç | Ne yapar | Sınav |
|---|---|---|
| `el-defteri.sh [--ajan AD] [--n 25]` | Koltuğun el defterini tek metin basar: bugünkü ÇIPA · son KONUM · son N not · açık işler (gorev.sh). Alt ajan istemine eklenir. Defter yoksa **"el defteri yok" rc 3** (uydurmaz); gorev.sh yoksa "ölçülemedi" yazar | `el-defteri.test.sh` E1-E7 + 2 mutant |
| `ekipc.sh benimse\|yenile --dosya KİMLİK --baz <persona> [--apply]` | Nexus `scripts/ekipc.sh`'ın **birebir** kopyası: izole kutuda (Nexus deposu ve manifesti YOK) kimliğe ortak temeli `## ELLE` bölgesine dokunmadan gömer ya da kaynak değişince yeniler. Katalog betiğin yanındaki `cekirdek/`'ten okunur; paket başlığı kimliğe gömülmez. `derle` ve `--rol` kipleri Nexus manifesti ister, bu pakette ÇALIŞMAZ (exit 3) | `ekipc-paritesi.test.sh` 12/12 (izole kutu + çivili md5 + Nexus ile bayt-aynı üretim) |
| `append-note.sh` | Nexus `scripts/append-note.sh`'ın **birebir** kopyası: Read'siz güvenli ekleme, ajan defterinde ÇIPA başlığı + saat damgasını ARAÇ yazar. 19 kutu aynı not aracını alır | `append-note-paritesi.test.sh` P1-P4 (P4 = Nexus kopyasıyla md5 eşitliği) |
| `alt-ajan-istem.sh <slug> --is "…" [--kart İŞ] [--dosyalar a,b] [--sure DK] [--depo KÖK]` | **Koltuksuz alt personel** (BENNÂ · MÜZEHHİP · ŞAKİRD · ÇAPAR · TATAR · MESSÂH · MEREMMETÇİ · MÜCERRİB · MÜTEFENNİN) için reisin Agent aracına yapıştıracağı **tek istem metnini** basar (yalnız stdout, dosyaya yazmaz). Altı blok: kimlik (`AGENT.md` `## ELLE` verbatim; ekipc üretilmiş ORTAK-TEMEL alınmaz) · reis/oda/yetki (aile-registry `oda:`+`amir:`; "birleştirme · canlı · host · sır reiste" sabit; 1.1.1: Sultan kararı satırı — alt personel kendi iş alanında küçük düzeltme PR'ı açabilir, birleştirme her durumda reiste, bütün odalar) · el defteri (`el-defteri.sh`; defter yoksa "defter boş, ilk görev" + ⚠, istem yine çıkar) · iş (`--is`; `--kart` varsa kartın `cumle`si önde) · dosyalar+süre · sabit kurallar (hat · Sultan-dili · kanıt · ölçmeden hüküm yok · scratchpad öneki · rerun yok). Slug'ın AGENT.md'si yoksa **rc 3 "kimlik yok: önce /ise-alim"**. `token|sifre|şifre|parola` geçen satır basılmaz → `[sır satırı süzüldü]` | `alt-ajan-istem.test.sh` A1-A9 + mutant `sir` (gömülü ve `--mutant sir`) |
| `surum.sh goster` · `surum.sh denetle [--depo KÖK] [--kurulu DİZİN]` | Paket sürümü · kutudaki kurulu sürüm kaynakla aynı mı · `ekipc` işaretli AGENT.md'lerde hash tutuyor mu (EL-DEĞMİŞ) ve gömülü çekirdek birebir mi (BAYAT). **Yalnız raporlar, yazmaz** (`--kuru` varsayılan ve tek kip) | `surum.test.sh` S1-S9 + 2 mutant |

İlk ölçüm (29 Eki, Nexus): ekipc işaretli 18 kimlik → 17 GÜNCEL, 1 BAYAT (HEZARFEN); işaretsiz 18 kimlik
(pakete dahil mi — Sultan kararı).

## Alt ajan istemi — reis koltuksuz personele nasıl iş verir (1.1.0)

Kuzey Yıldızı 3.3: koltuksuz personel reisin oturumundan **Agent aracıyla** doğar ve sıfır bağlamla başlar; eksik el defteriyle
telafi edilir. 3.3/3.8'e göre **el defterlerini BÂNİ yönetir, kendiliğinden gelişir** — bu araç defteri YAZMAZ, yalnız okur ve istem üretir.

```
bash /config/.claude/skills/duzen/scripts/alt-ajan-istem.sh sakird --is "X PR'ının sınavını yaz-koştur-mutasyonla" \
     --kart sinav-x --dosyalar "scripts/x.test.sh" --sure 60 --depo /config/projects/Nexus > /tmp/istem.txt
```
Çıktı Agent aracının `prompt` alanına olduğu gibi yapıştırılır. Reis için üç kural: (1) istemde ⚠ satırı varsa önce onu oku
(defter yok · kayıt yok · kart yok) — araç uydurmadı, eksik olanı söyledi; (2) `--dosyalar` vermezsen alt ajan iş alanını kendi
sınırlar — merkez/UI/canlı-yazılan dosyalar yine dışarıdadır (ÇIRAK `cirak-istem.sh` sınır denetimi bu sürümde **genelleştirilmedi**,
o ÇIRAK'a özgü kalır); (3) istem **sır değeri taşımaz** — AGENT.md/NOTES'ta `token|sifre|şifre|parola` geçen satır süzülür; süzülen
satırın işaretçisi gerekiyorsa reis sözle verir.

Kart alanı: `kart.sh` kartı `is` (ad) + `cumle` (cümle) tutar; araç `cumle`yi okur, yoksa `is`e düşer.

## Sürüm notları

- **1.6.1** (31 Eki 2026, MİRAHUR · Kuzey Hat E): izole kutuların çoğunda sistem python3'ünde PyYAML yoktu (ekipc exit 2). Paket artık saf Python PyYAML 6.0.3'ü `vendor/yaml-saf.zip` (+ başlatıcı `vendor/yaml/__init__.py`, lisans `vendor/LICENSE-PyYAML`) olarak taşır; `ekipc.sh` (Nexus #1458) vendor'ı bulursa kullanır, yoksa dürüst exit 2. Parite P8: `python3 -S` ile PyYAML'sız ortamda benimse (kuru ve --apply) ve yenile exit 0.
- **1.6.0** (31 Eki 2026, MİRAHUR · Kuzey Hat E G3.6): `ekipc.sh` düzen paketine girdi (Nexus #1455 + #1456 ile paket kipi). İzole kutuda `ekipc benimse|yenile --baz` artık
  çalışır: önceki durumda `ekipc benimse` kutuda `komut yok` (rc 127) veriyordu ve ortak bölge işi hiçbir izole kutuda yapılamıyordu. `cekirdek/`ye `base-manifest.yaml`,
  `ana-hedef-sablonu.md` ve `federe-inovasyon-charter.md` eklendi. `manuel-claude-base.md`ye koltuksuz alt personel bölümü eklendi (G3.3: istem `alt-ajan-istem.sh`
  ile, zil amire düşer; Nexus aynası #1457). Bu metin değişince manuel-claude kimlikleri BAYAT görünür ve gece işi yeniler. Sınav: `ekipc-paritesi.test.sh` 12/12 + mutant.
  Kimliklerin kutularda bağlanması (`benimse`) her kutunun reisinin işidir; bu paket yalnız aracı ve temeli taşır.
- **1.5.0** (31 Eki 2026, MİRAHUR · Kuzey G3.6): `surum.sh denetle` ve `duzen-gece.sh` `otonom-ajan` ortak temelini de tanır. `cekirdek/otonom-ajan-base.md` eklendi; gömülü temeli
  birebir olan otonom kimlik GÜNCEL sayılır, sapmışsa BAYAT (temel adıyla) ve gece işi onu `ekipc yenile --baz otonom-ajan` ile yeniler (günlükte `temel=otonom-ajan`).
  Öncesinde bu temel tanınmadığı için benimsenen otonom kimlikler her hafta sahte "bayat" bulgusu üretir, gece işi de "temel-bilinmiyor" diye atlardı. Ayrıca `duzen-gece.sh` gövdesi tek fonksiyona sarıldı: `sync-skills` bu dosyayı yerinde yeniden yazdığı için sarılmamış betik gece kurulumundan sonra kayık okur
  (sınamada gerçek `syntax error`). Sınav: surum 14/14 (S10 S11 + mutant), gece 17/17 (G11 G12 + mutant).
- **1.4.0** (31 Eki 2026, MİRAHUR · Kuzey G22 G3.3): `alt-ajan-istem.sh` her istem üretiminde `/config/.filo/alt-ajan-istem.jsonl`'e TEK satır yazar
  (zaman · slug · ad · oda · amir · kart · el_defteri_bayt · istem_bayt · istem_kimligi) ve aynı kimliği istem başlığına basar. İçerik/sır yazılmaz; kayıt
  yazılamazsa istem yine basılır, başlıkta ⚠ çıkar. Ölçüm: son 20 çağrının hepsinde el_defteri_bayt > 0. Sınav C1-C3 + mutant. Kayıt dosyasını ortam
  değişkeni `DUZEN_CAGRI_KAYDI` değiştirir (sınav için).
- **1.3.0** (31 Eki 2026, MİRAHUR · Kuzey G30): `uyum-haftalik.sh` — `surum.sh denetle`'yi koşar, sapmayı Bulgu Havuzu'na yazar (bug), günlüğe
  `uyum depo=… isaretli=N sapma=N durum=…` düşer; hiç kimlik işaretli değilse "güncel" DEMEZ, SARI der (rc 4, havuza ozellik). `--gunluk` bayrağı
  ölçüm fikstürünün gerçek günlüğe yazmaması içindir. Sınav + mutant var. Zamanlayıcı satırı ayrı cloudtop PR'ı.
- **1.2.0** (31 Eki 2026, MİRAHUR · Kuzey G25 G29): `duzen-gece.sh` (düzen sürümü artınca dört düzen becerisini gece kurar, bu depoda BAYAT ekipc
  kimliklerini yeniler, her kutu reisine "düzen vX indi" mektubu yollar; VARSAYILAN KURU, `--force` yok, reis bilinmiyorsa mektup tahminle gitmez).
  Sınavı + mutantı var; günlük biçimi `duzen-gece.sh` başlığında. Zamanlayıcı satırı ayrı PR (cloudtop `crontab-abc`); "sync-skills cron'da değil"
  kararı (aşağıda b) bu PR'la DEĞİŞMEZ, gece betiği yalnız --uygula ile yazar. Haftalık uyum denetimi (G30) ayrı kart/PR.

- **1.1.1** (30 Eki 2026, BÂNİ): yetki bloğuna Sultan kararı satırı (SERDAR 09:24): alt personel kendi iş alanında küçük düzeltme PR'ı AÇABİLİR; birleştirme her durumda reiste; canlı · host · sır yok; kural bütün odalar için aynı (MEREMMETÇİ dahil). Sınav A8b.
- **1.1.0** (30 Eki 2026, SERDAR gece inşası): `alt-ajan-istem.sh` + sınavı. 9 koltuksuz alt personel (Nexus #1414) için istem
  üretici. Yalnız stdout; el defterini yazmaz. Sultan kararı bekleyenler değişmedi.
- **1.0.0** (29 Eki 2026): iskelet — çekirdek metinler · el-defteri.sh · append-note.sh paritesi · surum.sh.

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
