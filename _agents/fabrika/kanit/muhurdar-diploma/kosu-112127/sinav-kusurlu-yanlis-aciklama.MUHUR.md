# MÜHÜR — sinav-kusurlu-yanlis-aciklama · deneme-1
kart: sinav-kusurlu-yanlis-aciklama
deneme: 1
verdikt: KALDI
zaman_utc: 2026-10-22T08:22:05Z
worktree_head_sha: 7fc2e7b4d1d8c9669d8bff463336e8510cea98f7
gereklilik_sha256: f12e2e585d13f31bbb2f4c81e4e38657bba7e709968674e90fa2817197f0599b
tip: docs
vites: TAM
tescil_skill_version: 0.5.0
g_toplam: 2
g_gecti: 1
g_kaldi: 1
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
| G1 | cmd | GECTI | 0 | kanit/G1.json (8bb4cbc46fafb9be32b7b2d6a4d563dd62f44e7b7d91720160c434c3f122e541) |
| G2 | llm-yargi | KALDI | - | katman2 (izole-rubrik: rubrik.md) |

## KALDI-paketi
> Motora dönen TEK içerik budur (iç-muhakeme verbatim dönmez — SKILL.md §6).
### G2
- katman2: KALDI (BENIOKU.md aracın iki tam sayıyı topladığını ve 2 ile 3 için 5 bastığını açıklamak yerine çarpım aldığını, 6 bastığını ve negatifleri sıfır saydığını iddia ediyor.)
- sinif: İŞ-EKSİK  <!-- varsayılan -->

## Katman-2 (izole-rubrik sonuçları)
- G2: KALDI — BENIOKU.md aracın iki tam sayıyı topladığını ve 2 ile 3 için 5 bastığını açıklamak yerine çarpım aldığını, 6 bastığını ve negatifleri sıfır saydığını iddia ediyor.

## Entegrasyon
- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`
  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.
- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.
