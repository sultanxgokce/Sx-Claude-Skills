---
name: yt-transcript
type: agent
version: 1.0.0
description: >
  YouTube videosunu okunabilir dokümana dönüştürür. Altyazı varsa direkt çeker,
  yoksa Whisper ile transkripsiyon yapar. Claude (OpenRouter) ile temizler ve
  PDF veya Word olarak kaydeder.
prerequisites:
  python: ">=3.9"
  packages:
    - youtube-transcript-api
    - yt-dlp
    - openai-whisper
    - python-docx
    - fpdf2
    - httpx
stacks: ["*"]
author: sultanxgokce
tags: [youtube, transcript, whisper, pdf, word, docx, openrouter, ai]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# YouTube Transcript Skill

YouTube videosunu düzgün biçimlendirilmiş, okunabilir bir dokümana dönüştürür.
`/yt-transcript <URL>` ile çağrılır.

## Ne Yapar

1. YouTube URL'den video ID çıkarır
2. `youtube-transcript-api` ile altyazı/otomatik CC çeker (hızlı, ücretsiz)
3. Altyazı yoksa `yt-dlp` ile ses indirir, `whisper` ile transkripsiyon yapar
4. Ham metni Claude (OpenRouter üzerinden) ile formatlar — paragraflar, başlıklar, temiz dil
5. Seçilen formatta (`--format pdf` veya `--format word`) kaydeder

## Kurulum

```bash
# 1. Repo'dan templates/scripts/yt_transcript.py dosyasını kopyala
cp templates/scripts/yt_transcript.py ~/scripts/yt_transcript.py

# 2. Bağımlılıkları kur
pip install youtube-transcript-api yt-dlp openai-whisper python-docx fpdf2 httpx

# 3. OpenRouter API key'ini ayarla
export OPENROUTER_API_KEY="sk-or-..."

# 4. Slash komutunu kur
cp templates/commands/yt-transcript.md ~/.claude/commands/yt-transcript.md
```

## Kullanım

```
/yt-transcript https://youtube.com/watch?v=xxx
/yt-transcript https://youtube.com/watch?v=xxx --format word
/yt-transcript https://youtube.com/watch?v=xxx --format pdf
/yt-transcript https://youtube.com/watch?v=xxx --format word --lang tr
```

### Parametreler

| Parametre | Varsayılan | Açıklama |
|-----------|-----------|----------|
| `URL` | — | YouTube video URL'i (zorunlu) |
| `--format` | `word` | Çıktı formatı: `word` veya `pdf` |
| `--lang` | `tr` | Öncelikli dil kodu (altyazı için) |
| `--output` | `./` | Çıktı dizini |
| `--whisper-model` | `base` | Whisper model boyutu: `tiny`, `base`, `small`, `medium`, `large` |

## Çıktı Formatı

```
# Video Başlığı

**Kaynak:** https://youtube.com/watch?v=xxx
**Tarih:** 2026-04-30
**Süre:** 45 dk

---

## Giriş

[temizlenmiş, paragraflanmış metin...]

## Ana Konu

[devam...]
```

## Teknik Akış

```
YouTube URL
    │
    ▼
youtube-transcript-api ──► başarılı → ham altyazı
    │ başarısız
    ▼
yt-dlp (ses indir, temp .mp3)
    │
    ▼
whisper (yerel transkripsiyon)
    │
    ▼
Claude via OpenRouter (format + temizle)
    │
    ▼
python-docx (.docx) veya fpdf2 (.pdf)
```

## OpenRouter Konfigürasyonu

Skill, `OPENROUTER_API_KEY` env değişkenini kullanır.
Model: `anthropic/claude-3-5-haiku` (hızlı + ucuz, formatlama için yeterli)

```python
# Özel model kullanmak için
export OPENROUTER_MODEL="anthropic/claude-sonnet-4-5"
```

## Notlar

- Whisper `base` model ~150MB, ilk çalışmada indirilir
- Uzun videolarda (60dk+) whisper yavaş çalışır — `--whisper-model tiny` dene
- Altyazısız ve whisper olmadan çalışmaz — ffmpeg kurulu olmalı (`brew install ffmpeg`)
