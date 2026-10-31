#!/usr/bin/env bash
# duzen-gece.test.sh — gece düzen kurulumu hermetik sınavı (sahte Sx + sahte kurulu kök + sahte sync/yenile/mektup; gerçek kutuya dokunmaz).
# G1 varsayılan KURU: hiçbir komut çalışmaz, günlük yazılmaz · G2 --uygula + kurulu eski: dört beceri kurulur (kuruldu satırları onceki/kutu/reis),
# bayat kimlik yenilenir (yenilendi satırı), reise mektup gider · G3 her şey güncel: hiçbir komut çalışmaz, mektup YOK, rc 0
# G4 sync reddederse atlandi satırı + rc 1 + "kuruldu" yazılmaz · G5 reis yoksa mektup tahminle yollanmaz (atlandi, rc 1)
# G6 kaynak sürüm okunamazsa rc 3 ÖLÇÜLEMEDİ · G7 bayat kimliğin temeli bilinmiyorsa yenile ÇAĞRILMAZ (atlandi) · G8 --force hiçbir komuta geçmez · G9 iki kutu reisine ayrı mektup · G10 düzen sürümü tetik (dördü de kurulur) · G11 bayat otonom kimlik --baz otonom-ajan ile yenilenir · G12 kurulum betiği yerinde değişse de çalışan kopya kayık okumaz
# mutant: kurulu=kaynak iken kurmaya kalkan kopya G3 kırmızı · reis yokken de mektup yollayan kopya G5 kırmızı · --force geçiren kopya G8 kırmızı · otonom temelini tanımayan kopya G11 kırmızı
set -uo pipefail
export LC_ALL=C.UTF-8
HERE="$(cd "$(dirname "$0")" && pwd)"; R="${GECE_BETIK:-$HERE/duzen-gece.sh}"
T="$(mktemp -d)"
temizle() { [ -d "$1" ] && { find "$1" -mindepth 1 -delete 2>/dev/null; rmdir "$1" 2>/dev/null; }; return 0; }
trap 'temizle "$T"; find "$HERE" -maxdepth 1 -name ".mutant-gece-$$-*" -delete 2>/dev/null' EXIT
G=0; K=0
ok() { if [ "$2" -eq 0 ]; then G=$((G+1)); echo "  ✓ $1"; else K=$((K+1)); echo "  ✗ $1 ${3:-}"; fi; }
BEC="duzen gunluk-plan mesveret bulgu"
skill() { mkdir -p "$1/$2"; printf -- '---\nname: %s\nversion: %s\n---\n' "$2" "$3" > "$1/$2/SKILL.md"; }
kaynak() { find "$T/sx" -mindepth 1 -delete 2>/dev/null; for b in $BEC; do skill "$T/sx" "$b" "$1"; done; }
kurulu() { find "$T/kur" -mindepth 1 -delete 2>/dev/null; mkdir -p "$T/kur"; for b in $BEC; do [ "$1" = yok ] || skill "$T/kur" "$b" "$1"; done; }
mkdir -p "$T/sx" "$T/kur"
cat > "$T/sync" <<'S'
#!/usr/bin/env bash
printf 'sync %s\n' "$*" >> "$KAYIT"; exit "${SYNC_RC:-0}"
S
cat > "$T/yenile" <<'S'
#!/usr/bin/env bash
printf 'yenile %s\n' "$*" >> "$KAYIT"; exit 0
S
cat > "$T/mektup" <<'S'
#!/usr/bin/env bash
printf 'mektup %s\n' "$*" >> "$KAYIT"; exit 0
S
export KAYIT="$T/kayit" DUZEN_SYNC_CMD="bash $T/sync" DUZEN_YENILE_CMD="bash $T/yenile" DUZEN_MEKTUP_CMD="bash $T/mektup" DUZEN_KURULU_KOK="$T/kur"
kimlik() {  # kimlik <depo> <ad> <gövde>
  mkdir -p "$1/_agents/$2"; local g="$3" h; h="$(printf '%s\n' "$g" | python3 -I -c 'import sys,hashlib; print(hashlib.sha256(sys.stdin.read().encode()).hexdigest())')"
  { printf '<!-- ekipc:uretilen:basla surum=1 hash=%s -->\n' "$h"; printf '%s\n' "$g"; printf '<!-- ekipc:uretilen:bitti -->\n\n## ELLE\nnot\n'; } > "$1/_agents/$2/AGENT.md"
}
BAYAT="$(printf '# ORTAK-TEMEL manuel (kaynak: _agents/ekip-os-base/manuel-claude-base.md)\nsatır bir\nESKİ satır\n')"
kimlik "$T/bayat" bani "$BAYAT"; mkdir -p "$T/bos"
kos() { : > "$KAYIT"; rm -f "$T/g.log"; bash "$R" --sx "$T/sx" --gunluk "$T/g.log" --kutu code "$@" 2>&1; }
cagri() { grep -c "^$1 " "$KAYIT"; }

