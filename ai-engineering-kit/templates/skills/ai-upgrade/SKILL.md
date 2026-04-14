---
name: ai-upgrade
description: Projedeki Claude AI ajan altyapısını analiz et, repo kataloğuna bak, iyileştirme öner ve uygula. Her çalıştırmada önceki/sonraki durumu SESSION_LOG'a kaydet.
---

> **Her çalıştırmadan önce OKU:**
> 1. `_agents/ai-research/REPO_CATALOG.md` — bilinen repo'lar ve değerlendirmeler
> 2. `_agents/ai-research/SESSION_LOG.md` — geçmiş oturumlar, mevcut skor, planlanan iyileştirmeler
>
> **Her çalıştırma sonunda YAZ:**
> 1. SESSION_LOG.md'ye yeni oturum bölümü ekle
> 2. REPO_CATALOG.md'deki "Durum" alanlarını güncelle

# AI Upgrade — Agent Mühendislik Sistemi

## Genel Bakış

Bu skill projenin Claude AI ajan altyapısını sürekli geliştirmek için çalışır.
Her oturumda: **mevcut durumu ölç → boşlukları bul → iyileştirme öner → uygula → logla.**

---

## Çalıştırma

Kullanıcı `/ai-upgrade` yazdığında aşağıdaki akışı takip et:

---

## AŞAMA 1: Mevcut Durumu Ölç

### 1.1 — Aktif Skill'leri Listele

```bash
ls _agents/skills/ 2>/dev/null || echo "Henüz skill yok"
```

Her skill için not et: adı, amacı, son ne zaman kullanıldı (git log'dan).

### 1.2 — MCP'leri Kontrol Et

```bash
timeout 15 claude mcp list 2>&1
```

Hangi MCP'ler aktif? Hangisi eksik?

### 1.3 — Hook'ları Kontrol Et

```bash
# Proje hook'larını kontrol et
cat .claude/settings.json 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
hooks=d.get('hooks',{})
print(json.dumps(hooks, indent=2) if hooks else 'Hook tanımlı değil')
" 2>/dev/null || echo "Hook yok"
```

### 1.4 — SESSION_LOG Skorunu Oku

`_agents/ai-research/SESSION_LOG.md`'den son skoru oku. Bu oturumun başlangıç skoru budur.

### 1.5 — Sonuç Tablosu

```
| Alan               | Mevcut Durum        | Skor (0-10) |
|--------------------|---------------------|-------------|
| Skill zenginliği   | X aktif skill       | ?/10        |
| MCP kapsama        | X MCP               | ?/10        |
| Self-improvement   | Manuel/Otomatik     | ?/10        |
| Otomasyon (hooks)  | Var/Yok             | ?/10        |
| Codebase analiz    | Repomix var/yok     | ?/10        |
```

---

## AŞAMA 2: Boşluk Analizi

REPO_CATALOG.md'den öncelik sırasına göre uygulanmamış iyileştirmeleri listele:

**Sorgular:**
- Durum `yeni` veya `değerlendirildi` olan repo'larda alınabilecek ne var?
- SESSION_LOG'daki "Planlanan İyileştirmeler" listesinde ne kaldı?
- Bu oturumda kullanıcının aktif çalıştığı alan ne? — o alana uygun öneri ver.

**Boşluk kategorileri:**
1. 🔴 KRİTİK — Hemen uygulanabilir, yüksek etki
2. 🟡 ORTA — Biraz kurulum gerektirir
3. 🟢 DÜŞÜK — Uzun vadeli, araştırma gerektirir

---

## AŞAMA 3: İyileştirme Önerileri Sun

Kullanıcıya en fazla **3 öneri** sun.

Her öneri için şunu göster:

```
### [X] Öneri Adı
**Kaynak:** repo/skill adı
**Kategori:** MCP / SKILL / HOOK / TOOL
**Kurulum süresi:** ~5 dakika / ~30 dakika / ~2 saat
**Fayda:** Ne değişecek? Hangi problemi çözer?
**Projeye özel:** Hangi mevcut iş akışını geliştirir?
**Kurulum adımları:**
  1. ...
  2. ...
```

**RAPORU SUNDUKTAN SONRA DUR.** Kullanıcı onay verene kadar uygulama yapma.

---

## AŞAMA 4: Uygulama (Onay Sonrası)

### MCP Kurulumu
```bash
claude mcp add <isim> <komut>
timeout 15 claude mcp list 2>&1   # doğrula
```

### Skill Ekleme
- Skill dosyasını `_agents/skills/<isim>/SKILL.md` olarak oluştur
- `.claude/settings.json`'a skill referansı ekle (gerekirse)

### Hook Ekleme
- `.claude/settings.json`'daki `hooks` bölümüne ekle
- `PreToolUse` veya `PostToolUse` event'ini kullan

### Repomix Kurulumu
```bash
npm install -g repomix && repomix --version
```

**Her uygulama sonrası doğrula:** `claude mcp list` / `ls _agents/skills/` / ilgili test

---

## AŞAMA 5: Yeni Repo Ekleme (İsteğe Bağlı)

Kullanıcı yeni bir GitHub repo paylaşırsa:
1. WebFetch ile README'yi çek
2. Kategori (SKILLS / MCP / TOOL / TEMPLATE / UI) ve öncelik (🔴🟡🟢) belirle
3. REPO_CATALOG.md'ye ekle

---

## AŞAMA 6: Oturum Logla

`_agents/ai-research/SESSION_LOG.md`'ye yeni bölüm ekle:

```markdown
## Oturum [N] — [YYYY-MM-DD]

### Başlangıç Skoru: X.X/10

### Yapılanlar
- [ ] Öneri adı — [uygulandı / ertelendi / iptal]

### Bitiş Skoru: Y.Y/10
### Skor Değişimi: +Z.Z (neden?)

### Bir Sonraki Oturumda Bak
- [ ] ...
```

---

## Kurallar

```
DURUMU ÖLÇ → BOŞLUK BUL → 3 ÖNERİ SUN → ONAY BEKLE → UYGULA → DOĞRULA → LOGLA
Her oturumda en az 1 iyileştirme hedefle.
"Büyük ihtimalle çalışıyor" deme — test et ve kanıtla.
Skor düşerse nedenini açıkla.
```
