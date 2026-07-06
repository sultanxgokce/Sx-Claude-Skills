---
name: ajan-gorev
description: Tek üyeye (ya da tüm-ekibe) hedefli görev ver — ekip-brief.md'ye görev-bloğu yaz + o üyeye tmux-ping. YALNIZ Sultan-yetkili (komuta).
disable-model-invocation: true
allowed-tools: Bash, Edit, Read, AskUserQuestion
---

# /ajan-gorev — Sultan → tek üyeye görev

**Kim çağırır:** YALNIZ Sultan (USER-ONLY · komuta-yetkisi Sultan'da; üyeler bu skill'i çağırmaz — sistemi işletirler, komuta etmezler).
**Ne yapar:** Hedef üyeye ortak `ekip-brief.md`'ye `## GÖREV` bloğu düşürür ve o üyenin tmux-oturumuna "sana görev var — oku + uygula" ping'i atar. Üye görevi kendine-adresli olarak ekip-brief.md'de okur.

## Adımlar

1. **Hedef ajan:** `$ARGUMENTS`'ta bir üye-id verilmişse onu kullan, soruyu ATLA. Verilmemişse:
   - Registry'yi oku (`_agents/handoff/ekip-registry.yaml`) → üye-id + rol listesini çıkar.
   - **AskUserQuestion** sor: "Görev hangi üyeye?" — seçenekleri registry'den DİNAMİK üret (her üye = `<ID> (<rol>)`), + `Tüm-ekip`. (Hardcoded liste TUTMA.)
2. **Görev metni:** `$ARGUMENTS`'ın kalanı doluysa kullan; boşsa Sultan'a "Görev metni?" diye sor. Kısa-öz + net-çıktı iste (sır-değer ASLA yazma).
3. **Yetki-doğrulama:** hedef üyenin `mod`'unu registry'den bak. Görev üyenin moduyla çelişiyorsa (ör. `salt-okur` üyeye kod-yaz görevi) Sultan'ı uyar — yine de o karar verir.
4. **Zaman damgası:** `date -Is` (`<ts>`).
5. **Kanala append:** `_agents/handoff/ekip-brief.md` SONUNA:
   ```
   ## GÖREV · <ts> · → <AJAN> · (Sultan-yetkili)

   <görev-metni>
   ```
6. **Ping:** çalıştır →
   ```bash
   bash scripts/ekip-notify.sh <ajan|all> "ekip-brief'te sana görev var — _agents/handoff/ekip-brief.md son GÖREV girdisini oku + uygula"
   ```
   (`<ajan>` = seçilen üye-id ya da `all`.)
7. **Takip:** script `ozet:`ini Sultan'a raporla. "Takibini ister misin?" diye sor — takip Sultan'ın ritmine bağlı (senkron değil).

## Sınırlar
- Komuta-yetkisi Sultan'da; üye-Claude'lar bu skill'i çağırmaz.
- Yalnız `ekip-brief.md`'ye yazar (kardeş inbox'a değil — tek-yazar korunur).
- Görev-ping'i tetiktir; üye ne zaman uygular ASENKRON.
