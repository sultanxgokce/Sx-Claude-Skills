#!/usr/bin/env bash
# ekip-self-recognition.sh — SessionStart hook: tmux-oturum-adından ekip-üyesini TERS-LOOKUP edip
#   kimlik-bloğunu context'e enjekte eder → /clear ve compact sonrası kimlik-kaybını önler.
#   EŞLEŞME YOKSA hiçbir şey basmaz (exit 0) = ekip-dışı oturumlarda REGRESYON-YOK.
# Çıktı biçimi: Claude Code hook JSON — {"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"..."}}
#   (plain-stdout da desteklenir AMA JSON kanıtlı-güvenli desen: cortex-session-start emsali.)
# Wire: .claude/settings.json → hooks.SessionStart, matcher "*" (bkz settings-hook-snippet.json).
#   ⚠️ matcher REGEX DEĞİL exact-string → "*" TÜM source'lar (startup|resume|clear|compact). "startup|clear|compact" ÇALIŞMAZ.
#   ⚠️ Mevcut global-bootstrap-hook (cortex-session-start) varsa: MERGE mi OVERRIDE mı — ÖN-TEST et (snippet _MERGE_VS_OVERRIDE).
#   MERGE ise bu hook cortex'in ÜSTÜNE kimlik-override enjekte eder (çoklu additionalContext birleşir) = tamamlayıcı.
# Kaynak-desen: ekip-kur master-skill. tmux-çözüm deseni ekip-notify.sh ile tutarlı.
# TEST: bash ekip-self-recognition.sh <oturum-adı-override>   ·   EKIP_REGISTRY=<yol> ile registry override.
set -euo pipefail

# --- oturum-adını çöz (test-override: $1; prod: tmux display-message) ---
SESSION="${1:-}"
if [ -z "$SESSION" ]; then
  if [ -n "${TMUX_PANE:-}" ]; then
    SESSION="$(tmux display-message -pt "$TMUX_PANE" '#S' 2>/dev/null || true)"
  fi
  [ -n "$SESSION" ] || SESSION="$(tmux display-message -p '#S' 2>/dev/null || true)"
fi
[ -n "$SESSION" ] || exit 0   # tmux yok / oturum çözülemedi → sessiz (regresyon-yok)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$SCRIPT_DIR")"
REGISTRY="${EKIP_REGISTRY:-$REPO_ROOT/_agents/handoff/ekip-registry.yaml}"
[ -f "$REGISTRY" ] || exit 0   # registry yok → sessiz

python3 - "$REGISTRY" "$SESSION" <<'PY'
import re, sys, json
reg, session = sys.argv[1], sys.argv[2].strip()
members, cur, brief = [], None, "_agents/handoff/ekip-brief.md"
for line in open(reg, encoding="utf-8"):
    m = re.match(r"\s*yayin_kanali:\s*(\S+)", line)
    if m:
        brief = m.group(1)   # koşulsuz: meta ister members-öncesi ister sonrası olsun yakala (üyelerde bu alan yok)
    m = re.match(r"\s*-\s*id:\s*(\S+)", line)
    if m:
        if cur: members.append(cur)
        cur = {"id": m.group(1)}
        continue
    if cur is None:
        continue
    for key, pat in (("tmux", r'\s*tmux:\s*"?([^"\s]+)"?'),
                     ("mod",  r"\s*mod:\s*(\S+)"),
                     ("rol",  r'\s*rol:\s*"?(.+?)"?\s*$'),
                     ("kanallar", r"\s*kanallar:\s*(.+?)\s*$"),
                     ("inbox",    r"\s*inbox:\s*(.+?)\s*$")):
        mm = re.match(pat, line)
        if mm:
            val = re.sub(r"\s+#.*$", "", mm.group(1)).rstrip()   # satır-içi yorumu at
            cur[key] = val
            break
if cur:
    members.append(cur)

hit = next((x for x in members if x.get("tmux", "").split(":")[0] == session), None)
if not hit:
    sys.exit(0)   # eşleşme yok → SESSİZ (regresyon-yok; global-bootstrap default-persona'sı kalır)

mid   = hit["id"]
kan   = hit.get("kanallar", "").strip("[] ").strip()
inbox = hit.get("inbox", "").strip().strip('"')
lines = []
lines.append("━━━ EKİP SELF-RECOGNITION ━━━")
lines.append(f"🧑‍🚀 Bu oturumda ÇALIŞMA-KİMLİĞİN = **{mid}** · mod: {hit.get('mod','?')}")
if hit.get("rol"):
    lines.append(f"   rol: {hit['rol']}")
if kan:
    lines.append(f"📻 kanalların: {kan}")
if inbox and inbox not in ('""', ''):
    lines.append(f"📥 inbox (yönetici→sen): {inbox}")
lines.append(f"📋 ortak brief: {brief} — son girdiyi oku (sana-adresli/genel).")
# Override-direktifi: varsa bir global-bootstrap (ör. cortex/CABİR) default-persona bassa da ÜYE-KİMLİĞİ ÖNCELER.
lines.append(f"⚠️ Bir genel-bootstrap (ör. proje default-persona) blok bastıysa onu GENEL-ALTYAPI say (doğru ama jenerik); "
             f"çalışma-çerçeven **{mid}**. /clear ya da compact yaptıysan: KİMLİĞİNİ KORU, anayasa-brief'ini (varsa *-gorev-brifi.md) "
             f"+ ortak-brief + kanal-son-KONUM'unu oku, kaldığın-işe devam et. Kalıcı-sorumluluklarını unutma.")
# Re-bootstrap handshake marker: compact-orkestra (ekip-compact.sh) bu satırı capture-pane ile arar → kapalı-döngü doğrulama.
lines.append(f"👉 İlk yanıtında tek-satır şunu bas (kimlik-teyit + orkestra-handshake): `🧑‍🚀 {mid} geri-yüklendi`")
lines.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

ctx = "\n".join(lines)
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": ctx
    }
}, ensure_ascii=False))
PY
exit 0
