#!/usr/bin/env bash
# cipa.sh — günün planının DİSKTEKİ çıpası + compact önerisinin kapısı.
#
# 🔴 NİÇİN VAR (ölçüldü 2026-10-02, Sultan sordu):
#   1) SKILL.md ADIM 5 "yarım kalanı ertesi günün ölçümüne ÇIPALAR" diyordu — bunu yazan
#      ya da okuyan TEK SATIR yoktu (`grep -c cipa olc.sh` → 0). Yazılı ama koşmayan kural.
#   2) Becerinin tamamında "compact" geçen satır sayısı SIFIRDI. Oysa bu komut günün en uzun
#      işi: bağlamı en çok yiyen komut, bağlam kuralı taşımıyordu.
#   3) Sultan'ın duran direktifi (eşik aşılınca compact ÖNER, sormadan ÖNCE çıpayı diske yaz)
#      yalnız ajanın hafızasında yaşıyordu → başka kutudaki ajana GELMİYORDU.
#
# 🔴 DÜRÜST SINIR — BU ARAÇ BAĞLAMI ÖLÇEMEZ. Bağlam doluluğu kabuktan okunamaz; onu yalnız
#   ajanın kendi göstergesi bilir. O yüzden burada ölçülen şey eşik DEĞİL, çıpanın DİSKTE
#   OLUP OLMADIĞIDIR. Araç şunu garanti eder: çıpa yoksa compact önerisi ÜRETİLMEZ (rc=3).
#   Yani "önce çıpayı yaz, sonra öner" kuralı iyi niyete değil kapıya bağlıdır.
set -uo pipefail

_kok() {
  local k; k="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null)"
  [ -n "$k" ] && { printf '%s' "$k"; return; }
  printf '%s' "${HOME:-/tmp}"
}
DIZ="${GUNLUK_PLAN_CIPA_DIZ:-$(_kok)/_agents/handoff}"
BUGUN="${GUNLUK_PLAN_TARIH:-$(date +%F)}"

# 🔴 ÇIPA AJAN BAŞINADIR — tek dosya DEĞİL (bulan: KÂŞİF/BASİRET, b0097; kusur benimdi).
#    İlk yazımda yol `<depo>/_agents/handoff/gunluk-plan-cipa.md` idi ve `yaz` KESEREK
#    yazıyordu. O dizin kutular arası ORTAK: ikinci ajan plan yazınca birincininkini
#    siliyordu. Ölçülmüş vaka: BASİRET'in akşam planı MUAVİN'in çıpasının üstüne bindi.
#    Yani bağlam kaybını önlemek için yazılan araç, başkasının planını kaybettiriyordu.
#    Kimlik sırası: açık ayar > aile kimliği > tmux oturumu > kullanıcı. Hiçbiri yoksa
#    "bilinmiyor" — uydurma ad YOK, ama o zaman da ESKİ TEK DOSYAYA dönmez; ayrı kalır.
_ajan() {
  local a="${GUNLUK_PLAN_AJAN:-${AGENT_NAME:-}}"
  [ -n "$a" ] || a="$(printf '%s' "${TMUX_PANE:+${TMUX:+}}" >/dev/null 2>&1; tmux display-message -p '#S' 2>/dev/null)"
  [ -n "$a" ] || a="$(id -un 2>/dev/null)"
  [ -n "$a" ] || a="bilinmiyor"
  printf '%s' "$a" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-' | sed 's/-\{1,\}/-/g; s/^-//; s/-$//'
}
AJAN="$(_ajan)"
CIPA="$DIZ/gunluk-plan-cipa.$AJAN.md"
# Geriye dönük: eski TEK dosya duruyorsa ve bu ajanınki yoksa, onu EZMEDEN yanına taşı.
if [ ! -f "$CIPA" ] && [ -f "$DIZ/gunluk-plan-cipa.md" ]; then
  cp -n "$DIZ/gunluk-plan-cipa.md" "$CIPA" 2>/dev/null || true
fi

kullanim() {
  cat >&2 <<'K'
kullanım:
  cipa.sh yaz --plan "1) madde … | 2) madde …" [--not "…"]   günün çıpasını diske yaz
  cipa.sh tazele --madde <n> --durum kapandi|yarim|acilmadi|geri-alindi [--not "…"]
  cipa.sh oku                                                 çıpayı bas (yoksa rc=1)
  cipa.sh yol                                                 çıpanın yolunu bas (dosya yoksa da)
  cipa.sh compact-onerisi                                     öneri metni; ÇIPA YOKSA rc=3
K
  exit 2
}

