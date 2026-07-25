#!/usr/bin/env bash
# kasif-tara.test.sh — L24 F3 KURULUM KANITI (G1-G8).
#
# NE SINAR: "paket bir odaya kurulunca gerçekten ÇALIŞIYOR mu" — motor pakete taşındıktan sonra en kötü
#   arıza türü "görünür ama çalışmaz"dı (el-kitabı iniyor, komut `No such file` diyor). Bu takım o
#   arızayı kurulu-düzenin kendisinde yakalar.
#
# HERMETİK: yalnız $TMPDIR altında sahte odalar kurar. Gerçek bayrağa, gerçek deftere, ortak dizine
#   YAZMAZ (G6 bunu ayrıca KANITLAR). node/npm gerekmez — saf bash + jq + python3.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAKETLER="$(cd "$HERE/../.." && pwd)"
KUR="$HERE/kasif-kur.sh"
KASIF="$HERE/kasif-havuz-ekle.sh"
MUCIT="$PAKETLER/mucit-suz/scripts/mucit-t1.sh"
FABRIKA="$PAKETLER/layiha-fabrikasi/scripts/layiha-fabrika.sh"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "PASS  $1"; }
kotu() { FAIL=$((FAIL+1)); echo "FAIL  $1 — beklenen [$2] · gelen [$3]"; }
esit() { if [ "$2" = "$3" ]; then ok "$1"; else kotu "$1" "$2" "$3"; fi; }

# Sahte oda = gerçek git deposu (hat-yolu git-kökü ister; K1 gereği git-siz yerde çalışmaz).
oda_kur() { # $1=ad → yol basar
  local d="$T/$1"
  mkdir -p "$d"
  ( cd "$d" && git init -q && git config user.email t@t && git config user.name t ) >/dev/null 2>&1
  printf '%s' "$d"
}

# Bayrağı ve kurulum-anahtarını gerçek ortak dizinden İZOLE et (hiçbir test gerçek bayrağa dokunmaz).
export LAYIHA_FABRIKA_BAYRAK="$T/kapali.flag"
export LAYIHA_FABRIKA_HOST="test-oda-1"

