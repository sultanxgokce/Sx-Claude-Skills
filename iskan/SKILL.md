---
name: iskan
type: agent
version: 0.1.0
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
- `yeni-proje` (UC1) — container-provizyon motoru (FAZ-4'te host-mutasyonu başlar, Sultan-GO'lu)
- `seans-getir` (UC2) — deterministik session-id resume merdiveni (FAZ-2/3, K3 tasarımı)
- `uye-ekle` (UC3) — tek-üye-iskân (FAZ-7)
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

## Durum (2026-07-15, FAZ-0)
Yalnız doğuş + doktrin + host-teyit probe'ları var. Host'a hiçbir yazma-dokunuşu yok. Alt-komutların HİÇBİRİ
henüz koşmaz (FAZ-1'den itibaren dolar). Kanıt-paketi: `iskan/kanit/faz0/`.
