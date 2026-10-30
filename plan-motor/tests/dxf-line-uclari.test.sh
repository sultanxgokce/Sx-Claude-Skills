#!/usr/bin/env bash
# dxf-line-uclari.test.sh — LINE uçları `vertices` ile gelen DXF çökertmemeli.
#
# 🔴 NEDEN VAR (ölçüldü 2026-09-24): paketin KENDİ demo dosyası `demo/ornek-plan.dxf` üstünde
# `goster` rc=3 ile çöküyordu ("Cannot read properties of undefined (reading 'x')"). Sebep:
# bu dxf-parser sürümü LINE uçlarını `startPoint/endPoint` yerine `vertices` içinde veriyor.
# Gerçek müşteri dosyaları DWG yolundan girdiği için hata hiç görünmemişti — yani "çalışıyor"
# sanılan yol, tek bir DXF müşterisinde ilk adımda kırılacaktı.
set -uo pipefail
PAKET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PAKET" || exit 1
. tests/bagimlilik.sh   # dxf-parser ister; CI paralel koşar → kurulumu kendisi (kilitle) yapar
bagimlilik_kur || { echo "✗ npm bağımlılıkları kurulamadı"; exit 1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
G=0; K=0
ok() { G=$((G+1)); }
kir() { K=$((K+1)); printf '  ✗ %s\n' "$1"; }

# (1) Paketin kendi demo DXF'i çökmeden okunmalı
node cli.mjs goster --dosya demo/ornek-plan.dxf --cikar-json "$T/ham.json" --cikti "$T/plan.png" >"$T/o" 2>"$T/e"
rc=$?
[ "$rc" -eq 0 ] && ok || kir "demo/ornek-plan.dxf goster rc=$rc: $(tail -1 "$T/e")"
[ -s "$T/ham.json" ] && ok || kir "ölçüm girdisi yazılmadı"

# (2) LINE'lar sınıra girmiş olmalı (A-DOOR/A-GLAZ hatları) — sessizce düşmemeli
python3 - "$T/ham.json" <<'PY' && ok || kir "LINE segmentleri sınıra girmedi"
import json,sys
h=json.load(open(sys.argv[1]))
sys.exit(0 if len(h.get("sinir",[])) >= 10 else 1)
PY

# (3) MUTASYON: uçsuz LINE taşıyan DXF çökertmemeli, varlığı atlamalı
cat <<'DXF' > "$T/ucsuz.dxf"
0
SECTION
2
ENTITIES
0
LINE
8
A-WALL
0
ENDSEC
0
EOF
DXF
node cli.mjs goster --dosya "$T/ucsuz.dxf" --cikar-json "$T/h2.json" --cikti "$T/p2.png" >"$T/o2" 2>"$T/e2"
if grep -qiF "cannot read properties" "$T/e2"; then kir "uçsuz LINE hâlâ çökertiyor"; else ok; fi

printf 'dxf-line-uclari: gecen=%d kirik=%d\n' "$G" "$K"
[ "$K" -eq 0 ]
