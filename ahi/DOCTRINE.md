# AHÎ — Değişmezler Kitabı (DOCTRINE)

> **AHÎ** = Sultan'ın ekosisteminde yeni AI-yetenek üretimini TEK-STANDARDA oturtan meta-fabrika.
> "Ahî" = Osmanlı esnaf-loncası kardeşliği; zanaat-standardının bekçisi. Bu dosya = kanon (insan+ajan buna uyar).
> Üreteç-yüzü (`ahi` skill) bu kanonu deterministik ZORLAR. Statü: FAZ-0a · v0.1 (kanon-kilit Fable-taste review-oracle ile).

---

## 1 · Dört Kademe (zanaat-rütbesi)
Her yeni AI-yeteneği bir kademeye oturur. Kademe = o yeteneğin **olgunluk-mertebesi** (yazılım-olgunluk-modeli CMMI emsali).

| Kademe | generic-goal (kurumsallaşma-testi — TEK cümle) | nerede-yaşar |
|---|---|---|
| **Çırak** (S1) | "işi yapıyor" — projeye-özgü, yerel, basit | o projenin `.claude/skills/<ad>/` (monorepo-içi doğrudan-ref) |
| **Kalfa** (S2) | "planlı + paketli + her-projede güvenilir tekrarlanabilir" | `Sx-Claude-Skills/<ad>/` (yayınlanmış-paket + semver) |
| **Usta** (S3) | "standarttan-türetilmiş bileşik iş-sistemi" (birkaç skill besteler) | `Sx-Claude-Skills/<ad>/` (`requires[]` + bileşik) |
| **Pîr/Lonca** (S4) | "ölçülen + kendini-geliştiren yaşayan-sistem" | kendi-repo (remote + CI zorunlu; örnek: Lonca) |

Detay kademe-kartları: `tiers/{cirak,kalfa,usta,pir}.md` (her biri 9-boyutu doldurur).

## 2 · Dokuz Boyut (her kademe kartında doldurulur)
1. **nedir** — generic-goal cümlesi. 2. **nerede-yaşar** — dağıtım-fiziği (yukarıdaki tablo). 3. **üretim-reçetesi** — makine-okunur
manifest (`ahi new`). 4. **isim+dosya-yapı** — §5. 5. **on/off** — iki-eksen (§6). 6. **test/doğrulama** — deterministik (§7).
7. **dağıtım** — elle-apply + drift-gözcü (§8). 8. **yaşam-döngüsü** — semver + soft-emeklilik (§9). 9. **terfi** — tertipli + appraisal (§10).

