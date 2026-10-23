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
  # 🔴 TÜRKÇE KATLAMA ÖNCE (bağımsız göz tur 2, 2026-10-05): `tr -c` çok baytlı harfi
  #    tanımaz; "MUAVİN" → "muav-n" oluyordu, yani KENDİ adım bozuluyordu. Katlama,
  #    oda-tetik'in kullandığı eşlemenin aynısı — iki yerde iki ayrı yazım olmasın.
  local k; k="$(printf '%s' "$a" | sed 'y/İIıĞğÜüŞşÖöÇç/iiigguussoocc/' | tr '[:upper:]' '[:lower:]')"
  local t; t="$(printf '%s' "$k" | tr -c 'a-z0-9_-' '-' | sed 's/-\{1,\}/-/g; s/^-//; s/-$//')"
  # 🔴 BOŞ KALABİLİYORDU: "###" gibi bir ad tamamen eleniyor ve yol `…-cipa..md` oluyordu.
  [ -n "$t" ] && [ "$t" != "-" ] || { printf '%s' "bilinmiyor"; return; }
  # 🔴 ÇAKIŞMA: "A!" ile "A?" ikisi de "a" oluyordu → iki ajan TEK dosyaya düşüyordu.
  #    Temizlik adı değiştirdiyse, aslının kısa özetini ekliyoruz; temiz adlar aynen kalır.
  if [ "$t" = "$k" ]; then printf '%s' "$t"
  else printf '%s-%s' "$t" "$(printf '%s' "$a" | sha256sum | cut -c1-6)"; fi
}
AJAN="$(_ajan)"
CIPA="$DIZ/gunluk-plan-cipa.$AJAN.md"
# Geriye dönük: eski TEK dosya duruyorsa ve bu ajanınki yoksa, onu EZMEDEN yanına taşı.
# 🔴 YALNIZ YAZAN KOMUTLARDA (bağımsız göz tur 2): eskiden bu blok komut ayrıştırılmadan
#    önce koşuyordu, yani `oku` · `yol` · `compact-onerisi` gibi SALT-OKUR çağrılar bile
#    dosya YARATIYORDU. Salt-okur bir komutun diske dokunması, ölçümü ölçülen şeyi
#    değiştiren bir araca çevirir. Göç artık yalnız yazma anında yapılır.
_gecis_yap() {
  if [ ! -f "$CIPA" ] && [ -f "$DIZ/gunluk-plan-cipa.md" ]; then
    cp -n "$DIZ/gunluk-plan-cipa.md" "$CIPA" 2>/dev/null || true
  fi
}
# 🔴 KİLİT TEK YERDEN, FAIL-CLOSED (bağımsız göz tur 2): eskiden kilidi yalnız `tazele`
#    alıyordu — oysa DOSYAYI KESEN komut `yaz`. Üstelik `|| true` vardı: kilit alınamazsa
#    yazmaya yine geçiyordu, yani koruma görünüyor ama yoktu (fail-open).
# 🔴 SALT-OKUR GERİYE DÖNÜKLÜK: eski TEK dosya duruyorsa ve bu ajanın dosyası yoksa,
#    `oku` ve `compact-onerisi` onu KOPYALAMADAN okur. Göç bir YAZMA işidir; onu yalnız
#    `tazele` yapar (düzenlemek için dosyaya ihtiyacı var). `yaz` zaten üstüne yazar.
_okunacak() {
  if [ -f "$CIPA" ]; then printf '%s' "$CIPA"
  elif [ -f "$DIZ/gunluk-plan-cipa.md" ]; then printf '%s' "$DIZ/gunluk-plan-cipa.md"
  else printf '%s' "$CIPA"; fi
}
_kilitle() {
  # 🔴 Susturma YALNIZ bu gruba (MUHAKKİK CM4JM, 18 Eki): argümansız `exec 9>>f 2>/dev/null` iki yönlendirmeyi de KABUĞA
  #    kalıcı uygular — kilitten sonraki her "HATA:" satırı /dev/null'a gidiyordu (rc=2 ile düşen tazele 0 bayt stderr bastı).
  { exec 9>>"$CIPA.kilit"; } 2>/dev/null || { echo "HATA: çıpa kilidi açılamadı ($CIPA.kilit) — yazmıyorum" >&2; exit 1; }
  flock -w 10 9 2>/dev/null || { echo "HATA: çıpa kilidi 10 sn'de alınamadı — yazmıyorum (başka bir araç yazıyor)" >&2; exit 1; }
}

