#!/usr/bin/env bash
# betik-bekcisi.sh — bu kutunun kendi betiklerinde ÖLÇÜLMÜŞ üç tuzağı arar.
#
# 🔴 NİÇİN VAR (bileyi turu, 12 Ekim 2026 — ölçüldü, uydurulmadı):
#   Bu kutuda 16 ölçülmüş ders var; ≥2 kez tekrar eden üç sınıf şunlar ve üçünün de YAZILI
#   kuralı vardı, KOŞAN kapısı yoktu ("kurdum ama koşmuyor" — bu filonun en pahalı sınıfı):
#   1) ÇİFT SIFIR · `grep -c … || echo 0` boş dosyada "0\n0" basar (grep zaten 0 yazar).
#      Vaka: 8 Eki imar.sh (onarıldı) · 12 Eki devir-ayikla.test.sh (sınav kendi yakaladı)
#      · zeyl.sh:57 bu turda BULUNDU ve hâlâ canlıydı. Kanıt: boş dosyada çıktı iki satır.
#   2) KABUK ÖLDÜRME · `pkill -f <desen>` / `pgrep -f` çağıran kabuğu da eşler → exit 144.
#      Vaka: olc-kos.sh yorumunda "iki kez (exit 144)" · 12 Eki NECCÂR üçüncü kez yaptı.
#      Meşru yol: süreç numarasıyla kapat ya da scripts/tarayici/olc-kos.sh koşucusunu kullan.
#   3) YASAKLI SİLME · kanca `rm -rf` dizgisini bloklar (niyeti değil DİZGİyi eşler, ve haklı).
#      Betik içinde kanca görmez; ama meşru yol kurulu: bileyi/scripts/guvenli-sil.sh.
#
# 🔴 MASUMU SUÇLAMAZ — bu kutuda kapının masumu suçlaması üç kez ölçüldü (6·11·12 Ekim):
#   · yorum satırları (#) sayılmaz — ders metni suç değildir
#   · `pgrep -f`/`pkill -f` kendini dışlıyorsa (grep -vx "$$" ya da "$PPID") MASUMDUR
#   · suçlama satır numarası + satırın kendisiyle gösterilir; "bir yerde var" demez
#
# Kullanım: betik-bekcisi.sh [--kok <dizin>] [--sert] [--liste]
#   --sert : 3. sınıf (yasaklı silme) da kırmızı sayılır (varsayılan: sarı, rc'yi düşürmez)
# rc: 0 temiz (sarı olabilir) · 1 kırmızı bulgu var · 3 ÖLÇEMEDİM (kök yok/okunamadı) · 4 kullanım
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SERT=0; LISTE=0
while [ $# -gt 0 ]; do case "$1" in
  --kok) KOK="${2:-}"; shift 2;;
  --sert) SERT=1; shift;;
  --liste) LISTE=1; shift;;
  -h|--help) sed -n '1,30p' "$0"; exit 4;;
  *) echo "bilinmeyen argüman: $1" >&2; exit 4;;
esac; done
[ -d "$KOK" ] || { echo "ÖLÇEMEDİM: kök dizin yok: $KOK" >&2; exit 3; }
# 🔴 BEKÇİ KENDİNİ TARAMAZ ve bunu SÖYLER: ilk koşuda kendi arama desenlerini suç saydı —
# tam da uyardığı hata (kapı masumu suçluyor, bu kutuda üç kez ölçüldü). Kendi dosyası
# dışlanır; o dosyanın denetimi insana ve sınavına (betik-bekcisi.test.sh) kalır.
# Kendi SINAVI da dışlanır: sınav, tuzakları fikstür olarak ÜRETMEK zorundadır (printf ile sahte
# betik yazar) — ikinci koşuda bekçi tam da onları suç saydı. Bu çift (araç + sınavı) bekçinin
# kendi alanıdır; denetimi birbirleridir, üçüncü bir göze değil.
_D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; _B="$(basename "${BASH_SOURCE[0]}")"
KENDI="$_D/$_B"; KENDI_SINAV="$_D/${_B%.sh}.test.sh"
mapfile -t DOSYALAR < <(find "$KOK" -type f \( -name '*.sh' -o -name '*.bash' \) -not -path '*/node_modules/*' | grep -vxF "$KENDI" | grep -vxF "$KENDI_SINAV" | sort)
[ "${#DOSYALAR[@]}" -gt 0 ] || { echo "ÖLÇEMEDİM: $KOK altında kabuk betiği yok" >&2; exit 3; }

