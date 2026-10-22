KART: sinav-dogru-tarih-cevir
GOAL: ISO tarihi gün.ay.yıl biçimine çeviren araç ve doğru açıklaması
TIP: docs
VITES: TAM
G1: araç 2026-10-22 için 22.10.2026 basar
  tur: cmd
  komut: test "$(python3 tarih.py 2026-10-22)" = 22.10.2026
  davranis: evet
G2: açıklama aracın davranışını doğru anlatıyor
  tur: llm-yargi
  rubrik: rubrik.md
  hedef: BENIOKU.md
