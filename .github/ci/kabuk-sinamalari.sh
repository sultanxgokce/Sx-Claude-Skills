#!/usr/bin/env bash
# kabuk-sinamalari.sh <kova> — Sx-Claude-Skills CI: her *.test.sh'i BİR kovada koşar (diploma · denetci · kalan).
#
# NİÇİN: tek `for` döngüsü 41 dk sürüyordu (CI #40003038870: 139 sınav, 2493 sn; diploma 740 · denetci 598 · kalan ~1150).
# Üç kova üç AYRI runner'da (lint.yml matrisi) koşar; duvar süresi en uzun kovadır (diploma). `kalan` kovası kendi içinde
# xargs -P ile paralel koşar (Nexus scripts/kabuk-testleri.sh deseni, #1223). Her kova KENDİ keşfini yapar ve aşağıdaki
# kova() kuralı listeyi BÖLER: bir sınama tam bir kovaya düşer (case'in son kolu * → yeni sınama kendiliğinden `kalan`'a girer,
# hiçbiri yetim kalmaz).
#
# Korunan eski sözleşme: liste TÜRETİLİR (find), sıfır bulmak KIRMIZI, karantina adıyla loglanır ve sayılır, karantina listesi
# bayatlarsa KIRMIZI, sınama başına süre tavanı (`# kabuk-testleri: sure=N`, varsayılan 300, tavan 900), arçelik sınavı ayrı işte.
set -uo pipefail
KOVA="${1:-}"
case "$KOVA" in diploma|denetci|kalan) ;; *) echo "::error::kullanım: kabuk-sinamalari.sh diploma|denetci|kalan (verilen: '${KOVA}')"; exit 2 ;; esac
cd "$(git rev-parse --show-toplevel 2>/dev/null || dirname "$0"/../..)" || exit 2

# KARANTİNA — kapı ilk kurulurken KIRMIZI bulunan, ilgisiz sınamalar. Sessiz atlama YASAK: her satır adıyla loglanır.
#   mucit-t1.test.sh   — 4 kapı (G10/G11 kota-tavanı · G17b/G18 layiha-üretimi) YALNIZ GitHub runner'ında düşüyor; üç yerel
#                        yapılandırmada 39/39 geçiyor. L24 MUCİT paketinin işi.
#   kasif-hafiza.test.sh — TAKVİMLE ÇÜRÜYEN SINAV (2026-08-23, PR #206): fikstür SABİT tarih, araç KAYAN 30 günlük pencere.
#                        Onarım: fikstür tarihleri göreceli olsun. Sahibi KAŞİF/MUCİT hattı.
#   compact.test.sh    — K2 (tur sırasında eklenen satır kaybolmaz) origin/main'de de KIRMIZI (2026-10-17); görev defteri bulgusu,
#                        sahip BÂNİ, kart compact-k2-yaris.
KARANTINA=" ./mucit-suz/scripts/mucit-t1.test.sh ./kasif-tara/scripts/kasif-hafiza.test.sh ./terminal-onar/scripts/compact.test.sh "
KABUK_SURE_VARSAYILAN=300; KABUK_SURE_TAVAN=900
PARALEL="${KABUK_PARALEL:-$(nproc 2>/dev/null || echo 2)}"; [ "$PARALEL" -ge 1 ] 2>/dev/null || PARALEL=2; [ "$PARALEL" -le 4 ] || PARALEL=4

kova() {   # kova <sınama yolu> → bu sınama hangi kovada
  case "$1" in
    ./tescil/scripts/diploma.test.sh)                  echo diploma ;;
    ./yazilim-fabrikasi/scripts/denetci.test.sh)       echo denetci ;;
    *)                                                 echo kalan ;;
  esac
}
sure_sec() {
  local t="$1" n
  n="$(head -15 "$t" 2>/dev/null | sed -n 's/^# *kabuk-testleri: *sure=\([0-9]\{1,5\}\) *$/\1/p' | head -1)"
  if [ -z "$n" ] || [ "$n" -lt 1 ]; then echo "$KABUK_SURE_VARSAYILAN"; return 0; fi
  if [ "$n" -gt "$KABUK_SURE_TAVAN" ]; then echo "::warning::$t sure=$n istedi, tavan $KABUK_SURE_TAVAN uygulandı" >&2; echo "$KABUK_SURE_TAVAN"; return 0; fi
  echo "$n"
}
kos_bir() {   # kos_bir <günlük dizini> <sınama> → <ad>.log .rc .ms
  local g="$1" t="$2" ad sure t0 rc
  ad="$(echo "$t" | tr '/' '_')"; sure="$(sure_sec "$t" 2>"$g/$ad.uyari")"; t0="$(date +%s%N)"
  timeout "$sure" bash "$t" > "$g/$ad.log" 2>&1 < /dev/null; rc=$?
  echo "$(( ( $(date +%s%N) - t0 ) / 1000000 ))" > "$g/$ad.ms"; echo "$sure" > "$g/$ad.sure"; echo "$rc" > "$g/$ad.rc"
}
export -f kos_bir sure_sec; export KABUK_SURE_VARSAYILAN KABUK_SURE_TAVAN

