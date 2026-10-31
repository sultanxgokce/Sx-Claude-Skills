<!-- kaynak: Sx duzen/cekirdek · Nexus kopyası bu dosyayı okur -->
# ANA-HEDEF ŞABLONU — her kutunun git-durable hedef-çapası (MABEYN B1 · 2026-08-03)

> **Niçin:** "Bu ajanın önünde net hedef var mı?" sorusunu BUGÜN hiçbir bekçi ölçemiyor —
> çapa bir Cortex hafıza-topic'inde yaşıyordu (grep'lenemez, CI-denetlenemez, kutu-dışından
> okunamaz). MİHENK'in hiç zamanlanmış işi olmadığı bir layihanın YAN-BULGUSU olarak, tesadüfen
> keşfedildi (L41). Bu şablon çapayı DİSKE indirir; `ana-hedef-lint.sh` tazeliğini ölçer;
> plan-bekcisi (MABEYN B2) filo-genelinde tarar; MÜFETTİŞ plansıza plan YAPTIRIR (yazmaz — A06).
>
> **Kural:** her kutuda `_agents/ANA-HEDEF.md` (repo-kökü `_agents/` yoksa CLAUDE.md'nin yanına).
> Tazelik MÜDÜR sorumluluğudur: damga ≤7 gün. İçerik-hakemliği kutunun kendi işidir (İ1) —
> bekçi yalnız VARLIK + TAZELİK + satır-sayısı ölçer, içerik OKUMAZ.

## BİÇİM (makine-okur üç blok — başlık satırları AYNEN)

```markdown
# ANA-HEDEF — <kutu/birim adı>
guncelleme: 2026-08-03 · sahibi: <MÜDÜR-persona>

HEDEF: <tek cümle — bu kutu şu an neden var, neye hizmet ediyor>

SIRADAKİ (3-5 iş, öncelik sırasıyla; Ş0/Ş1 sınıfı — durmadan yürünebilir):
1. <iş — tek satır, kanıt/çıktı belli>
2. <iş>
3. <iş>

PARK (isteğe bağlı — bilinçli bekletilenler, gerekçeli):
- <iş — neden park>
```

## KURALLAR
- `guncelleme:` ISO tarih (YYYY-AA-GG) — lint bunu parse eder; >7 gün = BAYAT.
- `SIRADAKİ` en az 1, en çok 5 numaralı satır — boş kuyruk "plan yok" demektir; kuyruk
  boşaldıysa MÜDÜR ya doldurur ya "kuyruk-boş" tetiği atar (durma-standardı Ş0/Ş1 bölümü).
- `HEDEF:` üst-hedefe bağ kurar (parent-zincir): kart/layiha şemasındaki opsiyonel `hedef:`
  alanı bu cümleye/koduna işaret eder — başıboş iş kalmaz (paperclip deseni).
- Sır-değeri · müşteri-verisi · izole-oda iç-detayı YAZILMAZ (dosya filo-bekçisince stat/head
  ile taranır — İ1 gereği yalnız-META kalmalı).
- Doğrulama: `bash scripts/ana-hedef-lint.sh [dosya]` → 0=taze · 1=bayat/eksik · 2=yok/parse-fail.
