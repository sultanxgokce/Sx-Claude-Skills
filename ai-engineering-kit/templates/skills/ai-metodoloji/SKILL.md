---
name: ai-metodoloji
description: AI ajanın çalışma metodolojisini denetler — bağlam kalitesi, hafıza sağlığı, reasoning verimliliği, orchestration, hata tekrarı. /ai-upgrade neye sahibiz sorusunu cevaplar, bu skill nasıl çalışıyoruz sorusunu.
---

> **Her çalıştırmadan önce OKU:**
> 1. `_agents/ai-research/METODOLOJI_LOG.md` — önceki denetim skorları ve trendler
> 2. `_agents/CONTEXT.md` — güncel proje durumu (varsa)
>
> **Her çalıştırma sonunda YAZ:**
> 1. `_agents/ai-research/METODOLOJI_LOG.md`'ye yeni oturum ekle
> 2. Tespit edilen yapısal sorunları ilgili dosyalarda düzelt (onay alarak)

# AI Metodoloji Denetimi

## Temel Ayrım

| Komut | Soru | Odak |
|-------|------|------|
| `/ai-upgrade` | Neye sahibiz? | Yeni skill, MCP, repo ekleme |
| `/ai-metodoloji` | Nasıl çalışıyoruz? | Bağlam kalitesi, reasoning, orchestration, hafıza |

**Bu skill araç eklemez. Çalışma sistemini ölçer ve iyileştirir.**

---

## AŞAMA 1: Bağlam Sağlığı

### 1.1 — CONTEXT.md Kalitesi

```bash
# Varsa CONTEXT.md'yi kontrol et
[ -f "_agents/CONTEXT.md" ] && wc -l _agents/CONTEXT.md && git log --format="%ar" _agents/CONTEXT.md | head -1 || echo "CONTEXT.md yok"
```

Değerlendir:
- **Tazelik:** Son güncelleme ne zaman? 3+ gün eskiyse stale.
- **Doluluk:** Tamamlanan işler hâlâ "Bekleyen" bölümünde mi?
- **Boyut:** 200+ satır → sıkıştırma zamanı?

Skor: 10 (güncel+temiz) → 5 (stale maddeler var) → 0 (1+ hafta güncellenmemiş)

### 1.2 — Proje Kural Dosyası (CLAUDE.md veya benzeri)

```bash
# CLAUDE.md veya .cursorrules veya benzeri kural dosyası
[ -f "CLAUDE.md" ] && git log --format="%ar" CLAUDE.md | head -1 || echo "Kural dosyası yok"
```

Sına:
- Son 10 commit'te kural ihlali var mı? (`git log --oneline -20`)
- Çelişen kurallar?
- Artık geçersiz referanslar?
- Son oturumlarda tekrarlanan uyarı CLAUDE.md'ye eklenmemiş mi?

Skor: 10 (güncel+tutarlı) → 5 (1-2 eski kural) → 0 (sık ihlal)

---

## AŞAMA 2: Hafıza Sağlığı

### 2.1 — Memory Dosyalarını Tara

```bash
# Projenin memory dizinini bul
PROJECT_PATH=$(pwd)
MEMORY_DIR=$(find ~/.claude/projects -maxdepth 2 -name "MEMORY.md" 2>/dev/null | head -1 | xargs dirname 2>/dev/null)
[ -n "$MEMORY_DIR" ] && ls "$MEMORY_DIR" || echo "Memory dizini bulunamadı"
```

Tespit et:
- **Stale project memory:** "Önümüzdeki hafta" gibi geçmiş kalmış maddeler
- **Eksik feedback:** Son oturumlarda tekrarlanan düzeltme memory'ye kaydedilmemiş mi?
- **Duplicate:** Aynı konuda 2+ memory dosyası?

Skor: 10 (temiz+güncel) → 5 (2-3 stale) → 0 (çoğu stale)

### 2.2 — Known-Errors Güncelliği

```bash
[ -f "_agents/known-errors.md" ] && git log --format="%ar" _agents/known-errors.md | head -1 || echo "known-errors.md yok"
```

- Son keşfedilen hatalar eklendi mi?
- Tekrar eden hatalar var mı?
- Çözülmüş ama "çözülmedi" işaretli?

Skor: 10 (her hata kayıtlı) → 5 (son 2-3 eksik) → 0 (haftalarca güncellenmemiş)

---

## AŞAMA 3: Skill Kalitesi ve Kullanım

### 3.1 — Skill Frekansı

```bash
# Mevcut skill'leri listele
ls _agents/skills/ 2>/dev/null || echo "Skill dizini yok"

# Git'te skill'lere son referanslar
git log --format="%ar %s" -- _agents/skills/ 2>/dev/null | head -10
```

Her skill için: son kullanım tarihi, güncellik, etkinlik.

### 3.2 — Boşluk Analizi

```bash
git log --oneline -30 2>/dev/null
```

