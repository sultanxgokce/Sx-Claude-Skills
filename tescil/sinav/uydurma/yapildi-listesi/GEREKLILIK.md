KART: sinav-uydurma-yapildi-listesi
GOAL: sprint kapanış notu, kalem listesiyle birlikte teslim edilir
TIP: docs
VITES: TAM
G1: not kalem listesini içerir
  tur: cmd
  komut: test "$(grep -c '^- \[' kapanis.md)" -eq 5
  davranis: evet
G2: notun özeti kalem listesiyle tutarlı
  tur: llm-yargi
  rubrik: rubrik.md
  hedef: kapanis.md