KIRMIZI=0; SARI=0
# satır yorum mu? (baştaki boşluklardan sonra #)
_yorum(){ case "${1#"${1%%[![:space:]]*}"}" in \#*) return 0;; *) return 1;; esac; }
_bas(){ printf '  %s:%s · %s\n' "${1#$KOK/}" "$2" "$(echo "$3" | sed 's/^[[:space:]]*//' | cut -c1-110)"; }

echo "🛡️  BETİK BEKÇİSİ · ${#DOSYALAR[@]} betik · kök: ${KOK}"
echo
echo "1 · ÇİFT SIFIR — 'grep -c … || echo' boş dosyada iki satır basar"
for f in "${DOSYALAR[@]}"; do
  while IFS=: read -r no satir; do
    [ -n "${no:-}" ] || continue; _yorum "$satir" && continue
    _bas "$f" "$no" "$satir"; KIRMIZI=$((KIRMIZI+1))
    echo "     → onar: n=\$(grep -c … 2>/dev/null); echo \"\${n:-0}\""
  done < <(grep -n 'grep -c[^|]*|| *echo' "$f" 2>/dev/null)
done
[ "$KIRMIZI" -eq 0 ] && echo "  temiz"

echo
echo "2 · KABUK ÖLDÜRME — desenle süreç öldürmek çağıran kabuğu da eşler (exit 144)"
K2=0
for f in "${DOSYALAR[@]}"; do
  while IFS=: read -r no satir; do
    [ -n "${no:-}" ] || continue; _yorum "$satir" && continue
    # kendini dışlama AYNI satırda olmak zorunda değil: ölçülen vaka (tarayici-kapat.sh) dışlamayı
    # bir sonraki satırda yapıyordu ve bekçi onu masumken suçladı. Pencere: satırın kendisi + 3 satır.
    pencere="$(sed -n "${no},$((no+3))p" "$f" 2>/dev/null)"
    case "$pencere" in *'$$'*|*'$PPID'*|*'/proc/'*) continue;; esac   # kendini dışlıyor → masum
    _bas "$f" "$no" "$satir"; K2=$((K2+1)); KIRMIZI=$((KIRMIZI+1))
    echo "     → onar: süreç numarasıyla kapat, ya da scripts/tarayici/olc-kos.sh koşucusunu kullan"
  done < <(grep -n 'pkill -f\|pgrep -f' "$f" 2>/dev/null)
done
[ "$K2" -eq 0 ] && echo "  temiz (kendini dışlayan kullanımlar masum sayıldı)"

echo
echo "3 · YASAKLI SİLME — kanca bu dizgiyi bloklar; meşru yol kurulu" $([ "$SERT" = 1 ] && echo "[SERT: kırmızı]" || echo "[sarı]")
K3=0; DESEN="rm -"$'rf'
for f in "${DOSYALAR[@]}"; do
  while IFS=: read -r no satir; do
    [ -n "${no:-}" ] || continue; _yorum "$satir" && continue
    _bas "$f" "$no" "$satir"; K3=$((K3+1))
    echo "     → meşru yol: bash /config/.claude/skills/bileyi/scripts/guvenli-sil.sh <dizin>"
  done < <(grep -nF "$DESEN" "$f" 2>/dev/null)
done
[ "$K3" -eq 0 ] && echo "  temiz"
if [ "$SERT" = 1 ]; then KIRMIZI=$((KIRMIZI+K3)); else SARI=$((SARI+K3)); fi

echo
echo "— kırmızı $KIRMIZI · sarı $SARI · taranan ${#DOSYALAR[@]} betik"
echo "  ATLANAN: bekçinin kendi dosyası ve kendi sınavı (desenleri ve fikstürleri suç sayılmasın)."
echo "  ÖLÇMEDİĞİ: boru arkasında yutulan çıkış kodu (meşru değer alımından ayırt edilemiyor,"
echo "  52 kullanımın çoğu masum) · kurulu olmayan araçların kullanımı · niyet."
[ "$KIRMIZI" -eq 0 ]
