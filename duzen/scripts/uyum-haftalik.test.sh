#!/usr/bin/env bash
# uyum-haftalik.test.sh — haftalık uyum denetimi hermetik sınavı (sahte surum.sh + sahte bulgu.sh; gerçek havuza/günlüğe dokunmaz).
# U1 sapma → rc 1, havuza 1 kayıt (bug), günlükte sapma=1 durum=sapma · U2 temiz → rc 0, havuza yazmaz, günlükte sapma=0
# U3 hiç kimlik işaretli değil + surum "güncel" der → SARI rc 4, havuza 1 kayıt (ozellik), "temiz" DENMEZ
# U4 surum ölçemedi (rc 3) → rc 3 olculemedi, "0 sapma" günlüğe temiz diye YAZILMAZ, havuza yazmaz
# U5 --kuru → ne havuz ne günlük · U6 havuz yazıcısı düşerse rc 5 (hüküm günlükte kalır) · U7 bilinmeyen seçenek rc 2
# U8 GERÇEK surum.sh + işaretsiz depo + eşit kurulu kopya → surum "güncel" rc 0 ama uyum SARI rc 4 (bugünkü açığın birebir sınavı)
# mutant: SARI'yı temiz sayan kopya U3 ve U8 kırmızı
set -uo pipefail
export LC_ALL=C.UTF-8
HERE="$(cd "$(dirname "$0")" && pwd)"; R="${UYUM_BETIK:-$HERE/uyum-haftalik.sh}"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null; find "$HERE" -maxdepth 1 -name ".mutant-uyum-$$-*" -delete 2>/dev/null' EXIT
G=0; K=0
ok() { if [ "$2" -eq 0 ]; then G=$((G+1)); echo "  ✓ $1"; else K=$((K+1)); echo "  ✗ $1 ${3:-}"; fi; }

sahte_surum() {  # sahte_surum <rc> <metin>
  printf '#!/usr/bin/env bash\nprintf "%%b\\n" %q\nexit %s\n' "$2" "$1" > "$T/surum.sh"
}
cat > "$T/bulgu.sh" <<'B'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${BULGU_KAYIT:?}"; exit "${BULGU_RC:-0}"
B
export BULGU_KAYIT="$T/bulgu.kayit"; export UYUM_SURUM_SH="$T/surum.sh"
kos() { : > "$BULGU_KAYIT"; rm -f "$T/gunluk"; bash "$R" --depo "$T/depo" --bulgu-sh "$T/bulgu.sh" --gunluk "$T/gunluk" "$@" 2>&1; }
mkdir -p "$T/depo"
n() { grep -c "^yaz " "$BULGU_KAYIT"; }

sahte_surum 1 'duzen · kaynak sürüm: 1.2.3\n  bani: BAYAT (gömülü eski)\n  ekipc işaretli 1 · işaretsiz 0\nSONUÇ: bayat/el-değmiş var'
O="$(kos)"; rc=$?
ok "U1 sapma → rc 1, havuza 1 bug kaydı, günlükte sapma=1 durum=sapma" "$([ $rc -eq 1 ] && [ "$(n)" = 1 ] && grep -q -- '--etiket bug' "$BULGU_KAYIT" && grep -q 'sapma=1 durum=sapma' "$T/gunluk" && echo 0 || echo 1)" "→ rc=$rc"

ok "U1b sapma kaydı bulgu komutuna '--kaynak uyum' ile gider (Kuzey G30 kaynak=uyum sayar)" "$(grep -q -- '--kaynak uyum' "$BULGU_KAYIT" && echo 0 || echo 1)" "→ $(cat "$BULGU_KAYIT")"
sahte_surum 0 'duzen · kaynak sürüm: 1.2.3\n  bani: GÜNCEL (manuel-claude-base birebir gömülü)\n  ekipc işaretli 2 · işaretsiz 0\nSONUÇ: güncel'
O="$(kos)"; rc=$?
ok "U2 temiz → rc 0, havuza yazmaz, günlükte sapma=0 durum=temiz" "$([ $rc -eq 0 ] && [ "$(n)" = 0 ] && grep -q 'sapma=0 durum=temiz' "$T/gunluk" && echo 0 || echo 1)" "→ rc=$rc"

