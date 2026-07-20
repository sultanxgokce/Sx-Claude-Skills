---
name: iskan
type: agent
version: 0.7.1
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
- `ekip-pong` (FAZ-6b, CANLI · P3 pong-kablosu): `ekip-pong <proje> --dry-run|--apply [--no-ping]` —
  ekip-yerlestir'in YERLEŞTİRDİĞİ her seat'in GERÇEKTEN canlı+doğru-kimlikli+yanıt-verir olduğunu kanıtlar
  (tenant-pong-proof delegesi; session-var + kimlik-banner bayt-eş + KENDİ-KORUMALI PONG üç-kapı; SAHTE-YEŞİL
  YOK). Kur zincirinde ekip-yerlestir'in ardından, claude-BAŞLATMADAN ÖNCE koşar (pane taze-shell; sıra-kritik).
  Roster-kaynağı ekip-yerlestir ile AYNI (`ISKAN_EY_ROSTER` → container-içi ekip-registry.yaml). Üç-durum:
  yeşil(GEÇTİ) / kırmızı(seat-ölü → **fail-closed**, zincir DURur) / doğrulanmadı(ölçülemedi, unknown≠fail).
  **Pozitif-kanıt kapısı:** özet-markör "canlılık-kapısı geçildi" (kondüktörün GEÇTİ sinyali) YALNIZ ≥1 seat
  POZİTİF-yeşilse basılır; boş/yalnız-boşluk roster → fail-closed, tümü-ölçülemedi (yeşil=0) → markörsüz
  [doğrulanmadı] (unknown≠pass; sahte-GEÇTİ yok).
  Pong-script: `ISKAN_PONG_SH` (default `Nexus/scripts/tenant-pong-proof.sh`). Standalone "Test now" re-verify
  için de kullanılır (post-claude → `--no-ping`, banner-kayması KAPI-C false-red panzehiri).
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
  durum-sinyalleri: 'zaten-sokuk' (kayıt-yok∧arşiv-var, rc=0) / 'kayitsiz-proje' (ikisi-de-yok, rc≠0) ·
  **3-Çit mahrem-reddi** (v0.5.0): mahrem-tenant adları (vekatip/mmex/medigate/huma/mihenk) HER modda
  GO'lu bile REDDEDİLİR (cmd_kur aynası; `sokum vekatip --apply` deliği kapandı, sıfır-dokunuş).
