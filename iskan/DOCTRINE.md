# İSKÂN — Değişmezler Kitabı (DOCTRINE)

> **İSKÂN** = container + ekip yaşam-döngüsü master-skill. "İskân" = bir topluluğu kendi meskenine
> kalıcı-yerleştirme — UC1 (yeni-iskân/container-provizyon), UC2 (yeniden-iskân/seans-getir),
> UC3 (tek-üye-iskân) üçünü de kapsar. Bu dosya = İSKÂN'a özgü kanon (AHÎ'nin genel-kanonu = `ahi/DOCTRINE.md`,
> ikisi ÇELİŞMEZ — bu dosya İSKÂN'ın kendi owner-domain'i için AHÎ-kanonunu SOMUTLAŞTIRIR).
> Kaynak: `Nexus/_agents/handoff/help2serdar-iskan-is-plani.md` (K1-K5 tasarım-kararları + §3 adversarial-düzeltmeler).
> Statü: FAZ-0 (doğuş + doktrin + host-teyit probe; host'a hiçbir yazma-dokunuşu yok).

---

## 1 · Altı Değişmez (İHLAL EDİLEMEZ)

- **Değişmez 1 — REPO-FIRST (plan D1, kritik):** host-mutasyonu yapan HİÇBİR adım host'a doğrudan-elle
  yazılmaz. Sıra sabit: git-tracked repo'ya yaz (compose-blok, setup-tunnel.sh hostname-satırı, vb.) →
  commit+push → SONRA host-deploy scripti (`host-recreate.sh` / `up.sh`) çalıştırılır. Ad-hoc
  `ssh hostsrv 'cloudflared tunnel route dns ...'` gibi doğrudan-host-komutları YASAK. Kabul-testleri
  host-canlı kontrolün YANINA `git show origin/main:` kontrolü koyar — host-only yeşil sahte-yeşildir.
- **Değişmez 2 — Volume-path kesişim-guard'ı (plan B1, kritik):** yeni bir compose-bloğunun bind-mount
  host-path'i, mevcut TÜM servislerin path-kümesiyle kesişmez (set-intersection = 0, otomatik-kontrol).
  Kesişim tespit edilirse `--apply` RED — yanlış-enterpolasyon iki container'ı aynı `/config`'e bağlarsa
  sonuç geri-dönüşsüz konfig-ezilmesidir.
- **Değişmez 3 — Sultan-GO kapısı + oto-geri-al (host-mutasyonu genel-kuralı):** create/recreate/
  CF-değişikliği/host-dosya-yazımı içeren HER adım Sultan-GO-marker'ı olmadan bloklanır (negatif-kapı
  testiyle kanıtlanır: marker yokken `--apply` exit≠0). Scope-ihlali (B1/B2/B3 guard'larından biri
  tetiklenirse) sadece abort değil OTOMATİK-GERİ-AL'a çıkar.
- **Değişmez 4 — KÂHYA izole-yasağı (plan İ1, kritik → ADR-düzeyi):** izole-container hedefi için
  `ise-alim`/KÂHYA DOĞRUDAN invoke EDİLMEZ (MERKEZİ-NEXUS doktrini kimliği paylaşılan-yüzeylere yazar =
  mahremiyet-sızıntısı). İzole-hedefte İSKÂN kendi hafif-kimlik-üreteci ile çalışır (mihenk Katman-2
  deseninin standartlaştırılmış hâli). Bkz İ1 aşağıda.
- **Değişmez 5 — Value-safe + transkript-gizliliği (plan İ2/İ3):** sır-değer hiçbir kayda/log'a/stdout'a
  yazılmaz (yalnız KEY-adı+len). Session `.jsonl` araması HER ZAMAN hedef-container İÇİNDEN
  (`docker exec <hedef>`) yapılır — host-bind-mount'tan doğrudan okuma YASAK; transkript-İÇERİĞİ İSKÂN
  çıktısına asla basılmaz, yalnız dosya-adı/session-id konuşulur.
- **Değişmez 6 — Deterministik session-id + sahiplik-kuralı (plan K3, kritik-yeniden-tasarım):** resume
  tahmine (mtime vb.) değil KAYDA dayanır. Bir session-id yalnız registry'deki sahibi role resume edilir;
  belirsiz/şüpheli eşleşmede sessiz-devam YASAK — `SUSPECT-mismatch` açık-etiketlenir + `--fork-session`
  ile orijinal transkripte geri-dönüşsüz yazım önlenir + Sultan'a sorulur.

## 2 · İ1 — KÂHYA izole-hedefte YASAK (kritik → ADR)

