# Probe (a) — headless session-id round-trip

**Komut:** `claude -p "1+1'i hesapla, sadece sayıyı yaz." --output-format json`
**Ortam:** bulut-masaüstü cloudtop-code container, motor-1 (MOTORSERDAR) oturumu, kendi test-uuid'i,
`/tmp/.../scratchpad/iskan-faz2` cwd'sinde (canlı aile-oturumlarına dokunulmadı), 2026-07-15.

**Çıktı (özet-JSON alanları):**
```
result: "...2"
stop_reason: "end_turn"
session_id: "9a57894a-3878-4720-8586-c68a4ee1885e"
```

**Durum: yeşil** — `--output-format json` çıktısının `.session_id` alanı dolu ve geçerli-uuid; headless
tek-atış çağrı kendi session-id'sini üretip döndürüyor. Round-trip (aç→id-yakala) çalışıyor.
Transkript-dosyası doğrulandı: `~/.claude/projects/<cwd-slug>/9a57894a-....jsonl` (13 satır) — İ3 kuralına
uygun, İSKÂN yalnız dosya-adı/id konuşuyor, transkript-içeriği bu dosyaya kopyalanmadı.
