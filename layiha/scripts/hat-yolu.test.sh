#!/usr/bin/env bash
# hat-yolu.test.sh — hat-yolu.lib.sh golden + fail-closed kapıları (L24 F1).
#
# Kuzey-yıldızı: (G1-G3) Nexus ana-checkout'ta üretilen yollar BUGÜNKÜ yollarla BAYT-AYNI olmalı
# — yani bu kitaplık davranış değiştirmez, yalnız tek kapıya toplar. (G4-G6) worktree/hücre
# doğruluğu. (G7-G9) fail-closed: git yoksa yazma YOK, ortak-mount'a düşme YOK.
set -uo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hat-yolu.lib.sh"
NEXUS="${NEXUS_ROOT:-/config/projects/Nexus}"
PASS=0; FAIL=0
ok(){ printf '  ✓ %s\n' "$1"; PASS=$((PASS+1)); }
no(){ printf '  ✗ %s\n     beklenen: %s\n     gelen   : %s\n' "$1" "${2:-}" "${3:-}"; FAIL=$((FAIL+1)); }
esit(){ [ "$2" = "$3" ] && ok "$1" || no "$1" "$2" "$3"; }

# Alt-kabukta koş: source + cwd yalıtımı (test süreci kirlenmesin).
kos(){ # kos <cwd> <env-atamaları|-> <komut...>
  local cwd="$1" envs="$2"; shift 2
  ( cd "$cwd" 2>/dev/null || exit 9
    [ "$envs" = "-" ] || eval "export $envs"
    # shellcheck disable=SC1090
    source "$LIB" || exit 8
    "$@" ) 2>/dev/null
}
kos_rc(){ local cwd="$1" envs="$2"; shift 2
  ( cd "$cwd" 2>/dev/null || exit 9
    [ "$envs" = "-" ] || eval "export $envs"
    source "$LIB" || exit 8
    "$@" >/dev/null 2>&1 ) ; printf '%s' "$?"
}

echo "== G1: bare-source set -euo pipefail altında yan-etkisiz (exit 0) =="
( set -euo pipefail; source "$LIB" ) >/dev/null 2>&1
esit "bare-source exit kodu" "0" "$?"

echo "== G2: GOLDEN — bulgu-havuzu, hucre-baglam.lib.sh'in ürettiğiyle BAYT-AYNI =="
if [ -f "$NEXUS/scripts/hucre-baglam.lib.sh" ]; then
  beklenen="$( cd "$NEXUS" && ROOT="$NEXUS" bash -c 'source scripts/hucre-baglam.lib.sh; printf "%s" "$HB_BULGU_HAVUZU"' )"
  gelen="$(kos "$NEXUS" - hat_yolu bulgu-havuzu)"
  esit "hat_yolu bulgu-havuzu == HB_BULGU_HAVUZU" "$beklenen" "$gelen"
  beklenen2="$( cd "$NEXUS" && ROOT="$NEXUS" bash -c 'source scripts/hucre-baglam.lib.sh; printf "%s" "$HB_MUCIT_DEFTERI"' )"
  esit "hat_yolu mucit-defteri == HB_MUCIT_DEFTERI" "$beklenen2" "$(kos "$NEXUS" - hat_yolu mucit-defteri)"
  beklenen3="$( cd "$NEXUS" && ROOT="$NEXUS" bash -c 'source scripts/hucre-baglam.lib.sh; printf "%s" "$HB_HANDOFF_DIR"' )"
  esit "hat_yolu handoff-dir == HB_HANDOFF_DIR" "$beklenen3" "$(kos "$NEXUS" - hat_yolu handoff-dir)"
else
  echo "  ⊘ atlandı: $NEXUS/scripts/hucre-baglam.lib.sh yok (bu container Nexus'u görmüyor)"
fi

echo "== G3: GOLDEN — layiha-defteri, layiha-defteri.sh'in bugünkü çözümüyle aynı =="
if [ -d "$NEXUS/_agents/handoff" ]; then
  beklenen="$( cd "$NEXUS" && printf '%s/_agents/handoff/layiha-defteri.jsonl' "$(git rev-parse --show-toplevel)" )"
  esit "ana-checkout'ta show-toplevel ile aynı" "$beklenen" "$(kos "$NEXUS" - hat_yolu layiha-defteri)"
else
  echo "  ⊘ atlandı: $NEXUS/_agents/handoff yok"
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
git init -q "$TMP/repo" 2>/dev/null
( cd "$TMP/repo" && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m init )

echo "== G4: hücre-scope — CELL_ID=s02 ayrı alt-dizine düşer, s01/unset kökte kalır =="
esit "unset → kök"  "$TMP/repo/_agents/handoff/bulgu-havuzu.jsonl"                   "$(kos "$TMP/repo" - hat_yolu bulgu-havuzu)"
esit "s01  → kök"   "$TMP/repo/_agents/handoff/bulgu-havuzu.jsonl"                   "$(kos "$TMP/repo" 'CELL_ID=s01' hat_yolu bulgu-havuzu)"
esit "s02  → hücre" "$TMP/repo/_agents/hucreler/s02/_agents/handoff/bulgu-havuzu.jsonl" "$(kos "$TMP/repo" 'CELL_ID=s02' hat_yolu bulgu-havuzu)"

