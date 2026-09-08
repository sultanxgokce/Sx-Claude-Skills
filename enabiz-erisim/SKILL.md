---
name: enabiz-erisim
type: agent
version: 1.0.0
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
description: e-Nabız'a (enabiz.gov.tr) e-Devlet kimliğiyle PANELE GİRMEDEN, headless Chromium ile girer; tahlil · ilaç raporu · patoloji · epikriz · radyoloji rapor PDF'lerini ve Teletıp radyoloji GÖRÜNTÜLERİNİ (WADO JPEG/DICOM) indirir; mevcut arşivle METİN-eşleşmesiyle dedupe eder. Kimlik merkezî kasadan (vault-cek · EDEVLET_TC / EDEVLET_SIFRE, kiracı nexus) gelir, bir daha sorulmaz; değer stdout/log/chat'e ASLA. "e-Nabız'a bağlan · teyzemin raporlarını çek · e-Nabız'da yeni ne var · radyoloji görüntülerini indir" tetiğinde. Kaynak-deneyim: OrucAi 2026-09-08 (bkz. Tuzaklar).
tags: [enabiz, e-devlet, saglik, erisim, platform-access, playwright, wado, teletip, pdf, secret-hygiene]
---

# enabiz-erisim

e-Nabız kişisel sağlık kayıtlarına **e-Devlet ile giriş** yapıp rapor PDF'lerini ve radyoloji
görüntülerini indiren erişim skill'i. Panel yok, ekran yok: headless Chromium (Playwright) + oturum
çerezleriyle doğrudan HTTP.

## Ne zaman
- "e-Nabız'dan yeni raporları çek", "tahliller güncel mi", "radyoloji görüntülerini indir".
- OrucAi (Fatma Oruç arşivi) güncellemesi — akışın devamı için `OrucAi/CLAUDE.md → Dosya Ekleme Süreci`.

