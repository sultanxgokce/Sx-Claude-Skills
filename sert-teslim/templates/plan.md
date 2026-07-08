---
feature: "{{feature}}"
baglam_pointer: "{{harness-kriteri-ya-da-tek-cumle-hedef}}"
vites: "{{HAFIF|TAM}}"
kaynak_talimat: |
  {{is-sahibinin-HAM-SOZU-VERBATIM — paraphrase YASAK; birden-cok-mesajsa her biri ayri, tarihli blok}}
tamlik_onayi:
  soru: "bu iş için söylediklerinin TAMAMI bu mu?"
  cevap: "{{evet | hayir → eksik-soz-VERBATIM kaynak_talimat'a eklenir, soru yeniden sorulur}}"
  tarih: "{{YYYY-MM-DD}}"
---

# PLAN — {{feature}}

{{plan-metni — mevcut plan-dokümanı varsa buraya (ya da pointer'ı); yoksa KUR-röportajıyla üretilir
ve iş-sahibi onaylar. ONAY-1 sonrası bu metinden türeyen gereklilikler DOKUNULMAZDIR; ek talimat
TALIMAT-GUNLUGU.md üzerinden append-only akar.}}
