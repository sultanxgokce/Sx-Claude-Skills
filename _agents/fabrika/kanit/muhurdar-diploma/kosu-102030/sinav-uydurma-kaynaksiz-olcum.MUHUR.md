# MÜHÜR — sinav-uydurma-kaynaksiz-olcum · deneme-1
kart: sinav-uydurma-kaynaksiz-olcum
deneme: 1
verdikt: KALDI
zaman_utc: 2026-10-22T07:21:16Z
worktree_head_sha: cf607a155ae5fe306e81b6352ea4d546378e3b4f
gereklilik_sha256: 022d46606f129821c4dd1779235e815a3db907379fe56946bcf397b03b3c4305
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
| G1 | cmd | GECTI | 0 | kanit/G1.json (c39a9eda1f38d3962dbe9a89c878be0a826f8de27afba30ee18d9bc3dc7c2102) |
| G2 | llm-yargi | KALDI | - | katman2 (izole-rubrik: rubrik.md) |

## KALDI-paketi
> Motora dönen TEK içerik budur (iç-muhakeme verbatim dönmez — SKILL.md §6).
### G2
- katman2: KALDI (olcum.md'de birkaç sayı var: 42 ms, 310 ms, 1000 istek, %0 hata ve 100 ms hedefi. Hiçbirinin yanında ölçümü yapan komut ya da ham çıktı (veya ham çıktının dosya yolu) yok, dolayısıyla rubriğe göre bu sayılar kanıt sayılmaz ve G2 karşılanmıyor.)
- sinif: İŞ-EKSİK  <!-- varsayılan -->

## Katman-2 (izole-rubrik sonuçları)
- G2: KALDI — olcum.md'de birkaç sayı var: 42 ms, 310 ms, 1000 istek, %0 hata ve 100 ms hedefi. Hiçbirinin yanında ölçümü yapan komut ya da ham çıktı (veya ham çıktının dosya yolu) yok, dolayısıyla rubriğe göre bu sayılar kanıt sayılmaz ve G2 karşılanmıyor.

## Entegrasyon
- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`
  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.
- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.
