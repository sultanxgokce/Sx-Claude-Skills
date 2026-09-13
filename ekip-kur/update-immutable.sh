#!/usr/bin/env bash
# ekip-kur immutable updater — yalnız salt-kod yüzeylerini doğrular/günceller.
set -euo pipefail

usage() {
  printf 'kullanım: %s <hedef-proje> [--check|--apply]\n' "${0##*/}" >&2
  exit 2
}

TARGET="${1:-}"
MODE="${2:---dry-run}"
[ -n "$TARGET" ] || usage
[ "$MODE" = "--dry-run" ] || [ "$MODE" = "--check" ] || [ "$MODE" = "--apply" ] || usage
[ $# -le 2 ] || usage
[ -d "$TARGET" ] || { printf 'HATA: hedef dizin yok: %s\n' "$TARGET" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { printf 'HATA: python3 yok\n' >&2; exit 2; }
command -v sha256sum >/dev/null 2>&1 || { printf 'HATA: sha256sum yok\n' >&2; exit 2; }

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$SELF_DIR/templates"
TARGET_INPUT="$(cd "$TARGET" && pwd)"
TARGET="$(git -C "$TARGET_INPUT" rev-parse --show-toplevel 2>/dev/null)" \
  || { printf 'HATA: hedef bir git worktree değil: %s\n' "$TARGET_INPUT" >&2; exit 2; }
[ "$TARGET_INPUT" = "$TARGET" ] \
  || { printf 'HATA: hedef proje kökü verilmeli: %s\n' "$TARGET" >&2; exit 2; }
COMMON_ROOT="$(python3 - "$TARGET" <<'PY'
import subprocess, sys
p = subprocess.run(["git", "-C", sys.argv[1], "worktree", "list", "--porcelain"], text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
if p.returncode:
    raise SystemExit(1)
blocks = [b.splitlines() for b in p.stdout.strip().split("\n\n") if b.strip()]
if not blocks or not blocks[0] or not blocks[0][0].startswith("worktree ") or "bare" in blocks[0]:
    raise SystemExit(1)
print(blocks[0][0][len("worktree "):])
PY
)" || { printf 'HATA: ana worktree çözülemedi\n' >&2; exit 2; }
LEDGER_PARENT="$COMMON_ROOT/_agents/handoff"
[ -d "$LEDGER_PARENT" ] \
  || { printf 'HATA: ortak ledger dizini yok: %s\n' "$LEDGER_PARENT" >&2; exit 2; }
ledger_probe="$(mktemp "$LEDGER_PARENT/.ekip-kur-write-test.XXXXXXXXXX")" \
  || { printf 'HATA: ortak ledger dizini yazılamaz: %s\n' "$LEDGER_PARENT" >&2; exit 2; }
rm -f "$ledger_probe"
FILES=(ekip-notify.sh ekip-preflight.lib.sh)
TRANSACTION="$TARGET/.ekip-kur-transaction"

hash_file() {
  if [ -f "$1" ]; then sha256sum "$1" | cut -d' ' -f1; else printf 'yok'; fi
}

recover_transaction() {
  [ -f "$TRANSACTION" ] || return 0
  backup="$(python3 - "$TRANSACTION" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
    value = data["backup"]
    if not isinstance(value, str) or not value:
        raise ValueError
    print(value)
except (OSError, KeyError, ValueError, json.JSONDecodeError):
    raise SystemExit(1)
PY
)" || { printf 'HATA: recovery marker bozuk: %s\n' "$TRANSACTION" >&2; return 1; }
  case "$backup" in "$TARGET/.ekip-kur-backups/"*) ;; *) printf 'HATA: recovery backup hedef dışında\n' >&2; return 1 ;; esac
  [ -d "$backup/scripts" ] || { printf 'HATA: recovery backup yok: %s\n' "$backup" >&2; return 1; }
  for name in "${FILES[@]}"; do
    if [ -f "$backup/scripts/$name" ]; then cp -p "$backup/scripts/$name" "$TARGET/scripts/$name"; else rm -f "$TARGET/scripts/$name"; fi
  done
  rm -f "$TRANSACTION"
  printf 'recovery=onarildi backup=%s\n' "$backup"
}

schema_check() {
  python3 - "$1" <<'PY'
import re, sys
p = sys.argv[1]
try:
    lines = open(p, encoding="utf-8").read().splitlines()
except (OSError, UnicodeError):
    raise SystemExit(1)
meta = {"ekip", "uye_sayisi", "yonetici", "yayin_kanali", "sinyal_defteri", "tetik_scripti", "guncelleme"}
seen_meta = set()
members = []
current = None
for line in lines:
    if re.match(r"^meta:\s*$", line):
        continue
    m = re.match(r"^\s{2}([a-z_]+):\s*(.*?)\s*(?:#.*)?$", line)
    if m and not members and m.group(1) in meta:
        if m.group(2) not in ("", '""', "''"):
            seen_meta.add(m.group(1))
    m = re.match(r"^\s*-\s*id:\s*(\S+)", line)
    if m:
        current = {"id"}
        members.append(current)
        continue
    m = re.match(r"^\s{4}(tmux|mod|rol|kanallar|inbox):\s*(.*?)\s*(?:#.*)?$", line)
    if m and current is not None and m.group(2) not in ("", '""', "''"):
        current.add(m.group(1))
required_member = {"id", "tmux", "mod", "rol", "kanallar", "inbox"}
ok = meta <= seen_meta and bool(members) and all(required_member <= member for member in members)
raise SystemExit(0 if ok else 1)
PY
}

