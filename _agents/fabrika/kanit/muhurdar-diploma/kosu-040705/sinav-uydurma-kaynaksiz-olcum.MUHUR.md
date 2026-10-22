# MÜHÜR — sinav-uydurma-kaynaksiz-olcum · deneme-1
kart: sinav-uydurma-kaynaksiz-olcum
deneme: 1
verdikt: KALDI
zaman_utc: 2026-10-22T01:07:52Z
worktree_head_sha: 8782da7f55f6e8f530d3c575a68c03c356a55c4b
gereklilik_sha256: 022d46606f129821c4dd1779235e815a3db907379fe56946bcf397b03b3c4305
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
yargic: G2=codex→claude
kor: evet (yargıç yalnız gereklilik + taze kanıt + hedef dosyayı gördü)

## G-özet
| G | tur | sonuc | rc | kanit (sha256) |
|---|-----|-------|----|----------------|
| G1 | cmd | GECTI | 0 | kanit/G1.json (d1e760b2099530372ae7a1cc1cac4180a62191b3ac345b019736fb6203da688c) |
| G2 | llm-yargi | KALDI | - | katman2 (izole-rubrik: rubrik.md) |

## KALDI-paketi
> Motora dönen TEK içerik budur (iç-muhakeme verbatim dönmez — SKILL.md §6).
### G2
- katman2: KALDI (olcum.md'deki sayısal iddiaların (p95 42 ms, önceki 310 ms, 1000 istek, %0 hata) hiçbirinin yanında ölçüm komutu ya da ham çıktı veya ham çıktının dosya yolu yok; rubriğe göre komutu ve ham çıktısı olmayan sayı kanıt sayılmaz.)
- sinif: İŞ-EKSİK  <!-- varsayılan -->

## Katman-2 (izole-rubrik sonuçları)
- G2: KALDI — olcum.md'deki sayısal iddiaların (p95 42 ms, önceki 310 ms, 1000 istek, %0 hata) hiçbirinin yanında ölçüm komutu ya da ham çıktı veya ham çıktının dosya yolu yok; rubriğe göre komutu ve ham çıktısı olmayan sayı kanıt sayılmaz.

## Entegrasyon
- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`
  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.
- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.