## 3 · Değişmezler (İHLAL EDİLEMEZ)
- **TERTİPLİ-PROGRESYON:** **TERFİ** atlanamaz (Çırak→Usta terfi-sıçraması YOK). **DOĞUM** herhangi-kademede olabilir (ör. Lonca born-at-S4; `ahi new usta`), AMA doğum-anında alt-kademelerin generic-goal'leri **born-at-tier appraisal** ile kanıtlanır (`ahi new usta` = Çırak+Kalfa checklist'lerini de yeşil-geçer). Üst-kademe alt-generic-goal'ü ön-koşul-sayar; her kademe kendi olgunlaşma-süresini ister. *(CMMI olgunlaşan-organizasyonu modeller — doğuştan-bileşik-artefaktı dışlamaz.)*
- **ÇEKİM > DAYATMA:** standardı dayatınca etrafından-dolanılır. "Doğru-yolu-kolay-yol-yap"; her kademe **escape-hatch**'le doğar (opt-out ceza-görmez, yalnız destek-kaybı-net). *(Netflix paved-road)*
- **TVP (Thinnest-Viable-Platform):** her yetenek %80-vakayı en-ince-çözümle; %20 için escape; %100-kapsama-şişmesi YASAK (over-engineering = platformdan-kaçış).
- **OBJECTIVE-EVIDENCE > VİBE:** terfi/emeklilik/drift kararları ölçülebilir-kanıta bağlanır (kaç-projede-aktif, drift-olay, min-yaş, lint-pass). Kanı ile "olgun" ilan edilmez.
- **MANİFEST TEK-KAYNAK (version-HARİÇ):** üretim-reçetesi · on/off · bağımlılık · host-uyum · emeklilik-durumu makine-okunur-manifest/frontmatter'da yaşar. **İSTİSNA:** `version` semver'in TEK evi = `SKILL.md` frontmatter (sync-skills.mjs otoritesi — §8/§11).
- **SOFT-AMA-SUNSETLİ (Kalfa+ dağıtılmış-yetenekler):** her yumuşak-emeklilik makine-okunur `successor`-pointer + `sunset`-tarihi ile çiftlenir; silme değil arşiv-varsayılan; DELETE caydırılmış+kanıtlı. *(İSTİSNA — Çırak/yerel+tüketicisiz: DELETE serbest, sunset-mekanizması gerekmez; bkz `tiers/cirak.md` dim-8.)*
- **İKİ-EKSEN AYRIMI:** capability(skill-kademesi) ⊥ maturity(ekip/ajan-olgunluğu); provizyon-ekseni(kurulu/değil) ⊥ runtime-ekseni(INERT/aktif); host-uyum(`requires_harness`).
- **PLATFORM-AS-A-PRODUCT SAHİPLİK:** AHÎ-doktrini sahipli + review-kapılı (sahip = SERDAR/KÂHYA review-kapısı). Sahipsiz golden-path ölçeklenmez.
- **VALUE-SAFE:** sır-değer ASLA stdout/log/chat/argv'ye; intake TTY-gizli; registry=pointer.
- **OWNER-DOMAIN-DOKUNMA:** `sync-skills.mjs` + mevcut-üreteç-kodları (skill-packager · erisim-skill-fabrikasi · provision.py) AHÎ tarafından DEĞİŞTİRİLMEZ; AHÎ onları TANIR/RAPORLAR, sarmalama V2.
- **KAPSAM-REFLEKSİ (E3/R-03 · federe-standart, Federe D8):** her yetenek-üretimi ÖNCESİNDE zorunlu 4-adım: R-03 "zaten-var-mı?" envanter-taraması (varsa üretme → "global-yayayım mı?") · negatif-kapsam ("neye DOKUNMAYACAK?"; sınırsız-cevap REDDEDİLİR, İ1 gevşemez) · bölge-çakışma (çakışıyorsa üretme → eskalasyon) · E3 dağıtım-kapsamı 3-şık (yerel / global-hepsi / seçili-liste; global=tek-üretim→senkron-yayılım, tek-tek-kurma YASAK). Cevap install-ÖNERİSİ olarak raporlanır — `sync-targets`/`catalog` girdisini insan/PR uygular (ADR-001). Metin-kanonu: `SKILL.md §Kapsam-refleksi`; bekçi: `ahi check`/CI çıpa-kontrolü.
- **INERT/FLAG-GATED:** AHÎ additive; kapalı=byte-identical; mevcut hiçbir skill/sistem bozulmaz.

## 4 · İki-yüz (form)
- **DOKÜMAN** (bu DOCTRINE + `tiers/*`) = "değişmezler kitabı" (insan+ajan uyar).
- **ÜRETEÇ** (`ahi` skill, `SKILL.md`+`scripts/ahi.sh`) = "el" (kanonu deterministik zorlar: scaffold + lint + terfi + emeklilik).
Sadece-biri eksik-kalır: doküman-yalnız→disiplin-çöker; üreteç-yalnız→"neden-böyle" kaybolur.

