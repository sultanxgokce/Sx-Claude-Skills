---
name: ekip-kur
type: agent
version: 1.5.0
description: >
  Bir projeye çok-ajan KOORDİNASYON-SUBSTRATI kurar — RÖPORTAJ-MODU: tek /ekip-kur çağrısında kullanıcıyı
  röportaj eder (proje · roller · terminaller · modlar · tmux-casing), gelenek-uyumlu İSİM önerir, onaylatır,
  topladığı gerçek-roster'la scaffold'lar. Üretilen: tmux-tetik primitifi (ekip-notify.sh, 4 kritik-fix baked-in)
  + tek-kaynak roster (ekip-registry.yaml) + broadcast kanalı (ekip-brief.md) + 3 USER-ONLY tetik-skill
  + SessionStart self-recognition hook (clear/compact-proof kimlik) + go-live checklist. Fix'ler şablonda sabit.
  Kaynak-desen: Nexus SERDAR-ailesi koordinasyon-sistemi.
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
tags: [koordinasyon, ekip, multi-agent, tmux, orchestration, scaffold, skill-uretici, roportaj, self-recognition, ekip-notify]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# Ekip-Kur — çok-ajan koordinasyon substratı

## Ne işe yarar
Sultan bir projede birden çok Claude'u (ayrı tmux-oturumları) paralel çalıştırıp aralarında
"kanalını oku + gereğini yap" sinyalleri geçirmek istediğinde, bu koordinasyon-sinir-sistemini her
projede elle kurmak angarya. Bu skill onu **bir kez damıtıp** her projeye scaffold'lar:

> `/ekip-kur [hedef-proje]` → **RÖPORTAJ** (proje · roller · modlar · tmux-casing) → gelenek-uyumlu isim-öner →
> onayla → substratı scaffold'la → gerçek-roster'la registry doldur → self-recognition-hook wire → go-live.

**Kaynak-desen = Nexus SERDAR-ailesi** (`scripts/aile-notify.sh` + `_agents/handoff/aile-registry.yaml`
+ `aile-brief.md` + ekip-brief skilleri). Bu skill onun jenerik (`ekip-*`) kopyasıdır.
**Model-referans = [`erisim-skill-fabrikasi`](../erisim-skill-fabrikasi/SKILL.md)** (scaffold + doldur deseni).

