# MATRIS — {{feature}}

> Biçim-kanonu: `reference/FORMAT.md` (kolon-şeması, `durum`/`kanıt-türü` enum'ları, dörtlü-denetim).
> `durum` kolonu TÜRETİLMİŞ-VERİ — elle yazılamaz; `core/durum_uret.mjs` kanit/-JSON'lardan rejenere eder.
> Kanıt-JSON'ları bu dosyanın yanındaki `kanit/` dizininde yaşar; kanonik ad-kuralı: `kanit/<M#>.json`
> (kırmızı-kanıt: `kanit/<M#>-kirmizi.json`).
> Emoji-yasağı: `durum` ve kanıt hücrelerinde emoji = lint-FAIL.

| M# | C-ID | kaynak-cümle-verbatim | yuzey | kanıt-türü | doğrulama-komutu(+hash) | etki-alanı | veri-rejimi | durum | kanıt-JSON-ref |
|---|---|---|---|---|---|---|---|---|---|
