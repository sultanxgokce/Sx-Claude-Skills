<!-- MANŞET-KURALI (teslim-lint denetler): teslim KISMİ ise aşağıdaki manşet İLK-SATIR olmak
     ZORUNDADIR: "{{X}}/{{Y}} gereklilik KANITSIZ — TESLİM EDİLMEDİ". TAM-teslimde manşet:
     "TESLİM: {{Y}}/{{Y}} gereklilik kanıtlı". Bu yorum-bloğu örnekleme sırasında silinir. -->
# {{manset}}

- feature: {{feature}} · vites: {{HAFIF|TAM}} · iter-sayısı: {{iter_no}}
- tarih: {{ISO-timestamp}} · skill_version: {{skill_version}}
- config: {{config_yolu}} · state: {{state_dizini}}

## Matris-özeti

| toplam-M | kanitli | fail | bekliyor | engelli | OLCULEMEZ |
|---|---|---|---|---|---|
| {{n}} | {{n}} | {{n}} | {{n}} | {{n}} | {{n}} |

Tam matris (kanıt-linkli): {{MATRIS.md-yolu}} · kanıt-JSON dizini: {{kanit-dizini-yolu}}

## Adversarial (teslim-gate koşul-2 + koşul-3)

- A1 + A2-tam + A3-tam (worktree-izole) wf-referansı: {{wf-id}}
- Önceki guard-suite'ler intact: {{evet|hayir+isimli-liste}}
- A4-MUTABAKAT: sınıflandırma-tablosu {{a4-tablo-yolu}} · sayımsal-lint sonucu: {{rc + özet}}
- "normatif-değil" sayılan cümleler (iş-sahibi veto-yüzeyi): {{isimli-liste | yok}}

## Canlı-smoke (koşul-4)

- stack-script koşum-ref: {{ref}} · yüzeyler: {{surface_id-listesi}}
- Kapsam-beyanı — sınadı: {{...}} · SINAMADI: {{...}}

## Açık-bulgu kesişimi (koşul-5)

{{dokunulan-yüzeyle-kesişen-açık-bulgular-İSİMLİ | yok}}

## Disclaimers — veri-rejimi (koşul-6)

{{config.disclaimers + sentetik/mock-kanıtlı-satırların-kalıcı-beyanı}}

## Cost-özeti

- iter: {{n}} · adversarial-koşum: {{n}} · yaklaşık-token: {{girdi/çıktı}} · eskalasyon: {{n}}
