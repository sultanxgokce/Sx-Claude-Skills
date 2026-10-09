---
name: bileyi
type: agent
version: 0.1.0
description: >
  Bıçağı bileyen komut: kendi izimizi (bulgu havuzu · sürtünme raporu · aday havuzu) tarar,
  TEKRAR EDEN sürtünmeyi bulur ve onu yeteneğe çevirir — beceri · kural · yapılandırma.
  Var olan fikir-hattı DIŞA bakar (kasif-tara web'i tarar); bu komut İÇE bakar. Yeni havuz
  KURMAZ: bulgu-havuzu ve layiha-aday-havuzu üstüne oturur, süzmeyi mucit-suz'e devreder,
  inşayı yazilim-fabrikasi hattına sokar. Tam otonom: sınıfsız işi uçtan uca bitirir ve
  kendi birleştirir; sınıflı işi (para · geri-alınamaz · dış-yüzey · yetki) Sultan'a bırakır.
  Kill-switch'li. "/bileyi", "/bileyi olc", "/bileyi durum", "/bileyi dur" çağrılarında kullanılır.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [bileyi, ic-tarama, surtunme, yetenek-uretimi, otonom, kill-switch]
disable-model-invocation: false
---

# /bileyi — bıçağı bile: kendi izini tara, tekrar edeni yeteneğe çevir

## Niçin var (ölçülmüş)

Sultan'ın cümlesi: *"gün içinde yaptıklarını, bu hafta yaptıklarını, loglarını, yakın zamandaki
çalışmalarını araştırıp agentic operasyonları artıracak sistem yapılandırması, kural üretimi,
beceri üretimi yapsın — tekrarlayan işlerde verimliliği artırsın. Genel bir bıçağını bileme."*

Boşluk ölçüldü, uydurulmadı:

| Var olan | Neye bakar | Bu komut |
|---|---|---|
| `kasif-tara` | **web**'i tarar, fikir toplar | kendi izimizi tarar |
| `mucit-suz` | havuzu süzer, aday önerir | **onu çağırır**, yeniden yazmaz |
| `layiha-fabrikasi` | dış fikir-hattının çatısı | iç sürtünme hattının çatısı |
| `friction-report.sh` | sürtünmeyi **sayar** | sayımı **yeteneğe çevirir** |
| `olcum-disiplini` | tek bir ölçümü denetler | ölçümlerin **tekrarını** görür |

🔴 **Asıl kanıt, bu becerinin doğduğu gün:** aynı ajan tek günde **beş** ölçüm hatası yaptı,
beşi de aynı kökten (aracı pozitif kontrolden geçirmeden olumsuz hüküm) ve sistem ona
*"bunu beşinci kez yapıyorsun"* demedi. Sürtünmeyi sayan araç Ağustos'tan beri duruyordu;
onu bir yeteneğe çeviren tek satır yoktu. Eksik olan ölçüm değil, **ölçümün tekrarını
görmek**ti.

## 🔴 Değişmezler

1. **YENİ HAVUZ KURULMAZ.** Bulgular `bulgu-havuzu.jsonl`'a, adaylar `layiha-aday-havuzu.jsonl`'a
   yazılır. Sekizinci havuz açmak, ilk değişiklikte ikisini de yalancı yapar.
2. **SÜZME DEVREDİLİR.** Elek `mucit-suz` T1'dir (kanıt kapısı · dedup · tavan). Burada ikinci
   bir elek yazmak, iki ayrı "zaten var mı" cevabı üretirdi.
3. **KENDİ İZİ — başkasının defteri OKUNMAZ.** Kimlik `cipa.sh ajan`dan **sorulur**, çivilenmez.
   Ölçülmüş vaka: bir ölçüm aracı çivili yolla hangi ajan koşarsa koşsun SERDAR'ın izini
   "dün nerede bıraktım" diye sunuyordu — iki zarar: yanlış ize bakan yanlış plan yazar, ve
   bir ajanın izi onu görmemesi gereken odalara **sızar**.
4. **EŞİK UYDURULMAZ.** "Kaç tekrar yeteneğe döner" bir ölçüm sorusudur. Eşik dosyadan okunur
   ve dosyada **ölçülmüş dayanağı** yazılı olmalıdır; dayanak yoksa araç **rc=3 (ÖLÇEMEDİM)**
   döner, yeşil basmaz. Bu kural bugünden: bir kota dersinde eşik seçmemek, veri bir hafta
   birikmeden sayı türetmemek bilerek tercih edildi.
5. **KAPSAMA DÜRÜSTLÜĞÜ.** Her ölçüm, havuzun **ne kadarını görebildiğini** yazar. Ölçüldü:
   177 bulgunun yalnız **61'inde** `sinif` alanı dolu — sınıfa dayanan bir sayım havuzun
   %66'sına **kördür** ve bunu söylemeyen bir sayım, tekrarın yokluğunu değil **alanın
   benimsenmesini** ölçer (vekil ölçüt).
6. **A06 — insan onayı ÜRETİLMEZ.** Sınıflı iş (geri-alınamaz · para · dış-yüzey · yetki)
   Sultan'ın kapısına gider; araç onun yerine "olur" yazmaz.
7. **TAVAN VAR.** Bir turda en çok `BILEYI_TAVAN` yetenek üretilir (varsayılan 2). Otonomluk
   sınırsızlık değildir; kendi kuyruğunu tıkayan bir araç yetenek değil yük üretir.
8. **KILL-SWITCH.** `dur` otonom turu kapatır; `olc` ve `durum` **hiçbir zaman** kesilmez —
   eldeki ölçüme erişim bir otonomluk ayarına bağlanamaz.
9. **Sultan-dili.** Sultan'a giden gövdede dosya yolu, komut, kod terimi geçmez.

## TAM OTONOMLUK — ne demek, ne demek DEĞİL

Sultan kararı (9 Ekim 2026, sohbet): **"beceriyi kuralım tam otonom olsun."**

Otonomluk şu sınıra kadar gider ve bu sınır beceriden değil **kanondan** gelir:

| Araç KENDİ yapar | Sultan'a GİDER |
|---|---|
| ölçmek · tekrarı saymak · süzmek | sınıflı işin birleştirilmesi |
| kart açmak (sınıf sorularını **ölçümden** cevaplayarak) | eşik değiştirmek (dayanak ister) |
| iş alanı açmak · inşa etmek · kanıt toplamak | kanonda SERT kural ilan etmek |
| bağımsız gözden geçirmek | sır değerine dokunan hiçbir şey |
| **sınıfsız işi kendi birleştirmek** | otonom turu açmak/kapatmak |

🔴 **Şüphede sınıf YUKARI.** Sınıf sorusuna "?" demek, Sultan'a gitmek demektir. Araç kendi
işini sınıfsız ilan etmeye **meyillidir**; bu yüzden sınıf cevapları ölçümle gerekçelenir ve
gerekçesi karta yazılır.

## AKIŞ — beş adım, sıra değişmez

### 1 · ÖLÇ (iç-tarama)

```
bash <bu-dizin>/scripts/bileyi.sh olc [--gun N]
```

Dört kaynağı tarar ve **ölçemediğini "ölçemedim" diye basar**:

| # | Kaynak | Hangi soruyu yanıtlar |
|---|---|---|
| 1 | bulgu havuzu (kendi odanın) | hangi sürtünme **tekrar ediyor** |
| 2 | sürtünme raporu (varsa) | hangi araç/kanca tekrar **reddediyor** |
| 3 | aday havuzu | bu zaten **önerilmiş** mi |
| 4 | kurulu beceriler | bu yetenek zaten **var** mı |

Tekrar **iki yüzeyden** sayılır, çünkü biri eksik:
- **sınıf alanı** — kesin ama havuzun bir kısmına kör (kapsama basılır)
- **ikili söz öbeği** — tüm havuzu görür, gürültülü

İki yüzey **çelişiyorsa hüküm YOK** — çelişki basılır ve tur durur.

### 2 · SAY ve EŞİKTEN GEÇİR

Eşik `esik.json`'dan okunur ve **ölçülmüş dayanağı** yazılı olmalıdır. Dayanaksız eşik
`rc=3`'tür. Varsayılan dayanak (9 Ekim 2026 ölçümü, 177 bulgu): ikili söz öbeklerinin
dağılımında tepe `vekil ölçüt` ×8, ikinci `sahte yeşil` ×5, üçüncü sıra ×4; **≥4** bir
söz öbeğini gürültüden ayırıyor — tek ve iki kez görünen öbekler yüzlerce.

### 3 · ÇEVİR — üç cinsten biri

| Cins | Ne zaman | Örnek |
|---|---|---|
| **kural** | davranış yanlış ve yazılı bir kural eksik | "olumsuz hüküm iki yüzey ister" |
| **yapılandırma** | kural var ama **koşmuyor** | kancaya bağla · cron'a koy |
| **beceri** | iş tekrar eden bir **prosedür** | yeni bir komut |

🔴 **Önce "kural var mı, koşuyor mu" sorulur.** Bu filoda ölçülmüş en pahalı sınıf
*"kurdum ama koşmuyor"*: kural yazılı, kapısı yok, göstergesi yeşil. Var olan bir kuralı
kapıya bağlamak, yeni bir beceri yazmaktan **neredeyse her zaman** daha değerlidir.

### 4 · UYGULA (otonom — araç FİİLEN yapar, tavsiye basmaz)

🔴 **Bu bölüm bir kez yalan söyledi ve bağımsız göz yakaladı.** İlk sürümde `tur`
komutu ölçümden sonra "sıradaki adımlar" diye altı satır **basıyor** ve 0 dönüyordu;
belge ise uçtan uca otonomluk vaat ediyordu. Yani becerinin manşet iddiası
belgelenmiş, yapılmamıştı — bu filoda en pahalı sınıf olan *"kurdum ama koşmuyor"*un
manşet hâli. Şimdi üç komut da gerçek iş yapıyor:

| Komut | FİİLEN ne yapar |
|---|---|
| `tur` | ölçer · **var olan** aday havuzuna satır yazar · tur durumunu diske bırakır |
| `kart` | sınıf sorularını **kâhinle** cevaplar ve kartı fabrika aracıyla **açar** |
| `devam` | diffin sınıfını **yeniden ölçer** · kanıt + bağımsız gözü **koşar** · sınıfsızsa **birleştirir** |

**Yapmadığı tek şey ve onu gizlemiyor:** *yazmak.* Bir kural metnini ya da yeni bir
beceriyi bir kabuk betiği yazamaz; onu ajan yazar. Fark şurada: eskiden **bütün hat**
tavsiyeydi, şimdi yalnız bu tek adım bir **durum**dur — diskte durur, `devam` onu arar.

### Sınıf kâhini — otonomluğun emniyet supabı

Otonom tur kart açacaksa sınıf sorusu cevaplanmak zorundadır. Bunu ajanın serbest
muhakemesine bırakmak, **ajanın kendi işini "sınıfsız" ilan edip kendi kendine
birleştirmesine** kapı açardı. O yüzden cevap muhakemeden değil, **denetlenebilir bir
listeden** gelir: `sinif-kurallari.json` (ölçülmüş dayanağı zorunlu; dayanaksızsa rc=3).

- bir desen tutarsa → sınıf **e**
- güvenli öneklerin **hiçbirini** tutmayan tek bir yol varsa → sınıf **"?"** → **Sultan**
- güvenli önek listesi bilerek **dardır**; onu genişletmek bir yetki genişletmesidir,
  yani Sultan kararıdır

🔴 **Sınıf iki kez ölçülür.** Kart açıldığında henüz diff yoktur; `devam` gerçek diffi
ölçer. Gerçek sınıf karttakinden **yukarı** çıkmışsa birleştirme YOK. Aşağı inmişse de
kartın sınıfı **korunur** — sınıf aşağı çekilmez.

### 5 · KAYDET

Üretilen yetenek bulgu havuzundaki **kaynak satırlara** bağlanır (hangi tekrarı
kapattığı yazılır) ve o satırlar `kapandi` damgası alır. Damgasız kapanış, bir sonraki
turda aynı tekrarı yeniden keşfetmek demektir — 30 günde 8 kez ölçüldü.

## Komutlar

```
bileyi.sh olc   [--gun N] [--esik N]    ölçüm raporu — YAZMAZ, hüküm vermez
bileyi.sh durum                          son tur · kill-switch hâli · eşik ve dayanağı
bileyi.sh dur   --gerekce "…"            otonom turu KAPAT (olc/durum kesilmez)
bileyi.sh ac    --gerekce "…"            otonom turu aç
bileyi.sh tur   [--kuru]                 ölç + adayı havuza yaz + tur durumu bırak
bileyi.sh kart  --is <ad> --hedef <yol>… sınıfı KÂHİN cevaplar, kartı AÇAR
bileyi.sh devam --is <ad> --dal <dal>     kanıt + bağımsız göz + SINIFSIZSA birleştir
```

## Sınırlar / dürüstlük

- Bu komut **sürtünme üretmez**, var olanı görür. Havuz boşsa çıktı da boştur.
- Tekrar sayımı bir **yargıya** girdi hazırlar, yargının kendisi değildir: hangi cinsten
  yetenek üretileceği (kural · yapılandırma · beceri) muhakeme ister.
- İkili söz öbeği ölçütü **dile bağlıdır**; başlıkları başka bir dilde yazan bir oda için
  aynı eşik geçerli değildir ve araç bunu her koşuda söyler.
- 🔴 **Ölçmediğini söyler:** bir sürtünmenin *maliyeti* bu aracın konusu değildir. Kaç kez
  olduğunu sayar, kaç dakika yediğini **bilmez** ve oraya "temiz" demez — hiç bakmaz.
- 🔴 **Çelişki kapısı:** iki yüzey aynı aday hakkında zıt şey söylüyorsa (biri "N kez
  tekrar etti", öbürü "tek parti") o aday hüküm üretmez; hepsi çelişiyorsa **rc=3** —
  ne temiz ne kirli. Bu kapı da belgede yazılıp uygulanmamıştı; bağımsız göz yakaladı.
- Kendi sınavı: `bash scripts/bileyi.test.sh` (**54 kapı**, hermetik — gerçek havuza,
  gerçek anahtara dokunmaz). Kapılar mutasyonla sınandı: eşik dayanağı · havuz yokluğu ·
  boş kimlik · tek-parti · kapsama · sürtünme bilinmezliği · kill-switch · bozuk satır ·
  eşik sıfırı öldürülünce sınav **kırmızıya döner**.
- 🔴 **Mutasyon düzeneğinin kendi pozitif kontrolü var** ve niçini utandırıcıdır: ilk
  koşumda bir kopyalama uyarısı yüzünden dizine hiç geçilmemişti ve **on mutasyon da
  "kırmızı" bastı** (rc=127) — yani mutasyonlar değil kırık düzenek ölçülmüştü. Artık
  temiz hâl önce ve sonra ölçülür; temiz hâl kırmızıysa koşum **geçersiz** sayılır.
