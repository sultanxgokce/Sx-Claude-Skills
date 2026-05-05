---
sayfa_id: wiki._index
kategori: index-master
son_guncelleme: 2026-05-05
guvenilirlik: yüksek
önem: 5
etiketler: [meta, master-index, navigation]
---

# Cortex Wiki — Master Index

Sultan'ın dijital ikinci beyninin **giriş kapısı**. Tüm branch'ler buradan dallanır. 6 yıllık ufuk için **bu sayfa hep güncel olmalı**.

---

## 🌳 Branch'ler

### 🧠 Sultan (Sultan'ın Profili & Vizyonları)
[`sultan/_index.md`](sultan/_index.md) — kişisel profil, düşünce tarzı, uzun-vade vizyonlar

| Dosya | Konu | Önem |
|-------|------|------|
| [sultan/profil.md](sultan/profil.md) | Sultan'ın kim olduğu, rol, hedefler | ⭐⭐⭐⭐⭐ |
| [sultan/dusunce-tarzi.md](sultan/dusunce-tarzi.md) | Karar verme, problem çözme stili | ⭐⭐⭐⭐ |
| [sultan/vizyon-digital-sultan.md](sultan/vizyon-digital-sultan.md) | Digital Sultan vizyon (uzun-vade hedef) | ⭐⭐⭐⭐⭐ |
| [sultan/mitoz-bolunme-vizyonu.md](sultan/mitoz-bolunme-vizyonu.md) | Mitoz bölünme — sistem büyüme felsefesi | ⭐⭐⭐⭐⭐ |
| [sultan/sistem-rehberi.md](sultan/sistem-rehberi.md) | Sistemin nasıl kullanılacağı | ⭐⭐⭐⭐ |
| [sultan/2-gun-takip-notlari.md](sultan/2-gun-takip-notlari.md) | ⚠️ 286 satır — bölünmesi gerek (atomicity) | ⭐⭐ |

### 📐 Kararlar (Mimari & Stratejik)
[`kararlar/_index.md`](kararlar/_index.md)

| Dosya | Konu | Önem |
|-------|------|------|
| [kararlar/cortex-mimarisi.md](kararlar/cortex-mimarisi.md) | Cortex'in genel mimarisi | ⭐⭐⭐⭐⭐ |
| [kararlar/agac-index-mimarisi.md](kararlar/agac-index-mimarisi.md) | Ağaç-index pattern (Karpathy-inspired) | ⭐⭐⭐⭐⭐ |
| [kararlar/ambient-cortex-mimarisi.md](kararlar/ambient-cortex-mimarisi.md) | Ambient bilgi yakalama | ⭐⭐⭐⭐ |
| [kararlar/karar-pipeline-vizyonu.md](kararlar/karar-pipeline-vizyonu.md) | Karar verme pipeline'ı | ⭐⭐⭐⭐ |
| [kararlar/ruya-dongusu-implementasyonu.md](kararlar/ruya-dongusu-implementasyonu.md) | Dream cycle (günlük rüya raporu) | ⭐⭐⭐⭐ |
| [kararlar/query-geri-yazma-koprusu.md](kararlar/query-geri-yazma-koprusu.md) | Query rewrite köprüsü | ⭐⭐⭐ |
| [kararlar/memex-paketleme-plani.md](kararlar/memex-paketleme-plani.md) | Memex paketleme | ⭐⭐⭐ |
| [kararlar/nexus-harita-arayuz-vizyonu.md](kararlar/nexus-harita-arayuz-vizyonu.md) | Nexus harita UI | ⭐⭐⭐ |

### 💡 Konular (Teknik Araştırmalar)
[`konular/_index.md`](konular/_index.md)

| Dosya | Konu | Önem |
|-------|------|------|
| [konular/karpathy-skills-4-katman.md](konular/karpathy-skills-4-katman.md) | Karpathy 4-katman skill mimarisi | ⭐⭐⭐⭐ |
| [konular/pgvector-entegrasyon.md](konular/pgvector-entegrasyon.md) | pgvector kurulum (Faz 2) | ⭐⭐⭐⭐ |
| [konular/context-limit-cozumu.md](konular/context-limit-cozumu.md) | Context window limit yönetimi | ⭐⭐⭐ |
| [konular/mert-jarvis-karpathy-implementasyonu.md](konular/mert-jarvis-karpathy-implementasyonu.md) | Mert Jarvis pattern | ⭐⭐⭐ |
| [konular/raw-wiki-aktarim-mekanizmasi.md](konular/raw-wiki-aktarim-mekanizmasi.md) | Raw → Wiki distill akışı | ⭐⭐⭐⭐ |

### 🌐 Nexus Projesi
[`nexus/_index.md`](nexus/_index.md)

| Dosya | Konu | Önem |
|-------|------|------|
| [nexus/profil.md](nexus/profil.md) | Nexus genel profili | ⭐⭐⭐⭐ |
| [nexus/aktif-gorevler.md](nexus/aktif-gorevler.md) | Mevcut hafta görevleri | ⭐⭐⭐ |

### 🛠 MMEpanel Projesi
[`mmepanel/_index.md`](mmepanel/_index.md)

| Dosya | Konu | Önem |
|-------|------|------|
| [mmepanel/profil.md](mmepanel/profil.md) | MMEpanel genel profili | ⭐⭐⭐⭐ |
| [mmepanel/aktif-gorevler.md](mmepanel/aktif-gorevler.md) | Aktif görevler — Veri Genom ile senkron olmalı | ⭐⭐⭐⭐ |

⚠️ **Not (2026-05-05 audit):** MMEpanel branch'i hem burada hem `MMEpanel/_agents/docs/veri-genom/` altında. Çift-kaynak riski. Master truth olarak Veri Genom (commit history ile) kabul edilmeli, Cortex aynalı.

### 🔗 Bağlantılar
[`baglantilar/_index.md`](baglantilar/_index.md) — dış kaynak referansları

---

## 🚨 Aktif Açık Sorular

→ [_open_questions.md](_open_questions.md)

## 📈 Audit History

→ [_audit_history.md](_audit_history.md)

---

## 📌 Cortex Disiplini

1. **Frontmatter zorunlu** — `sayfa_id`, `kategori`, `son_guncelleme`, `guvenilirlik`, `önem`, `etiketler`, `ilgili`
2. **Atomicity** — 1 sayfa = 1 konsept. 200+ satırda böl.
3. **Backlink her iki yönde** — A→B linki varsa B'de de A bahsedilmeli (manuel veya otomatik script)
4. **Tarih kanıtı** — her güncellemede `son_guncelleme` çek
5. **Açık sorular** — `S1:`, `?:`, `TODO` görenler `_open_questions.md`'ye taşı

## 🔧 Bakım

`/memory-audit` slash komutu (haftalık) — bu index'i ve genel sağlığı izler.
