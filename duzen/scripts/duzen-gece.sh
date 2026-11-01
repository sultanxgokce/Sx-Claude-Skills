#!/usr/bin/env bash
# duzen-gece.sh — gece düzen kurulumu (Kuzey G25+G29): kaynaktaki düzen paketi kurulu olandan YENİYSE dört düzen becerisini
# (duzen · gunluk-plan · mesveret · bulgu) kurar, bu kutudaki ekipc işaretli BAYAT kimlikleri yeniler ve kutunun reisine
# "düzen vX indi" mektubu yollar. VARSAYILAN KURU: --uygula olmadan hiçbir şey yazmaz/yollamaz.
#
# Kullanım: duzen-gece.sh [--uygula] [--depo KÖK] [--kutu AD] [--reis AD] [--sx KÖK] [--gunluk DOSYA]
#   --sx      Sx-Claude-Skills kökü (varsayılan /config/projects/Sx-Claude-Skills; kaynak sürüm onun duzen/SKILL.md'sinden okunur)
#   --kutu    günlüğe/mektuba yazılan kutu adı (varsayılan: duzen sürüm kaydındaki hostname kısası)
#   --reis    mektubun gideceği reis(ler): virgülle ayrılmış 'kutu:reis' (ya da yalnız reis = bu kutu). /config/.claude her kutuda AYNI dizin olduğu için
#             betik tek yerde koşar ve HER kutu reisine ayrı mektup gider. Boşsa/bilinmiyorsa mektup ATLANIR ve günlüğe yazılır — tahminle yazılmaz
# Dikişler (sınav): DUZEN_SYNC_CMD · DUZEN_YENILE_CMD · DUZEN_MEKTUP_CMD · DUZEN_KURULU_KOK (kurulu beceriler kökü)
# duzen_gunlugu satırları (key=value, tek satır):
#   <ISO> kuruldu beceri=<ad> surum=<yeni> onceki=<eski|yok> kutu=<kutu> reis=<reis|->
#   <ISO> yenilendi kimlik=<ad> temel=<manuel-claude|MÜDÜR|otonom-ajan> surum=<duzen sürümü> kutu=<kutu> reis=<reis|->
#   <ISO> atlandi beceri=<ad> sebep=<…> kutu=<kutu>        (kurulum yapılamadı: elle değişmiş kopya vb.)
#   <ISO> mektup reis=<reis|-> surum=<v> durum=gitti|atlandi|hata kutu=<kutu>
# rc: 0 iş yok ya da bitti · 1 en az bir adım atlandı/hata · 2 kullanım · 3 ölçülemedi (kaynak sürümü okunamadı)
set -uo pipefail
# TÜM gövde tek fonksiyonda: bash betiği artımlı okur, gece kurulumu bu dosyayı (duzen paketi) yerinde yeniden yazar → sarılmazsa kurulumdan sonraki satırlar kayık okunur.
# Fonksiyon baştan ayrıştırıldığı için dosya koşarken değişse de bu çalışma etkilenmez; çağrı ile exit aynı satırda (dönüşte dosyadan başka satır okunmaz).
main() {
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SURUM="$HERE/surum.sh"
BECERILER=(duzen gunluk-plan mesveret bulgu)
SX="/config/projects/Sx-Claude-Skills"; DEPO=""; KUTU=""; REIS=""; UYGULA=0
KURULU_KOK="${DUZEN_KURULU_KOK:-/config/.claude/skills}"; GUNLUK="${DUZEN_GUNLUGU:-/config/.claude/duzen-gunlugu.log}"
while [ $# -gt 0 ]; do
  case "$1" in
    --uygula) UYGULA=1; shift ;; --kuru) UYGULA=0; shift ;;
    --depo) DEPO="${2:-}"; shift 2 ;; --kutu) KUTU="${2:-}"; shift 2 ;; --reis) REIS="${2:-}"; shift 2 ;;
    --sx) SX="${2:-}"; shift 2 ;; --gunluk) GUNLUK="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
    *) echo "duzen-gece: bilinmeyen seçenek: $1" >&2; exit 2 ;;
  esac
