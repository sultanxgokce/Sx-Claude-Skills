---
name: sultanca
version: 0.1.0
description: Sultan'a NASIL konuşulacağını (dil) ve Sultan-yüzlü çıktının NASIL biçimleneceğini (format/tasarım) yöneten yaşayan-model. ÜÇ yüz — UYGULA (Sultan'a bir şey yazmadan önce üslûbu yükle+uygula), ÖĞREN (Sultan bir tercih/dil-düzeltmesi söyleyince kaydet), SORGU ("Sultan bunu nasıl ister?"). "Sultan'a nasıl söylemeliyim / Sultan bunu nasıl ister / Sultan üslûbu / sultanca / bunu Sultan-diline çevir" ya da Sultan bir dil/biçim tercihi belirtince çağrılır. Tek-kaynak store'u (/config/.claude/sultan-uslubu.md) okur; sürekli-öğrenir.
allowed-tools: Bash, Read, Edit
---

# /sultanca — Sultan Üslûbu (yaşayan dil & çıktı-tercih modeli)

**Ne:** Sultan'a **nasıl konuşulur** + Sultan-yüzlü çıktı **nasıl biçimlenir** — sürekli-öğrenen tek-kaynak.
Sultan-direktifi: *"tercihlerimi ve Sultan-dilini sürekli anla, AI-skill yap, sürekli geliştir."*

**Store (tek-kaynak):** `/config/.claude/sultan-uslubu.md` — kişiye-özel-GLOBAL (her container aynı modeli okur).
**Firewall:** ortam/mod → `CLAUDE.md` · karar-kalıbı → F-sultan-profili (Cortex) · süreç-feedback → auto-memory. Burası
YALNIZ "Sultan'a nasıl SÖYLENSİN/GÖSTERİLSİN".

**Kapsam (§4 scoping — kritik):** üslûbu YALNIZ **Sultan-YÜZLÜ** çıktıya uygulanır (sultan_ozeti · durum-özeti ·
defter-içerik · Sultan'a-gösterilecek mandate-sonucu). **Ajan-yüzlü iletişim** (aile-brief, --done özetleri,
kardeş-kanalları) verimli-ajan-dili kalır — her-şeyi Sultan-diline çevirmek israftır. Hedef Sultan → uygula; hedef ajan → uygulama.

---

## YÜZ 1 · UYGULA (Sultan'a bir şey yazmadan ÖNCE)
1. Store'u oku: `Read /config/.claude/sultan-uslubu.md` (ya da `grep -A4 '🟢 ONAYLI' -A200`).
2. **🟢 ONAYLI** kuralları uygula (zorunlu); **🟡 ADAY** kuralları dikkatli-uygula (tentatif, aşırı-genelleme yapma).
3. Jargon→Sultan-dili sözlüğünü metne geçir. 3-sütun kontrol: ① her kelimeyi anlar mı ② "bana ne?" cevabı var mı ③ gated ise neyi onaylayacağı açık mı.
4. Çıktı-tercihleri (düz-liste·inline-etiket·biten-soluk·id/hash-gizle·"sen"-hitabı) uygula.

## YÜZ 2 · ÖĞREN (Sultan bir tercih/dil-düzeltmesi söyleyince — `/sultan-ogren`)
Sinyaller (recall-biased — kaçırma>gürültü): **DÜZELTME** ("hâlâ ajan-dili", "bunu anlamadım") · **TERCİH** ("sade sever", "kısa olsun") · **ONAY** ("süper", "çok daha iyi", "artık anlıyorum").

Aday-kayıt ekle (helper tek-yazar+flock; DAİMA 'aday'):
```bash
bash "${CLAUDE_SKILL_DIR:-/config/.claude/skills/sultanca}/ogren.sh" \
  --eksen dil \
  --kural "<uygulanabilir tek-cümle>" \
  --kanit "Sultan <tarih>: \"<verbatim>\"" \
  --ornek "❌ <önce> → ✅ <sonra>"   # opsiyonel
```
- `--eksen`: `dil` (jargon/ifade) · `cikti-tasarim` (yerleşim/gruplama) · `cikti-format` (görünüm/vurgu) · `ifade` (ton/hitap).
- **Dedup:** eklemeden önce store'da benzer-kural var mı bak → varsa PEKİŞTİR (aşağı), yoksa yeni-aday.
- **Kanıt-çapası:** her kural Sultan-verbatim'ine çapalı (iddia≠kanıt). Uydurma-kural YASAK.

## YÜZ 3 · SORGU ("Sultan bunu nasıl ister?")
Store'u oku → ilgili eksendeki onaylı+aday kuralları + sözlüğü uygula, öneriyi ver. Kural yoksa dürüst söyle ("henüz kayıtlı-tercih yok; şöyle öneririm + istersen /sultan-ogren ile kaydedeyim").

---

## PEKİŞTİR / REVİZE (kritik — "geliştir", salt-append değil)
- Sultan bir çıktıyı **ONAYLAR** ("çok daha iyi") → onu-üreten kuralları `Edit` ile 🟡 ADAY'dan 🟢 ONAYLI'ya taşı (`guven: onaylı` + onay-kanıtı ekle). ≥2-tekrar da terfi ettirir.
- Sultan **DÜZELTİR** / çelişir → çelişen-kuralı `Edit` ile revize et ya da düşür (eski-kuralı körü-körüne koruma). Böylece profil DERİNLEŞİR.
- **Yetki-sınırı:** kurallar SENİN-davranışını ayarlar (insan-onay-alanı DEĞİL) → düşük-risk; yine de aday/onaylı-kademe + Sultan-kanıt-çapası drift'i önler. Onay/`sultan_response` alanına ASLA yazılmaz.

## Kayıt-şeması (gömülü — progressive-disclosure)
`### su<seq3> · <eksen> · <guven>` + `- **kural:**` · `- **kanıt:**` (Sultan-verbatim+tarih) · `- **ornek:**` (opsiyonel) · `- **updated:**`.
`guven`: `aday` (1-gözlem) · `onaylı` (Sultan-explicit VEYA ≥2-tekrar VEYA onay-pekiştirmesi). Yeni-kayıt DAİMA aday, dosya-SONUNA (ogren.sh).

## Değişmezler
- Store tek-kaynak; frozen-kopya üretme (§A /katip'te, /durum-sözlüğü → hepsi buraya REFERANS verir).
- §A'yı SUPERSEDE etme — bu onu SARAR (dil-ekseninin tohumu).
- Sultan-verbatim olmadan kural uydurma; sır-değer/kod-adı yeni-metinlerde de temiz.
