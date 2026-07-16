---
name: credential-yasam-dongusu
type: agent
version: 0.1.0
description: >
  Kimlik-katmanı yaşam-döngüsü (Usta/S3 bileşik): Arçelik-kaynak-evreninin Okta-künye + broker-token +
  Fernet + VPS-custody katmanını insan-tetikli, kanıt-üreten, fail-closed akışlarla yönetir —
  tazele (broker-yolu token-otonomisi) · tasi (DR-göç, T1-runbook) · teshis (salt-okur sağlık-probe).
  vault-cek + sunucu-kur + erisim KOMPOZİSYONU. Sır=pointer-only; değer ASLA basılmaz.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [credential, vault, broker, okta, dr, mmex, bilesik]
status: v0.1-usta
---

# credential-yasam-dongusu — kimlik-katmanı yaşam-döngüsü (Usta · bileşik iş-sistemi)

**NE-DİR:** `vault-cek` (sır-çözüm seam'i) + `sunucu-kur` (VPS-provizyon standardı) + `erisim`
(erişim-zinciri dispatcher'ı) Kalfa-skill'lerini besteleyerek Arçelik-kaynak-evreninin kimlik-katmanını
(Okta-künye · broker-token · Fernet · VPS-custody) **yaşam-döngüsü-boyu** yöneten çalışma-prensibi kurar:
her akış insan-tetikli, her koşu kanıt-üreten, her belirsizlik fail-closed.

> **Doğum-kaynağı:** SİNAN-spec **v1.1** (2026-07-16) — kanonik kopya MMEx-repo'da; hub-kopyası
> `evraklar/Sultan/1-Calisma/broker-deploy/SINAN-usta-credential-SPEC.md` (çelişkide repo kazanır).
> Davranış-sözleşmesi spec'ten BAĞLAYICI; arayüz-adları Serdar-takdiri (spec §4).

## Uygulama-durumu (dürüstlük-beyanı)
**v0.1 = İSKELET (scaffold).** `doctor` GERÇEK (aşağıda); `tazele/tasi/teshis` akış-scriptleri
T1/T8 tatbikat-dalgasında yazılır — o güne dek çağrılırlarsa **dürüst-fail RC=1** ("henüz-uygulanmadı")
dönerler, hiçbir dış-istek yapmazlar (fail-closed). "Olmalı/muhtemelen-çalışır" dili bu skill'de YASAK.

## Üç bestelenen-akış (davranış-sözleşmesi — spec §2 birebir)

### A · `tazele <kaynak>` — kanıtlı token-otonomisi
Kaynak-token'ı süresi-dolunca/bozulunca **YALNIZ broker-refresh-yolu** üzerinden tazele (TOTP-mint dahil);
başarı = davranış-duvarı-teyidi (artifact-200 + valid:true).
- ⛔ **YASAK-ÇİZGİ:** ad-hoc/doğrudan-Okta-login AKIŞTA YOK — tek-login-kapısı broker; broker-dışı her-yol
  hard-fail. Cooldown/ban-sinyali → DUR + eskalasyon (asla retry-fırtınası; MMEx heal-merdiveni emsal).
- Kanıt-bağı: her-koşu → telemetri-satırı; canlı-varyant T8-tescil-kartıyla mühürlenir (K3-sonrası;
  ilk-ay-haftalık → çeyreklik + her-parola-rotasyonunda).

### B · `tasi` — DR-göç (T1-runbook'un skill-leşmesi)
Broker-beynini yeni-VPS'e taşı: `sunucu-kur` (masraf=Sultan-gate) → R2-yedekten env-restore →
**Fernet-AYNEN** (sha256-hash-teyit; rotate=kayıt-kaybı → akış-İÇİNDE-imkansız) → paralel-tünel →
davranış-duvarı (healthz-200 · bearersiz-401 · boş-cache-503 · bilinmeyen-404 · Okta-egress-0) →
canonical-repoint (ayrı-onay).
- ⛔ **YASAK-ÇİZGİ:** `/data`-cache-restore YOK (boş-cache-503 = login-olmadı-kanıtı) · eski-VPS'e
  dokunuş=0 · IP-re-allowlist = MANUEL-Arçelik-adımı (T7-iletişim-zinciri; skill bunu ADIM-olarak
  listeler, ASLA otomatikleştirmez).
- Kanıt-bağı: T1-V-A/V-B tescil-kartları; `--dry-run` default (gerçek-koşu Sultan-gate).

### C · `teshis [<kaynak>]` — sağlık-probe + kök-neden-ayrımı (SALT-OKUR)
Kimlik-katmanı uçtan-uca-teşhis: vault-çözülüyor-mu (RC-only, değersiz) · broker-healthz/bearer-duvarı ·
token-yaş/cooldown-durumu · hata-taksonomisi: **403-serisi=ban-şüphesi ≠ 401=token-bayat ≠ 503=cache-boş**.
- ⛔ **YASAK-ÇİZGİ:** teşhis HİÇBİR-ŞEYİ tetiklemez (izleyen-göz doktrini); çıktı = rapor + öneri.
- Vault-probe **RC-only + `cortex-access.env → source` deseniyle KODLANIR** (s0131 ANSI-tuzağı:
  `$(get)`-capture yasak — desen skill-içinde kodlanır, kullanıcı-diskresyonuna bırakılmaz). [şerh-3]

## Değişmezler (üçü-birden, akış-bağımsız — spec §3)
1. **Sır=pointer-only:** değer chat/log/dosyaya ASLA; tüketim `cortex-access.env → source` deseniyle.
2. **Fail-closed her-katmanda:** çözülemeyen-sır=DUR · emin-değilsen-dış-istek-YAPMA · kısmî-durum=
   dürüst-rapor (recovered:false sınıfı; false-green YASAK).
3. **İnsan-tetik + kanıt:** hiçbir-akış cron'la-kendiliğinden koşmaz (tek-KOMUT-doktrini); her-koşu
   telemetri+RC; tescil-mühürsüz-akış "kanıtlı" SAYILMAZ.

## Arayüz + RC-haritası (spec §4 + v1.1 şerhleri)
```
bash scripts/cyd.sh tazele <kaynak>     # A-akışı (v0.1: dürüst-fail RC=1 — uygulanmadı)
bash scripts/cyd.sh tasi [--dry-run]    # B-akışı (v0.1: dürüst-fail RC=1 — uygulanmadı; --dry-run default olacak)
bash scripts/cyd.sh teshis [<kaynak>]   # C-akışı (v0.1: dürüst-fail RC=1 — uygulanmadı)
bash scripts/cyd.sh doctor              # kendi-sağlığı: requires-üçlüsü + force-bayrak-bekçisi (GERÇEK)
```
**RC:** `0`=başarı+kanıt · `1`=dürüst-fail · `3`=gate-bekliyor · `4`=ön-koşul-eksik.
⚠️ **RC-4 = "ön-koşul-eksik" (İSKÂN'ın GO-marker-reddi-4'üyle KARIŞTIRMA — skill-lokal tanım).** [şerh-1]
⛔ **force YOK-BAYRAĞI:** bu skill'in hiçbir akışında force-benzeri bayrak var-OLAMAZ; `doctor`
force-benzeri-bayrak tespit-ederse **hard-fail** (mekanik-bekçi, yalnız-doküman-değil). [şerh-2]

## Besteleme
`ahi.manifest.yaml` → `requires: [vault-cek, sunucu-kur, erisim]` (üçü de Kalfa-manifestli).
Bileşenler `.claude/skills/<kardeş>` yolundan çözülür (vendoring-YOK).

## Pîr-terfi-yolu (şimdiden-ölçülür — spec §5)
Hammadde: (a) tatbikat-telemetrisi (T1/T5/T8-MUHUR'lar), (b) izleyen-göz-v3 öneri→uygulandı→etki-zinciri,
(c) akış-başına koşu-sayısı + fail-oranı. `ahi promote` ancak: T8-kadansı ≥1-çeyrek-temiz + T1-V-B-MUHUR +
sıfır-sır-sızıntı-kaydı → Sultan-töreni.

## Kademe
Usta (S3 · bileşik · born-at-tier, Sultan-kararı). Doğrula: `ahi check credential-yasam-dongusu` ·
Kanon: `ahi doctrine`.
