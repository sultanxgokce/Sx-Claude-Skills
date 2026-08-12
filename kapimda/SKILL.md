---
name: kapimda
type: tool
version: 1.6.0
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

## Çakışma kuralı (⏸️ BAŞKASINDA kuralının YERİNE — Sultan-kararı 2026-08-11)
**Kartla ilgili işe girmeden önce devret damgasına bak; kart dışı işte üstlenme kaydına yaz.**
Eski `⏸️ BAŞKASINDA` damgası **kaldırıldı**: aynı ihtiyaca bakan üçüncü kopyaydı ve hiçbir kod
yolu onu yazmıyor, hiçbir lint okumuyordu (ölçüm: fiilî kullanım **0**). Kart işleri için
`devret` (sahip damgası `🎯 <AJAN>`), kart-dışı işler için `ustlen al` zaten vardı.

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
kapimda liste            # açık kartlar (Sultan-yüzü: kendi odan · yalnız 🚦 SENDE)
kapimda sahip "<Kısa Ad>"  # SULTAN | <AJAN> | TIKANDI bas · RC 1 = böyle bir açık kart YOK
                           # (otomasyon yüzeyi: "bu kart açık mı / kimde" — devredilmişi de görür)
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
| K4 | Kısa Ad tekil | aynı iş iki kart olmaz — **sahipten bağımsız** sorar: devredilmiş (`🎯`) ve tıkanmış (`⚠️`) kart da "açık" sayılır (L49) |
| K5 | Sultan-dili / İ1 kalkanı | dosya yolu · uzantı · komut · kod-terimi → RED (yol/komut adım-kartına ait) |
| K6 | tek-eylem | "şunu yap, sonra şunu" → adım-kartına bölünür |
| K7 | sır-desen | karta sır yazılamaz (değer basılmadan reddedilir) |
| K8 | uzunluk | gövde ≤600, alan ≤240 karakter |

## Adım motoru (L39)
Plan **diske** yazılır (`kapimda-adim/<Kısa Ad>.md`: `toplam · suanki · durum`), ekrana yalnız
`adım i/N` ve tek iş basılır. Sıradaki adım **ancak Sultan cevapladıktan sonra** `ilerle` ile açılır.
"Yaptım" denince üç-durumlu kanıt-probu koşulur; **"yapmamışsın" dili yasaktır** (Sultan yalanlanmaz).

## Kanıt
`scripts/kapimda.test.sh` → **84 kapı** (8 lint-RED yolu + fail-closed dosya-kirlenmezliği + çizici
sözleşmesi + tavan + kapatma + adım motorunun tek-adım disiplini + 10 devir kapısı + 14 kaynak-damgası
kapısı + 7 varsayılan-görünüm kapısı + **15 L39 kapısı**: K9 kart-çapası · K10 N-dürüstlüğü ·
yumuşak-kilit · A06 cevap-alanı). Gerçek `kapimda.md`'ye dokunmaz. Kapılar negatif-test edildi: kaynak
uydurulursa O4, devir kaynağı ezerse O7/O9, uydurma-N verilirse K10, kartsız adım eklenirse K9
**kırmızıya döner** (yani koruma gerçek, süs değil).

## 🛠️ ŞİMDİ SEN adım-bloğu — Sultan-Talimat Formatı (L39, 9 Sultan-kararı · 2026-08-11 gece)

Kanon: `_agents/spec/sultan-talimat-formati-DESIGN.md`. Kart `"bu iş SENDE"` der; adım-bloğu
`"işte tam olarak ne yapacaksın"` der — aynı gramerin iki kademesi (kartsız adım-bloğu yasak,
§3.1 DESIGN). Sultan dokuz kararı verdi; hepsi aşağıda numaralıdır ve kod-kapısına bağlıdır
(L35 dersi: "kural var ama hiçbir kapıda koşmuyorsa yok sayılır").

**Sabit şablon:**
```
🛠️ ŞİMDİ SEN · <Kısa Ad> · adım <i>/<N>
Yapılacak: <TEK eylem>
Nerede:    <panel/uygulama adı — jargonsuz, yol/komut yok>
Bitince:   <ajanın soracağı takip-sorusuna cevap ver>
```

**Dokuz karar → nerede yaşıyor:**