done
[ -n "$DEPO" ] || DEPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
[ -n "$KUTU" ] || KUTU="$(hostname -s 2>/dev/null || echo kutu)"
SYNC="${DUZEN_SYNC_CMD:-node $SX/sync-skills.mjs}"
# Yenileme betiğin YANINDAKİ paket ekipc.sh ile yapılır (vendor/yaml taşır); Nexus scripts/ekipc.sh değil — zamanlayıcı PATH'inde PyYAML yok, Nexus kopyası exit 2 verir (1 Kas 2026 03:17: 37 kimlik atlandı).
YENILE="${DUZEN_YENILE_CMD:-bash $HERE/ekipc.sh yenile}"
MEKTUP="${DUZEN_MEKTUP_CMD:-bash /config/projects/Nexus/scripts/ulak.sh gonder}"
surum_oku() { sed -nE 's/^[[:space:]]*version:[[:space:]]*["'"'"']?([0-9]+\.[0-9]+\.[0-9]+)["'"'"']?[[:space:]]*$/\1/p' "$1" 2>/dev/null | head -1; }
yeni_mi() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]; }   # $1 > $2
yaz() { local s; s="$(date -Iseconds) $*"; echo "$s"; [ "$UYGULA" -eq 1 ] || return 0; mkdir -p "$(dirname "$GUNLUK")" 2>/dev/null; printf '%s\n' "$s" >> "$GUNLUK" || echo "duzen-gece: günlüğe yazılamadı" >&2; }

KAYNAK_DUZEN="$(surum_oku "$SX/duzen/SKILL.md")"
[ -n "$KAYNAK_DUZEN" ] || { echo "duzen-gece: ÖLÇÜLEMEDİ — kaynak sürüm okunamadı ($SX/duzen/SKILL.md)" >&2; exit 3; }
RC=0; REISYAZ="${REIS:--}"; REISYAZ="${REISYAZ//,/+}"; REISYAZ="${REISYAZ//[^[:alnum:]_+:ÇĞİÖŞÜçğıöşü-]/}"; [ "$UYGULA" -eq 1 ] || echo "KURU: yazılmayacak, yollanmayacak (uygulamak için --uygula)"

# 1) dört beceriyi kur (kaynak > kurulu olanı; --force YOK — elle değişmiş kopya ezilmez, atlanır ve günlüğe yazılır)
KURULDU=0; KURULANLAR=()
# tetik: düzen paketinin sürümü artınca dört becerinin TAMAMI kurulur; düzen aynıysa yalnız kendi sürümü artan beceri
dk="$(surum_oku "$SX/duzen/SKILL.md")"; dku="$(surum_oku "$KURULU_KOK/duzen/SKILL.md")"
ZORLA=0; { [ -z "$dku" ] || yeni_mi "$dk" "$dku"; } && ZORLA=1
for b in "${BECERILER[@]}"; do
  kv="$(surum_oku "$SX/$b/SKILL.md")"; ku="$(surum_oku "$KURULU_KOK/$b/SKILL.md")"
  [ -n "$kv" ] || { yaz "atlandi beceri=$b sebep=kaynak-surum-okunamadi kutu=$KUTU"; RC=1; continue; }
  if [ "$ZORLA" -eq 1 ] || [ -z "$ku" ] || yeni_mi "$kv" "$ku"; then
    if [ "$UYGULA" -eq 1 ]; then
      if $SYNC --skill "$b" --apply </dev/null >/dev/null 2>&1; then yaz "kuruldu beceri=$b surum=$kv onceki=${ku:-yok} kutu=$KUTU reis=$REISYAZ"; KURULDU=1; KURULANLAR+=("$b")
      else yaz "atlandi beceri=$b sebep=sync-reddetti-rc$? kutu=$KUTU"; RC=1; fi
    else echo "KURU: $b ${ku:-yok} → $kv kurulacaktı"; KURULDU=1; fi
  fi
