# 1 · İZOLE — iş kendi alanında yapılır

**Kural:** ana dalda asla çalışma; başkasının alanına, dalına, kayıtsız işine asla dokunma. Her iş, `origin/main`'den
o an açılan **taze** bir worktree'de başlar.

**Neden yapı, neden dikkat değil:** paylaşılan ağaçta dal global bir durumdur. Sen dal açıp çalışırken başka bir ajan
`checkout` derse commit'lerin onun dalına düşer. cloudtop'ta 4 Ağustos'ta aynı gün üç kez oldu; biri 16 dosyayla
başkasının PR'ına karıştı ve ancak elle fark edildi. "Ajan dosyamı sildi" şikâyetlerinin çoğu da bu sınıftır: suç
ajanın değil, çalışma biçiminin.

## Komut
```bash
F=/config/.claude/skills/yazilim-fabrikasi/scripts/is-alani.sh
bash $F ac <iş-adı>        # origin/main'den taze alan: /config/projects/_wt/<depo>-<iş-adı>, dal <iş-adı>
cd /config/projects/_wt/<depo>-<iş-adı>
bash $F kontrol            # güvenli / riskli / ölçülemedi
bash $F kapat <iş-adı>     # merge sonrası; kayıtsız iş varsa SİLMEZ
```

## `ac` ne yapar (sırayla; biri düşerse açmaz)
1. `git fetch origin` — düşerse durur ("taze" garanti edilemez).
2. **Kapsam kontrolü:** `gh` varsa açık PR'ların dosya listesine bakar. Senin işinin dokunacağı dosya
   (`--dosyalar a,b,c` ile söylersin) bir PR'da zaten değişiyorsa **rc=2, durur ve sorar**. `gh` yoksa
   "kapsam kontrolü yapılamadı" der, açar — sessizce atlamaz.
3. Dal adı çakışıyorsa yeni ad ister; asla zorla üstüne yazmaz, asla başkasınınkini kullanmaz.
4. Worktree'yi **depo dışında** açar (`/config/projects/_wt/`, kalıcı disk; `/tmp` konteyner yeniden
   başlayınca silinir — kayıtsız iş orada kaybolur).
5. Paylaşılan-kaynak uyarısını basar (aşağıda).

## Worktree neyi izole ETMEZ
- **Port:** iki alan aynı geliştirme sunucusunu açamaz; port cevap veriyorsa **senin** süreç mi diye bak (`lsof -i :<port>`).
- **Veritabanı:** şema denemesi paylaşılan DB'ye yapılmaz.
- **Kilit dosyası** (`package-lock`, `pnpm-lock`): çakışırsa elle birleştirme yok, yeniden üret.
- **Bağımlılıklar:** `node_modules` paylaşılmaz; alanda yeniden kur, çalışma-zamanı sürümünü doğrula.

## Çıkış kapısı
`kapat`, alanda kayıtsız değişiklik varsa reddeder. İşi kaybetme: commit'le ya da bilinçli sil. Squash-merge sonrası
`git branch -d` reddedebilir; `-D` beklenen davranıştır (iş merge olmuştur).

## Zorlama (kapı mı, tavsiye mi — dürüst)
- Paylaşılan ağaçta özellik dalına **commit**: `pre-commit` kancası engeller (`fabrika-kur.sh kur --kanca`). Sınavlı.
- Ana dalda **dosya düzenleme**: F0'da tavsiye, kapı değil. F4'te filo kancası (ayrı Sultan onayı).
