# Probe (c) — `--session-id <uuid>` rezervasyon

**Komut:** `claude -p "Sana 'mor fil' kelimesini veriyorum, sadece 'tamam' yaz." --session-id <rezerve-uuid> --output-format json`
**Rezerve-edilen-uuid (önceden `uuid4()` ile üretildi, İSKÂN registry-yazımını simüle eder):**
`abaeb253-c30b-4c36-9ecc-6ca7863e8b3b`
**Ortam:** aynı test-cwd, canlı aile-oturumlarına dokunulmadı, 2026-07-15.

**Çıktı:**
```
requested_session_id: abaeb253-c30b-4c36-9ecc-6ca7863e8b3b
returned_session_id:  abaeb253-c30b-4c36-9ecc-6ca7863e8b3b
match: True
```

**Durum: yeşil** — `--session-id` ile önceden-belirlenen bir uuid'i CLI'nin kendi ürettiği rastgele-id
yerine kullanmaya zorlamak çalışıyor; birebir eşleşiyor. Bu, K3 madde-1'in dayandığı temel-primitif:
İSKÂN bir üye-seansını `claude --session-id <registry-uuid'i>` ile açtığında, o seansın transkript-dosyası
GERÇEKTEN o uuid'le disk'e yazılıyor (kanıt: `~/.claude/projects/<cwd-slug>/abaeb253-....jsonl` diskte
oluştu, 13 satır). Rezervasyon = tahmin değil, kayıt.
