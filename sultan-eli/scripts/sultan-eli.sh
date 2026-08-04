#!/usr/bin/env bash
# sultan-eli.sh — "bu komutu gerçekten insan mı başlattı?" ölçümü
#
# NİÇİN VAR (A06 · NÂZIR bulgusu 2026-08-03 · Sultan kararı 2026-08-04):
#   Filoda 18 beceri bir "Sultan onayladı" bayrağı taşıyor. Ölçüldü: bayrağın VARLIĞI
#   fail-closed zorlanıyor, ama KAYNAĞI hiç sorulmuyor. NÂZIR uçtan uca sınadı: ajan
#   ortamında, insan hiç devrede değilken bir terfi geçti — RC=0. Ajanı durduran tek şey,
#   bayrağı yazmamayı SEÇMESİYDİ. Bugün "kapı var" SANILIYOR; gerçek olan "bayrak var,
#   ölçüm yok" — arada bir sürüklenme değil, bir YANLIŞ GÜVEN vardı.
#
# 🔴 NE OLMADIĞI — ÖNCE BU (abartılmasın, ilk yanlış kullanım buradan doğar):
#   Bu bir KİLİT DEĞİL, bir KORKULUKTUR. Oda anahtarsız doğdu: betiği koşturabilen ajan,
#   betiğin okuyabildiği her şeyi de yazabilir (transkript ajanın kendi kullanıcısına aittir).
#   Yani: KAZAYI ve SESSİZ SÜRÜKLENMEYİ durdurur, KASTI durdurmaz. Bunu bilerek kullan;
#   "artık güvenli" cümlesi bu dosyanın verdiği güvencenin ötesindedir.
#
# NİÇİN YALNIZ GERİ ALINAMAZ KAPILAR (Sultan kararı, 2026-08-04):
#   Tam kilit imkânsız olduğuna göre ölçüm ancak kazayı durdurur → bedeli, kazanın FELAKET
#   olduğu yere harcanır: söküm · üretim-veritabanı · sunucu kurma · CF rota silme.
#   Geri alınabilir kapılarda (terfi, layiha) bayrak BEYAN olarak kalır — çünkü yanlış-red
#   gerçek bir maliyettir: 31 Tem'de meşru bir Sultan işi tam bu yüzden engellendi.
#
# ÖLÇÜLEN YÜZEY (firsthand, 2026-08-04 · SERDAR):
#   İnsanın `!` ile koştuğu komut, Claude Code oturum kaydına `<bash-input>` sarmalayıcısıyla
#   düşer; ajanın kendi komutu DÜŞMEZ (o `tool_use`/Bash olarak görünür). Aynı oturumda:
#     <bash-input> satırı  = 59      ajan Bash çağrısı = 12515
#   ⚠️ NÂZIR'ın önerdiği `userType=external` AYIRT ETMEZ — 168047 satırda var (her user-rolü
#      satırında, araç sonuçları dahil). Ayıran tek şey `<bash-input>` sarmalayıcısıdır.
#   ZAMANLAMA ölçüldü (yaklaşımın yaşam-şartı): kayıt satırı komuttan ÖNCE düşüyor —
#     <bash-input> yazıldı 1785856411.492 · komut koştu .863 · <bash-stdout> yazıldı .866
#   Yani kapı, koşarken kendi çağrısını kayıtta GÖREBİLİR. Sonra düşseydi bu yaklaşım ölüydü.
set -uo pipefail

PENCERE="${SULTAN_ELI_PENCERE:-45}"   # saniye: kaydın tazeliği
KOK="${SULTAN_ELI_KOK:-/config/.claude/projects}"

_kullanim() {
  cat <<'EOF'
sultan-eli.sh — geri alınamaz kapılar için "bunu insan mı başlattı" ölçümü

  dogrula --imza <metin>   kayıtta, son <pencere> sn içinde, <metin> geçen bir insan-`!`
                           komutu var mı? (imza = kapının kendi komut parçası)
  durum                    ölçüm yüzeyi görünüyor mu (tanı; verdikt vermez)

Çıkış: 0 insan-izi VAR · 1 insan-izi YOK · 2 kullanım · 3 ÖLÇÜLEMEDİ (kayıt görünmüyor)

⚠️ 3 ≠ 1. Ölçemediğini "insan yok" saymak, kapıyı yer-gerçeği yerine bilgisizliğe bağlar.
   Çağıran taraf 3'ü kendi politikasına göre yorumlar (İSKÂN: 3 → dur ve Sultan'a sor).
EOF
}

# Kayıt dosyası: bu oturuma ait olanı bilmiyoruz (ortamda oturum-kimliği yok — ölçüldü),
# o yüzden EN SON DOKUNULAN kayıt okunur. Yanlış-oturum riski pencere ile daraltılır.
_kayitlar() { find "$KOK" -name '*.jsonl' -mmin -10 2>/dev/null; }

