---
name: ahi
type: agent
version: 0.1.0
description: >
  AHÎ — 4-kademe AI-yetenek fabrikası. Yeni skill/sistem üretimini TEK-STANDARDA oturtan meta-fabrika:
  kademe-seç→standart-iskelet (ahi new), drift-gözcü (ahi check), terfi-appraisal (ahi promote),
  soft-emeklilik (ahi deprecate), kademe-sınıflandırıcı (ahi classify), sağlık-panosu (ahi health).
  Kanon: DOCTRINE.md (Değişmezler Kitabı) + tiers/{cirak,kalfa,usta,pir}.md. "ahi" / "fabrika" / yeni-skill-üretimi tetiğinde.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [ahi, fabrika, kademe, skill-uretec, standart, meta, lonca-emsali]
status: v0.1-faz0a
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
ahi new <kademe> <ad> # kademe-seç → standart-iskelet SCAFFOLD (dry-run-DURAK → onay)   [FAZ-1]
ahi check [<skill>]   # deterministik drift-lint (catalog/sync-targets/README parity + manifest) [FAZ-2]
ahi promote <skill>   # terfi-appraisal-checklist → yeşilse Sultan-törenine öner (hibrit)  [FAZ-3]
ahi deprecate <s> "<m>" # soft-emeklilik (deprecated+sunset+successor; reversible)         [FAZ-3]
ahi classify          # yeni-işi anlat → hangi-kademe önerici                              [FAZ-4]
ahi health            # sağlık-panosu (hangi skill hangi kademede, bayat/öksüz)            [FAZ-4]
ahi --help            # bu yardım
```

## Progressive-disclosure (önce-bunu-oku)
1. Kanon+değişmezler → `DOCTRINE.md`. 2. Kademe-detayı → `tiers/<kademe>.md`. 3. Şema → `schema/ahi.schema.json` (FAZ-0b).
4. Drift-otorite-kararı → `ADR/ADR-001-drift-otorite-ayrimi.md`.

## Değişmezler (özet — tam liste DOCTRINE §3)
tertipli-progresyon · çekim>dayatma+escape-hatch · TVP · objective-evidence>vibe · manifest-tek-kaynak(version-hariç) ·
soft-ama-sunsetli · owner-domain-dokunma (sync-skills.mjs + mevcut-üreteçler DEĞİŞTİRİLMEZ) · value-safe · INERT/additive.

## Statü (FAZ-0a)
Kanon + skill-kabuğu KURULDU. Komutlar FAZ-1..4'te dolar. `ahi doctrine`/`ahi tiers`/`ahi --help` CANLI.
Kaynak: `Sx-Claude-Skills/ahi/` (kanonik). Dağıtım: `_global` (sync-skills.mjs; elle-apply).
