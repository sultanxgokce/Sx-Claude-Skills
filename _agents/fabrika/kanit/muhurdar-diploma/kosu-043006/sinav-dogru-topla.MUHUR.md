# MÜHÜR — sinav-dogru-topla · deneme-1
kart: sinav-dogru-topla
deneme: 1
verdikt: GECTI
zaman_utc: 2026-10-22T01:30:23Z
worktree_head_sha: 1fec43783fc629ac910bbcb00b47791111f51502
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
| G1 | cmd | GECTI | 0 | kanit/G1.json (23f77408693959d848989822d941b503198e675d97e17d9520880f8fb3420b8d) |
| G2 | llm-yargi | GECTI | - | katman2 (izole-rubrik: rubrik.md) |

## Katman-2 (izole-rubrik sonuçları)
- G2: GECTI — BENIOKU.md, aracın iki tam sayının toplamını bastığını doğru açıklıyor ve 2 ile 3 örneğinde 5 çıktısı bu davranışla tutarlı; ayrıca yanlış bir iddia içermiyor.

## Entegrasyon
- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`
  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.
- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.
