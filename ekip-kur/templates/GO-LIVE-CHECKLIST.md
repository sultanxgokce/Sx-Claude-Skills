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
- [ ] `/ekip-brief-ver`, `/ekip-brief-iste`, `/ajan-gorev` `.claude/skills/` altında görünüyor (USER-ONLY — `disable-model-invocation: true`).
- [ ] `/ekip-brief-ver "test brief"` → `ekip-brief.md`'ye BRİF-bloğu düştü + ping gitti.

## 5. İZOLE-KONTEYNER NOTU (varsa)
- [ ] Dosyalar **başka bir konteynerden** yazıldıysa: bu dosyalar hedef-konteynerde görünüyor mu? (mount/senkron topolojisi — VARSAYMA, `ls` ile teyit et).
- [ ] Canlı tmux-tetik yalnız **oturumların açık olduğu konteynerde** çalışır → duman-testi ORADA.

## 6. Kapanış
- [ ] Yukarıdakiler yeşil → sistem canlı. Değilse kırmızı-maddeyi raporla (sessiz-geçme yok).