kaynak 1.2.0; kurulu 1.1.1
O="$(kos --depo "$T/bayat" --reis SERDAR)"; rc=$?
ok "G1 varsayılan KURU: komut çalışmaz, günlük yazılmaz" "$([ $rc -eq 0 ] && [ ! -s "$KAYIT" ] && [ ! -e "$T/g.log" ] && grep -q '^KURU' <<<"$O" && echo 0 || echo 1)" "→ rc=$rc"

O="$(kos --uygula --depo "$T/bayat" --reis SERDAR)"; rc=$?
ok "G2 --uygula: dört beceri kurulur, bayat kimlik yenilenir, reise mektup gider" "$([ $rc -eq 0 ] && [ "$(cagri sync)" = 4 ] && [ "$(grep -c ' kuruldu ' "$T/g.log")" = 4 ] && grep -q 'kuruldu beceri=duzen surum=1.2.0 onceki=1.1.1 kutu=code reis=SERDAR' "$T/g.log" && grep -q 'yenilendi kimlik=bani temel=manuel-claude surum=1.2.0 kutu=code reis=SERDAR' "$T/g.log" && grep -q 'mektup reis=SERDAR surum=1.2.0 durum=gitti kutu=code' "$T/g.log" && [ "$(cagri mektup)" = 1 ] && grep -q -- '--baz manuel-claude' "$KAYIT" && echo 0 || echo 1)" "→ rc=$rc"

kaynak 1.2.0; kurulu 1.2.0
O="$(kos --uygula --depo "$T/bos" --reis SERDAR)"; rc=$?
ok "G3 her şey güncel: komut yok, mektup yok, rc 0" "$([ $rc -eq 0 ] && [ ! -s "$KAYIT" ] && ! grep -q 'kuruldu\|mektup' "$T/g.log" 2>/dev/null && echo 0 || echo 1)" "→ rc=$rc"

kurulu yok
export SYNC_RC=1; O="$(kos --uygula --depo "$T/bos" --reis SERDAR)"; rc=$?; unset SYNC_RC
ok "G4 sync reddeder: atlandi + rc 1, 'kuruldu' yazılmaz" "$([ $rc -eq 1 ] && grep -q 'atlandi beceri=duzen sebep=sync-reddetti' "$T/g.log" && ! grep -q ' kuruldu ' "$T/g.log" && echo 0 || echo 1)" "→ rc=$rc"

kurulu 1.1.1
O="$(kos --uygula --depo "$T/bos")"; rc=$?
ok "G5 reis yok: mektup tahminle yollanmaz (atlandi), rc 1" "$([ $rc -eq 1 ] && [ "$(cagri mektup)" = 0 ] && grep -q 'mektup reis=- .*durum=atlandi' "$T/g.log" && echo 0 || echo 1)" "→ rc=$rc"

kurulu 1.1.1
O="$(kos --uygula --depo "$T/bos" --reis code:SERDAR,mmex:BERİD)"; rc=$?
ok "G9 iki kutu reisi: her birine AYRI mektup satırı (kutu+reis), rc 0" "$([ $rc -eq 0 ] && [ "$(cagri mektup)" = 2 ] && grep -q 'mektup reis=SERDAR surum=1.2.0 durum=gitti kutu=code' "$T/g.log" && grep -q 'mektup reis=BERİD surum=1.2.0 durum=gitti kutu=mmex' "$T/g.log" && echo 0 || echo 1)" "→ rc=$rc"

kurulu 1.2.0; skill "$T/kur" duzen 1.1.1
O="$(kos --uygula --depo "$T/bos" --reis SERDAR)"; rc=$?
ok "G10 yalnız duzen sürümü eski: düzen artınca dördü de kurulur, mektup kurulan adları sayar" "$([ $rc -eq 0 ] && [ "$(cagri sync)" = 4 ] && grep -q 'kurulan beceriler: duzen gunluk-plan mesveret bulgu' "$KAYIT" && echo 0 || echo 1)" "→ rc=$rc"

O="$(bash "$R" --sx "$T/yok-sx" --gunluk "$T/g2.log" 2>&1)"; rc=$?
ok "G6 kaynak sürüm yok: rc 3 ÖLÇÜLEMEDİ" "$([ $rc -eq 3 ] && grep -q 'ÖLÇÜLEMEDİ' <<<"$O" && echo 0 || echo 1)" "→ rc=$rc"

kimlik "$T/tembel" bani "$(printf '# ORTAK-TEMEL manuel\nsatır bir\nESKİ\n')"
kurulu 1.2.0; O="$(kos --uygula --depo "$T/tembel" --reis SERDAR)"; rc=$?
ok "G7 temeli bilinmeyen bayat kimlik: yenile çağrılmaz (atlandi), rc 1" "$([ $rc -eq 1 ] && [ "$(cagri yenile)" = 0 ] && grep -q 'atlandi beceri=kimlik:bani sebep=temel-bilinmiyor' "$T/g.log" && echo 0 || echo 1)" "→ rc=$rc"

