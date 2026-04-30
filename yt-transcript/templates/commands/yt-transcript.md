# /yt-transcript — YouTube Videosunu Dokümana Dönüştür

YouTube video URL'ini al ve okunabilir PDF veya Word dosyasına dönüştür.

## Sabit Referanslar

```
Script           : ~/scripts/yt_transcript.py
Varsayılan çıktı : ~/Downloads/
OpenRouter key   : $OPENROUTER_API_KEY
OpenRouter model : $OPENROUTER_MODEL (varsayılan: anthropic/claude-haiku-4-5)
```

## Kullanım

Kullanıcı şu şekillerde çağırabilir:

```
/yt-transcript https://youtube.com/watch?v=xxx
/yt-transcript https://youtube.com/watch?v=xxx --format word
/yt-transcript https://youtube.com/watch?v=xxx --format pdf
/yt-transcript https://youtube.com/watch?v=xxx --format word --lang en
/yt-transcript https://youtube.com/watch?v=xxx --whisper-model small
```

## Çalıştırma Adımları

### 1. Argümanları parse et

Kullanıcı mesajından şunları çıkar:
- `URL` — YouTube linki (zorunlu)
- `--format` — `word` veya `pdf` (yoksa: `word`)
- `--lang` — dil kodu (yoksa: `tr`)
- `--output` — dizin (yoksa: `~/Downloads/`)
- `--whisper-model` — `tiny`, `base`, `small`, `medium`, `large` (yoksa: `base`)

### 2. OPENROUTER_API_KEY kontrolü

```bash
echo $OPENROUTER_API_KEY
```

Boşsa kullanıcıya sor: "OpenRouter API key'in nedir? `export OPENROUTER_API_KEY=sk-or-...` olarak terminal'e gir ya da bana ilet."

### 3. Script'i çalıştır

```bash
python ~/scripts/yt_transcript.py "<URL>" \
  --format <format> \
  --lang <lang> \
  --output ~/Downloads/ \
  --whisper-model <model>
```

### 4. Sonucu raporla

Script tamamlandığında kullanıcıya şunu söyle:
- Hangi yöntem kullanıldı (altyazı mı, Whisper mi)
- Dosyanın tam yolu
- Dosya boyutu

Hata olursa hata mesajını olduğu gibi göster ve sebebini açıkla.

## Sık Karşılaşılan Sorunlar

| Sorun | Çözüm |
|-------|-------|
| `No transcript found` + whisper çalışmıyor | `brew install ffmpeg` gerekiyor |
| `ModuleNotFoundError` | `pip install youtube-transcript-api yt-dlp openai-whisper python-docx fpdf2 httpx` |
| `OPENROUTER_API_KEY` eksik | Kullanıcıdan iste, ham metin yine de kaydedilir |
| Çok uzun video (60dk+) | `--whisper-model tiny` öner veya parçalara böl |
| Türkçe altyazı yok | `--lang en` dene, Whisper ile dil otomatik algılanır |
