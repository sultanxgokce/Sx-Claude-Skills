# durum-raporu · veri sözleşmesi v1 (tüm kutular için ORTAK) · 2026-09-15 · MÜTEVELLİ taslağı, MUAVİN paketler

Amaç: Sultan "durum raporu" deyince her kutuda (akar, tellal, mihenk, huma, medigate, vekatip, s02, code…) AYNI biçimde,
personel başına, canlı bağlantılı tek rapor. Tek veri kaynağı: kutunun `_agents/durum/<AD>.json` dosyaları.

## 1 · Dosya: `_agents/durum/<AD>.json` — her üye KENDİ dosyasını yazar (başkasınınkine yazmaz)
```json
{
  "surum": 1,
  "ad": "MUHTESIP",                    // ASCII kimlik (registry id ile aynı)
  "gorunen_ad": "MUHTESİP",
  "rol": "ölçü/denetim; tasarım turları",
  "kutu": "akar",                       // konteyner kısa adı (cloudtop-akar → akar)
  "guncelleme": "2026-09-15T22:10:00+03:00",
  "bitirdi": [ { "is": "Saha raporu ekranı (rapor v1)", "zaman": "2026-09-15T21:54:00+03:00",
                 "kayit": "4cd7291", "link": "mmepanel://akar/kayit/4cd7291" } ],
  "simdi":  { "is": "Ciro vitrini canlıda yürütme", "baslangic": "2026-09-15T22:12:00+03:00",
              "link": "mmepanel://akar/dosya/tasarim/CIRO-VITRIN-20260915.md" },
  "kuyruk": [ { "sira": 1, "is": "Rapor dönem satırı sadeleştirme", "hedef": "2026-09-17",
                "link": "mmepanel://akar/dosya/_agents/handoff/MUTEVELLI-MUHTESIP-rapor-onay-20260915.md" } ],
  "bekliyor": [ { "kimden": "MUTEVELLI", "ne": "p17 yayını", "beri": "2026-09-15T22:10:00+03:00",
                  "link": "mmepanel://akar/yayin/p17" } ],
  "canli": { "pencere": "MUHTESIP:0", "link": "mmepanel://akar/pencere/MUHTESIP" }
}
```
Kurallar: `bitirdi` son 3 iş (yeni → eski); boş liste `[]`, bilinmeyen `null` (uydurma yok); saat `date -Is` ile kutudan.
Dosya yoksa rapor üyeyi "durum dosyası yok" diye gösterir ve kayıttan (registry + son commit + son sinyal) TÜRETİLMİŞ satır basar — türetilmiş satır "(türetildi)" damgalıdır.

## 2 · Bağlantı şeması (her kutuda aynı yazılır, tek yerde çözülür)
Kanonik biçim: `mmepanel://<kutu>/<tur>/<hedef>`. Türler kapalı küme:
| tur | hedef | çözümleme (URL şablonu, `link-taban.yaml`) |
|---|---|---|
| `pencere` | ajan adı | canlı tmux penceresi (mobil panel) — **şablonu MUAVİN doldurur** (m.mmepanel.com) |
| `dosya` | repo içi yol | code-server dosya görünümü — şablon MUAVİN'den |
| `kayit` | commit sha | repo kayıt görünümü (code-server ya da git web) — şablon MUAVİN'den |
| `yayin` | paket/makbuz adı | yayın makbuzu ya da canlı adres (akar için https://akar.mukarnas.net) |
| `sinyal` | sinyal id | ekip sinyal defteri satırı |
| `https` | tam URL | olduğu gibi (dış adres; örn. canlı ürün) |
Çözümleme `scripts/link-coz.sh <mmepanel-link>` ile; şablon dosyası `link-taban.yaml` KUTU BAŞINA DEĞİL, filo genelinde tektir
(cloudtop reposunda; her kutuya ortak `~/.claude` üzerinden gelir). Kutu adı ile hedef arasındaki eşleme orada durur.
Bir link çözülemezse rapor ham `mmepanel://…` yazar, uydurmaz.

## 3 · Rapor biçimi (Sultan standardı, 2026-09-15)
```
DURUM RAPORU · <kutu> · <saat>
1. <GÖRÜNEN AD> (<rol>)
   Bitirdi: <iş> · <saat> · <link>
   Geçti:   <iş> · <başlangıç> · <link>
   Önünde:  1) <iş> · <hedef> · <link>   2) …
   Bekliyor: <kimden> · <ne> · <beri> · <link>   (yoksa "—")
   Canlı:   <link>
2. <GÖRÜNEN AD> …
```
Sıra: registry sırası (yönetici en üstte). Boş alan "—". Yönetici (reis) de bir personeldir, kendini de yazar.
