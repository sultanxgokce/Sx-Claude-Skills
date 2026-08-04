---
name: kapimda
type: tool
version: 1.2.0
description: >
  Sultan'ı bekleyen işlerin TEK yüzeyini (kapimda.md) yazan, denetleyen ve adım adım yürüten
  kabuk. Kart açma fail-closed 8 lint kapısından geçer (dört zorunlu alan · "Niçin sen" boşsa
  kart AÇILAMAZ · tavan 3 · ad tekilliği · Sultan-dili/İ1 kalkanı · tek-eylem · sır-desen ·
  uzunluk). Elle yapılacak işler için tek-mesaj-tek-adım motoru (L39) diske plan yazar, ekrana
  yalnız sıradaki adımı basar. "kart aç · kapımda ne var · Sultan'a adım ver · kartı kapat"
  tetiğinde çağrılır. GLOBAL (tüm kutular aynı /config/.claude dosyasını görür).
---

# kapımda — Sultan'ı bekleyen işlerin yazıcısı

## Niçin var (ölçülmüş)
Kart **formatı** ve **çizicisi** 2026-07-31'de kuruldu (`kapimda.md` + karşılama ekranındaki
`🚦 kapında N iş var` bloğu) — ama **yazıcı hiç yazılmadı**: kartlar elle yazılıyordu, lint yoktu,
besleyici yoktu. Canlı sonuç (2026-08-04): Sultan "onay verdim" dedi, sistem 0 onay gördü; kartların
tek yüzü 2.671 mesajlık bir Telegram sohbetiydi ve Sultan onları bulamadı. Bu kabuk o derdin
yazıcı-yarısıdır. Kanon: `_agents/spec/sultan-blokaj-formati-DESIGN.md` (L38) + `…talimat-formati…` (L39).

## Değişmezler
- **A06:** bu araç Sultan'ın cevabını ÜRETMEZ. `bitti` yalnız kartın GÖRÜNÜRLÜĞÜNÜ kapatır
  (kart bir görünürlük yüzeyidir; onay kaydı karar-kartlarında yaşar). `--gerekce` zorunludur.
- **Tek dosya, 16 kutu:** `/config/.claude/kapimda.md` hepsinde ortaktır → her yazım flock'lu.
- **Çizici sözleşmesi:** açık kart satırı `^🚦 SENDE · <Kısa Ad>` — karşılama ekranı bunu grep'ler.
  Format değişirse ekran sessizce körelir; testte kilitlidir (M2/M5).
- **Fail-closed:** lint kapısı düşerse kart YAZILMAZ ve sebebi basılır (sessiz kırpma yok).

## Komutlar
```
kapimda ac "<Kısa Ad>" --ne "…" --nicin-sen "…" --yapilmazsa "…" --bitince "…" \
           [--ozet "gövde 2-4 cümle"] [--yas "3 gündür bekliyor"] [--engel "ne duruyor"] [--kuru]
kapimda bitti "<Kısa Ad>" --gerekce "…"
kapimda liste            # açık kartlar
kapimda lint             # dosya-geneli denetim (RC≠0 = bulgu)
kapimda adim ekle "<Kısa Ad>" --yapilacak "…" --nerede "…" --bitince "…"
kapimda adim goster "<Kısa Ad>"   # YALNIZ sıradaki adım (tek mesaj = tek adım)
kapimda adim ilerle "<Kısa Ad>"   # Sultan cevapladıktan SONRA
kapimda adim durum  "<Kısa Ad>"
```

## Sekiz lint kapısı
| # | Kapı | Niçin |
|---|---|---|
| K1 | dört alan dolu | kartın iskeleti (Ne yapman gerekiyor · Niçin sen · Yapılmazsa · Bitince) |
| K2 | `Niçin sen` bir cümle | ajanın yapabileceği iş kart OLAMAZ — Sultan'a gitmesinin sebebi yazılmalı |
| K3 | tavan 3 açık kart | dördüncüsü sessizce sıraya atılmaz, RED verir (kesme-enflasyonu panzehiri) |
| K4 | Kısa Ad tekil | aynı iş iki kart olmaz |
| K5 | Sultan-dili / İ1 kalkanı | dosya yolu · uzantı · komut · kod-terimi → RED (yol/komut adım-kartına ait) |
| K6 | tek-eylem | "şunu yap, sonra şunu" → adım-kartına bölünür |
| K7 | sır-desen | karta sır yazılamaz (değer basılmadan reddedilir) |
| K8 | uzunluk | gövde ≤600, alan ≤240 karakter |

