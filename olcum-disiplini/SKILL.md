---
name: olcum-disiplini
type: agent
version: 1.0.0
description: >
  Bir ÖLÇÜMÜN gerçekten ölçüm olduğunu denetler. Üç araç: `boru` (çıkış kodu bir
  görüntü süzgecinin arkasından okunuyor mu — kırmızı koşumu "temiz" gösteren sessiz
  hata), `negatif` (aynı negatifi ikinci kez ölçme; append-only defter, kanıt zorunlu),
  `kart` (ölçümü kurmadan önce beş soru; defteri KENDİ sorar). 🔴 RC=3 ÖLÇÜLEMEDİ
  demektir, yeşil değil. "ölçtüm / kanıtladım / çalışıyor / temiz" demeden önce.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
---

# olcum-disiplini — "ölçtüm" demek yetmez

## Niçin var (ölçülmüş, 2026-08-23)

e-Logo hattının derin kazısında **altı ölçüm geçersiz** çıktı. Hiçbirinde araç bozuk
değildi; hepsinde **soru** yanlıştı:

| Sandık | Aslında ölçtük |
|---|---|
| Portalın KDV-dahil kipini destekleyip desteklemediğini | NET fiyata "bu brüttür" etiketi yapıştırılınca ne olduğunu — anlamsız bir girdiyi |
| Formdaki alan sayısını | Yalnız ışık-DOM'daki alan sayısını (alanlar gölge-DOM'daydı) |
| Fatura toplamını | "Yazıyla tutar" satırını, üstelik kırpılmış hâlde |
| Tablodaki kalem sayısını | **Düzenleme kipindeki** satır sayısını (kipten çıkınca sayım hep "1") |
| "Ekle düğmesi bozuk" | Önkoşulu sağlanmamış bir akışı — cevap zaten ekrandaydı |

Ve aynı gün, **iki ayrı kutuda, iki ayrı ajan, aynı hata**:

```
bash sinav.sh | tail -3 ; echo "rc=$?"      ← tail'in kodunu okur, sınavın DEĞİL
```

MUHASİP (MMEx) bunu iki kez yaptı ve yanılgı defterine yazdı. MUAVİN (merkez) aynı gün
canlı doğrulamada aynısını yaptı: `exit=0` gördü, "temiz" sandı; çıplak koşunca **1**'di.
Kural **ikisinde de yazılıydı**. Sonuç açık: bu bir *"dikkatli ol"* maddesi değil,
**mekanik kapı** olmak zorunda.

## Değişmezler

- 🔴 **Bu araç ölçüm YAPMAZ**, ölçümün KURULUŞUNU denetler.
- 🔴 **RC=3 = ÖLÇÜLEMEDİ, yeşil değil.** Negatif defteri yoksa *"daha önce ölçülmedi"*
  denmez — yokluk kanıt değildir.
- 🔴 **Kanıtsız negatif yazılamaz.** Kanıtsız bir negatif kaydı, ölçülmemiş bir şeyi
  "ölçüldü" diye gelecek turlara satar.
- 🔴 **Defter append-only.** Ölçülmüş negatif silinmez.

## `boru` — çıkış kodu nerede okundu

```
olcum-disiplini.sh boru <dosya|dizin>...
```

Bir boru hattının çıkış kodu **son komutununkidir**. Tehlike, hattın bir **görüntü
süzgeciyle** bitmesidir (`tail` `head` `cat` `tee` `sed` `less` `tr` `column` …): o
süzgeç neredeyse hep 0 döner, yani **kırmızı bir koşum "temiz" görünür**.

Güvenli sayılanlar — yanlış-pozitif üretmemek için: `set -o pipefail` varsa ·
`${PIPESTATUS[…]}` kullanılıyorsa · `||` · tırnak içindeki `|` · ve **`grep`/`wc` ile
biten borular** (orada çıkış kodu kasıtlı bir yargıdır).

