#!/usr/bin/env bash
# cokus-senaryo.sh <kanit.py> — gorev-klasor-merkez emsali: mutant betiği yığın iziyle çöker (rc 1, düşen kapı satırı yok).
# Beklenen (düzeltme sonrası): mutasyon kaydı SARI, araç rc 3. Eski araçta YEŞİL "YAKALADI" yazıyordu (hata). Çıkış: sari ise 0, değilse 1.
set -u; PY="$1"; D="$(mktemp -d)"; ( cd "$D" && git init -q -b main ) >/dev/null 2>&1
export KANIT_DEPO="$D" KANIT_SIRA=0
python3 "$PY" olcum is-cokus gercek --asama tek -- bash -c 'echo "  ✓ KS1 klasör taşınmaz"; exit 0' >/dev/null 2>&1
python3 "$PY" olcum is-cokus mutant-cokus --asama tek --mutasyon gercek -- bash -c 'echo "Traceback (most recent call last):"; echo "  File \"gecit.test.mjs\""; echo "Error: ENOENT: no such file or directory, open ../docker-compose.defter.yml" >&2; exit 1'; rc=$?
renk="$(python3 -c "import json,sys;k=json.load(open(sys.argv[1]))['kayitlar'][-1];print(k['renk'], 'dusen_kapi=%s'%k.get('dusen_kapi'))" "$D/_agents/fabrika/kanit/is-cokus/KANIT.json")"
echo "SONUÇ: arac_rc=$rc renk=$renk"; echo "BAŞLIK: $(head -1 "$D/_agents/fabrika/kanit/is-cokus/olcum-mutant-cokus-tek.txt")"
find "$D" -mindepth 1 -delete 2>/dev/null; rmdir "$D" 2>/dev/null
if [ "${renk%% *}" = "sari" ] && [ "$rc" -eq 3 ]; then echo "  ✓ çöken mutant SARI"; exit 0; fi
echo "  ✗ çöken mutant SARI değil (renk=${renk%% *} arac_rc=$rc) — rc≠0 yakalandı sayıldı"; exit 1