kimlik "$T/otonom" ares "$(printf '# ORTAK-TEMEL otonom (kaynak: _agents/ekip-os-base/otonom-ajan-base.md)\nESKİ otonom\n')"
kurulu 1.2.0; O="$(kos --uygula --depo "$T/otonom" --reis SERDAR)"; rc=$?
ok "G11 bayat otonom kimlik: yenile --baz otonom-ajan ile çağrılır, günlükte temel=otonom-ajan" "$([ $rc -eq 0 ] && [ "$(cagri yenile)" = 1 ] && grep -q -- '--baz otonom-ajan' "$KAYIT" && grep -q 'yenilendi kimlik=ares temel=otonom-ajan' "$T/g.log" && echo 0 || echo 1)" "→ rc=$rc"

# G12 kurulum betiği YERİNDE değiştirir (sync-skills copyFileSync gibi): çalışan kopya kayık okumaz, 2. ve 3. adım yine koşar
P12="$T/paket12"; mkdir -p "$P12"; cp -r "$HERE/../scripts" "$HERE/../cekirdek" "$P12/" 2>/dev/null; cp "$HERE/../SKILL.md" "$P12/" 2>/dev/null; cp "$R" "$P12/scripts/duzen-gece.sh"
cat > "$T/sync12" <<'S'
#!/usr/bin/env bash
printf 'sync %s\n' "$*" >> "$KAYIT"
python3 -I - "$P12_BETIK" <<'PY'
import sys; p=sys.argv[1]; b=open(p,'rb').read(); i=b.index(b'\n')+1
open(p,'r+b').write(b[:i]+b'# '+b'x'*300+b'\n'+b[i:])
PY
exit 0
S
kurulu 1.1.1; : > "$KAYIT"; rm -f "$T/g12.log"
O="$(P12_BETIK="$P12/scripts/duzen-gece.sh" DUZEN_SYNC_CMD="bash $T/sync12" bash "$P12/scripts/duzen-gece.sh" --sx "$T/sx" --gunluk "$T/g12.log" --kutu code --uygula --depo "$T/bayat" --reis SERDAR 2>&1)"; rc=$?
ok "G12 kurulum betiği yerinde değiştirse de çalışan kopya kayık okumaz: kurulum + yenileme + mektup satırları tamam" "$([ $rc -eq 0 ] && grep -q ' kuruldu ' "$T/g12.log" && grep -q 'yenilendi kimlik=bani' "$T/g12.log" && grep -q 'mektup reis=SERDAR' "$T/g12.log" && [ "$(wc -c < "$P12/scripts/duzen-gece.sh")" -gt "$(wc -c < "$R")" ] && echo 0 || echo 1)" "→ rc=$rc $(tail -2 <<<"$O")"

kurulu 1.1.1; O="$(kos --uygula --depo "$T/bayat" --reis SERDAR)"
ok "G8 hiçbir komuta --force geçmez" "$(! grep -q -- '--force' "$KAYIT" && echo 0 || echo 1)"

if [ -z "${GECE_BETIK:-}" ]; then
  echo "── mutasyon"
  mut() { local M="$HERE/.mutant-gece-$$-$1"; python3 -I - "$R" "$M" "$2" "$3" <<'PY' || { ok "mutant $1: desen tutmadı" 1; return; }
import sys; s=open(sys.argv[1],encoding='utf-8').read(); o=s; s=s.replace(sys.argv[3],sys.argv[4]); assert s!=o; open(sys.argv[2],'w',encoding='utf-8').write(s)
PY
    local o; o="$(GECE_BETIK="$M" bash "$0" 2>&1)"; ok "mutant '$1' → $4 kırmızı" "$(grep -q "✗ $4 " <<<"$o" && echo 0 || echo 1)" "→ $(grep -E '✗' <<<"$o" | head -2)"; }
  mut her-zaman-kur 'if [ "$ZORLA" -eq 1 ] || [ -z "$ku" ] || yeni_mi "$kv" "$ku"; then' 'if true; then' G3
  mut duzen-surumu-tetik-degil 'ZORLA=0; { [ -z "$dku" ] || yeni_mi "$dk" "$dku"; } && ZORLA=1' 'ZORLA=0' G10
  mut reissiz-mektup 'if [ -z "$REIS" ]; then yaz' 'if false; then yaz' G5
  mut otonom-temel-bilinmez 'otonom-ajan) arg=(--baz otonom-ajan); t=otonom-ajan ;; ' '' G11
  mut force-gecir '--skill "$b" --apply' '--skill "$b" --apply --force' G8
fi
echo "== $G geçti · $K düştü =="; [ "$K" -eq 0 ]
