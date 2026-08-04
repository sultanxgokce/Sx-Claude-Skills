#!/usr/bin/env bash
# ekip-context-scan.sh — context-ağır-üye BEST-EFFORT tespiti (ekibi-tazele adım B, SALT-OKUR)
#   Kaynak-teknik: ekip-hooks/ctx-nudge.sh ile AYNI ölçüm (usage.input_tokens+cache_* / model-pencere-tahmini)
#   ama DIŞARIDAN: ctx-nudge her üyenin KENDİ PostToolUse-hook'unda içeriden ölçer; bu araç dışarıdan
#   ~/.claude/projects/<proje-slug>/*.jsonl transcript'lerini tarar (aynı-container'daki paylaşılan $HOME şart).
#   Kimlik-eşleme best-effort: ekip-self-recognition.sh'in enjekte ettiği "<MID> geri-yüklendi" marker'ını
#   transcript içinde arar — YOKSA o oturum mid'e eşlenmez (UNMAPPED, dürüstçe raporlanır, uydurulmaz).
# Kullanım: ekip-context-scan.sh [--pct N] [--max-age-min N]
#   --pct N          eşik-yüzde (default 75 — ctx-nudge.sh DANGER-eşiği 80'in az-altı, erken-görünürlük için)
#   --max-age-min N  yalnız son N dakikada değişen transcript'ler taranır (default 30 — kapalı/eski oturum gürültüsü elenir)
# Çıktı: TAB-satırları — HEAVY<TAB>mid<TAB>pct=N<TAB>model=…<TAB>yas=Ndk · OK<TAB>… · UNMAPPED<TAB>n<TAB>… · SUMMARY<TAB>…
# Exit: 0=ağır-yok (tespit-imkansız dahil — "unknown ≠ fail") · 1=en-az-1-ağır-üye · 2=usage/python3-yok
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$SCRIPT_DIR")"

PCT=75; MAXAGE=30
while [ $# -gt 0 ]; do
  case "$1" in
    --pct)          shift; PCT="${1:-75}" ;;
    --max-age-min)  shift; MAXAGE="${1:-30}" ;;
    *) echo "usage: ekip-context-scan.sh [--pct N] [--max-age-min N]" >&2; exit 2 ;;
  esac
  shift
done
[[ "$PCT" =~ ^[0-9]+$ ]] || { echo "usage: --pct sayısal olmalı" >&2; exit 2; }
[[ "$MAXAGE" =~ ^[0-9]+$ ]] || { echo "usage: --max-age-min sayısal olmalı" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || { echo "HATA: python3 kurulu değil" >&2; exit 2; }

# proje-slug: Claude Code'un kendi ~/.claude/projects/<slug> yerleşim-kuralı — cwd'deki '/' → '-'.
SLUG="$(printf '%s' "$REPO_ROOT" | tr '/' '-')"
PROJDIR="${EKIP_CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}/$SLUG"

if [ ! -d "$PROJDIR" ]; then
  printf 'INFO\ttespit-edilemedi\ttranscript-dizini-yok (best-effort — konteyner/proje-yolu farklı olabilir): %s\n' "$PROJDIR" >&2
  printf 'SUMMARY\theavy=0\tok=0\tunmapped=0\teşik=%%%s\tnot=dizin-yok\n' "$PCT"
  exit 0
fi

MAXAGE_SEC=$((MAXAGE * 60))
python3 - "$PROJDIR" "$MAXAGE_SEC" "$PCT" "${CTX_NUDGE_WINDOW:-}" <<'PY'
import re, sys, os, glob, time, json

proj_dir     = sys.argv[1]
max_age_sec  = int(sys.argv[2])
pct_threshold = int(sys.argv[3])
window_env   = sys.argv[4] if len(sys.argv) > 4 else ""

# ekip-self-recognition.sh enjeksiyonu: "🧑‍🚀 {mid} geri-yüklendi" — hem hook-metninde hem üyenin
# ilk-yanıt basmakla görevli olduğu satırda geçer. Sadece BÜYÜK-HARF registry-id-benzeri token kabul
# (yanlış-pozitif azaltma: sıradan cümledeki bir kelimeyi mid sanmasın).
MARKER_RE = re.compile(r'\b([A-Z][A-Z0-9_-]{1,30})\s+geri-yüklendi')

def default_window(model):
    m = (model or "").lower()
    if "fable" in m or "mythos" in m or "[1m]" in m:
        return 1000000
    if any(t in m for t in ("opus-4-8", "opus-4.8", "opus-4-7", "opus-4.7", "sonnet-5", "sonnet5")):
        return 500000
    return 200000

now = time.time()
files = glob.glob(os.path.join(proj_dir, "*.jsonl"))
results = []   # (mtime, mid_or_None, pct, model)

for path in files:
    try:
        st = os.stat(path)
    except OSError:
        continue
    if (now - st.st_mtime) > max_age_sec:
        continue

    mid = None
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            content = fh.read()
        matches = MARKER_RE.findall(content)
        if matches:
            mid = matches[-1]
    except Exception:
        pass

    ctx = None
    model = ""
    try:
        size = st.st_size
        with open(path, "rb") as f:
            if size > 262144:
                f.seek(size - 262144)
                f.readline()
            tail = f.read().decode("utf-8", errors="ignore").splitlines()
        for line in reversed(tail):
            if '"usage"' not in line:
                continue
            try:
                obj = json.loads(line)
                msgo = obj.get("message") or {}
                u = msgo.get("usage") or {}
                it = u.get("input_tokens")
                if it is None:
                    continue
                ctx = it + (u.get("cache_read_input_tokens") or 0) + (u.get("cache_creation_input_tokens") or 0)
                model = str(msgo.get("model") or "")
                break
            except Exception:
                continue
    except Exception:
        pass
    if ctx is None:
        continue

    try:
        window = int(window_env) if window_env else default_window(model)
        if window <= 0:
            window = default_window(model)
    except Exception:
        window = default_window(model)

    pct = round(100.0 * ctx / window)
    results.append((st.st_mtime, mid, pct, model))

# üye-başına yalnız EN-TAZE oturum (eski/kapalı session'lar stale-pct üretmesin)
best = {}
unmapped = 0
for mtime, mid, pct, model in results:
    if mid is None:
        unmapped += 1
        continue
    if mid not in best or mtime > best[mid][0]:
        best[mid] = (mtime, pct, model)

heavy, ok = [], []
for mid, (mtime, pct, model) in best.items():
    age_min = round((now - mtime) / 60)
    row = (mid, pct, model or "?", age_min)
    (heavy if pct >= pct_threshold else ok).append(row)

heavy.sort(key=lambda r: -r[1])
for mid, pct, model, age_min in heavy:
    print(f"HEAVY\t{mid}\tpct={pct}\tmodel={model}\tyas={age_min}dk")
for mid, pct, model, age_min in ok:
    print(f"OK\t{mid}\tpct={pct}\tmodel={model}\tyas={age_min}dk")
if unmapped:
    print(f"UNMAPPED\t{unmapped}\toturum(lar) mid'e eşlenemedi (best-effort — self-recognition marker bulunamadı)")
print(f"SUMMARY\theavy={len(heavy)}\tok={len(ok)}\tunmapped={unmapped}\teşik=%{pct_threshold}")
sys.exit(1 if heavy else 0)
PY
