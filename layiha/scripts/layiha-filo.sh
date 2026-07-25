#!/usr/bin/env bash
# layiha-filo.sh — TÜM odaların layihalarını tek ekranda (Sultan-kararı K3: "evet, yalnız başlıklar").
#
# NE: Her oda kendi defterini tutar (İ1 — odalar birbirinin defterini görmez). Bu araç o defterleri
#   BİRLEŞTİRMEZ; sırayla ziyaret edip yalnız BAŞLIK + durum satırlarını ekrana basar. Ortak dizine
#   birleşik bir defter YAZILMAZ, hiçbir dosyaya dokunulmaz — bu araç %100 salt-okurdur.
#
# NİÇİN YALNIZ BAŞLIK: detay odasında kalır (mevcut federe "yalnız-META" deseni). Sultan yukarıdan
#   "nerede ne var" görür; içeriğe bakmak isterse o odaya girip `liste` der.
#
# ODALARI NEREDEN BULUR (ilk eşleşen kazanır):
#   1) $LAYIHA_FILO_ODALAR      — iki-nokta ayrık yol listesi (ör. /a/proje1:/b/proje2)
#   2) <hat-kökü>/_agents/handoff/layiha-filo-odalar.txt — satır başına bir yol ('#' yorum)
#   3) otomatik tarama: ${LAYIHA_FILO_KOK:-/config/projects}/* içinde defteri OLAN dizinler
#
# ⚠️ GÖRÜNÜRLÜK SINIRI (dürüstlük): bu araç yalnız BU container'ın dosya sisteminden görünen odaları
#   sayabilir. İzole container'ların (vekatip · mmex · medigate · huma · mihenk · tellal · akar · s02)
#   depoları buradan görünmez → listede ÇIKMAZLAR ve bu bir arıza değil, İ1'in ta kendisidir.
#   Çıktı bunu her koşuda alt-notta söyler ki "hepsi bu kadar mı?" yanılgısı doğmasın.
#
# Kullanım: layiha-filo.sh [--aktif(default)|--bugun|--hafta|--hafta-bitmemis|--tescil-bekleyen|--hepsi]
# Çıkış: 0 OK · 2 girdi/ortam hatası
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFTERI="${LAYIHA_DEFTERI_BIN:-$HERE/layiha-defteri.sh}"
[ -r "$DEFTERI" ] || { echo "HATA: layiha-defteri.sh bulunamadı: $DEFTERI" >&2; exit 2; }

FILT="--aktif"
for arg in "$@"; do
  case "$arg" in
    --aktif|--bugun|--hafta|--hafta-bitmemis|--tescil-bekleyen|--hepsi) FILT="$arg" ;;
    *) echo "HATA: tanınmayan bayrak: $arg" >&2
       echo "      geçerli: --aktif --bugun --hafta --hafta-bitmemis --tescil-bekleyen --hepsi" >&2
       exit 2 ;;
  esac
done

# ── odaları topla ────────────────────────────────────────────────────────────────────────────
ODALAR=()
if [ -n "${LAYIHA_FILO_ODALAR:-}" ]; then
  IFS=':' read -r -a ODALAR <<< "$LAYIHA_FILO_ODALAR"
  KAYNAK="LAYIHA_FILO_ODALAR"