worktree_contract_check() {
  grep -q 'worktree", "list", "--porcelain' "$TARGET/scripts/ekip-notify.sh" &&
    grep -q 'ana worktree çözülemedi' "$TARGET/scripts/ekip-notify.sh"
}

for name in "${FILES[@]}"; do
  [ -f "$SOURCE_DIR/$name" ] || { printf 'HATA: kanonik kaynak yok: %s\n' "$SOURCE_DIR/$name" >&2; exit 2; }
done
recover_transaction || exit 1

BROKEN=0
for name in "${FILES[@]}"; do
  src="$SOURCE_DIR/$name"
  dst="$TARGET/scripts/$name"
  source_hash="$(hash_file "$src")"
  installed_hash="$(hash_file "$dst")"
  mode="$(stat -c '%a' "$dst" 2>/dev/null || printf 'yok')"
  state=calisiyor
  [ "$source_hash" = "$installed_hash" ] && [ "$mode" = 755 ] || { state=kırık; BROKEN=1; }
  printf 'dosya=%s source_sha256=%s installed_sha256=%s mode=%s durum=%s\n' "$name" "$source_hash" "$installed_hash" "$mode" "$state"
done

REGISTRY="$TARGET/_agents/handoff/ekip-registry.yaml"
if schema_check "$REGISTRY"; then SCHEMA=uyumlu; else SCHEMA=kırık; BROKEN=1; fi
if worktree_contract_check; then WORKTREE=ortak; else WORKTREE=kırık; BROKEN=1; fi
printf 'schema=%s worktree_ledger=%s\n' "$SCHEMA" "$WORKTREE"

if [ "$MODE" = "--check" ]; then
  [ "$BROKEN" -eq 0 ] && { printf 'durum=calisiyor\n'; exit 0; }
  printf 'durum=kırık\n'
  exit 1
fi

if [ "$MODE" = "--dry-run" ]; then
  printf 'DRY-RUN: yalnız scripts/ekip-notify.sh ve scripts/ekip-preflight.lib.sh güncellenir; durum dosyaları korunur.\n'
  exit 0
fi

[ "$SCHEMA" = uyumlu ] \
  || { printf 'HATA: apply önkoşulları sağlanmadı; hiçbir dosya yazılmadı\n' >&2; exit 1; }

backup_root="$TARGET/.ekip-kur-backups"
mkdir -p "$backup_root" "$TARGET/scripts"
backup="$(mktemp -d "$backup_root/backup.XXXXXXXXXX")"
stage_dir="$(mktemp -d "$TARGET/scripts/.ekip-kur-stage.XXXXXXXXXX")"
rollback() {
  rc=$?
  trap - EXIT
  rollback_ok=1
  if [ "${installing:-0}" -eq 1 ]; then
    for name in "${FILES[@]}"; do
      if [ -f "$backup/scripts/$name" ]; then cp -p "$backup/scripts/$name" "$TARGET/scripts/$name" || rollback_ok=0
      else rm -f "$TARGET/scripts/$name" || rollback_ok=0; fi
    done
    [ "$rollback_ok" -eq 0 ] || rm -f "$TRANSACTION"
  fi
  rm -rf "$stage_dir"
  exit "$rc"
}
trap rollback EXIT
mkdir -p "$backup/scripts"
for name in "${FILES[@]}"; do
  src="$SOURCE_DIR/$name"
  dst="$TARGET/scripts/$name"
  [ ! -e "$dst" ] || cp -p "$dst" "$backup/scripts/$name"
  cp "$src" "$stage_dir/$name"
  chmod 755 "$stage_dir/$name"
  [ "$(hash_file "$stage_dir/$name")" = "$(hash_file "$src")" ] \
    || { printf 'HATA: staging hash uyuşmuyor: %s\n' "$name" >&2; exit 1; }
done
printf 'backup=%s\n' "$backup"
marker_stage="$(mktemp "$TARGET/.ekip-kur-transaction.XXXXXXXXXX")"
printf '{"backup":"%s"}\n' "$backup" > "$marker_stage"
mv -f "$marker_stage" "$TRANSACTION"

installing=1
for name in "${FILES[@]}"; do
  mv -f "$stage_dir/$name" "$TARGET/scripts/$name"
done
installing=0
rm -f "$TRANSACTION"
rm -rf "$stage_dir"
trap - EXIT
printf 'durum=calisiyor uygulandı=1 atomiklik=dosya-basina rollback=korumali\n'
