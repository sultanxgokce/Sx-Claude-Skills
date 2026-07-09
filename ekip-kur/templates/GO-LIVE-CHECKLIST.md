# EKİP KOORDİNASYON — GO-LIVE / DUMAN-TESTİ CHECKLIST

> ekip-kur scaffold'u dosyaları yazdı. Sistem **canlı** sayılmadan önce bu adımlar KANITLI ✅ olmalı.
> Duman-testi tmux-tetik gerektirir → **hedef-ortamın kendisinde** (izole-konteynerse o konteynerde) koşulur.

## 1. Roster doğru mu?
- [ ] `_agents/handoff/ekip-registry.yaml` gerçek üyelerle dolduruldu (örnek UYE1/UYE2 silindi).
- [ ] **Her `tmux:` hedefi `tmux ls` çıktısıyla firsthand-teyit edildi** (CASING duyarlı! yanlış-casing = sessiz ping-kaybı).
- [ ] `meta.uye_sayisi` gerçek sayıyla güncel.

## 2. Parse çalışıyor mu? (salt-okur, güvenli)
- [ ] `bash scripts/ekip-notify.sh 2>&1 | head -5` → usage basıyor (arg-yok → exit 2).
- [ ] Registry parse boş-değil: `python3 -c "…"` yerine basitçe `bash scripts/ekip-notify.sh BILINMEYEN_ID x` → "bilinmeyen ajan … registry-id kullan (<DİNAMİK-LİSTE>)" hatası + dinamik id-liste görünüyor mu?

## 3. Duman-testi — 3-adım-Enter fix'i (≥2 tmux-oturum, hedef-ortamda)
- [ ] En az 2 üye-oturumu açık (registry id'leriyle eşleşen tmux oturum-adları).
- [ ] Bir oturumdan: `bash scripts/ekip-notify.sh <diğer-üye-id> "duman-testi 1"`.
- [ ] **KRİTİK gözlem:** diğer oturumda mesaj composer'a düşüp **otomatik SUBMIT oldu** mu? (Gömülü-Enter regresyonu olsaydı düşer ama gönderilmezdi.)
- [ ] `all` testi: `bash scripts/ekip-notify.sh all "duman-testi 2"` → `ozet: gonderildi=N atlandi_self=1 eksik_oturum=M` mantıklı mı? (çağıran-oturum self-atlandı mı?)
- [ ] Kapalı-oturum dürüstlüğü: olmayan üye için `eksik_oturum` say + exit 1 doğru mu?

## 4. Tetik-skilleri
- [ ] `/ekip-brief-ver`, `/ekip-brief-iste`, `/ajan-gorev`, `/durum` `.claude/skills/` altında görünüyor (USER-ONLY — `disable-model-invocation: true`).
- [ ] `/ekip-brief-ver "test brief"` → `ekip-brief.md`'ye BRİF-bloğu düştü + ping gitti.

## 4b. İKİ-YÖN DÖNGÜ — sinyal-defteri + --done/--waiting + --nudge (≥2 tmux-oturum)
Klasik ping tek-yönlü (yönetici→üye). Bu döngü PULL→PUSH'u kapatır: üye→yönetici sinyal + yönetici Stop-hook nudge.
- [ ] **meta.yonetici doğru mu:** `ekip-registry.yaml` `meta.yonetici` gerçek yönetici-id (üyelerden biri). Boşsa scriptler
      İLK-üyeyi varsayar + stderr uyarı basar (test et: geçici sil → `ekip-durum.sh` çalıştır → "⚠️ meta.yonetici tanımsız → ilk-üye … varsayıldı" gördün mü?).
- [ ] **--done akışı:** bir üye-oturumdan `bash scripts/ekip-notify.sh --done "duman: iş bitti"` → `ekip-sinyal.log`'a
      satır düştü mü (`grep done _agents/handoff/ekip-sinyal.log`) + yöneticiye ping gitti mi? (yönetici meşgulse exit 3 = sinyal-defterde, normal.)
- [ ] **--waiting akışı:** `bash scripts/ekip-notify.sh --waiting "duman: yön bekliyorum"` → sinyal-defterine `waiting` satırı.
- [ ] **radar:** yönetici-oturumdan `bash scripts/ekip-durum.sh` → bekleyen üye ⏳ BEKLİYOR bölümünde neden+son-KONUM ile görünüyor mu?
- [ ] **--ack:** yönetici `bash scripts/ekip-notify.sh --ack <SID>` → sonraki `ekip-durum.sh`'de o sinyal düştü mü (ACK'sız-sayı azaldı)?
- [ ] **--nudge (Stop-hook):** yönetici-oturumda Stop-hook devrede + bekleyen sinyal varsa turu bitirince "📟 N bekleyen ekip-sinyali" additionalContext bastı mı? (üye-oturumda yumuşak-kapı-backstop çalışır.)

