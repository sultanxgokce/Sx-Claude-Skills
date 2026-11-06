---
name: canli-dinle
type: tool
version: 0.1.0
description: "Canlı yayını tek komutla dinler: adresi alır, 30 sn parçalara böler (5 sn örtüşme), Türkçe yazıya döker (Groq whisper-large-v3-turbo ya da yerel whisper.cpp small-q5) ve istenirse 10 dakikalık pencerelerde özet çıkarır. Metin ve özet kutuda dosyada kalır. DRM'li yayında durur, tarayıcı yolu (girişli siteler) bu sürümde YOK."
allowed-tools: Bash
---

# /canli-dinle — canlı yayını yazıya dök, not çıkar

**Niçin (SERDAR layihası `canli-yayin-dinleme-DESIGN.md`, 6 Kas 2026):** canlı yayını izleyemeyen ajan/Sultan için yayının metnini ve özetini kutuda biriktirmek.
Deney 1-2 (HEZARFEN, 6 Kas, TRT Haber HLS) ölçümleri bu sürümün varsayılanlarını belirledi.

## Komut
```bash
bash canli-dinle/scripts/canli-dinle.sh <adres> [--kaynak groq|yerel] [--not] [--sure SN] [--pencere-sn 600] [--cikti DIR] [--kuru]
```
- `adres`: streamlink'in anladığı her adres (YouTube/Twitch/Kick… ya da `hls://https://…/master.m3u8`); streamlink yoksa yt-dlp, o da yoksa ffmpeg doğrudan.
- `--kaynak groq` (varsayılan): `GROQ_API_KEY` süreç ortamından ya da `~/.config/cortex-access.env`'den okunur; **hiçbir yere yazılmaz/basılmaz**. Anahtar yoksa rc 3.
- `--kaynak yerel`: `WHISPER_CLI` + `WHISPER_MODEL` (small-q5, RTF ≈ 0,25). Anahtar gerekmez, özet (`--not`) yine Groq ister.
- `--not`: her `--pencere-sn` (600) saniyelik pencere için Groq LLM ile özet (`ozet-NNN.md`, toplu `ozet.md`; model `CANLI_DINLE_OZET_MODELI`, varsayılan `openai/gpt-oss-120b`). Özet alınamazsa döküm sürer.
- Çıktı: `<cikti>/<tarih-saat>/metin.txt` + `parca-NNNNN.wav`. Dış yükleme yok.
- `CANLI_DINLE_KUR=1`: streamlink yoksa kullanıcı venv'ine pip ile kurar.

## Nasıl çalışır
1. **Yakala** → `streamlink --stdout | ffmpeg` (ya da yt-dlp / ffmpeg doğrudan) → 16 kHz mono WAV, `--parca-sn` (30).
2. **Örtüşme:** her parçaya önceki parçanın son 5 sn'si eklenir; kelime zamanı mutlak saniyeye çevrilir.
3. **Sahiplik süzgeci:** her sözcük, zamanı örtüşmenin ortasından bölünen TEK parçaya aittir → ne çift ne eksik sözcük (sınavda kanıtlı).
4. **Dök:** Groq `verbose_json` kelime zaman damgası (yerelde segment zamanı).

## Ölçülmüş sınırlar (6 Kas 2026)
- Groq: parça başına istek ≈ 0,4 sn (gecikme ≈ 30 sn parça + 0,4 sn), 10 dk ≈ 0,0067 $, saatlik 7200 ses-sn sınırı (429'da 3 kez yeniden dener).
- whisper.cpp turbo-q5 bu sunucuda RTF 0,97 (canlıya yetmez), small-q5 RTF 0,25. medium-q5 metni kesiyor — kullanma.
- **YouTube bu sunucudan bot engeline takılır** ("Sign in to confirm you're not a bot"); çerezle aşılmaz. Herkese açık HLS (haber kanalları) çalışır.
- **Bu sunucudaki static ffmpeg MPEG-TS girdisinde çöker** (core dump); fMP4/HLS-fMP4, WAV ve streamlink'in kendi ayıklaması çalışır. Doğrudan adres yolunda çökerse streamlink kullan.
- Groq, varsayılan `Python-urllib` kimliğini 403 ile reddeder; araç kendi User-Agent'ını gönderir.
- DRM'li yayın (Udemy, Vimeo OTT): durulur, aşılmaz. Toplantı botu / girişli site: bu sürümde yok (F2).

## Sınav
`bash canli-dinle/scripts/canli-dinle.test.sh` — sahte fMP4 HLS yayını + sahte Groq/whisper; 11 kapı. Mutant: `MUTANT=kirpma|ortu|arac-sirasi` (üçü de kırmızı verir).
