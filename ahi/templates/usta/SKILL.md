---
name: {{NAME}}
type: agent
version: 0.1.0
description: >
  {{GENERIC_GOAL}} — (AHÎ ile üretildi; doldur: {{NAME}} hangi skilleri besteler, ne iş-sistemi kurar).
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [{{NAME}}, bilesik]
status: v0.1-usta
---

# {{NAME}} — (Usta · bileşik iş-sistemi)

**NE-DİR:** (doldur — hangi Kalfa-skilleri besteleyerek hangi çalışma-prensibini kurar).

## Besteleme
⚠️ `ahi.manifest.yaml` içindeki `requires[]`'i doldur (≥1 bileşen-skill). Boşken `ahi check` uyarır (DOCTRINE §10).
Bileşenler `.claude/skills/<kardeş>` yolundan çözülür (vendoring-YOK).

## Kademe
Usta (S3 · bileşik). generic-goal: "{{GENERIC_GOAL}}". Doğrula: `ahi check {{NAME}}` · Kanon: `ahi doctrine`.

## Geliştirme (KULLANDIKÇA GELİŞTİR — AHÎ §12)
Bu beceriyi kullanırken eksik/hata/daha-iyi-yol görürsen **düzeltmek senin işindir**:
1. Kendi kutunun canlı rafındaki kopyada düzelt.
2. **Sürümü yükselt** (yukarıdaki `version:`; davranış-düzeltmesi=patch · yeni yetenek=minor).
   Sürüm yükseltmeden düzenlersen dağıtım aracı dosyaya dokunmaz → düzeltmen sessizce kaybolur.
3. **Kanona döndür** — `Sx-Claude-Skills`'e PR; kutun kanonu görmüyorsa klasörü kuryenin giden
   kutusuna bırak + tek sayfalık devir notu (ne değişti · niçin · hangi işte kullanıldı).
4. Dağıtımı doğrula (hedef kutuda dosya fiilen duruyor mu) + deftere bir satır düş.

"Yalnız kendi rafımda düzelttim" = bir kutu kazandı, ötekiler kaybetti. Kanon: `ahi doctrine` §12.
