---
name: feedback-widget
type: feature
version: 1.0.0
description: >
  In-app feedback widget — floating button, screenshot capture, canvas annotation,
  multi-image support, reply threads. FastAPI + Next.js / React için tam kurulum.
prerequisites:
  backend: FastAPI, SQLModel, PostgreSQL
  frontend: Next.js (App Router), React 19, Tailwind CSS v4, lucide-react
stacks: [fastapi+nextjs]
author: sultanxgokce
source: https://github.com/sultanxgokce/MMEpanel (M012)
tags: [feedback, widget, screenshot, annotation, fastapi, nextjs]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# Feedback Widget Skill

Kullanıcıların uygulamanın herhangi bir sayfasından geri bildirim gönderebildiği,
ekran görüntüsü çekip üzerine çizim yapabildiği, geçmiş bildirimleri ve yanıt
thread'lerini görebildiği tam kapsamlı bir modül.

## Özellikler

- Sağ altta sabit floating `💬` butonu
- Ekran görüntüsü yakalama (Screen Capture API) — panel otomatik gizlenir
- Dosyadan görsel yükleme
- Canvas annotation editörü (kalem, ok, kutu, metin, undo, temizle)
- Çoklu görsel desteği (sınırsız, pCloud veya base64 fallback)
- Geri bildirim tipleri: Bug / Özellik / Soru / Takdir
- Öncelik seviyesi: Düşük / Normal / Yüksek / Kritik
- Memnuniyet skoru (1–5 emoji)
- Geçmişim sekmesi — durum badge'i, okunmamış yanıt göstergesi
- Yanıt thread'i (admin + kullanıcı, dahili not desteği)
- SessionStorage ile draft ve görsel persistence
- Otomatik sayfa URL ve browser info etiketleme

---

## Kurulum Adımları

### 1. Backend — Model

`backend/models/feedback.py` dosyasını oluştur.
Kaynak: `templates/backend/model.py`

**Adaptasyon notları:**
- `from backend.models.user import User` → kendi User model import path'ini kullan
- `TZ = ZoneInfo("Europe/Istanbul")` → projenin timezone'una göre değiştir
- `users` tablosu foreign key'i → kendi users tablon adına göre düzenle

### 2. Backend — Schema

`backend/schemas/feedback.py` dosyasını oluştur.
Kaynak: `templates/backend/schema.py`

**Adaptasyon notları:**
- `UserMinimal` schema'sını kendin tanımlıyorsan düzenle
- `FeedbackListParams` query param'larını ihtiyacına göre genişlet

### 3. Backend — Endpoint

`backend/api/v1/endpoints/feedback.py` dosyasını oluştur.
Kaynak: `templates/backend/endpoint.py`

**Adaptasyon notları:**

```python
# 1. Import'ları düzenle:
from backend.core.security import get_current_user   # → kendi auth dependency'n
from backend.db.session import get_session            # → kendi session factory'n
from backend.models.user import User                  # → kendi User modelin
from backend.models.feedback import Feedback, FeedbackReply, FeedbackReaction
from backend.schemas.feedback import FeedbackCreate, FeedbackRead, FeedbackDetail

# 2. pCloud servisi yoksa upload endpoint'ini düzenle:
# Varsayılan olarak pCloud'a yükler, başarısız olursa base64 fallback devreye girer.
# Kendi dosya storage servisine adaptasyon için /upload-screenshot endpoint'ini bul
# (dosyanın en altında) ve PCloudService çağrısını kendininkiyle değiştir.

# 3. Router'ı ana api.py'a ekle:
from backend.api.v1.endpoints.feedback import router as feedback_router
app.include_router(feedback_router, prefix="/api/v1/feedback", tags=["feedback"])
```

### 4. File Upload Servisi — pCloud

Feedback screenshot'ları pCloud'a yüklenir, public link DB'ye kaydedilir.
Kaynak: `templates/backend/pcloud_service.py`

**Varsayılan hedef klasör (Sx-Claude-Skills / AiSkills):**
```
Klasör ID : 23473046120
Public URL : https://filedn.eu/lNbvMu0swIW8D7ExzploSu8/Sx-Claude-Skills/AiSkills/{dosya}
```

**Ortam değişkenleri:**
```
PCLOUD_USERNAME=<pCloud hesap e-postası>
PCLOUD_PASSWORD=<pCloud şifresi>
PCLOUD_FOLDER_ID=23473046120   # AiSkills klasörü — projeye göre değiştir
```

