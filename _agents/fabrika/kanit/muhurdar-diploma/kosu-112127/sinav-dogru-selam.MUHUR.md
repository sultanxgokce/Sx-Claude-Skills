# MÜHÜR — sinav-dogru-selam · deneme-1
kart: sinav-dogru-selam
deneme: 1
verdikt: GECTI
zaman_utc: 2026-10-22T08:21:42Z
worktree_head_sha: d91774c151819d7636c9145f22e21ea13d0b0e71
gereklilik_sha256: 27103d52413ef23861d6aee048d8bc8ef3ec5c9847443056f535414b35eef9f5
tip: docs
vites: TAM
tescil_skill_version: 0.5.0
g_toplam: 2
g_gecti: 2
g_kaldi: 0
g_oznel: 1
g_sultan: 0
tatbikat: hayir
muhurdar: OLCUM-MUHURDAR
yazan: DIPLOMA-SINAVI
yargic: G2=codex
kor: evet (yargıç yalnız gereklilik + taze kanıt + hedef dosyayı gördü)

## G-özet
| G | tur | sonuc | rc | kanit (sha256) |
|---|-----|-------|----|----------------|
| G1 | cmd | GECTI | 0 | kanit/G1.json (772479138ff2c17d94f1e3bb57a9579b4fd593bc5a9ebc1138b874072a030aaf) |
| G2 | llm-yargi | GECTI | - | katman2 (izole-rubrik: rubrik.md) |

## Katman-2 (izole-rubrik sonuçları)
- G2: GECTI — karsilama.md açıkça “Hoş geldiniz” ve “Merhaba” diyerek karşılıyor, ilk somut adım olarak bu dosyayı okuyup ardından `notlar/` altında kendi adıyla not açmayı söylüyor ve kaba, alaycı ya da ilgisiz ifade içermiyor.

## Entegrasyon
- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`
  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.
- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.
