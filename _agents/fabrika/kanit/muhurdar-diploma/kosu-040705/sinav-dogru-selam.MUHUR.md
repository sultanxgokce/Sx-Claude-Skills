# MÜHÜR — sinav-dogru-selam · deneme-1
kart: sinav-dogru-selam
deneme: 1
verdikt: GECTI
zaman_utc: 2026-10-22T01:07:17Z
worktree_head_sha: bc4b976eb70e5c65158bd88e4f6d2af9821af7c6
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
| G1 | cmd | GECTI | 0 | kanit/G1.json (427d40a54b25397375d3bd94be1afadaba545efa8a4781f25d9fede1432b788e) |
| G2 | llm-yargi | GECTI | - | katman2 (izole-rubrik: rubrik.md) |

## Katman-2 (izole-rubrik sonuçları)
- G2: GECTI — “Hoş geldiniz” ve “Merhaba” ile açıkça karşılıyor; ilk somut adım olarak bu dosyayı okumayı, ardından `notlar/` altında kendi adıyla not açmayı söylüyor ve kaba, alaycı ya da ilgisiz ifade içermiyor.

## Entegrasyon
- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`
  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.
- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.
