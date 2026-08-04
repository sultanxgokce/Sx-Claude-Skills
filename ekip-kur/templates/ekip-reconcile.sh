#!/usr/bin/env bash
# ekip-reconcile.sh — registry↔tmux GÜVENLİ-otomatik-uzlaştırma (ekibi-tazele adım A)
#   ekip-durum.sh yalnız "registry-bayat-olabilir" diye UYARIR; bu araç GÜVENLİ olanı DÜZELTİR:
#     • tmux-casing/rename self-heal (declared-session ölü ama normalize-edilmiş TEK canlı-aday var → tmux: alanını düzelt)
#     • meta.uye_sayisi gerçek-sayıyla uyumsuzsa düzelt
#     • meta.yonetici BOŞSA ilk-üyeye doldur (ASLA dolu-değeri ezmez)
#   Riskli/belirsiz olanı DÜZELTMEZ, BAYRAKLAR (insan-karar): ölü-oturum (aday yok/belirsiz) ·
#   registry-dışı canlı-oturum · duplike-id · meta.yonetici geçersiz-id.
# Kullanım: ekip-reconcile.sh [--dry-run]
# Çıktı: TAB-ayraçlı satırlar — FIX<TAB>tür<TAB>detay · FLAG<TAB>tür<TAB>detay · SUMMARY<TAB>fixed=N<TAB>flags=N
# Exit: 0=temiz(fix da flag da yok) · 1=flag-var(insan-bakmalı; fix olmuş-olmasın fark etmez) · 2=usage · 3=registry-yok/parse-hata
# Kaynak-desen: ekip-self-recognition.sh'in self-heal algoritması (aynı norm() kuralı) — burada STANDALONE/on-demand.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$SCRIPT_DIR")"
REGISTRY="${EKIP_REGISTRY:-$REPO_ROOT/_agents/handoff/ekip-registry.yaml}"

DRY=0
case "${1:-}" in
  --dry-run) DRY=1 ;;
  "") : ;;
  *) echo "usage: ekip-reconcile.sh [--dry-run]" >&2; exit 2 ;;
esac

[ -f "$REGISTRY" ] || { echo "HATA: registry yok: $REGISTRY" >&2; exit 3; }
command -v python3 >/dev/null 2>&1 || { echo "HATA: python3 kurulu değil (registry-parse için gerekir)" >&2; exit 3; }

LIVE="$(tmux ls -F '#{session_name}' 2>/dev/null || true)"

python3 - "$REGISTRY" "$DRY" "$LIVE" <<'PY'
import re, sys, os, datetime

reg_path, dry = sys.argv[1], sys.argv[2] == "1"
live = [s for s in sys.argv[3].splitlines() if s.strip()]
live_set = set(live)
now_iso = datetime.date.today().isoformat()

raw = open(reg_path, encoding="utf-8").read().splitlines(keepends=True)

def norm(s):  # ekip-self-recognition.sh ile AYNI kural — küçük-harf + baştaki rakam/tire soy
    return re.sub(r'^[0-9\-]+', '', s.strip().lower())

members, cur = [], None
in_members = False
meta_yon = None   # (idx, prefix, val, rest)
meta_n   = None   # (idx, prefix, val, rest)
meta_gun_idx = None
meta_gun_indent = ""

for i, line in enumerate(raw):
    if not in_members:
        m = re.match(r'^(\s*yonetici:\s*)(\S*)(.*)$', line.rstrip('\n'))
        if m:
            meta_yon = (i, m.group(1), m.group(2), m.group(3)); continue
        m = re.match(r'^(\s*uye_sayisi:\s*)(\S*)(.*)$', line.rstrip('\n'))
        if m:
            meta_n = (i, m.group(1), m.group(2), m.group(3)); continue
        m = re.match(r'^(\s*)guncelleme:', line)
        if m:
            meta_gun_idx, meta_gun_indent = i, m.group(1); continue
        if re.match(r'^\s*uyeler:\s*$', line):
            in_members = True; continue
        continue
    m = re.match(r'\s*-\s*id:\s*(\S+)', line)
    if m:
        if cur: members.append(cur)
        cur = {"id": m.group(1)}
        continue
    if cur is None:
        continue
    mt = re.match(r'(\s*tmux:\s*")([^"]*)(".*)', line)
    if mt:
        cur["tmux"] = mt.group(2); cur["tmux_idx"] = i
        cur["tmux_pre"] = mt.group(1); cur["tmux_post"] = mt.group(3)