[ $# -ge 1 ] || kullanim
KOMUT="$1"; shift
PLAN=""; NOT=""; MADDE=""; DURUM=""
# 🔴 DEĞERSİZ BAYRAK SONSUZ DÖNGÜ YAPIYORDU (bulan: NÂZIR/MÜDÜR, 2026-10-02 — aracı
#    yazdığım gün). `--plan` değer verilmeden gelince `shift 2` tek argümanda İLERLEMİYOR,
#    döngü sonsuza giriyor ve işlemci %100'e çıkıyordu (timeout ile rc=124 ölçüldü).
#    Bu, "ölçemediğin yere yeşil deme" kuralının arg-ayrıştırma yüzü: bayrağın DEĞERİ VAR MI
#    diye sormadan ilerlemek, hatayı sessiz bir kilide çeviriyor.
_al() { # $1=bayrak adı · kalan argüman sayısı ve değeri DIŞARIDA sınanır
  :
}
while [ $# -gt 0 ]; do
  bayrak="$1"
  case "$bayrak" in
    --plan|--not|--madde|--durum)
      # 🔴 İKİ AYRI ŞART, İKİSİ DE GEREKLİ:
      #    (a) argüman KALDI MI — kalmadıysa `shift 2` İLERLEMEZ ve döngü sonsuza girer
      #        (işlemci %100). Bulan: NÂZIR/MÜDÜR, aracı yazdığım gün; rc=124 ile ölçüldü.
      #    (b) gelen şey DEĞER Mİ — bir sonraki bayraksa, değer verilmemiş demektir.
      [ $# -ge 2 ] || { echo "HATA: $bayrak bir değer ister (değer verilmedi)" >&2; exit 2; }
      case "$2" in --*) echo "HATA: $bayrak bir değer ister (gelen: $2)" >&2; exit 2 ;; esac
      case "$bayrak" in
        --plan) PLAN="$2" ;; --not) NOT="$2" ;; --madde) MADDE="$2" ;; --durum) DURUM="$2" ;;
      esac
      shift 2 ;;
    *) echo "tanınmayan argüman: $bayrak" >&2; kullanim ;;
  esac
done
case "$KOMUT" in
  yaz)
    [ -n "$PLAN" ] || { echo "HATA: --plan zorunlu (boş çıpa çıpa değildir)" >&2; exit 2; }
    mkdir -p "$DIZ" 2>/dev/null || { echo "HATA: çıpa dizini açılamadı: $DIZ" >&2; exit 1; }
    {
      printf '# ⚓ GÜNÜN PLANI ÇIPASI · %s\n\n' "$BUGUN"
      printf '> Bu dosya compact/kesinti sonrası planın geri okunduğu yerdir.\n'
      printf '> Transkripte güvenilmez; plan burada yaşar.\n\n'
      printf '## Maddeler\n'
      printf '%s\n' "$PLAN" | tr '|' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | while IFS= read -r s; do
        [ -n "$s" ] && printf -- '- [ ] %s\n' "$s"
      done
      [ -n "$NOT" ] && printf '\n## Not\n%s\n' "$NOT"
      printf '\n_yazıldı: %s_\n' "$(date -Iseconds)"
    } > "$CIPA" || { echo "HATA: çıpa yazılamadı" >&2; exit 1; }
    # 🔴 YAZDIĞINI GERİ OKU: "yazdım" demek yetmez (ölçülmüş ders).
    grep -q "GÜNÜN PLANI ÇIPASI · $BUGUN" "$CIPA" || { echo "HATA: çıpa yazıldı sanıldı, geri okunamadı" >&2; exit 1; }
    echo "✓ çıpa yazıldı: $CIPA"
    ;;
  tazele)
    [ -f "$CIPA" ] || { echo "HATA: çıpa yok — önce 'yaz'" >&2; exit 1; }
    # 🔴 KİLİT (bulan: NÂZIR/MÜDÜR — eşzamanlı yazımda 5 turun 1'inde bir işaret EZİLDİ).
    #    Çıpa tek dosya ve birden çok el ona yazıyor; kilitsiz tazeleme kapanmış bir maddeyi
    #    sessizce geri açabilir. Kardeş araçta aynı desen kullanılıyor.
    exec 9>>"$CIPA.kilit" 2>/dev/null && flock 9 2>/dev/null || true
    [ -n "$MADDE" ] && [ -n "$DURUM" ] || { echo "HATA: --madde ve --durum zorunlu" >&2; exit 2; }
    # 🔴 "geri-alindi" EKLENDI (bulan: NÂZIR/MÜDÜR). Eksikti ve eksikliği sessizdi: geri
    #    alınmış bir madde `kapandi` ile tazelenince "GERİ ALINDI → KAPANDI" diye ÜST ÜSTE
    #    yazılıyordu. Kapanışta da ayrı sayılmıyordu — yani vazgeçilen iş, bitmiş iş gibi
    #    görünüyordu. Bitmeyen işi bitmiş saymak, bu defterin tam tersi.
    case "$DURUM" in
      kapandi) im="x" ; et="KAPANDI" ;;
      yarim)   im="~" ; et="YARIM" ;;
      acilmadi) im=" "; et="AÇILMADI" ;;
      geri-alindi) im="-" ; et="GERİ ALINDI" ;;
      *) echo "HATA: --durum kapandi|yarim|acilmadi|geri-alindi olmalı" >&2; exit 2 ;;
    esac
    python3 - "$CIPA" "$MADDE" "$im" "$et" "$NOT" <<'PY' || exit 1