## Üretilen substrat (hedef-projede)
| Dosya | Rol |
|-------|-----|
| `scripts/ekip-notify.sh` | tmux-tetik + sinyal-defteri primitifi (iki-yön: ping/--done/--waiting/--ack/--check; preflight+draft-guard baked-in) |
| `scripts/ekip-preflight.lib.sh` | pane-durum sınıflandırma (busy/menu/compact/idle + ghost-vs-draft SGR) — notify+durum source eder |
| `scripts/ekip-durum.sh` | tek-bakış radar (SALT-OKUR): insan-tablo · `--porcelain`(durum-skill tüketir) · `--nudge`(Stop-hook yönetici-nudge + üye-backstop) · `--nudge-poll`(F1 PostToolUse pasif tur-içi yönetici-nudge, uzun-tur körlüğü) |
| `scripts/ekip-ac.sh` | TEK-KOMUT sekme-kurtarma: kapanan sekmeler sonrası CANLI üye-tmux'larını tek terminalde paylaşımlı-pencere olarak geri-getirir (link-window; üye YARATMAZ/ÖLDÜRMEZ; `ekip` alias) |
| `scripts/ekip-compact.sh` | COMPACT-ORKESTRA (yönetici→üye UZAKTAN): `<üye-id>` verince o üyenin pane'ine `/compact` tetikler → settle → devam-nonce → `geri-yüklendi` marker-doğrula (kimlik-korunmuş re-bootstrap). `ekip-compact-core.lib` REUSE (öz-servis'in uzaktan-kardeşi). Exit-dürüst (0=doğrulandı·5=doğrulanamadı·6=takıldı). |
| `scripts/ekip-selfcompact.sh` + `-watcher.sh` + `ekip-compact-core.lib.sh` | ÖZ-SERVİS compact: üye yüksek-context'te KENDİNİ compact+re-bootstrap (detached-watcher: idle→/compact→devam-marker). ctx-nudge DANGER-eşiğinde `EKIP_SELFCOMPACT_PATH` ile önerir. |
| `_agents/handoff/ekip-registry.yaml` | tek-kaynak roster {id · tmux · mod · rol · kanallar · inbox} + `meta.yonetici` |
| `_agents/handoff/ekip-brief.md` | ortak broadcast kanalı (append-only, all-read) |
| `_agents/handoff/ekip-sinyal.log` | append-only sinyal-defteri (done/waiting/ack; oto-oluşur) — koordinasyonun kaynak-gerçeği |
| `.claude/skills/ekip-brief-ver/` | yönetici→hepsi brief (USER-ONLY) |
| `.claude/skills/ekip-brief-iste/` | ekipten durum-topla, salt-okur (USER-ONLY) |
| `.claude/skills/ajan-gorev/` | Sultan→bir üye görev (USER-ONLY) |
| `.claude/skills/durum/` | `/durum` — Sultan-dili ekip-özeti (kim çalışıyor/boşta/yön-bekliyor; jargonsuz; USER-ONLY) |
| `.claude/skills/ekibi-tazele/` | `/ekibi-tazele` — TEK-komut bakım: bayat-registry auto-fix + context-ağır tespit(compact-öner, onay-kapılı) + kapıda-bekleyen/ölü-oturum yüzeyleme (USER-ONLY) |
| `scripts/ekip-reconcile.sh` | registry↔tmux GÜVENLİ-otomatik-uzlaştırma (tmux-casing self-heal · uye_sayisi düzelt · boş-yonetici doldur); riskli-olanı (ölü-oturum, duplike-id, registry-dışı-oturum) yalnız BAYRAKLAR |
| `scripts/ekip-context-scan.sh` | context-ağır-üye best-effort TESPİTİ (dışarıdan `~/.claude/projects/` transcript-taraması, ctx-nudge.sh ile aynı ölçüm) — SALT-OKUR, asla compact tetiklemez |
| `scripts/ekip-tazele.sh` | `/ekibi-tazele`'nin CLI-motoru — reconcile+context-scan+durum'u sırayla koşup tek-rapor basar; `--dry-run`/`--pct`/`--max-age-min` |
| `scripts/ekip-self-recognition.sh` | SessionStart hook: tmux-oturum→registry ters-lookup→**JSON** kimlik enjekte + self-heal (clear/compact-proof; eşleşme-yoksa sessiz) |
| `scripts/ekip-hooks/ctx-nudge.sh` | PostToolUse hook: context-eşik nudge (ERKEN<%80 sessiz-anchor / DANGER≥%80 compact-öner; model-farkında pencere) |
| `_agents/handoff/EKIP-settings-hook-snippet.json` | 3-hook wire-snippet'i (SessionStart+Stop+PostToolUse; settings.json'a merge-instructions) |
| `_agents/handoff/EKIP-GO-LIVE-CHECKLIST.md` | duman-testi + izolasyon-notu |

## 4 KRİTİK-FİX (ŞABLONDA SABİT — tek-kaynak-gerçek, DEĞİŞTİRME)
`ekip-notify.sh` bu 4 fix'i taşır; roster değişse de bunlar sabit kalır:
1. **3-adım ayrı-Enter** — `send-keys C-u` → `send-keys -- "$MSG"` → `sleep 0.4` → **ayrı** `send-keys Enter`.
   Gömülü-Enter (metin+Enter tek çağrı) Claude-Code TUI'de **submit ETMEZ**. Bu 4 satırı birleştirme = regresyon.
2. **self-loop guard** — `$TMUX_PANE`'den çağıran-oturumu çöz, kendini tetikleme.
3. **has-session dürüst-warn** — oturum yoksa stderr-uyarı + `eksik_oturum` say + exit 1 (sessiz-geçme yok).
4. **python3 line-based parse** — PyYAML/yq gereksiz; registry düz-blok tutulur.