> **Kural bir kez daraltıldı.** İlk hâl "boru + `$?`" gören her yeri işaretliyordu ve
> gerçek depoda **yedi yanlış-pozitif** üretti; hepsi `printf … | grep -q …` deseniydi,
> yani grep'in kodu **kasten** okunuyordu. Gürültülü kapı kapatılan kapıdır: kesinlik
> kapsamdan önce gelir.

## `negatif` — aynı negatifi ikinci kez ölçme

```
olcum-disiplini.sh negatif yaz --iddia "…" --kanit "…"
olcum-disiplini.sh negatif sor --iddia "…"
```

Kazıda aynı negatif **üç ve dört kez** ölçüldü (~25 dakika). Yanılgı defteri iş
**bittikten sonra** yazıldığı için hiçbirini engellemedi. Bu defter ölçümden **önce**
sorulur; eşleşme bulanıktır (kelime kümesi benzerliği), bulunca önceki **kanıtı** basar.

## `kart` — ölçümü kurmadan önce beş soru

```
olcum-disiplini.sh kart --hipotez "…" --degisken "…" --beklenen "…" \
                        --gecersiz "…" --ortam "…"
```

| Alan | Soru |
|---|---|
| `hipotez` | Neyin doğru olduğunu sanıyorum? |
| `degisken` | **TEK başına** neyi değiştiriyorum? |
| `beklenen` | Fark ne olmalı — sayı ya da gözlem? |
| `gecersiz` | Bu ölçümü **geçersiz** kılacak şey ne? |
| `ortam` | Bu iddiayı hangi ortam **kanıtlayabilir**? |

Yukarıdaki altı geçersiz ölçümün altısı da bu beş sorudan birine takılırdı. Eksik alan →
**RC=2**: *eksik kart, ölçümü değil ümidi kaydeder.*

🔴 **Kartın çağıranı burada:** kart, negatif defterini **kendiliğinden** sorar. Böylece
defter gönüllülüğe kalmaz.

## Çağıran kim — dürüst tablo

| Parça | Çağıran | Mekanik mi |
|---|---|---|
| `boru` | Depo lint'i (`*.sh` taraması) | ✅ evet |
| `negatif sor` | `kart` onu kendiliğinden çağırır | ✅ evet |
| `negatif yaz` | Ölçümü yapan | ❌ hayır — dürüst sınır |
| `kart` | Ölçümü kuran; ayrıca `geri-alinamaz-is` Kapı-0 artefaktı olarak istenebilir | ⚠️ kısmen |

## Kanıt

`scripts/olcum-disiplini.test.sh` → **28 kapı**, hermetik (gerçek deftere/depoya dokunmaz).
Kapsanan: **bugünün iki gerçek vakası** (aynı satır ve sonraki satır biçimleri) ·
pipefail kalkanı · PIPESTATUS · çıplak komut · `||` · tırnaklı `|` · **grep ile biten
boru yanlış-pozitif üretmez** · wc · dizin taraması · yol yok → rc=2 · defter yokken
rc=3 · kanıtsız negatif reddi · bulanık eşleşme · kanıt basımı · append-only · eksik
kart · kartın defteri kendi sorması.

**Gerçek-veri regresyonu:** iki bağımsız korpus — beceri deposu (**140** `.sh`) ve Nexus
`scripts/` (**215** `.sh`) → ikisinde de **0 bulgu, 0 yanlış-pozitif**; ve aynı araç
bugünün iki gerçek vakasını fikstürde yakalıyor.

> ⚠️ **Aracın kendi kusuru, kayda geçiyor:** ilk sürümde kalkan kontrolü
> `'pipefail' in metin` idi — **düz alt-dizge**. Deneme dosyasındaki `pipefail_yok`
> ifadesi kalkan sanıldı ve gerçek bir vaka **sessizce atlandı**. Bu, aynı gün ölçülen
> muhafız kusurunun birebir ikizidir (izin belirteci tehlikeli ifadenin İÇİNE gömülünce
> izin veriyordu). Kelime sınırına geçildi, regresyon sınavı eklendi.
