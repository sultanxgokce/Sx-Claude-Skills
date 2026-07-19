---
name: iskan
type: agent
version: 0.3.0
description: >
  Container + ekip yaşam-döngüsü master-skill. Bir hedef (yeni-proje / mevcut-ekip-yeniden-doğuşu / tek-üye-ekleme)
  için host-provizyon (UC1), oturum-kurtarma (UC2, deterministik session-id), üye-ekleme (UC3) akışlarını
  ekip-kur/ise-alim/sunucu-kur/cloudflare-erisim'i BESTELEYEREK tek-komuta indirger. FAZ-0: yalnız doğuş +
  doktrin + host-teyit probe'ları — host'a hiçbir yazma-dokunuşu YOK (bkz DOCTRINE.md).
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [iskan, bilesik, container-yasamdongusu, ekip-yerlestirme]
status: v0.1-usta
---

# iskan — Container + Ekip Yaşam-Döngüsü Master-Skill (Usta · bileşik)

**NE-DİR:** Bir hedef için container/ekip yaşam-döngüsünün üç kullanım-durumunu (UC1 yeni-iskân · UC2
yeniden-iskân/seans-getir · UC3 tek-üye-iskân) tek-yüzeyde toplayan bileşik-fabrika. Kendi owner-domain'i
(bugün hiçbir skill'de olmayan): (a) container-provizyon host-adaptörü, (b) tmux-oturumu gerçekten açma +
casing + deterministik session-id rezervasyonu, (c) CF-hostname orkestrasyonu, (d) evergreen-manifest
oto-yazımı. Dördü BESTELEDİĞİ kardeşlerin (aşağı) çalışma-kopyasına YAZMAZ — yalnız CLI-invoke eder
(ADR-001 owner-domain-dokunma).

**Alt-komutlar (plan §K1 — henüz FAZ-0, hiçbiri implemente değil, isimler kilitli):**
- `yeni-proje` (UC1) — container-provizyon motoru (FAZ-4'te host-mutasyonu başlar, Sultan-GO'lu).
  P1-sertleştirme (2026-07-19): --apply artık **DURAK-1 ÜÇLÜSÜNÜ** üretir — compose-blok (mount-paketi:
  ortak `./config/.claude` keyless-login + DEFAULT_WORKSPACE; mihenk-emsal) + `infra/setup-<ad>.sh`
  (ince-sarmalayıcı → setup-isolated.sh) + setup-tunnel 3-satır (değişken+ingress-çifti+route-dns);
  idempotent-geçiş eksik kardeş-kalemi tamamlar; B1-guard bilinçli-köprü allowlist'li (`ISKAN_B1_BILINCLI_KOPRU`)
- `seans-getir` (UC2) — deterministik session-id resume merdiveni (FAZ-2/3, K3 tasarımı)
- `cf-yayin` — CF-hostname yayını: Access-app+policy+DNS (cf.sh onboard delegesi) + tünel-ingress
  host-deploy (FAZ-5, `ISKAN_FAZ5_GO=1` Sultan-GO'lu; 7-hostname sert-kapı + .bak oto-geri-al)
- `uye-ekle` (UC3) — tek-üye-iskân (FAZ-7, CANLI): `uye-ekle <proje> <uye> [--gorev <g>] --dry-run|--apply` —
  kayıtlı İSKÂN-projesine TEK üye ekler (rezerve-uuid + tmux + banner + hafif-kimlik AGENT.md + registry).
  Çakışma-koruması ('uye-zaten-var') · Nexus-hedefte canlı-invoke YOK ('ise-alim' yönlendirmesi, İ1) ·
  izole-hedef dry-run'ı koşulsuz 'sultan-bildirim' satırı basar. Roster-köprüsü: ekip-yerlestir roster'ı
  `ISKAN_EY_ROSTER` (açık-override) ya da container-içi `_agents/handoff/ekip-registry.yaml`'dan okur;
  kaynak yoksa DÜRÜST-KIRMIZI rc=1 'roster-kaynağı yok' (D6 tuzak-fix — eski hardcoded denekAlfa/denekBeta
  fallback'i sahte-ekip doğuruyordu, KALDIRILDI).
- `evergreen-kaydet` (FAZ-8, CANLI): `evergreen-kaydet <proje> --dry-run|--apply` — kayıtlı İSKÂN-projesinin
  kalıcı izlerini evergreen-manifestlere yazar (REPO-FIRST lokal cloudtop working-tree; host-apply YOK):
  provider-inventory.yaml (tunnel.ingress + access_apps) + backup.sh (docker-inspect listesi). .bak +
  bash -n sözdizim-kapısı (düşerse .bak-restore rc=1) · idempotent ('mevcut → atla') · K4 kayıtsız-kapı
  ('kayitsiz-proje'). Bekçisi: cloudtop `evergreen-parity.sh` P8-CONTAINER + P9-CFAPP kolları (report-only;
  drift-inject kanıtı `iskan/kanit/faz8/drift-inject-test.sh`).
- `sokum` (k0083, CANLI): `sokum <proje> [--dry-run|--apply]` — TAM-SÖKÜM ("sökülemeyen sancak doğamaz"
  kapanış-yarısı): tmux-kapat → servis-scoped container-down (arg'sız down / -v YASAK) → ingress-çıkar
  (.bak'lı) + **8-hostname sert-kapı** (7-prod + mihenk; regresyonda oto-geri-al) → CF geri-alım
  (`cf.sh offboard` delegesi, tek-kayıt-assertion) → 5-manifest LOKAL repo-first geri-alım (.bak +
  bash -n kapıları + iz-sıfır/tombstone-yasak assertion; registry-dosyası SİLİNMEZ, künye çıkar) →
  config-dizini **arşive-taşı** (telafisiz-silme YOK) → komşu ÖNCE/SONRA StartedAt+config-hash kanıtı.
  dry-run DEFAULT (exit=3) · apply yalnız `ISKAN_SOKUM_GO=1` (marker-yok exit=4, sıfır-dokunuş) ·
  durum-sinyalleri: 'zaten-sokuk' (kayıt-yok∧arşiv-var, rc=0) / 'kayitsiz-proje' (ikisi-de-yok, rc≠0).
- `kur` (D6, CANLI): `kur <proje> [--dry-run|--devam|--durum]` — UC1 tam-yaşamdöngüsü ZİNCİRLEYİCİSİ
  (duraklı durum-makinesi, mimSerdar §4.2): mevcut alt-komutları CLI-invoke ederek FAZ-sırasıyla besteler,
  HİÇBİRİNİ yeniden yazmaz: yeni-proje(dry→apply) → **DURAK-1 cloudtop-PR merge** (REPO-FIRST insan-durağı,
  exit=0 + --devam) → iskan-host --apply → provizyon → cf-yayin → ekip-yerlestir → evergreen-kaydet.
  GO-marker'ları ASLA bypass/export etmez (her adım kendi GO'sunu kendi ortamından bekler; GO-yok exit=4
  AYNEN iletilir + Sultan-dilinde hangi-GO raporu). Durum-dosyası git-DIŞI
  `${ISKAN_STATE_DIR:-$HOME/.claude}/iskan-kur-<proje>.state` (tek-satır: son-tamamlanan-adım);
  `--devam` oradan sürer · `--durum` salt-oku · `--dry-run` TÜM zinciri yazmadan uçtan-uca planlar (exit=3).
  İlk kırmızıda DUR (fail-closed) · 3-Çit: mahrem-tenant adları (vekatip/mmex/medigate/huma/mihenk) RED.
- `doctor` — salt-okur preflight (FAZ-1)
- `check` — AHÎ-standart drift-lint (bugünden itibaren: `ahi check iskan`)

## Besteleme
`ahi.manifest.yaml` → `requires: [ekip-kur, ise-alim, sunucu-kur, cloudflare-erisim]` (4 kardeş, hepsi
Kalfa+). Bileşenler `.claude/skills/<kardeş>` yolundan çözülür (vendoring-YOK). İstisna (İ1, bkz DOCTRINE.md):
izole-container hedefinde `ise-alim`/KÂHYA DOĞRUDAN invoke EDİLMEZ — İSKÂN kendi hafif-kimlik-üreteci kullanır.

## Kademe
Usta (S3 · bileşik), born-at-Usta (`ahi new usta iskan`). generic-goal: "container + ekip yaşam-döngüsünü
(doğuş/yeniden-doğuş/üye-ekleme) tek-komutla yöneten fabrika". Terfi-olgunluk şerhi: DOCTRINE.md → "Manuel-beyan".
Doğrula: `ahi check iskan` · Kanon: `ahi doctrine` · İş-planı: `Nexus/_agents/handoff/help2serdar-iskan-is-plani.md`.

## Durum (2026-07-18, D6 kur-zincirleyici)
CANLI alt-komutlar: `doctor` (FAZ-1) · `seans-getir` (FAZ-2/3) · `yeni-proje` + `iskan-host.sh` (FAZ-4,
ISKAN_FAZ4_GO'lu) · `cf-yayin` (FAZ-5, ISKAN_FAZ5_GO'lu) · `ekip-yerlestir` (FAZ-6) · `uye-ekle` (FAZ-7) ·
`evergreen-kaydet` (FAZ-8) · `provizyon` (FAZ-9, ISKAN_FAZ9_GO'lu) · `sokum` (k0083, ISKAN_SOKUM_GO'lu) ·
`kur` (D6 zincirleyici — GO'ları yalnız SIRALAR, bypass etmez).
Kanıt-paketleri: `iskan/kanit/faz0..faz9,sokum/`. FAZ-9 mihenk-dogfood TESCİLLİ (k0084 MUHUR 13/13).
✓ Söküm-borcu KAPANDI (k0083): iskantest izleri `iskan.sh sokum iskantest --apply` ile geri-alındı
(container + CF + 5-manifest + arşiv); yaşam-döngüsü artık iki-yönlü (doğuş ↔ söküm).
✓ D6 tuzak-fix'leri (2026-07-18): yeni-proje default `mem_limit` 512m→**2g** ("sessiz-ölü ekip" panzehiri;
2g-altı açık-beyan WARN, hard-fail değil) · ekip-yerlestir hardcoded deneme-roster fallback'i KALDIRILDI
(kaynaksız hâl dürüst-kırmızı 'roster-kaynağı yok').