## SELF-RECOGNITION (clear/compact-proof kimlik · `ekip-self-recognition.sh`)
Bir üye `/clear` ya da compact yapınca kimliğini kaybeder. SessionStart-hook bunu re-bootstrap eder:
**tmux-oturum-adı** (`display-message '#S'`, `$TMUX_PANE` hedefli) → **ekip-registry ters-lookup** → eşleşen
üyenin kimlik-bloğunu (id · mod · rol · kanallar · inbox · brief + "kimliğini koru, brief oku, devam") context'e enjekte eder.
- **Eşleşme yoksa hiçbir şey basmaz (exit 0) → ekip-dışı oturumlarda REGRESYON-YOK.** Registry/tmux yoksa da sessiz.
- **Wire:** `EKIP-settings-hook-snippet.json` → `.claude/settings.json` `hooks.SessionStart` (matcher `"*"` — REGEX DEĞİL exact-string; `startup|clear|compact` alternation ÇALIŞMAZ).
  Mevcut `cortex-session-start` (genelde `settings.local.json`) **RAKİP DEĞİL** — ayrı entry/dosya, ikisi de ateşler = **tamamlayıcı**.
  Doktrin gereği scaffold canlı-`settings.json`'u OTOMATİK yeniden-yazmaz → snippet'i ajan/Sultan merge eder (mevcut hook'ları silmeden).
- **Test:** `bash scripts/ekip-self-recognition.sh <oturum-adı>` (override) veya gerçek tmux-oturumunda argümansız.

## İKİ-YÖN KOORDİNASYON DÖNGÜSÜ (sinyal-defteri + radar + nudge)
Klasik ping tek-yönlüdür (yönetici→üye). Bu substrat PULL→PUSH döngüsünü kapatır:
- **`--done`/`--waiting` (üye→yönetici):** üye işini bitirince/yumuşak-kapıya gelince ÖNCE `ekip-sinyal.log`'a
  yazar (kaynak-gerçek), SONRA yöneticiye ping atar. Ping bloklansa da sinyal kaybolmaz.
- **`ekip-durum.sh --nudge` (Stop-hook):** yönetici bir turu bitirince, bekleyen ACK'sız sinyal VARSA
  additionalContext ile yüzeye çıkarır (turu bloklamaz). ⚠️ **üye-backstop:** üye yumuşak-kapıda `--waiting`
  emit etmeyi unutsa bile Stop-hook pane-imini tespit edip yönetici'ye OTOMATİK waiting atar (sessiz-kapıda-bekleme fix'i).
- **`ekip-durum.sh --porcelain` + `/durum`:** yönetici/Sultan tek-bakışta "kim çalışıyor · kim boşta · kim gizlice
  yön-bekliyor" görür; `/durum` skill ham-jargonu Sultan-diline çevirir.
- **`meta.yonetici` ZORUNLU:** `--done`/`--waiting`/`--nudge` hedefi budur. Boşsa scriptler İLK-üyeyi varsayar +
  stderr uyarı basar (yönetici-hardcode YOK — her ekibe taşınabilir).

## CONTEXT-NUDGE (öz-yönetimli compact · `ekip-hooks/ctx-nudge.sh`)
PostToolUse-hook context-doluluğunu izler: ERKEN-tier (~%65-80) sessizce "resume-anchor'ını diske yaz + devam"
(bloke-soru AÇMAZ → koordinasyon-akışını bölmez); DANGER-tier (≥%80) TEMİZ faz-sınırında Sultan'a compact-önerir.
Pencere model-farkındadır (1M/500k/200k). **Öz-servis-compact DAHİL** (v1.5.0+): scaffold `ekip-selfcompact.sh`
(+watcher +core-lib) yazar → ctx-nudge onu tespit edip `EKIP_SELFCOMPACT_PATH` set eder → DANGER-mesajı üyeye
KENDİNİ-compact ettirmeyi önerir (detached-watcher: idle→/compact→re-bootstrap-marker). Uzaktan-kardeşi =
`ekip-compact.sh <üye-id>` (yönetici→üye orkestra). İkisi de `ekip-compact-core.lib.sh` çekirdeğini paylaşır (DRY).

## EKİBİ-TAZELE (tek-komut bakım · `/ekibi-tazele` · `ekip-tazele.sh`)
Var-olan parçalar dağınıktı: `ekip-durum.sh` bayat-registry'yi yalnız UYARIRDI (düzeltmezdi), context-doluluk
yalnız her üyenin KENDİ `ctx-nudge.sh` hook'unda içeriden görünürdü (dışarıdan bakan yok), bekleyen/ölü-oturum
tespiti ayrı komutlardı. `/ekibi-tazele` bunları TEK çağrıda birleştirir:
- **(A) registry-reconcile — GÜVENLİ olan otomatik-düzelt:** tmux-casing/rename self-heal (tek-aday varsa),
  `meta.uye_sayisi` gerçek-sayıyla düzelt, boş `meta.yonetici`'yi ilk-üyeyle doldur (dolu-değer ASLA ezilmez).
  Riskli/belirsiz olan (ölü-oturum, registry-dışı-oturum, duplike-id, geçersiz-yönetici) yalnız **BAYRAKLANIR** —
  insan-kararı gerekir, otomatik eklenmez/silinmez.
