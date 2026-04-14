# Changelog — feedback-widget

## [1.0.0] — 2026-04-14

### Kaynak
MMEpanel M012 modülünden extract edildi.

### Özellikler
- Floating feedback butonu (sağ alt, fixed)
- Screen Capture API ile ekran görüntüsü (panel otomatik gizlenir)
- Dosyadan görsel yükleme
- Canvas annotation editörü (kalem, ok, kutu, metin, undo)
- Çoklu görsel desteği (pCloud veya base64 fallback)
- Geri bildirim tipleri ve öncelik seviyeleri
- Memnuniyet skoru (emoji 1–5)
- Geçmişim sekmesi + okunmamış yanıt göstergesi
- Yanıt thread'i (admin + kullanıcı, dahili not)
- SessionStorage draft persistence

### Bug Fix (1.0.0 içinde)
- **stale closure**: `handleScreenshotCapture` `[]` deps ile yaratıldığından
  `screenshots.length` her zaman 0 dönüyordu → `screenshotsRef` ile düzeltildi
- **AnnotationCanvas reset**: Yeni görsel gelince eski çizim state'i temizlenmiyordu
  → `imageBlob` useEffect'e state reset eklendi