- `kur` (D6, CANLI): `kur <proje> [--dry-run|--devam|--durum]` — UC1 tam-yaşamdöngüsü ZİNCİRLEYİCİSİ
  (duraklı durum-makinesi, mimSerdar §4.2): mevcut alt-komutları CLI-invoke ederek FAZ-sırasıyla besteler,
  HİÇBİRİNİ yeniden yazmaz: yeni-proje(dry→apply) → **DURAK-1 cloudtop-PR merge** (REPO-FIRST insan-durağı,
  exit=0 + --devam) → iskan-host --apply → provizyon → cf-yayin → ekip-yerlestir → **ekip-pong** → evergreen-kaydet.
  GO-marker'ları ASLA bypass/export etmez (her adım kendi GO'sunu kendi ortamından bekler; GO-yok exit=4
  AYNEN iletilir + Sultan-dilinde hangi-GO raporu). Durum-dosyası git-DIŞI
  `${ISKAN_STATE_DIR:-$HOME/.claude}/iskan-kur-<proje>.state` — **state v2** (PR-C env-pin, 0.6.0):
  satır-1 = son-tamamlanan-adım AYNEN (eski okuyucu head-1 uyumlu) + satır-2+ = `pin AD=değer` blokları
  (600, atomik tmp+mv). Pin-allowlist DAR-5: `ISKAN_CLOUDTOP_REPO_DIR · ISKAN_REPO_COMPOSE ·
  ISKAN_REPO_TUNNEL · ISKAN_SSH_HOST · ISKAN_EY_ROSTER`; **GO'lar ve güvenlik-kapı setleri
  (ISKAN_PROD_HOSTS/ISKAN_SOKUM_HOSTS/ISKAN_SOKUM_KOMSULAR) ASLA pinlenmez** (yazıcı allowlist-only +
  okuyucuda kurcalanmış-state kırmızısı rc=1); ISKAN_CF_SH/ISKAN_PONG_SH de bilinçli pinlenmez
  (delege/prob-yolu state-güvenine bağlanmaz — launcher taze verir). `--devam` pinleri geri yükler
  (öncelik **açık-env > pin > default**; boş açık-env `AD=` = o koşuda pin-iptal → fallback); kanıt-satırı
  adlar-only (`[yeşil] env-pin yüklendi: <ADLAR>` — değer stdout'a basılmaz). Her kur-koşusu başında
  **ENV-HEDEF-HARİTASI** (salt-oku preflight): adım→etkin-hedef→kaynak + V1 hedef-ayrışma (F1-imzası:
  ayrışma ∧ compose=default → zincir/devam kırmızı; iki taraf açık/pin ise uyarı+devam) + V2
  worktree-checkout (.git DOSYA ∧ cf-yayin-öncesi → kırmızı; dry-run/durum'da bilgi-dili).
  `--devam` oradan sürer · `--durum` salt-oku · `--dry-run` TÜM zinciri yazmadan uçtan-uca planlar (exit=3).
  İlk kırmızıda DUR (fail-closed) · 3-Çit: mahrem-tenant adları (vekatip/mmex/medigate/huma/mihenk) RED.
  ⚠️ rc-değişimi (0.6.0, bilinçli): KURCALANMIŞ state'te (GO/deny-pin satırı) `--durum` raporu yine basar
  ama sonda `[kırmızı] GO-pin tespit` + **rc=1** döner (eski daima-0 sözleşmesi temiz-state'te aynen sürer;
  sahte-yeşil yok); zincir/devam/dry-run kurcalanmış-state'te anında rc=1.
  Dürüstlük-notları: (a) pinler YALNIZ `kur` zincirinde geri-yüklenir — `sokum` pin OKUMAZ (sokum'da
  env'i elle ver; sokum state-dosyasını tek-rm ile pinleriyle birlikte siler). (b) Rollback'te (eski-kod +
  v2-state) zincir head-1 sayesinde DOĞRU sürer ama eski yazıcı truncate ettiğinden pinler ilk adım-yazımında
  sessizce kaybolur = F6-degradasyonu (bozulma değil). (c) ISKAN_EY_ROSTER pini `uye-ekle` sonrası
  BAYATLAYABİLİR — tazelemek için açık-env ver (pin kendini tazeler), iptal için boş `ISKAN_EY_ROSTER=` ver.
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

## Durum (2026-07-20, CYCLE-4 Tier-A birth-side hijyen — v0.7.1)
✓ Sertleştirme-döngüsü cycle-3 dürüst-verdiktinin META-DERS-3'ü (birth ana-checkout'u kirletiyor →
her tur env-reset) kapatılmaya başlandı. **Tier-A (debris-temizlik):** söküm ADIM-5 (5-manifest) ve
evergreen (inventory + backup.sh) yazımdan önce `.bak` güvenlik-yedeği alıyor ama BAŞARIDA silmiyordu →
working-tree'de kalıcı `.bak` debris = env-reset tetikleyicisi. Yeni ORTAK helper `_iskan_bak_temizle`
başarı-noktasında `.bak`'ları siler; **fail-path'ler `.bak`'ı restore+inceleme için KORUR** (helper
yalnız başarı-noktasında çağrılır). Golden: davranış (silinir + orijinal BAYT-korunur + `.bak`-yok
sessiz-geçer) + kaynak-wiring + evergreen #40 flip (`.bak` başarıda-temiz). Süit **217/217**.
(Tier-B = ADIM-1 temiz-worktree redirect = ayrı Nexus PR: `dogum-zinciri` env-wiring.)

## Durum (2026-07-20, CYCLE-3 söküm-fix'leri — v0.7.0)
✓ İSKÂN sertleştirme-döngüsü cycle-2 söküm-hasadının **3 bulgusu** kapatıldı (hepsi Sx-merged, golden'lı):
- **fix-1 (bulgu-1, Sx#48):** söküm arşiv-yolu artık **saniye-hassas** (`date +%F-%H%M%S`) — aynı-gün ≥2
  söküm arşiv-yolu çakışıp ADIM-6'da durmuyor (cycle-1+2 aynı-gün yakalanmıştı). Golden: bare `+%F` yasak.
- **fix-2 (bulgu-2, Sx#49):** **kısmi-teardown koruması** — compose-kaydı temiz AMA host config-dir hâlâ
  varsa (önceki söküm ADIM-6 öncesi durmuş) 'zaten-sokuk' DEĞİL: `rc=1` KISMİ-SÖKÜM reddi, kur-state
  SİLİNMEZ + config KORUNUR (config-öksüz-bırakma + telafisiz-state-silme kapandı). Golden: config-dir probe.
- **fix-3 (bulgu-3, Sx#50):** yeni **ADIM-5b HOST-compose residual temizliği** — ADIM-2 `down` sadece
  container'ı indiriyor, host compose-METNİ bayat-blokla kalıyordu → sonraki doğumun COMPOSE-SENKRON
  komşu-kapısı "host'ta ölü tenant-bloğu" ile fail-closed oluyordu. ADIM-5b bloğu host'tan **cerrahi**
  siler (birth `_compose_senkron`'un söküm-simetriği: birth YAZAR, söküm SİLER; aynı `.bak-TS→tmp+mv→BAYT
  re-verify` yolu). `del lines[start:end]` yeniden-inşa yapmaz → 7 MAHREM komşu bayt-korunur (birth full-
  rewrite'ından güvenli). Asimetrik-yutma token-kapısı: aday-bitişik token'sız yorum → `rc=5` fail-closed
  (host-drift). docker ÇAĞRILMAZ → ADIM-7 komşu-kanıtı korunur. Golden: blok-var/idempotent/host-drift/wiring.
Süit **215/215**. Bu sürüm söküm'ün "iz-sıfır" hedefini host-katmanına genişletir (repo iz-sıfır + host iz-sıfır).

## Durum (2026-07-19, PR-C env-pin + preflight-harita — v0.6.0)
✓ F1/F6 fix (CYCLE-1 PR-C): kur-state **v2 env-pin** — satır-2+'da allowlist DAR-5 pinleri; `--devam`
env-kaybı (F6: kondüktör-roster'ı elle yeniden-hesaplama) bitti. 4-katman GO-garantisi: K1 yazıcı
allowlist-only (ortam taranmaz) · K2 allowlist koşulsuz-atama · K3 okuyucu sabit kapı-sırası + deny-kırmızı
(*_GO + PROD_HOSTS/SOKUM_HOSTS/SOKUM_KOMSULAR — allowlist'ten ÖNCE, sessiz-atlama değil, iki-geçişli:
tamper'da SIFIR pin yüklenir) · K4 eval-yok. PREFLIGHT **ENV-HEDEF-HARİTASI**: adım→etkin-hedef→kaynak
(default|pin|açık-env) + V1 F1-imzası kırmızısı (yalnız ayrışma∧default — bilinçli worktree-PR deseni
bloklanmaz) + V2 worktree-.git erken-teşhisi (eşik `<cf-yayin`, üç '-d .git' kapısı sayılır).
Golden: 192/192 (öncesi 175; test-56+59 head-1'e bilinçli çevrildi + 17 yeni). Ertelenen: V3-debris
(operatör-preflight'ta var) · allowlist-v2 genişlemesi (cycle-3).

## Durum (2026-07-19, G1 compose-senkron — v0.5.0)
✓ G1 zincir-fix (CYCLE-1 PR-B): `iskan-host.sh --apply` artık R4 drift-kapısından HEMEN ÖNCE
**COMPOSE-SENKRON** koşar — origin/main'deki compose'u host'a TAM-DOSYA eşitler (elle-bridge bitti):
host-probe 3-durum (dosya-YOK → bootstrap-reddi exit=5; ölçülemedi → fail-closed exit=5) →
no-op kapısı **BAYT-eş** (md5; yapısal-eş-ama-bayt-farklı bayat ADAY-blok EZİLİR — 512m sessiz-OOM
panzehiri) → **KOMŞU-BAYT kapısı** (`compose_block.py sil <cname>` iki-taraftan adayı metin-düzeyi
çıkarır, kalan komşu-metinler md5-eş DEĞİLSE → fark-raporu + exit=5, **--force YOK**; yapısal kapı
mem_limit/env/image görmediğinden MAHREM komşu-drift'ine kördü — bayt-kapı komşu-ezmeyi imkânsız kılar;
teşhis-ipucu: tamamlanmamış söküm / komşu-drift MAHREM dahil) → **ASİMETRİK-YUTMA kapısı**
(`compose_block.py yutulan <cname>`; `sil` aday-header'a BİTİŞİK host-only bir bakım-yorumunu adaya
yutup komşu-md5'i sahte-EŞ gösterebilir — host'un yuttuğu bir non-blank satır repo'nunkinde YOKSA
tam-dosya yazımı onu SİLERDİ → exit=5, sahte-attestasyon panzehiri) → .bak-TS + tmp+mv atomik yazım
(mv-fail'de .iskan-tmp artığı temizlenir) → **BAYT re-verify** (düşerse .bak-restore + exit=1). docker-up
senkronda ASLA çağrılmaz (container-mutasyon tek-noktası R1); R4 senkron-sonrası tanım-gereği yeşil
(totoloji) — regresyon-bekçisi olarak kalır, genel-drift'i senkron-öncesi komşu-BAYT + yutulan kapıları
yakalar. Yeni GO-marker YOK (ISKAN_FAZ4_GO şemsiyesi). cmd_apply girişine **ad-hijyeni**
(`^[A-Za-z0-9-]+$` — iskan.sh `_ey_ad_hijyeni` ile BAYT-eş, parite-goldenli; kur-adım-1'in kabul edip
host-doğumun reddetmesi 'aynı-adım-fail' tuzağı kapandı; nokta/slash/boşluk charset-dışı → ERE-enjeksiyon
+ path-traversal kapalı, REPO-KANIT ayrıca sabit-string) + **3-Çit mahrem-reddi** eklendi
(`--apply --proje vekatip` GO'lu bile RED; liste iskan.sh ISKAN_KUR_IZOLE ile parite-goldenli).
R2-guard yolunda yazım olduysa kanıta zorunlu not: "dosya güncellendi, çalışan-config ESKİ — recreate
ayrı Sultan-alanı". Ertelenen: söküm ADIM-2b host-blok-çıkarma + standalone --senkron CLI (cycle-3).

## Durum (2026-07-19, P3 pong-kablosu)
✓ P3 (Doğum-Akışı, v0.4.0): `ekip-pong` (FAZ-6b) canlılık-kapısı zincire kablolandı — kur artık **8-adım**
(ekip-yerlestir → **ekip-pong** → evergreen-kaydet). Adım-sayısı ADIMLAR'dan TÜRER (magic-number yok).
tenant-pong-proof ÖKSÜZLÜĞÜ (B5) kapandı; seat-ölü → fail-closed (zincir DURur), SAHTE-YEŞİL yakalanır.

## Durum (2026-07-18, D6 kur-zincirleyici)
CANLI alt-komutlar: `doctor` (FAZ-1) · `seans-getir` (FAZ-2/3) · `yeni-proje` + `iskan-host.sh` (FAZ-4,
ISKAN_FAZ4_GO'lu) · `cf-yayin` (FAZ-5, ISKAN_FAZ5_GO'lu) · `ekip-yerlestir` (FAZ-6) · `ekip-pong` (FAZ-6b) · `uye-ekle` (FAZ-7) ·
`evergreen-kaydet` (FAZ-8) · `provizyon` (FAZ-9, ISKAN_FAZ9_GO'lu) · `sokum` (k0083, ISKAN_SOKUM_GO'lu) ·
`kur` (D6 zincirleyici — GO'ları yalnız SIRALAR, bypass etmez).
Kanıt-paketleri: `iskan/kanit/faz0..faz9,sokum/`. FAZ-9 mihenk-dogfood TESCİLLİ (k0084 MUHUR 13/13).
✓ Söküm-borcu KAPANDI (k0083): iskantest izleri `iskan.sh sokum iskantest --apply` ile geri-alındı
(container + CF + 5-manifest + arşiv); yaşam-döngüsü artık iki-yönlü (doğuş ↔ söküm).
✓ D6 tuzak-fix'leri (2026-07-18): yeni-proje default `mem_limit` 512m→**2g** ("sessiz-ölü ekip" panzehiri;
2g-altı açık-beyan WARN, hard-fail değil) · ekip-yerlestir hardcoded deneme-roster fallback'i KALDIRILDI
(kaynaksız hâl dürüst-kırmızı 'roster-kaynağı yok').
