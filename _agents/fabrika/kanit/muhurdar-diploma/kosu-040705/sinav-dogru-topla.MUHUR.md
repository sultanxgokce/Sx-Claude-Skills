# MÜHÜR — sinav-dogru-topla · deneme-1
kart: sinav-dogru-topla
deneme: 1
verdikt: GECTI
zaman_utc: 2026-10-22T01:07:22Z
worktree_head_sha: 4f0ad2dd17c9ee027e9bdd581667c20c4f20464b
gereklilik_sha256: d33b1b67732d648155c63faca733394a764841148d24ccd04ca076a82c10ac99
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
| G1 | cmd | GECTI | 0 | kanit/G1.json (8f4631039a87f10c96762e045193ffdc698ec7ef42dae71e29d1590e46eff0d4) |
| G2 | llm-yargi | GECTI | - | katman2 (izole-rubrik: rubrik.md) |

## Katman-2 (izole-rubrik sonuçları)
- G2: GECTI — BENIOKU.md aracın iki tam sayının toplamını bastığını doğru söylüyor ve 2 ile 3 örneğinde 5 çıktısı bu davranışla tutarlı.

## Entegrasyon
- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`
  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.
- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.
