# MÜHÜR — sinav-kusurlu-eksik-cikti · deneme-1
kart: sinav-kusurlu-eksik-cikti
deneme: 1
verdikt: KALDI
zaman_utc: 2026-10-22T08:21:58Z
worktree_head_sha: cb9a1875ec5a38da49175b410ea61b1d03b430d4
gereklilik_sha256: 36af4017341cc0b04e6a35893d09a9e2349b15ff94894bf22006062ba5e0a79e
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
| G1 | cmd | KALDI | 1 | kanit/G1.json (34726a48cc66a14e4e98c0c948d9a080423c863e0dd398a22d3a6df8078511de) |
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
- G2: GECTI — Yapılanlar ve açık işler bölümlerindeki cümleler anlaşılır Türkçeyle tamamlanan ve bekleyen somut işleri belirtmektedir; G1’deki bölüm sayısı eksikliği bu rubrikte ölçülmez.

## Entegrasyon
- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`
  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.
- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.
