#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPDATER="$ROOT/ekip-kur/update-immutable.sh"
TMP="$(mktemp -d)"
PASS=0
FAIL=0
trap 'rm -rf "$TMP"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok - %s\n' "$1"; }
not_ok() { FAIL=$((FAIL + 1)); printf 'not ok - %s\n' "$1" >&2; }
assert_eq() {
  local want="$1" got="$2" name="$3"
  if [ "$want" = "$got" ]; then ok "$name"; else not_ok "$name (want=$want got=$got)"; fi
}
assert_file_eq() {
  local left="$1" right="$2" name="$3"
  if cmp -s "$left" "$right"; then ok "$name"; else not_ok "$name"; fi
}
sha() { sha256sum "$1" | cut -d' ' -f1; }
run_rc() {
  local out="$1"; shift
  set +e
  "$@" >"$out" 2>&1
  RUN_RC=$?
  set -e
}

set -e
TARGET="$TMP/tenant"
mkdir -p "$TARGET/scripts" "$TARGET/_agents/handoff" "$TARGET/.claude"
printf 'old notify\n' > "$TARGET/scripts/ekip-notify.sh"
printf 'old preflight\n' > "$TARGET/scripts/ekip-preflight.lib.sh"
printf 'meta:\n  ekip: test\n  uye_sayisi: 1\n  yonetici: MUTEVELLI\n  yayin_kanali: _agents/handoff/ekip-brief.md\n  sinyal_defteri: _agents/handoff/ekip-sinyal.log\n  tetik_scripti: scripts/ekip-notify.sh\n  guncelleme: "2026-09-13"\nuyeler:\n  - id: MUTEVELLI\n    tmux: "MUTEVELLI:0"\n    mod: kod\n    rol: yonetici\n    kanallar: [ _agents/handoff/mutevelli.md ]\n    inbox: _agents/handoff/mutevelli-inbox.md\n' > "$TARGET/_agents/handoff/ekip-registry.yaml"
printf '# brief\nözel "satır"\n' > "$TARGET/_agents/handoff/ekip-brief.md"
printf 'eski|sinyal\n' > "$TARGET/_agents/handoff/ekip-sinyal.log"
printf '{"hooks":{"Stop":[]}}\n' > "$TARGET/.claude/settings.json"
printf 'ürün\n' > "$TARGET/product.txt"
chmod 600 "$TARGET/scripts/ekip-notify.sh" "$TARGET/scripts/ekip-preflight.lib.sh"
git init -q -b main "$TARGET"
git -C "$TARGET" config user.email test@example.invalid
git -C "$TARGET" config user.name test
git -C "$TARGET" add scripts _agents .claude product.txt
git -C "$TARGET" commit -qm init
STATE_BEFORE="$TMP/state.before"
sha "$TARGET/_agents/handoff/ekip-registry.yaml" > "$STATE_BEFORE"
sha "$TARGET/_agents/handoff/ekip-brief.md" >> "$STATE_BEFORE"
sha "$TARGET/_agents/handoff/ekip-sinyal.log" >> "$STATE_BEFORE"
sha "$TARGET/.claude/settings.json" >> "$STATE_BEFORE"
sha "$TARGET/product.txt" >> "$STATE_BEFORE"

mkdir -p "$TMP/non-git/scripts" "$TMP/non-git/_agents/handoff"
run_rc "$TMP/non-git.out" "$UPDATER" "$TMP/non-git" --apply
assert_eq 2 "$RUN_RC" "non-git apply fails closed"
git init -q --bare "$TMP/bare.git"
run_rc "$TMP/bare.out" "$UPDATER" "$TMP/bare.git" --check
assert_eq 2 "$RUN_RC" "bare repository fails closed"
chmod 500 "$TARGET/_agents/handoff"
run_rc "$TMP/unwritable.out" "$UPDATER" "$TARGET" --check
assert_eq 2 "$RUN_RC" "unwritable ledger parent fails closed"
chmod 755 "$TARGET/_agents/handoff"

