#!/usr/bin/env bash
# D1 içerik probu: biçimi doğru ama 'ertele' kararı taşımayan damga ertelemeye izin veriyor mu?
# Hermetik: çıpa geçici dizinde (cipa.test.sh ile aynı üç değişken); gerçek çıpaya dokunmaz.
W="$1"; T=$(mktemp -d "$(dirname "$0")/prob.XXXX")
export GUNLUK_PLAN_CIPA_DIZ="$T/cipa" GUNLUK_PLAN_TARIH="2026-01-02" GUNLUK_PLAN_AJAN="prob"
A="$W/gunluk-plan/scripts/cipa.sh"
C=$(bash "$A" yol); case "$C" in "$T"/*) ;; *) echo "DUR: çıpa yolu geçici dizinde değil ($C)"; exit 9;; esac
for v in "2026-01-02 Sultan: bugün görüşelim (sohbet · s1 · \"bugün görüşelim\" · beyan:MUAVIN)" \
         "2026-01-02 Sultan: ertele (sohbet · s1 · \"yarına ertele\" · beyan:MUAVIN)" \
         "2026-01-02 Sultan: yarına ertelensin (sohbet · s1 · \"yarına kalsın\" · beyan:MUAVIN)"; do
  bash "$A" yaz --plan "1) bir | 2) iki" >/dev/null 2>&1
  bash "$A" tazele --madde 2 --durum ertelendi --d1 "$v" >/dev/null 2>&1; rc=$?
  # tablo.py'yi araçtan bağımsız sına: elle ertelendi satırı yaz, ayrıştırıcı nasıl okuyor
  printf '# ⚓ GÜNÜN PLANI ÇIPASI · 2026-01-02\n\n## Maddeler\n- [-] 2) iki → ERTELENDİ · D1: %s\n' "$v" > "$T/elle.md"
  d=$(python3 "$W/gunluk-plan/scripts/tablo.py" "$T/elle.md" --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["maddeler"][0]["durum"])')
  echo "vaka=[${v%% (*}] cipa_tazele_rc=$rc tablo_okuma=$d"
done
