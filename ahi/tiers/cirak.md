# Kademe-Kartı — ÇIRAK (S1 · Yerel Skill)

> generic-goal: **"işi yapıyor"** (CMMI GG1 Performed). Projeye-özgü, global-DEĞİL, basit.

| # Boyut | Tanım |
|---|---|
| 1 **nedir** | Tek bir projede işi gören basit skill; henüz paketlenmemiş, tekrarlanabilirlik-kanıtı yok. |
| 2 **nerede-yaşar** | O projenin `.claude/skills/<ad>/` dizini (monorepo-içi doğrudan-ref; anlık-etki). |
| 3 **üretim-reçetesi** | `ahi new cirak <ad>` → minimal SKILL.md + scripts/ iskeleti (manifest-driven, placeholder-doğrulamalı). |
| 4 **isim+dosya-yapı** | Çıplak-ad + fonksiyon-soneki; `<ad>/SKILL.md` (+ `scripts/` gerekirse). |
| 5 **on/off** | Provizyon: dizinde-VARLIK. Runtime: `activation:` bloğu (opsiyonel) / `disable-model-invocation`. |
| 6 **test/doğrulama** | Manifest-şema-valid + placeholder-doğrulama (dolmamış `{{}}` → RED). |
| 7 **dağıtım** | YOK (tek repoda kalır; harness o projenin `.claude/skills`'ini tarar). |
| 8 **yaşam-döngüsü** | Sürüm-opsiyonel; emeklilik = dizini-kaldır (yerel + tüketicisiz → **DELETE serbest**, sunset-mekanizması gerekmez; SOFT-AMA-SUNSETLİ değişmezi yalnız Kalfa+ için). |
| 9 **terfi (→Kalfa)** | Eklenecek eksen: **on/off-paketlenebilirlik**. Checklist: paketlendi mi? · frontmatter-sözleşmesi tam mı? · `ahi check` temiz mi? · ≥1 başka-proje "bana da kur" dedi mi (sinyal)? |

**Çırak→Kalfa terfi-sinyali:** skill >1 projede işe yarıyor VEYA başka-proje talep-ediyor → `ahi promote` (Sultan-tören).
**hedef-kademe notu:** bazı yerel-yardımcılar Çırak'ta kalır (hakettiği tavan); terfi-baskısı yok.
