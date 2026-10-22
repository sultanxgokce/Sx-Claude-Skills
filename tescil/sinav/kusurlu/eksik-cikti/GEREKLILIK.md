KART: sinav-kusurlu-eksik-cikti
GOAL: üç bölümlü haftalık rapor (yapılanlar, açık işler, riskler)
TIP: docs
VITES: TAM
G1: rapor üç bölüm içerir
  tur: cmd
  komut: test "$(grep -c '^## ' rapor.md)" -ge 3
  davranis: evet
G2: rapor anlaşılır ve somut
  tur: llm-yargi
  rubrik: rubrik.md
  hedef: rapor.md
