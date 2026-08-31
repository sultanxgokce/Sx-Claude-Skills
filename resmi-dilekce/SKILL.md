---
name: resmi-dilekce
type: agent
version: 0.1.0
description: >
  Resmî Türk dilekçesini (kuruma/başhekimliğe/müdürlüğe hitaplı) tek komutta PDF + Word
  olarak üretir; tek sayfaya sığdırır, Türkçe karakteri gömülü fontla garantiler, üretilen
  PDF'i metin-okuyarak DOĞRULAR ve istenirse Ortak-hub klasörüne + WhatsApp'a düşürür.
  Kişi/kurum/gerekçe JSON'dan gelir; gövde şablon değil, o iş için yazılır.
  "dilekçe yaz / dilekçe hazırla / başhekimliğe dilekçe / kuruma dilekçe / şu talebi
  dilekçeye dök / pdf ve word olarak ver" tetiğinde çağrılır.
install_target:
  skills: .claude/skills/
stacks: ["*"]
---

# Resmî Dilekçe — PDF + Word üretici

Bir dilekçeyi **elle biçimlendirmeye çalışma.** Metni yaz, JSON'a koy, motoru çağır.

## Kullanım

```bash
D=/config/.claude/skills/resmi-dilekce/scripts

# 1) JSON'u yaz (şablon: reference/ornek.json)
# 2) Üret + Ayşe'nin Ortak klasörüne koy + WhatsApp'a at:
bash $D/dilekce.sh /tmp/dilekce.json --kisi Ayse --wa

# yalnız üret (bulunulan dizine):
bash $D/dilekce.sh /tmp/dilekce.json
```

| Bayrak | Ne yapar |
|---|---|
| `--kisi Ayse\|Sultan\|Fahri` | Çıktıyı `/config/evraklar/<Kişi>/Gelen/` altına koyar |
| `--wa` | PDF + DOCX'i WhatsApp'a gönderir (`whatsapp-gonder` skill'i üzerinden) |
| `--cikis DIZIN` | Serbest çıktı dizini |

## JSON alanları

| Alan | Zorunlu | Not |
|---|---|---|
| `dosya_adi` | ✓ | Uzantısız; `.pdf` ve `.docx` bundan türer |
| `tarih` | ✓ | `GG.AA.YYYY` — sağ üstte |
| `makam` | ✓ | Liste; her satır ayrı. Son satır `...NE/NA` ile biter |
| `il` | — | Makamın altında, kalın |
| `paragraflar` | ✓ | Liste; her biri iki yana yaslı + girintili basılır |
| `ad` | ✓ | İmza bloğu, kalın |
| `unvan` | — | Adın altında |
| `ekler` | — | Liste; otomatik `1-`, `2-` numaralanır |
| `iletisim` | — | Sözlük; anahtarlar hizalanır (TC / Telefon / E-posta) |
| `dogrula` | — | PDF'te **bulunması şart** olan metinler; biri yoksa `rc=4` |
| `max_sayfa` | — | Varsayılan 1 |

## Değişmezler

- **Tek sayfa hedeflenir.** Taşarsa motor punto/satır aralığını 4 kademe kısarak
  yeniden dener. Yine sığmazsa son kademeyi basar ve sayfa sayısını bildirir —
  sessizce 2 sayfa vermez.
- **Türkçe karakter garantili.** DejaVu Serif gömülür (ğ ş İ ı Ç Ö Ü tam kapsama).
  Font `~/.cache/dilekce-fonts` altında saklanır; yoksa `matplotlib`ten alınır,
  o da yoksa kurulur. Sistem fontu aranmaz — bu kutularda yok.
- **Kanıtsız yeşil yok.** Üretimden sonra PDF'in metni geri okunur; `dogrula`
  listesindeki bir ifade PDF'e girmemişse **rc=4** ve gönderim yapılmaz.
- **Gövde şablon DEĞİLDİR.** `paragraflar` her iş için yazılır. Hazır cümle
  doldurmak dilekçeyi zayıflatır — dayanak (belge/mevzuat/olgu) somut olmalı.

## Dilekçe yazarken (içerik notları)

- **Talebi doğru adlandır.** "Görevlendirilmem" ile "atanmam" farklı süreçlerdir:
  birim görevlendirmesi kurum amirinin yetkisinde ve hızlıdır; kadro/atama talebi
  İl Sağlık Müdürlüğü'ne çıkar. Yanlış kelime işi büyütür.
- **Kendi aleyhine vurgu yapma.** Geçmişteki bir eksikliği açıklamaya çalışmak
  ("şöyle girmiştim ama") savunma tonu yaratır; kronolojiyi düz anlat.
- **Dayanağı ekle.** Talebin bir emsale (önceki görevlendirme) veya belgeye
  (diploma, rapor) bağlanması, takdir yetkisini lehe çevirir.
- Soyadı/kimlik bilgisi **ek belgeyle uyuşmuyorsa** (kızlık soyadı vb.) bunu
  dilekçe gövdesinde bir cümleyle belirt — memurun kafası karışmasın.
- Teslimde **evrak kayıt numarası** istenmeli; dilekçenin sisteme düştüğünün
  tek kanıtı odur.

## Bağımlılıklar

`reportlab` · `python-docx` · `pypdf` · (font için) `matplotlib`.
Eksikse motor `matplotlib`i kendi kurar; diğerleri için: `pip install reportlab python-docx pypdf`.

## Kademe (AHÎ)

**Çırak.** Tek motor + tek sarmalayıcı. Kalfa'ya terfi için: çok-sayfalı ek yönetimi,
ıslak-imza yerine e-imza (PAdES) hattı, kurum-adres defteri (`makam` otomatik tamamlama).
