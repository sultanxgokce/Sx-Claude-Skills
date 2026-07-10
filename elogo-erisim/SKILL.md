---
name: elogo-erisim
type: agent
version: 1.1.0
description: >
  e-Logo (Logo e-Fatura/e-Arşiv entegratörü) erişimi gereken işleri PANELE GİRMEDEN, saf SOAP WS ile
  yapar: fatura durumu sorgula, kesilmiş e-Arşiv PDF/UBL indir. Kimlik yoksa BİR-KERELİK gizli giriş
  ister (WS kullanıcı+şifre → doğrula → cortex-access.env 600), sonra bir daha sormaz. SALT-OKUR +
  KUYRUK-GÜVENLİ (eski prod B2B senkronunu bozmaz) + sır-hijyenik. (erisim-skill-fabrikasi ürünü.)
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
tags: [elogo, e-fatura, e-arsiv, erisim, platform-access, soap, setup]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# e-Logo Erişim

> e-Fatura/e-Arşiv işlerini Sultan'a tekrar tekrar giriş sordurmadan yap.
> Kanon reçete: `erisim-skill-fabrikasi/recipes/elogo.md`. Omurga: ../cloudflare-erisim/SKILL.md.

## GERÇEK KISIT (dürüstçe söyle)
e-Logo'nun "şifre → API token" akışı YOK — Web Servisi doğrudan **kullanıcı-adı+şifre → `Login` → sessionID**
ile çalışır. Least-privilege = portalda ÖZEL bir "Bağlantı (Web Servis) Kullanıcısı" (alt-kullanıcı) açmak.
⚠️ Login **hesap-kilitlidir** (yanlış deneme sayacı azaltır) → körlemesine şifre deneme YOK.
⚠️ **Kontör sınırlı** → gereksiz WS çağrısı yapma.

## Akış
1. `doctor` — kimlik geçerli mi? Yeşil → Adım 3.
2. Bir-kerelik gizli giriş: `bash scripts/elogo.sh login` → WS Kullanıcı Kodu + Şifre'yi GİZLİ (`read -rs`)
   girer, `Login` ile doğrular, `cortex-access.env`'e (600) yazar. (Ana insan-portal şifresini WS'e KOYMA.)
3. Asıl iş (salt-okur, idempotent):
   - `bash scripts/elogo.sh status <ETTN>`   → fatura durumu
   - `bash scripts/elogo.sh get <ETTN> [f]`  → kesilmiş e-Arşiv **PDF** indir
   - `bash scripts/elogo.sh xml <ETTN> [f]`  → **UBL XML** indir
4. Doğrula: `bash scripts/elogo.sh doctor` (yeşil). Sır YALNIZ cortex-access.env (600) + registry pointer.

## Çalışan referans
Firma: FAHRİ GÖKÇE ELEKTRONİK (VKN 3840044863). Prod'un kullandığı WS alt-kullanıcısı `…mmebroker` —
ONA DOKUNMA. Ajan erişimi için ayrı `3840044863mmexclaude` alt-kullanıcısı açıldı (8 Tem 2026).

## YASAK / dikkat
- **Kuyruk-tüketen ops YASAK:** `GetDocument`/`receiveInvoiceDone`/`GetDocumentDone` gelen-fatura kuyruğunu
  tüketip "alındı" işaretler → eski prod cron'unun (b2b_elogo_sync) belgesini kaçırtır. Bu skill onları SUNMAZ.
- Prod'un `…mmebroker` alt-kullanıcısını sıfırlama; Railway'deki eski `ELOGO_WS_*` env'ine yazma (CLAUDE.md §3).
- TASLAK (kesilmemiş, Fatura No boş) faturalar WS'te YOKTUR → `get`/`xml` "NOTFOUND" döner (hata değil).
- Şifre bilinmiyorsa DUR, kullanıcıdan iste — asla brute-force (kilit riski).
