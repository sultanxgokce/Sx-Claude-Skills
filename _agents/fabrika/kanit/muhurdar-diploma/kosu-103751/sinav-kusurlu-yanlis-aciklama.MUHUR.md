# MÜHÜR — sinav-kusurlu-yanlis-aciklama · deneme-1
kart: sinav-kusurlu-yanlis-aciklama
deneme: 1
verdikt: KALDI
zaman_utc: 2026-10-22T07:38:31Z
worktree_head_sha: 7dda43f10fbb2a3cc4b994e9e2f58ab1b768b651
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
yargic: G2=codex→claude
kor: evet (yargıç yalnız gereklilik + taze kanıt + hedef dosyayı gördü)

## G-özet
| G | tur | sonuc | rc | kanit (sha256) |
|---|-----|-------|----|----------------|
| G1 | cmd | GECTI | 0 | kanit/G1.json (382d5336d144173764d2e445ed963ff2e5cbfe723e972a93e513879c778f9449) |
| G2 | llm-yargi | KALDI | - | katman2 (izole-rubrik: rubrik.md) |

## KALDI-paketi
> Motora dönen TEK içerik budur (iç-muhakeme verbatim dönmez — SKILL.md §6).
### G2
- katman2: KALDI (BENIOKU.md aracın iki sayının "çarpımlarını" bastığını ve "2 3 → 6" örneğini veriyor; araç ise toplamı basıyor (2 ve 3 için 5), negatif sayıları sıfır saydığı iddiası da rubrikte desteklenmiyor, yani açıklama yanlış ve tutarsız iddialar içeriyor.)
- sinif: İŞ-EKSİK  <!-- varsayılan -->

## Katman-2 (izole-rubrik sonuçları)
- G2: KALDI — BENIOKU.md aracın iki sayının "çarpımlarını" bastığını ve "2 3 → 6" örneğini veriyor; araç ise toplamı basıyor (2 ve 3 için 5), negatif sayıları sıfır saydığı iddiası da rubrikte desteklenmiyor, yani açıklama yanlış ve tutarsız iddialar içeriyor.

## Entegrasyon
- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`
  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.
- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.
