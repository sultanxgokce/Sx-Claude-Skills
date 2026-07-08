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
- [ ] **Öz-servis-compact opsiyonel:** `scripts/ekip-selfcompact.sh` bu pakette YOK → DANGER-mesajı jenerik "/compact öner" fallback'i basar. selfcompact sonradan eklenirse hook otomatik onu önerir (kod-değişikliği gerekmez).

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
