---
name: avci
type: agent
version: 0.1.0
description: >
  AVCI — filo-geneli, kendini-onaran KAYNAK-TOPLAMA yetenek-servisi (basit web-scraper DEĞİL, yetenek-ağı).
  Gövde = paylaşımlı HTTP-servis (changedetection.io izleme/diff + Crawlee-TS ince av-motoru + TEK paylaşımlı
  Chromium); yüz = tüketici-container'lara ince CLI-istemci (avci fetch/extract/izle/durum). Kaynak-toplamayı
  merkezîleştirir: politeness-SABİT · kademeli-self-heal (K1/K2 $0 → K3 LLM tek-atış, bütçe-bayraklı) ·
  dürüst-sınır (stealth-yarışı YOK) · provenance-zorunlu · sır-hijyen (vault-cek) · ham-veri pCloud-CAS.
  "avci / kaynak-topla / scrape / fetch→markdown / izle-değişim / self-heal-scraper" tetiğinde.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [avci, bilesik, kaynak-toplama, scraper, usta]
status: v0.1-usta
---

# avci — (Usta · bileşik iş-sistemi · born-at-USTA)

> **FAZ-0 (AHÎ-doğum) iskeleti.** Bu sürüm = doktrin + kontrat + kapsam-refleksi. Çalışan av-motoru
> Faz-1'de gelir (build-spec: `Nexus/_agents/handoff/serdar-avci-faz1-spec.md`). Canlı servis (cloudtop-avci)
> Faz-3'te, KAPASİTE-GATE (Sultan) arkasında. Kanıt-matrisi G1..G13 → `SPEC §11`. R1 kapanışı = beyan değil,
> G-kanıt-dosyaları (`kanit/G<i>`).

**NE-DİR:** AVCI, filonun paylaşılan kaynak-toplama servisidir (Sultan-kararı R1). Üç şeyi BESTELER:
`vault-cek` (sır-değer-görmeden çözüm), `pcloud-erisim` (ham-veri CAS deposu), `erisim` (erişim-zinciri
dispatcher). Üstüne kendi av-motorunu (Crawlee-TS) + izleme-servisini (changedetection.io) + TEK Chromium'u
koyar. Ajan-yüzü CLI-first; kaynak-maliyeti servis-tarafında merkezî (ADR-009).

## Mimari (kontrat özeti — tam: SPEC §1)
- **Gövde = HTTP-servis** (avci-konteyneri): `POST /fetch` · `POST /extract` · `POST /izle` · `GET /job/<id>` ·
  `GET /health` · `GET /butce-rapor`. Varsayılan CheerioCrawler (browser'sız); Playwright YALNIZ
  `js_zorunlu:true` hedeflere. TEK paylaşımlı Chromium = cx33'e tek RAM-faturası.
- **Yüz = ince CLI** (curl-sarmalayıcı, tüketici-skill): `avci fetch <url>` · `avci extract <url> --schema <f>` ·
  `avci izle <url>` · `avci durum`.

## Besteleme (requires[] — DOCTRINE §10)
`ahi.manifest.yaml → requires[]` = **vault-cek · pcloud-erisim · erisim** (≥2 Kalfa → Usta kriteri sağlanır).
Bileşenler `.claude/skills/<kardeş>` yolundan çözülür (vendoring-YOK).

## USTA-değişmezleri (bu servis onları KOD-seviyesinde taşır — Faz-1+)
- **Test-kapılı:** "bitti" = deterministik-oracle. G1..G13 kabul-matrisi (SPEC §11) fixture/mock/canlı-testle
  kanıtlanır; kanıtsız-yeşil YASAK. 10/13 container-siz (fixture) ⟂ 3/13 canlı (G6/G12/G7-canonical).
- **İdempotent:** aynı-içerik 2 ardışık koşu → `changes.log`'a 0 yeni satır (G4); ham-veri sha256-CAS dedupe.
- **Sır-hijyenik:** tüm sırlar `vault-cek`/machine-identity ile DEĞER-görmeden; değer repo/log/stdout/API-yanıtına
  ASLA (G10 grep-testi kanıtlar).
- **Drift-dirençli:** kademeli-self-heal (K1 CSS/XPath+lexical $0 → K2 imza-eşleme $0 → K3 LLM tek-atış,
  cache+bütçe-bayrak); selector-kırılması koşuyu öldürmez, GÜRÜLTÜLÜ işaretlenir (G3/G9).
- **Dokümante:** kontrat SPEC §1-§14 + ADR-009; her çıktı-kaydı provenance taşır (`kaynak_id,url,zaman`; boş=FAIL, G8).

## Kapsam-refleksi (E3/R-03 · federe-standart — DOCTRINE §3; ahi/CI çıpa-kontrolü buraya bakar)
- **0) zaten-var-mı? (R-03):** HAYIR — tarandı: `ahi health` (canlı) · Sx-catalog.json · origin/main raf ·
  canlı `_global` raf → avci/scraper/crawl/kazi skill YOK. Komşular komplementer, çakışmıyor:
  `kesif` DOM-panel-TEST eder (doğrulama), `yt-transcript` tek-platform transcript; AVCI generic çok-kaynak TOPLAR.
