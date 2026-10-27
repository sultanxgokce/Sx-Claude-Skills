---
name: oda-kur
description: Kutu–oda modeli aracı — bir kutunun (tek depo) içinde amacı ayrı odalar kurar. Oda klasörü iskeleti (master prompt CLAUDE.md, oda.json hedef+reis+ölçü, hafiza/, .claude/skills+agents), kutu ortak ayarından HER odanın .claude/settings.json'unu üretir (izin, ayrı autoMemoryDirectory, yazma kancası), doğrular ve kod yazımını oda klasörüne, ortak veri yazımını çekirdeğin komutuna sınırlayan PreToolUse kancasını sağlar. Tetik "oda kur", "yeni oda", "odalara ayar üret", "oda doğrula", "oda kancası".
version: 0.2.0
---

# oda-kur — kutu–oda modeli: iskelet, ayar üretimi, yazma kancası

Karar: Nexus `_agents/handoff/kutu-oda-kararlari-20261027.md` (karar 9). Görev: Oda modeli 4 (gorev_01M5YHE18D38W4AHJM65VPXA9W).

## Ölçülenler (claude 2.1.311, sahte iki odalı depo)
- Ajan oda klasöründe açılınca kök `CLAUDE.md` + kendi odanın `CLAUDE.md`'si yüklenir; **kardeş odanınki yüklenmez** (iki yönde: A'da B yok, B'de A yok; pozitif kontrol geçti). Sınır: bu hüküm modelin kendi bağlamından tek yüzeydir (hata ayıklama günlüğü ve akış çıktısı yönerge metnini göstermez).
- `autoMemoryDirectory` oda klasöründeki `.claude/settings.json`'dan gerçekten uygulanır (oda başına ayrı hafıza).
- `.claude/settings.json` **yalnız cwd'den** okunur: kökteki `autoMemoryDirectory` oda cwd'sine İNMEDİ. Bu yüzden her odanın ayarı ortak kaynaktan ÜRETİLİR.
- Üretilen ayardaki kanca gerçek Claude Code'da çalıştı: kendi odaya yazma geçti, kardeş odaya ve ortak veriye yazma durduruldu (Write aracı).

## Depo düzeni
```
<depo>/.claude/oda-ortak.json     ortak kaynak: izin{allow,deny} · ortak_veri[globlar] · cekirdek_komutlar[komut önekleri]
<depo>/<oda>/CLAUDE.md            odanın master promptu (reis düzenler)
<depo>/<oda>/oda.json             ad · reis (kalıcı koltuk) · hedef · olcu · ek_yazma[globlar]
<depo>/<oda>/hafiza/              odanın hafızası (autoMemoryDirectory buraya bakar)
<depo>/<oda>/.claude/settings.json   ÜRETİLİR — elle düzenleme
<depo>/<oda>/.claude/settings.oda.json   oda-özel ayar (izinler ortakla birleşir; hooks ve autoMemoryDirectory yazılamaz)
<depo>/<oda>/.claude/{skills,agents}/
```

## Komutlar (`bash /config/.claude/skills/oda-kur/scripts/oda.sh …`)
- `yeni <depo> <oda> --reis K --hedef "…" --olcu "…"` — iskelet + ayar üretimi. Üçü de zorunlu (oda = hedef + reis + ölçü). Ortak ayar yoksa boş varsayılan yazar.
- `uret <depo>` — ortak ayardan her odanın settings.json'unu üretir; idempotent (ikinci koşu "aynı").
- `dogrula <depo>` — iskeletin tamamı (CLAUDE.md, oda.json, hafiza/MEMORY.md, .claude/skills+agents), üretilmiş ayarın tazeliği (elle düzenleme/bayat → rc 1), hafıza ayrılığı. Hiç oda yoksa rc 3 ÖLÇÜLEMEDİ.
- `yol <depo> <oda>` — açılış cwd'si: odanın mutlak klasörü. Koltuk başlatıcı `cd "$(oda.sh yol …)"` ile açar.
- `kanca <oda_dizini> <ortak_json>` — PreToolUse kancası (üretilen ayar bunu bağlar). stdin JSON; rc 2 = durdur.
- `cekirdek-yaz <depo> <yol> --neden "<tek cümle>" [--siparis gorev_<kimlik>] [--dosya <kaynak>]` — çekirdek ortak dosyaya TEK yazım yolu (Oda modeli 5 D4). İçerik `--dosya` ya da stdin.
  - **Kim** ajanın beyanından değil, `DEFTER_JETON_YOL` dosyasındaki jetonla defterden (`GET /ben` → kutu + ajan) okunur. Yol değişkeni yok / dosya okunamaz / defter yanıt vermez / jetonda ajan kimliği yok → **ret, yazım 0** (varsayılan jetona düşülmez; 27 Eki olayı).
  - **Yalnız kutu deposundan**: `<depo>` oda-ortak.json'u taşıyan git kökü olmalı ve komutu koşturan sürecin cwd'si aynı depoda olmalı; ayrı depodaki oda (kendi git deposu) yazamaz. Yol `ortak_veri` globlarına uymalı, depo dışına (sembolik bağ dahil) çıkamaz.
  - **Kayıt** `<depo>/.claude/cekirdek-kayit.jsonl`: zaman · kim · kutu · dosya · önceki sha (yeni dosyada boş) · sonraki sha · neden · sipariş. `--siparis` yoksa `siparissiz: true` (çekirdek reisinin günlük nabzında ayrı satır). Reddedilen yazım kayıt bırakmaz. Yazım+kayıt tek işlem: kilit altında (eşzamanlı yazanlar sıraya girer, sha zinciri kopmaz), kayıt dosyası önce açılır, kayıt satırı yazılamazsa dosya eski içeriğine döner.
  - Kanca doğrudan yazımı reddederken bu komutu gösterir.