## 4c. DURUM-SKİLL duman-testi (Sultan-dili)
- [ ] `bash scripts/ekip-durum.sh --porcelain` → her satır 6-alan TAB (`ID⇥oturum⇥sınıf⇥sinyal⇥neden⇥son-KONUM`) + son satır `#OZET⇥calisan=…`. Ham `idle`/emoji SIZMIYOR (sınıf: calisir/serbest/bekliyor/…).
- [ ] `/durum` → Sultan-dili 3-bölüm (çalışanlar · boşta · seni-bekliyorlar) + tek-cümle özet. Jargon/SID/hash/dosya-yolu Sultan'a GÖRÜNMÜYOR.

## 4d. CONTEXT-NUDGE eşik-doktrini (`ekip-hooks/ctx-nudge.sh`)
- [ ] PostToolUse-hook wire edildi (matcher `"*"`). ERKEN-tier (~%65-80) BLOKE-SORU AÇMAZ (yalnız anchor-yaz+devam) — koordinasyon-akışını bölmez.
- [ ] DANGER-tier (≥%80) yalnız TEMİZ faz-sınırında compact-önerir. Pencere TAHMİNDİR → nudge `/context ile doğrula` der.
- [ ] **Öz-servis-compact KABLOLU:** scaffold `scripts/ekip-selfcompact.sh`'i yazar → ctx-nudge onu tespit edip `EKIP_SELFCOMPACT_PATH` set eder → DANGER-mesajı jenerik "/compact öner" yerine `bash scripts/ekip-selfcompact.sh --self` önerir (aşağıda 4e canlı-test).

## 4e. ÖZ-SERVİS COMPACT canlı-testi (`ekip-selfcompact.sh` — detached-watcher deseni)
Ajan yüksek-context'te AskUserQuestion-EVET'te KENDİNİ compact + kimlik-korunmuş re-bootstrap. PAZARLIKSIZ: literal
`/compact` (asla `/clear`) · DURABLE-WRITE-FIRST (anchor önce diske). Test hedef-ortamda ≥1 açık tmux-üye-oturumu ister.
- [ ] **Statik:** `bash -n scripts/ekip-selfcompact.sh scripts/ekip-selfcompact-watcher.sh scripts/ekip-compact-core.lib.sh` → 0 hata; üçü de exec-bit'li (`ls -l`).
- [ ] **Ön-koşul:** hedef-ortamda `command -v tmux python3 setsid` üçü de var (yoksa script dürüst-HATA basar, sessiz-geçmez).
- [ ] **Resolve-self:** bir üye-oturumundan `bash scripts/ekip-selfcompact.sh --self` → registry'den kendi MID/TARGET'ını çözüp "watcher spawn edildi (<MID> · <TARGET>)" bastı mı? (ekip-dışı oturumda jenerik-fallback: `marker=geri-yüklendi`.)
- [ ] **Canlı akış (temiz faz-sınırında):** ajan `--self` koşup **turu DERHAL bitirir** → pane idle → watcher taze `/compact` yollar → settle → devam-nonce → **re-bootstrap marker** (`🧑‍🚀 <MID> geri-yüklendi`) görülür mü? Sonuç `grep SELFCOMPACT _agents/handoff/ekip-sinyal.log` → `OK compact+rebootstrap-dogrulandi`.
- [ ] **Dürüstlük:** marker VERIFY_TIMEOUT'ta görülmezse sinyal-defterinde `UNVERIFIED rc=…` (başarı İDDİA edilmez); `/clear` HİÇBİR yerde gönderilmedi (yalnız literal `/compact`).