run_rc "$TMP/dry.out" "$UPDATER" "$TARGET"
assert_eq 0 "$RUN_RC" "dry-run exits zero"
assert_eq "old notify" "$(tr -d '\n' < "$TARGET/scripts/ekip-notify.sh")" "dry-run does not mutate code"
if grep -q 'DRY-RUN' "$TMP/dry.out" && grep -q 'source_sha256=' "$TMP/dry.out" && grep -q 'installed_sha256=' "$TMP/dry.out"; then ok "dry-run reports source and installed hashes"; else not_ok "dry-run reports source and installed hashes"; fi

cp "$TARGET/_agents/handoff/ekip-registry.yaml" "$TMP/registry.before-precondition"
grep -v '^[[:space:]]*tmux:' "$TMP/registry.before-precondition" > "$TARGET/_agents/handoff/ekip-registry.yaml"
run_rc "$TMP/apply-precondition.out" "$UPDATER" "$TARGET" --apply
assert_eq 1 "$RUN_RC" "apply rejects broken registry precondition"
assert_eq "old notify" "$(tr -d '\n' < "$TARGET/scripts/ekip-notify.sh")" "failed apply precondition writes no notify bytes"
assert_eq "old preflight" "$(tr -d '\n' < "$TARGET/scripts/ekip-preflight.lib.sh")" "failed apply precondition writes no preflight bytes"
mv "$TMP/registry.before-precondition" "$TARGET/_agents/handoff/ekip-registry.yaml"

cat >> "$TARGET/_agents/handoff/ekip-registry.yaml" <<'YAML'
yardimcilar:
  - id: MUNECCIM
    sinif: arac
    tmux: "muneccim:0"
    kimlik: _agents/muneccim/AGENT.md
YAML
run_rc "$TMP/helper-schema.out" "$UPDATER" "$TARGET" --dry-run
assert_eq 0 "$RUN_RC" "registry helpers are not validated as team members"
cp "$TARGET/_agents/handoff/ekip-registry.yaml" "$TMP/registry.with-helper"
python3 - "$TARGET/_agents/handoff/ekip-registry.yaml" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read(); s=s.replace('    inbox: _agents/handoff/mutevelli-inbox.md\n', '')
open(p,'w').write(s)
PY
run_rc "$TMP/helper-broken-member.out" "$UPDATER" "$TARGET" --apply
assert_eq 1 "$RUN_RC" "broken real member remains fail closed when helpers exist"
mv "$TMP/registry.with-helper" "$TARGET/_agents/handoff/ekip-registry.yaml"
cp "$TARGET/_agents/handoff/ekip-registry.yaml" "$TMP/registry.with-helper"
python3 - "$TARGET/_agents/handoff/ekip-registry.yaml" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read(); s=s.replace('uye_sayisi: 1', 'uye_sayisi: 2')
open(p,'w').write(s)
PY
run_rc "$TMP/helper-count.out" "$UPDATER" "$TARGET" --apply
assert_eq 1 "$RUN_RC" "member count mismatch remains fail closed"
mv "$TMP/registry.with-helper" "$TARGET/_agents/handoff/ekip-registry.yaml"
sha "$TARGET/_agents/handoff/ekip-registry.yaml" > "$STATE_BEFORE"
sha "$TARGET/_agents/handoff/ekip-brief.md" >> "$STATE_BEFORE"
sha "$TARGET/_agents/handoff/ekip-sinyal.log" >> "$STATE_BEFORE"
sha "$TARGET/.claude/settings.json" >> "$STATE_BEFORE"
sha "$TARGET/product.txt" >> "$STATE_BEFORE"