## 5 · İsim + dosya-yapı standardı
- **İsim konvansiyonu (ekosistem-kanonik):** `skill-` öneki YOK. Çıplak-ad + fonksiyon-soneki: `<ad>-erisim`, `<ad>-fabrikasi` (AHÎ'nin kendisi `ahi`). İlke: benzersiz + açıklayıcı + progressive-disclosure. *(Backstage-naming yalnız ilke-olarak; prefix-formu değil.)*
- **Dosya-yapı (Kalfa+):** `<ad>/SKILL.md` (name/description → progressive-disclosure) + `<ad>/scripts/` + gerekirse `<ad>/reference/`. Bileşik(Usta): `requires[]` deklare eder.
- **Manifest:** `<ad>/ahi.manifest.yaml` (makine-okunur tek-kaynak; şema `schema/ahi.schema.json` — FAZ-0b).

## 6 · On/Off — İKİ EKSEN
- **Provizyon-ekseni:** skill hedef-dizinde VAR mı? (`sync-targets.json` install-listesi → `sync-skills.mjs --apply`). Var=kurulu, yok=kurulu-değil.
- **Runtime-ekseni:** kurulu-skill AKTİF mi yoksa INERT mi? `activation:` bloğu (`onKeyword`/`onContext`/`onCommand`/`workspaceContains`) — tetikte-uyanır. *(VS Code lazy-activation)* + `disable-model-invocation` (yalnız-Sultan-tetikli).
- İzolasyon-scope: izole-container'lar yalnız `_global` + kendi-per-proje-listesini görür (mahremiyet-sınırı).

## 7 · Test/Doğrulama (deterministik, LLM'siz)
İki-katman guardrail: (1) **girdi** = manifest-şema doğrulaması (zero-dep vendored-validator; FAZ-0b). (2) **çıktı** = placeholder-doğrulama
(dolmamış `{{...}}` → sevk-RED) + dry-run (üretmeden-doğrula). **"bitti" = deterministik-oracle** (script→lint-RC=0 · prose-kanon→review-oracle);
kanıtsız-yeşil YASAK. AHÎ kendi kendini denetler: `ahi check ahi` → temiz (dogfood).

## 8 · Dağıtım + Drift-gözcü
- **Dağıtım:** elle-apply (`sync-skills.mjs --apply`, bilinçli) — `_global` (ortak-mount **7/7**: pc/kod/vekatip/mmex/medigate/huma/mihenk — compose `./config/.claude` paylaşımlı bind; Federe-D6 compose-kanıtı 2026-07-21) VEYA per-proje. *(Eski "huma ulaşmaz" notu bayattı — huma/mihenk de aynı ortak-mount'u bağlar; huma'nın curated-köprüsü Cortex-İÇERİĞİ içindir, skill-mount'u değil.)* Otomatik-tetikleyici YOK (elle disiplin).
- **Drift-gözcü (`ahi check`):** YALNIZ `catalog.json`↔`sync-targets.json`↔`README` parity + tier/requires/deprecated semantiği + manifest-şema-geçerliliği. **`sync-targets`/`catalog`'a ASLA YAZMAZ — yalnız RAPORLAR** (insan/PR uygular). Bkz `ADR/ADR-001`.

## 9 · Yaşam-döngüsü (soft-ama-sunsetli)
- **Sürüm:** semver, TEK evi `SKILL.md` frontmatter (§11).
- **Emeklilik:** `ahi deprecate <skill> "<mesaj>"` → frontmatter `deprecated:true` + `sunset:<tarih>` + `successor:<skill|ayar>` ZORUNLU; işaretler+uyarır+KALDIRMAZ+reversible. *(npm-deprecate)*. Silme değil arşiv. [hard-retire + demote = V2.]

## 10 · Terfi (tertipli + appraisal-checklist)
Terfi = **objektif-appraisal** (vibe değil). Her kademe-atlaması TEK yeni yetenek-ekseni ekler:
- **Çırak→Kalfa:** on/off-paketlenebilirlik. Checklist: paketlendi mi? · frontmatter-sözleşmesi tam mı? · `ahi check` temiz mi?
- **Kalfa→Usta:** çoklu-skill-besteleme. Checklist: bu skill `requires[]` ile **≥2 Kalfa-skill BESTELİYOR** (deklare-ediyor) ve hepsi çözülüyor + co-install temiz mi? · **≥2-projede-aktif** (katalog-sayımı) mi? · drift-gözcü temiz mi? *(NOT: "başkaları bunu require-ediyor" = olgun-Kalfa **sinyali**, Usta-kriteri DEĞİL — yön karıştırılmaz: Usta = besteleyen, bestelenен değil.)*
- **Usta→Pîr:** kendi-repo + CI + kendini-besleyen-döngü (tek-paket: "yaşayan-sistem altyapısı"). Checklist: remote-repo var mı? · CI var mı? · telemetri→gelişme-döngüsü var mı?
- **Mekanik:** `ahi promote <skill>` checklist'i otomatik-koşar (makine-kaynağı: `ahi health` katalog · git-log · `requires[]`-indeks); YEŞİLSE Sultan-törenine ÖNERİR (hibrit — karar+tören Sultan'da). Makine-okunamayan kriter AÇIKÇA "manuel-beyan (Sultan-gate)" işaretlenir. **Eşikler (V1): N=2-proje · min-yaş=30 gün** (objective-evidence sayıya-bağlı; kanı değil).
- **hedef-kademe ≠ en-üst:** her yetenek "hakettiği tavan-kademe" taşır; çoğu Kalfa/Usta'da "yeterince olgun" kalır — gereksiz-Pîr-şişmesi YASAK. *(RMM-L2/DevOps-L4 emsali)*. V1-appraisal = STATİK-katalog-only; runtime-kullanım-metrikleri = V2.

## 11 · Drift-otorite ayrımı (kritik — ADR-001)
- **`sync-skills.mjs` = version-karşılaştır + kopya/apply OTORİTESİ** (owner-domain, DEĞİŞMEZ). `version` bunun regex-okuduğu `SKILL.md` frontmatter'ında yaşar.
- **`ahi check` = TAMAMLAYICI** (rakip değil): catalog/sync-targets/README parity + manifest-semantiği. Version'ı sync-skills'e salt-okur-DELEGE; iki-yerde-varsa eşitlik-assert. sync-targets/catalog'a **yazmaz**.
- Bkz `ADR/ADR-001-drift-otorite-ayrimi.md`.

---
*AHÎ · Sx-Claude-Skills · kademe-rütbesi: Çırak → Kalfa → Usta → Pîr/Lonca · sahip: SERDAR/KÂHYA review-kapısı*
