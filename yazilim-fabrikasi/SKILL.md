---
name: yazilim-fabrikasi
type: agent
version: 0.5.2
description: >
  Filonun tek çalışma hattı: her iş KABUL → İZOLE → İNŞA → KANITLA → GÖNDER adımlarından geçer.
  Her adımın çıktısını ajan değil ARAÇ yazar; puanı yazandan FARKLI model verir (bağımsız göz);
  Sultan yalnız dört sınıfta (geri alınamaz · para · dış yüzey · yetki genişletme) ve gün sonu
  özetinde görünür. Hat dosyası FABRIKA.md her depoda birebir aynıdır (fabrika-kur.sh koyar ve
  sha ile denetler). Tetik: "/fabrika", "iş başlat", "iş alanı aç", "hat dosyasını kur",
  "fabrika denetle", "kanıtla", "gönder", "bağımsız göz". F0 sürümü: hat dosyası + iş alanı;
  F1: kanıt (kanit.sh, manifesti araç yazar) +
  bağımsız göz (denetci.sh, Codex/Claude çapraz, tavan 3+1) + karne. F2: sergi. F3: kart.sh (0. adım: sınıf sorularını araç sorar, kartsız alan açılmaz) + gun-sonu.sh (özet defterden). Kalan F4: ana-dal kilidi.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [fabrika, worktree, kanit, bagimsiz-goz, puan, hat-dosyasi, orkestrasyon, global]
---

# /fabrika — yazılım fabrikası (tek hat, beş adım)

> **NE-DİR:** filodaki her işin geçtiği **tek hat**. Videodan (Mert Durmazer, 21 Eyl 2026) alınan
> fikir dört adımdı; bizde beş: başa **KABUL** (kim istedi · kim aldı · ne zaman · sınıf) eklendi,
> çünkü Sultan'ın devreye gireceği yer işin başında belli olmalı (K6).
> **NE-DEĞİL:** yeni test motoru değil (`olcum-disiplini`, `kapi-sinavi`, `sert-dongu` çağrılır,
> yeniden yazılmaz) · PR motoru değil (`pr-onay` çağrılır) · defter değil (kayıt var olan
> deftere `kayit-damgasi` ile düşer). **Yeni havuz kurmaz.**
> **Kaynak ve lisans:** `KAYNAK.md` — iki dış beceri okundu, kopyalanmadı (lisansları yok).
> **Mimari:** Nexus `_agents/handoff/YAZILIM-FABRIKASI-MIMARI-20260922.md` (Sultan onaylı 22 Eyl).

## Komutlar (hepsi bu dizinin `scripts/` altında; global yol `/config/.claude/skills/yazilim-fabrikasi`)

