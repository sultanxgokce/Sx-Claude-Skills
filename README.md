# Sx-Claude-Skills

Projeye özgü olmayan, tek komutla kurulabilen portable Claude Code skill'leri koleksiyonu.
Her skill kendi klasöründe yaşar. Claude `SKILL.md`'yi okur, projeyi anlar, adapte eder.

---

## 🔑 Altın Kural — Sx-Claude-Skills = TEK KAYNAK (single source of truth)

> **Bir AI skill'i güncellenir veya geliştirilirse, güncel hâli ÖNCE buraya (Sx-Claude-Skills)
> yazılır. Diğer projeler/ortamlar bunu buradan senkronlar — asla tersi değil.**

Neden: skill birden çok ortamda yaşar (`_global` bulut, Nexus/cortex VPS, tekil repolar). Herkes kendi
kopyasını elle düzenlerse **drift** olur (aynı skill'in N farklı bayat sürümü). Kural bunu keser:

1. **Düzenleme yeri = burası.** Bir skill'i geliştirdiğinde (bir başka repoda kurulu kopyada fark
   ettiğin iyileştirme dahil) değişikliği **bu repoda** yap.
2. **Sürümü yükselt.** İlgili `SKILL.md` frontmatter'ında `version: x.y.z` artır (senkron bunu karşılaştırır).
3. **Yay.** `node sync-skills.mjs --apply` → değişiklik `sync-targets.json`'daki tüm hedeflere
   versiyon-damgalı gider. `_global` sayesinde bulutta her projede otomatik tazelenir.
4. **Kurulu kopyayı yerinde düzenleme.** Bir hedefte elle değişiklik yaparsan senkron motoru
   "HEDEF DAHA YENİ — DRIFT!" diye UYARIR ve `--force`'suz dokunmaz → önce o farkı buraya geri taşı.

Kısaca: **kaynak burada, dağıtım `sync-skills.mjs` ile, düzenleme daima yukarı-akış (upstream).**
Mekanik detay → aşağıdaki [Senkron](#senkron--güncellemeleri-yay-sync-skillsmjs) bölümü.

---

## Skill Kataloğu

| Skill | Tür | Stack | Süre | Versiyon | Durum |
|-------|-----|-------|------|----------|-------|
| [feedback-widget](feedback-widget/SKILL.md) | feature | FastAPI + Next.js | ~2h | 1.0.0 | stable |
| [ai-engineering-kit](ai-engineering-kit/SKILL.md) | agent | * (stack bağımsız) | ~2min | 1.0.0 | stable |
| [whatsapp-baileys](whatsapp-baileys/SKILL.md) | agent | * (stack bağımsız) | ~5min | 1.0.0 | stable |
| [cloudflare-erisim](cloudflare-erisim/SKILL.md) | agent | * (stack bağımsız) | ~2min | 1.1.0 | stable |
| [railway-erisim](railway-erisim/SKILL.md) | agent | * (stack bağımsız) | ~2min | 1.1.0 | stable |
| [pcloud-erisim](pcloud-erisim/SKILL.md) | agent | * (stack bağımsız) | ~2min | 1.1.0 | stable |
| [elogo-erisim](elogo-erisim/SKILL.md) | agent | * (stack bağımsız) | ~2min | 1.1.0 | stable |
| [erisim](erisim/SKILL.md) | agent | * (stack bağımsız) | ~1min | 1.0.0 | stable |
| [vault-cek](vault-cek/SKILL.md) | agent | * (stack bağımsız) | ~1min | 1.0.0 | stable |
| [erisim-skill-fabrikasi](erisim-skill-fabrikasi/SKILL.md) | agent (meta) | * (stack bağımsız) | ~5min/platform | 1.1.0 | stable |
| [ekip-kur](ekip-kur/SKILL.md) | agent (scaffold) | * (stack bağımsız) | ~5min | 1.2.0 | v1.2-mvp |

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

## Senkron — güncellemeleri yay (`sync-skills.mjs`)

"Pull + adapt" kurulumun tersine, bir skill geliştiğinde onu hedeflere **versiyon-damgalı**
dağıtan katman. Kaynak = bu repo; hedef haritası = `sync-targets.json`.

```bash
node sync-skills.mjs                 # dry-run: ne değişirdi (VARSAYILAN)
node sync-skills.mjs --apply         # kaynak >= hedef ise kopyala
node sync-skills.mjs --apply --force # hedef daha yeni olsa bile ez
node sync-skills.mjs --skill <id>    # tek skill
```

- **`_global` hedefi = `/config/.claude/skills`** → `HOME=/config` sayesinde **bulutta HER projede**
  otomatik yüklenir (tek kopya, sıfır ek senkron). Bir skill'i belirli bir repoya (git'e girsin,
  başka makineye/CI'a taşınsın diye) kurmak için `sync-targets.json` `install`'a o repo anahtarını ekle.
- **Drift koruması:** hedef sürümü kaynaktan yeniyse (kurulu kopya elle düzenlenmiş) UYARIR, `--force`
  olmadan dokunmaz → önce o değişikliği kaynağa geri taşı, sonra normal senkron.
- Her `SKILL.md` frontmatter'ında `version: x.y.z` ZORUNLU (senkron bunu karşılaştırır).

---

## pCloud Entegrasyonu

Oluşturulan asset'ler pCloud `AiSkills` klasöründe saklanır.

```
Public Folder / Sx-Claude-Skills / AiSkills /
Folder ID: 23473046120
Public URL: https://filedn.eu/lNbvMu0swIW8D7ExzploSu8/Sx-Claude-Skills/AiSkills/
```