sahte_surum 0 'duzen · kaynak sürüm: 1.2.3\n  kurulu: v1.2.3 GÜNCEL\n  ekipc işaretli 0 · işaretsiz 3\nSONUÇ: güncel'
O="$(kos)"; rc=$?
ok "U3 işaretli kimlik yok → SARI rc 4, havuza 1 ozellik kaydı, günlükte durum=sari (temiz değil)" "$([ $rc -eq 4 ] && [ "$(n)" = 1 ] && grep -q -- '--etiket ozellik' "$BULGU_KAYIT" && grep -q 'durum=sari' "$T/gunluk" && ! grep -q 'durum=temiz' "$T/gunluk" && echo 0 || echo 1)" "→ rc=$rc"

sahte_surum 3 'duzen · kaynak sürüm: 1.2.3\n  ÖLÇÜLEMEDİ: ne kurulu kopya ne ekipc işaretli AGENT.md bulundu'
O="$(kos)"; rc=$?
ok "U4 ölçülemedi → rc 3, havuza yazmaz, günlükte durum=olculemedi" "$([ $rc -eq 3 ] && [ "$(n)" = 0 ] && grep -q 'durum=olculemedi' "$T/gunluk" && echo 0 || echo 1)" "→ rc=$rc"

sahte_surum 1 'x\n  bani: EL-DEĞMİŞ\n  ekipc işaretli 1\nSONUÇ: bayat'
O="$(kos --kuru)"; rc=$?
ok "U5 --kuru: hüküm basar, ne havuza ne günlüğe yazar" "$([ $rc -eq 1 ] && [ "$(n)" = 0 ] && [ ! -e "$T/gunluk" ] && grep -q 'UYUM:' <<<"$O" && echo 0 || echo 1)" "→ rc=$rc"

export BULGU_RC=1; O="$(kos)"; rc=$?; unset BULGU_RC
ok "U6 havuz yazıcısı düşerse rc 5, hüküm günlükte kalır" "$([ $rc -eq 5 ] && grep -q 'sapma=1' "$T/gunluk" && echo 0 || echo 1)" "→ rc=$rc"

O="$(kos --yok)"; rc=$?
ok "U7 bilinmeyen seçenek rc 2" "$([ $rc -eq 2 ] && echo 0 || echo 1)" "→ rc=$rc"

unset UYUM_SURUM_SH
mkdir -p "$T/bos/_agents/x"; printf '# serbest\n' > "$T/bos/_agents/x/AGENT.md"
: > "$BULGU_KAYIT"; rm -f "$T/gunluk"
O="$(bash "$R" --depo "$T/bos" --kurulu "$HERE/.." --bulgu-sh "$T/bulgu.sh" --gunluk "$T/gunluk" 2>&1)"; rc=$?
S="$(bash "$HERE/surum.sh" denetle --depo "$T/bos" --kurulu "$HERE/.." >/dev/null 2>&1; echo $?)"
ok "U8 gerçek surum.sh işaretsiz depoda rc $S 'güncel' der; uyum SARI rc 4" "$([ "$S" = 0 ] && [ $rc -eq 4 ] && grep -q 'durum=sari' "$T/gunluk" && echo 0 || echo 1)" "→ rc=$rc surum=$S"

if [ -z "${UYUM_BETIK:-}" ]; then
  echo "── mutasyon"
  mut() { local M="$HERE/.mutant-uyum-$$-$1"; python3 -I - "$R" "$M" "$2" "$3" <<'PY' || { ok "mutant $1: desen tutmadı" 1; return; }
import sys; s=open(sys.argv[1],encoding='utf-8').read(); o=s; s=s.replace(sys.argv[3],sys.argv[4]); assert s!=o; open(sys.argv[2],'w',encoding='utf-8').write(s)
PY
    local o; o="$(UYUM_BETIK="$M" bash "$0" 2>&1)"; ok "mutant '$1' → $4 kırmızı" "$(grep -q "✗ $4 " <<<"$o" && echo 0 || echo 1)" "→ $(grep -E '✗' <<<"$o" | head -2)"; }
  mut kaynak-uyum-yazilmaz '--etiket "$ETIKET" --kaynak uyum --not' '--etiket "$ETIKET" --not' U1b
  mut sari-temiz-sayilir 'elif [ "$ISARETLI" -eq 0 ]; then DURUM=sari' 'elif false; then DURUM=sari' U3
  mut olculemedi-temiz 'if [ "$RC" -eq 3 ]; then DURUM=olculemedi; SAPMA=0' 'if false; then DURUM=olculemedi; SAPMA=0' U4
  mut havuza-yazmaz 'bash "$BULGU" yaz' 'true yaz' U1
fi
echo "== $G geçti · $K düştü =="; [ "$K" -eq 0 ]
