# bagimlilik.sh — plan-motor sınavlarının ORTAK npm bağımlılık kapısı (source edilir; çağıran PAKET dizinindedir).
#
# NİÇİN (30 Eki 2026, kart sync-drift-ayikla): bağımlılığı yalnız dwg-teknik.test.sh kuruyordu. Kurulu kopyadan kaynağa
# taşınan birim-uyarisi ve dxf-line-uclari sınavları da dxf-parser ister; CI'da sınavlar PARALEL koştuğu için (xargs -P)
# dwg-teknik'ten önce koşan sınav node_modules'u bulamayıp kırmızı yanıyordu (yerelde ölçüldü: node_modules yokken
# ikisi de rc 1). Aynı anda iki npm install aynı dizine yazmasın diye kurulum kilit altında yapılır.
# Varlık ölçüsü paket.json dosyalarıdır. Eski ölçü (dxf-parser/dist/index.js'i ESM ile içe aktarmak) bu kilitli sürümde
# kurulumdan SONRA bile düşüyor (index.js uzantısız içe aktarım yapıyor) → "her seferinde kur" demekti; kurulum ardından
# yeniden ölçen bu kapı onu kalıcı kırmızı sanırdı (30 Eki yerel ölçüm).
bagimlilik_var() {
  [ -f node_modules/dxf-parser/package.json ] && [ -f node_modules/dejavu-fonts-ttf/package.json ] && [ -f node_modules/sharp/package.json ]
}
bagimlilik_kur() {
  bagimlilik_var && return 0
  local kilit; kilit="${TMPDIR:-/tmp}/plan-motor-npm-$(printf '%s' "$PWD" | cksum | cut -d' ' -f1).lock"
  echo "── bağımlılıklar eksik, kuruluyor (npm install --no-fund --no-audit) ──"
  ( flock 9; bagimlilik_var || npm install --no-fund --no-audit >/dev/null 2>&1 ) 9>"$kilit"
  bagimlilik_var
}
