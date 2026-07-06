---
name: ekip-kur
type: agent
version: 1.1.0
description: >
  Bir projeye çok-ajan KOORDİNASYON-SUBSTRATI kurar: tmux-tetik primitifi (ekip-notify.sh, 4 kritik-fix
  baked-in) + tek-kaynak roster (ekip-registry.yaml) + ortak broadcast kanalı (ekip-brief.md) + 3 USER-ONLY
  tetik-skill (/ekip-brief-ver · /ekip-brief-iste · /ajan-gorev) + go-live duman-testi checklist'i. Roster
  proje-göre parametrik, fix'ler şablonda sabit. Kaynak-desen: Nexus SERDAR-ailesi koordinasyon-sistemi.
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
tags: [koordinasyon, ekip, multi-agent, tmux, orchestration, scaffold, skill-uretici, aile-notify]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# Ekip-Kur — çok-ajan koordinasyon substratı

## Ne işe yarar
Sultan bir projede birden çok Claude'u (ayrı tmux-oturumları) paralel çalıştırıp aralarında
"kanalını oku + gereğini yap" sinyalleri geçirmek istediğinde, bu koordinasyon-sinir-sistemini her
projede elle kurmak angarya. Bu skill onu **bir kez damıtıp** her projeye scaffold'lar:

> `/ekip-kur [hedef-proje]` → roster'ı oku/sor → substratı scaffold'la → registry'yi doldur →
> go-live duman-testi checklist'i sun.

**Kaynak-desen = Nexus SERDAR-ailesi** (`scripts/aile-notify.sh` + `_agents/handoff/aile-registry.yaml`
+ `aile-brief.md` + ekip-brief skilleri). Bu skill onun jenerik (`ekip-*`) kopyasıdır.
**Model-referans = [`erisim-skill-fabrikasi`](../erisim-skill-fabrikasi/SKILL.md)** (scaffold + doldur deseni).

## Üretilen substrat (hedef-projede)
| Dosya | Rol |
|-------|-----|
| `scripts/ekip-notify.sh` | tmux-tetik primitifi (4-fix baked-in; registry'yi python3 ile parse eder) |
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
- **Wire:** `EKIP-settings-hook-snippet.json` → `.claude/settings.json` `hooks.SessionStart` (matcher `startup|clear|compact`).
  Mevcut `cortex-session-start` (genelde `settings.local.json`) **RAKİP DEĞİL** — ayrı entry/dosya, ikisi de ateşler = **tamamlayıcı**.
  Doktrin gereği scaffold canlı-`settings.json`'u OTOMATİK yeniden-yazmaz → snippet'i ajan/Sultan merge eder (mevcut hook'ları silmeden).
- **Test:** `bash scripts/ekip-self-recognition.sh <oturum-adı>` (override) veya gerçek tmux-oturumunda argümansız.

## Akış (`/ekip-kur` çağrılınca)

### 1. Hedef-projeyi belirle
Argüman verildiyse onu al; yoksa çalışılan proje-kökü (`git rev-parse --show-toplevel`). Sultan'a teyit ettir.

### 2. Roster'ı topla (parametrik yüzey)
Hedef-projenin üyelerini çıkar: varsa mevcut ajan-registry'sinden oku (ör. `_agents/orchestration/AGENT_REGISTRY.md`),
yoksa Sultan'a sor. Her üye için: `id` (BÜYÜK) · `tmux` (oturum:0) · `mod ∈ {motor,kod,salt-okur,salt-plan}` · `rol` · `kanallar` · `inbox`.
> ⚠️ **tmux CASING firsthand-teyit ZORUNLU:** `tmux ls` çıktısından her oturum-adını birebir doğrula
> (case-duyarlı; yanlış-casing = sessiz "oturum YOK" ping-kaybı). Oturumlar **başka bir konteynerdeyse**
> (izolasyon), casing'i Sultan o konteynerden verir / go-live orada teyit edilir.

### 3. Substratı scaffold'la
```bash
bash <bu-skill-dizini>/scaffold.sh <hedef-proje-dizini>        # non-destructive (mevcut dosyayı ezmez)
# mevcut bir substratı bilinçli yenilemek için: … <dizin> --force
```
Scaffold sabit dosyaları (notify.sh + brief + 3 skill + checklist) yazar; registry'yi `.tmpl`'den seeder.

### 4. Registry'yi doldur
`_agents/handoff/ekip-registry.yaml`'deki örnek `UYE1/UYE2`'yi SİL, Adım-2'deki gerçek roster'ı yaz.
`meta.ekip`, `meta.uye_sayisi`, `meta.guncelleme` güncelle. **Sır-değer ASLA yazma** (yalnız tmux/rol/kanal).

### 5. Go-live / duman-testi
`_agents/handoff/EKIP-GO-LIVE-CHECKLIST.md`'i Sultan'a sun. Duman-testi (3-adım-Enter kanıtı) tmux-tetik
gerektirir → **oturumların açık olduğu ortamda** koşulur (izole-konteynerse orada, Sultan-eşli).
"Kuruldu" ≠ "canlı" — checklist yeşillenene dek canlı deme (Engel-Doğrulama disiplini).

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