if cur:
    members.append(cur)

fixes, flags = [], []
changed = False

def sep(pre):  # prefix zaten boşlukla bitmiyorsa tek-boşluk ekle (ör. "yonetici:" değer-öncesi boşluksuz olabilir)
    return "" if pre.endswith((" ", "\t")) else " "

# claim: declared-tmux zaten canlı olan üyeler o session'ı "kullanıyor" sayılır (self-heal aday-havuzundan düşer)
claimed = {m["tmux"].split(":")[0] for m in members if m.get("tmux") and m["tmux"].split(":")[0] in live_set}

for m in members:
    mid = m["id"]
    sess = m["tmux"].split(":")[0] if m.get("tmux") else ""
    if sess and sess in live_set:
        continue  # zaten canlı-geçerli, dokunma
    if "tmux_idx" not in m:
        flags.append(f"tmux-alani-parse-edilemedi\t{mid}\tsatır bulunamadı (registry biçimi beklenenden farklı olabilir)")
        continue
    cands = [s for s in live if s not in claimed and (s.lower() == mid.lower() or norm(s) == norm(mid))]
    if len(cands) == 1:
        newsess = cands[0]
        idx, pre, post = m["tmux_idx"], m["tmux_pre"], m["tmux_post"]
        old = m.get("tmux", "") or "(boş)"
        newval = f"{newsess}:0"
        raw[idx] = f'{pre}{newval}"   # {now_iso} ekibi-tazele self-heal (önceki: {old})\n'
        claimed.add(newsess)
        fixes.append(f"tmux-self-heal\t{mid}\t{old} -> {newval}")
        changed = True
    elif len(cands) > 1:
        flags.append(f"belirsiz-eslesme\t{mid}\t{len(cands)}-aday({','.join(cands)}) — elle-seç")
    else:
        flags.append(f"olu-oturum\t{mid}\tdeclared={m.get('tmux') or '?'} canlı-değil, otomatik-eşleşme-yok")

# registry-dışı canlı-oturumlar (üye tarafından iddia-edilmeyen tüm live sessionlar) — yalnız BAYRAK, ASLA otomatik-ekleme
for s in live:
    if s not in claimed:
        flags.append(f"registry-disi-oturum\t{s}\tcanlı ama registry'de hiçbir üyeye bağlı değil (yeni-üye mi, ilgisiz-oturum mu — kontrol-et)")

# duplike id
seen = {}
for m in members:
    seen[m["id"]] = seen.get(m["id"], 0) + 1
for mid, cnt in seen.items():
    if cnt > 1:
        flags.append(f"duplike-id\t{mid}\t{cnt}-kez-listelenmiş — elle-birleştir")

# meta.uye_sayisi
actual_n = len(members)
if meta_n is not None:
    idx, pre, val, rest = meta_n
    try:
        cur_n = int(val)
    except Exception:
        cur_n = None
    if cur_n != actual_n:
        raw[idx] = f"{pre}{sep(pre)}{actual_n}{rest}\n"
        fixes.append(f"uye-sayisi\tmeta.uye_sayisi\t{val or '?'} -> {actual_n}")
        changed = True

# meta.yonetici — YALNIZ boşsa ilk-üyeye doldur; dolu-değer ASLA ezilmez
if meta_yon is not None:
    idx, pre, val, rest = meta_yon
    if not val and members:
        ilk = members[0]["id"]
        raw[idx] = f"{pre}{sep(pre)}{ilk}{rest}\n"
        fixes.append(f"yonetici-doldur\tmeta.yonetici\t(boş) -> {ilk}")
        changed = True
    elif val and members and val.upper() not in {mm["id"].upper() for mm in members}:
        flags.append(f"yonetici-gecersiz\tmeta.yonetici\t'{val}' registry'de üye-id olarak bulunamadı — elle-düzelt")

if changed and meta_gun_idx is not None:
    raw[meta_gun_idx] = f'{meta_gun_indent}guncelleme: "{now_iso}"\n'

if changed and not dry:
    tmp = reg_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("".join(raw))
    os.replace(tmp, reg_path)

prefix_fix = "PREVIEW-FIX" if dry else "FIX"
for f in fixes:
    print(f"{prefix_fix}\t{f}")
for f in flags:
    print(f"FLAG\t{f}")
print(f"SUMMARY\tfixed={len(fixes)}\tflags={len(flags)}\tdry_run={'1' if dry else '0'}")

sys.exit(1 if flags else 0)
PY
