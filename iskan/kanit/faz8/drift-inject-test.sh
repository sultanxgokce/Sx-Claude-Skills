#!/usr/bin/env bash
# drift-inject-test.sh — İSKÂN FAZ-8 G9: çift-kol drift-inject kanıtı (gözcü uyumuyor-kanıtı).
#
# NE: evergreen-parity P8-CONTAINER + P9-CFAPP kollarının GERÇEKTEN yakaladığını kasıtlı-drift'le
# kanıtlar. İKİ AYRI enjeksiyon, İKİ AYRI geçici kopyada (gerçek-repo'ya ASLA dokunulmaz):
#   (1) compose'dan container_name satırı sil            → P8-CONTAINER [DRIFT] olmalı
#   (2) provider-inventory access_apps'ten iskantest sil → P9-CFAPP     [DRIFT] olmalı
# AND-sözleşmesi: İKİSİ de ayrı-ayrı kırmızı (OR değil — tek-kol-canlı öbür-kol-SKIP-kör deliği
# kapanır). Baseline'da her iki kol [OK] olmalı (SKIP = false-green, burada da FAIL sayılır).
#
# Kaynak = cloudtop origin/main `git archive` (working-tree/bayat-checkout sızamaz; kör-tescil
# G6-G10 origin/main-okur sözleşmesiyle hizalı). Pre-merge öz-test: ISKAN_PARITY_REF=<dal>.
# rc=0 = "her iki gözcü de kanıtlanmış-yakalıyor + gerçek-repo değişmedi".
set -uo pipefail

REPO="${ISKAN_CLOUDTOP_REPO_DIR:-/config/projects/cloudtop}"
REF="${ISKAN_PARITY_REF:-origin/main}"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1"; }

echo "== drift-inject-test (İSKÂN FAZ-8 G9) · kaynak: $REPO @ $REF =="

if [ ! -e "$REPO/.git" ]; then
  echo "  FAIL - cloudtop-repo bulunamadı: $REPO"; exit 2
fi
git -C "$REPO" fetch -q origin main 2>/dev/null || true

# gerçek-repo dokunulmazlık-tanığı (ilgili 4 dosyanın md5'i önce/sonra)
tanik() {
  md5sum "$REPO/infra/docker-compose.server.yml" "$REPO/infra/provider-inventory.yaml" \
         "$REPO/infra/backup.sh" "$REPO/scripts/evergreen-parity.sh" 2>/dev/null
}
MD5_ONCE="$(tanik)"

T1="$(mktemp -d)"; T2="$(mktemp -d)"; T0="$(mktemp -d)"
trap 'rm -rf "$T0" "$T1" "$T2"' EXIT

kopya() { # <hedef-dizin> — REF'ten infra+scripts anlık-görüntüsü (repo-dışı, .git'siz)
  git -C "$REPO" archive "$REF" infra scripts | tar -x -C "$1"
}
parity() { # <kopya-dizin> — parity'yi kopyanın İÇİNDEN koşar; exit-kodu önemsenmez (report-only),
  # kol-durum satırları grep'lenir. TTY-dışı capture → renk-kodu yok (düz "[DURUM] KOL:" biçimi).
  (cd "$1" && bash scripts/evergreen-parity.sh 2>&1)
}

# ── 0 · BASELINE: temiz kopyada P8 ve P9 [OK] (SKIP/DRIFT/EKSIK = kol-ölü/kaynak-bozuk → FAIL) ─
kopya "$T0"
OUT0="$(parity "$T0")"
echo "$OUT0" | grep -q '^\[OK\] P8-CONTAINER' \
  && ok "baseline: P8-CONTAINER [OK] (kol canlı + manifest senkron)" \
  || { bad "baseline: P8-CONTAINER [OK] değil"; echo "$OUT0" | grep 'P8-CONTAINER' | sed 's/^/    | /'; }
echo "$OUT0" | grep -q '^\[OK\] P9-CFAPP' \
  && ok "baseline: P9-CFAPP [OK] (kol canlı + manifest senkron)" \
  || { bad "baseline: P9-CFAPP [OK] değil"; echo "$OUT0" | grep 'P9-CFAPP' | sed 's/^/    | /'; }

# ── 1 · ENJEKSİYON-1: compose'dan cloudtop-iskantest container-satırını sil → P8 DRIFT ────────
kopya "$T1"
sed -i '/container_name: cloudtop-iskantest/d' "$T1/infra/docker-compose.server.yml"
grep -q 'container_name: cloudtop-iskantest' "$T1/infra/docker-compose.server.yml" \
  && bad "enjeksiyon-1: satır silinemedi (test-düzeneği bozuk)" \
  || ok "enjeksiyon-1: geçici-kopyada compose'dan cloudtop-iskantest silindi"
OUT1="$(parity "$T1")"
echo "$OUT1" | grep -q '^\[DRIFT\] P8-CONTAINER' \
  && ok "P8-CONTAINER kasıtlı-drift'i YAKALADI ([DRIFT])" \
  || { bad "P8-CONTAINER drift'i YAKALAYAMADI (gözcü uyuyor)"; echo "$OUT1" | grep 'P8-CONTAINER' | sed 's/^/    | /'; }
echo "$OUT1" | grep -q 'cloudtop-iskantest' \
  && ok "P8 drift-mesajı düşen container'ı adlandırıyor (cloudtop-iskantest)" \
  || bad "P8 drift-mesajında cloudtop-iskantest yok"

# ── 2 · ENJEKSİYON-2: provider-inventory access_apps'ten iskantest-hostname sil → P9 DRIFT ────
kopya "$T2"
sed -i '/^    - iskantest\.mmepanel\.com/d' "$T2/infra/provider-inventory.yaml"
grep -q '^    - iskantest\.mmepanel\.com' "$T2/infra/provider-inventory.yaml" \
  && bad "enjeksiyon-2: satır silinemedi (test-düzeneği bozuk)" \
  || ok "enjeksiyon-2: geçici-kopyada access_apps'ten iskantest.mmepanel.com silindi"
OUT2="$(parity "$T2")"
echo "$OUT2" | grep -q '^\[DRIFT\] P9-CFAPP' \
  && ok "P9-CFAPP kasıtlı-drift'i YAKALADI ([DRIFT])" \
  || { bad "P9-CFAPP drift'i YAKALAYAMADI (gözcü uyuyor)"; echo "$OUT2" | grep 'P9-CFAPP' | sed 's/^/    | /'; }
echo "$OUT2" | grep -q '^\[OK\] P8-CONTAINER' \
  && ok "izolasyon: enjeksiyon-2'de P8-CONTAINER hâlâ [OK] (kollar bağımsız)" \
  || bad "izolasyon: enjeksiyon-2 P8'i de bozdu (kol-bağımsızlık kırık)"

# ── 3 · GERÇEK-REPO DEĞİŞMEDİ (dokunulmazlık-tanığı) ──────────────────────────────────────────
MD5_SONRA="$(tanik)"
[ "$MD5_ONCE" = "$MD5_SONRA" ] \
  && ok "gerçek-repo değişmedi (4 dosya md5 önce=sonra)" \
  || bad "gerçek-repo DEĞİŞTİ — enjeksiyon sızdı!"

echo "== ${PASS} geçti / ${FAIL} kaldı =="
[ "$FAIL" -eq 0 ]