Tasarım-notu değil KESİN kural: izole-container üyesi için `ise-alim`/KÂHYA doğrudan invoke EDİLMEZ
(MERKEZİ-NEXUS doktrini kimliği paylaşılan-yüzeylere yazar = sızıntı). İzole-hedef → İSKÂN kendi
hafif-kimlik-üreteci (mihenk Katman-2 desenini standartlaştırır). Negatif-test: izole-hedefli `uye-ekle`
sonrası Nexus'un 4 registry-dosyasında `git diff` SIFIR olmalı (bkz Nexus `CLAUDE.md` → "Ajan Registry
Güncelleme Zorunluluğu" — izole-hedef bu 4-dosyaya asla dokunmaz).

## 3 · İ2 — Cortex-capture istisnası (yüksek)

İSKÂN'ın kendi capture'ı yalnız META-değişikliği taşır (örnek: "X adında izole-container provizyonlandı",
"Y ekibine Z üyesi eklendi"). Hedef-projenin roster/görev/içeriği Cortex'e ASLA yazılmaz — İSKÂN bir
provizyon-aracıdır, hedef-projenin bilgi-tabanına müdahil değildir. Bu istisna Nexus `CLAUDE.md`'deki
"Geliştirme Sonrası Zorunlu Protokol → 1. Cortex DB'ye Capture" adımının İSKÂN-özel daralmasıdır.

## 4 · D6 — İki-rebuild-yolu sınırı (düşük)

İki ayrı "sıfırdan-geri-getirme" yolu vardır ve İSKÂN ikisinin köprüsünü açıkça yazar, birbirine
KARIŞTIRMAZ:
- **Katman-4 / `bulut-yapilandir`** = container-**İÇİ** durum (global `~/.claude` state, repo'lar,
  credential-yönlendirmesi) — konteyner zaten AYAKTAYKEN çalışır.
- **Container'ın KENDİSİ** = host-seviyeli compose-deploy (`docker compose up`, cloudtop-repo
  `infra/docker-compose.server.yml`) — konteyner HENÜZ YOKKEN çalışır.

İSKÂN'ın UC1'i (yeni-iskân) ikinci-katmanı (host-compose) tetikler; container ayağa kalktıktan SONRA
birinci-katman (`bulut-yapilandir`) devreye girer. İSKÂN bu iki yolu TEK bir "kur" fiiline gizlemez —
hangi adımın hangi katmanda olduğunu kanıt-kapılarında ayrı ayrı raporlar.

## 5 · Manuel-beyan şerhi — born-at-Usta olgunluk-eşiği

İSKÂN `ahi new usta iskan` ile **doğrudan Usta kademesinde doğdu** (born-at-tier, AHÎ DOCTRINE §1
Değişmez-1 "TERTİPLİ-PROGRESYON" bunu meşru sayar: doğum herhangi-kademede olabilir, üst-kademe
alt-kademe generic-goal'lerini born-at-tier appraisal ile kanıtlar).

AHÎ DOCTRINE §10 (Terfi) Kalfa→Usta checklist'inde **objective-evidence** eşiği tanımlar: "**≥2-projede-aktif**
(katalog-sayımı)" + "**Eşikler (V1): N=2-proje · min-yaş=30 gün**". İSKÂN bugün (2026-07-15, FAZ-0,
doğuş-günü) bu eşiği **sağlayamaz** — henüz sıfır-proje aktif, sıfır-gün yaşında. Bu MANUEL-BEYANDIR,
"zaten terfi-olgunluğuna erişti" iddiası DEĞİL: İSKÂN'ın Usta-kademesindeki-varlığı **besteleme-genişliğinden**
(K1: `requires[]` ile 4 Kalfa-skill besteliyor — bileşik-artefaktı doğuştan sağlıyor) gelir, **kullanım-yaşından**
DEĞİL. `ahi promote`/appraisal ileride koşulursa bu şerh objective-evidence eşiğinin henüz-sağlanmadığını
açıkça gösterir; Sultan-gate bu ayrımı bilerek verir. (Plan-dokümanındaki referans: Z14/K1 "DOCTRINE §70
≥2-proje olgunluk-kriteri" — bu plan-metninde AHÎ DOCTRINE §10'daki N=2-proje/min-30-gün eşiğine yapılan
kısaltılmış atıftır; AHÎ DOCTRINE'de ayrı "§70" başlığı yoktur, doğru-anchor §10'dur.)

---

## 6 · Kapsam-sınırı (FAZ-0)

Bu doküman FAZ-0 doğuşunun bir parçasıdır. FAZ-1'den itibaren dolacak alt-komutlar (`doctor`, `seans-getir`,
`yeni-proje`, `uye-ekle`) kendi kanıt-kapılarıyla gelecek; bu dosyaya o fazlarda yeni Değişmez EKLENEBİLİR
ama mevcut 6 Değişmez SİLİNMEZ/gevşetilmez (yalnız GÜÇLENDİRİLİR). Kanon-değişikliği = ayrı PR + Sultan-gate.
