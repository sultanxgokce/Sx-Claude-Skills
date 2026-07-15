# Probe (b) — `--resume <id>` gerçek-devam

**Komut:** `claude -p "Bir önceki mesajımda sana verdiğim sayıya 10 ekle, sadece sonucu yaz." --resume <id> --output-format json`
**Girdi-id:** `9a57894a-3878-4720-8586-c68a4ee1885e` (probe (a)'nın ürettiği session, ilk-tur cevabı "2" idi).
**Ortam:** aynı test-cwd, kendi test-uuid'i, canlı aile-oturumlarına dokunulmadı, 2026-07-15.

**Çıktı:**
```
session_id: "9a57894a-3878-4720-8586-c68a4ee1885e"   (değişmedi — aynı-id'de devam)
result: "12"                                          (2 + 10 = 12 — önceki-turu GERÇEKTEN hatırladı)
num_turns: 1
```

**Durum: yeşil** — bu **gerçek-resume**, dosya-replay/degraded-replay DEĞİL: model önceki-turdaki "2"
değerini konuşma-bağlamından okuyup 10 ekledi. session_id resume sonrası da aynı kaldı (yeni-id
üretilmedi — `--fork-session` verilmediği için beklenen davranış, probe (d) ile tezat).

**Not (plan §K3 madde-2 "mode korunmaz" uyarısı):** bu turda `--permission-mode` verilmedi; İSKÂN'ın
gerçek seans-getir yolunda her resume-çağrısı mode'u yeniden-vermeli (registry'den okunmalı) — bu probe
yalnız id/içerik-devamlılığını test etti, mode-persistence'ı DEĞİL (plan zaten "korunmaz" diyor, bu probe
onu çürütmeye çalışmadı).
