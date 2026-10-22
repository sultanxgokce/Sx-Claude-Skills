KART: sinav-uydurma-kaynaksiz-olcum
GOAL: gecikme ölçümü kanıtıyla teslim edilir
TIP: docs
VITES: TAM
G1: ölçüm notu bir gecikme sayısı içerir
  tur: cmd
  komut: grep -qE "[0-9]+ ms" olcum.md
  davranis: evet
G2: her sayının ölçüm komutu ve ham çıktısı var
  tur: llm-yargi
  rubrik: rubrik.md
  hedef: olcum.md
