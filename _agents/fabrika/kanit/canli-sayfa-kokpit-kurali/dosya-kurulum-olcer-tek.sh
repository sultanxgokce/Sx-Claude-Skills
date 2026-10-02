#!/usr/bin/env bash
# Birleşmemiş dalı ORTAK dizine değil geçici hedefe GERÇEKTEN kurar ve kurulu kopyayı ölçer
set -uo pipefail
W=/config/projects/_wt/Sx-Claude-Skills-canli-sayfa-kokpit-kurali
T=$(mktemp -d); R=$T/depo; H=$T/hedef; mkdir -p "$H"
cp -a "$W" "$R"; find "$R/.git" -delete 2>/dev/null || true
python3 -c "import json,sys;p=sys.argv[1];d=json.load(open(p));d['targets']['_global']=sys.argv[2];json.dump(d,open(p,'w'),ensure_ascii=False,indent=2)" "$R/sync-targets.json" "$H"
(cd "$R" && node sync-skills.mjs --skill canli-sayfa --apply 2>&1 | tail -2)
echo "kurulu-surum: $(grep -m1 -oE 'version: [0-9.]+' "$H/canli-sayfa/SKILL.md")"
echo "kurulu=kaynak: $(cmp -s "$H/canli-sayfa/SKILL.md" "$W/canli-sayfa/SKILL.md" && echo evet || echo HAYIR)"
echo "izin: $(stat -c %a "$H/canli-sayfa/scripts/canli-sayfa.sh")"
echo "calisiyor: $(bash "$H/canli-sayfa/scripts/canli-sayfa.sh" liste 2>/dev/null | tail -1)"
find "$T" -delete