import sys, re
yol, madde, im, et, not_ = sys.argv[1:6]
s = open(yol, encoding='utf-8').read().split('\n')
n = 0; bulundu = False
for i, satir in enumerate(s):
    m = re.match(r'^- \[(.)\] (.*)$', satir)
    if not m: continue
    n += 1
    if str(n) != str(madde): continue
    govde = re.sub(r'\s*→ (KAPANDI|YARIM|AÇILMADI|GERİ ALINDI).*$', '', m.group(2))
    s[i] = f'- [{im}] {govde} → {et}' + (f' · {not_}' if not_ else '')
    bulundu = True
if not bulundu:
    sys.stderr.write(f'HATA: {madde}. madde yok (çıpada {n} madde var)\n'); sys.exit(1)
open(yol, 'w', encoding='utf-8').write('\n'.join(s))
print(f'✓ madde {madde} → {et}')
PY
    ;;
  oku)
    [ -f "$CIPA" ] || { echo "çıpa YOK: $CIPA" >&2; exit 1; }
    cat "$CIPA"
    ;;
  yol)
    # 🔴 TEK KAYNAK: çıpanın yolunu BAŞKA araçlar da bilmek zorunda (ör. /gun-ortasi'nın
    #    cipa-ekle.sh'ı). Yolu ikinci bir yerde TÜRETMEK, b0097'nin birebir tekrarıdır:
    #    ajan-başına dosyaya geçtiğim gün NÂZIR'ın aracı eski TEK dosyaya yazmaya devam etti,
    #    kimsenin okumadığı bir dosyaya — ve ortak kilit de bu yüzden fiilen çalışmadı
    #    (ölçüldü 2026-10-05: kilit beklemesi 9 ms). Yol artık sorulur, tahmin edilmez.
    #    DOSYA YOKSA DA yolu basar (rc=0): "nereye yazacağım" sorusu "yazdım mı"dan AYRI.
    printf '%s\n' "$CIPA"
    ;;
  compact-onerisi)
    # 🔴 FAIL-CLOSED: çıpa diskte yoksa öneri ÜRETİLMEZ. Sultan'ın direktifi
    #    "sormadan ÖNCE çıpayı yaz" idi; burada o sıra mekanik olarak zorlanır.
    if [ ! -f "$CIPA" ]; then
      echo "✗ ÇIPA YOK — compact önerisi üretilmedi (önce: cipa.sh yaz --plan …)" >&2
      echo "  Niçin sert: çıpasız compact, planı transkriptle birlikte götürür." >&2
      exit 3
    fi
    cat <<M
🔴 BAĞLAM ÖNERİSİ — çıpa diskte, compact güvenli

Plan çıpası yazılı: $CIPA
Bağlamın eşiği geçtiyse ŞİMDİ compact öner; plan kaybolmaz, çıpadan geri okunur.

Sultan'a sorulacak tek cümle:
  "Bağlam eşiği geçti. Planı diske yazdım, kaybolmaz — compact yapalım mı?"

🔴 Otomatik YAPILMAZ: karar Sultan'ın. Bu araç yalnız sıranın doğru olduğunu güvence altına alır.
M
    ;;
  *) kullanim ;;
esac