run_rc "$TMP/apply.out" "$UPDATER" "$TARGET" --apply
assert_eq 0 "$RUN_RC" "apply exits zero"
assert_file_eq "$ROOT/ekip-kur/templates/ekip-notify.sh" "$TARGET/scripts/ekip-notify.sh" "apply installs canonical notify"
assert_file_eq "$ROOT/ekip-kur/templates/ekip-preflight.lib.sh" "$TARGET/scripts/ekip-preflight.lib.sh" "apply installs canonical preflight"
assert_eq 755 "$(stat -c '%a' "$TARGET/scripts/ekip-notify.sh")" "notify executable mode normalized"
assert_eq 755 "$(stat -c '%a' "$TARGET/scripts/ekip-preflight.lib.sh")" "preflight executable mode normalized"
STATE_AFTER="$TMP/state.after"
sha "$TARGET/_agents/handoff/ekip-registry.yaml" > "$STATE_AFTER"
sha "$TARGET/_agents/handoff/ekip-brief.md" >> "$STATE_AFTER"
sha "$TARGET/_agents/handoff/ekip-sinyal.log" >> "$STATE_AFTER"
sha "$TARGET/.claude/settings.json" >> "$STATE_AFTER"
sha "$TARGET/product.txt" >> "$STATE_AFTER"
assert_file_eq "$STATE_BEFORE" "$STATE_AFTER" "apply preserves registry brief signal settings and product state"
BACKUP="$(grep '^backup=' "$TMP/apply.out" | cut -d= -f2-)"
if [ -n "$BACKUP" ] && [ -f "$BACKUP/scripts/ekip-notify.sh" ] && [ -f "$BACKUP/scripts/ekip-preflight.lib.sh" ]; then ok "apply creates complete timestamped backup"; else not_ok "apply creates complete timestamped backup"; fi
assert_eq "old notify" "$(tr -d '\n' < "$BACKUP/scripts/ekip-notify.sh")" "backup contains pre-apply bytes"

printf 'transaction old notify\n' > "$TARGET/scripts/ekip-notify.sh"
printf 'transaction old preflight\n' > "$TARGET/scripts/ekip-preflight.lib.sh"
chmod 600 "$TARGET/scripts/ekip-notify.sh" "$TARGET/scripts/ekip-preflight.lib.sh"
mkdir -p "$TMP/failbin"
printf '#!/usr/bin/env bash\nfor arg in "$@"; do case "$arg" in *\/.ekip-kur-stage.*) n=$(cat "$MV_COUNT" 2>/dev/null || printf 0); n=$((n+1)); printf "%%s" "$n" > "$MV_COUNT"; [ "$n" -eq 2 ] && exit 1;; esac; done\nexec /bin/mv "$@"\n' > "$TMP/failbin/mv"
chmod +x "$TMP/failbin/mv"
: > "$TMP/mv.count"
run_rc "$TMP/transaction.out" env PATH="$TMP/failbin:$PATH" MV_COUNT="$TMP/mv.count" "$UPDATER" "$TARGET" --apply
assert_eq 1 "$RUN_RC" "second-file install failure exits nonzero"
assert_eq "transaction old notify" "$(tr -d '\n' < "$TARGET/scripts/ekip-notify.sh")" "transaction rollback restores first file"
assert_eq "transaction old preflight" "$(tr -d '\n' < "$TARGET/scripts/ekip-preflight.lib.sh")" "transaction rollback preserves second file"
if [ ! -e "$TARGET/.ekip-kur-transaction" ]; then ok "successful rollback clears transaction marker"; else not_ok "successful rollback clears transaction marker"; fi

