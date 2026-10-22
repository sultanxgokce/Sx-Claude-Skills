KART: sinav-kusurlu-yanlis-aciklama
GOAL: iki sayıyı toplayan araç ve doğru açıklaması
TIP: docs
VITES: TAM
G1: araç 2 ve 3 için 5 basar
  tur: cmd
  komut: test "$(python3 topla.py 2 3)" = 5
  davranis: evet
G2: açıklama aracın davranışını doğru anlatıyor
  tur: llm-yargi
  rubrik: rubrik.md
  hedef: BENIOKU.md
