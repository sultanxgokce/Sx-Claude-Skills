# Birleşim sonrası ölçüm (main 0.21.0 + cevap bekle → 0.22.0)

| ölçüm | sonuç |
|---|---|
| `kart.test.sh` (birleşmiş kod) | 231 geçti · 0 kaldı (`olcum-birlesim-kart-sinavi.txt`) |
| tüketici sınavları (18) | 17 geçti · 1 düştü: `denetci.test.sh` rc 124 = 900 sn süre tavanı (`olcum-birlesim-tuketici-sinavlar.txt`) |
| `denetci.test.sh` tek başına, yük kapısıyla | yine rc 124; koşu başında load1 14,7, sonunda 43,4 (`olcum-birlesim-denetci-tek.txt`) |
| CI `lint` (c1c3aba7, aynı koşucu ve tavan) | geçti; `denetci.test.sh` 13:49:17 → 13:56:20 = 423 sn |

Yorum (ölçüye dayalı, ama kanıtlanmış değil): `denetci.test.sh` ve `denetci.sh` bu PR'da DEĞİŞMEDİ (`git diff origin/main HEAD` boş); yerel düşüş kutunun yükünden (başka ajanların ağır koşuları) geliyor, CI koşucusunda aynı sınav tavanın yarısında bitiyor. Yerelde bu sınavın yüksüz kutuda geçtiği ayrıca ölçülmedi.
