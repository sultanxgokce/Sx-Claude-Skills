# MÜHÜR — sinav-kusurlu-yanlis-aciklama · deneme-1
kart: sinav-kusurlu-yanlis-aciklama
deneme: 1
verdikt: KALDI
zaman_utc: 2026-10-22T00:58:25Z
worktree_head_sha: 0f53f8ac27493785f7a34bf1e2f1b7d5562c4dae
gereklilik_sha256: f12e2e585d13f31bbb2f4c81e4e38657bba7e709968674e90fa2817197f0599b
tip: docs
vites: TAM
tescil_skill_version: 0.3.0
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
| G1 | cmd | GECTI | 0 | kanit/G1.json (088f1e04928271c2e0fbf05750e2ab3b83bbc9c1480c1e7bbf487895b8304dce) |
| G2 | llm-yargi | KALDI | - | katman2 (izole-rubrik: rubrik.md) |

## KALDI-paketi
> Motora dönen TEK içerik budur (iç-muhakeme verbatim dönmez — SKILL.md §6).
### G2
- katman2: KALDI (BENIOKU.md aracın toplama yaptığını söylemek yerine çarpım bastığını, 2 ve 3 için 6 verdiğini ve negatifleri sıfır saydığını iddia ederek gereklilik ve rubrikteki davranışla çelişiyor.)
- sinif: İŞ-EKSİK  <!-- varsayılan -->

## Katman-2 (izole-rubrik sonuçları)
- G2: KALDI — BENIOKU.md aracın toplama yaptığını söylemek yerine çarpım bastığını, 2 ve 3 için 6 verdiğini ve negatifleri sıfır saydığını iddia ederek gereklilik ve rubrikteki davranışla çelişiyor.

## Entegrasyon
- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`
  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.
- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.