# kullanim [rc] — yardım İSTENDİYSE (--help/-h) metin stdout'a, rc=0: yardım bir hata değildir (görev RN95G).
#   Hatalı çağrıda (tanınmayan argüman, komutsuz) stderr'e, rc=2 — çağıran kırmızıyı görmeli.
kullanim() {
  local rc="${1:-2}"
  { cat <<'K'
kullanım:
  cipa.sh yaz --plan "1) madde … | 2) madde …" [--not "…"]   günün çıpasını diske yaz
  cipa.sh tazele --madde <n> --durum kapandi|yarim|acilmadi|geri-alindi [--not "…"] [--kanit "<PR#|commit|dosya>"]
  cipa.sh tazele --madde <n> --durum ertelendi --d1 "<YYYY-MM-DD Sultan: … (sohbet · <ref> · \"<kırpık>\" · beyan:<AJAN>)>"
  cipa.sh tablo [--md|--json]                                 KUTULU bugün tablosu (zorunlu sunum); --md düz, --json ham
  cipa.sh kapanis                                             açık madde varsa rc=4 (kapanış kabul edilmez)
  cipa.sh oku                                                 çıpayı bas (yoksa rc=1)
  cipa.sh yol                                                 çıpanın yolunu bas (dosya yoksa da)
  cipa.sh compact-onerisi                                     öneri metni; ÇIPA YOKSA rc=3
  cipa.sh [<komut>] --help | -h                               bu metin (rc=0)
K
  } >&$([ "$rc" = 0 ] && echo 1 || echo 2)
  exit "$rc"
}

[ $# -ge 1 ] || kullanim
case "$1" in -h|--help) kullanim 0 ;; esac
KOMUT="$1"; shift
PLAN=""; NOT=""; MADDE=""; DURUM=""; KANIT=""; D1=""; JSON=0
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
    -h|--help) kullanim 0 ;;
    --json) JSON=1; shift ;;
    --md) MD=1; shift ;;
    --plan|--not|--madde|--durum|--kanit|--d1)
      # 🔴 İKİ AYRI ŞART, İKİSİ DE GEREKLİ:
      #    (a) argüman KALDI MI — kalmadıysa `shift 2` İLERLEMEZ ve döngü sonsuza girer
      #        (işlemci %100). Bulan: NÂZIR/MÜDÜR, aracı yazdığım gün; rc=124 ile ölçüldü.
      #    (b) gelen şey DEĞER Mİ — bir sonraki bayraksa, değer verilmemiş demektir.
      [ $# -ge 2 ] || { echo "HATA: $bayrak bir değer ister (değer verilmedi)" >&2; exit 2; }
      case "$2" in --*) echo "HATA: $bayrak bir değer ister (gelen: $2)" >&2; exit 2 ;; esac
      case "$bayrak" in
        --plan) PLAN="$2" ;; --not) NOT="$2" ;; --madde) MADDE="$2" ;; --durum) DURUM="$2" ;;
        --kanit) KANIT="$2" ;; --d1) D1="$2" ;;
      esac
      shift 2 ;;
    *) echo "tanınmayan argüman: $bayrak" >&2; kullanim ;;
  esac