- **(B) context-ağır üye — best-effort TESPİT, ASLA otomatik-compact:** `~/.claude/projects/<proje-slug>/*.jsonl`
  transcript'lerini `ctx-nudge.sh` ile AYNI ölçümle (usage.input_tokens+cache_*/model-pencere-tahmini) dışarıdan
  tarar; kimlik-eşleme self-recognition marker'ı (`<MID> geri-yüklendi`) üzerinden best-effort — eşlenemeyen
  oturum dürüstçe `UNMAPPED` sayılır (uydurulmaz). Compact-tetikleme SKILL.md'de Sultan-onaylı (AskUserQuestion).
- **(C) kapıda-bekleyen yüzeyle:** `ekip-durum.sh --porcelain`'i REUSE eder (yeni-mantık icat etmez).
- **(D) ölü/eksik oturum bayrakla:** aynı porcelain-çıktının `oturum=0` satırları + reconcile'ın `olu-oturum` flag'i.

**CLI-motoru** (`scripts/ekip-tazele.sh [--dry-run] [--pct N] [--max-age-min N]`) skill'siz de çalışır — Sultan
ya da bir cron/CI bunu çıplak koşup TAB-`SUMMARY` satırını otomasyonla tüketebilir. Exit: 0=tamamen-temiz ·
1=en-az-bir-madde insan-bakışı bekliyor (fix/flag/heavy/waiting/dead) · 2=usage.

## Akış (`/ekip-kur` çağrılınca) — RÖPORTAJ-MODU
**Amaç:** Sultan tek `/ekip-kur` yazınca skill onu RÖPORTAJ eder, gelenek-uyumlu isimler önerir, onaylatır ve
topladığı GERÇEK-roster'la ekibi kurar. **Ezberlenmiş roster YOK** — her şey röportajda toplanır. Onay-alanına ajan-değer yazmaz.

### 1. Hedef-projeyi belirle
Argüman verildiyse onu al; yoksa çalışılan proje-kökü (`git rev-parse --show-toplevel`). Sultan'a teyit ettir.
Mevcut ajan-geleneği varsa OKU (`_agents/orchestration/AGENT_REGISTRY.md` / proje-CLAUDE.md) → röportajda isim-önerisine kaldıraç yap.

### 2. RÖPORTAJ (interaktif — AskUserQuestion + konuşarak; tek-tek, Sultan'ı yormadan)
1. **Ekip/proje-adı** (brief `meta.ekip`).
2. **Kaç üye/terminal?**
3. **Her üye için:** rol (tek-cümle) · **mod** ∈ {motor, kod, salt-okur, salt-plan} (AskUserQuestion) · **ad**.
   - **AD VERİLMEZSE → gelenek-uyumlu ÖNER** (KÂHYA `/ise-alim` emsali): projenin ajan-geleneğine bak
     (ör. SERDAR-ailesi `-SERDAR` eki; Osmanlı/Türkçe rol-adları SİNAN/CABİR/KÂHYA…). 2-3 aday öner → Sultan seçsin.
4. **tmux oturum-adları + CASING** — her üye `<oturum>:0`. ⚠️ **CASING firsthand-teyit:** hedef-ortamda
   `tmux ls` ile birebir doğrula (case-duyarlı; yanlış-casing = sessiz ping-kaybı). İzole-konteynerse Sultan
   o konteynerden verir → go-live orada teyit (VARSAYMA).
5. **kanallar/inbox** — varsayılan öner `_agents/handoff/<id-lower>-durum.md` + inbox `<id-lower>-inbox.md`; Sultan sadeleştirebilir (inbox `""` olabilir).

### 3. Özet-onay (düzeltme şansı — ZORUNLU)
Roster'ı TABLO hâlinde göster (id · tmux · mod · rol · kanallar) → Sultan onaylasın. **Onay gelmeden scaffold'a GEÇME** (insan-onay-alanı; yanlış-casing/eksik-mod burada düzelt).

### 4. Substratı scaffold'la
```bash
bash <bu-skill-dizini>/scaffold.sh <hedef-proje-dizini>        # non-destructive (mevcut dosyayı ezmez; yenilemek için --force)
```
Sabit dosyaları (notify.sh + self-recognition.sh + brief + 3 skill + checklist + hook-snippet) yazar; registry'yi `.tmpl`'den seeder.

### 5. Registry'yi GERÇEK-roster'la doldur
`_agents/handoff/ekip-registry.yaml`'deki örnek `UYE1/UYE2`'yi SİL, röportaj-roster'ını yaz. `meta.ekip` · `meta.uye_sayisi` · `meta.guncelleme` doldur. **Sır-değer ASLA** (yalnız tmux/rol/kanal).

