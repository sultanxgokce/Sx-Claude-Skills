---
name: mucit-suz
version: 1.0.0
description: >
  MUCİT'in el-kitabı: DİVAN bulgu-havuzunu (bulgu-havuzu.jsonl — KEŞŞAF dış-tarama + SERDAR pilot-bulguları)
  acımasızca süzüp Sultan-dilinde en çok haftada 3 ADAY-kart önerir. T1 = scripts/mucit-t1.sh ($0-mekanik:
  uygunluk·kanıt-kapısı·MİHENK-deny·kart-dedup·haftalık-tavan RC≠0); T2 = repo-grep "zaten var mı" +
  Sultan-dili aday-yazımı + etki×kolaylık×kanıt×hedef-uyum puanı. Kalibrasyon turunda adaylar deftere DEĞİL
  önizlemeye; canlı turda sevk-arz.sh aday ile Sultan tek-tuş. Kuyruğa kartı MUCİT SOKAMAZ. (DİVAN k0054, doktrin §9.)
disable-model-invocation: false
---

# /mucit-suz — MUCİT fikir-süzme kabuğu (T1-mekanik + T2-muhakeme)

**NE-DİR:** DİVAN-anayasası §9 "Fikir-hattı"nın icra aracı. Ham-malzemeyi (bulgu-havuzu) süzüp Sultan'ın
"düşünme yükünü azalt — basit onayla yürütülebilir hazır fikirlerle gel" vizyonuna hizmet eder. **Fikir
ÜRETMEZ, fikir SÜZER** — kaynak KEŞŞAF (dış) + SERDAR (pilot/iç). Kimlik: `_agents/mucit/BIRIM.md`.

## Tetikler
| Çağrı | Davranış |
|---|---|
| `/mucit-suz` ya da `/mucit-suz kalibrasyon` | Kalibrasyon turu: süz → **tek-sayfa önizleme** (defter YOK). İLK 2 tur ZORUNLU bu mod. |
| `/mucit-suz canli` | Canlı tur: süz → aday-kart (durum=aday) + `sevk-arz.sh aday` (Sultan tek-tuş). Yalnız kalibrasyon bitince. |

