---
name: ahi
type: agent
version: 0.2.1
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
ahi new <kademe> <ad> # kademe-seç → standart-iskelet SCAFFOLD (dry-run-DURAK → --apply onay)
ahi check [<skill>]   # deterministik drift-lint (repo-parity catalog↔sync-targets + manifest-şema)
ahi promote <skill>   # terfi-appraisal-checklist → yeşilse Sultan-törenine öner (hibrit)
ahi deprecate <s> "<m>" # soft-emeklilik (deprecated+sunset+successor; reversible)
ahi classify          # yeni-işi anlat → hangi-kademe önerici
ahi health            # sağlık-panosu (hangi skill hangi kademede, bayat/öksüz + pir-own-repo)
ahi --help            # bu yardım
```

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
