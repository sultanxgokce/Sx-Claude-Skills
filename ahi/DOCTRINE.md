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
- **Dağıtım:** elle-apply (`sync-skills.mjs --apply`, bilinçli) — `_global` (ortak-mount **10/10**: pc/kod/vekatip/mmex/medigate/huma/mihenk/tellal/akar/s02 — compose `./config/.claude` paylaşımlı bind; `pc` bunu `./config:/config` üst-mount'uyla alır. Compose-kanıtı 2026-07-25 L25-W2: docker-compose.server.yml satır 44/91/164/228/296/354/409/448/478/512. Altyapı `openbao`+`cloudtop-ntfy` AYRI compose → payda DIŞI) VEYA per-proje. *(Eski "huma ulaşmaz" notu bayattı — huma/mihenk de aynı ortak-mount'u bağlar; huma'nın curated-köprüsü Cortex-İÇERİĞİ içindir, skill-mount'u değil.)* Otomatik-tetikleyici YOK (elle disiplin).
- **Drift-gözcü (`ahi check`):** YALNIZ `catalog.json`↔`sync-targets.json`↔`README` parity + tier/requires/deprecated semantiği + manifest-şema-geçerliliği. **`sync-targets`/`catalog`'a ASLA YAZMAZ — yalnız RAPORLAR** (insan/PR uygular). Bkz `ADR/ADR-001`.

