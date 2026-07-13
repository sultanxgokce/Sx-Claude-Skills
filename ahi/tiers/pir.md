# Kademe-Kartı — PÎR / LONCA (S4 · Yaşayan Sistem)

> generic-goal: **"ölçülen + kendini-geliştiren yaşayan-sistem"** (CMMI Optimizing). En üst kademe — terfi yok, **mezuniyet** var.

| # Boyut | Tanım |
|---|---|
| 1 **nedir** | Basit iş-akışı değil; bir **çalışma-prensibi** + sürekli-büyüyen, yenilikleri takip-eden, kendini-geliştiren büyük sistem. Örnek: **Lonca**. |
| 2 **nerede-yaşar** | **Kendi-repo** (remote + CI zorunlu). Opsiyonel iki-katman: L1(metod/skill)→`_global`-dağıtım · L2(telemetri)→Cortex-bound. |
| 3 **üretim-reçetesi** | `ahi new pir <ad>` → kendi-repo iskeleti (DOCTRINE/CONTRACT/ROADMAP/ADR + design-nest); deklaratif-spec deseni. **Born-at-tier:** Lonca emsali (born-at-S4); doğumda alt-generic-goal'ler appraisal ile kanıtlanır. |
| 4 **isim+dosya-yapı** | Kendi-repo yapısı: vizyon+ADR + in-repo-impl + (opsiyonel) Cortex-telemetri. |
| 5 **on/off** | Normatif asgari: **restart-siz kapatılabilirlik + izole-sızma-yok**. *(Örnek-mekanik/Lonca: runtime DB-bayrağı per-instance + dosya-bayrağı+scope-guard.)* |
| 6 **test/doğrulama** | Kendi-CI + kendi-gate'leri (OTORİTER); AHÎ yalnız kademe-uyumunu denetler. |
| 7 **dağıtım** | L1 global (ortak-mount + `_global`); L2 curated-köprü (izole-container'a girmez). |
| 8 **yaşam-döngüsü** | Kendi-roadmap + sürüm; "emeklilik" = substrat-nasıl-emekli-olur (V2/FAZ-6 dogfood). |
| 9 **terfi** | YOK (en-üst). Mezuniyet-ölçütü: remote+CI+roadmap + kendini-besleyen-döngü (telemetri→değerlendir→gelişme-planı). |

**⚠️ DOĞRULAMA-DÖNGÜSÜ (post-V1, SERDAR-Lonca-bitince):** Lonca = CANLI S4-örnek. AHÎ-kanonunun İLK gerçek-testi = "Lonca bu 9-boyuta oturuyor mu?".
V1 bunu HENÜZ mekanik-kanıtlamaz (Sultan-kabul, `04-plan §8-Q4`); Lonca-törpüleme = FAZ-6 dogfood (Dim2/3/4/5/8/9 + üreteç-yüzü büküm + S3→S4 Pîr-özel-appraisal + substrat-emeklilik).
