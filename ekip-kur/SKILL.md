---
name: ekip-kur
type: agent
version: 1.3.0
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
tags: [koordinasyon, ekip, multi-agent, tmux, orchestration, scaffold, skill-uretici, roportaj, self-recognition, read-before-trigger, compact-orchestration, aile-notify]
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
| `scripts/ekip-notify.sh` | tmux-tetik primitifi (4-fix + **READ-BEFORE-TRIGGER ön-uçuş** baked-in; registry'yi python3 ile parse eder) |
| `scripts/ekip-compact.sh` | **COMPACT-ORKESTRA** primitifi (üyeyi uzaktan compact-et → kimlik-re-bootstrap-bekle → devam-ettir; dürüst-timeout) |
| `_agents/handoff/ekip-registry.yaml` | tek-kaynak roster {id · tmux · mod · rol · kanallar · inbox} |
| `_agents/handoff/ekip-brief.md` | ortak broadcast kanalı (append-only, all-read) |
| `.claude/skills/ekip-brief-ver/` | yönetici→hepsi brief (USER-ONLY) |
| `.claude/skills/ekip-brief-iste/` | ekipten durum-topla, salt-okur (USER-ONLY) |
| `.claude/skills/ajan-gorev/` | Sultan→bir üye görev (USER-ONLY) |
| `scripts/ekip-self-recognition.sh` | SessionStart hook: tmux-oturum→registry ters-lookup→kimlik enjekte (clear/compact-proof; eşleşme-yoksa sessiz) |
| `_agents/handoff/EKIP-settings-hook-snippet.json` | self-recognition wire-snippet'i (settings.json'a merge-instructions) |
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
- **Çıktı = JSON `hookSpecificOutput.additionalContext`** (plain-stdout değil) → kanıtlı-güvenli desen (cortex-session-start emsali). Üye-kimliği **override-direktifi** taşır: bir genel-bootstrap default-persona bassa da "çalışma-kimliğin = <ID>, onu genel-altyapı say" → üye-eşleşmesi default'u ÖNCELER. Ek: ilk-yanıtta `🧑‍🚀 <ID> geri-yüklendi` tek-satır-marker (compact-orkestra handshake'i).
- **Wire:** `EKIP-settings-hook-snippet.json` → `.claude/settings.json` `hooks.SessionStart`. ⚠️ **matcher REGEX DEĞİL, exact-string** → `"*"` kullan (TÜM source'lar: startup|resume|clear|compact; `resume`=post-auto-compact kimlik-kurtarma). `"startup|clear|compact"` alternation ÇALIŞMAZ (hiç ateşlemez) — kaynak: claude-code-guide 2026-07-06.
- ⚠️ **MERGE-vs-OVERRIDE ön-testi:** mevcut bir global-bootstrap-hook (cortex-session-start) VARSA, ayrı-entry eklemeden önce test et — farklı settings-dosyalarındaki SessionStart-hook'lar **MERGE** mi (ikisi de ateşler) **OVERRIDE** mı (proje globali ezer) docs'ta muğlak. MERGE ise ayrı-entry temiz (çoklu additionalContext birleşir). OVERRIDE ise ayrı-entry global'i öldürür → self-recognition'ı global-hook İÇİNE guarded-blok göm (rakip-entry açma). Test: proje-hook ekle → `/clear` → debug-log'da HER İKİSİ ateşledi mi.
- **Test:** `bash scripts/ekip-self-recognition.sh <oturum-adı>` (override) veya gerçek tmux-oturumunda argümansız.

## READ-BEFORE-TRIGGER (ön-uçuş · `ekip-notify.sh` baked-in)
Bir üyeyi **boştayken** tetikle. Kör-tetik (busy/menü/compact-önerisi olan üyeyi ping'leme) bir compact-önerisini ezip iş kaybettirebilir. `ekip-notify.sh` send-keys'ten ÖNCE hedef-pane'i `capture-pane | tail` ile sınıflandırır:
- `idle` → NORMAL GÖNDER · `busy` ("esc to interrupt"/Compacting) · `menu` ("❯ 1."/"Do you want") · `compact` (footer "auto-compact"/"compact yap") → **DUR + stderr-uyar + say(engellendi)** → çağıran karar-versin.
- **`--force`** ön-uçuşu bypass eder. Belirsiz-durum → idle (araç kullanışlı-kalır; C-u+3-adım düşük-zarar).
- ⚠️ **Marker'lar TUNABLE + LIVE-KALİBRE:** `BUSY_RE`/`MENU_RE`/`COMPACT_RE` (env-override) hedef-TUI-string'lerine göre bir kez kalibre edilir. `ekip-compact.sh` AYNI marker'ları taşır — **birini kalibre edince diğerini de senkronla** (drift-riski).

## COMPACT-ORKESTRA (`ekip-compact.sh`)
`ekip-compact.sh <üye> ["devam-mesajı"]` — compact-gerektiğinde/üye-önerince **uzaktan uçtan-uca**: tetikle → kimliği-korunmuş-bekle → devam-ettir.
1. **Ön-uçuş:** busy/menü → DUR (mid-work compact YAPMA). compact-önerisi/idle → GO.
2. `/compact` gönder (3-adım-Enter fix).
3. **Settle bekle:** "Compacting" görünüp kaybolsun (dürüst-timeout).
4. **devam** gönder → **re-bootstrap-marker** (`🧑‍🚀 <ID> geri-yüklendi` / bootstrap) belirene dek poll → görülürse ✅, timeout ise **"tetiklendi ama re-bootstrap DOĞRULANAMADI"** (başarı-İDDİA ETMEZ = dürüst-degrade). devam-mesajı verilmezse KONUM-devri-varsayılanı.

## ⚠️ BAĞIMLILIK-SIRASI (KURULUM 1→2→3)
Üç yetenek aynı-kökün (kör-uyanma/kör-tetikleme) parçaları; sırayla canlanır:
1. **SELF-RECOGNITION canlı** (hook wire + doğrulandı) — compact/clear sonrası kimliği kuran budur.
2. **READ-BEFORE-TRIGGER canlı** (ekip-notify ön-uçuş kalibre) — busy-üyeyi ezmeyi önler.
3. **COMPACT-ORKESTRA** (ekip-compact) — adım-4'ü PARÇA-1'e bağlı: self-recognition canlı-DEĞİLSE re-bootstrap doğrulanamaz → araç "compact + kör-devam"a çöker. **PARÇA-1 canlı olmadan PARÇA-3 tam-çalışmaz.**

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

### 6. Self-recognition hook'u wire et
`_agents/handoff/EKIP-settings-hook-snippet.json` → `.claude/settings.json` `hooks.SessionStart`'a MERGE (matcher `startup|clear|compact`; mevcut hook'ları SİLME — cortex-session-start vb. korunur = tamamlayıcı).

### 7. Go-live / duman-testi
`EKIP-GO-LIVE-CHECKLIST.md`'i Sultan'a sun. Duman-testi (3-adım-Enter + self-recognition) tmux gerektirir →
oturumların açık olduğu ortamda, Sultan-eşli. **"Kuruldu" ≠ "canlı"** — checklist yeşillenene dek canlı deme (Engel-Doğrulama disiplini).

## İZOLASYON NOTU (izole-konteyner hedefleri, ör. cloudtop-mmex)
Dosyalar bu (kaynak) konteynerinden yazılabilir AMA **canlı tmux-tetik hedef-konteyner-içinde** çalışır.
Dosya-yazımının hedef-konteynere propagasyonu mount/senkron-topolojisine bağlı → **VARSAYMA**, `ls` ile teyit et.
Duman-testi = hedef-oturumların yaşadığı konteynerde.

## Doktrin bağları
- **Altın Kural (Sx-Claude-Skills):** bu skill'in KENDİSİ geliştirilince kaynak burada (Sx-Claude-Skills) güncellenir,
  `version` artırılır, `node sync-skills.mjs --apply` ile dağıtılır. (Üretilen substrat proje-lokaldir, sync'lenmez.)
- **Non-destructive scaffold:** mevcut canlı-koordinasyon-sistemini `--force`'suz ASLA ezme.
- **Dürüstlük:** "kuruldu" demek "canlı" demek değil — go-live checklist kanıtlanmadan canlı deme.
- **Sır-hijyeni:** registry'ye/brief'e sır-değer ASLA; yalnız tmux-hedef/rol/kanal.
