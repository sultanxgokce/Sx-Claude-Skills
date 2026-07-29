---
name: layiha-fabrikasi
type: agent
version: 1.5.0
description: >
  L24 Layiha Fabrikası — DİVAN'ın fikir-hattını (KAŞİF dış-tarama → bulgu-havuzu → MUCİT süzme →
  aday-havuzu → Sultan tek-tuş terfi) tek-çatı altında toplayan Usta-paket. kasif-tara + mucit-suz'ü
  besteler, layiha (defter) üzerine oturur. Kill-switch'li: Sultan hata bulursa günlük-üretim-turunu
  tek-komutla kapatabilir; eldeki aday-havuzuna erişim (liste/göster/terfi) HİÇBİR ZAMAN kesilmez.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [layiha-fabrikasi, bilesik, fikir-hatti, kill-switch]
status: v1.0-usta
---

# layiha-fabrikasi — DİVAN Fikir-Hattı Fabrikası (Usta · bileşik iş-sistemi)

**NE-DİR:** `kasif-tara` (KAŞİF — dış-tarama) + `mucit-suz` (MUCİT — süzme) skillerini besteleyerek
DİVAN'ın günlük "ham-malzeme → aday" bandını tek-çatı altına toplayan Usta-paket. Aday-havuzunun CRUD
katmanı (`<skill-dizini>/scripts/layiha-aday-havuzu.sh`) ve terfi-hedefi (`layiha` skill'i, defter) FABRIKA'nın
üzerine oturduğu temel — bu paket onları YENİDEN YAZMAZ, yalnız günlük-turu + kill-switch'i ekler.

## Kullanım-yüzeyi (Sultan-dili, 3 komut)

| Ne istiyorsun | Komut |
|---|---|
| **Günlük üretim-turu** (dış-tarama + süzme) | `/kasif-tara` (tara → havuza yaz) sonra `/mucit-suz` (süz → önizleme/aday) — DİVAN §9 sırasıyla. ⚠️ **İkisi de AYRI birer taze alt-ajanda koşar** (ADR-025 K3+K4: bulan ≠ eleyen); dispatch kalıbı her iki el-kitabının başındadır. Müdür tarama/eleme yapmaz, orkestra şefidir. |
| **Her yerde kapat** (hata bulundu, tüm odalarda üretimi durdur) | `bash <skill-dizini>/scripts/layiha-fabrika.sh kapat --sebep "<neden>"` |
| **Yalnız bu odayı kapat** (öbür odalar üretmeye devam etsin) | `bash <skill-dizini>/scripts/layiha-fabrika.sh kapat --yerel --sebep "<neden>"` |
| **Aç** (kapattığın neyse onu geri açar) | `bash <skill-dizini>/scripts/layiha-fabrika.sh ac` · yalnız bu oda: `ac --yerel` · hepsi: `ac --filo` |
| **Durum bak** (bu oda açık mı, filoda ne var, neden) | `bash <skill-dizini>/scripts/layiha-fabrika.sh durum` |
| **İlk kurulum** (yeni odada tezgâhı üret) | `bash <kasif-tara-dizini>/scripts/kasif-kur.sh` — oda **KAPALI doğar** |
| **Eldeki adayları görüntüle/terfi et** (HER-ZAMAN çalışır — kill-switch'ten ETKİLENMEZ) | `bash <skill-dizini>/scripts/layiha-aday-havuzu.sh liste` · `goster <id>` · `terfi <id> --sultan-onay` · `durum` — ⚖️ terfi **Sultan kilidi** taşır (ADR-025 · fikir-hattındaki tek insan kapısı; otomatik akış atlayamaz) |
| **Tek bir fikri havuza koy** (fabrika-turu beklemeden — K3) | `bash <skill-dizini>/scripts/layiha-aday-havuzu.sh ekle "<serbest metin>" --kaynak <ad>` — kayıt `durum=aday` doğar, **puanlanmaz** (`pct=0`; süzme/puanlama MUCİT'in işi). Eşdeğer metin havuzdaysa **sessizce atlar** (RC=0, stdout boş). Yazılan id stdout'a basılır. Kill-switch'ten ETKİLENMEZ (CRUD muaf). |

## Otonom hat (ADR-025 icra-5 · EK-A §A2-A4) — ⛔ **INERT DOĞAR**

Hat kendiliğinden koşabilir, ama **açılana kadar hiçbir şey yapmaz**. Açmak ayrı bir Sultan-GO'sudur.

| Ne istiyorsun | Komut |
|---|---|
| **Bugün ne oldu** (cam arkası) | `bash <skill-dizini>/scripts/hat-izle.sh` |
| **Bir turu uçtan uca izle** | `hat-izle.sh --tur t20260728-1` |
| **Tek satır özet** (gün sonu / ntfy) | `hat-izle.sh --ozet` |
| **Kararı gör, hiçbir şey koşturma** | `bash <skill-dizini>/scripts/hat-durtme.sh --kuru` |
| **Bu odada hattı AÇ** (⚠️ gerçek koşu başlar) | `hat-durtme.sh --ac "<sebep>"` |
| **Kapat** (INERT'e dön) | `hat-durtme.sh --kapat` |

**Mimari (§A2):** cron 30 dk'da bir `hat-durtme.sh`'i dürter → betik **LLM çağırmadan** karar verir
("bugün koşuldu mu? hak var mı? kilit boş mu?") → hak varsa **başsız** koşu (`claude --print`).
Müdür oturumunda loop **reddedildi**: oturum kapalıysa hat durur, her tur müdürün bağlamını şişirir,
ve oturum ölümlüdür (2026-07-25'te tmux sunucusu öldü). *"Ekipler kendiliğinden açılmasın"* direktifi
**delinmez** — tmux ekip-oturumu AÇILMAZ.

**Karar kuralları (§A3) — dürtme sıklığı ≠ tur sıklığı.** Cron sık sorar (bedava), iş günde bir olur:
1. Hak günlüktür; tamamlandıysa o gün bir daha koşulmaz
2. **Boş dönmek tamamlanmadır** — aynı gün ikinci arama aynı web'i tarar; ısrar fikir değil çöp üretir
3. Çalışamamak tamamlanma **değildir** → 3 deneme, artan aralık (+30dk, +2sa)
4. 3'te de olmazsa **pes eder ve RC≠0 verir** — sessiz pes RASAT faciasıdır, sonsuz deneme alarm yorgunluğu
5. MUCİT'in tetiği **saat değil sayıdır**: süzülmemiş ≥1 malzeme ∧ bugün süzülmedi
6. Tek koşu kilidi; kilit başkasındaysa sessiz çık — **deneme sayacı artmaz** ("ölçemedim ≠ başarısız")
7. Hak **09:00'da doğar, 18:00'de düşer** — gece boşuna deneme yok, ertesi gün taze hak

**Görünürlük iki parçadır (§A4):** *var olan işi pano gösterir, olmayan işi bekçi söyler.* Pano
**terminaldir**, panel değil — terminal defterlerden doğrudan okur, yalan söyleyemez; panel
bozulduğunda yanlış bilgi gösterir. Dört işaret: 🟢 akıyor · 🟡 sende · 🔴 sessiz · ⚪ kapalı.

**Açılış kademeli (§A5):** günde 1 tur, yalnız Nexus, 2 hafta ölç. **Günde 3 tur ölçümün sonucudur,
varsayımı değil.** Yayılım oda-oda ayrı GO.

## Kill-switch (FAZ-D2, `_agents/spec/layiha-fabrikasi-dagitim-DESIGN.md` §5)

- Bayrak: `/config/.claude/layiha-fabrikasi.kapali` (10/10 container'da AYNI dosya — paylaşılan
  `_global` bind-mount, DESIGN §1.1/1.2). Yoksa=açık.
- **ÇİFT MOD (Sultan-kararı K2):** bayrak `kapsam` taşır —
  `filo` = **bütün odalar** kapalı · `yerel` = yalnız `scope` listesindeki oda(lar) kapalı.
  `kapat`ın varsayılanı `filo`; `--yerel` bu odayı listeye ekler (öbür odalara dokunmaz), tekrar
  koşmak bozmaz. `ac` kapattığının tam tersidir; **başka** bir odanın filo-kapatmasını geri almak
  kaza olmasın diye açık onay ister (`ac --filo`).
- **Doğuşta KAPALI (K4):** yeni kurulan oda `kapsam:"yerel"` + kendi adıyla doğar — yetenek her
  odada, izin Sultan'da. Kurulum betiği bunu **yalnız ilk kez** yapar; sonradan açtığın odayı
  yeniden kapatmaz.
- **Geriye-uyum:** eski (JSON olmayan/boş) bayrak `filo` sayılır — eski bir kapatma sessizce
  gevşemez.
- Bayrak ortak dizinde durur ama **hiçbir kiracı-verisi taşımaz**: yalnız oda-adları + Sultan'ın
  yazdığı gerekçe. Layiha/bulgu verisi oraya ASLA yazılmaz (İ1).
- **Kapsam DAR (bilinçli):** kill-switch YALNIZ **layiha üretim-bandına** girer —
  `mucit-suz` paketindeki `scripts/mucit-t1.sh --profil layiha` (bandın zorunlu boğaz-noktası). MUAF olanlar:
  (1) `<skill-dizini>/scripts/layiha-aday-havuzu.sh` (liste/göster/terfi/durum) — Sultan'ın eldeki aday-havuzuna
  erişimi asla kesilmez; (2) **DİVAN fikir-hattı** — `mucit-t1.sh --profil divan` (VARSAYILAN) ve
  `kasif-tara` paketindeki `scripts/kasif-havuz-ekle.sh`. DİVAN kendi anayasası (§8) olan AYRI bir programdır;
  "layiha-fabrikasını kapat" onu susturma yetkisi VERMEZ. Kanıt: `mucit-suz/scripts/mucit-t1.test.sh` G13-G15 + `kasif-tara/scripts/kasif-tara.test.sh` G7.
- Fail-closed: bayrak-dizini okunamıyor/şüpheli ise de üretim tarafı KAPALI varsayılır.

## Besteleme

`requires: [layiha, kasif-tara, mucit-suz]` — `ahi.manifest.yaml`'de deklare edilmiştir. `layiha`
skill'i (defter) terfi-hedefidir; `kasif-tara`/`mucit-suz` günlük-bandın iki ucudur. Bileşenler
`.claude/skills/<kardeş>` yolundan çözülür (vendoring-YOK).

## Dağıtım (tek-tuş kurulum + güncelleme)

- Kurulum/güncelleme: `node sync-skills.mjs --apply --skill layiha-fabrikasi` (Sx-Claude-Skills'ten,
  Sultan-onaylı) — `_global` mount sayesinde 10/10 container'da aynı-anda görünür, ekstra adım yok.
- Sürüm tek-evi bu dosyanın `version:` alanı (ADR-001). Hata düzelt → version artır → `--apply` → anında filoda.
- Drift-bekçisi: `cloudtop/scripts/evergreen-parity.sh` (haftalık-cron, report-only) — `--apply` unutulursa fark eder.

## Kademe

Usta (S3 · bileşik). generic-goal: "kasif-tara + mucit-suz'ü besteleyen, kill-switch'li, filo-genelinde
güncel/senkron DİVAN fikir-hattı fabrikası". Doğrula: `ahi check layiha-fabrikasi` · Kanon: `ahi doctrine`.

## İ1 izolasyon-notu

Kod (bu paket + kasif-tara/mucit-suz SKILL.md'leri) `_global`'e gider — filo-geneli görünür. VERİ
(bulgu-havuzu.jsonl, aday-havuzu.jsonl, mucit-defteri, kapalı-bayrağı-İÇERİĞİ hariç) her zaman
container-yerel repo'da kalır (İ1). Kill-switch bayrağının kendisi (VAR/YOK durumu) İSTİSNA — o
bilinçli-olarak filo-geneli (Sultan "tüm container'larda" dedi, DESIGN §5 FAZ-D2).
