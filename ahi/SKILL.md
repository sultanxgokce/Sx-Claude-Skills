---
name: ahi
type: agent
version: 0.3.0
description: >
  AHÎ — 4-kademe AI-yetenek fabrikası. Yeni skill/sistem üretimini TEK-STANDARDA oturtan meta-fabrika:
  kademe-seç→standart-iskelet (ahi new), drift-gözcü (ahi check), terfi-appraisal (ahi promote),
  soft-emeklilik (ahi deprecate), kademe-sınıflandırıcı (ahi classify), sağlık-panosu (ahi health).
  Kanon: DOCTRINE.md (Değişmezler Kitabı) + tiers/{cirak,kalfa,usta,pir}.md. "ahi" / "fabrika" / yeni-skill-üretimi tetiğinde.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [ahi, fabrika, kademe, skill-uretec, standart, meta, lonca-emsali]
status: v0.2-canli
---

# ahi — AHÎ 4-Kademe Yetenek Fabrikası

**NE-DİR:** Sultan'ın ekosisteminde yeni AI-yetenek üretimini tek-standarda oturtan meta-fabrika. İki-yüz:
**DOKÜMAN** (`DOCTRINE.md` = Değişmezler Kitabı) + **ÜRETEÇ** (bu skill = kanonu deterministik zorlayan "el").

**KADEMELER (zanaat-rütbesi):** Çırak(S1 yerel) → Kalfa(S2 paketli) → Usta(S3 bileşik) → Pîr/Lonca(S4 yaşayan).
Her kademe kartı: `tiers/{cirak,kalfa,usta,pir}.md`. Kademe atlanamaz (tertipli-progresyon).

## Komutlar
```
ahi doctrine          # Değişmezler Kitabı'nı göster (kanon)
ahi tiers [<kademe>]  # kademe-kart(lar)ını göster
ahi new <kademe> <ad> # kademe-seç → standart-iskelet SCAFFOLD (kapsam-refleksi + dry-run-DURAK → --apply onay)
ahi check [<skill>]   # deterministik drift-lint (repo-parity catalog↔sync-targets + manifest-şema)
ahi promote <skill>   # terfi-appraisal-checklist → yeşilse Sultan-törenine öner (hibrit)
ahi deprecate <s> "<m>" # soft-emeklilik (deprecated+sunset+successor; reversible)
ahi classify          # yeni-işi anlat → hangi-kademe önerici
ahi health            # sağlık-panosu (hangi skill hangi kademede, bayat/öksüz + pir-own-repo)
ahi --help            # bu yardım
```

## Kapsam-refleksi (E3/R-03 · federe-standart — üretim-ÖNCESİ ZORUNLU, atlanamaz)
`ahi new` (ve her yetenek-üretimi) öncesi 4 adım; belirsiz cevap = `--apply`'a GEÇME (ise-alim A2
kapsam-refleksinin fabrika-aynası, Federe D8):
0. **zaten-var-mı? (R-03)** — üretmeden ÖNCE tara: bu-kutu rafı + Sx `catalog.json` + canlı
   `~/.claude/skills`. VARSA → üretme; "zaten var, şurada — global-yayayım mı?" de
   (aynı-şeyi-5-kutuda-5-kez-üretme panzehiri). (İzole-kutu YEREL rafı buradan fiziksel
   taranamaz → `catalog.json` kanonik-proxy'dir; beyanlı-daralma, spec R-03.)
1. **negatif-kapsam** — "Bu yetenek neye **DOKUNMAYACAK**? Hangi dizin/sistem/bölge sınırın
   **DIŞINDA**?" ("her şeye erişir / sınırsız" cevabı REDDEDİLİR → en-dar-yeterli scope;
   mahrem-tenant duvarları İ1 gevşetilmez.)
2. **bölge-çakışma** — "Bu kapsam mevcut bir skill'in/birimin/üretecin bölgesiyle **ÇAKIŞIYOR mu**?"
   Çakışıyorsa duplikasyon/iki-baş riski → körlemesine üretme YOK, Sultan'a/zirveye eskalasyon
   (owner-domain-dokunma değişmezi de burada devreye girer).
3. **dağıtım-kapsamı (E3 · 3-şık)** — **yerel** (tek-kutu; Çırak-default) / **global-hepsi**
   (`_global`) / **seçili-liste** (`sync-targets` subset). Global-ise tek-üretim → senkron-yayılım;
   tek-tek-kutuya-kurma YASAK. Cevap üretim-sonunda **install-ÖNERİSİ** olarak raporlanır;
   `sync-targets.json`/`catalog.json` girdisini İNSAN/PR uygular (ADR-001 — script ASLA yazmaz).

Bekçi: CI `validate-repo --strict` = KIRMIZI-kapı; çıplak `ahi check` = uyarı (report-only).
Zorlama-modeli: ajan-disiplini + dry-run-DURAK banner'ı + `--apply` hatırlatması (mekanik-kilit değil;
D8-a ise-alim emsaliyle aynı sınıf — metin-çıpası bekçilidir, cevap-içeriği insan/ajan sorumluluğu).

## Progressive-disclosure (önce-bunu-oku)
1. Kanon+değişmezler → `DOCTRINE.md`. 2. Kademe-detayı → `tiers/<kademe>.md`. 3. Şema → `schema/ahi.schema.json` + validator'lar (`schema/validate*.mjs`).
4. Drift-otorite-kararı → `ADR/ADR-001-drift-otorite-ayrimi.md`.

## Değişmezler (özet — tam liste DOCTRINE §3)
tertipli-progresyon · çekim>dayatma+escape-hatch · TVP · objective-evidence>vibe · manifest-tek-kaynak(version-hariç) ·
soft-ama-sunsetli · owner-domain-dokunma (sync-skills.mjs + mevcut-üreteçler DEĞİŞTİRİLMEZ) · value-safe · INERT/additive.

## Statü (v0.2 — CANLI; firsthand: scripts/ahi.sh, 2026-07-14)
TÜM komutlar DOLU ve CANLI: `doctrine` · `tiers` · `new` (kademe-doğrulama + dry-run-DURAK + scaffold +
placeholder-lint + otomatik `ahi check`) · `check` (repo-parity + manifest-şema; ADR-001: yalnız-raporlar) ·
`promote` (objective-evidence appraisal; Usta→Pîr nihai-karar Sultan-gate) · `deprecate` (soft + --undo) ·
`classify` · `health` (pir-registry own-repo çözümlemesi dahil — FAZ-6/ADR-002). İlk Kalfa-doğum kanıtı:
`tescil` (`ahi new kalfa tescil`, DİVAN K5). Eski "FAZ-0a / komutlar FAZ-1..4'te dolar" metni BAYATTI —
2026-07-14 gerçeğe çekildi. Kaynak: `Sx-Claude-Skills/ahi/` (kanonik). Dağıtım: `_global` (sync-skills.mjs; elle-apply).