- 3+ kez aynı tip iş yapıldı mı? → Skill öner
- Hangi tekrarlayan görev var ama skill yok?

Skor: 10 (tümü güncel+kullanılıyor) → 5 (bazı stale) → 0 (çoğu unused)

---

## AŞAMA 4: Reasoning Verimliliği

### 4.1 — İterasyon Sayısı

```bash
git log --oneline -30 --format="%s" 2>/dev/null
```

- Ortalama bug fix kaç commit? Hedef: 1-2
- `fix: fix` veya `fix: revert` kalıpları? → Yanlış çözüm işareti
- Aynı dosya birden fazla commit'te?

### 4.2 — Doğrulama Uyumu

- Build kanıtı olmadan push edilen commit var mı?
- Verification protokolü uygulanıyor mu?

### 4.3 — Context Şişmesi

```bash
wc -l _agents/ai-research/SESSION_LOG.md _agents/ai-research/METODOLOJI_LOG.md 2>/dev/null
```

Skor: 10 (1-2 commit/fix, doğrulama var) → 5 (bazı parçalı) → 0 (fix-fix dolu)

---

## AŞAMA 5: Orchestration Kalitesi

Multi-agent sistemi varsa kontrol et:
```bash
[ -f "_agents/orchestration/BOARD.md" ] && git log --format="%ar" _agents/orchestration/BOARD.md | head -1 || echo "Orchestration sistemi yok"
```

- BOARD.md güncel mi?
- Ajan START promptları stale mi?
- Paralel tool çağrıları kullanılıyor mu?

Orchestration sistemi yoksa → bu boyut için 5/10 (nötr) ver.

Skor: 10 (güncel+aktif) → 5 (stale ama mevcut) → 0 (tamamen kullanılmıyor)

---

## AŞAMA 6: Hook ve Otomasyon

### 6.1 — Mevcut Hook'lar

```bash
# Proje hook'ları
cat .claude/settings.json 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
hooks=d.get('hooks',{})
for e,h in hooks.items():
    print(f'{e}: {len(h)} hook')
" 2>/dev/null || echo "Hook yok"
```

- False positive üretiyor mu?
- Eksik kritik otomasyon var mı?

### 6.2 — Eksik Otomasyon

- Her commit öncesi manuel build? → pre-commit hook öner
- Her deploy sonrası manuel kontrol? → post-deploy hook öner

Skor: 10 (kritik işler otomatik) → 5 (2-3 manuel) → 0 (hook yok)

---

## AŞAMA 7: Skor ve Öneriler

```
| Boyut                 | Skor | Ağırlık | Ağırlıklı |
|-----------------------|------|---------|-----------|
| Bağlam Sağlığı        | ?/10 | 20%     | ?         |
| Hafıza Sağlığı        | ?/10 | 20%     | ?         |
| Skill Kalitesi        | ?/10 | 15%     | ?         |
| Reasoning Verimliliği | ?/10 | 20%     | ?         |
| Orchestration         | ?/10 | 15%     | ?         |
| Hook/Otomasyon        | ?/10 | 10%     | ?         |
| TOPLAM                |      | 100%    | ?.?/10    |
```

En düşük 3 alandan **en fazla 3 öneri** sun:

```
### [1] İyileştirme Adı
**Boyut:** Hangi aşama
**Etki:** Ne değişir?
**Çaba:** Düşük (~5dk) / Orta (~30dk) / Yüksek (~2saat)
```

**RAPORU SUNDUKTAN SONRA DUR.**

---

## AŞAMA 8: Uygulama (Onay Sonrası)

| Tür | Yapılacak |
|-----|-----------|
| Bağlam | CONTEXT.md temizle, CLAUDE.md kural ekle |
| Hafıza | Stale memory güncelle/sil, known-errors ekle |
| Skill | SKILL.md güncelle, yeni skill taslağı |
| Hook | `.claude/settings.json` güncelle |
| Orchestration | BOARD.md güncelle, stale prompt yenile |

---

## AŞAMA 9: Logla

`_agents/ai-research/METODOLOJI_LOG.md`'ye ekle:

```markdown
## Denetim [N] — [YYYY-MM-DD]

| Boyut | Önceki | Bu Oturum | Değişim |
|-------|--------|-----------|---------|
| Bağlam | - | ?/10 | +/- |
| Hafıza | - | ?/10 | +/- |
| Skill | - | ?/10 | +/- |
| Reasoning | - | ?/10 | +/- |
| Orchestration | - | ?/10 | +/- |
| Hook | - | ?/10 | +/- |
| **TOPLAM** | - | ?.?/10 | +/- |

### Uygulanan
- [ ] ...

### Sonraki Denetimde
- [ ] ...
```

---

## Kural Özeti

```
ÖLÇMEDEN ÖNCE KOD AÇMA.
Skor < 7 → önce metodoloji düzelt.
Skor ≥ 7 → /ai-upgrade ile araç ekle.
Onay almadan dosya değiştirme.
Kanıtsız "iyileşti" deme.
```