## Adım motoru (L39)
Plan **diske** yazılır (`kapimda-adim/<Kısa Ad>.md`: `toplam · suanki · durum`), ekrana yalnız
`adım i/N` ve tek iş basılır. Sıradaki adım **ancak Sultan cevapladıktan sonra** `ilerle` ile açılır.
"Yaptım" denince üç-durumlu kanıt-probu koşulur; **"yapmamışsın" dili yasaktır** (Sultan yalanlanmaz).

## Kanıt
`scripts/kapimda.test.sh` → 39 kapı (8 lint-RED yolu + fail-closed dosya-kirlenmezliği + çizici
sözleşmesi + tavan + kapatma + adım motorunun tek-adım disiplini). Gerçek `kapimda.md`'ye dokunmaz.

## Sürüm notları
- **1.0.0 (2026-08-04, MABEYN H2):** ilk sürüm — yazıcı + 8 kapı + kapatıcı + adım motoru + lint.
- **1.1.0 (2026-08-04, MABEYN H3):** **SON-HALKA** — `bitti --federe-tamam <tetik-id>`: kartın ilgili
  olduğu federe tetiği `tamam` değilse kart **KAPANMAZ** (RC=4). Niçin: Sultan bir engeli kaldırdı diye
  iş çözülmüş SAYILMAZ — bunu ancak **engellenen taraf** söyleyebilir ("gönderildi ≠ ulaştı ≠ üstlenildi
  ≠ çözüldü" zincirinin kapanmayan son halkası). Kanıtlı kapanış `olur:` satırı taşır; kanıtsız kapatma
  hâlâ mümkündür ama satır yazılmaz → kayıt hangi kapanışın doğrulandığını gösterir. Test: 39 kapı.

## 🎯 Kart devri — "bunu SERDAR'a şutla" (v1.2.0 · L47/F5)

Sultan'ın isteği birebir: *"SİNAN container'ında Sultan kapısında biriken işlerin bazıları SERDAR
gerektirebilir; o zaman SİNAN o kartları SERDAR etiketli atabilir, SERDAR'ın kapısına şutlayabilir."*

```
kapimda devret "<Kısa Ad>" --sahip <AJAN|SULTAN> --gerekce "…" [--sultan-onayi "<Sultan'ın cümlesi>"]
```

🔴 **Kart TAŞINMAZ.** Kapımda dosyası 14 kutuda aynı dosyadır; devir yalnız bir satır değiştirir.
Federe/kurye zincirine bağımlılık YOK — o zincir yarım (`oda-zil` 12 turdur `zil=0`) ve zile bel
bağlamak kartı kaybettirirdi. Zil olsa olsa **kolaylıktır**, taşıyıcı değil.

| Geçiş | İzin |
|---|---|
| `<AJAN>` → `<AJAN>` | ✅ serbest (asıl kullanım: SİNAN→SERDAR), gerekçe zorunlu |
| `<AJAN>` → `SULTAN` | ✅ serbest, gerekçe zorunlu |
| `SULTAN` → `<AJAN>` | 🔴 **Sultan-onayı şart** (`--sultan-onayi`), yoksa **RC=5** |

**Niçin son satır sert:** Sultan'ın kapısından iş çıkarmak bir KARARDIR. Ajan kendi kendine
"bu bana düşer" deyip Sultan'ın listesini temizleyemez (A06'nın devir-yüzü). Verilen onay
**verbatim karta yazılır** → denetlenebilir. ⚠️ Bu cümleyi uydurmak, sahte onay yazmakla
**aynı sınıf ihlaldir**; kanıt kartın kendisindedir.

**Damga ve sayım:** ajan-sahipli kart `🎯 <AJAN> · <Kısa Ad>` olur ve **Sultan'ın tavan-3
sayımına girmez** — Sultan'ın kapısı yalnız kendi işlerini gösterir. Dokunulmamış kartın
damgası birebir aynı kalır (çizici sözleşmesi bozulmaz; kapı D10).

**Pinpon panzehiri:** her devir `devir: N` sayacını artırır; **3. devirde** kart otomatik
`⚠️ TIKANDI` damgasıyla Sultan'a döner. *Üç kez el değiştirdiyse sahibi belli değildir,
hakem Sultan'dır.* Her devir gerekçesiyle karta satır düşer — **sessiz devir yoktur**.

