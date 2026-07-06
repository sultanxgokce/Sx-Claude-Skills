#!/usr/bin/env bash
# erisim-skill-fabrikasi · scaffold.sh — yeni bir <platform>-erisim skill'ini cloudflare-erisim'i
# ŞABLON alarak Sx-Claude-Skills reposunda iskeletler. İskeleti kurar; ajan reçeteye göre doldurur.
#   bash scaffold.sh <platform>            # ör: railway, github, google-cloud
# Ortam: SXSKILLS_DIR (varsayılan /config/projects/Sx-Claude-Skills)
set -euo pipefail

PLATFORM="${1:-}"
[ -n "$PLATFORM" ] || { echo "kullanım: scaffold.sh <platform>   (ör: railway, github, vercel)" >&2; exit 1; }
case "$PLATFORM" in *[!a-z0-9-]*) echo "✗ platform adı yalnız küçük-harf/rakam/tire olmalı: '$PLATFORM'" >&2; exit 1;; esac

REPO="${SXSKILLS_DIR:-/config/projects/Sx-Claude-Skills}"
TMPL="$REPO/cloudflare-erisim"
DEST="$REPO/${PLATFORM}-erisim"
[ -d "$TMPL" ] || { echo "✗ şablon yok: $TMPL (Sx-Claude-Skills klonlu mu? SXSKILLS_DIR doğru mu?)" >&2; exit 1; }
[ -e "$DEST" ] && { echo "⚠ zaten var: $DEST — üzerine yazmıyorum. Elle düzenle ya da sil." >&2; exit 2; }

install -d "$DEST/scripts" "$DEST/recipes" 2>/dev/null || install -d "$DEST/scripts"
# cf.sh'i BAŞLANGIÇ referansı olarak <platform>.sh'e kopyala (ajan API'yi reçeteye göre uyarlar).
cp "$TMPL/scripts/cf.sh" "$DEST/scripts/${PLATFORM}.sh"
chmod +x "$DEST/scripts/${PLATFORM}.sh"

# Placeholder'lı SKILL.md iskeleti.
cat > "$DEST/SKILL.md" <<EOF
---
name: ${PLATFORM}-erisim
type: agent
version: 1.0.0
description: >
  ${PLATFORM^} erişimi gereken işleri PANELE GİRMEDEN yapar. Kimlik yoksa bir-kerelik gizli giriş
  ister, dar-yetkili token'ı üretir/alır, cortex-access.env'e (600) kaydeder, sonra asıl işi yapar.
  İdempotent + sır-hijyenik. (erisim-skill-fabrikasi tarafından cloudflare-erisim şablonundan üretildi.)
install_target:
  skills: .claude/skills/
stacks: ["*"]
author: sultanxgokce
tags: [${PLATFORM}, erisim, platform-access, token, setup]
nexus_catalog: "AI Engineer Workbook > Skill Kataloğu"
---

# ${PLATFORM^} Erişim

> ⚠️ İSKELET — erisim-skill-fabrikasi \`recipes/${PLATFORM}.md\` reçetesine göre DOLDUR.
> Referans: ../cloudflare-erisim/SKILL.md (birebir kalıp).

## GERÇEK KISIT (dürüstçe söyle)
<recipe.honesty_constraint>

## Akış
1. \`doctor\` — kimlik var mı? Yeşil → Adım 4.
2. Bir-kerelik gizli giriş: <recipe.credential_intake>  → \`${PLATFORM}.sh login\` / \`set-token\`
3. Token üret/kaydet: <recipe.token_mint> · env: <recipe.env_var> · scope: <recipe.scopes>
4. Asıl iş (idempotent): <platforma özgü komutlar>
5. Doğrula: \`${PLATFORM}.sh doctor\` (yeşil). Sır YALNIZ cortex-access.env (600) + registry pointer.

## YASAK / dikkat
<recipe.forbidden>
EOF

echo "✓ iskelet kuruldu: $DEST"
echo "  · scripts/${PLATFORM}.sh  (cf.sh referansı — API'yi reçeteye göre uyarla)"
echo "  · SKILL.md               (placeholder'ları reçeteyle doldur)"
echo
echo "SONRAKİ (ajan):"
echo "  1. recipes/${PLATFORM}.md reçetesini oku (yoksa araştır+kaydet)."
echo "  2. scripts/${PLATFORM}.sh: load_creds/api/doctor/<iş> komutlarını platforma uyarla; forbidden'a uy."
echo "  3. SKILL.md placeholder'larını doldur."
echo "  4. catalog.json + sync-targets.json(install: ${PLATFORM}-erisim) + README tablosu güncelle."
echo "  5. node sync-skills.mjs --apply   (dağıt: _global + VPS)."
