---
name: {{NAME}}
type: agent
version: 0.1.0
description: >
  {{GENERIC_GOAL}} — (AHÎ ile üretildi; bu açıklamayı doldur: {{NAME}} ne yapar, ne zaman tetiklenir).
install_target: { skills: .claude/skills/ }
stacks: ["*"]
author: sultanxgokce
tags: [{{NAME}}]
status: v0.1
---

# {{NAME}} — (Kalfa · paketli skill)

**NE-DİR:** (doldur — bu skill ne yapar, hangi işi güvenilir-tekrarlanabilir kılar).

## Kullanım
(doldur — komut/tetik + örnek)

## Kademe
Kalfa (S2 · paketli). generic-goal: "{{GENERIC_GOAL}}".
Manifest: `ahi.manifest.yaml` · Doğrula: `ahi check {{NAME}}` · Kanon: `ahi doctrine`.

## Geliştirme (KULLANDIKÇA GELİŞTİR — AHÎ §12)
Bu beceriyi kullanırken eksik/hata/daha-iyi-yol görürsen **düzeltmek senin işindir**:
1. Kendi kutunun canlı rafındaki kopyada düzelt.
2. **Sürümü yükselt** (yukarıdaki `version:`; davranış-düzeltmesi=patch · yeni yetenek=minor).
   Sürüm yükseltmeden düzenlersen dağıtım aracı dosyaya dokunmaz → düzeltmen sessizce kaybolur.
3. **Kanona döndür** — `Sx-Claude-Skills`'e PR; kutun kanonu görmüyorsa klasörü kuryenin giden
   kutusuna bırak + tek sayfalık devir notu (ne değişti · niçin · hangi işte kullanıldı).
4. Dağıtımı doğrula (hedef kutuda dosya fiilen duruyor mu) + deftere bir satır düş.

"Yalnız kendi rafımda düzelttim" = bir kutu kazandı, ötekiler kaybetti. Kanon: `ahi doctrine` §12.
