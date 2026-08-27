# A/B protokol referansı (dağıtım-görünümü)

> KANON Nexus repo'sundadır (spec `_agents/spec/federe-ekip-os-standardi-GEREKLILIKLER.md` +
> `_agents/federe/DEFTER-SEMA.md`). İzole-birimler Nexus'u göremediği için bu dosya dondurulmuş
> özeti taşır; çelişkide Nexus-kanon kazanır, bu paket semver'le tazelenir.

## A · Kontrol-düzlemi (Sultan-onaylı, 2026-07-20)
- **A1 Tetikleme:** merkez (s01/SERDAR) uzak-birime görev/uyandırma sinyali bırakır; birim POLL eder
  (`federe.sh dinle`), teslim-alır (`alindi`), kapatır (`tamam`). Push/ssh yok.
- **A2 Standart akış-görünümü:** her birim aynı-şemalı fleet-meta satırı yayınlar (aşağıda); zengin
  iş-notu birimin kendi repo'sunda kalır.
- **A3 Nabız:** "yaşıyorum + şunu yapıyorum" (`federe.sh nabiz`); tek panelde toplanır; defter↔nabız
  çelişirse nabız (yer-gerçeği) kazanır.
- **A4 Auth:** kimliksiz-tetik yasak; kimlik sunucu-türevli (token→cell); fail-closed 401/403.

## B · Ajan-davranış (Sultan-onaylı)
- **B1 Not-tutma:** append-only + git-tracked + Sultan-dili iş-defteri ve karar-kaydı; her satır
  kanıt-ref'li (PR/commit/çıktı).
- **B2 Haberleşme:** ajan↔ajan + ajan↔Sultan tek-şema; izole-arası YALNIZ META (başlık≤120 ·
  not≤500 · sır-desen yasak); insan-onay alanına ajan yazamaz.
- **B3 Kimlik + hafıza-vatandaşlığı:** oturum-başı kimlik-oku (AGENT.md/oryantasyon), iş-sonu
  kayıt-yaz (defter + capture). Hiçbir ajan hafızasız/kayıtsız çalışmaz.

## Fleet-defter dondurulmuş şeması (A2/D1 — kanon: Nexus DEFTER-SEMA.md)
Dosya: Nexus `_agents/federe/defter/<cell_id>.yaml` — birimin fleet'e yayınladığı TEK şey.

| alan | zorunlu | kural |
|---|---|---|
| `cell_id` | ✓ | `^s\d{2}$`, dosya-adı-stem ile eş, registry'de kayıtlı |
| `birim_kodu` | ✓ | `^\d{2}$`, `cell_id == "s"+birim_kodu` |
| `durum` | ✓ | enum: `aktif · mesgul · bekliyor · bakim · yuva` |
| `guncelleme` | ✓ | tırnaklı ISO `"YYYY-MM-DD"` |
| `ozet` | ✓ | tek-satır ≤200, jargonsuz, sır-desen yok |
| `mudur` / `son_kart` / `acik_tetik` | — | persona-adı / `k####` / tamsayı ≥0 |

**Yapısal kilit:** TÜMÜ-SKALAR — hiçbir alan liste/dict olamaz (içerik-gömme yapısal-imkânsız).
Bekçi: Nexus `scripts/federe-defter-lint.sh` (CI `federe.yml`). İzole-birim bu satırı doğrudan
yazamıyorsa (Nexus'a erişimi yok) güncellemeyi meta olarak merkeze iletir: `federe.sh gonder s01
"defter: durum=mesgul, özet=..."` — merkez işler.

## Tetik-API meta-tavanları (sunucu da zorlar)
başlık ≤120 · not/sonuç-notu ≤500 · kart-ref `[A-Za-z0-9._-]{1,40}` · gövde ≤4KB · hız-sınırı 429 ·
sır-desen → 400 (değer geri-basılmaz) · durum-makinesi ileri-yönlü (geri-sarım 409) · hub-and-spoke
(kaynak=s01 ∨ hedef=s01).
