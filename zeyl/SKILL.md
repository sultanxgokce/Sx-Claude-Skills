---
name: zeyl
type: agent
version: 1.0.1
description: >
  Sultan'ın gün içinde söylediği gereklilikleri sessizce deftere düşürür ve verdikt almadan
  yaşamalarına izin vermez. Ölçüldü: 6 günde 72 kalemin 45'i (%62) hiçbir dosyaya inmemiş,
  compaction üçünü fiilen yemiş, Sultan aynı şeyi tekrar söylemek zorunda kalmış ("hâlâ"
  kelimesi 5 mesajda 6 kez). Yeni depo AÇMAZ — seyir-defterinin kendi dosyasına, aynı
  şemayla yazar. Kanıtsız "yapıldı" REDDEDİLİR. jsonl append-only · sır-hijyenik ·
  kimlik uydurma-YOK · fail-closed.
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
---

# zeyl — söylenen şey uçmasın

> **Zeyl** (ذيل): bir yazının sonuna eklenen ek, hâşiye. Bu araç konuşmanın sonuna
> düşülen nottur — ana metni değiştirmez, ama kaybolmasını engeller.

## Niçin var (ölçüldü, tahmin değil)

Sultan'ın 6 günlük oturum transkripti sayıldı: **27 mesaj · 16'sı gereklilik taşıyor ·
72 kalem · diske inen 27 · hiçbir dosyada olmayan 45 (%62).** Aynı oturumdaki compaction
üç kalemi fiilen yedi. Kayıtsızlığın faturasını Sultan kesiyordu, sistem değil.

Eksik olan **motor değil, test ve çağıran**dı — bu paket o ikisini getirir.

## Üç şart

| Şart | Karşılığı |
|---|---|
| **ÇAĞIRAN** | Kutunun kendi kimlik/SessionStart betiği `zeyl ozet` çağırır. **Yeni cron YOK.** Bekleyen yoksa hiç basmaz. |
| **ÇIKIŞ ZORUNLULUĞU** | `ham` kayıt verdiktsiz yaşayamaz; `doktor` rc=1 verir ve **vermeye devam eder**. Giriş tavanı YOK — tavan çıkıştadır. |
| **DOĞRULAMA** | `zeyl doktor` diskten TÜRETİR, saklanmış özet basmaz (saklanan bayatlar). |

## Komutlar

```
zeyl yaz "<Sultan'ın cümlesi>" [--kaynak=<küme>] [--tur-no=<n>] [--proje=<ad>] [--not="…"]
zeyl bekleyen                    # verdikt bekleyen ham kayıtlar (toplu soru için)
zeyl verdikt <id> <acik|dustu|engelli> [--sebep="…"] [--ref=<id|bağ>]
zeyl yapildi <id> --kanit=<commit|dosya|PR#>
zeyl ozet                        # tek satır; bekleyen yoksa SESSİZ
zeyl doktor                      # 0 sağlıklı · 1 ihlal · 2 ölçülemedi
```

`--kaynak` kapalı kümedir: `kullanim-testi · gun-ici-not · canli-kullanim · denetim-bulgusu ·
sultan-talebi · kod-incelemesi · hata-sonrasi · bilinmeyen`. `bilinmeyen` seçilirse **`--not`
zorunludur** (taşma valfi) ve payı %20'yi geçerse doktor uyarır: *hata ajanda değil KÜMEDE.*

**`tur` ile `tur-no` ayrı boyuttur.** "1. kullanım testi mi 3. kullanım testi mi" derken tür ve
sıra iki farklı şeydir; `1-kullanim-testi` diye enum'a gömülseydi küme sonsuz büyürdü.

## Defter — nereye yazar

Kardeş araç `seyir-defteri` ile **aynı dosyaya**, aynı şemayla. Yol çözümü de aynı sözleşme:
`SEYIR_DEFTERI` env → yoksa **git-kökü** → yoksa **rc=2**.