# Arçelik sınavı aşağıdaki bağımsız işte koşar; burada ikinci kez çalıştırılmaz.
mapfile -t TUM < <(find . -name '*.test.sh' -not -path './.git/*' -not -path './arcelik-fatura-kesim/scripts/kesim.test.sh' | sort)
if [ "${#TUM[@]}" -eq 0 ]; then echo "::error::hiç *.test.sh bulunamadı — keşif bozuk"; exit 1; fi
dusen=0; atlanan=0; KOS=(); BENIM=0
for t in "${TUM[@]}"; do
  [ "$(kova "$t")" = "$KOVA" ] || continue
  BENIM=$((BENIM+1))
  case "$KARANTINA" in *" $t "*) echo "::warning::KARANTİNA — atlandı: $t"; atlanan=$((atlanan+1)); continue ;; esac
  KOS+=("$t")
done
# Kovası boş kalmak kırmızıdır: kova() kuralı bir dosya adına bağlı ve o ad kayarsa kova sessizce "hiçbir şey koşmadı, yeşil" derdi.
if [ "$BENIM" -eq 0 ]; then echo "::error::'$KOVA' kovasında hiç sınama yok — kova kuralı dosya adına tutmuyor (keşif bozuk)"; exit 1; fi
echo "kova=$KOVA · toplam sınama ${#TUM[@]} · bu kovada $BENIM · koşan ${#KOS[@]} · atlanan $atlanan · paralel $PARALEL"

G="$(mktemp -d)"; trap 'find "$G" -mindepth 1 -delete 2>/dev/null; rmdir "$G" 2>/dev/null' EXIT
T0="$(date +%s)"; havuz_rc=0
if [ "${#KOS[@]}" -gt 0 ]; then
  printf '%s\0' "${KOS[@]}" | xargs -0 -P "$PARALEL" -n 1 bash -c 'kos_bir "$1" "$2"' _ "$G" || havuz_rc=$?
  [ "$havuz_rc" -eq 0 ] || echo "::warning::işçi havuzu (xargs -P $PARALEL) rc=$havuz_rc — koşmayan sınama varsa aşağıda ÖLÇÜLEMEDİ olarak kırmızı"
fi
# Paralelde ZAMAN AŞIMINA (124) düşen sınama TEK BAŞINA bir kez daha ölçülür: yük altındaki aşım "takıldı" değil "ölçülemedi".
# Tek başına geçerse geçer AMA ekrana ::warning:: yazılır; yine aşarsa kırmızı. Başka her kırmızı olduğu gibi kırmızı kalır
# (paralel çarpışma saklanmaz: paylaşılan kaynak hatası görünür olsun).
YENIDEN=()
for t in "${KOS[@]}"; do
  ad="$(echo "$t" | tr '/' '_')"; [ "$(cat "$G/$ad.rc" 2>/dev/null)" = "124" ] || continue
  [ "${#KOS[@]}" -gt 1 ] || continue
  ilk="$(cat "$G/$ad.ms")"; kos_bir "$G" "$t"; YENIDEN+=("$t|$ilk|$(cat "$G/$ad.rc")|$(cat "$G/$ad.ms")")
done
for y in ${YENIDEN[@]+"${YENIDEN[@]}"}; do IFS='|' read -r t ilk rc ms <<<"$y"; echo "::warning::$t paralelde zaman aşımına düştü (${ilk} ms), tek başına yeniden ölçüldü: rc=$rc (${ms} ms)"; done

# Sonuçlar listelenme sırasıyla okunur; günlükler grup içinde basılır.
for t in "${KOS[@]}"; do
  ad="$(echo "$t" | tr '/' '_')"
  echo "::group::── $t"; cat "$G/$ad.uyari" 2>/dev/null; cat "$G/$ad.log" 2>/dev/null; echo "::endgroup::"
  if [ ! -f "$G/$ad.rc" ]; then echo "::error::$t ÖLÇÜLEMEDİ: işçi koşmadı (havuz rc=$havuz_rc)"; dusen=$((dusen+1)); continue; fi
  rc="$(cat "$G/$ad.rc")"; ms="$(cat "$G/$ad.ms")"; sure="$(cat "$G/$ad.sure")"
  if [ "$rc" -eq 0 ]; then echo "   ✓ $t (${ms} ms)"; else echo "::error::$t KIRMIZI rc=$rc (süre tavanı ${sure}sn, ${ms} ms)"; dusen=$((dusen+1)); fi
done
echo "kova=$KOVA toplam=$BENIM koşan=${#KOS[@]} atlanan=$atlanan düşen=$dusen duvar=$(( $(date +%s) - T0 )) sn"
# karantina listesindeki bir dosya artık YOKSA liste bayatlamıştır → kırmızı (kalan kovası bakar; tek kova tek kez raporlar)
if [ "$KOVA" = kalan ]; then
  for k in $KARANTINA; do [ -f "$k" ] || { echo "::error::karantina listesi bayat: $k artık yok"; dusen=$((dusen+1)); }; done
fi
[ "$dusen" -eq 0 ]
