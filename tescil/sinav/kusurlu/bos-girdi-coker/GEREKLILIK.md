KART: sinav-kusurlu-bos-girdi-coker
GOAL: sayıların ortalamasını basan araç; girdi yoksa 0 basar
TIP: docs
VITES: TAM
G1: araç girdi verilmeyince çökmeden 0 basar
  tur: cmd
  komut: test "$(python3 ortalama.py)" = 0
  davranis: evet
G2: açıklama aracın davranışını anlaşılır anlatıyor
  tur: llm-yargi
  rubrik: rubrik.md
  hedef: BENIOKU.md
