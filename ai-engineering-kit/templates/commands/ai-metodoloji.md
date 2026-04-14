# /ai-metodoloji — AI Agent Metodoloji Denetimi

Bu komut Claude AI ajanının **nasıl çalıştığını** denetler.
`/ai-upgrade` neye sahibiz sorusunu cevaplarken bu komut nasıl çalışıyoruz sorusunu cevaplar.

---

## Ne Denetler?

| Boyut | Ağırlık | Açıklama |
|-------|---------|----------|
| Bağlam Sağlığı | 20% | CONTEXT.md tazeliği, CLAUDE.md kural geçerliliği |
| Hafıza Sağlığı | 20% | Memory dosyaları, known-errors, stale kayıtlar |
| Skill Kalitesi | 15% | Kullanım frekansı, boşluk analizi |
| Reasoning Verimliliği | 20% | İterasyon sayısı, doğrulama uyumu |
| Orchestration | 15% | Multi-agent sistemi, ajan promptları |
| Hook/Otomasyon | 10% | Mevcut etkinlik, eksik otomasyonlar |

---

## Çalıştırma Akışı

`_agents/skills/ai-metodoloji/SKILL.md` dosyasını oku ve 9 aşamalı denetimi uygula.

---

## Kaynak Dosyalar

- **Detaylı akış:** `_agents/skills/ai-metodoloji/SKILL.md`
- **Denetim logu:** `_agents/ai-research/METODOLOJI_LOG.md`

---

## Öncelik Kuralı

```
Metodoloji < 7  →  /ai-metodoloji önce (sistemi düzelt)
Metodoloji ≥ 7  →  /ai-upgrade ile yeni araç ekle
İkisi ≥ 7       →  Yeni modül / özellik geliştir
```
