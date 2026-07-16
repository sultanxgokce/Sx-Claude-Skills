#!/usr/bin/env bash
# baslat-claude.sh — İSKÂN FAZ-6 başlatma-sarmalayıcısı (b0019'un sistemik cevabı).
#
# NEDEN: sid'siz-launcher görünmezliği (b0019) — bir rol claude'u elle/rastgele session-id'yle
# açarsa K3 rezerve-id disiplini kırılır (kurtarmada gerçek-resume imkânsızlaşır). Bu sarmalayıcı
# TEK meşru başlatma-yoludur: iskan-registry'den rol-kaydını (rezerve session-id + permission-mode)
# çözer ve claude'u HER ZAMAN o kimlikle başlatır.
#
# DÜRÜST-KIRMIZI SÖZLEŞMESİ: claude-binary yoksa sahte-yeşil BASMAZ — exit≠0 + ASCII-marker
# 'claude-binary yok' + kur-reçetesi (İSKÂN GEREKLILIK G9 sözleşmesi; marker locale/ı-i tuzağına bağışık).
#
# Kullanım: bash scripts/baslat-claude.sh <rol>
# Registry: default = <script-dizini>/../iskan-registry.yaml (container-içi co-locate kopya;
#           kanonik kaynak cloudtop origin/main infra/iskan-registry.yaml). ISKAN_REGISTRY ile override.
set -uo pipefail

ROL="${1:-}"
[ -n "$ROL" ] || { echo "kullanim: baslat-claude.sh <rol>" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REG="${ISKAN_REGISTRY:-$SCRIPT_DIR/../iskan-registry.yaml}"
[ -f "$REG" ] || { echo "[kirmizi] iskan-registry bulunamadi: $REG (once iskan.sh ekip-yerlestir --apply kosulmali)" >&2; exit 1; }

# rol-kaydı çözümü: line-based python3 (PyYAML gerektirmez — İSKÂN-container'larında python3 garanti)
KAYIT="$(python3 - "$REG" "$ROL" <<'PYEOF'
import re, sys
reg, rol = sys.argv[1], sys.argv[2]
cur = None
rec = {}
for ln in open(reg, encoding="utf-8"):
    m = re.match(r'\s*-\s*id:\s*(\S+)\s*$', ln)
    if m:
        cur = m.group(1)
        continue
    for key in ("session_id", "permission_mode"):
        m = re.match(r'\s*' + key + r':\s*"?([^"\s]+)"?\s*$', ln)
        if m and cur == rol:
            rec[key] = m.group(1)
sid = rec.get("session_id")
if sid and sid != "null":
    print(sid, rec.get("permission_mode", "default"))
PYEOF
)"

if [ -z "$KAYIT" ]; then
  echo "[kirmizi] rol-kayitsiz: '$ROL' — registry'de uye-kaydi/rezerve-session-id yok ($REG)" >&2
  exit 1
fi
SID="${KAYIT%% *}"
PMODE="${KAYIT##* }"

if ! command -v claude >/dev/null 2>&1; then
  echo "[kirmizi] claude-binary yok — bu container'da claude kurulu degil (mem-cap geregi canli-claude FAZ-9 kapsami; sahte-yesil basilmaz)."
  echo "kur-recetesi: (1) compose'ta mem_limit >= 2g (claude ~357-657MB RSS olculdu) (2) nvm+node kur (3) npm install -g @anthropic-ai/claude-code"
  echo "rol=$ROL rezerve-session-id=$SID permission-mode=$PMODE (kayit hazir — binary gelince AYNI komut calisir)"
  exit 1
fi

exec claude --session-id "$SID" --name "$ROL" --permission-mode "$PMODE"
