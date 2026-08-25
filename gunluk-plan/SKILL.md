---
name: gunluk-plan
description: Günün planı — elimizdeki işleri ÖLÇ, katma değer katacakları süz, Sultan-dilinde plan sun, onaydan sonra icra et. Sultan'ın her gün verdiği "işleri analiz et, bugün ne yapalım" isteğinin tek komutlu karşılığı.
version: 1.0.0
---

# /gunluk-plan — günün planı (ölç → süz → sun → icra)

## Niçin var (Sultan-direktifi 2026-08-25)

Sultan her gün aynı şeyi uzun uzun yazıyordu: *"elimizdeki işleri analiz et ve bugün yapılacak
katma değer katacak işleri tespit et, bugüne yoğun bir planlama yap, aksiyona geçelim."*
Bu skill onun tek-komutlu karşılığıdır. **Amaç plan yazmak değil, gün sonunda kapanmış iş
bırakmaktır** — plan yalnız oraya giden yoldur.

## 🔴 Değişmezler (ihlal = plan çöp)

1. **Ölçmeden madde yazılmaz.** Her plan maddesinin arkasında bu turda koşulmuş bir komut çıktısı
   olur. Hafızadan/özetten madde üretmek yasak — hafıza bayatlar ([[project_bayat_kayit]]).
2. **Yeni havuz/defter KURULMAZ.** Kaynaklar aşağıda sabittir; sekizincisini icat etme.
3. **A06:** Sultan'ın onayı üretilmez. Plan sunulur, seçimi o yapar.
4. **Sultan-dili.** Dosya yolu · komut · kod-terimi plan gövdesinde geçmez; kanıt satırında geçebilir.
5. **Kapasite dürüstlüğü.** Bir güne 3-5 maddeden fazlası yazılmaz. Uzun liste plan değil, kaçıştır.
6. **Kuyruğunda iş varken durma.** Onaylanan maddeyi bitir, sonra sonrakine geç.

## ADIM 1 — YER-GERÇEĞİNİ ÖLÇ (yedi kaynak, hepsi zorunlu)

```bash
bash /config/.claude/skills/gunluk-plan/scripts/olc.sh
```

Script yedi kaynağı sırayla basar ve **ölçemediğini "ölçemedim" diye basar** (sessiz atlama yok):

| # | Kaynak | Hangi soruyu yanıtlar |
|---|---|---|
| 1 | layiha defteri (`--aktif`) | araştırması bitmiş, inşası bekleyen ne var |
| 2 | kapımda kartları (`--hepsi`) | Sultan'ı fiilen ne bekletiyor |
| 3 | açık PR'lar + yaşları | yarım bırakılmış iş nerede |
| 4 | federe gelen kutusu (son 7 gün) | başka odalardan ne geldi, cevapsız ne var |
| 5 | görev listesi (`in_progress`) | kendi kuyruğumda ne açık kaldı |
| 6 | kendi defterim (son 30 satır) | dün nerede bıraktım |
| 7 | git durumu (dal · commit'siz · geride) | ortam temiz mi, dallanma güvenli mi |

## ADIM 2 — SÜZ (dört elek, sırayla)

Ölçülen ham listeyi şu dört elekten geçir. **Eleme gerekçesiz olmaz.**

1. **Kapanabilir mi?** Bugün içinde BİTECEK mi, yoksa yalnız ilerleyecek mi? Kapananı öne al —
   yarım iş ertesi güne faiziyle döner.
2. **Kilidi açıyor mu?** Bu iş bitince BAŞKA kaç iş serbest kalıyor? Zincirin baş halkası
   her zaman tek başına duran bir işten değerlidir.
3. **Bozuk mu, eksik mi?** Bozuk olan (kurulmuş ama çalışmayan, "yeşil görünüp iş yapmayan")
   eksik olandan önce gelir — bozuk şey yanlış güven üretir.
4. **Sultan bunu hisseder mi?** Görünmeyen altyapı işi ile Sultan'ın ekranında değişen şey
   arasında seçim gerekiyorsa ikincisi kazanır ([[project_ana_aks_zemin_once]] dengesi:
   zemin önce ama zemin hep değil).

Elenenler **kayda geçer** ("bugün değil, çünkü …") — sessizce düşen iş kayıp iştir.

## ADIM 3 — SUN (sabit format, kopyalanabilir)

Tek kod-bloğu içinde:

````
```
📅 GÜNÜN PLANI · <YYYY-MM-DD>
ölçüm: <N> aktif layiha · <N> kart · <N> açık PR · <N> okunmamış mesaj

BUGÜN (sırayla):
1. <Sultan-dilinde tek cümle> — <bitince ne değişir> · <kim: ben|sen|birlikte>
2. …
3. …

SENDE (tek tuşluk):
• <karar/onay> — <bir cümle niçin sen>

BUGÜN DEĞİL (gerekçesiyle):
• <iş> — <niçin bugün değil>
```
````

Sonra **tek soru**: *"Böyle mi ilerleyelim, yoksa sıralamayı değiştirelim mi?"*
Şıklar 2-4 arası, biri `(önerim)` işaretli. Yığma yasak — bir mesaj, bir istek.

## ADIM 4 — İCRA

Onaydan sonra maddeleri **sırayla** yürüt. Her madde bitince:
- kayıt-damgası (layiha defteri / kart / CONTEXT — hangisi ilgiliyse)
- `append-note.sh` ile deftere tek satır
- Sultan'ın notlarına tek satır (`[SERDAR]` etiketli, onun ağzından)

Madde ortasında yeni bir bulgu çıkarsa: **bodoslama fixleme** — layihaya yaz, plana dokunma
([[feedback_kesif_layiha_yolu]]).

## ADIM 5 — GÜN SONU (aynı komut, `kapanis` argümanıyla)

`/gunluk-plan kapanis` → sabah sunulan planı geri okur, her madde için **kapandı / yarım / açılmadı**
basar ve yarım kalanı ertesi günün ölçümüne çıpalar. Kapanış olmadan plan bir dilek listesidir.

## Sınırlar / dürüstlük

- Bu skill iş ÜRETMEZ, var olanı süzer. Ölçüm boşsa plan da boştur — uydurma madde yazma.
- Süzme bir yargıdır, mekanik değil; gerekçesi her zaman yazılır ki ertesi gün tartışılabilsin.
- Ölçülemeyen kaynak "yok" sayılmaz, "ölçülemedi" diye basılır (unknown ≠ fail).