run_rc "$TMP/pre-crash-apply.out" "$UPDATER" "$TARGET" --apply
assert_eq 0 "$RUN_RC" "pre-crash apply normalizes transaction fixture"
cp "$TARGET/scripts/ekip-notify.sh" "$TMP/crash.before-notify"
cp "$TARGET/scripts/ekip-preflight.lib.sh" "$TMP/crash.before-preflight"
mkdir -p "$TMP/killbin"
printf '#!/usr/bin/env bash\nfor arg in "$@"; do case "$arg" in *\/.ekip-kur-stage.*) n=$(cat "$MV_COUNT" 2>/dev/null || printf 0); n=$((n+1)); printf "%%s" "$n" > "$MV_COUNT"; [ "$n" -eq 2 ] && kill -KILL "$PPID";; esac; done\nexec /bin/mv "$@"\n' > "$TMP/killbin/mv"
chmod +x "$TMP/killbin/mv"
: > "$TMP/kill-mv.count"
run_rc "$TMP/crash.out" env PATH="$TMP/killbin:$PATH" MV_COUNT="$TMP/kill-mv.count" "$UPDATER" "$TARGET" --apply
assert_eq 137 "$RUN_RC" "SIGKILL between renames leaves interrupted apply"
if [ -f "$TARGET/.ekip-kur-transaction" ]; then ok "SIGKILL leaves durable recovery marker"; else not_ok "SIGKILL leaves durable recovery marker"; fi
run_rc "$TMP/recover.out" "$UPDATER" "$TARGET" --check
assert_eq 0 "$RUN_RC" "next check repairs interrupted transaction deterministically"
assert_file_eq "$TMP/crash.before-notify" "$TARGET/scripts/ekip-notify.sh" "crash recovery restores first file"
assert_file_eq "$TMP/crash.before-preflight" "$TARGET/scripts/ekip-preflight.lib.sh" "crash recovery restores second file"
if [ ! -e "$TARGET/.ekip-kur-transaction" ]; then ok "crash recovery clears marker"; else not_ok "crash recovery clears marker"; fi

run_rc "$TMP/apply-again.out" "$UPDATER" "$TARGET" --apply
assert_eq 0 "$RUN_RC" "second apply exits zero"
BACKUP_AGAIN="$(grep '^backup=' "$TMP/apply-again.out" | cut -d= -f2-)"
if [ "$BACKUP" != "$BACKUP_AGAIN" ] && [ -d "$BACKUP_AGAIN" ]; then ok "rapid backups use collision-free unique directories"; else not_ok "rapid backups use collision-free unique directories"; fi

run_rc "$TMP/check.out" "$UPDATER" "$TARGET" --check
assert_eq 0 "$RUN_RC" "check passes canonical hashes mode schema and worktree contract"
if grep -q 'durum=calisiyor' "$TMP/check.out" && grep -q 'schema=uyumlu' "$TMP/check.out" && grep -q 'worktree_ledger=ortak' "$TMP/check.out"; then ok "check reports normalized compatibility"; else not_ok "check reports normalized compatibility"; fi

printf '\n' >> "$TARGET/scripts/ekip-notify.sh"
run_rc "$TMP/mutant-notify.out" "$UPDATER" "$TARGET" --check
assert_eq 1 "$RUN_RC" "notify one-byte mutant is broken"
cp "$ROOT/ekip-kur/templates/ekip-notify.sh" "$TARGET/scripts/ekip-notify.sh"
chmod 755 "$TARGET/scripts/ekip-notify.sh"
printf '\n' >> "$TARGET/scripts/ekip-preflight.lib.sh"
run_rc "$TMP/mutant-preflight.out" "$UPDATER" "$TARGET" --check
assert_eq 1 "$RUN_RC" "preflight one-byte mutant is broken"
cp "$ROOT/ekip-kur/templates/ekip-preflight.lib.sh" "$TARGET/scripts/ekip-preflight.lib.sh"
chmod 755 "$TARGET/scripts/ekip-preflight.lib.sh"
cp "$TARGET/_agents/handoff/ekip-registry.yaml" "$TMP/registry.good"
grep -v '^[[:space:]]*tmux:' "$TMP/registry.good" > "$TARGET/_agents/handoff/ekip-registry.yaml"
run_rc "$TMP/schema.out" "$UPDATER" "$TARGET" --check
assert_eq 1 "$RUN_RC" "registry missing required member field is broken"
mv "$TMP/registry.good" "$TARGET/_agents/handoff/ekip-registry.yaml"
chmod 644 "$TARGET/scripts/ekip-notify.sh"
run_rc "$TMP/mode.out" "$UPDATER" "$TARGET" --check
assert_eq 1 "$RUN_RC" "non-executable immutable script is broken"
chmod 755 "$TARGET/scripts/ekip-notify.sh"

