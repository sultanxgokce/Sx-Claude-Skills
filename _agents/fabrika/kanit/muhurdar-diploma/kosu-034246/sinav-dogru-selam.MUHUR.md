# MÜHÜR — sinav-dogru-selam · deneme-1
kart: sinav-dogru-selam
deneme: 1
verdikt: GECTI
zaman_utc: 2026-10-22T00:43:04Z
worktree_head_sha: b1a5d2fc9bf053cf6041861dce2191dd391c8078
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
yargic: G2=codex→claude
kor: evet (yargıç yalnız gereklilik + taze kanıt + hedef dosyayı gördü)

## G-özet
| G | tur | sonuc | rc | kanit (sha256) |
|---|-----|-------|----|----------------|
| G1 | cmd | GECTI | 0 | kanit/G1.json (01d0651dd0a29449500ae431afec3d608d81da569a635594cd3f034b9730a6ea) |
| G2 | llm-yargi | GECTI | - | katman2 (izole-rubrik: rubrik.md) |

## Katman-2 (izole-rubrik sonuçları)
- G2: GECTI — karsilama.md rubriğin üç şartını da karşılıyor: "Hoş geldiniz" başlığı ve "Merhaba!" selamı var, yeni geleni somut adımlara yönlendiriyor (önce bu dosyayı okuyacak, sonra `notlar/` altına kendi adıyla not açacak, sorusunu ekip kanalına yazacak) ve kaba, alaycı ya da konu dışı bir cümle içermiyor.

## Entegrasyon
- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`
  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.
- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.