## Kanca kuralları
Write/Edit/MultiEdit/NotebookEdit ve Bash yazımı için (hedef yollar `realpath` ile çözülür → sembolik bağ kaçışı yok):
1. Hedef depo DIŞINDA → bu kancanın işi değil (serbest).
2. `ortak_veri` globlarına uyuyorsa → DURDUR (okuma serbest, yazma yalnız çekirdeğin komutundan). Çekirdek komutu METİN öneki ile değil GERÇEK YOLLA tanınır: tanımdaki dosya-yolu depo köküne göre, komuttaki karşılığı kancanın cwd'sine göre `realpath` edilip eşit olmalı — odanın içinde aynı adlı sahte betik çekirdek sayılmaz. Bu yüzden oda cwd'sinden çekirdek betiği `bash ../scripts/ortak-yaz.sh …` ya da mutlak yolla çağrılır.
3. Odanın kendi klasörü → serbest. `oda.json ek_yazma` globları → serbest (açık, kayıtlı istisna).
4. Depo içi, oda dışı (kardeş oda, depo kökü `.claude/oda-ortak.json`, `.git/`) → DURDUR.
Fail-closed: kanca girdisi bozuksa, ortak ayar ya da `oda.json` okunamazsa DURDURUR (sessizce serbest bırakmaz).

**Dürüst sınır (Bash):** yalnız yönlendirme (`>`, `>>`), `tee`, `sed -i`, `cp/mv/install/ln` hedefleri taranır; zincirde (`;` `&&` `||` `|`) her parça ayrı değerlendirilir; yönlendirme hedefleri çekirdek komutunun parçasında bile taranır; çekirdek komutu zincirin başında olsa da ardındaki yazım durdurulur. Çekirdek betiğin KENDİ içinde ne yazdığı (ya da oda içine konan bir sahte betiğin içi) kancadan görünmez. `$DEĞİŞKEN`/`$(…)` içeren hedef, betik dosyasının içindeki yazım ve `python -c "open(…,'w')"` gibi dolaylı yazımlar GÖRÜNMEZ. Kanca kazayı önler, kasıtlı dolanmayı değil; kesin sınır için ortak veri dosyalarının işletim sistemi izni de kısılmalıdır (ayrı iş).

## Bu sürümde yok (açık)
- Koltuk→oda eşlemesi ve koltuk başlatıcının `oda.sh yol` ile bağlanması: oda alanı kaydı (Oda modeli 1, MUAVİN) gelince bağlanır; `yol` komutu hazır.
- Kurulu kutularda ayarın üretilmesi pilot (TELLAL) ile.

## Sınav
`bash scripts/oda.test.sh` — hermetik sahte iki odalı depo, 69 kapı (26'sı cekirdek-yaz, sahte defter /ben ile) + 29 mutant (ortak veri kuralı kapalı · oda dışı kuralı kapalı · realpath yok · bozuk girdi serbest · ortak ayar yoksa serbest · çekirdek komutu tüm zinciri izinli sayar · çekirdek eşleşmesi yalnız metin öneki · çekirdek parçada yönlendirme taranmaz · kanca komutu alıntısız · ek_yazma her odaya açık · oda-özel parça kancayı ezer · hafıza yolu ortak · uret yazmıyor · uret iskeleti kurmaz · doğrula MEMORY.md bakmaz). claude çağrılmaz.
