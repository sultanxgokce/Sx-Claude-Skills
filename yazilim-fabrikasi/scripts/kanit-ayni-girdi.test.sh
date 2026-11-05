#!/usr/bin/env bash
# kanit-ayni-girdi.test.sh — kanit.sh olcum --ayni-girdi-atla: aynı girdide sınav yeniden koşmaz; girdi değişince, mutantta, kırmızı kayıtta ve bayraksız KOŞAR.
# Sayaç: sınavın gerçekten koştuğu, depo DIŞINDaki sayac dosyasına satır eklemesiyle ölçülür (koşmadıysa satır artmaz).
set -uo pipefail
export KANIT_SIRA=0
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; K_ASIL="${KANIT:-$HERE/kanit.sh}"
gecen=0; kalan=0; g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }

kos_takim() {   # $1 = kanit.sh yolu, $2 = ad öneki
  local K="$1" P="$2" T S CNT c
  T="$(mktemp -d)"; S="$(mktemp -d)"; export KANIT_DEPO="$T"; CNT="$S/sayac"; : > "$CNT"
  ( cd "$T" && git init -q -b main && git config user.email t@t && git config user.name t && echo a > f.sh && git add -A && git commit -q -m "chore: ilk" ) >/dev/null 2>&1
  printf '#!/usr/bin/env bash\necho x >> "%s"\nexit 0\n' "$CNT" > "$S/gec.sh"
  printf '#!/usr/bin/env bash\necho x >> "%s"\nexit 1\n' "$CNT" > "$S/kirmizi.sh"
  printf '#!/usr/bin/env bash\necho x >> "%s"\necho "✗ K1 düştü"\nexit 1\n' "$CNT" > "$S/mut.sh"
  sayi() { wc -l < "$CNT" | tr -d ' '; }
  ol() { ( cd "$T" && bash "$K" olcum "$@" ) 2>&1; }
  commitle() { ( cd "$T" && git add -A && git commit -q -m "docs: $1" ) >/dev/null 2>&1; }

  echo "════ ${P}A1 · bayraksız: iki çağrı iki koşu ════"
  ol is-g bir --asama tek -- bash "$S/gec.sh" >/dev/null; commitle k1; ol is-g bir --asama tek -- bash "$S/gec.sh" >/dev/null
  [ "$(sayi)" = "2" ]; g $? "bayraksız ikinci çağrı da koştu (sayaç 2)"

  echo "════ ${P}A2 · bayraklı: ilk koşar, ikinci (kanıt commit'i arada) koşmaz ════"
  ol is-g iki --asama tek --ayni-girdi-atla -- bash "$S/gec.sh" >/dev/null; commitle k2
  [ "$(sayi)" = "3" ]; g $? "bayraklı ilk çağrı koştu (sayaç 3)"
  c="$(ol is-g iki --asama tek --ayni-girdi-atla -- bash "$S/gec.sh")"; commitle k3
  [ "$(sayi)" = "3" ]; g $? "aynı girdi: komut YENİDEN KOŞMADI (sayaç 3)"
  printf '%s' "$c" | grep -q "YENİDEN KOŞMADI"; g $? "çıktı yeniden koşmadığını söylüyor"
  ( cd "$T" && bash "$K" dogrula is-g ) >/dev/null 2>&1; g $? "dogrula rc=0 (kayıt değişmedi, imza sağlam)"

  echo "════ ${P}A3 · girdi değişince koşar ════"
  ( cd "$T" && echo b > f.sh ); commitle kod
  ol is-g iki --asama tek --ayni-girdi-atla -- bash "$S/gec.sh" >/dev/null
  [ "$(sayi)" = "4" ]; g $? "izlenen kod dosyası değişti → koştu (sayaç 4)"
  echo "# degisti" >> "$S/gec.sh"
  ol is-g iki --asama tek --ayni-girdi-atla -- bash "$S/gec.sh" >/dev/null
  [ "$(sayi)" = "5" ]; g $? "depo DIŞI betik içeriği değişti → koştu (sayaç 5)"
  ol is-g iki --asama tek --ayni-girdi-atla -- bash "$S/gec.sh" x >/dev/null
  [ "$(sayi)" = "6" ]; g $? "komut argümanı değişti → koştu (sayaç 6)"
  echo u1 > "$T/u.txt"; ol is-g iki --asama tek --ayni-girdi-atla -- bash "$S/gec.sh" >/dev/null
  echo u2 > "$T/u.txt"; ol is-g iki --asama tek --ayni-girdi-atla -- bash "$S/gec.sh" >/dev/null
  [ "$(sayi)" = "8" ]; g $? "izlenmeyen dosyanın içeriği değişti → yine koştu (sayaç 8)"

  printf 'ign.txt\n' > "$T/.gitignore"; commitle gi; echo i1 > "$T/ign.txt"
  ol is-g iki --asama tek --ayni-girdi-atla -- bash "$S/gec.sh" >/dev/null
  echo i2 > "$T/ign.txt"; ol is-g iki --asama tek --ayni-girdi-atla -- bash "$S/gec.sh" >/dev/null
  [ "$(sayi)" = "10" ]; g $? "Git'in yok saydığı depo içi dosyanın içeriği değişti → yine koştu (sayaç 10)"

  echo "════ ${P}A4 · mutant ve kırmızı kayıt atlanmaz ════"
  ol is-g mut --asama tek --mutasyon iki --kapi K1 --ayni-girdi-atla -- bash "$S/mut.sh" >/dev/null
  ol is-g mut --asama tek --mutasyon iki --kapi K1 --ayni-girdi-atla -- bash "$S/mut.sh" >/dev/null
  [ "$(sayi)" = "12" ]; g $? "mutasyon ölçümü bayrakla bile iki kez koştu (sayaç 12)"
  ol is-g kirm --asama tek --ayni-girdi-atla -- bash "$S/kirmizi.sh" >/dev/null
  ol is-g kirm --asama tek --ayni-girdi-atla -- bash "$S/kirmizi.sh" >/dev/null
  [ "$(sayi)" = "14" ]; g $? "kırmızı önceki kayıt atlanmaz, iki kez koştu (sayaç 14)"

  echo "════ ${P}A5 · kirli ağaç: anahtar HEAD'i temsil etmez, koşar ════"
  commitle onceki   # izlenmeyen u.txt ağaca girsin: anahtar iki ölçüm arasında kendiliğinden kaymasın
  ol is-g kirli --asama tek --ayni-girdi-atla -- bash "$S/gec.sh" >/dev/null; commitle k4
  ( cd "$T" && echo c > f.sh )
  ol is-g kirli --asama tek --ayni-girdi-atla --kirli-izin "sınav: kirli ağaçta atlama yok" -- bash "$S/gec.sh" >/dev/null
  [ "$(sayi)" = "16" ]; g $? "kirli ağaçta (izinli) atlanmadı (sayaç 16)"
  rm -rf "$T" "$S"
}

