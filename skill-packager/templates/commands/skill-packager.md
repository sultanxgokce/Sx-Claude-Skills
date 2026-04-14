# Skill Packager — Modülü Sx-Claude-Skills Formatına Paketle

## Sabit Referanslar

```
Sx-Claude-Skills repo (local) : /Users/sultan/Desktop/Sx-Claude-Skills
Sx-Claude-Skills GitHub        : https://github.com/sultanxgokce/Sx-Claude-Skills
catalog.json                   : /Users/sultan/Desktop/Sx-Claude-Skills/catalog.json
pCloud klasör ID               : 23473046120
pCloud public URL              : https://filedn.eu/lNbvMu0swIW8D7ExzploSu8/Sx-Claude-Skills/AiSkills/
Nexus API                      : https://nexusapp.up.railway.app
Nexus Skill Kataloğu ID        : 7e98409a-1f26-48d3-afe2-468135f0bca6
```

## SKILL.md Frontmatter Standardı

Her skill şu frontmatter ile başlar:

```yaml
---
name: skill-adi            # kebab-case, küçük harf
type: feature | agent      # feature = kod üretir, agent = altyapı kurar
version: 1.0.0
description: >
  Tek cümle, ne yaptığını açıklar.
prerequisites:             # type: feature için
  backend: FastAPI, SQLModel, PostgreSQL
  frontend: Next.js App Router, React 19, Tailwind CSS v4
stacks: [fastapi+nextjs]   # veya ["*"] agent için
author: sultanxgokce
source: https://github.com/sultanxgokce/MMEpanel  # kaynak proje
tags: [tag1, tag2, tag3]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---
```

## catalog.json Entry Formatı

```json
{
  "id": "skill-adi",
  "type": "feature",
  "name": "Skill Görünen Adı",
  "version": "1.0.0",
  "description": "Tek cümle açıklama.",
  "prerequisites": {
    "backend": ["FastAPI", "SQLModel", "PostgreSQL"],
    "frontend": ["Next.js App Router", "React 19", "Tailwind CSS v4"]
  },
  "tags": ["tag1", "tag2"],
  "stacks": ["fastapi+nextjs"],
  "author": "sultanxgokce",
  "source": "https://github.com/sultanxgokce/MMEpanel",
  "install_time": "~Xh",
  "status": "stable",
  "path": "skill-adi/SKILL.md",
  "nexus_catalog": "AI Engineer Workbook > Skill Kataloğu",
  "installed_in": ["MMEpanel"]
}
```

## Nexus Record Oluşturma

```bash
curl -X POST https://nexusapp.up.railway.app/api/smart-notes/7e98409a-1f26-48d3-afe2-468135f0bca6/records \
  -H "Content-Type: application/json" \
  -d '{
    "templateId": "7e98409a-1f26-48d3-afe2-468135f0bca6",
    "values": {
      "skill_adi": "SKILL_ADI",
      "versiyon": "1.0.0",
      "proje": "MMEpanel",
      "durum": "Aktif",
      "repo_url": "https://github.com/sultanxgokce/Sx-Claude-Skills/blob/main/SKILL_ADI/SKILL.md",
      "notlar": "KISA_ACIKLAMA. Tarih: TARIH."
    }
  }'
```

---

## Adımlar

### 1. Argümanı oku

`$ARGUMENTS` içinden modül adını al. Yoksa sor:
> "Hangi modülü paketleyeceğiz? (örn: finans, depo, kullanici-yonetimi)"

### 2. Modül kodunu analiz et

Şu konumlarda ara (mevcut projeye göre):
```
backend/models/{modul}.py
backend/schemas/{modul}.py
backend/api/v1/endpoints/{modul}/
frontend/src/app/*/{modul}/
frontend/src/components/{modul}/
frontend/src/hooks/use{Modul}.ts
frontend/src/types/{modul}.ts
```

Her dosya için not al:
- Proje-özel import'lar (from backend.core.security, from backend.db.session vb.)
- Proje-özel sabitler (tablo adları, URL prefix'ler)
- Dışarıdan gelecek olan şeyler (User modeli, auth dependency)

### 3. Sx-Claude-Skills'te klasör aç

```
/Users/sultan/Desktop/Sx-Claude-Skills/{modul-adi}/
├── SKILL.md
├── CHANGELOG.md
└── templates/
    ├── backend/
    │   ├── model.py
    │   ├── schema.py
    │   └── endpoint.py
    ├── frontend/
    │   ├── components/
    │   ├── hooks/
    │   └── types/
    └── migrations/
        └── 001_{modul}_tables.sql
```

### 4. Templates'i adapte et

Her dosyayı kopyalarken:
- Proje-özel import'ları `# → kendi import path'ini kullan` yorumuyla işaretle
- Sabit değerleri (`DATABASE_URL`, proje adı vb.) environment variable veya config'e taşı
- `**Adaptasyon notları:**` bölümü ekle

### 5. SKILL.md oluştur

Frontmatter standardını kullan. Kurulum adımları:
1. Backend — Model
2. Backend — Schema  
3. Backend — Endpoint (router'ı api.py'a ekle)
4. Migration (SQL)
5. Frontend — Dosyaları kopyala
6. Frontend — Layout/routing'e bağla
7. Doğrulama senaryoları

Her adımda adaptasyon notları ekle.

### 6. CHANGELOG.md oluştur

```markdown
# Changelog — {modul-adi}

## [1.0.0] — {TARIH}

### Kaynak
MMEpanel {ModulKodu} modülünden extract edildi.

### Özellikler
- [özellik 1]
- [özellik 2]
```

### 7. catalog.json güncelle

`/Users/sultan/Desktop/Sx-Claude-Skills/catalog.json` dosyasını oku.
`skills` array'ine yeni entry ekle. `"version"` ve `"updated"` alanlarını güncelle.

### 8. Push

```bash
cd /Users/sultan/Desktop/Sx-Claude-Skills
git add {modul-adi}/ catalog.json
git commit -m "feat({modul-adi}): v1.0.0 — MMEpanel {ModulKodu}'den extract"
git push origin main
```

### 9. Nexus'a kaydet

Yukarıdaki curl komutunu çalıştır. Başarılı response'da `"id"` alanı döner.

### 10. Rapor ver

```
✅ {modul-adi} v1.0.0 paketlendi

📁 Repo   : github.com/sultanxgokce/Sx-Claude-Skills/{modul-adi}/
📋 Nexus  : AI Engineer Workbook > Skill Kataloğu
🗂️ Dosya  : {N} backend, {M} frontend dosyası templates'e taşındı

Başka bir projede kurmak için:
"Sx-Claude-Skills/{modul-adi}/SKILL.md dosyasını oku ve bu projeye kur"
```
