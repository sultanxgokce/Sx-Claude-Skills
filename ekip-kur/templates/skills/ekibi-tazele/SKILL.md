---
name: ekibi-tazele
description: Ekipteki hantallığı/eksikliği TEK-komutla tespit+düzelt — bayat-registry auto-reconcile, context-ağır üye tespiti (compact öner, onay-kapılı), kapıda-bekleyen üyeyi yüzeye çıkar, ölü/eksik oturumu bayrakla. Sultan "ekibi tazele" dediğinde çağrılır. USER-ONLY, Sultan-dili özet basar.
disable-model-invocation: true
allowed-tools: Bash, Read, AskUserQuestion
---

# /ekibi-tazele — ekip-bakımı tek-komut

**Kim çağırır:** Sultan (ya da yönetici). USER-ONLY — model kendiliğinden çağırmaz.
**Ne yapar:** `/durum` yalnız SALT-OKUR gösterir; bu skill ONUN ÜSTÜNE bakım ekler — bayat-registry'yi
**güvenli-olanı otomatik-düzeltir**, context-ağır üyeyi tespit edip compact **önerir** (onay-kapılı, otomatik-tetiklemez),
kapıda-bekleyen üyeyi yüzeye çıkarır, ölü/eksik oturumu bayraklar. Tek çağrıda dört bakım-maddesini sırayla yürütür.

## Adımlar

1. **Motoru çalıştır (tek komut, sırayla A→B→C→D):**
   ```bash
   bash scripts/ekip-tazele.sh
   ```
   Registry/scriptler yoksa (`scripts/ekip-tazele.sh` bulunamadı) → bu proje ekip-kur ile kurulmamış demektir;
   Sultan'a söyle, `/ekip-kur` öner. Uydurma-çıktı ÜRETME.

2. **[A] REGİSTRY-RECONCILE — zaten UYGULANDI (güvenli-otomatik):**
   Script'in `FIX` satırları GÜVENLİ değişiklikleri (tmux-casing self-heal, `meta.uye_sayisi` düzeltme,
   boş `meta.yonetici` doldurma) **zaten registry'ye yazdı** — onay gerekmez, sadece Sultan'a ne düzeldiğini
   sade-Türkçe bildir ("BETA'nın oturum-adı değişmişti, otomatik düzelttim"). `FLAG` satırları (ölü-oturum,
   registry-dışı-oturum, duplike-id, geçersiz-yönetici) **insan-kararı gerektirir** — bunları 4. adıma taşı.
   ⚠️ **Önizleme istenirse** (Sultan "önce göster" derse) `bash scripts/ekip-tazele.sh --dry-run` ile tekrar-çalıştır — hiçbir şey yazmaz.

3. **[B] CONTEXT-AĞIR ÜYE — ASLA otomatik-compact'leme (onay-kapılı):**
   `HEAVY` satırları best-effort tahmindir (transcript-eşleme; `UNMAPPED` varsa "bazı oturumlar tespit edilemedi" diye
   dürüstçe söyle, uydurma). Her `HEAVY <MID> pct=N` için Sultan'a **AskUserQuestion** sor:
   *"<MID> context'i ~%N dolu görünüyor (tahmin) — hafızasını temizlemesini (compact) önereyim mi?
   [Evet-ping-at / Hayır / Kendi-halletsin]"*
   - **Evet** → `bash scripts/ekip-notify.sh <MID> "context ağır görünüyor (~%N tahmini) — uygun bir faz-sınırında /compact düşün; scripts/ekip-selfcompact.sh varsa --self ile öz-servis de yapabilirsin"` (varsa `ekip-selfcompact.sh`, yoksa jenerik mesaj).
   - **Hayır/Kendi-halletsin** → hiçbir şey yapma, sadece not düş.
   - Zaten her üyenin kendi `ctx-nudge.sh` PostToolUse-hook'u wire'lıysa büyük ihtimalle üye KENDİSİ zaten
     fark edip Sultan'a soracaktır — bu adım yalnız DIŞARIDAN-erken-uyarı/yedek-katman, tekrar-nudge'lamak zorunlu değil.

4. **[C]+[D] KAPIDA-BEKLEYEN + ÖLÜ/EKSİK OTURUM + kalan-FLAG'lar — yüzeye çıkar, yönlendir:**
   - **Bekleyen (⚠️):** `/durum` skill'indeki JARGON→Sultan-dili sözlüğü ile çevir (busy/idle/vs Sultan'a ham-görünmez).
     Sultan'a "kim ne bekliyor" söyle; istenirse `bash scripts/ekip-notify.sh <MID> "..."` (ya da `/ajan-gorev`) ile
     yönlendirme ping'i at (onay-kapılı — göndermeden önce Sultan'a sor, otomatik gönderme).
   - **Ölü/eksik oturum (💀):** "kapalı, normal olabilir" de (alarm-yapma) AMA eğer registry `FLAG olu-oturum` da bastıysa
     ("otomatik-eşleşme-yok") bunu ayrıca not et — canlı bir oturum farklı isimle açılmış olabilir, Sultan'a sor.
   - **Diğer FLAG'lar** (`registry-disi-oturum`, `duplike-id`, `yonetici-gecersiz`, `belirsiz-eslesme`): ham-satırı
     Sultan'a birebir okutma — ne anlama geldiğini bir cümlede çevir + "elle-bakman gerek" de.

5. **Sultan-dili tek-özet bas** (şablon):
   ```
   🧹 EKİP TAZELENDİ · <saat>

   ✅ OTOMATİK-DÜZELTİLEN (n)
     • <ne düzeldi, sade>

   😮‍💨 CONTEXT-AĞIR (n)          ← boşsa satırı atla
     • <MID> — ~%N dolu (tahmin) → <ne yapıldı: ping-atıldı / atlanmadı>

   ⚠️ KAPIDA BEKLEYEN (n)         ← boşsa satırı atla
     • <MID> — <neyi bekliyor>

   💀 KAPALI/EKSİK OTURUM (n)     ← boşsa satırı atla
     • <MID>

   🔎 ELLE-BAKILMASI GEREKEN (n)  ← boşsa satırı atla
     • <sade açıklama>

   📋 Tek cümle: <n otomatik-düzeldi · n context-ağır · n bekliyor · n kapalı · n elle-bak>.
   ```
   Hepsi 0 ise: "Ekip tertemiz — düzeltilecek/bakılacak bir şey yok. 👍"

## Sınırlar
- **[A] reconcile GÜVENLİ-otomatiktir** (tmux-casing self-heal, sayaç-düzeltme, boş-alan-doldurma) — mevcut
  dolu bir değeri ASLA ezmez, yeni üye ASLA icat etmez.
- **[B]/[C] risk taşıyan hiçbir aksiyon onaysız YAPILMAZ** — compact-tetikleme ve yönlendirme-ping'i her zaman
  Sultan onayı ister (AskUserQuestion). Bu script'in kendisi hiçbir tmux-pane'e otomatik mesaj GÖNDERMEZ.
- **Context-% tahmindir** (best-effort transcript-taraması) — Sultan'a "kesin" diye sunma, "~tahmini" de.
- Ham jargon/dosya-yolu/hash Sultan'a görünmesin — `/durum`'daki sözlüğü uygula.
- Registry/scriptler eksikse uydurma-rapor ÜRETME — dürüstçe "bu proje ekip-kur ile kurulmamış" de.
