#!/usr/bin/env bash
# olcum-disiplini.test.sh — HERMETİK. Gerçek hiçbir depoya/deftere dokunmaz.
set -uo pipefail

ARAC="$(cd "$(dirname "$0")" && pwd)/olcum-disiplini.sh"
GECEN=0; DUSEN=0
_ok(){ printf '  ✓ %s\n' "$1"; GECEN=$((GECEN+1)); }
_no(){ printf '  ✗ %s\n' "$1"; printf '      %s\n' "${2:-}"; DUSEN=$((DUSEN+1)); }
_bekle(){ if [[ "$2" == "$3" ]]; then _ok "$1"; else _no "$1" "beklenen rc=$2 gerçek rc=$3"; fi; }
_sil(){ [ -n "${1:-}" ] && [ -d "$1" ] && find "$1" -depth -delete 2>/dev/null; return 0; }
_rc(){ "$@" >/dev/null 2>&1; printf '%s' $?; }

# ── 1 · boru — bugünün İKİ GERÇEK VAKASI ─────────────────────────────────────
printf 'boru — çıkış kodu boru hattının arkasından okunuyor mu\n'
D="$(mktemp -d)"

cat > "$D/vaka-muavin.sh" <<'SH'
#!/usr/bin/env bash
KOK="$X" bash arac.sh denetle 2>&1 | tail -14
echo "exit=$?"
SH
_bekle "🔴 GERÇEK VAKA (MUAVİN): boru sonraki satırda \$? ile okunuyor" 1 "$(_rc bash "$ARAC" boru "$D/vaka-muavin.sh")"

cat > "$D/vaka-muhasip.sh" <<'SH'
#!/usr/bin/env bash
bash sinav.sh | tail -3 ; echo "rc=$?"
SH
_bekle "🔴 GERÇEK VAKA (MUHASİP): boru ve \$? aynı satırda" 1 "$(_rc bash "$ARAC" boru "$D/vaka-muhasip.sh")"

# ── yanlış-pozitif olmamalı ──
cat > "$D/temiz-pipefail.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
bash sinav.sh | tail -3
echo "rc=$?"
SH
_bekle "set -euo pipefail varsa temiz" 0 "$(_rc bash "$ARAC" boru "$D/temiz-pipefail.sh")"

cat > "$D/temiz-pipestatus.sh" <<'SH'
#!/usr/bin/env bash
bash sinav.sh | tail -3
echo "rc=${PIPESTATUS[0]}"
SH
_bekle "PIPESTATUS kullanılıyorsa temiz" 0 "$(_rc bash "$ARAC" boru "$D/temiz-pipestatus.sh")"

cat > "$D/temiz-ciplak.sh" <<'SH'
#!/usr/bin/env bash
bash sinav.sh > /tmp/l 2>&1
echo "rc=$?"
SH
_bekle "çıplak komut + \$? temiz" 0 "$(_rc bash "$ARAC" boru "$D/temiz-ciplak.sh")"

cat > "$D/temiz-veya.sh" <<'SH'
#!/usr/bin/env bash
komut_a || komut_b
echo "rc=$?"
SH
_bekle "|| boru sayılmaz" 0 "$(_rc bash "$ARAC" boru "$D/temiz-veya.sh")"

cat > "$D/temiz-tirnak.sh" <<'SH'
#!/usr/bin/env bash
echo "a|b"
echo "rc=$?"
SH
_bekle "tırnak içindeki | boru sayılmaz" 0 "$(_rc bash "$ARAC" boru "$D/temiz-tirnak.sh")"

# 🔴 GERÇEK-VERİ REGRESYONU: grep ile biten boru YARGIDIR, süsleme değil
cat > "$D/temiz-grep-yargi.sh" <<'SH'
#!/usr/bin/env bash
out="$(bash x.sh 2>&1)"
printf '%s' "$out" | grep -q 'DUMAN TESTİ DÜŞTÜ'
kapi "G2 duman testi sessiz" $?
SH
_bekle "🔴 grep ile biten boru YANLIŞ POZİTİF ÜRETMEZ (grep bir yargıdır)" 0 "$(_rc bash "$ARAC" boru "$D/temiz-grep-yargi.sh")"

cat > "$D/temiz-wc.sh" <<'SH'
#!/usr/bin/env bash
n="$(cat f | wc -l)"
echo "rc=$?"
SH
_bekle "wc ile biten boru işaretlenmez" 0 "$(_rc bash "$ARAC" boru "$D/temiz-wc.sh")"

# 🔴 ARACIN KENDİ KUSURUNUN REGRESYONU
cat > "$D/sahte-kalkan.sh" <<'SH'
#!/usr/bin/env bash
set -uo pipefail_yok
bash sinav.sh | tail -3
echo "rc=$?"
SH
_bekle "🔴 'pipefail_yok' KALKAN SAYILMAZ (alt-dizge değil KELİME sınırı)" 1 "$(_rc bash "$ARAC" boru "$D/sahte-kalkan.sh")"