## 9 · Yaşam-döngüsü (soft-ama-sunsetli + SYS geri-bildirim-döngüsü)
- **Sürüm:** semver, TEK evi `SKILL.md` frontmatter (§11).
- **Emeklilik:** `ahi deprecate <skill> "<mesaj>"` → frontmatter `deprecated:true` + `sunset:<tarih>` + `successor:<skill|ayar>` ZORUNLU; işaretler+uyarır+KALDIRMAZ+reversible. *(npm-deprecate)*. Silme değil arşiv. [hard-retire + demote = V2.]
- **SYS — doğum-sonrası yaşam (Skill Yaşam-Döngüsü Standardı, L01):** doğum ile emeklilik ARASINDAKİ yaşam standarttır: **tetik→kayıt→depo→owner→anlamlandır→aksiyon→gate'li-icra** (DİVAN owner-loop'unun SKILL-instansı; yeni-sistem değil, mevcutları teKler). Mekanik:
  - **(a) Dayanıklı-kayıt (ephemeral YASAK):** skill'den şikâyet/eksik/drift → `scripts/skill-fb-ekle.sh ekle` (tek yazma-yüzeyi, fail-closed: `skill`+`baslik`+`kanit` ZORUNLU) → append-only `_agents/handoff/skill-geri-bildirim.jsonl`. "SERDAR'a emit et, unut" YASAK — her bulgu havuza düşer (K1: DİVAN-havuzundan AYRI).
  - **(b) Owner:** feedback owner'ı manifest `feedback.owner` (→ §schema) ile DETERMİNİSTİK atanır; boşsa `ahi health` "öksüz-owner" WARN'lar. Süzen owner'ı ATLAYAMAZ (DİVAN sahip-süzemez kuralı).
  - **(c) KATMANLI önem (aşırı-yük panzehiri):** `scripts/skill-fb-t1.sh` her bulguya `agirlik = tür-ağırlığı × tekrar × kanıt-gücü` verir; eşik-üstü → **CLOSURE** (kart+GEREKLILIK+tescil), eşik-altı → **DIGEST** (owner'a toplu, kart-açmaz). Her feedback kart-AÇMAZ.
  - **(d) Kanıt-kapılı kapanış:** skill-onarımı "bitti" YALNIZ tescil-mührüyle (skill-defect `GEREKLILIK.md` — en az 1 davranış-G, defect'i yeniden-üret→fix-doğrula) → `skill-fb-ekle.sh durum g#### bitti --kanit <MUHUR|PR>` (kanıtsız RC=2). Beyanla-kapanış YOK.
  - **(e) İcra-öncesi GO-gate + INERT:** onarım-icrası/global-yayılım DAİMA insan/owner-gate'li (kontrolsüz-otomasyon YASAK). Tüm SYS-yüzeyi additive/INERT — kapalı=byte-identical.
  - *(Konteyner-arası skill-defect wire = FAZ-3, mahremiyet-duvarı red-team-gated; bu kanonda AKTİF DEĞİL.)*

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

## 12 · KULLANDIKÇA GELİŞTİR (yaşayan-senkron · L46 · Sultan-onayı 2026-08-04)

> **Kural tek cümle:** bir beceriyi KULLANAN, onu geliştirmekle de yükümlüdür — ve geliştirdiği
> şey **kanona dönmeden iş bitmiş sayılmaz**.

**Niçin var (ölçüldü, 2026-08-04):** 50+ becerinin **7'si** canlı rafta kanondan İLERİDEYDİ.
Yani ajanlar becerileri zaten geliştiriyordu; gelişme kanona hiç dönmüyordu. Üç somut kayıp:
`whatsapp-gonder`'in sessiz-yanlış-alıcı düzeltmesi 4 gün yalnız bir kutuda yaşadı ve başka bir
kutu aynı hatayı canlıda yedi · `federe-os-cekirdek`'in tetikli-mesaj geliştirmesi kanonda yoktu →
sıfırdan-rebuild onu geri getirmezdi · `iskan` ters yönde takıldı: kanon ileri, canlı geri, **sürüm
aynı** olduğu için dağıtım aracı dosyaya hiç dokunmuyordu (sessizce).

### 12.1 · Altı adım (sıra bağlayıcı)
1. **Kim geliştirir:** kullanan. Eksik/hata/daha-iyi-yol gördüğün an düzeltirsin; "sahibine bildirdim"
   diyip geçmek geliştirme DEĞİLDİR (kayıt bırakmadan geçen bulgu kaybolur — §9-SYS/a).
2. **Nerede düzeltirsin:** kendi kutunun **canlı rafında** (`/config/.claude/skills/<ad>/`). İzole
   kutu kanon-depoyu göremez; bu bir arıza değil mahremiyet duvarıdır.
3. **SÜRÜMÜ YÜKSELT — atlanamaz.** Davranış değiştiyse `SKILL.md` frontmatter'ındaki `version`
   yükselir (davranış-düzeltmesi=patch · yeni yetenek=minor). **Sürüm yükseltmeden düzenlemek =
   sessiz drift:** dağıtım aracı sürüm eşitken dosyaya DOKUNMAZ, düzeltmen sonraki senkronda
   sessizce ezilir ya da hiç yayılmaz. (`iskan` vakası tam buydu.)
4. **KANONA DÖNDÜR — "bitti"nin şartı budur.** Kanon-depoya (`Sx-Claude-Skills`) PR aç. Kutun
   kanonu göremiyorsa: beceri klasörünü kuryenin giden kutusuna bırak
   (`oda-kurye.sh` 2026-08-04'ten beri **klasör taşır**) + yanına tek sayfalık devir notu:
   *ne değişti · niçin · hangi işte fiilen kullanıldı · hangi kısım hâlâ sana özgü.*
5. **Dağıtımı DOĞRULA.** "PR birleşti" ≠ "kutularda var". `sync-skills.mjs --apply` sonrası hedef
   kutuda dosyanın fiilen durduğunu gör. (Aynı gün üç compose PR'ı host'a hiç inmemişti — depo ≠ canlı.)
6. **Deftere bir satır.** Ne değişti + sürüm + PR. Damgasız gelişme, bir sonraki ajan tarafından
   yeniden keşfedilir.

### 12.2 · Neyi BAĞLAMAZ (negatif kapsam — sınırsız kural reddedilir)
- **Çırak/kutu-yerel denemeler** (`<proje>/.claude/skills/`): tüketicisi yok, kanona dönmek zorunda değil.
  Kural, **dağıtılmış** becerileri (Kalfa+ ve canlı ortak raftakileri) bağlar.
- **Geriye dönük toplu tarama emri DEĞİLDİR.** Kural kullanım-anında işler: 50+ beceriyi bugün
  elden geçirme borcu doğurmaz; bir beceriye DOKUNULDUĞU an o beceri için yürürlüğe girer.
  (Bugünkü 7 ihlal kuraldan ÖNCE ayrıca temizlendi — kural doğarken ihlalli doğmasın diye.)
- **Sır/kişisel veri** hiçbir gelişmede kanona taşınmaz; izole kutu içeriği kanala girmez (İ1).

### 12.3 · Bekçi ZORLAR (yoksa kural temenni kalır)
Canlı kopya kanondan **ileriyse ya da sürüm eşitken içeriği farklıysa** rapor **KIRMIZI** kalır.
- `sync-skills.mjs` (bayraksız, dry-run) iki drift hâlini de yakalar — sürüm-drift'i ve
  **içerik-drift'ini** — ve **çıkış 1** verir. Bu zorlama araçta ZATEN VAR (2026-08-04 ölçüldü).
- Eksik olan **çağıran**dı: haftalık `evergreen-parity.sh` bu aracı yalnız *remediation metninde*
  anıyordu, hiç KOŞMUYORDU → kırmızı üretilse de kimse duymuyordu. `P11e-BECERI-DRIFT` kolu bunu
  bağlar. *("Bunu kim çağıracak?" — motor sağlam, çağıran yok sınıfı.)*
- **Ölçerken tuzak:** `node sync-skills.mjs | tail` çıkış kodunu YUTAR ve bekçi yeşil görünür.
  Çıplak koş ya da `; echo exit=$?` ekle. (Bu satır bizzat o tuzağa düşülerek yazıldı.)

---
*AHÎ · Sx-Claude-Skills · kademe-rütbesi: Çırak → Kalfa → Usta → Pîr/Lonca · sahip: SERDAR/KÂHYA review-kapısı*