## 4f. EKİBİ-TAZELE duman-testi (`ekip-tazele.sh` — tek-komut bakım)
- [ ] **Statik:** `bash -n scripts/ekip-reconcile.sh scripts/ekip-context-scan.sh scripts/ekip-tazele.sh` → 0 hata; üçü de exec-bit'li.
- [ ] **Salt-CLI çalışır mı:** `bash scripts/ekip-tazele.sh --dry-run` → hata vermeden 3 bölüm (`[A]`/`[B]`/`[C+D]`) + `SUMMARY` satırı bastı mı?
- [ ] **Reconcile GÜVENLİ-fix uygulanıyor mu:** kasıtlı bir tmux-casing hatası (registry'de `tmux: "yanlisAd:0"` yaz, gerçek oturum farklı-casing'de açık) → `bash scripts/ekip-tazele.sh` (dry-run'sız) → registry'de `tmux:` alanı otomatik düzeldi mi (`FIX tmux-self-heal` satırı)?
- [ ] **Riskli-olan otomatik-YAPILMIYOR mu:** context-ağır bir üye varsa (`HEAVY` satırı) script kendisi hiçbir tmux-pane'e mesaj GÖNDERMEDİ mi (yalnız rapor)? Compact-önerisi/ping SADECE `/ekibi-tazele` skill-akışında Sultan-onaylı.
- [ ] **`/ekibi-tazele`** çağrısı Sultan-dili özet bastı mı (jargon/hash/dosya-yolu sızmadı) — boş-durumda "ekip tertemiz" dedi mi?

## 4g. COMPACT-ORKESTRA — `ekip-compact.sh` (yönetici→üye UZAKTAN compact)
Yönetici bir üyeyi uzaktan compact+re-bootstrap eder (öz-servis'in uzaktan-kardeşi; `ekip-compact-core.lib` REUSE).
- [ ] **Statik:** `bash -n scripts/ekip-compact.sh` → 0 hata; exec-bit'li.
- [ ] **Usage/guard:** `bash scripts/ekip-compact.sh` (arg-yok) → usage exit 2. `bash scripts/ekip-compact.sh BILINMEYEN` → "bilinmeyen üye … registry-id kullan" exit 1.
- [ ] **self-loop guard:** çağıran-oturumdan KENDİ id'sini compact'lemeye çalış → "kendini-compact bu araçla yapılmaz (öz-servis … ayrı-yol)" exit 1.
- [ ] **Canlı akış (≥1 diğer-üye açık, temiz faz-sınırında):** `bash scripts/ekip-compact.sh <diğer-üye>` → preflight idle/compact GO → `/compact` → settle → devam → **re-bootstrap marker** (`🧑‍🚀 <ID> geri-yüklendi`) → exit 0. busy/menu üyede: "ENGEL: … mid-work compact'lemem" exit 1 (--force ile aşılır).
- [ ] **Dürüstlük:** marker VERIFY_TIMEOUT'ta görülmezse exit 5 (başarı İDDİA edilmez); compaction takılırsa exit 6. `/clear` HİÇ gönderilmez (yalnız literal `/compact`).

## 5. İZOLE-KONTEYNER NOTU (varsa)
- [ ] Dosyalar **başka bir konteynerden** yazıldıysa: bu dosyalar hedef-konteynerde görünüyor mu? (mount/senkron topolojisi — VARSAYMA, `ls` ile teyit et).
- [ ] Canlı tmux-tetik yalnız **oturumların açık olduğu konteynerde** çalışır → duman-testi ORADA.

## 5b. PR-YETKİ (otonom PR+merge — opsiyonel ama önerilen)
Üyelerin "tamam" sonrası KENDİ PR açıp merge'lemesi için (Sultan'a sıfır-komut). İki-kapı: pr-gate hook (marker)
+ permission-classifier (bypassPermissions temizler; auto-mode `gh pr merge`'ü sert-durdurur, allow-rule YETMEZ).
- [ ] **Ortam uygun mu:** izole/sandbox container · **non-root** (`id` → uid≠0) · internet-kısıtlı · yedekli.
      (bypassPermissions yalnız böyle ortamda güvenli; **root'ta ÇALIŞMAZ** — Anthropic güvenlik-kilidi.)
- [ ] **Default'u ayarla:** hedef-container'ın `~/.claude/settings.json` → `permissions.defaultMode: "bypassPermissions"`
      (+ `skipDangerousModePermissionPrompt: true` → seans-başı uyarı-atlar). ⚠️ **Her container'a AYRI** uygulanır
      (izole-config; bir container'daki değişiklik diğerine geçmez). Git-tracked settings'e KOYMA (klon'a sızar).
- [ ] **Açık seanslar restart:** mid-session çevrilemez (Shift+Tab bypass'ı döngüye almaz) → `claude --resume <id>`
      (paylaşılan-cwd'de `--continue` DEĞİL — yanlış-üye çeker). tmux `cc-<uuid8>` adı = session-id prefix'i.
- [ ] **Korumalar duruyor mu:** bypass'ta `deny`/`ask`-kuralları + PreToolUse-hook'lar + `rm -rf` root/home
      circuit-breaker yine ateşler. Felaket-ops için küçük `deny`-listesi öner (main-force-push, prod-DB-drop).
- [ ] **DERS içselleştirildi mi:** bayat "classifier-bloklar/no-retry" hafızası **≠ engel-kanıtı** → yeni-modda
      taze-probe et; "no class-retry" yalnız gizli-bypass'a uygulanır, Sultan'ın açık mod-değişimine değil.

## 6. Kapanış
- [ ] Yukarıdakiler yeşil → sistem canlı. Değilse kırmızı-maddeyi raporla (sessiz-geçme yok).
