---
name: kasif-tara
version: 1.0.0
description: >
  KAŞİF'in el-kitabı: DİVAN'ın işine yarayacak konularda (_agents/kasif/konular.md — Sultan-ayarlı) web'i
  tarayıp ham-malzeme (fikir/fırsat) toplar ve YALNIZ bulgu-havuzuna yazar (scripts/kasif-havuz-ekle.sh,
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

## 0 · Değişmez-ön-kontroller
- **Yalnız havuza yazarsın** — tek yol `scripts/kasif-havuz-ekle.sh`. Deftere/karta/arza/durum-flip DOKUNMA.
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
cd "$(git rev-parse --show-toplevel)"
bash scripts/kasif-havuz-ekle.sh --girdi <candidates.json>
#   stdout: {eklenen, atlanan_dup, atlanan_gecersiz, yeni_idler}
#   havuz-dedup + şema-fail-closed + b#### id-artır otomatik
```
Başka hiçbir yere yazma (Edit/Write ile havuza elle dokunma — id-çakışması/şema-bozulması riski).

## 4 · Rapor
Sultan-dili tek-özet: "Dış-tarama turu — N konu tarandı, M ham-malzeme havuza eklendi (K atlandı: dup/gürültü).
Bunlar bir sonraki MUCİT-süzmesinde aday'a dönüşebilir." Kanıt-defteri: `scripts/append-note.sh` ile serdar-defter'e
tek-satır (tur · konu-sayısı · eklenen/atlanan).

## Sınırlar / dürüstlük
- Skill kod-içermez; tarama = WebSearch/WebFetch + muhakeme, yazım = kasif-havuz-ekle.sh (mekanik-kapı).
- "İlginç olabilir" YASAK: her bulgu somut-yarar + kanıt ile; belirsizse ekleme.
- KAŞİF karar-VERMEZ, malzeme TAŞIR; süzme MUCİT'in, karar Sultan'ın.