| Komut | Ne yapar | rc |
|---|---|---|
| `fabrika-kur.sh kur [depo]` | `FABRIKA.md`'yi depo köküne koyar, `CLAUDE.md`'ye tek satır işaretçi (`@FABRIKA.md`) ekler | 0 kuruldu · 1 çakışma (elle değişmiş hat dosyası) · 3 ölçülemedi |
| `fabrika-kur.sh denetle [depo]` | şablon sha ≟ depo sha; işaretçi var mı | 0 eşit · 1 drift · 3 dosya yok |
| `fabrika-kur.sh kur --kanca` | ek olarak ana-dal commit korumasını (pre-commit) kurar | — |
| `kart.sh ac <iş> --is … --istedi … --aldi … --geri-alinamaz/--para/--dis-yuzey/--yetki e\|h\|?` | 0. adım: iş kartını ARAÇ yazar; dört sınıf sorusu cevapsız kart açılmaz; e/? → Sultan'a gider. `bitti` · `tikandi --yol --neden` · `liste` · `goster`. `--oda` ile tetikli mesaj | 0 · 1 eksik cevap · 3 |
| `is-alani.sh ac <iş> [--dosyalar a,b] [--kartsiz]` | `origin/main`'den TAZE worktree (`/config/projects/_wt/<depo>-<iş>`); **kart yoksa açılmaz** (kaçış `--kartsiz` → kart cevapsız açılır, Sultan'a gider); açık PR'larla dosya çakışması varsa **durur ve sorar**; kartı worktree'ye kopyalar | 0 · 1 hata/kart yok · 2 çakışma |
| `gun-sonu.sh [--gun] [--yaz]` | gün sonu özeti DEFTERDEN (kartlar + karne): Sultan'a gidenler · içeride bitirdiklerimiz · tıkananlar · açık işler; elle satır yok | 0 · 3 defter yok |
| `is-alani.sh kontrol` | güvenli / riskli / ölçülemedi | 0 · 1 · 2 |
| `is-alani.sh kapat <iş>` | merge sonrası temizlik; **kayıtsız iş varsa silmez** | 0 · 1 |
| `is-alani.sh liste` | açık alanlar | 0 |
| `kanit.sh olcum <iş> <etiket> --asama once\|sonra -- <komut>` | komutu ARAÇ koşar, kırpılmamış çıktı+rc kaydeder, manifesti imzalar | 0 · 3 sarı (komut rc=3) |
| `kanit.sh ekran <iş> <etiket> --url U [--urun-imi CSS]` | başsız Chromium karesi; ürün imi yoksa kare kanıt sayılmaz | 0 · 2 ürün imi yok · 3 alınamadı (sarı) |
| `kanit.sh dosya <iş> <etiket> <yol>` · `dogrula <iş>` · `ozet <iş>` | var olan dosyayı ekler · imza+sha doğrular · PR tablosu | dogrula: 0 sağlam · 1 bozuk · 3 yok |
| `denetci.sh <iş> --pr N\|--diff F [--yazan claude\|codex] [--denetci …]` | BAĞIMSIZ GÖZ: yazandan farklı model; puan iki satır; DENETIM-<tur>.json'u araç yazar | 0 GEÇTİ · 1 adım 2 · 2 kanıt yok/bozuk · 3 ölçemedi · 4 tıkandı |
| `gun-sonu.sh` kaçış başlığı | kapı atlamaları **Sultan'ın önüne** gelir: gerekçe + komut, veto hakkıyla |
| `karne.sh yaz <iş>` · `kirildi <iş> --neden --kanit` · `ozet` | puan kalibrasyonu defteri: "5 alanların kaçı kırıldı" | 0 · 3 |
| `birlestirme-kapisi.sh <iş>\|--pr N` | 4. adımın SON kapısı: kart + imzalı kanıt + bağımsız göz 5/5 ve "doğru şey E" ve denetçi≠yazan. Biri eksikse birleştirme YOK | 0 geçti · 1 eksik · 3 ölçülemedi |
| `sergi-beceri.py --sx <Sx> --out <dizin> [--depo ad=yol]` | beceri sergisi manifesti (+SKILL.md kopyaları); sonra `sergi/scripts/build_catalog.py` | 0 · 3 |

## Beş adım — kısa; tam kural her adımın kendi dosyasında

0. **KABUL** — `adimlar/0-kabul.md`. İş kartı dört satır + sınıf. Şüphede sınıf **yukarı**.
1. **İZOLE** — `adimlar/1-izole.md`. Ana dalda asla; başkasının alanına asla. `is-alani.sh ac`.
2. **İNŞA** — `adimlar/2-insa.md`. Üç kat: yüzey · servis · depo. Tek gerekçe: hata olduğunda nerede olduğunu bil.
3. **KANITLA** — `adimlar/3-kanit.md`. Görüntü / ölçüm / video. "Çalışıyor" demek kanıt değil. Kanıtsız adım 4 yok.
4. **GÖNDER** — `adimlar/4-gonder.md`. PR (`pr-onay`) + bağımsız göz (yazandan farklı model). Puan iki satır:
   **kod iyi mi** 0-5 · **doğru şey mi** E/H. 5+E değilse adım 2. Tavan 3 tur (+1 ilerleyene), 4 mutlak.

