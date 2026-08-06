---
name: worktree-hijyen
type: agent
version: 0.2.0
description: >
  git-worktree yaşam-döngüsünü zorlayan paketli yardımcı: dallanma/fan-out öncesi tazelik-kapısı,
  taze-off-origin/main worktree açma, kapanışta güvenli temizlik ve bayat-worktree/artık-artefakt
  denetimi. En pahalı tekil-hata sınıfını (bayat-base üstüne dallanma → split-brain, ölü-PR,
  duplicate-roster) önler. AYRICA ortak-index tuzağını yazar: aynı ağacı paylaşan iki ajanda
  hazırlık alanı da ortaktır, ötekinin `git add`'i senin commit'ine biner (huzur'da 15 dosya
  ana dala böyle indi) → paylaşılan ağaçta `git commit -- <yollar>`. Tetik: yeni dal/worktree
  açmadan önce, pahalı fan-out öncesi, "N-behind" şüphesi doğunca, worktree'leri toparlarken,
  ya da bir ağacı başka bir koltukla paylaşırken.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [worktree, git, hijyen, preflight, fan-out, split-brain]
status: v0.2
---

# worktree-hijyen — (Kalfa · paketli skill)

**NE-DİR:** git-worktree yaşam-döngüsünü **taze-aç → kullan → temiz-kapat** disiplinine bağlayan yardımcı.
Ölçülen en pahalı tekil-hata (mihenk split-brain → duplicate-roster, saatler; aynı gün 2× bayat-worktree
tuzağı) tam bu döngünün gevşemesinden doğuyor. Skill, mevcut `scripts/branch-preflight.sh` kapısını sarar
(yoksa taşınabilir eşdeğerini koşar) ve worktree aç/kapat/denetle mekaniğini güvenli hale getirir.

## Kullanım

```bash
# 1) Dallanma / pahalı fan-out (Workflow, çoklu-subagent) ÖNCESİ tazelik-kapısı
worktree-hijyen preflight               # base=origin/main; exit 0 = taze+temiz → serbest

# 2) TAZE base'den yeni worktree aç (bayat-base = split-brain reddi)
worktree-hijyen ac feat-yeni-is         # origin/main'i fetch'ler, ../_wt/feat-yeni-is açar

# 3) İş bitince güvenli kapat (DRY-varsayılan)
worktree-hijyen kapat /config/projects/_wt/feat-yeni-is          # ne yapılacağını basar (kirli/merge-durumu)
worktree-hijyen kapat /config/projects/_wt/feat-yeni-is --apply  # temizse kaldırır

# 4) Tüm worktree'leri + bayat-branch + artık-artefakt tara (SALT-OKU)
worktree-hijyen denetle
```

**Tipik refleks:**
- Motor-kartına başlamadan: `worktree-hijyen ac <dal>` → daima taze origin/main'den.
- Damga-push sonrası: `worktree-hijyen kapat <yol> --apply` → worktree + artık-kopya birikmez.
- Oturum-toparlama: `worktree-hijyen denetle` → bayat/kirli/öksüz worktree'leri tek-bakışta gör.

## 🔴 ORTAK INDEX TUZAĞI — aynı ağacı paylaşan koltuklar (huzur, 2026-08-06)

Bu skill bugüne kadar **bayat-base**'i anlatıyordu; asıl kanayan yer başkasıymış. Aynı git ağacında
iki ajan çalışıyorsa **hazırlık alanı (index) da ORTAKTIR.** Yani öteki ajanın `git add` ile
sıraya koyduğu dosyalar senin `git commit`'ine sessizce biner.

**Canlı vaka (huzur):** bir ajan üç belgeyi `git add` edip commit'ledi; ötekinin hazırladığı
**15 dosya** da o commit'e girdi ve ana dala indi. Kod doğruydu, testler yeşildi, veri kaybı
olmadı — bozulan **kayıt düzeniydi**: kod, kendi kanıt listesi okunmadan birleşti ve öteki
öneri artık birleştirilemez hâle geldiği için kapatıldı.
**Aynı gün merkezde de yakalandı:** başka bir ajanın kaydedilmemiş dosyaları neredeyse
commit'e girecekti; `git reset` ile dönüldü.

**Kural — paylaşılan ağaçta commit'lerken:**
```bash
git commit -- <yollar>          # ✅ YALNIZ senin dosyaların; index'te ne varsa umursamaz
git add . && git commit         # ⛔ ötekinin sıraya koyduğu her şeyi de alır
git commit -a                   # ⛔ aynı tuzak
```
Commit'ten önce **daima** `git status --porcelain` oku: tanımadığın dosya varsa o senin değildir.

**Asıl çözüm koltuk başına ayrı ağaçtır** (`worktree-hijyen ac <dal>`) — yukarıdaki kural, ağaç
ayrılana kadar geçerli olan emniyet kemeridir, ağaç ayrımının yerine geçmez.

## Filo geneli toplama — bu skill'in işi DEĞİL

`kapat`/`denetle` **tek ağaç** ve **elle** çalışır. Terk edilmiş ağaçların filo genelinde ve
kendiliğinden toplanması ayrı bir araçtır: `Nexus/scripts/agac-hijyeni.sh` (haftalık cron;
canlı-oturum · kaydedilmemiş iş · açık PR · sahipsiz ağaç korumaları fail-closed).
İkisi çakışmaz: burası **elle yaşam-döngüsü**, orası **gözetimsiz süpürme**. Süpürme kuralını
buraya kopyalama — tek güncelleme noktası orasıdır.

## Değişmezler (güvenlik)
- **Taze-off-origin/main:** `ac` her worktree'yi fetch'lenmiş base'den açar; bayat/çözümlenemeyen base = red.
- **DRY-varsayılan:** `kapat` (--apply'sız) ve `denetle` hiçbir yıkıcı-işlem yapmaz.
- **Veri-koruma:** kirli ya da merge-edilmemiş worktree `--force` olmadan SİLİNMEZ; net-uyarıyla durur.
- **Yeniden-icat yok:** tazelik-kapısı `scripts/branch-preflight.sh`'e devredilir (varsa); yoksa taşınabilir eşdeğer.

## Kademe
Kalfa (S2 · paketli). generic-goal: "planlı + paketli + her-projede güvenilir tekrarlanabilir".
Manifest: `ahi.manifest.yaml` · Doğrula: `ahi check worktree-hijyen` · Kanon: `ahi doctrine`.
Kaynak: Vizyon-denetimi FAZ-2 İLK-DALGA (Z8, YK-007); defter-kartı k0109.