- **1) negatif-kapsam (neye DOKUNMAYACAK — 'sınırsız' REDDEDİLİR):**
  - Stealth / anti-bot silahlanma-yarışı YOK (dürüst-sınır: DataDome/CF-Enterprise/davranışsal-ML → "kazınamaz"
    damgalı, RSS/API/üçüncü-taraf öner; SPEC §5).
  - Embeddings + vision AVCI'da KAPALI, **fail-closed** — hiçbir bayrakla açılamaz (G13; SPEC §6b).
  - Host-mutasyon YOK (Faz-0 repo-only; canlı-servis Faz-3 KAPASİTE-GATE + ISKÂN REPO-FIRST arkasında).
  - Residential-proxy AYRI bütçe-kalemi + Sultan-gate (G-F); default-OFF.
- **2) bölge-çakışma:** yok (yukarıda; kesif/yt-transcript komplementer). Üreteç-bölgesi çakışması yok.
- **3) dağıtım-kapsamı:** **seçili-liste** (tüketici-container'lar, per-container-ACL) — global-hepsi DEĞİL.
  install-ÖNERİSİ Sultan-gate G-E'de kilitlenir (Faz-3); `install_targets: []` = Faz-0'da dağıtım-ertelendi.
  Gerçek per-container sınır = SERVİS-tarafı runtime ACL (allowlist-dışı → 403 + log), skill-install değil.
  Girdiyi `sync-targets.json`/`catalog.json`'a insan/PR uygular (ADR-001; ahi/AVCI YAZMAZ).

## Sultan-gate'ler (Yetki-sınırı — design §4)
Container-placement + provizyon GO · final ACL-matris (G-E) · disk kalıcı-çözüm (AVCI 10. container tetikler) ·
RAM-eksen · bütçe-bayrak (llm-heal/resid-proxy/poll) · G-D mahremiyet (ZATEN gömülü, 2026-07-21) · kademe-töreni.

## Terfi-yolu (Pîr-PATH açık — şimdi USTA)
Doğumda Pîr objective-evidence (kendi-repo + CI + telemetri→gelişme-döngüsü) mekanik-yok → gereksiz-Pîr-şişmesi
YASAK (DOCTRINE §10). `GET /butce-rapor` sayaçları → telemetri-döngü + kendi-repo+CI olgunlaşınca
`ahi promote avci`; tören Sultan'da (hibrit).

## Kademe
Usta (S3 · bileşik). Doğrula: `ahi check avci` · Kanon: `ahi doctrine` · Kontrat: `serdar-r1-avci/10-AVCI-SERVIS-SPEC.md`.