# Linked worktrees must append to the main checkout's shared ledger, never a worktree-local ledger.
GIT="$TMP/repo"
git init -q -b main "$GIT"
git -C "$GIT" config user.email test@example.invalid
git -C "$GIT" config user.name test
mkdir -p "$GIT/scripts" "$GIT/_agents/handoff" "$GIT/bin"
cp "$ROOT/ekip-kur/templates/ekip-notify.sh" "$GIT/scripts/ekip-notify.sh"
cp "$ROOT/ekip-kur/templates/ekip-preflight.lib.sh" "$GIT/scripts/ekip-preflight.lib.sh"
chmod 755 "$GIT/scripts/"*.sh
cp "$TARGET/_agents/handoff/ekip-registry.yaml" "$GIT/_agents/handoff/ekip-registry.yaml"
printf '#!/usr/bin/env bash\ncase "$1" in list-panes) exit 0;; list-sessions) printf "MUTEVELLI\\n";; has-session) exit 0;; capture-pane) printf "│ >\\n";; send-keys) exit 0;; esac\n' > "$GIT/bin/tmux"
chmod +x "$GIT/bin/tmux"
git -C "$GIT" add scripts _agents
GIT_AUTHOR_DATE='2020-01-01T00:00:00Z' GIT_COMMITTER_DATE='2020-01-01T00:00:00Z' git -C "$GIT" commit -qm init
git -C "$GIT" branch linked
git -C "$GIT" worktree add -q "$TMP/linked" linked
PATH="$GIT/bin:$PATH" VERIFY_WAIT=0 "$GIT/scripts/ekip-notify.sh" --done "main" >/dev/null 2>&1 || true
PATH="$GIT/bin:$PATH" VERIFY_WAIT=0 "$TMP/linked/scripts/ekip-notify.sh" --done "linked" >/dev/null 2>&1 || true
assert_eq 2 "$(awk -F'|' '$3=="done"{n++} END{print n+0}' "$GIT/_agents/handoff/ekip-sinyal.log")" "two linked worktrees append done signals to one common ledger"
if [ ! -e "$TMP/linked/_agents/handoff/ekip-sinyal.log" ]; then ok "linked worktree does not create a local ledger"; else not_ok "linked worktree does not create a local ledger"; fi

# A prefix-similar session must not satisfy or receive delivery for the exact registry session.
FAKE="$TMP/fake"
mkdir -p "$FAKE"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$TMUX_CALLS"\ncase "$1" in list-panes) exit 0;; list-sessions) printf "MUTEVELLI-CODEX\\n";; has-session) exit 0;; capture-pane) printf "│ >\\n";; send-keys) exit 0;; esac\n' > "$FAKE/tmux"
chmod +x "$FAKE/tmux"
: > "$TMP/tmux.calls"
run_rc "$TMP/exact.out" env PATH="$FAKE:$PATH" TMUX_CALLS="$TMP/tmux.calls" EKIP_REGISTRY="$TARGET/_agents/handoff/ekip-registry.yaml" EKIP_SINYAL_LOG="$TMP/exact.log" "$ROOT/ekip-kur/templates/ekip-notify.sh" MUTEVELLI mesaj
assert_eq 1 "$RUN_RC" "prefix-similar tmux session is treated as missing"
if ! grep -q '^send-keys ' "$TMP/tmux.calls"; then ok "prefix-similar tmux session receives no keys"; else not_ok "prefix-similar tmux session receives no keys"; fi