echo "== G5: WORKTREE-İMMÜNLÜK — worktree'den koşunca BİRİNCİL checkout'a çivilenir =="
( cd "$TMP/repo" && git worktree add -q "$TMP/wt" -b wt-dal 2>/dev/null )
if [ -d "$TMP/wt" ]; then
  esit "worktree'den → birincil kök" "$TMP/repo/_agents/handoff/layiha-defteri.jsonl" "$(kos "$TMP/wt" - hat_yolu layiha-defteri)"
  # kontrast: bugünkü hatalı davranış worktree kökünü verirdi
  yanlis="$TMP/wt/_agents/handoff/layiha-defteri.jsonl"
  [ "$(kos "$TMP/wt" - hat_yolu layiha-defteri)" != "$yanlis" ] \
    && ok "worktree kopyasına DÜŞMÜYOR (17-kopya split-brain panzehiri)" \
    || no "worktree kopyasına düştü" "≠ $yanlis" "$yanlis"
else
  echo "  ⊘ atlandı: worktree kurulamadı"
fi

echo "== G6: HAT_ROOT override her şeyi ezer (test/izole kancası) =="
esit "override kök" "/tmp/ozel/_agents/handoff/bulgu-havuzu.jsonl" "$(kos "$TMP/repo" 'HAT_ROOT=/tmp/ozel' hat_yolu bulgu-havuzu)"

echo "== G7: FAIL-CLOSED — git olmayan dizinde RC=2, çıktı YOK =="
mkdir -p "$TMP/gitsiz"
esit "hat_root RC" "2" "$(kos_rc "$TMP/gitsiz" - hat_root)"
esit "hat_yolu RC" "2" "$(kos_rc "$TMP/gitsiz" - hat_yolu bulgu-havuzu)"
cikti="$(kos "$TMP/gitsiz" - hat_yolu bulgu-havuzu)"
esit "stdout boş (yanlış yol sızmıyor)" "" "$cikti"
hata="$( cd "$TMP/gitsiz" && source "$LIB" && hat_yolu bulgu-havuzu 2>&1 >/dev/null; true )"
case "$hata" in *HAT_ROOT=*) ok "reçete basıldı (HAT_ROOT=... ipucu)";; *) no "reçete basılmadı" "HAT_ROOT=... içeren mesaj" "$hata";; esac

echo "== G8: İ1 NEGATİF-TESTİ — ortak mount'a hiçbir koşulda düşmüyor =="
onceki="$(ls -1 /config/.claude/*.jsonl 2>/dev/null | wc -l)"
sizinti=0
for cw in "$TMP/gitsiz" "$TMP/repo" "$HOME"; do
  for art in layiha-defteri bulgu-havuzu aday-havuzu mucit-defteri; do
    y="$(kos "$cw" - hat_yolu "$art")"
    case "$y" in
      /config/.claude/*) no "ORTAK MOUNT'A DÜŞTÜ (cwd=$cw art=$art)" "≠ /config/.claude/*" "$y"; sizinti=$((sizinti+1)) ;;
    esac
  done
done
# NOT: bu damga YALNIZ bu kapının kendi sayacına bakar — global FAIL'e bakmak, önceki bir kapı
# düştüğünde İ1 testini sessizce atlatır ("sessizlik = başarı" tuzağı).
[ "$sizinti" -eq 0 ] && ok "hiçbir cwd'de /config/.claude/* üretilmedi (gitsiz · repo · \$HOME · 12 kombinasyon)"
sonraki="$(ls -1 /config/.claude/*.jsonl 2>/dev/null | wc -l)"
esit "ortak dizinde yeni dosya oluşmadı" "$onceki" "$sonraki"

echo "== G9: bilinmeyen artefakt adı sessizce yanlış yol vermez =="
esit "bilinmeyen ad RC" "2" "$(kos_rc "$TMP/repo" - hat_yolu bu-yok)"
esit "argümansız RC"    "2" "$(kos_rc "$TMP/repo" - hat_yolu)"
esit "bilinmeyen ad stdout boş" "" "$(kos "$TMP/repo" - hat_yolu bu-yok)"

echo "== G10: hat_tani kökü ve kaynağını bildiriyor =="
t="$(kos "$TMP/repo" - hat_tani)"
case "$t" in *"$TMP/repo"*git-common-dir*) ok "tanı satırı doğru: $t";; *) no "tanı satırı" "kök + git-common-dir" "$t";; esac

printf '\n════════ SONUÇ: PASS=%d · FAIL=%d ════════\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
echo "GOLDEN: TEMİZ ✓"
