#!/usr/bin/env bash
# ekip-kur · scaffold.sh — çok-ajan koordinasyon-substratını hedef-projeye İSKELETLER.
# İskeleti mekanik kurar; ajan sonra ekip-registry.yaml roster'ını gerçek üyelerle doldurur.
#   bash scaffold.sh <hedef-proje-dizini> [--force]
# Non-destructive: mevcut dosyanın üzerine YAZMAZ (--force'suz) — canlı-koordinasyon-sistemini ezme koruması.
# Kaynak-desen: erisim-skill-fabrikasi/scaffold.sh (Sx-Claude-Skills konvansiyonu).
set -euo pipefail

TARGET="${1:-}"
FORCE=0; [ "${2:-}" = "--force" ] && FORCE=1
[ -n "$TARGET" ] || { echo "kullanım: scaffold.sh <hedef-proje-dizini> [--force]   (ör: /config/projects/MMEx)" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "✗ hedef dizin yok: $TARGET" >&2; exit 1; }

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
TMPL="$SKILL_DIR/templates"
[ -d "$TMPL" ] || { echo "✗ templates dizini yok: $TMPL (ekip-kur klonlu mu?)" >&2; exit 1; }

TARGET="$(cd "$TARGET" && pwd)"

# put <src> <dst> — non-destructive kopya (mevcut varsa --force'suz atla)
put() {
  local src="$1" dst="$2" rel="${2#$TARGET/}"
  if [ -e "$dst" ] && [ "$FORCE" -ne 1 ]; then
    echo "  = atla (mevcut, --force yok): $rel"
    return 0
  fi
  install -d "$(dirname "$dst")"
  cp "$src" "$dst"
  echo "  + yazıldı: $rel"
}

echo "  ekip-kur scaffold → $TARGET$( [ "$FORCE" -eq 1 ] && echo '  [--force]' )"
install -d "$TARGET/scripts" "$TARGET/_agents/handoff" "$TARGET/.claude/skills"

put "$TMPL/ekip-notify.sh"          "$TARGET/scripts/ekip-notify.sh"
chmod +x "$TARGET/scripts/ekip-notify.sh" 2>/dev/null || true
put "$TMPL/ekip-preflight.lib.sh"   "$TARGET/scripts/ekip-preflight.lib.sh"
chmod +x "$TARGET/scripts/ekip-preflight.lib.sh" 2>/dev/null || true
put "$TMPL/ekip-durum.sh"           "$TARGET/scripts/ekip-durum.sh"
chmod +x "$TARGET/scripts/ekip-durum.sh" 2>/dev/null || true
put "$TMPL/ekip-self-recognition.sh" "$TARGET/scripts/ekip-self-recognition.sh"
chmod +x "$TARGET/scripts/ekip-self-recognition.sh" 2>/dev/null || true
put "$TMPL/ekip-hooks/ctx-nudge.sh" "$TARGET/scripts/ekip-hooks/ctx-nudge.sh"
chmod +x "$TARGET/scripts/ekip-hooks/ctx-nudge.sh" 2>/dev/null || true
put "$TMPL/ekip-registry.yaml.tmpl" "$TARGET/_agents/handoff/ekip-registry.yaml"
put "$TMPL/ekip-brief.md"           "$TARGET/_agents/handoff/ekip-brief.md"
for s in ekip-brief-ver ekip-brief-iste ajan-gorev durum; do
  put "$TMPL/skills/$s/SKILL.md"    "$TARGET/.claude/skills/$s/SKILL.md"
done
put "$TMPL/GO-LIVE-CHECKLIST.md"    "$TARGET/_agents/handoff/EKIP-GO-LIVE-CHECKLIST.md"
put "$TMPL/settings-hook-snippet.json" "$TARGET/_agents/handoff/EKIP-settings-hook-snippet.json"

echo
echo "✓ substrat iskeleti kuruldu."
echo "SONRAKİ (ajan):"
echo "  1. _agents/handoff/ekip-registry.yaml → örnek UYE1/UYE2'yi SİL, gerçek üyeleri yaz. meta.yonetici'yi DOLDUR (ZORUNLU: --done/--nudge hedefi)."
echo "     ⚠️ tmux CASING: her hedefi 'tmux ls' ile firsthand-teyit (yanlış-casing = sessiz ping-kaybı)."
echo "  2. HOOK wire: EKIP-settings-hook-snippet.json → .claude/settings.json hooks'a MERGE — 3 tip:"
echo "     SessionStart(kimlik) · Stop(ekip-durum.sh --nudge) · PostToolUse(ekip-hooks/ctx-nudge.sh)."
echo "     (mevcut hook'ları SİLME; cortex-session-start vb. genelde settings.local.json'da → rakip değil, ikisi de ateşler)."
echo "  3. _agents/handoff/EKIP-GO-LIVE-CHECKLIST.md duman-testini KOŞ (hedef-ortamda, ≥2 tmux-oturum)."
echo "     Ekstra: /durum → Sultan-dili özet · ekip-durum.sh --porcelain 6-alan-TAB basıyor mu?"
echo "  4. Tetik-skiller USER-ONLY: /ekip-brief-ver · /ekip-brief-iste · /ajan-gorev · /durum"
