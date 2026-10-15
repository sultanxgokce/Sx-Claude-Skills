#!/usr/bin/env bash
# Playwright ortamı — root'suz kutuda Chromium'u GERÇEKTEN çalışır hâle getirir.
# Kaynak: MUHASİP firsthand ölçümü 2026-08-22. İki eksik vardı, ikisi de sessizdi:
#   1. libglib vb. 17 kütüphane bulunamıyordu → Chromium hiç açılmıyordu (gürültülü hata).
#   2. HİÇ FONT YOKTU → Chromium açılıyor ama metin yüksekliği 0 çıkıyor, her öğe
#      "hidden" sayılıyor, inner_text boş dönüyor, click "element not visible" diyor.
#      🔴 Bu SESSİZ hatadır: tarayıcı ayakta görünür, otomasyon sebepsiz başarısız olur.
#      Teşhis parmak izi: boundingBox height == 0.
export PATH="/config/.local/bin:$PATH"
export LD_LIBRARY_PATH="/config/.local/micromamba/envs/pw-libs/lib:${LD_LIBRARY_PATH:-}"
PW_FONT_KAYNAK="/config/.local/micromamba/envs/pw-libs/fonts"
PW_FONT_HEDEF="$HOME/.local/share/fonts/pw-libs"
if [ -d "$PW_FONT_KAYNAK" ] && [ ! -e "$PW_FONT_HEDEF" ]; then
  mkdir -p "$(dirname "$PW_FONT_HEDEF")"; ln -sfn "$PW_FONT_KAYNAK" "$PW_FONT_HEDEF"
fi
