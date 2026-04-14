# Sx-Claude-Skills

Projeye özgü olmayan, tek komutla kurulabilen portable Claude Code skill'leri koleksiyonu.
Her skill kendi klasöründe yaşar. Claude `SKILL.md`'yi okur, projeyi anlar, adapte eder.

---

## Skill Kataloğu

| Skill | Tür | Stack | Süre | Versiyon | Durum |
|-------|-----|-------|------|----------|-------|
| [feedback-widget](feedback-widget/SKILL.md) | feature | FastAPI + Next.js | ~2h | 1.0.0 | stable |
| [ai-engineering-kit](ai-engineering-kit/SKILL.md) | agent | * (stack bağımsız) | ~2min | 1.0.0 | stable |

Makine-okunabilir indeks: [catalog.json](catalog.json)

---

## Skill Türleri

**`feature`** — Gerçek backend/frontend kodu üretir. Proje stack'ine adapte olur.
`templates/` altında `.py`, `.tsx` gibi dosyalar içerir.

**`agent`** — Kod üretmez. Claude'un çalışma altyapısını kurar.
`templates/` altında `.md` ve `.json` dosyaları içerir.

---

## Kurulum

Herhangi bir projede Claude'a şunu söyle:

```
Sx-Claude-Skills reposundan [skill-adı] skill'ini kur.
Repo: https://github.com/sultanxgokce/Sx-Claude-Skills
```

Claude `SKILL.md`'yi okur ve projeye göre adapte ederek kurar.

---

## Yeni Skill Ekleme

1. `yeni-skill-adi/` klasörü aç
2. `SKILL.md` yaz — zorunlu frontmatter:

   ```yaml
   ---
   name: skill-adi
   type: feature | agent
   version: 1.0.0
   description: >
     Tek cümle açıklama.
   prerequisites:           # feature için
     backend: ...
     frontend: ...
   install_target:          # agent için
     commands: .claude/commands/
     skills: _agents/skills/
   stacks: [stack1+stack2]  # feature: spesifik; agent: ["*"]
   author: sultanxgokce
   tags: [tag1, tag2]
   ---
   ```

3. `templates/` dizinini doldur
4. `catalog.json`'a ekle
5. Bu README'deki tabloyu güncelle

---

## Kural

> Skill'ler gerçek projede test edilip onaylanmadan repoya eklenmez.
> Template'ler çalışan koddan tersine mühendislikle çıkarılır.

---

## pCloud Entegrasyonu

Oluşturulan asset'ler pCloud `AiSkills` klasöründe saklanır.

```
Public Folder / Sx-Claude-Skills / AiSkills /
Folder ID: 23473046120
Public URL: https://filedn.eu/lNbvMu0swIW8D7ExzploSu8/Sx-Claude-Skills/AiSkills/
```
