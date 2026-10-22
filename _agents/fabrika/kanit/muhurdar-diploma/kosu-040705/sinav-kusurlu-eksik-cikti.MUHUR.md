# MÜHÜR — sinav-kusurlu-eksik-cikti · deneme-1
kart: sinav-kusurlu-eksik-cikti
deneme: 1
verdikt: KALDI
zaman_utc: 2026-10-22T01:07:28Z
worktree_head_sha: bd153b12e6653361a916f389dc21fc64a7c9c80b
gereklilik_sha256: 36af4017341cc0b04e6a35893d09a9e2349b15ff94894bf22006062ba5e0a79e
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
| G1 | cmd | KALDI | 1 | kanit/G1.json (9432e23fe60b00a31d21fe79b9a759626122876233a63aad3b224d158ec2412c) |
| G2 | llm-yargi | GECTI | - | katman2 (izole-rubrik: rubrik.md) |

## KALDI-paketi
> Motora dönen TEK içerik budur (iç-muhakeme verbatim dönmez — SKILL.md §6).
### G1
- komut: `test "$(grep -c '^## ' rapor.md)" -ge 3`
- beklenen: rc=0
- gozlenen: rc=1
- cikti_kuyrugu (redakte, ≤2KB):
```

```
- sinif: İŞ-EKSİK  <!-- varsayılan; GEREKLİLİK-MUĞLAK teşhisi = gerekçe + düzeltme-diff'i şart (SKILL.md §6) -->

## Katman-2 (izole-rubrik sonuçları)
- G2: GECTI — “Giriş ekranı yenilendi; eski düğmeler kaldırıldı.” ve “Bildirim ayarları henüz taşınmadı.” ifadeleri anlaşılır Türkçeyle yazılmış somut cümlelerdir.

## Entegrasyon
- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`
  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.
- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.
