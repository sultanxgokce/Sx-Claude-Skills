# k0078 İSKÂN FAZ-8 — G1-G10 öz-koşu özeti (MOTORSERDAR, 2026-07-16)

Tümü çıplak-komut + exit-echo; G6-G10 cloudtop origin/main'den (PR #59 merge = e6f290f).

| G | Ne | Sonuç |
|---|---|---|
| G1 | ahi check iskan | exit=0 |
| G2 | evergreen-kaydet iskantest --dry-run | rc=3 + 'evergreen-onizleme' + EKLENECEK diff |
| G3 | iskan.test.sh | 73/73, exit=0 |
| G4 | kayıtsız-proje --apply | rc=1 + 'kayitsiz-proje' + manifest md5 önce=sonra |
| G5 | iskantest --apply 2.+ koşu | rc=0 no-op ('mevcut → atla') |
| G6 | origin/main provider-inventory | iskantest ingress≥1 VE access_apps≥1 (iki ayrı bölüm), exit=0 |
| G7 | origin/main backup.sh | cloudtop-iskantest + cloudtop-huma + bash -n, exit=0 |
| G8 | origin/main parity (mktemp) | [OK] P8-CONTAINER 7-container · [OK] P9-CFAPP 8-hostname, exit=0 |
| G9 | drift-inject-test.sh | 9/9 (P8-DRIFT ✓ · P9-DRIFT ✓ ayrı-enjeksiyon · izolasyon ✓ · repo md5-eş ✓) |
| G10 | iki-repo kapsam | Sx yalnız iskan/** = 0 · cloudtop k0078-commit yalnız 4-dosya = 0 |

Not: MÜHÜRDAR kör-tescilde G'leri kendisi yeniden koşar; bu özet motor-tarafı kanıt-izi.
FAZ-9-söküm-borcu: iskantest evergreen-satırları İSKÂN-BİTTİ öncesi söküm-reçetesiyle geri-alınacak (ayrı-kart).
