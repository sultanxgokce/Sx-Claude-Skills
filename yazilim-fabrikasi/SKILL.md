---
name: yazilim-fabrikasi
type: agent
version: 0.1.0
description: >
  Filonun tek çalışma hattı: her iş KABUL → İZOLE → İNŞA → KANITLA → GÖNDER adımlarından geçer.
  Her adımın çıktısını ajan değil ARAÇ yazar; puanı yazandan FARKLI model verir (bağımsız göz);
  Sultan yalnız dört sınıfta (geri alınamaz · para · dış yüzey · yetki genişletme) ve gün sonu
  özetinde görünür. Hat dosyası FABRIKA.md her depoda birebir aynıdır (fabrika-kur.sh koyar ve
  sha ile denetler). Tetik: "/fabrika", "iş başlat", "iş alanı aç", "hat dosyasını kur",
  "fabrika denetle", "kanıtla", "gönder", "bağımsız göz". F0 sürümü: hat dosyası + iş alanı;
  kanıt/denetçi/karne/gün-sonu betikleri F1–F3'te gelir (bkz. "Durum").
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
| `is-alani.sh ac <iş>` | `origin/main`'den TAZE worktree (`/config/projects/_wt/<depo>-<iş>`), açık PR'larla dosya çakışması varsa **durur ve sorar** | 0 · 1 hata · 2 çakışma |
| `is-alani.sh kontrol` | güvenli / riskli / ölçülemedi | 0 · 1 · 2 |
| `is-alani.sh kapat <iş>` | merge sonrası temizlik; **kayıtsız iş varsa silmez** | 0 · 1 |
| `is-alani.sh liste` | açık alanlar | 0 |

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
| `kanit.sh` (KANIT.json'u araç yazar) · `denetci.sh` (Codex/Claude çapraz) · `karne.sh` | F1 — **henüz yok**; adım 3-4 şimdilik elle, rubrik belgede |
| `sergi-beceri.py` → sergi.mmepanel.com | F2 — yok |
| `gun-sonu.sh` + sınıf soruları araçta | F3 — yok (kabul kartı şimdilik elle, biçim `0-kabul.md`) |
| ana-dal Edit/Write kilidi (filo kancası) | F4 — yok, ayrı Sultan onayı ister |

Bu tablo "yazılmış ≠ kurulmuş" kanununun beceriye uygulanmış hâlidir: olmayan şey "var" diye yazılmaz.

## Sınırlar
- Beceri **proje bilmez**: test/lint/paket komutunu deponun kendi dosyasından okur, hat dosyasına yazmaz.
- Worktree **paylaşılan kaynağı izole etmez** (port · veritabanı · kilit dosyası) — `is-alani.sh ac` her açılışta bunu basar.
- Her betik `rc=3` = ölçülemedi (sarı); yeşil değil. Kanıt komutu boru arkasına konmaz.
- Sınav: `bash scripts/is-alani.test.sh` (sahte depoda gerçek koşum) · `bash scripts/fabrika-kur.test.sh`.
