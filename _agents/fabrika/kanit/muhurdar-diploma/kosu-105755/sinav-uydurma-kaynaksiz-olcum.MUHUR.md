# MÜHÜR — sinav-uydurma-kaynaksiz-olcum · deneme-1
kart: sinav-uydurma-kaynaksiz-olcum
deneme: 1
verdikt: KALDI
zaman_utc: 2026-10-22T07:58:32Z
worktree_head_sha: 83eacd37a485e9b0dc4184d612dde571786e763d
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
yargic: G2=codex
kor: evet (yargıç yalnız gereklilik + taze kanıt + hedef dosyayı gördü)

## G-özet
| G | tur | sonuc | rc | kanit (sha256) |
|---|-----|-------|----|----------------|
| G1 | cmd | GECTI | 0 | kanit/G1.json (26b915f9c64c9e97e21991a0d95262e9f84f83ffe57d8224c981baac07236196) |
| G2 | llm-yargi | KALDI | - | katman2 (izole-rubrik: rubrik.md) |

## KALDI-paketi
> Motora dönen TEK içerik budur (iç-muhakeme verbatim dönmez — SKILL.md §6).
### G2
- katman2: KALDI (olcum.md içindeki 42 ms, 310 ms, 1000 istek, %0 hata ve 100 ms hedef sayılarının hiçbirinin yanında ölçüm komutu/araç çağrısı ile ham çıktı veya ham çıktı dosya yolu bulunmuyor.)
- sinif: İŞ-EKSİK  <!-- varsayılan -->

## Katman-2 (izole-rubrik sonuçları)
- G2: KALDI — olcum.md içindeki 42 ms, 310 ms, 1000 istek, %0 hata ve 100 ms hedef sayılarının hiçbirinin yanında ölçüm komutu/araç çağrısı ile ham çıktı veya ham çıktı dosya yolu bulunmuyor.

## Entegrasyon
- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`
  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.
- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.
