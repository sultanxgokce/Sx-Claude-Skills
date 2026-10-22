# MÜHÜR — sinav-dogru-topla · deneme-1
kart: sinav-dogru-topla
deneme: 1
verdikt: GECTI
zaman_utc: 2026-10-22T07:58:13Z
worktree_head_sha: f01e927240b94dc90f3d64ce8477a3c166754bfb
gereklilik_sha256: d33b1b67732d648155c63faca733394a764841148d24ccd04ca076a82c10ac99
tip: docs
vites: TAM
tescil_skill_version: 0.5.0
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
| G1 | cmd | GECTI | 0 | kanit/G1.json (62b595f3841347c9c6afba053af3c62c21470e6c8dacf33bdef2aba3bff374a2) |
| G2 | llm-yargi | GECTI | - | katman2 (izole-rubrik: rubrik.md) |

## Katman-2 (izole-rubrik sonuçları)
- G2: GECTI — BENIOKU.md aracın iki tam sayının toplamını bastığını doğru söylüyor ve 2 ile 3 için 5 örneği bu davranışla tutarlı; ayrıca araç hakkında yanlış bir iddia görünmüyor.

## Entegrasyon
- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`
  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.
- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.
