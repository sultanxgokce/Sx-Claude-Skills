#!/usr/bin/env bash
# ekip-self-recognition.sh — SessionStart hook: tmux-oturum-adından ekip üyesini TERS-LOOKUP
#   edip kimlik-bloğunu context'e enjekte eder → /clear, compact ve model-switch sonrası kimlik-kaybını önler.
#   EŞLEŞME YOKSA hiçbir şey basmaz (exit 0) = ekip-dışı oturumlarda REGRESYON-YOK.
# Çıktı: Claude Code hook JSON — {"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"..."}}
# Wire: .claude/settings.json → hooks.SessionStart, matcher "*" (TÜM source: startup|resume|clear|compact).
#   ⚠️ matcher REGEX DEĞİL exact-string → "*" hepsini yakalar; "startup|clear|compact" alternation ÇALIŞMAZ (hiç ateşlemez).
#   Mevcut global bootstrap-hook (ör. cortex-session-start) RAKİP DEĞİL: MERGE → ikisi de ateşler, additionalContext'ler birleşir.
#   Bu hook onun ÜSTÜNE üye-kimlik-override enjekte eder (override-direktifiyle üye-çerçevesi genel-default'unu önceler).
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
command -v python3 >/dev/null 2>&1 || exit 0   # python3 yoksa sessiz (hook akışını bozma)

python3 - "$REGISTRY" "$SESSION" <<'PY'
import re, sys, json, os
reg, session = sys.argv[1], sys.argv[2].strip()
raw = open(reg, encoding="utf-8").read().splitlines(keepends=True)
members, cur, brief = [], None, "_agents/handoff/ekip-brief.md"
tmux_idx = {}   # id -> (satır-index, tmux-değer-öncesi-prefix, tmux-değer-sonrası-suffix) — self-heal yazımı için
for i, line in enumerate(raw):
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
    mt = re.match(r'(\s*tmux:\s*")([^"]*)(".*)', line)   # self-heal için prefix/suffix'i sakla
    if mt:
        cur["tmux"] = mt.group(2)
        tmux_idx[cur["id"]] = (i, mt.group(1), mt.group(3))
        continue
    for key, pat in (("mod",  r"\s*mod:\s*(\S+)"),
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

def norm(s):  # küçük-harf + baştaki rakam/tire soy ("3-Uye"→"uye", "altUye"→"altuye")
    return re.sub(r'^[0-9\-]+', '', s.strip().lower())

# 1) EXACT tmux-session eşleşmesi (steady-state hızlı-yol)
hit = next((x for x in members if x.get("tmux", "").split(":")[0] == session), None)
# 2) NORMALIZE-FALLBACK + best-effort SELF-HEAL: restart'ta session yeniden-adlandı (cc-uuid→rol) → rol-adıyla eşleştir.
#    Kimliği yine bul (genel-default'a düşme) VE registry'nin tmux-hedefini bu-oturuma güncelle (notify/durum için).
if not hit:
    hit = next((x for x in members if x["id"].lower() == norm(session)), None)
    if hit and hit["id"] in tmux_idx:
        idx, pre, post = tmux_idx[hit["id"]]
        new_t = session + ":0"
        if hit.get("tmux") != new_t:
            try:
                import datetime
                stamp = datetime.date.today().isoformat()
                raw[idx] = f'{pre}{new_t}"   # {stamp} self-heal (SessionStart: {session}; önceki {hit.get("tmux","?")})\n'
                tmp = reg + ".tmp"
                with open(tmp, "w", encoding="utf-8") as f: f.write("".join(raw))
                os.replace(tmp, reg)   # atomik: kısmi-yazım yok
            except Exception:
                pass   # ⚠️ yazım-fail kimlik-enjeksiyonunu ASLA bozmaz (best-effort); global düzeltme = manuel tmux↔registry reconcile
if not hit:
    sys.exit(0)   # eşleşme yok (ekip-dışı oturum) → SESSİZ (regresyon-yok; global bootstrap/default-persona kalır)

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
# Override-direktifi: global bootstrap default-persona bassa da ÜYE-KİMLİĞİ ÖNCELER.
lines.append(f"⚠️ Bir genel-bootstrap (ör. genel-bootstrap default-persona) blok bastıysa onu GENEL-ALTYAPI say (doğru ama jenerik); "
             f"çalışma-çerçeven **{mid}**. /clear ya da compact/model-switch yaptıysan: KİMLİĞİNİ KORU, anayasa-brief'ini "
             f"(varsa *-gorev-brifi.md) + ortak-brief + kanal-son-KONUM'unu oku, kaldığın-işe devam et. Kalıcı-sorumluluklarını unutma.")
# Re-bootstrap handshake marker: uzaktan-compact orkestrası bu satırı capture-pane ile arar → kapalı-döngü doğrulama.
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
