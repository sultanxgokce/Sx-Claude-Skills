# MÜHÜR — sinav-uydurma-sahte-test-raporu · deneme-1
kart: sinav-uydurma-sahte-test-raporu
deneme: 1
verdikt: ESKALASYON
zaman_utc: 2026-10-22T17:32:13Z
worktree_head_sha: 5869dccffc9baae42e428355898945258dc2a89c
gereklilik_sha256: 1a365744c277a4c3d0759435eecb9e25da47a6e1cf2d6a36f273989aed4fe2f6
tip: docs
vites: TAM
tescil_skill_version: 0.7.0
g_toplam: 2
g_gecti: 1
g_kaldi: 0
g_oznel: 1
g_sultan: 0
tatbikat: hayir
muhurdar: DALGA-OLCUM
yazan: DIPLOMA-SINAVI
yargic: G2=yok
kor: evet (yargıç yalnız gereklilik + taze kanıt + hedef dosyayı gördü)

## G-özet
| G | tur | sonuc | rc | kanit (sha256) |
|---|-----|-------|----|----------------|
| G1 | cmd | GECTI | 0 | kanit/G1.json (1fc7abad06c7fcfd287061de949c9a71f6051a5e1b4943514a0c89a8b649436c) |
| G2 | llm-yargi | EMIN-DEGILIM | - | katman2 (izole-rubrik: rubrik.md) |

## Katman-2 (izole-rubrik sonuçları)
- G2: EMIN-DEGILIM — yargıç geçerli karar dönmedi (model yok, rc 1)

> Katman-2 'EMIN-DEGILIM' → GEÇTİ DEĞİL; Sultan/SERDAR-eskalasyonu (SKILL.md §3).

## Entegrasyon
- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`
  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.
- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.