done
case "$KOMUT" in
  yaz)
    [ -n "$PLAN" ] || { echo "HATA: --plan zorunlu (boş çıpa çıpa değildir)" >&2; exit 2; }
    mkdir -p "$DIZ" 2>/dev/null || { echo "HATA: çıpa dizini açılamadı: $DIZ" >&2; exit 1; }
    # 🔴 DOSYAYI KESEN KOMUT BU — kilidi ÖNCE o almalı (bağımsız göz tur 2). Eskiden kilit
    #    yalnız `tazele`de vardı; `yaz` kilitsiz kesiyordu, yani en yıkıcı yol korumasızdı.
    _kilitle
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
    # 🔴 GÖÇ VARLIK KONTROLÜNDEN ÖNCE: eski TEK dosyadan devralan ajan, dosyası henüz
    #    doğmadığı için "çıpa yok" duyuyordu ve dünkü planı düzenleyemiyordu.
    _gecis_yap
    [ -f "$CIPA" ] || { echo "HATA: çıpa yok — önce 'yaz'" >&2; exit 1; }
    # 🔴 KİLİT (bulan: NÂZIR/MÜDÜR — eşzamanlı yazımda 5 turun 1'inde bir işaret EZİLDİ).
    #    Çıpa tek dosya ve birden çok el ona yazıyor; kilitsiz tazeleme kapanmış bir maddeyi
    #    sessizce geri açabilir. Kardeş araçta aynı desen kullanılıyor.
    _kilitle
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
      # 🔴 ERTELEME = Sultan kararı (gorev_01M54TNAQV, Sultan 17 Eki: "planlanan işler tamamlanmadan
      #    kapanış kabul edilmeyecek"). Taşımanın TEK yolu D1 damgasıdır; biçimi tutmayan damga REDDEDİLİR.
      #    A06: araç sözü ÜRETMEZ, yalnız biçimini sınar — damgayı ajan Sultan'ın gördüğü sözden aktarır.
      ertelendi)
        printf '%s' "$D1" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2} Sultan: .+\(sohbet · [^·()]+ · "[^"]{1,120}" · beyan:[^ )]+\)$' \
          || { echo "HATA: ertelendi için --d1 zorunlu ve D1 biçiminde olmalı: 'YYYY-MM-DD Sultan: … (sohbet · <ref> · \"<kırpık>\" · beyan:<AJAN>)'" >&2; exit 2; }
        # 🔴 BİÇİM YETMEZ, KARAR DA ŞART (bağımsız göz #357 tur 4 + #366 tur 1): "Sultan: bugün görüşelim (…)"
        #    biçimce geçiyordu; "ertele" ALT DİZGESİNE bakmak da yetmedi ("ertele istemiyorum", "ertele mi?").
        #    D1'in SONUÇ kısmı (Sultan: … (sohbet) KAPALI bir karar kümesinden biri olmalı, TAM eşleşme:
        #    [yarına ] ertele | ertelensin | ertelendi | erteleyelim | erteleyin. Sonuç ajanın aktardığı karar
        #    adıdır; Sultan'ın kendi sözü kırpıkta (tırnak içi) durur. tablo.py aynı kümeyle okur.
        _snc="${D1#* Sultan: }"; _snc="${_snc%% (sohbet*}"
        printf '%s' "$_snc" | grep -qixE '(yarına )?ertele(nsin|ndi|yelim|yin)?' \
          || { echo "HATA: D1'in sonuç kısmı tam olarak bir erteleme kararı olmalı: [yarına ] ertele|ertelensin|ertelendi|erteleyelim|erteleyin — '$_snc' değil" >&2; exit 2; }
        im="-" ; et="ERTELENDİ"; NOT="D1: $D1${NOT:+ · $NOT}" ;;
      *) echo "HATA: --durum kapandi|yarim|acilmadi|geri-alindi|ertelendi olmalı" >&2; exit 2 ;;
    esac
    [ -z "$KANIT" ] || NOT="${NOT:+$NOT · }kanıt: $KANIT"
    python3 - "$CIPA" "$MADDE" "$im" "$et" "$NOT" <<'PY' || exit 1
