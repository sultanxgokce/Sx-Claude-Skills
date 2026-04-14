---
name: skill-packager
type: agent
version: 1.0.0
description: >
  Mevcut bir modülü Sx-Claude-Skills formatında paketler: SKILL.md oluşturur,
  templates/ hazırlar, catalog.json günceller, GitHub'a push eder, Nexus'a kaydeder.
prerequisites: {}
install_target:
  commands: .claude/commands/
stacks: ["*"]
author: sultanxgokce
tags: [packaging, skill-creator, sx-claude-skills, nexus]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# Skill Packager

Bir MMEpanel modülünü (veya herhangi bir projenin modülünü) taşınabilir Claude Code
skill'ine dönüştürür. `/skill-packager [ModülAdı]` ile çağrılır.

## Ne Yapar

1. Modülün backend + frontend kodunu analiz eder
2. `templates/` altına adapte edilmiş kopyaları oluşturur
3. `SKILL.md` frontmatter'ını doldurur
4. `CHANGELOG.md` başlatır
5. `catalog.json`'a entry ekler
6. Sx-Claude-Skills reposuna push eder
7. Nexus AI Engineer Workbook > Skill Kataloğu'na kayıt oluşturur

## Kurulum

`templates/commands/skill-packager.md` dosyasını `.claude/commands/skill-packager.md` olarak kopyala.

`.claude/commands/` yoksa oluştur.

## Sonraki Adım

Kurulumdan sonra şunu çalıştır:
```
/skill-packager [ModülAdı]
```