## Kurulum (bir kutuda bir kez)

```bash
bash /config/.claude/skills/yazilim-fabrikasi/scripts/fabrika-kur.sh kur /config/projects/<depo>
bash /config/.claude/skills/yazilim-fabrikasi/scripts/fabrika-kur.sh denetle /config/projects/<depo>; echo rc=$?
```
Hat dosyası **düzenlenmez**; kutuya özel kural `.claude/skills/` katmanına girer. Değişiklik = bu beceride
(Sx-Claude-Skills) sürüm artır → `sync-skills.mjs --skill yazilim-fabrikasi --apply` → her depoda `kur` yeniden.

## Durum (dürüst)

| Parça | Durum |
|---|---|
| FABRIKA.md şablonu + fabrika-kur.sh + is-alani.sh + 5 adım belgesi | **F0 — bu sürümde var**, sınavlı |
| `kanit.sh` (KANIT.json'u araç yazar, imzalı) · `denetci.sh` (Codex/Claude çapraz, tavan 3+1/4) · `karne.sh` | **F1 — bu sürümde var**, sınavlı (21+25+9); Codex canlı koşuldu |
| `sergi-beceri.py` → sergi.mmepanel.com | **F2 — var**: manifest üretir (katalog ∪ kurulu ∪ depo-yerel; öksüz görünür), `sergi` becerisi basar, Nexus `scripts/sergi-yayinla.sh` yayınlar. Canlı 22 Eyl: 117 kayıt, Access arkasında |
| `kart.sh` (sınıf soruları araçta, kartsız alan açılmaz) · `gun-sonu.sh` (defterden özet) · tetik entegrasyonu (`--oda`) | **F3 — var**, sınavlı (25) |
| akış videosu (grafik ortam) | yok — konteynerde grafik ortam yok; `ekran` kare dizisi, video SARI kalır |
| ana-dal Edit/Write kilidi | **var** — Nexus'ta canlı, uçtan uca ölçüldü (Write engellendi) |
| birleştirme kapısı (`gh pr merge` kancası) | **var** — kanıtsız/puansız iş birleşemez; hat dosyası kurulu depolarda geçerli |

Bu tablo "yazılmış ≠ kurulmuş" kanununun beceriye uygulanmış hâlidir: olmayan şey "var" diye yazılmaz.

## Sınırlar
- Beceri **proje bilmez**: test/lint/paket komutunu deponun kendi dosyasından okur, hat dosyasına yazmaz.
- Worktree **paylaşılan kaynağı izole etmez** (port · veritabanı · kilit dosyası) — `is-alani.sh ac` her açılışta bunu basar.
- Her betik `rc=3` = ölçülemedi (sarı); yeşil değil. Kanıt komutu boru arkasına konmaz.
- Kanıt manifesti imzası elle yazımı yakalar; kriptografik gizlilik iddiası YOK (tuz araçta açık). Kararlı ajanı değil, kestirmeyi durdurur.
- Araçlar arası veri DOSYADAN geçer, kabuk alıntısından değil (23 Eyl: denetçinin Türkçe metnindeki kesme işareti puan satırını kırdı).
- Codex bu konteynerde kum havuzu (bwrap) açamıyor → istem argüman olarak verilir, denetçi komut koşmaz; >120 KB istem kırpılır ve söylenir.
- Defter yerleşimi: kartlar + karne + gün-sonu BİRİNCİL depoda (`_agents/fabrika/kartlar|karne.jsonl|gun-sonu`), kanıt + denetim İŞİN worktree'sinde (`_agents/fabrika/kanit/<iş>/`, PR ile gider).
- Sınav: `is-alani.test.sh` · `fabrika-kur.test.sh` · `kanit.test.sh` (playwright varsa gerçek kare) · `denetci.test.sh` (sahte denetçi) · `karne.test.sh` · `kart.test.sh` (kart + gün sonu + zincir).