# Background ACK text without a visible submitted prompt must remain unverified under strict mode.
printf '#!/usr/bin/env bash\ncase "$1" in list-panes) exit 0;; list-sessions) printf "MUTEVELLI\\n";; capture-pane) printf "background ACK only\\n│ >\\n";; send-keys) exit 0;; esac\n' > "$FAKE/tmux"
chmod +x "$FAKE/tmux"
run_rc "$TMP/strict.out" env PATH="$FAKE:$PATH" VERIFY_WAIT=0 EKIP_REGISTRY="$TARGET/_agents/handoff/ekip-registry.yaml" EKIP_SINYAL_LOG="$TMP/strict.log" "$ROOT/ekip-kur/templates/ekip-notify.sh" --strict-ack MUTEVELLI mesaj
assert_eq 4 "$RUN_RC" "strict unverifiable delivery exits four"
run_rc "$TMP/strict-done.out" env PATH="$FAKE:$PATH" VERIFY_WAIT=0 EKIP_REGISTRY="$TARGET/_agents/handoff/ekip-registry.yaml" EKIP_SINYAL_LOG="$TMP/strict-done.log" "$ROOT/ekip-kur/templates/ekip-notify.sh" --strict-ack --done tamam
assert_eq 4 "$RUN_RC" "strict done unverifiable delivery exits four"
printf '#!/usr/bin/env bash\ncase "$1" in list-panes) exit 0;; list-sessions) printf "MUTEVELLI\\n";; capture-pane) printf "eski mesaj scrollback\\n│ >\\n";; send-keys) [ "${*: -1}" = Enter ] && exit 1; exit 0;; esac\n' > "$FAKE/tmux"
chmod +x "$FAKE/tmux"
run_rc "$TMP/strict-old.out" env PATH="$FAKE:$PATH" VERIFY_WAIT=0 EKIP_REGISTRY="$TARGET/_agents/handoff/ekip-registry.yaml" EKIP_SINYAL_LOG="$TMP/strict-old.log" "$ROOT/ekip-kur/templates/ekip-notify.sh" --strict-ack MUTEVELLI mesaj
assert_eq 4 "$RUN_RC" "old scrollback prefix plus Enter failure remains unverified"
run_rc "$TMP/strict-done-old.out" env PATH="$FAKE:$PATH" VERIFY_WAIT=0 EKIP_REGISTRY="$TARGET/_agents/handoff/ekip-registry.yaml" EKIP_SINYAL_LOG="$TMP/strict-done-old.log" "$ROOT/ekip-kur/templates/ekip-notify.sh" --strict-ack --done mesaj
assert_eq 4 "$RUN_RC" "strict done rejects old scrollback and Enter failure"

# README, catalog and skill frontmatter must advertise the same ekip-kur version.
README_VERSION="$(awk -F'|' '/\[ekip-kur\]/{gsub(/[[:space:]]/, "", $6); print $6; exit}' "$ROOT/README.md")"
SKILL_VERSION="$(awk '$1=="version:"{print $2; exit}' "$ROOT/ekip-kur/SKILL.md")"
read -r CATALOG_VERSION CATALOG_STATUS < <(python3 - "$ROOT/catalog.json" <<'PY'
import json, sys
for item in json.load(open(sys.argv[1], encoding="utf-8"))["skills"]:
    if item.get("id") == "ekip-kur":
        print(item["version"], item["status"])
        break
PY
)
README_STATUS="$(awk -F'|' '/\[ekip-kur\]/{gsub(/[[:space:]]/, "", $7); print $7; exit}' "$ROOT/README.md")"
assert_eq "$SKILL_VERSION" "$README_VERSION" "README version matches ekip-kur frontmatter"
assert_eq "$SKILL_VERSION" "$CATALOG_VERSION" "catalog version matches ekip-kur frontmatter"
assert_eq "$README_STATUS" "$CATALOG_STATUS" "catalog status matches README status"

printf 'tests=%s failures=%s\n' "$((PASS + FAIL))" "$FAIL"
[ "$FAIL" -eq 0 ]