**Her proje için ayrı alt klasör açmak istersen:**
pCloud panelinden `AiSkills/` altında `{proje-adi}/` klasörü oluştur, ID'sini `PCLOUD_FOLDER_ID`'ye yaz.

pCloud istemiyorsan: Upload endpoint'indeki `PCloudService` bloğunu kaldır,
base64 fallback otomatik devreye girer (DB'de TEXT olarak saklanır).

### 5. Migration

```sql
-- Direkt SQL olarak çalıştır (idempotent):
```

Dosya: `templates/migrations/001_feedback_tables.sql`

Bu SQL'i çalıştırmak için:
```python
# backend/db/migrations/ altında _ensure_feedback_tables(engine) fonksiyonu var
# app startup'a ekle:
from backend.db.migrations.feedback import _ensure_feedback_tables
_ensure_feedback_tables(engine)
```

### 6. Frontend — Dosyaları Kopyala

```
templates/frontend/components/  →  src/components/feedback/
templates/frontend/hooks/        →  src/hooks/
templates/frontend/types/        →  src/types/
```

**Adaptasyon notları:**

```typescript
// useFeedback.ts içinde:
const BASE = "/api/v1/feedback";  // Backend route prefix'ini kontrol et

// api.ts'de (kendi API client'ın):
// apiFetch ve authorizedFetch export edilmiş olmalı.
// Yoksa useFeedback.ts'deki import'ları kendi fetch wrapper'ınla değiştir.

// getSession() → kendi session/auth hook'un
// session.role === "admin" kontrolünü kendi RBAC'ına göre ayarla
```

### 7. Frontend — Layout'a Widget'ı Ekle

```tsx
// app/layout.tsx veya ana layout dosyana:
import FeedbackWidget from "@/components/feedback/FeedbackWidget";

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        {children}
        <FeedbackWidget />   {/* ← Bunu ekle */}
      </body>
    </html>
  );
}
```

### 8. Admin Yönetim Sayfası (Opsiyonel)

Tüm kullanıcıların feedback'lerini admin olarak görmek için:
`/yonetim/feedback` sayfası — kendi admin routing'ine göre adapte et.

---

## Konfigürasyon

### Tip ve Öncelik Renkleri

`types/feedback.ts` içinde `FEEDBACK_TYPE_CONFIG` ve `FEEDBACK_PRIORITY_CONFIG` nesneleri var.
Renkleri, ikonları ve label'ları projenin tasarım sistemine göre düzenleyebilirsin.

### Widget Pozisyonu

`FeedbackWidget.tsx` içinde `fixed bottom-6 right-6` class'larını değiştir.

### Dosya Boyut Limiti

`backend/api/v1/endpoints/feedback.py` → `/upload-screenshot` endpoint'inde:
```python
if len(content) > 5 * 1024 * 1024:  # 5MB — değiştir
```

---

## Bilinen Kısıtlamalar & Notlar

1. **Screen Capture API** — Sadece desktop Chrome/Firefox destekler. Mobilde "Görsel Ekle" butonu görünür.

2. **stale closure fix** — `FeedbackPanel.tsx`'te `screenshotsRef` kullanımı kritik.
   `handleScreenshotCapture` `useCallback([], [])` deps ile yaratıldığından
   `screenshots` state'i closure'da her zaman `[]` görünür. `screenshotsRef.current`
   doğru index'i verir. Bu pattern'i bozmadan koru.

3. **pCloud fallback** — pCloud bağlantısı yoksa görsel base64 olarak DB'ye kaydedilir.
   Büyük görsellerde DB boyutu artabilir. Production'da pCloud veya S3 tercih et.

4. **sessionStorage persistence** — Sayfa yenilendiğinde draft ve görseller kaybolmaz.
   Her görsel JPEG 50% kalite ile sıkıştırılarak saklanır.

---

## Test Senaryoları

Her kurulumdan sonra şu senaryoları doğrula (Playwright ile):

```
1. Tek görsel — Görsel ekle → mesaj yaz → gönder → geçmişte 1 görsel
2. İki görsel — 2 görsel ekle → gönder → geçmişte 2 görsel görünmeli
3. Screen capture — Ekran görüntüsü al → annotation yap → kaydet → gönder
4. Yanıt — Admin yanıt ekledi → kullanıcı unread badge görüyor
5. Durum güncelleme — Admin "Çözüldü" yapar → badge değişir
```

---

## Versiyon Geçmişi

| Versiyon | Tarih | Not |
|----------|-------|-----|
| 1.0.0 | 2026-04-14 | MMEpanel M012'den extract — stale closure fix dahil |
