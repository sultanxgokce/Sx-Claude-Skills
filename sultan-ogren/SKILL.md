---
name: sultan-ogren
version: 0.1.0
description: Sultan'ın bir dil/biçim tercihini ya da düzeltmesini Sultan-üslûbu modeline HIZLI kaydeder (aday-kayıt). "/sultan-ogren <gözlem>" ya da "Sultan üslûbuna kaydet / şunu öğren / bunu not al Sultan-tercihi olarak" dendiğinde çağrılır. Garantili manuel yakalama hattı (recall-hook'un elle karşılığı). Kayıt tek-yazar helper (ogren.sh) ile /config/.claude/sultan-uslubu.md'ye eklenir.
disable-model-invocation: true
allowed-tools: Bash
---

# /sultan-ogren — Sultan-tercihi hızlı-yakala (manuel-hat)

**Kim çağırır:** Sultan ya da ajan (Sultan bir tercih/düzeltme belirtince). Açık tetik (`disable-model-invocation`).
**Ne yapar:** Gözlemi **aday-kayıt** olarak `/config/.claude/sultan-uslubu.md` store'una ekler (tek-yazar+flock).
Pekiştirme/onaylı-terfi = `/sultanca` PEKİŞTİR yüzü (Sultan onaylayınca).

## Akış
1. Gözlemi **eksene** ata: `dil` (jargon/ifade) · `cikti-tasarim` (yerleşim/gruplama) · `cikti-format` (görünüm/vurgu) · `ifade` (ton/hitap).
2. **Uygulanabilir tek-cümle kural** çıkar (Sultan-verbatim'i kanıt olarak sakla — iddia≠kanıt, uydurma yasak).
3. Ekle:
```bash
bash /config/.claude/skills/sultanca/ogren.sh \
  --eksen <eksen> \
  --kural "<tek-cümle kural>" \
  --kanit "Sultan $(date +%Y-%m-%d): \"<verbatim>\"" \
  --ornek "❌ <önce> → ✅ <sonra>"   # opsiyonel
```
4. Onayla: "✔ Sultan-üslûbuna aday-kayıt olarak eklendi (<id>). Bir dahaki Sultan-yüzlü çıktıda dikkate alacağım; onaylarsan kalıcılaştırırım."

## Değişmezler
- Yeni-kayıt DAİMA `aday` (tentatif); onaylı-terfi Sultan-onayı/≥2-tekrar ile (`/sultanca`).
- Kanıt-çapası zorunlu (Sultan-sözü olmadan kural ekleme).
- Firewall: ortam/mod → CLAUDE.md · karar-kalıbı → F-sultan-profili · süreç → auto-memory. Burası yalnız "Sultan'a nasıl konuşulur".
- Bu = **Sultan-YÜZLÜ** üslûp; ajan-yüzlü iletişime uygulanmaz (§4 scoping).

> **Otomatik yakalama (recall-hook):** opsiyonel; `/katip` recall-hook ile AYNI hedef-oturum (session-scoping)
> kararına bağlı — Sultan-direkt oturumlarda mı yoksa aile-ajan oturumlarında da mı koşmalı? O karar netleşince
> `sultanca-capture.sh` (katip-emsali, INERT-default) eklenir. Şimdilik manuel-hat garantili yoldur.
