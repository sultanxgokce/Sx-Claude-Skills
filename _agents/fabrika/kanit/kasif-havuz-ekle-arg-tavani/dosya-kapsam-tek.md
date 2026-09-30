# kasif-havuz-ekle-arg-tavani — kapsam, karar, kanıt (2026-09-30 · SERDAR)

## İstek
NÂZIR (ÇAVUŞ tetiği 212239d9, s13→s01): `kasif-havuz-ekle.sh` havuz listelerini jq'ya `--argjson` ile TEK argüman
geçiriyordu; Linux tek argümanı 131 072 baytta keser. 23 Eylül'de nazir havuzunda anahtar listesi 131 218 bayta çıktı →
rc 126, havuza 7 gün yazılamadı. NÂZIR düzeltmeyi ortak beceri dizinindeki KURULU kopyada yaptı (Sultan onayı, kör
inceleme 5·E, sınav 47/47) ve kaynağa işlenmesini istedi: eşitleme aksi hâlde düzeltmeyi geri alır.

## Ölçüm (bu iş başında)
Kurulu `kasif-tara` ↔ ana dal: yalnız iki dosya farklı — `kasif-havuz-ekle.sh` (19 satır) ve `kasif-havuz-ekle.test.sh`
(46 satır), ikisi de 30 Eyl 10:06 damgalı. Öbür 9 dosya bayt bayt aynı. (İlk ölçümüm yanlış yolla 11 dosya demişti;
pozitif kontrol yoktu. Deftere düzeltme yazıldı.)

## Bu işte ne var
| Parça | Ne |
|---|---|
| `kasif-tara/scripts/kasif-havuz-ekle.sh` | üç `--argjson` → `--slurpfile` (süreç ikamesi) + `[0]` sarmal açma + KARAR notu — kurulu kopyadan bire bir |
| `kasif-tara/scripts/kasif-havuz-ekle.test.sh` | T-ARG: 1200 kayıtlık havuz + 900 kayıtlık kütüphane + 1500 kayıtlık tekrar defteri; fikstürün tavanı AŞTIĞI ölçülür, aşmıyorsa kapı kendini kırmızıya çeker |
| `kasif-tara/SKILL.md` | sürüm 1.4.1 → 1.4.2 + sınır notu |

`catalog.json`'da yalnız `kasif-tara` sürüm satırı 1.4.2 yapıldı (denetim tur 1: sürüm artışı depo genelinde eksikti).
Dosya #256/#33'te de açık ama farklı satırlar; birleştirmede çakışmaz.

## Denetim turları
- **Tur 1 (4/5 E):** katalog sürümü eski kalmıştı → düzeltildi; kanıta katalog↔SKILL.md sürüm eşitliği ölçümü eklendi.

## Kanıt
| Ölçüm | Ne gösterir |
|---|---|
| sınav | 47 kapı yeşil (NÂZIR'ın sayısıyla aynı) |
| negatif | ana daldaki ESKİ araç aynı sınavda yalnız 3 tavan kapısında kırmızı (44 geçer), "Argument list too long" görünür → sınav gerçekten tavanı ölçüyor |
| kurulu = kaynak | çalışma kopyasındaki iki dosya kurulu kopyayla bayt bayt aynı |
| depo kapıları | `validate-repo --strict` · `version-lint` temiz |

## Bu işte OLMAYAN
- Kurulum yok (kurulu kopya zaten yeni; bu iş kaynağı ona eşitler). Birleşince `kurulu = kaynak` ölçümü yeniden yapılır, NÂZIR'a yazılır.
- "Kurulu kopyada yapılan düzeltme kaynağa nasıl otomatik döner" sorusu bu işin değil; aday havuzuna yazıldı.