kos_takim "$K_ASIL" ""

echo "════ M · mutantlar: araç bozulursa sınav DÜŞMELİ ════"
MD="$(mktemp -d)"; cp "$HERE/kanit.py" "$MD/asil.py"
printf '#!/usr/bin/env bash\nexec python3 "%s/kanit.py" "$@"\n' "$MD" > "$MD/kanit.sh"; chmod +x "$MD/kanit.sh"
mut() {   # $1 ad, sonra (eski, yeni) çiftleri
  local ad="$1"; shift
  cp "$MD/asil.py" "$MD/kanit.py"
  python3 - "$MD/kanit.py" "$@" <<'PY'
import sys
p = sys.argv[1]; cift = sys.argv[2:]
t = open(p, encoding="utf-8").read()
for eski, yeni in zip(cift[0::2], cift[1::2]):
    assert eski in t, "mutant çapası bulunamadı: " + eski
    t = t.replace(eski, yeni, 1)
open(p, "w", encoding="utf-8").write(t)
PY
  [ $? -eq 0 ] || { g 1 "mutant kurulamadı: $ad"; return; }
  local gec0=$gecen kal0=$kalan cikti
  cikti="$(kos_takim "$MD/kanit.sh" "M:$ad " 2>&1)"
  gecen=$gec0; kalan=$kal0
  if printf '%s' "$cikti" | grep -q "✗"; then g 0 "mutant YAKALANDI: $ad"; else g 1 "mutant KAÇTI: $ad"; fi
}
mut "ağaç özeti çıkarıldı" '"agac": satirlar,' '"agac": [],'
mut "dış betik sha çıkarıldı" '"dis": dis,' '"dis": [],'
mut "izlenmeyen dosya çıkarıldı" '"izlenmeyen": izlenmeyen,' '"izlenmeyen": [],'
mut "mutant atlanabilir (yok sayma + kayıtta anahtar + mutant süzgeci)" '        if mut:
            print("ℹ --ayni-girdi-atla mutasyon' '        if False:
            print("ℹ --ayni-girdi-atla mutasyon' 'if anahtar and not mut: kayit["girdi_anahtar"]' 'if anahtar: kayit["girdi_anahtar"]' 'and not k.get("mutasyon") and' 'and' 'and k.get("rc") == 0
                and k.get("renk")' 'and k.get("renk")'
mut "yok sayılan dosya çıkarıldı" '"yoksayilan": yoksayilan,' '"yoksayilan": [],'
mut "kırmızı kayıt atlanabilir" 'and k.get("rc") == 0
                and k.get("renk") == "yesil" and k.get("etkin_renk") == "yesil"' 'and True'
mut "kirli ağaçta anahtar kurulur" 'if anahtar and (_ok0 or KIRLI_IZIN):' 'if False:'
rm -rf "$MD"

echo; echo "SONUÇ: $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ]
