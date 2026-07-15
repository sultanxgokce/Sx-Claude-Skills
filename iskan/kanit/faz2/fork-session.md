# Probe (d) — `--fork-session` davranışı

**Komut:** `claude -p "Sana verdiğim kelimeyi tekrar et." --resume <orijinal-id> --fork-session --output-format json`
**Orijinal-id:** `abaeb253-c30b-4c36-9ecc-6ca7863e8b3b` (probe (c)'nin rezerve-ettiği, "mor fil" içeren seans).
**Ortam:** aynı test-cwd, canlı aile-oturumlarına dokunulmadı, 2026-07-15.

**Çıktı:**
```
orijinal_id:  abaeb253-c30b-4c36-9ecc-6ca7863e8b3b
fork_yeni_id: 71c58081-47f4-4f36-ae4c-0da8800c42cf   (FARKLI — yeni-id üretildi)
result:       "mor fil"                               (içerik-bağlamı KORUNDU)
```

**Transkript-dosya-kanıtı (satır-sayımı, İ3-uyumlu — içerik bu dosyaya kopyalanmadı):**
```
abaeb253-....jsonl   → 13 satır (orijinal, fork ÖNCESİ ile AYNI — fork sonrası büyümedi)
71c58081-....jsonl   → 17 satır (yeni-dosya, orijinalin+fork-turunun kopyası)
```

**Durum: yeşil** — `--fork-session`, plan K3 madde-2(c)'nin beklediği gibi davranıyor: konuşma-bağlamını
(mor fil) yeni bir session-id'ye KOPYALAR, orijinal transkript dosyasına geri-dönüşsüz yazım YAPMAZ
(orijinal dosya satır-sayısı fork-öncesi/sonrası birebir aynı — 13→13). Bu, SUSPECT-mismatch dalının
güvenlik-temelini doğrular: şüpheli-eşleşmede fork kullanmak orijinal transkripti bozmadan devam etmeyi
sağlıyor.