echo "=== G1 · sözdizimi: paketteki her script bash -n temiz ==="
G1FAIL=0
for f in "$PAKETLER"/kasif-tara/scripts/*.sh "$PAKETLER"/mucit-suz/scripts/*.sh "$PAKETLER"/layiha-fabrikasi/scripts/*.sh; do
  bash -n "$f" 2>/dev/null || { echo "   sözdizimi HATASI: $f"; G1FAIL=$((G1FAIL+1)); }
done
esit "G1 bash -n hepsi temiz" "0" "$G1FAIL"

echo
echo "=== G2 · bootstrap: boş odada tezgâh doğar ==="
ODA1="$(oda_kur oda1)"
( cd "$ODA1" && bash "$KUR" ) >"$T/kur1.log" 2>&1
esit "G2 kasif-kur rc=0" "0" "$?"
for p in _agents/handoff/bulgu-havuzu.jsonl _agents/handoff/layiha-aday-havuzu.jsonl \
         _agents/handoff/mucit-defteri.jsonl _agents/handoff/mucit-defteri-layiha.jsonl \
         _agents/handoff/layiha-defteri.jsonl _agents/mucit/kanon.json _agents/kasif/knowledge; do
  if [ -e "$ODA1/$p" ]; then ok "G2 üretildi: $p"; else kotu "G2 üretildi: $p" "var" "yok"; fi
done
# K4 — doğuştan KAPALI
esit "G2 K4: yeni oda üretime KAPALI doğdu" "0" \
  "$(if [ -e "$LAYIHA_FABRIKA_BAYRAK" ]; then echo 0; else echo 1; fi)"
esit "G2 K4: kapatma YEREL kapsamda (filo değil)" "yerel" \
  "$(jq -r '.kapsam' "$LAYIHA_FABRIKA_BAYRAK" 2>/dev/null)"
esit "G2 K4: kapsamda yalnız bu oda var" "test-oda-1" \
  "$(jq -r '.scope|join(",")' "$LAYIHA_FABRIKA_BAYRAK" 2>/dev/null)"

echo
echo "=== G3 · idempotans: ikinci koşu veriyi bozmaz, açık odayı YENİDEN KAPATMAZ ==="
echo '{"id":"b0001","baslik":"elle konmuş satır","durum":"ham","kanit":"x"}' > "$ODA1/_agents/handoff/bulgu-havuzu.jsonl"
ONCE_SUM="$(cat "$ODA1/_agents/handoff/bulgu-havuzu.jsonl")"
# Sultan odayı açtı:
LAYIHA_FABRIKA_HOST=test-oda-1 bash "$FABRIKA" ac >/dev/null 2>&1
( cd "$ODA1" && bash "$KUR" ) >"$T/kur2.log" 2>&1
esit "G3 ikinci koşu rc=0" "0" "$?"
esit "G3 mevcut defter ÜZERİNE YAZILMADI" "$ONCE_SUM" "$(cat "$ODA1/_agents/handoff/bulgu-havuzu.jsonl")"
esit "G3 Sultan'ın açtığı oda yeniden KAPATILMADI" "0" \
  "$(if [ -e "$LAYIHA_FABRIKA_BAYRAK" ]; then echo 1; else echo 0; fi)"
( cd "$ODA1" && bash "$KUR" --kontrol ) >"$T/kur3.log" 2>&1
esit "G3 --kontrol rc=0" "0" "$?"
esit "G3 --kontrol hiçbir şey yazmadığını söyler" "1" \
  "$(grep -c 'hiçbir şey yazılmadı' "$T/kur3.log")"

echo
echo "=== G4 · uçtan uca: kurulan tezgâha gerçek bulgu yazılır, MUCİT onu görür ==="
printf '[{"baslik":"Kurulum sonrası ilk bulgu maddesi","detay":"d","kanit":"https://ör.nek/kanit"}]' > "$T/aday.json"
O4="$( cd "$ODA1" && bash "$KASIF" --girdi "$T/aday.json" 2>/dev/null )"
esit "G4 kasif-havuz-ekle rc=0" "0" "$?"
esit "G4 bir bulgu eklendi" "1" "$(jq -r '.eklenen' <<<"$O4" 2>/dev/null)"
esit "G4 satır kurulan tezgâha düştü" "2" \
  "$(wc -l < "$ODA1/_agents/handoff/bulgu-havuzu.jsonl" | tr -d ' ')"
echo '[]' > "$T/bos-kartlar.json"
O4B="$( cd "$ODA1" && bash "$MUCIT" suz --kartlar "$T/bos-kartlar.json" 2>/dev/null )"
esit "G4 MUCİT aynı tezgâhı okudu (aday sayısı)" "2" "$(jq -r '.uygun_sayi' <<<"$O4B" 2>/dev/null)"
esit "G4 kanon.json'da base BOŞ → ağ çağrısı yok" "" \
  "$(jq -r '.kart_kaynagi.base' "$ODA1/_agents/mucit/kanon.json" 2>/dev/null)"

echo
echo "=== G5 · yabancı yazma-hedefi reddedilir (SF1 değişmezi paket-içinde de geçerli) ==="
: > "$T/yabanci.jsonl"
( cd "$ODA1" && KASIF_HAVUZ="$T/yabanci.jsonl" bash "$KASIF" --girdi "$T/aday.json" ) >/dev/null 2>&1
esit "G5 kanonik-dışı hedef rc=2" "2" "$?"
esit "G5 yabancı dosyaya HİÇBİR ŞEY yazılmadı" "0" "$(wc -c < "$T/yabanci.jsonl" | tr -d ' ')"

echo
echo "=== G6 · İ1 NEGATİF TESTİ: git-siz dizinde ortak dizine SIZMA yok ==="
# Bu, K1'in tek gerçek kanıtı: eski sürüm burada \$HOME/.claude'a düşüyordu; \$HOME=/config ve
# /config/.claude 10 container'ın ORTAK dizini → tek yanlış çağrı bütün odaları birleştirirdi.
# Sızma-fotoğrafı: yalnız kökteki *.jsonl DEĞİL — bir tezgâh sızarsa `_agents/handoff/*.jsonl` olarak
# iner, o yüzden derinlik-4 tarıyoruz. (Mutasyon dersi: dar fotoğraf `liste` gibi salt-okur yollarda
# hiç kıpırdamıyor ve kapıyı boş gösteriyordu.)
ORTAK="${HOME:-/config}/.claude"
_ortak_foto() { find "$ORTAK" -maxdepth 4 \( -name '*.jsonl' -o -name '_agents' \) 2>/dev/null | sort; }
ONCE_LISTE="$(_ortak_foto)"
GITSIZ="$T/gitsiz"; mkdir -p "$GITSIZ"
( cd "$GITSIZ" && unset LAYIHA_ADAY_HAVUZ; bash "$KASIF" --girdi "$T/aday.json" ) >/dev/null 2>&1
esit "G6 KAŞİF git-siz dizinde rc=2" "2" "$?"
( cd "$GITSIZ" && bash "$PAKETLER/layiha-fabrikasi/scripts/layiha-aday-havuzu.sh" liste ) >/dev/null 2>&1
esit "G6 aday-havuzu git-siz dizinde rc=2" "2" "$?"
( cd "$GITSIZ" && bash "$MUCIT" suz --kartlar "$T/bos-kartlar.json" ) >/dev/null 2>&1
esit "G6 MUCİT git-siz dizinde rc=2" "2" "$?"
( cd "$GITSIZ" && bash "$KUR" ) >/dev/null 2>&1
esit "G6 kasif-kur git-siz dizinde rc=2" "2" "$?"
esit "G6 ORTAK DİZİNDE yeni defter/tezgâh OLUŞMADI" "$ONCE_LISTE" "$(_ortak_foto)"
esit "G6 git-siz dizinde de dosya bırakılmadı" "0" \
  "$(find "$GITSIZ" -type f 2>/dev/null | wc -l | tr -d ' ')"

echo
echo "=== G7 · bayrak kapsam-disiplini: kapalı oda üretmez, komşu oda üretir ==="
LAYIHA_FABRIKA_HOST=test-oda-1 bash "$FABRIKA" kapat --yerel --sebep "G7" >/dev/null 2>&1
O7A="$( cd "$ODA1" && LAYIHA_FABRIKA_HOST=test-oda-1 bash "$MUCIT" suz --profil layiha \
        --kartlar "$T/bos-kartlar.json" 2>/dev/null )"
esit "G7 kapalı odada layiha üretimi ATLANDI (çıktı yok)" "" "$O7A"
O7B="$( cd "$ODA1" && LAYIHA_FABRIKA_HOST=test-oda-2 bash "$MUCIT" suz --profil layiha \
        --kartlar "$T/bos-kartlar.json" 2>/dev/null )"
esit "G7 komşu oda ÜRETMEYE DEVAM ediyor" "layiha" "$(jq -r '.profil' <<<"$O7B" 2>/dev/null)"
O7C="$( cd "$ODA1" && LAYIHA_FABRIKA_HOST=test-oda-1 bash "$MUCIT" suz \
        --kartlar "$T/bos-kartlar.json" 2>/dev/null )"
esit "G7 kapalı odada bile DİVAN hattı çalışıyor (dar kapsam)" "divan" "$(jq -r '.profil' <<<"$O7C" 2>/dev/null)"

echo
echo "=== G8 · sürüm paritesi (saf bash — node/npm gerekmez) ==="
G8FAIL=0; G8SKIP=0
KATALOG="$PAKETLER/catalog.json"
for p in kasif-tara mucit-suz layiha-fabrikasi; do
  sv="$(grep -m1 '^version:' "$PAKETLER/$p/SKILL.md" 2>/dev/null | tr -d ' ' | cut -d: -f2)"
  if [ -z "$sv" ]; then echo "   SKILL.md'de version yok: $p"; G8FAIL=$((G8FAIL+1)); continue; fi
  if [ ! -r "$KATALOG" ]; then G8SKIP=$((G8SKIP+1)); continue; fi
  cv="$(jq -r --arg n "$p" '.skills[]? | select(.id==$n) | .version // empty' "$KATALOG" 2>/dev/null)"
  if [ "$sv" != "$cv" ]; then echo "   sürüm sapması $p: SKILL.md=$sv katalog=$cv"; G8FAIL=$((G8FAIL+1)); fi
done
esit "G8 SKILL.md ↔ catalog sürümleri uyumlu" "0" "$G8FAIL"
if [ "$G8SKIP" -gt 0 ]; then echo "      (kurulu düzende catalog.json yok — parite kontrolü atlandı: $G8SKIP)"; fi

echo
echo "════════ SONUÇ: PASS=$PASS · FAIL=$FAIL ════════"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