done

# 2) bu depoda BAYAT ekipc kimliklerini yenile (temel adı gömülü metinden: manuel-claude-base → --baz manuel-claude · mudur-base → --rol MÜDÜR · otonom-ajan-base → --baz otonom-ajan)
YENILENDI=0
while IFS= read -r satir; do
  ad="$(sed -nE 's/^[[:space:]]*([^:[:space:]]+): BAYAT.*/\1/p' <<<"$satir")"; [ -n "$ad" ] || continue
  temel="$(sed -nE 's/.*temel: ([a-z-]+)-base.*/\1/p' <<<"$satir")"
  case "$temel" in manuel-claude) arg=(--baz manuel-claude); t=manuel-claude ;; mudur) arg=(--rol MÜDÜR); t=MÜDÜR ;; otonom-ajan) arg=(--baz otonom-ajan); t=otonom-ajan ;; *) yaz "atlandi beceri=kimlik:$ad sebep=temel-bilinmiyor kutu=$KUTU"; RC=1; continue ;; esac
  if [ "$UYGULA" -eq 1 ]; then
    if $YENILE --dosya "$DEPO/_agents/$ad/AGENT.md" "${arg[@]}" --apply </dev/null >/dev/null 2>&1; then yaz "yenilendi kimlik=$ad temel=$t surum=$KAYNAK_DUZEN kutu=$KUTU reis=$REISYAZ"; YENILENDI=1
    else yaz "atlandi beceri=kimlik:$ad sebep=yenile-reddetti kutu=$KUTU"; RC=1; fi
  else echo "KURU: $ad yenilenecekti ($t)"; YENILENDI=1; fi
done < <(bash "$SURUM" denetle --depo "$DEPO" --kurulu "$KURULU_KOK/duzen" 2>/dev/null)

# 3) reise düzen konulu sürüm mektubu (yalnız bir şey kurulduysa/yenilendiyse; reis bilinmiyorsa tahmin edilmez)
if [ "$UYGULA" -eq 1 ] && { [ "$KURULDU" -eq 1 ] || [ "$YENILENDI" -eq 1 ]; }; then
  if [ -z "$REIS" ]; then yaz "mektup reis=- surum=$KAYNAK_DUZEN durum=atlandi kutu=$KUTU"; RC=1
  else
    IFS=',' read -r -a LISTE <<<"$REIS"
    for oge in "${LISTE[@]}"; do
      case "$oge" in *:*) mk="${oge%%:*}"; mr="${oge#*:}" ;; *) mk="$KUTU"; mr="$oge" ;; esac
      if [ -z "$mr" ] || [ "$mr" = "-" ]; then yaz "mektup reis=- surum=$KAYNAK_DUZEN durum=atlandi kutu=$mk"; RC=1; continue; fi
      if $MEKTUP "$mr" "düzen v$KAYNAK_DUZEN indi ($mk): kurulan beceriler: ${KURULANLAR[*]:-yok}; yenilenen kimlik: $YENILENDI (1=var, 0=yok). 'bash /config/.claude/skills/duzen/scripts/surum.sh denetle' koş; BAYAT kimlik kalırsa 'ekipc yenile' ile tazele." --kimden MİRAHUR --onem normal --konu "düzen v$KAYNAK_DUZEN indi" </dev/null >/dev/null 2>&1
      then yaz "mektup reis=$mr surum=$KAYNAK_DUZEN durum=gitti kutu=$mk"
      else yaz "mektup reis=$mr surum=$KAYNAK_DUZEN durum=hata kutu=$mk"; RC=1; fi
    done
  fi
fi
exit "$RC"
}
main "$@"; exit $?
