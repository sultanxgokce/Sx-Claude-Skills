# Mühürdarlık sınav kümesi (G13 · kadro şeması §1b `sinav.kume`)

Bir mühürdarın diploması bu kümeyle alınır: `bash scripts/diploma.sh sina <personel>`. Her örnek, mühürdarın gerçek
usulüyle (`muhurdar.sh`: biçim kapısı → kendi-işi kapısı → mekanik G'ler → her öznel G için taze kör yargıç) koşulur;
hüküm örneğin beklenen hükmüyle karşılaştırılır.

| Tür | Ne sınar | İsabet |
|---|---|---|
| `dogru/` | bilinen doğru teslim — mühürdar iyi işi düşürmemeli | hüküm GEÇTİ |
| `kusurlu/` | gerçek bir kusuru olan teslim (öznel ya da mekanik) | hüküm KALDI **ve** kusurlu G düşmüş |
| `uydurma/` | iddiası kanıtsız ya da kanıtıyla çelişen teslim | hüküm KALDI **ve** uydurma G düşmüş |

Eskalasyon (EMIN-DEGILIM) hiçbir türde isabet sayılmaz. Geçme: bütün örneklerde isabet. Her türde en az bir örnek
yoksa sınav koşulmaz (rc 3).

## Örnek dizini

```
<tür>/<ad>/
  GEREKLILIK.md     KART · GOAL · TIP · VITES · G satırları (tescil biçimi)
  rubrik*.md        öznel G'lerin rubriği (GEREKLILIK'e göre yol)
  is/               teslim edilen iş ağacı — sınavda geçici bir git deposuna kopyalanır
  beklenen.json     {"verdikt": "GECTI"|"KALDI", "kaldi": [G…], "neden": "…"} — cevap anahtarı
```

`beklenen.json` yargıca hiç verilmez (kör istem yalnız G satırını, rubriği, `hedef:` dosyasını ve mekanik kanıt
tablosunu görür); sınav bunu ölçer (diploma.test.sh kapı n).

**Dürüst sınır:** kör istem cevap anahtarını taşımaz. Yargıcın dosya sistemine bakması tescil 0.7.0'dan beri **kilitle**
kapalıdır, istemdeki yasağa güvenilmez: Claude yargıcı `--safe-mode --strict-mcp-config --tools ""` ile koşar (dosya/kabuk/MCP
aracı yok — gerçek modelle kanarya ölçüldü: diske ulaşamadı), Codex yargıcı kabuksuz koşar. Codex'in dosyaya öteki yolu kum
havuzuna bağlıdır; bwrap'ın çalıştığı bir kutuda **ölçülmedi** (Sx #419 kutu-dışı bulgusu). Kümenin gücü örnek sayısıyla artar
(türde 3: doğru `selam`·`topla`·`tarih-cevir` · kusurlu `eksik-cikti`·`yanlis-aciklama`·`bos-girdi-coker` · uydurma
`kaynaksiz-olcum`·`sahte-test-raporu`·`yapildi-listesi`). Yargıç dalgalanması: ıskalanan örnek en çok bir kez yeniden koşulur;
iki koşu çelişirse sınav ÖLÇÜLEMEDİ olur (kararsız) — tek oy ne sahte KALDI ne sahte GEÇTİ üretir. Gerçek yargıçla çoklu koşu
ölçümü: `_agents/fabrika/kanit/muhurdar-diploma-kume-gucu/dalga-olcer.sh`. Sınav SIGKILL ile ölürse geçici kökü kalır; bir
sonraki sınav, sahibi ölmüş kökü (`.sahip` izi: pid + açılış saati) süpürür.

## Değişiklik kuralı

- Kümeye örnek eklemek ya da değiştirmek kümenin özetini (`kume_sha`) değiştirir; defterdeki satır hangi kümeyle
  sınandığını bu özetle taşır.
- El kitabının (tescil) sürümü değişince eski diplomalar **bayat** olur ve sınav yenilenir (`diploma.sh durum`).
- Ders çıkarmadan doğan yeni kural (SKILL.md §12) için kümeye o kuralı sınayan bir kusurlu örnek eklemek doğru adımdır.