| # | Karar | Nasıl uygulanır |
|---|---|---|
| **1** | Damga **`🛠️ ŞİMDİ SEN`** | `adim goster` bunu basar (kod: `_adim_goster`) |
| **2** | İlerleme **`adım i/N` HEP görünür, N dürüst** — adımlar dallanmalarıyla PEŞİN yazılır | Her adım `adim ekle` ile TEK TEK, önceden eklenir; N `toplam:` alanından okunur. **K10 kapısı** (`_n_dogru_mu`): plan dosyasındaki `toplam:` ile gerçek `### adim` blok sayısı eşleşmezse `adim goster/durum` RED döner — uydurma N yasak (DESIGN R8) |
| **3** | Blokaj-kilidi **YUMUŞAK** — açık adım varken yeni adım → **uyarı basılır, engellenmez** | `_adim_goster`: (a) aynı karta 2. kez basılırsa (`bekliyor: evet` iken tekrar `goster`) kendi-uyarısı · (b) başka bir kartın adımı `bekliyor: evet` iken çapraz-uyarı. İkisi de RC'yi **0'da bırakır** — sert-kilit (`PreToolUse` deny) DESIGN §6.2-iii'te bilerek reddedildi (paylaşımlı `settings.json` 16 kutuyu dondurur) |
| **4** | Her adım-bloğu **MUTLAKA** açık bir `🚦 SENDE` kartına bağlı | **K9 kapısı** (`_kart_var_mi`): `adim ekle` çağrısı, o isimde açık bir `🚦 SENDE · <Ad>` satırı YOKSA RED döner (plan dosyası hiç yazılmaz — fail-closed). `🎯 <AJAN>` kartına adım-bloğu bağlanmaz: adım Sultan'ın ELİYLE yapacağı iş içindir |
| **5** | Takip şıkları **sabit: `yaptım / takıldım / iptal`** | Ekrana `AskUserQuestion` ile basılır (kod-dışı — çağıran ajan sorar). "başka bir şey" şıkkı elle yazılmaz, harness ekler. **`takıldım` dallanma-planını açar**: ajan nerede takıldığını sorar, kalan adımları Sultan'ın gördüğü ekrana göre yeniden yazar |
| **6** | Şık-oranı: **2-4 şık + her zaman işaretli tek öneri** | Takip-sorusunun `options[]`'ında bir seçenek `(önerim)` işaretiyle gelir — şema tavanı zaten 2-4 (`sdk-tools.d.ts:867`) |
| **7** | Tur başına soru tavanı **4** (şema tavanı, Sultan bilerek üst-sınırı seçti) | Çağıran ajanın disiplinidir; kod bunu ölçmez. Bir turda 4'ten fazla `AskUserQuestion` çağrısı YASAK |
| **8** | A06: **`answers` alanı hiç doldurulmasın**, lint reddetsin | **A06 kapısı** (`_cevap_alani_var`, `kapimda lint`): `kapimda.md` ya da herhangi bir `kapimda-adim/*.md` dosyasında `cevap:` / `yanit:` / `sultan_cevap:` / `sultan_response:` / `onay-cevabi:` / `answer:` deseni RED döner. Bu araç Sultan'ın cevabının METNİNE hiç dokunmaz — yalnız `suanki`'yi ilerletir |
| **9** | Bugünkü açık kartların adım-planları şimdi çıkarılsın | Ölçülmüş kart-durumuna göre `_agents/handoff/` altına yazılır (Nexus repo, bu skill'in kapsamı değil — kart içeriği CANLI `kapimda.md`'den ölçülür, uydurulmaz) |

**Kart-devri ile ilişki:** `🎯 <AJAN>` sahipli bir kart tekrar `🚦 SENDE`'ye dönerse (Sultan-onayıyla
ya da 3. devir pinpon-panzehiriyle `⚠️ TIKANDI`), adım-bloğu ancak O NOKTADAN SONRA açılabilir
— K9 kapısı bunu otomatik uygular, ayrı bir kural yazmaya gerek yoktur.