## Kullanım
```bash
E=/config/.claude/skills/enabiz-erisim/scripts/enabiz.py
PY=/config/.local-py/python/bin/python
$PY $E doctor                 # 3-durum: kasa-anahtarı · chromium+fontconfig · enabiz erişilebilir
$PY $E login                  # e-Devlet ile gir → oturum state.json (çalışma dizinine, 600)
$PY $E liste  --out liste.json         # tahlil/rapor/patoloji/epikriz/radyoloji listeleri (tam yıl aralığı)
$PY $E indir  --liste liste.json --out indir/   # tüm PDF'ler (rapor türlerine göre alt-klasör)
$PY $E goruntu --out goruntu/ [--acc 2258451392]  # Teletıp WADO ile JPEG kareler (varsayılan: hepsi)
$PY $E dedupe --indir indir/ --mevcut sistem/ --out yeni.json  # metin-benzerliğiyle yeni dosyaları ayır
```
Kimlik: `vault-cek get EDEVLET_TC` ve `EDEVLET_SIFRE` (kiracı **nexus**; `~/.config/cortex-access.env`'e düşer).
Kasada yoksa `login` kırmızı verir ve tek satırla nasıl konulacağını söyler (`put … --tenant nexus --stdin`).

## Omurga (erisim-skill-fabrikasi · 7-madde)
1. **Tek-sefer gizli intake** — TC/şifre `read -rsp` + `--stdin` ile kasaya; chat'e/argv'ye düşmez.
2. **Kimlik = e-Devlet** — e-Nabız'ın kendi şifresi gerekmez. e-Devlet'te "iki aşamalı giriş" KAPALI ise SMS
   sorulmaz (Fatma Oruç hesabında kapalı, 2026-09-08). Açıksa `login` SMS'i `--otp` ile ister; kod telefondadır.
3. **Oturum yeniden-kullanımı** — `state.json` çerezleri ~30 dk geçerli; `liste/indir/goruntu` önce onu dener,
   düşmüşse `login` çağırır.
4. **Sır-hijyeni** — TC/şifre yalnız ortam değişkeninde; loglara **uzunluk** yazılır, değer yazılmaz.
   e-Devlet onay sayfası TC'yi düz metin basar: `inner_text` çıktısını **chat'e kopyalama**.
5. **Salt-okur** — hiçbir e-Nabız ayarını, paylaşımı, "profilimde görünmesin"i değiştirmez.
6. **Fail-closed** — PDF baytları `%PDF` ile başlamıyorsa dosya yazılmaz; WADO yanıtı JPEG değilse atlanır.
7. **Hasta verisi hassastır** — indirilenler proje dışına (scratch, pCloud public klasörü dışı) yazılmaz; commit'e girmez.

## Tuzaklar (ölçülmüş, 2026-09-08 · OrucAi)
- 🔴 **Chromium çöküyor (`Target page … closed`) yalnız enabiz.gov.tr'de** → sebep Fontconfig: konteynerde
  `/etc/fonts/fonts.conf` yok, sayfa web-font yükleyince Skia `FATAL Not implemented`. Çözüm:
  `FONTCONFIG_FILE=/config/.config/fontconfig/fonts.conf` (DejaVu fontlarıyla; `doctor` kontrol eder, yoksa kurar).
- **Sayfalar server-render; JSON listesi YOK.** Tahliller `.accordion-item` kartları
  (`onclick="TahlillerPdfIndir(dil, tarih, kurumKodu)"`); rapor/patoloji/epikriz **DataTables** — DOM'da yalnız
  görünen sayfa var → `$.fn.dataTable.tables({api:true}).page.len(-1).draw()` ile hepsini göster.
- **Yıl filtresi varsayılan son 2 yıl.** `#baslangicyilSelect`'i en eski yıla çek + sayfanın `Get…ByDateList()` /
  `RadyolojiApp.getListByDate()` fonksiyonunu çağır (butonun selector'ı sayfadan sayfaya değişir; JS çağrısı sabit).
- **PDF uçları (GET, oturum çerezi yeter):**
  `/Tahlil/TahlillerPdf?baslangicYil&bitisYil&cardTarih=DD.MM.YYYY&kurumKodu&dil=tr-TR&sonucTuru=null` ·
  `/Rapor/RaporPdf?raporTakipNo` · `/Patoloji/GetPatolojiPdf?referansNo&sysNo` · `/Epikriz/GetEpikrizPdf?referansNo&sysNo`.
- **Radyoloji rapor PDF'i JSON içinde base64:** `/RadyolojikGoruntu/GetRaporPdfByOrder?orderId` →
  `{"rapor": "<b64>"}`; header `RequestVerificationToken: <input[name=__RequestVerificationToken]>` +
  `X-Requested-With: XMLHttpRequest` ŞART. `GetRaporByOrder` HTML verir; `…RaporPdf2` boş döner.
- **Görüntü = Teletıp WADO.** `/RadyolojikGoruntu/GetGoruntuLinkByOrder?AccessionNumber` → viewer URL'inde
  `otac` → `POST teleradyoloji.saglik.gov.tr/viewerbackend/viewerapi/CheckOTAC?otac=` → Bearer (60 dk) →
  `GET …/viewerapi/LoadWorkItemForENabiz?otac=` → `Patient.Studies[].Series[].Instances[]` (tüm hastanın çalışmaları) →
  `{WadoAddress}requestType=WADO&studyUID&seriesUID&objectUID&contentType=image/jpeg` (contentType'sız = DICOM ~500 KB).
  UID'ler `STR_<hex>` kodlu; olduğu gibi gönderilir. **SR/OT serileri 400 verir** — görüntü değildir, atla.
- **Dedupe tarihle YAPILMAZ** — sistem tarihi PDF içinden (istem/çekim tarihi), e-Nabız tarihi liste tarihi; farklı.
  PyMuPDF metni + `difflib.ratio ≥ 0.9` → aynı belge. Epikriz'de aynı protokol no = aynı belge (0.8 çıkabilir).
- Oturum başına hasta **tek** (e-Devlet kimliği kimin ise onun kayıtları); "yakınım" akışı bu sürümde yok.

## Ölçüm (2026-09-08, Fatma Oruç)
27 tahlil · 46 ilaç raporu satırı (24 PDF) · 22 patoloji · 7 epikriz · 81 radyoloji (62 rapor PDF) ·
67 Teletıp çalışması, 41'inde görüntü, **13.785 kare** (JPEG ~25 KB/kare ≈ 400 MB; DICOM ≈ 7 GB).
Yeni bulunan: 7 tahlil + 24 ilaç raporu + 7 radyoloji raporu + 2 epikriz = 40 PDF.

## Görüntü paketleme (`scripts/paketle.py`)
`goruntu/` altındaki her çalışma → `paket/<ad>.zip` (tüm JPEG + `_calisma.json`) + `<ad>_ozet.png` (her seriden
orta kare, 4 sütun kontakt tablo). OrucAi'de ZIP+PNG pCloud `enabiz/goruntu-arsiv/`'e gider; PNG kategori
`goruntuleme`/fileType `png`, ZIP fileType `zip` (UI proxy-indirir). ⚠ Paketlemeyi indirme **bitince** çalıştır;
yarım klasör yarım ZIP üretir.
- **Özel Dünya Hastanesi PACS'i (retrieveWadoId STR_31333938) ~40 kare/dk** — öbür hastaneler ~1000 kare/dk.
  Uzun sürüyorsa Dünya-dışı çalışmaları ikinci bir süreçle paralel indir (dosya varsa atlar, çakışmaz).
- ES (endoskopi) serilerinde bazı kareler 400 verir; atla.
- 🔴 **Bearer tek başına yetmez**: `CheckOTAC` sonrası `LoadWorkItemForENabiz?otac=` çağrılmadan WADO **401 "Yetkisiz
  Erişim"** verir. Token 60 dk; e-Nabız oturumu **30 dk idle**'da düşer (`SessionTimeoutABC`) → uzun indirmede her
  4 dk `/Home/Index` ping + 45 dk'da token yenile (skill bunu yapar).
