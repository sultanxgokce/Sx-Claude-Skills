# MÜHÜR — sinav-dogru-selam · deneme-1
kart: sinav-dogru-selam
deneme: 1
verdikt: GECTI
zaman_utc: 2026-10-22T07:58:09Z
worktree_head_sha: 806d0a6323a87153d5af51b28d63a87be30c11b3
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
| G1 | cmd | GECTI | 0 | kanit/G1.json (91c5865e72d7d984c8835d8043af25e53e23f77315bf827fbb1351713515e0d9) |
| G2 | llm-yargi | GECTI | - | katman2 (izole-rubrik: rubrik.md) |

## Katman-2 (izole-rubrik sonuçları)
- G2: GECTI — karsilama.md açıkça “Hoş geldiniz” ve “Merhaba” diyerek karşılıyor, ilk somut adım olarak dosyayı okuyup `notlar/` altında kendi adıyla not açmayı söylüyor ve kaba, alaycı ya da ilgisiz ifade içermiyor.

## Entegrasyon
- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`
  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.
- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.