## 0 · Değişmez-ön-kontroller (koşmadan önce)
- **Kuyruğa SOKAMAZSIN.** En fazla `aday-arzı` mint edersin; aday→kuyruk flip'i YALNIZ Sultan (respond-endpoint).
- **Haftada ≤3.** T1 kota-kilidini (RC=3) ASLA baypas etme; kalan-kotadan fazla aday üretme.
- **Fail-closed.** Emin değilsen aday AÇMA. Kill meşru sonuçtur; şişirme değil.
- **Sultan-dili.** Aday-metni jargonsuz (sevk-arz.sh'ın `_jargon_uyar` bekçisi de tarar).

## 1 · T1 — mekanik prefilter (script, $0)
```bash
cd "$(git rev-parse --show-toplevel)"
bash scripts/mucit-t1.sh suz            # stdout=JSON kontrat, stderr=eleme-özeti
#   RC 0 → adaylar emit (JSON: {hafta,tavan,uretilen,kalan,uygun_sayi,mihenk_alani,adaylar[]})
#   RC 3 → HAFTA-TAVAN dolu → DUR: bu hafta yeni aday YOK (Sultan-dili tek-satır rapor, çık)
#   RC 2 → girdi/kullanım hatası → düzelt
```
- `kalan` = bu hafta üretilebilecek aday tavanı. **T2 bundan fazla üretemez.**
- `mihenk_alani` = ürün/pazar/gelir bulguları → aday DEĞİL; Sultan'a "MİHENK-alanı" notu olarak AYRI sunulur.
- `adaylar[]` = mekanik-kapılardan geçen ham-adaylar (ön-skora göre sıralı). Bunlar T2-girdisidir.

## 2 · T2 — muhakeme (bu skill; her aday-ADAYI için)
Her `adaylar[]` öğesi için sırayla:
1. **repo-grep "zaten var mı"** — bulgunun işaret ettiği fix/özellik kodda/skript'te ZATEN var mı?
   `grep -rn`, `scripts/` + ilgili dizin. VARSA → aday AÇMA; mucit-defteri'ne `verdikt:elendi, not:"zaten-var: <yer>"`.
2. **Sultan-dili aday-kart yaz** — jargonsuz tek-cümle GOAL + 1-cümle niçin-değerli. Teknik-ad kart-detayına düşer, başlığa değil.
3. **Puanla (T2-takdiri, 1-5):** `etki` (Sultan'ın hissedeceği fark) × `kolaylık` (efor tersine) × `kanıt` (ne kadar sağlam) ×
   `hedef-uyum` (DİVAN kuzey-yıldızına — "düşünme yükünü azalt / defteri akıt / testsiz-tescil-yok"). Çarpım = sıra-skoru.
4. **Acımasız-ele → en iyi ≤`kalan`.** Skorca en üstteki `kalan` adayı SEÇ; gerisi `verdikt:elendi` (gerekçeyle).
   Şüphe hâlinde ele (kill meşru). Tek bir sağlam aday, üç zayıf adaydan iyidir.

## 3 · Çıkış — mod'a göre
### Kalibrasyon (varsayılan · İLK 2 tur)
- Seçilen adayları **`_agents/handoff/mucit-onizleme-<turu>.md`** dosyasına yaz (tek-sayfa; her aday: başlık ·
  Sultan-dili GOAL · puan-kırılımı · kaynak-bulgu-id · niçin-değerli). Defter/arz'a DOKUNMA.
- Sultan'a sun: "Fikir-hattı turu-<n> önizlemesi hazır — <N> aday. Hangilerini beğendin / 'bu sınıfı getirme' dediklerin?"
- Sultan geri-bildirimi (beğeni + "bu sınıfı getirme") → **deny-profile**'a işle (sonraki turda o sınıf elenir).
- mucit-defteri'ne her aday `verdikt:preview` satırı (tavana SAYILMAZ).

### Canlı (kalibrasyon bittikten sonra)
- Her seçilen aday için: prod-deftere aday-kart oluştur (durum=`aday`; defter-mailbox akışıyla) → `k####` al.
- `bash scripts/sevk-arz.sh aday <k####>` → source=`aday-arzi`, Sultan defterde tek-tuş görür.
- mucit-defteri'ne `verdikt:aday-arzi, kart:<k####>` (bu tavana SAYILIR).

## 4 · mucit-defteri satır-şeması (append-only, git-tracked)
```json
{"turu":"kalibrasyon-0|canli-N","tarih":"YYYY-MM-DD","bulgu_id":"bNNNN","baslik":"...","verdikt":"aday-arzi|preview|elendi|mihenk-alani","kart":"k####|null","not":"gerekçe (elendi/mihenk için zorunlu)"}
```
- **Ölçüm:** kill-rate = elendi/(toplam) · **dönüşüm = aday→kuyruk (asıl sinyal)** → /durum nabız-satırı buradan.
- Redaction: satırlarda sır/token YOK (Sultan-dili özet).

## 5 · Kanıt-defteri (gate atlamadığını kanıtla)
`scripts/append-note.sh` ile `_agents/handoff/serdar-defter.md`'ye tek-satır: tur-no · T1-RC · uygun/geçen/aday
sayıları · kalan-kota. (Tavan-kilidi RC=3 ise "bu hafta tavan dolu, aday üretilmedi" satırı = meşruiyet-kanıtı.)

## Sınırlar / dürüstlük
- Skill kod-içermez; T1 mekaniği `mucit-t1.sh`'te, T2 muhakemesi burada talimat-akışıdır.
- "Değerli olabilir/muhtemelen" dili YASAK: her aday için etki+kanıt somut yazılır; belirsizse ele.
- Bu skill kuyruk-yetkisi VERMEZ; aday→kuyruk her koşulda Sultan tek-tuşundan geçer.
