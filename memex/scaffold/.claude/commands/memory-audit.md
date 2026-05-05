---
description: Cortex + Veri Genom hafıza sistemlerini audit + tamirat (haftalık ya da on-demand)
---

# /memory-audit — Hafıza Sistemi Audit + Tamirat Protokolü

## Amaç

Sultan'ın AI hafıza sistemleri (Nexus Cortex + MMEpanel Veri Genom) **6 yıl boyunca** sağlıklı kalsın. Bilgi yığıldıkça çöplük oluşmasın — düzenli aralıklarla:
- İzole dosyaları tespit et (link verilmemiş)
- Frontmatter tutarsızlıklarını yakala
- Duplikasyonları bul (aynı bilgi 2+ yerde)
- Stale/conflict durumlarını tara
- Açık soruları topla
- KPI snapshot al
- Tamirat uygula (kullanıcı onayıyla)

**Endüstri kaynağı:** Cognee `memify` pattern — periyodik consolidation. Graphiti bi-temporal. Letta self-edit. Veri Genom: `kavramlar/cortex-mimarisi.md` (eğer varsa).

---

## Çalıştırma Modları

| Mod | Komut | Davranış |
|-----|-------|----------|
| **Audit-only** | `/memory-audit` | Sadece raporla, dokunma |
| **Tamirat** | `/memory-audit fix` | Tamirat öner + onayla → uygula |
| **Sadece Cortex** | `/memory-audit cortex` | Nexus repo (cortex/ + ui/prisma) |
| **Sadece Veri Genom** | `/memory-audit veri-genom` | MMEpanel `_agents/docs/veri-genom/` |
| **Otomatik (cron)** | `/memory-audit auto` | Tamirat onaysız uygula (sadece güvenli olanlar) |

---

## Audit Kapsamı

### A. Yapısal Sağlık (mekanik)

1. **Frontmatter tutarlılığı:**
   - Her `wiki/kavramlar/*.md` ve `cortex/wiki/**/*.md` dosyada YAML frontmatter var mı?
   - Zorunlu alanlar: `gen_id`, `kategori`, `son_guncelleme`, `guvenilirlik`, `önem`, `tags`, `ilgili`
   - **Tamirat:** Eksik alanlar için template ekle, `son_guncelleme` bugüne çek

2. **İzole dosyalar (orphan):**
   - `ilgili:` array'i boş VEYA dosya hiç linke alınmamış (backlink=0)
   - **Tamirat:** Manuel inceleme (otomatik link tehlikeli)

3. **Merkezi index:**
   - `wiki/kavramlar/_index.md` var mı? Tüm dosyaları listeliyor mu?
   - **Tamirat:** Eksikse oluştur (kategori bazlı tablo)

4. **Dosya boyutu:**
   - `wc -l` ile, 200+ satır olan dosyaları flag'le (atomicity ihlali şüphesi)
   - **Tamirat:** Manuel bölme önerisi (otomatik değil)

### B. İçerik Kalitesi (semantik)

5. **Duplikasyon tespiti:**
   - Aynı sabit/kavram 2+ dosyada açıklanmış mı? (`UCRETSIZ_KAPANIS_KONUMLARI` 3 dosyada gibi)
   - **Tamirat:** Kanonik dosya seç, diğerleri "→ X.md'ye bak" link'i ile değiştir

6. **Stale tespit:**
   - `son_guncelleme` 60+ gün öncesi VE içerikte "yapılacak/sürüyor/eksik" gibi kelimeler
   - **Tamirat:** Manuel inceleme — gerçekten stale mi?

7. **Açık sorular topla:**
   - Tüm dosyalarda `S1:`, `S2:`, `**Açık soru**`, `?:`, `❓`, `[ ] beklemede` pattern'i tara
   - **Tamirat:** `wiki/_open_questions.md` dosyasında topla, kaynak link ekle

### C. KPI Snapshot

8. **Her run'da yaz:** `wiki/_audit_history.md`
   ```
   ## 2026-05-XX
   - Toplam dosya: 57 (Cortex: 29, Genom: 28)
   - Frontmatter eksik: X
   - İzole dosya: Y
   - Açık soru: Z
   - Duplikasyon: N
   - Skor: X/100 (önceki: Y/100, Δ: +Z)
   ```

---

## Tamirat Akışı

```
1. Audit raporu oluştur (tablo halinde)
2. Tamirat önerilerini listele:
   - 🟢 Güvenli (otomatik): frontmatter ekle, son_guncelleme tarihi, _audit_history yaz
   - 🟡 Yarı güvenli (onay gerek): _index.md yenile, _open_questions topla
   - 🔴 Manuel (sadece öner): atomicity bölme, conflict çözümü, stale arşivleme
3. Mod 'fix' ise: 🟢'lar uygula, 🟡'lar tek tek sor
4. Mod 'auto' ise: sadece 🟢'lar
5. KPI snapshot kaydet
6. Sultan'a özet sun
```

---

## Best Practice Çerçeve

Bu komut şu pattern'lere dayanır:

- **Cognee `memify`** (periyodik consolidation): https://www.cognee.ai/blog
- **Graphiti bi-temporal** (versioning): https://github.com/getzep/graphiti
- **Letta self-editing memory**: https://letta.com
- **Open Brain pattern** (raw vs derived ayrımı)

---

## Çıktı Formatı

```markdown
# 📊 Hafıza Audit — 2026-05-XX

## Snapshot
| Metric | Cortex | Veri Genom | Δ |
|--------|--------|------------|---|
| Dosya | 29 | 28 | — |
| Frontmatter ✓ | 20/29 (69%) | 22/28 (79%) | — |
| İzole | 4 | 17 | — |
| Açık soru | 3 | 0 | — |
| Skor | 63/100 | 66/100 | — |

## 🚨 Acil
- ...

## ✅ Tamirat Önerileri
1. 🟢 [auto] _audit_history yaz → uygulandı
2. 🟡 [onay] _index.md güncelle (5 yeni dosya) → ?
3. 🔴 [manuel] `2-gun-takip-notlari.md` 286 satır, böl

## 📈 Trend (son 4 audit)
2026-05-05: 65 → 2026-05-12: 70 → ...
```

---

## Sıklık Önerisi

- **Haftalık** (otomatik cron önerisi): pazartesi sabah 07:00
- **On-demand:** Yeni büyük seans bittiğinde manuel
- **Kritik öncesi:** Embedding model upgrade'inden önce (consolidation şart)

---

## Notlar

- Bu komut **silmez** — sadece **işaretler ve önerir**.
- Tamirat sonrası `git diff` görünür → review edilebilir.
- `_audit_history.md` zamanla **trend graph** verir → sistem sağlığını izle.
