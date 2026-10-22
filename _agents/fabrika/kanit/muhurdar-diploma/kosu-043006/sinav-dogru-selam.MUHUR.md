# MÜHÜR — sinav-dogru-selam · deneme-1
kart: sinav-dogru-selam
deneme: 1
verdikt: GECTI
zaman_utc: 2026-10-22T01:30:16Z
worktree_head_sha: a31914b43281d9c547d2680545b3b4daa17688da
gereklilik_sha256: 27103d52413ef23861d6aee048d8bc8ef3ec5c9847443056f535414b35eef9f5
tip: docs
vites: TAM
tescil_skill_version: 0.3.0
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
| G1 | cmd | GECTI | 0 | kanit/G1.json (90cfcb5ce79543695c750b34a3eb71d5c7594078275bc5beb3d4409cb7a1795d) |
| G2 | llm-yargi | GECTI | - | katman2 (izole-rubrik: rubrik.md) |

## Katman-2 (izole-rubrik sonuçları)
- G2: GECTI — karsilama.md açıkça “Hoş geldiniz” ve “Merhaba” diyerek karşılıyor, ilk somut adım olarak dosyayı okuyup `notlar/` altında kendi adıyla not açmayı yönlendiriyor ve kaba, alaycı ya da ilgisiz ifade içermiyor.

## Entegrasyon
- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`
  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.
- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.