**Sert-kilit BİLEREK reddedildi:** `PreToolUse` deny tekniği vardı ama `/config/.claude/settings.json`
16 kutunun **paylaştığı tek dosyadır**; kötü bir gate tüm filoyu dondurur (global CLAUDE.md, "Araç
& Hook Sürtünmesi"). Yumuşak-kilit bunun yerine yalnız bir *nudge*'dır — ajan görmezden gelebilir,
kaçış yolu her zaman açıktır (kart `Şimdi değil`/`iptal` diyebilir, kilit dosyası kimseyi dondurmaz).

## Sürüm notları
- **1.5.0 (2026-08-11, L39 · 9 Sultan-kararı):** `adım-bloğu` üç yeni kapıya bağlandı — **K9**
  kart-çapası (kartsız adım-bloğu RED) · **K10** N-dürüstlüğü (uydurma `toplam:` RED) ·
  **yumuşak-kilit** (aynı-karta 2. açık adım / çapraz açık-adım → UYARI, RED DEĞİL) · **A06**
  cevap-alanı koruması `kapimda lint`'e eklendi. Plan dosyasına `bekliyor: evet|hayir` alanı
  eklendi (goster→evet, ilerle→hayir). Test: **84 kapı** (69 eski + 15 yeni, hepsi mutasyon-kanıtlı).
- **1.0.0 (2026-08-04, MABEYN H2):** ilk sürüm — yazıcı + 8 kapı + kapatıcı + adım motoru + lint.
- **1.1.0 (2026-08-04, MABEYN H3):** **SON-HALKA** — `bitti --federe-tamam <tetik-id>`: kartın ilgili
  olduğu federe tetiği `tamam` değilse kart **KAPANMAZ** (RC=4). Niçin: Sultan bir engeli kaldırdı diye
  iş çözülmüş SAYILMAZ — bunu ancak **engellenen taraf** söyleyebilir ("gönderildi ≠ ulaştı ≠ üstlenildi
  ≠ çözüldü" zincirinin kapanmayan son halkası). Kanıtlı kapanış `olur:` satırı taşır; kanıtsız kapatma
  hâlâ mümkündür ama satır yazılmaz → kayıt hangi kapanışın doğrulandığını gösterir. Test: 39 kapı.
- **1.3.0 (2026-08-05, L48/G1):** **kart kaynağı** — her kart doğuş anında `oda: <kutu>` damgası alır.
- **1.4.0 (2026-08-05, L48/G2):** **varsayılan görünüm = KENDİ odan.** Liste artık 14 kutunun işini
  "kapında" diye basmıyor; yalnız bu odanın kartlarını + damgasız (kökeni bilinmeyen) kartları gösteriyor.
  🔴 **Gizlemek değil susturmak:** başka odanın işleri düşürülmez, tek satırlık dipnota iner
  (*"… 3 iş başka odalarda"*) ve `--hepsi` ile tam liste bir tuş uzaktadır — sessizce yutulan iş kayıp iştir.
  🔴 **Damgasız kart GÖSTERİLİR:** damgasız kart "başka odanın" değil "bilinmeyen"dir; onu gizlemek
  kanıtsız bir varsayımla Sultan'ın işini saklamak olurdu. Test: **69 kapı** (P1-P7 yeni).
  Tavan-3 bilerek GLOBAL bırakıldı: oda-başına gevşetmek Sultan'ı 14×3 karta açardı — ölçüm olmadan
  koruma gevşetilmez.

- **1.6.0 (2026-08-11, L49):** **sahip-kör tekillik kapatıldı.** Ölçülmüş vaka: SERDAR'a
  devredilen "Tescil Bekleyen İşler" kartı aynı gün **iki kez** yeniden açıldı (16:52 ve 17:29) —
  çünkü K4 ve besleyici, tavan-3 için yazılmış dar filtreye (`^🚦 SENDE`) bakıyordu ve devredilmiş
  kartı GÖRMÜYORDU. Üç değişiklik: (a) K4 artık sahipten bağımsız sorar → devredilmiş/tıkanmış
  kartın adıyla ikinci kart AÇILAMAZ; (b) `bitti` devredilmiş (`🎯`) ve tıkanmış (`⚠️`) kartı da
  kapatır (eskiden RC 3 → kapanış yolu YOKTU); (c) yeni `sahip` komutu otomasyona ham gerçeği verir
  (besleyici artık `liste | grep` ile sormaz). 🔴 **Tavan-3 semantiği DEĞİŞMEDİ** — devredilmiş kart
  Sultan'ın 3'lük sayımına hâlâ girmez ve `liste` Sultan-yüzü aynı kalır; regresyon zırhı testte
  kilitli (L49-5/L49-5b/L49-6). Test: **96 kapı** (12 yeni).

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

## 🏷️ Kart kaynağı — "bu kart hangi odadan çıktı" (v1.3.0 · L48/G1 = L47/F3)

**Niçin var (ölçülmüş):** kapımda dosyası 14 kutuda **aynı dosyadır**, ama kartta "bunu kim
açtı" alanı hiç yoktu. Sonuç: her kutu ötekinin işini kendi kapısı sanıyordu — HUZUR
kutusunda "kapında 3 iş var" dendi, üçü de başka odanın işiydi. Sultan'ın cümlesiyle:
*"bir container'ın işi diğerine gidiyor."*

Artık her kart **doğduğu anda** başlığının hemen altına kaynağını yazar:

```
🚦 SENDE · Kasa Erişimi
oda: tellal
```

- **Otomatik — ajan yazmaz.** Kaynak kutunun çalışma alanından türer (her kutuda, izole
  olanlarda da vardır; merkez kutu `nexus` olur). Gerekirse `KAPIMDA_ODA` ile ezilebilir.
- **🔴 Uydurma yok.** Türetilemiyorsa `bilinmiyor` yazılır. Sahte bir kutu adı basmak
  yanlış-yönlendirmeyi çözmez, **ölçülemez hâle getirir** — 818 karar kaydının 818'inin
  aynı değeri taşıması alanı tam bu yüzden fiilen öldürmüştü.
- **Kaynak ≠ sahip.** `oda` kartı KİM AÇTI der; `sahip` kart ŞU AN kimde der. Devir
  kaynağı **ezmez**, damgasız eski kartlara da köken **uydurulmaz** (kapı O7/O9).
- **Şimdilik salt-bilgi.** Kaynak gösterilir ama liste ona göre **süzülmez** — süzme
  Sultan'ın gördüğü çıktıyı değiştirir, ayrı karar ister.