⛔ **Ortak-mount fallback YOK.** Git-kökü bulunamazsa `$HOME/.claude`'a düşmez. O dizin 15
kutunun paylaştığı yerdir; oraya düşen defter bir kutunun gerekliliklerini ötekilere açar
(İ1'i geri alınamaz biçimde deler) ve hiçbir projenin kendi defteriyle birleşmez.

🔴 Bu, devralınan sürümde **bir kusurdu**: defter betiğin yanında aranıyordu, MİHENK'te
tesadüfen doğru yere denk geliyordu. Global kurulumda düşeceği yer ortak dizindi.
Kapılar `G-A` ve `G-B2` bunu kilitler.

## Seyir-defteri şemasına eklenen üç delta

1. `tur` += **`gereklilik`**
2. `kaynak` + `tur_no` (provenans; mevcut `baglam` alanı bunu karşılamıyordu — o dosya:satır tutar)
3. `durum` += **`ham`** (verdikt almamış) ve **`yapildi`** (canlıya indi, kanıtlı)

🔴 **`onaylandi` BİLEREK YOK.** O bir insan alanıdır (A06): `yapildi` üretici beyanıdır,
"Sultan onayladı" hükmünü hiçbir ajan kendi eliyle veremez. Alanı açmak Sultan kararıdır.

## Kapılar

`zeyl.test.sh` → **20 kapı, çift yönlü** (ALTIN yüz + KIRMIZI yüz + globalleştirme kapıları).

🔴 **ALTIN yüz niçin şart:** yalnız kırmızı fikstürle "her şeye kırmızı de" diyen bir betik de
sınavı geçerdi. ALTIN, **boş defterin ONURLU olduğunu ve alarm ÜRETMEDİĞİNİ** kilitler.

| Kapı | Davranış |
|---|---|
| kanıtsız `yapildi` | RED — kanıt gerçekten çözülmeli; beyan yetmez |
| çözülemeyen kanıt | RED |
| sebepsiz `dustu` | RED — "yapmayacağız" bir karardır, gerekçesi kaydedilir |
| refsiz `engelli` | RED |
| sır-deseni | RED — defter değer taşımaz |
| küme-dışı `kaynak` | RED · `bilinmeyen` ise not ZORUNLU |
| defter yok | **rc=2 ÖLÇÜLEMEDİ** — "temiz" DEĞİL |
| bozuk satır | atlanır ama **sayılır ve raporlanır** — gizlenmez |
| git-kökü yok + env yok | **rc=2** — ortak dizine DÜŞMEZ (G-A) |
| kurulum dizini | defter oraya SIZMAZ (G-B2) |
| kimlik | sabitlenmiş kutu-adı YOK; verilmezse `host:dizin` (G-C) |

**Üreten ⟂ doğrulayan:** uyarı basılır, **ENGELLENMEZ** (iz `ayni_kimlik:true` olarak düşer).
🔴 Çok-ajanlı kutularda bunun SERT olması gerekebilir — açık karar.

## Dürüst sınırlar

- **Bayatlık eşiği YOK.** 14 gün önerilmişti ama tek vakadan devralınmış bir sayıdır;
  ölçülmeden sert ilan edilmez (K01). Zeyl yaş basar, eşik dayatmaz.
- **Çağıran kutu-başınadır.** Bu paket komutu verir; her kutunun kendi kimlik betiğine
  bağlanması ayrı adımdır ve `zeyl ozet` bekleyen yoksa sessizdir (fail-open).
- **Devralınan betik bir kez yalan söyledi** (okuyucu "hoşgörülü" yazılmıştı, kod değildi;
  beş kayıt aynı id'yi aldı) **ve testi onu yakalamadı; şimdi yakalıyor.**

## Kaynak

MİHENK/NİŞANCI tarafından yazıldı ve o kutuda kanıtlandı; merkeze (SERDAR) globalleştirme
için devredildi. Yol/kimlik sözleşmesi ve `G-*` kapıları devir sırasında eklendi.
