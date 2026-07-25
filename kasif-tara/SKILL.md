---
name: kasif-tara
version: 1.1.0
description: >
  KAŞİF'in el-kitabı: DİVAN'ın işine yarayacak konularda (_agents/kasif/konular.md — Sultan-ayarlı) web'i
  tarayıp ham-malzeme (fikir/fırsat) toplar ve YALNIZ bulgu-havuzuna yazar (<skill-dizini>/scripts/kasif-havuz-ekle.sh,
  tek yazma-yüzeyi). Deftere/karta/arza DOKUNMAZ; MUCİT'i atlayamaz. Her bulgu kanıt=kaynak-URL ister
  (fail-closed). Kesin süzme (dedup/MİHENK/tavan) downstream MUCİT-T1'de. (DİVAN k0054, doktrin §5/§9.)
disable-model-invocation: false
---

# /kasif-tara — KAŞİF dış-tarama kabuğu (web fan-out → havuz)

**NE-DİR:** DİVAN §9 "Fikir-hattı"nın DIŞ ucu. Fikir-hattı: **KAŞİF (dış-tarama) → havuz → MUCİT (süzgeç) →
aday → Sultan tek-tuş.** KAŞİF yalnız ilk-ucu besler. Kimlik: `_agents/kasif/BIRIM.md`.

## Tetik
| Çağrı | Davranış |
|---|---|
| `/kasif-tara` | konular.md'deki tüm aktif konularda tarama turu. |
| `/kasif-tara "<konu>"` | tek-konu odaklı tarama (konu konular.md kapsamında olmalı). |

## Kurulum — bu odada ilk kez mi? (tek komut, idempotent)
```bash
bash <skill-dizini>/scripts/kasif-kur.sh --kontrol   # önce bak: ne eksik? (hiçbir şey yazmaz)
bash <skill-dizini>/scripts/kasif-kur.sh             # kur: boş defterler + dizinler + nötr kanon
```
**Asla üzerine yazmaz** — ikinci koşu veri kaybettirmez. Yeni oda **üretime KAPALI doğar** (Sultan
açana dek); açmak için `layiha-fabrikasi` paketindeki `layiha-fabrika.sh ac`. Kurulum **proje (git)
klasörü** ister: git-siz dizinde RC=2 + reçete verir, ortak dizine ASLA yazmaz.
Kanıt: `<skill-dizini>/scripts/kasif-tara.test.sh` (G1-G8; G6 = ortak-dizine-sızma negatif testi).

## 0 · Değişmez-ön-kontroller
- **Yalnız havuza yazarsın** — tek yol `<skill-dizini>/scripts/kasif-havuz-ekle.sh`. Deftere/karta/arza/durum-flip DOKUNMA.
- **MUCİT'i atlayamazsın** — ham-malzeme havuza gider; aday/kart/Sultan-taşıma MUCİT'in işi, senin değil.
- **Kanıt zorunlu** — her bulgu `kanit` = kaynak-URL ya da doğrudan alıntı. Kaynaksız → kasif-havuz-ekle eler (fail-closed).
- **Kapsam Sultan-malı** — yalnız konular.md'deki konularda tara; MİHENK-alanı (ürün/pazar/gelir) DEFAULT tarama.

## 1 · Tara (web fan-out)
1. `_agents/kasif/konular.md` OKU — aktif konular + kalite-zemini + kapsam-dışı.
2. Aktif konu-başına **WebSearch** (paralel; ToolSearch ile şema-yükle: `select:WebSearch`). Taze + uygulanabilir öğe ara.
   Gerekirse **WebFetch** ile kaynağı derinleştir (kanıt-alıntısı çıkar).
3. Web-gürültüsünü ELE: pazarlama-yazısı/içi-boş-trend/genel-haber DEĞİL — somut desen/araç/teknik.

## 2 · Süz (kaba — kesin süzme MUCİT'te)
Her aday-öğe için:
- **baslik** (Sultan-dili, tek-cümle, jargonsuz) — "ne fikri/fırsatı".
- **detay** (1-2 cümle) — neden DİVAN'a-yarar, nasıl uygulanabilir.
- **kanit** (ZORUNLU) — kaynak-URL ya da doğrudan alıntı.
- **tip** — `bulgu` (iyileştirme/desen) | `firsat` (yeni-imkân).
- **MİHENK-farkındalık:** öğe saf ürün/pazar/gelir ise EKLEME (kapsam-dışı) ya da tip'te belirt — MUCİT-T1 zaten
  MİHENK-etiketler, ama gürültüyü kaynağında azalt.
- **Kalite-eşiği:** emin değilsen EKLEME (az-ama-öz; havuz-kirliliği MUCİT'in işini zorlaştırır).

## 3 · Yaz (TEK yol)
Adayları JSON-dizi dosyasına yaz (`[{baslik,detay,kanit,tip}]`) → 
```bash
cd <projenin kök klasörü>          # hangi odanın defterine yazdığın CWD'den belirlenir
bash <skill-dizini>/scripts/kasif-havuz-ekle.sh --girdi <candidates.json>
#   stdout: {eklenen, atlanan_dup, atlanan_gecersiz, yeni_idler}
#   havuz-dedup + şema-fail-closed + b#### id-artır otomatik
```
Başka hiçbir yere yazma (Edit/Write ile havuza elle dokunma — id-çakışması/şema-bozulması riski).

> 📍 **Hangi deftere yazıyorum?** Defter **odaya özeldir** (her proje kendi `_agents/handoff/`'una yazar).
> Motor bunu bulunduğun klasörden çözer — `<skill-dizini>`'nden DEĞİL. Proje klasörü dışındaysan komut
> **çalışmaz** (RC=2) ve doğru klasörü söyler; bu bilinçlidir: odalar birbirinin defterini görmez (İ1).

## 4 · Rapor
Sultan-dili tek-özet: "Dış-tarama turu — N konu tarandı, M ham-malzeme havuza eklendi (K atlandı: dup/gürültü).
Bunlar bir sonraki MUCİT-süzmesinde aday'a dönüşebilir." Kanıt-defteri: `scripts/append-note.sh` ile serdar-defter'e
tek-satır (tur · konu-sayısı · eklenen/atlanan) — **bu araç yalnız Nexus odasında var; yoksa bu adımı atla.**

## Sınırlar / dürüstlük
- Skill kod-içermez; tarama = WebSearch/WebFetch + muhakeme, yazım = kasif-havuz-ekle.sh (mekanik-kapı).
- "İlginç olabilir" YASAK: her bulgu somut-yarar + kanıt ile; belirsizse ekleme.
- KAŞİF karar-VERMEZ, malzeme TAŞIR; süzme MUCİT'in, karar Sultan'ın.
