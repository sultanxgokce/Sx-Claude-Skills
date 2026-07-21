# Kademe-Kartı — KALFA (S2 · Paketli Skill)

> generic-goal: **"planlı + paketli + her-projede güvenilir tekrarlanabilir"** (CMMI GG2 Managed).

| # Boyut | Tanım |
|---|---|
| 1 **nedir** | Her projeden tek-komutla kurulup on/off yapılabilen, güvenilir-tekrarlanabilir paketli skill. |
| 2 **nerede-yaşar** | `Sx-Claude-Skills/<ad>/` (yayınlanmış-paket + semver); `_global` VEYA per-proje dağıtılır. |
| 3 **üretim-reçetesi** | `ahi new kalfa <ad>` → SKILL.md (frontmatter tam) + scripts/ + ahi.manifest.yaml. |
| 4 **isim+dosya-yapı** | `<ad>/SKILL.md` (name/description→progressive-disclosure) + `scripts/` + `reference/` (gerekirse). |
| 5 **on/off** | Provizyon: `sync-targets.json` install-listesi + `--apply`. Runtime: `activation:` tetiği (INERT/aktif). |
| 6 **test/doğrulama** | Manifest-şema-valid + placeholder-doğrulama + pre-publish-hard-lint (zorunlu-frontmatter/isim-benzersizlik). |
| 7 **dağıtım** | Elle-apply (`sync-skills.mjs`); `_global`=ortak-mount **7-container** (compose paylaşımlı `.claude`; mihenk dahil — Federe-D6). Drift-gözcü: `ahi check`. |
| 8 **yaşam-döngüsü** | semver (SKILL.md frontmatter); soft-emeklilik `ahi deprecate` (sunset+successor). |
| 9 **terfi (→Usta)** | Eklenecek eksen: **çoklu-skill-besteleme**. Checklist: bu skill `requires[]` ile **≥2 Kalfa-skill besteliyor** (deklare+çözülüyor+co-install-temiz)? · ≥2-projede-aktif (katalog-sayımı)? · drift-gözcü temiz? *(NOT: başkaları-bunu-require = olgun-Kalfa sinyali, Usta-kriteri DEĞİL — Usta = besteleyen.)* |

**Kalfa→Usta terfi-sinyali:** bu skill birkaç paketli-skill'i **besteleyerek** bir iş-sistemi/çalışma-prensibi oluşturuyor (aday = besteleyen, bestelenen değil).
**hedef-kademe notu:** çoğu skill Kalfa'da "yeterince olgun" kalır (RMM-L2 emsali); Usta'ya çıkmak zorunlu değil.
