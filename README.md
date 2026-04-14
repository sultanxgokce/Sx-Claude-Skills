# Sx-Claude-Skills

Claude Code ile kullanılabilen, taşınabilir modül skill'leri koleksiyonu.

Her skill bir `SKILL.md` içerir — Claude Code bu dosyayı okuyarak modülü
hedef projeye otomatik adapte eder.

## Skill'ler

| Skill | Versiyon | Stack | Açıklama |
|-------|----------|-------|----------|
| [feedback-widget](./feedback-widget/) | 1.0.0 | FastAPI + Next.js | In-app geri bildirim widget'ı |

## Nasıl Kullanılır

### Yeni projede skill kurulumu

```
Claude Code'a de ki:
"Sx-Claude-Skills/feedback-widget/SKILL.md dosyasını oku ve bu projeye kur"
```

Claude Code:
1. `SKILL.md`'yi okur
2. Hedef projenin yapısını (auth, routing, DB) analiz eder
3. `templates/` içindeki dosyaları adapte ederek kopyalar
4. Migration'ı çalıştırır

### Manuel kurulum

Her skill klasöründeki `SKILL.md` dosyasını oku — adım adım kurulum talimatları var.

## Katkı

Yeni bir modülü skill olarak paketlemek için:
1. `{skill-adi}/SKILL.md` oluştur (bu repo'daki format'ı takip et)
2. `templates/` altına kaynak dosyaları ekle
3. `README.md` tablosunu güncelle

## pCloud Storage

Skill'lerin ürettiği dosyalar (görseller, ekler) şu klasöre yüklenir:

```
Public Folder / Sx-Claude-Skills / AiSkills /
Folder ID: 23473046120
Public URL: https://filedn.eu/lNbvMu0swIW8D7ExzploSu8/Sx-Claude-Skills/AiSkills/
```