_dogrula() {
  local imza="$1" simdi bulundu=0 gorundu=0
  simdi="$(date +%s)"
  while IFS= read -r dosya; do
    [ -n "$dosya" ] || continue
    gorundu=1
    # 🔴 İLK SÜRÜM FIXTURE'DA YEŞİL, GERÇEK KAYITTA KIRMIZIYDI (2026-08-04, ölçüldü).
    #   O sürüm `tail -n 400 "$dosya" | python3 …` idi: 14/14 fixture testi geçti, ama gerçek
    #   oturum kaydında insan-izi VARKEN "yok" dedi (aynı python standalone koşturulunca
    #   BULUYORDU — yani hata python'da değil, sarmalayıcıdaydı).
    #   ⚠️ KÖK-NEDEN DOĞRULANMADI. İki aday vardı: (a) erken-çıkan python → tail SIGPIPE →
    #   `pipefail` başarıyı başarısız gösteriyor, (b) satır, tail derinliğinin dışına kaymış.
    #   Boruyu geri takan mutasyon fixture'ı kırmadı → (a) KANITLANMADI. Uydurma bir kök-neden
    #   yazmaktansa bunu açık bırakıyorum; kesin bilinen tek şey: bu sürüm gerçek kayıtta
    #   ölçüldü ve DOĞRU cevap veriyor, öncekiyse vermiyordu.
    #   Bu yüzden pipe kaldırıldı ve derinlik 800'e çıkarıldı: dosyayı python KENDİSİ okur
    #   (deque), yani iki adayın da zemini ortadan kalkar — belirsizliği tartışmak yerine
    #   belirsizliğin kaynağını sildik.
    #   DERS (bu tur 8. kez): fixture-yeşil, gerçek-yeşil DEĞİLDİR. Her kapı gerçek veride sınanır.
    if python3 -c '
import json,sys,datetime,collections
dosya,imza=sys.argv[1],sys.argv[2]; simdi=float(sys.argv[3]); pencere=float(sys.argv[4])
try: son=collections.deque(open(dosya,encoding="utf-8",errors="replace"), maxlen=800)
except Exception: sys.exit(1)
for satir in son:
    try: o=json.loads(satir)
    except Exception: continue
    ic=o.get("message",{}).get("content")
    if not isinstance(ic,str) or "<bash-input>" not in ic: continue
    if imza not in ic: continue
    ts=o.get("timestamp")
    if not ts: continue
    try: an=datetime.datetime.fromisoformat(ts.replace("Z","+00:00")).timestamp()
    except Exception: continue
    if 0 <= simdi-an <= pencere: sys.exit(0)
sys.exit(1)
' "$dosya" "$imza" "$simdi" "$PENCERE"; then
      bulundu=1; break
    fi
  done <<< "$(_kayitlar)"
  [ "$gorundu" = 1 ] || return 3
  [ "$bulundu" = 1 ] || return 1
  return 0
}

case "${1:-}" in
  dogrula)
    IMZA=""
    shift
    while [ $# -gt 0 ]; do
      case "$1" in
        --imza) IMZA="${2:-}"; shift 2 ;;
        *) echo "HATA: bilinmeyen argüman: $1" >&2; exit 2 ;;
      esac
    done
    # İmza ZORUNLU ve anlamlı olmalı. İmzasız "herhangi bir insan komutu var mı" sorusu,
    # kapıyı bir zaman-penceresine indirger: insan başka bir iş için `!` yazdıktan hemen
    # sonra ajan bu kapıdan geçebilirdi. İmza, izi KOMUTA bağlar.
    [ ${#IMZA} -ge 3 ] || { echo "HATA: --imza en az 3 karakter olmalı (kapının kendi komut parçası)" >&2; exit 2; }
    _dogrula "$IMZA"; RC=$?
    case "$RC" in
      0) echo "insan-izi VAR: son ${PENCERE}sn içinde '$IMZA' geçen bir '!' komutu kayıtta" ;;
      1) echo "insan-izi YOK: son ${PENCERE}sn içinde '$IMZA' geçen bir '!' komutu kayıtta bulunamadı" >&2 ;;
      3) echo "ÖLÇÜLEMEDİ: oturum kaydı görünmüyor ($KOK) — bu 'insan yok' DEMEK DEĞİLDİR" >&2 ;;
    esac
    exit $RC
    ;;
  durum)
    N="$(_kayitlar | wc -l)"
    echo "kayıt kökü : $KOK"
    echo "taze kayıt : $N dosya (son 10 dk)"
    echo "pencere    : ${PENCERE} sn"
    [ "$N" -gt 0 ] && echo "ölçüm yüzeyi: GÖRÜNÜYOR" || echo "ölçüm yüzeyi: YOK — bu kutuda kapı ölçemez (3 döner)"
    exit 0
    ;;
  ""|-h|--help) _kullanim; exit 2 ;;
  *) echo "HATA: bilinmeyen fiil: $1" >&2; _kullanim; exit 2 ;;
esac