_bekle "dizin taranır ve bulgu döner" 1 "$(_rc bash "$ARAC" boru "$D")"
_bekle "olmayan yol → kullanım hatası" 2 "$(_rc bash "$ARAC" boru "$D/yok.sh")"
_bekle "argümansız → kullanım hatası" 2 "$(_rc bash "$ARAC" boru)"
_sil "$D"

D2="$(mktemp -d)"; cat > "$D2/hepsi-temiz.sh" <<'SH'
#!/usr/bin/env bash
set -o pipefail
bash x.sh | tail -1
echo "$?"
SH
_bekle "tümü temiz dizin → 0" 0 "$(_rc bash "$ARAC" boru "$D2")"
_sil "$D2"

# ── 2 · negatif defteri ──────────────────────────────────────────────────────
printf 'negatif defteri — aynı negatifi ikinci kez ölçme\n'
W="$(mktemp -d)"; export OLCUM_DEFTERI="$W/.olcum/negatifler.jsonl"

_bekle "🔴 defter YOKKEN 'ölçülmedi' denmez → ÖLÇÜLEMEDİ (0 DEĞİL)" 3 "$(_rc bash "$ARAC" negatif sor --iddia "portalde XML yükleme ekranı var mı")"
_bekle "kanıtsız negatif yazılamaz" 2 "$(_rc bash "$ARAC" negatif yaz --iddia "x")"
_bekle "iddiasız sorgu → kullanım hatası" 2 "$(_rc bash "$ARAC" negatif sor)"

bash "$ARAC" negatif yaz --iddia "portalde XML yükleme ekranı var mı" \
     --kanit "üç aday ekran tek tek elendi, 2026-08-22" >/dev/null 2>&1
_bekle "yazıldıktan sonra aynı iddia → BULGU (daha önce ölçüldü)" 1 "$(_rc bash "$ARAC" negatif sor --iddia "portalde XML yükleme ekranı var mı")"
_bekle "kelimeleri karışık ama aynı iddia → yine yakalanır" 1 "$(_rc bash "$ARAC" negatif sor --iddia "XML yükleme ekranı portalde var mı")"
_bekle "ilgisiz iddia → 0 (ölçüm açılabilir)" 0 "$(_rc bash "$ARAC" negatif sor --iddia "kontör servisten sorgulanabiliyor mu")"

R="$(bash "$ARAC" negatif sor --iddia "portalde XML yükleme ekranı var mı" 2>&1)"
if grep -q 'üç aday ekran' <<<"$R"; then _ok "önceki ölçümün KANITI gösteriliyor"; else _no "önceki ölçümün KANITI gösteriliyor" "kanıt basılmadı"; fi

N1=$(wc -l < "$OLCUM_DEFTERI"); bash "$ARAC" negatif yaz --iddia "başka bir şey" --kanit "k" >/dev/null 2>&1
N2=$(wc -l < "$OLCUM_DEFTERI")
if [[ "$N2" -eq $((N1+1)) ]]; then _ok "defter append-only (satır eklendi, ezilmedi)"; else _no "defter append-only" "$N1 → $N2"; fi

# ── 3 · ölçüm kartı ──────────────────────────────────────────────────────────
printf 'ölçüm kartı — ölçümü KURMADAN önce beş soru\n'
_bekle "eksik kart → kullanım hatası (ümit kaydedilmez)" 2 "$(_rc bash "$ARAC" kart --hipotez "a" --degisken "b")"
_bekle "tam kart + defterde yok → 0" 0 "$(_rc bash "$ARAC" kart --hipotez "kontör servisten sorgulanabiliyor mu" --degisken "operasyon adı" --beklenen "69 operasyonda eşleşme" --gecersiz "WSDL bayatsa" --ortam "demo")"
_bekle "🔴 tam kart AMA daha önce ölçülmüş → BULGU (kart defteri KENDİ sorar)" 1 "$(_rc bash "$ARAC" kart --hipotez "portalde XML yükleme ekranı var mı" --degisken "ekran" --beklenen "yükleme alanı" --gecersiz "menü kırpılmışsa" --ortam "canlı")"

R="$(bash "$ARAC" kart --hipotez "kontör servisten sorgulanabiliyor mu" --degisken "op" --beklenen "e" --gecersiz "g" --ortam "demo" 2>&1)"
if grep -q 'geçersiz' <<<"$R" && grep -q 'ortam' <<<"$R"; then _ok "kart beş alanı da basıyor"; else _no "kart beş alanı da basıyor" "alan eksik"; fi
_sil "$W"; unset OLCUM_DEFTERI

# ── 4 · kullanım ─────────────────────────────────────────────────────────────
printf 'kullanım\n'
_bekle "bilinmeyen komut → 2" 2 "$(_rc bash "$ARAC" saklambac)"
_bekle "negatif alt-komutu eksik → 2" 2 "$(_rc bash "$ARAC" negatif)"

printf '\ntoplam=%d geçen=%d düşen=%d\n' "$((GECEN+DUSEN))" "$GECEN" "$DUSEN"
[[ $DUSEN -eq 0 ]]
