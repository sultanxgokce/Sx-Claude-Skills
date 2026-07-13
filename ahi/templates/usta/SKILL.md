---
name: {{NAME}}
type: agent
version: 0.1.0
description: >
  {{GENERIC_GOAL}} — (AHÎ ile üretildi; doldur: {{NAME}} hangi skilleri besteler, ne iş-sistemi kurar).
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [{{NAME}}, bilesik]
status: v0.1-usta
---

# {{NAME}} — (Usta · bileşik iş-sistemi)

**NE-DİR:** (doldur — hangi Kalfa-skilleri besteleyerek hangi çalışma-prensibini kurar).

## Besteleme
⚠️ `ahi.manifest.yaml` içindeki `requires[]`'i doldur (≥1 bileşen-skill). Boşken `ahi check` uyarır (DOCTRINE §10).
Bileşenler `.claude/skills/<kardeş>` yolundan çözülür (vendoring-YOK).

## Kademe
Usta (S3 · bileşik). generic-goal: "{{GENERIC_GOAL}}". Doğrula: `ahi check {{NAME}}` · Kanon: `ahi doctrine`.