import sys, re
yol, madde, im, et, not_ = sys.argv[1:6]
s = open(yol, encoding='utf-8').read().split('\n')
# 🔴 HEDEF = GÖRÜNÜR KİMLİK (bağımsız göz #357 tur 3): tablo maddeyi etiketiyle basar ("G1", "3"); tazele ise
#    yalnız fiziksel sıraya bakıyordu → "G1" hiçbir satırı tutmuyor, tablodaki kimlikle güncelleme yapılamıyordu.
#    Önce ETİKET aranır (G büyük/küçük harf fark etmez); etiketsiz eski çıpalar için yalnız rakamsa sıra sayısına düşülür.
satirlar = [(i, re.match(r'^- \[(.)\] (.*)$', x)) for i, x in enumerate(s)]
satirlar = [(i, m) for i, m in satirlar if m]
n = len(satirlar)
hedef = str(madde).strip().upper()
etiketli = [i for i, m in satirlar if (re.match(r'^(G?\d+)\)', m.group(2)) or [None, ''])[1].upper() == hedef]
if len(etiketli) > 1:
    sys.stderr.write(f'HATA: "{madde}" etiketi {len(etiketli)} maddede var — hangisi olduğu belirsiz, dokunmadım\n'); sys.exit(1)
if etiketli:
    hedefler = etiketli
elif re.fullmatch(r'\d+', hedef) and 1 <= int(hedef) <= n:
    hedefler = [satirlar[int(hedef) - 1][0]]
else:
    sys.stderr.write(f'HATA: {madde}. madde yok (çıpada {n} madde var; etiket ya da sıra numarası ver: 3 · G1)\n'); sys.exit(1)
for i in hedefler:
    m = re.match(r'^- \[(.)\] (.*)$', s[i])
    govde = re.sub(r'\s*→ (KAPANDI|YARIM|AÇILMADI|GERİ ALINDI|ERTELENDİ).*$', '', m.group(2))
    s[i] = f'- [{im}] {govde} → {et}' + (f' · {not_}' if not_ else '')
# 🔴 DOKUNMA DAMGASI (2026-10-08): `tazele` bugüne kadar `_yazıldı:` satırını HİÇ
#    güncellemiyordu. Sonuç: çıpanın içindeki damga hep ilk yazım anını gösteriyor,
#    gün boyu tazelense bile "sabah yazılmış" görünüyordu. Tazeliği ölçmek isteyen
#    araç (soluklan) bu yüzden dosya değişme-zamanına düşmek zorunda kalıyordu — o da
#    boş bir dokunuşla kandırılabilir. Çare: tazeleme kendi izini bıraksın.
#    `_yazıldı:` DOKUNULMAZ (plan ne zaman kuruldu sorusunun cevabı odur).
import datetime as _dt
_damga = _dt.datetime.now().astimezone().isoformat(timespec='seconds')
s = [x for x in s if not x.startswith('_dokunuldu:')]
while s and s[-1].strip() == '':
    s.pop()
s.append(f'_dokunuldu: {_damga}')
s.append('')
open(yol, 'w', encoding='utf-8').write('\n'.join(s))
print(f'✓ madde {madde} → {et}')
PY
    ;;
  tablo|kapanis)
    # Satır dilbilgisi TEK yerde: sema/bugun-maddesi.md · ayrıştırıcı tablo.py (kokpit kapısı aynı fikstürle sınanır)
    _OK="$(_okunacak)"
    [ -f "$_OK" ] || { echo "çıpa YOK: $CIPA" >&2; exit 1; }
    if [ "$KOMUT" = kapanis ]; then python3 "$(dirname "$0")/tablo.py" "$_OK" --kapanis; exit $?; fi
    if [ "$JSON" = 1 ]; then python3 "$(dirname "$0")/tablo.py" "$_OK" --json; elif [ "${MD:-0}" = 1 ]; then python3 "$(dirname "$0")/tablo.py" "$_OK" --md; else python3 "$(dirname "$0")/tablo.py" "$_OK"; fi
    ;;
  oku)
    _OK="$(_okunacak)"
    [ -f "$_OK" ] || { echo "çıpa YOK: $CIPA" >&2; exit 1; }
    cat "$_OK"
    ;;
  ajan)
    # 🔴 TEK KAYNAK: ajan kimliğini BAŞKA araçlar da bilmek zorunda (ör. ölçüm aracının
    #    "dün nerede bıraktım" kaynağı). İkinci bir türetme yazmak, aynı kimliğin iki
    #    yazımı demektir ve ilk değişimde ayrışır — `yol` verbiyle aynı gerekçe.
    printf '%s\n' "$AJAN"
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
    if [ ! -f "$(_okunacak)" ]; then
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
