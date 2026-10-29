#!/usr/bin/env bash
# dongu-senaryo.sh <kanit.py> — QY2D senaryosu: döngü içindeki `X | tail -1 || exit 1` maskesi reddediliyor mu?
# Çıkış 0 = reddedildi (doğru) · 1 = kabul edildi, yeşil kayıt üretildi (hata).
set -u
KP="$1"; D="$(mktemp -d)"; trap 'python3 -c "import shutil,sys;shutil.rmtree(sys.argv[1],ignore_errors=True)" "$D"' EXIT
KANIT_DEPO="$D" python3 "$KP" olcum is-dongu dongu --asama tek -- bash -c 'for i in 1; do false | tail -1 || exit 1; done' >"$D/cikti" 2>&1; rc=$?
if [ "$rc" -eq 1 ]; then echo "✓ reddedildi (rc 1): $(grep -o 'BORU REDDİ: [^.]*' "$D/cikti" | head -1)"; exit 0; fi
echo "✗ kabul edildi (rc $rc) — döngüdeki boru maskesi görülmedi; kayıt rengi: $(python3 -c "import json,glob;m=glob.glob('$D/**/KANIT.json',recursive=True);print(json.load(open(m[0]))['kayitlar'][-1]['renk'] if m else '?')")"; exit 1