### 6. Hook'ları wire et (3-tip)
`_agents/handoff/EKIP-settings-hook-snippet.json` → `.claude/settings.json` `hooks`'a MERGE — 3 tip: **SessionStart**
(kimlik, matcher `"*"`) · **Stop** (`ekip-durum.sh --nudge`) · **PostToolUse** (`ekip-hooks/ctx-nudge.sh`, matcher `"*"`).
⚠️ matcher REGEX DEĞİL exact-string. Mevcut hook'ları SİLME — cortex-session-start vb. korunur = tamamlayıcı.

### 7. Go-live / duman-testi
`EKIP-GO-LIVE-CHECKLIST.md`'i Sultan'a sun. Duman-testi (3-adım-Enter + self-recognition) tmux gerektirir →
oturumların açık olduğu ortamda, Sultan-eşli. **"Kuruldu" ≠ "canlı"** — checklist yeşillenene dek canlı deme (Engel-Doğrulama disiplini).

## İZOLASYON NOTU (izole-konteyner hedefleri, ör. cloudtop-mmex)
Dosyalar bu (kaynak) konteynerinden yazılabilir AMA **canlı tmux-tetik hedef-konteyner-içinde** çalışır.
Dosya-yazımının hedef-konteynere propagasyonu mount/senkron-topolojisine bağlı → **VARSAYMA**, `ls` ile teyit et.
Duman-testi = hedef-oturumların yaşadığı konteynerde.

## PR-YETKİ (bypassPermissions — üye "tamam" sonrası KENDİ PR açar+merge'ler)
Koordinasyon-substratının doğal-uzantısı: üye işini bitirince Sultan-diliyle özetler → Sultan **"tamam"** → üye
**otonom** `gh pr create` + CI-bekle + `gh pr merge` yapar (Sultan'a sıfır-komut). Scaffold'lanan `ekip-brief.md`
bu B-akışını `🔀 PR-bloğu`nda taşır. Kurulum-notu (opsiyonel ama önerilen):
- **İki-kapı (İKİSİ gerekli):** (1) varsa pr-gate PreToolUse-hook `gh pr create`'i marker'la geçirir
  (ör. `AGENT_DASHBOARD_PR_SKILL=1`) — bypass'ta **BİLE** ateşler (permission-öncesi). (2) permission-classifier
  `auto`-mode'da `gh pr merge`'ü sert-durdurur (allow-rule `Bash(gh pr *)` **YETMEZ** — firsthand-doğrulandı,
  rule vardı yine bloklandı); **`bypassPermissions` bunu temizler** (Shift+Tab/slash ile mid-session açılamaz).
- **Kurulum:** hedef-container `~/.claude/settings.json` → `permissions.defaultMode: "bypassPermissions"`
  (+ `skipDangerousModePermissionPrompt: true`). Ön-koşul: **non-root** (uid≠0) + sandbox/izole + yedekli.
  ⚠️ **Her izole-container'a AYRI** uygulanır — kaynak-container'daki değişiklik hedefe GEÇMEZ (izolasyon).
- **Açık-seans restart:** mid-session çevrilemez → `claude --resume <session-id>` (paylaşılan-cwd'de `--continue` DEĞİL).
- **Bypass'ta korumalar durur:** `deny`/`ask`-kural + PreToolUse-hook + rm-rf circuit-breaker yine ateşler.
- **DERS:** bayat "classifier-bloklar/no class-retry" hafızası **≠ engel-kanıtı** → yeni-modda taze-probe et
  (Sultan'ın açık mod-değişimi ≠ gizli class-retry). Detay: `EKIP-GO-LIVE-CHECKLIST.md` §5b · vaka: Nexus PR#310.

## Doktrin bağları
- **Altın Kural (Sx-Claude-Skills):** bu skill'in KENDİSİ geliştirilince kaynak burada (Sx-Claude-Skills) güncellenir,
  `version` artırılır, `node sync-skills.mjs --apply` ile dağıtılır. (Üretilen substrat proje-lokaldir, sync'lenmez.)
- **Non-destructive scaffold:** mevcut canlı-koordinasyon-sistemini `--force`'suz ASLA ezme.
- **Dürüstlük:** "kuruldu" demek "canlı" demek değil — go-live checklist kanıtlanmadan canlı deme.
- **Sır-hijyeni:** registry'ye/brief'e sır-değer ASLA; yalnız tmux-hedef/rol/kanal.