else
  LISTE=""
  # shellcheck source=/dev/null
  if source "$HERE/hat-yolu.lib.sh" 2>/dev/null; then
    _kok="$(hat_root 2>/dev/null)" || _kok=""
    [ -n "$_kok" ] && LISTE="$_kok/_agents/handoff/layiha-filo-odalar.txt"
  fi
  if [ -n "$LISTE" ] && [ -r "$LISTE" ]; then
    KAYNAK="oda-listesi ($LISTE)"
    while IFS= read -r l; do
      case "$l" in ''|'#'*) continue ;; esac
      ODALAR+=("$l")
    done < "$LISTE"
  else
    KOK="${LAYIHA_FILO_KOK:-/config/projects}"
    KAYNAK="otomatik tarama ($KOK)"
    for d in "$KOK"/*; do
      [ -d "$d" ] || continue
      [ -f "$d/_agents/handoff/layiha-defteri.jsonl" ] || continue
      ODALAR+=("$d")
    done
  fi
fi

if [ "${#ODALAR[@]}" -eq 0 ]; then
  echo "🌐 LAYİHA · FİLO GÖRÜNÜMÜ"
  echo "   (defteri olan oda bulunamadı — kaynak: $KAYNAK)"
  exit 0
fi

DUR_SIM() { case "$1" in
  insa-bekliyor) printf '⏳' ;; insa-ediliyor) printf '🔨' ;; insa-edildi) printf '🔧' ;; *) printf '•' ;;
esac; }
TES_SIM() { case "$1" in
  tescilli) printf ' 🏅' ;; bekliyor) printf ' 📋' ;; reddi) printf ' ↩' ;; muaf) printf ' ⊘' ;; *) printf '' ;;
esac; }

echo "🌐 LAYİHA · FİLO GÖRÜNÜMÜ  ·  filtre: ${FILT#--}  ·  oda-kaynağı: $KAYNAK"
echo ""

TOPLAM=0; OKUNAN=0; ATLANAN=0
for oda in "${ODALAR[@]}"; do
  defter="$oda/_agents/handoff/layiha-defteri.jsonl"
  ad="$(basename -- "${oda%/}")"
  if [ ! -r "$defter" ]; then ATLANAN=$((ATLANAN+1)); continue; fi
  cikti="$(LAYIHA_DEFTER="$defter" LAYIHA_PROJE="$ad" bash "$DEFTERI" liste "$FILT" --porcelain 2>/dev/null)" || {
    echo "  ⚠️  $ad — defter okunamadı (atlandı)"; ATLANAN=$((ATLANAN+1)); continue; }
  OKUNAN=$((OKUNAN+1))
  n=0
  # NOT: `IFS=$'\t' read` KULLANILAMAZ — sekme bash'te IFS-boşluğu sayılır, ardışık sekmeler TEK
  # ayırıcıya çöker ve BOŞ alanlar (kart/muhur çoğu kayıtta boş) sütunları kaydırır. Testte
  # yakalandı: başlık yerine doküman-yolu basılıyordu. awk boş alanları doğru sayar.
  while IFS= read -r satir; do
    [ -n "$satir" ] || continue
    kod="$(printf '%s' "$satir" | awk -F'\t' '{print $1}')"
    case "$kod" in '#OZET'*) continue ;; '') continue ;; esac
    durum="$(printf '%s' "$satir"  | awk -F'\t' '{print $3}')"
    tescil="$(printf '%s' "$satir" | awk -F'\t' '{print $4}')"
    konu="$(printf '%s' "$satir"   | awk -F'\t' '{print $8}')"
    proje="$(printf '%s' "$satir"  | awk -F'\t' '{print $11}')"
    [ -n "$proje" ] || proje="$ad"
    # Başlıkları KIRP: bu ekranın tek amacı "hepsi bir bakışta". Defterdeki `konu` alanları çoğu zaman
    # "Kısa Ad — uzun gerekçe" biçiminde; ham basılınca tek satır 300 karaktere çıkıp amacı bozuyor
    # (gerçek ortamda ölçüldü). Tam metin odasındaki `liste`'de duruyor. LAYIHA_FILO_GENIS=1 → kırpma yok.
    if [ "${LAYIHA_FILO_GENIS:-0}" != "1" ] && [ "${#konu}" -gt 84 ]; then konu="${konu:0:83}…"; fi
    # K3: YALNIZ başlık + durum. resume/dokuman/kart bilerek OKUNMAZ bile — detay odasında kalır.
    printf '  %-14s [%s]  %s%s  %s\n' "$proje" "$kod" "$(DUR_SIM "$durum")" "$(TES_SIM "$tescil")" "$konu"
    n=$((n+1)); TOPLAM=$((TOPLAM+1))
  done <<< "$cikti"
  [ "$n" -eq 0 ] && printf '  %-14s (bu filtrede kayıt yok)\n' "$ad"
done

echo ""
echo "── toplam $TOPLAM layiha · $OKUNAN oda okundu$( [ "$ATLANAN" -gt 0 ] && printf ' · %d oda atlandı' "$ATLANAN" )"
echo "   Not: yalnız BU makineden görünen odalar sayılır — izole container'ların defterleri"
echo "   buradan görünmez (İ1). Detay için o odaya girip 'layihaları listele' de."
exit 0
