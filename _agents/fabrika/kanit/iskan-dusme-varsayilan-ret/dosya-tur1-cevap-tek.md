# Tur 1 bulgularına cevap (SERDAR · 12 Eki 2026)

## Bulgu 1 — "tam sınavda yeni regresyon: kur --dry-run zincir-planında eksik adım"
**Regresyon değil; sınavın borulu grep kalıbının rastgele düşmesi (SIGPIPE).**
- `iskan.test.sh:9` → `set -uo pipefail`. Zincir kapısı (`:1621`) `printf '%s' "$out" | grep -q "kur adım $a"` kullanıyor:
  grep eşleşmeyi bulunca erken çıkar, printf SIGPIPE alır, pipefail ile boru 141 döner → adım "eksik" sayılır.
- Belirti tam bunu söylüyor: eksik küme koşudan koşuya değişiyor — `[4/8][6/8]` (olcum-sinav-sonra) ve `[3/8][5/8][6/8]` (dosya-sinav-sonra-2-tam-tek). Kod kaynaklı eksik adım her koşuda AYNI olurdu.
- Ölçüm (`dosya-kur-zincir-borusuz-prob-tek.out`, betik `dosya-kur-zincir-prob-betigi-tek.sh`): yalnız o satır here-string'e çevrildi, başka hiçbir şey değişmedi:
  - bu dal: 3/3 koşu zincir kapısı **ok**, `267 geçti / 1 kaldı` (kalan = `baslat-claude.sh`, origin/main'de de var)
  - origin/main: 3/3 koşu zincir kapısı **ok**, `264/1 · 264/1 · 263/2`
- Bu dal +3 kapı ekledi (264→267) ve kalan kırmızı sayısını artırmadı. Kalıp sınavda 174 yerde var → ayrı kusur, havuzda **A340** (bu PR'ın kapsamı değil).

## Bulgu 2 — "BASİRET + ENİS iki ölçüm karşılanmamış; ENİS kaydı düşen-üye reddini ölçmüyor"
- Karttaki `istedi` alanı **işi isteyenleri** yazar (BASİRET'in A323 mektubu + ENİS'in 11 Eki iki ölçümü = tetikleyen emsal); "iki ayrı ölçüm teslim et" şartı değildir.
- İkinci yarı **haklıydı**: eski `enis-dry-run` bugünkü roster'la koştu (SIHHAT eklendiği için düşen üye yok) → red kapısını hiç sınamadı; komut da boru arkasındaydı. Düzeltildi — 11 Eki emsali aynı ENİS kaydıyla, SIHHAT'sız roster (`ISKAN_EY_ROSTER="ENIS:yonetici MURSIT:uye"`), kuru koşum, borusuz:
  - `olcum-emsal-enis-sihhatsiz-0102-once.txt` (origin/main 0.10.2): `[sarı] uye-dusuyor: SIHHAT` + plan SIHHAT'sız, **rc=3** → 11 Eki'deki tehlike birebir
  - `olcum-emsal-enis-sihhatsiz-varsayilan-sonra.txt` (bu dal): `[kırmızı] uye-dusme-reddi`, **rc=1**, plan basılmadı
  - `olcum-emsal-enis-sihhatsiz-uyar-sonra.txt` (bu dal, `ISKAN_EY_DUSME=uyar`): sarı uyarı + plan, **rc=3**
