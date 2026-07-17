---
name: worktree-hijyen
type: agent
version: 0.1.0
description: >
  git-worktree yaşam-döngüsünü zorlayan paketli yardımcı: dallanma/fan-out öncesi tazelik-kapısı,
  taze-off-origin/main worktree açma, kapanışta güvenli temizlik ve bayat-worktree/artık-artefakt
  denetimi. En pahalı tekil-hata sınıfını (bayat-base üstüne dallanma → split-brain, ölü-PR,
  duplicate-roster) önler. Tetik: yeni dal/worktree açmadan önce, pahalı fan-out öncesi, "N-behind"
  şüphesi doğunca, ya da worktree'leri toparlarken.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [worktree, git, hijyen, preflight, fan-out, split-brain]
status: v0.1
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

## Değişmezler (güvenlik)
- **Taze-off-origin/main:** `ac` her worktree'yi fetch'lenmiş base'den açar; bayat/çözümlenemeyen base = red.
- **DRY-varsayılan:** `kapat` (--apply'sız) ve `denetle` hiçbir yıkıcı-işlem yapmaz.
- **Veri-koruma:** kirli ya da merge-edilmemiş worktree `--force` olmadan SİLİNMEZ; net-uyarıyla durur.
- **Yeniden-icat yok:** tazelik-kapısı `scripts/branch-preflight.sh`'e devredilir (varsa); yoksa taşınabilir eşdeğer.

## Kademe
Kalfa (S2 · paketli). generic-goal: "planlı + paketli + her-projede güvenilir tekrarlanabilir".
Manifest: `ahi.manifest.yaml` · Doğrula: `ahi check worktree-hijyen` · Kanon: `ahi doctrine`.
Kaynak: Vizyon-denetimi FAZ-2 İLK-DALGA (Z8, YK-007); defter-kartı k0109.
