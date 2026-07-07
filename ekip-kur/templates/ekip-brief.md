# EKİP-BRİF — ekip ortak yayın-kanalı

> **Append-only · all-read.** Ekibin ortak duyuru-tahtası (ekip-kur master-skill'i scaffold etti).
> **Yazan:** yalnız `/ekip-brief-ver` (yönetici→hepsi) ve `/ajan-gorev` (Sultan→bir) skill'leri — elle-edit drift-kaynağı.
> Kardeş `*-inbox.md`'ler tek-yazar olduğundan brief/görev BURAYA iner (tek-yazar disiplini korunur).
> **Okuyan:** hepsi. Bir üye `ekip-notify` ile ping alınca buraya bakar, kendine-adresli/genel girdiyi okur+gereğini yapar.
>
> Girdi-türleri:
> - `## BRİF · <ts> · → hepsi` — tüm-ekibe duyuru (/ekip-brief-ver).
> - `## GÖREV · <ts> · → <AJAN> · (Sultan-yetkili)` — tek-üyeye görev (/ajan-gorev).
> - `## DURUM-İSTEĞİ · <ts> · → hepsi` — /ekip-brief-iste ping-kaydı (opsiyonel).
>
> Diyet: her girdi kısa-öz + gerekirse madde-detay. Sır-değer ASLA düşmez.
>
> ⏱️ **Tetik-kuralı (tetikleyen okusun):** Üyeyi **boştayken** tetikle. Üye yanıt-ortasındayken gelen ping
> composer'a düşer ama submit için esc-to-interrupt gerekebilir; **otomatik-interrupt/kill YOK** (bilinçli sınır).
> Tetik = "kanalını oku" sinyali; üye ne zaman uygular ASENKRON (senkron-yanıt bekleme, best-effort).
>
> ✅ **İş-bitti kuralı (her üye):** görev bitince/bloklanınca çıktını kanalına yaz+commit'le, SONRA
> `scripts/ekip-notify.sh --done "<tek-satır özet>"` koş (varsa; yoksa yöneticiyi ping'le) — sinyal deftere
> düşer + yönetici uyanır. Özete SIR-DEĞER yazma. Yönetici meşgulse ping düşmeyebilir; defter-kaydı yeter.
>
> 🔀 **PR gerekiyorsa (Sultan-onaylı OTONOM-yetki):**
> **bypassPermissions modundaysan** (alt-bar "bypass permissions on") PR-yetkin TAM: işi Sultan-diliyle özetle
> ("şunu ekledim/değiştirdim, PR açıp merge edeyim mi?") → Sultan **"tamam"** → **KENDİN koş** (Sultan'a ham `gh`
> komutu UZATMA): kalite-gate yeşil (tsc+test) → PR aç (projendeki pr-gate hook'u marker istiyorsa taşı,
> ör. `AGENT_DASHBOARD_PR_SKILL=1`) → CI-yeşil bekle (arka-planda) → squash-merge → kanıt-satırı (kanal + PR-URL).
> ⛔ "classifier bloklar / no class-retry" **bayat-hafızasına GÜVENME** → bypass-modda o engel YOK, **taze-probe et**
> (Sultan'ın açık mod-değişimi ≠ gizli class-retry). ⛔ gate-marker sahteleme / `SKIP_*_GATE` env-set YASAK.
> **bypass-modda DEĞİLSEN** (auto-mode) gh pr classifier'ca bloklanır → Sultan'dan
> `claude --resume <senin-session-id> --dangerously-skip-permissions` relaunch iste (ya da container
> `permissions.defaultMode: "bypassPermissions"` ayarlıysa sadece yeniden-başla), sonra yukarıdaki akış.

<!-- İlk gerçek brief/görev buraya iner (skill'ler append eder). -->
