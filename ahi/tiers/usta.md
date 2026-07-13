# Kademe-Kartı — USTA (S3 · Bileşik Paketli)

> generic-goal: **"standarttan-türetilmiş bileşik iş-sistemi"** (CMMI GG3 Defined). Birkaç skill birleşip çalışma-prensibi.

| # Boyut | Tanım |
|---|---|
| 1 **nedir** | Tek skill'in yapamayacağı geniş iş; birkaç Kalfa-skill'i **besteleyen** bileşik iş-sistemi (ör. sert-dongu = kesif × sert-teslim). |
| 2 **nerede-yaşar** | `Sx-Claude-Skills/<ad>/` — kardeş-skilleri `.claude/skills/<kardeş>` yolundan çözer (vendoring-YOK). |
| 3 **üretim-reçetesi** | `ahi new usta <ad>` → SKILL.md + scripts/ + manifest (`requires[]` + `layers[]`/`consumable_surface[]` opsiyonel). **Born-at-tier:** doğum-anında Çırak+Kalfa checklist'leri de yeşil-geçer (tertipli-progresyon). |
| 4 **isim+dosya-yapı** | `<ad>/` çekirdek; bileşenler `requires[]` ile deklare-edilir (deklare-et-VE-doğrula). |
| 5 **on/off** | Kalfa + **kompozisyon-kısıtı:** bileşenler co-present olmalı; `ahi check` `requires[]` co-install doğrular. |
| 6 **test/doğrulama** | Kalfa + kompozisyon-testi: `requires[]` çözülüyor mu (deterministik). |
| 7 **dağıtım** | Kalfa ile aynı; AMA co-install ZORUNLU (tesadüfî değil — `requires[]` + drift-lint). |
| 8 **yaşam-döngüsü** | semver; emeklilik bileşen-bağımlılığını dikkate alır (bağımlı-bilgilendir). |
| 9 **terfi (→Pîr)** | Eklenecek eksen: **kendi-repo + CI + kendini-besleyen-döngü**. Checklist: remote-repo? · CI? · runtime-telemetri→gelişme-döngüsü? |

**Usta→Pîr terfi-sinyali (mezuniyet):** bileşik sürekli-büyüyen, kendi-repolu, kendini-geliştiren YAŞAYAN sisteme dönüşüyor.
**KRİTİK gap-kapatma (endüstri):** `requires[]` bağımlılık-deklarasyonu ZORUNLU (bugün tesadüfî-co-install sessizce-kırılabilir); `type:composite` işareti V2.
