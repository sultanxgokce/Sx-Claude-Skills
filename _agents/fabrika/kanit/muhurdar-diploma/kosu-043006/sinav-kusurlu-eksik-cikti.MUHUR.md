# MÜHÜR — sinav-kusurlu-eksik-cikti · deneme-1
kart: sinav-kusurlu-eksik-cikti
deneme: 1
verdikt: KALDI
zaman_utc: 2026-10-22T01:30:31Z
worktree_head_sha: 199f2daacf3d2bee3a7626b005b55695e9ac51b2
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
| G1 | cmd | KALDI | 1 | kanit/G1.json (8518a8b063a39c2c5914810c7b7fb6274c230ce882708eb32971fe29afead2ce) |
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
- G2: GECTI — Rapor anlaşılır Türkçeyle yazılmıştır; yapılan iş olarak giriş ekranının yenilenmesi ve eski düğmelerin kaldırılması, açık iş olarak bildirim ayarlarının taşınmamış olması somut biçimde belirtilmiştir.

## Entegrasyon
- Kart-durum flip'ini tescil YAPMAZ — verdikt raporlanır; flip `scripts/dongu-sayac.sh`
  → tek-boğaz GECISLER-route yolundadır. dongu-sayac `gecti|kaldi` MUHUR.md-varlık şartlıdır.
- Telemetri: `scripts/telemetri-append.sh` → `_agents/tescil/telemetri.jsonl`.
