#!/usr/bin/env bash
# gorev-yolu.test.sh — günlük planın görev betiğini bulma sırası + paketlenmiş kopyanın bütünlüğü (0HC75A: 9 kutuda betik yoktu).
# Y1 açık env KESİN · Y2 olmayan env yoluna sessizce düşmez · Y3 kanonik varsa o · Y4 kanonik yoksa becerinin kendi kopyası (PATH'teki eskiden ÖNCE)
# Y5 hiçbiri yoksa rc 3 · Y6 paketlenmiş kopya sözdizimi geçerli ve dugum-bak.py yanında · Y7 cloudtop kanoniği (origin/main) varsa bayt eşit (gorev.sh · dugum-bak.py · oda-dagit.py, drift)
# Mutantlar: sıra bozulursa Y4 kırmızı.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; R="${YOL_BETIK:-$HERE/gorev-yolu.sh}"
T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null; find "$HERE" -maxdepth 1 -name ".mutant-yol-$$-*" -delete 2>/dev/null' EXIT
G=0; K=0
ok() { if [ "$2" -eq 0 ]; then G=$((G+1)); echo "  ✓ $1"; else K=$((K+1)); echo "  ✗ $1 ${3:-}"; fi; }
mkdir -p "$T/bin" "$T/kan"; printf '#!/bin/sh\n' > "$T/bin/gorev.sh"; chmod +x "$T/bin/gorev.sh"; : > "$T/kan/gorev.sh"
env0() { env -u GUNLUK_PLAN_GOREV_SH "$@"; }
O="$(GUNLUK_PLAN_GOREV_SH=/yok/bu bash "$R")"; ok "Y1 açık env KESİN (olmayan yol bile aynen basılır)" "$([ "$O" = /yok/bu ] && echo 0 || echo 1)" "→ $O"
O="$(GUNLUK_PLAN_GOREV_SH="$T/bin/gorev.sh" bash "$R")"; ok "Y2 açık env var olan yolu basar" "$([ "$O" = "$T/bin/gorev.sh" ] && echo 0 || echo 1)" "→ $O"
O="$(env0 GUNLUK_PLAN_CLOUDTOP_GOREV="$T/kan/gorev.sh" PATH="$T/bin:$PATH" bash "$R")"; ok "Y3 kanonik varsa PATH'ten ve paketlenmiş kopyadan önce o" "$([ "$O" = "$T/kan/gorev.sh" ] && echo 0 || echo 1)" "→ $O"
O="$(env0 GUNLUK_PLAN_CLOUDTOP_GOREV=/yok/kanonik PATH="$T/bin:$PATH" bash "$R")"; ok "Y4 kanonik yoksa becerinin KENDİ kopyası (PATH'teki eski sarmalayıcıdan önce)" "$([ "$O" = "$HERE/gorev.sh" ] && echo 0 || echo 1)" "→ $O"
# Y5: kopyasız beceri dizini (yalnız çözücü) + kanonik yok + PATH'te yok → rc 3
mkdir -p "$T/bos"; cp "$R" "$T/bos/gorev-yolu.sh"
env0 GUNLUK_PLAN_CLOUDTOP_GOREV=/yok/kanonik PATH="/usr/bin:/bin" bash "$T/bos/gorev-yolu.sh" >/dev/null 2>&1; rc=$?; ok "Y5 hiçbir yerde yoksa rc 3 (ölçülemedi)" "$([ "$rc" -eq 3 ] && echo 0 || echo 1)" "→ rc=$rc"
bash -n "$HERE/gorev.sh" 2>/dev/null; a=$?; ok "Y6 paketlenmiş gorev.sh sözdizimi geçerli ve dugum-bak.py yanında" "$([ "$a" -eq 0 ] && [ -f "$HERE/dugum-bak.py" ] && echo 0 || echo 1)"
# Y7 kanoniği cloudtop'un origin/main'inden okur (ana checkout'un ÇALIŞMA AĞACINDAN değil): paylaşılan checkout birleşmeleri geriden
#   izleyebilir ve o zaman Y7 sapmayı değil checkout'un yaşını ölçer (31 Eki: ağaç #1251'de, kanonik #1252 → eşitlemeden önce sahte yeşil).
#   origin/main okunamazsa çalışma ağacına düşer ve bunu söyler.
CT=/config/projects/cloudtop; KYOL=infra/defter-gecit/gorev
kan() { if [ "$KAYNAK" = origin ]; then git -C "$CT" show "origin/main:$KYOL/$1"; else cat "$CT/$KYOL/$1"; fi; }
if git -C "$CT" cat-file -e "origin/main:$KYOL/gorev.sh" 2>/dev/null; then KAYNAK=origin; elif [ -f "$CT/$KYOL/gorev.sh" ]; then KAYNAK=agac; echo "  · Y7 origin/main okunamadı — çalışma ağacıyla ölçülüyor (bayat olabilir)"; else KAYNAK=; fi
if [ -n "$KAYNAK" ]; then
  cmp -s <(kan gorev.sh) "$HERE/gorev.sh" && cmp -s <(kan dugum-bak.py) "$HERE/dugum-bak.py" && cmp -s <(kan oda-dagit.py) "$HERE/oda-dagit.py" && [ -x "$HERE/oda-dagit.py" ]; ok "Y7 paketlenmiş kopya cloudtop kanoniğiyle ($KAYNAK) bayt eşit (gorev.sh · dugum-bak.py · oda-dagit.py +x; sapmışsa kanoniği buraya yeniden kopyala)" "$?"
else echo "  · Y7 atlandı: cloudtop kanoniği bu kutuda yok (eşitlik ölçülemedi)"; fi
if [ -z "${YOL_BETIK:-}" ]; then
  echo "── mutasyon"
  mut() { local M="$HERE/.mutant-yol-$$-$1"; python3 -I - "$R" "$M" "$2" "$3" <<'PY' || { ok "mutant $1: desen tutmadı" 1; return; }
import sys; s=open(sys.argv[1],encoding='utf-8').read(); o=s; s=s.replace(sys.argv[3],sys.argv[4]); assert s!=o; open(sys.argv[2],'w',encoding='utf-8').write(s)
PY
    local o; o="$(YOL_BETIK="$M" bash "$0" 2>&1)"; ok "mutant '$1' → $4 kırmızı" "$(grep -q "✗ $4 " <<<"$o" && echo 0 || echo 1)" "→ $(grep -E '✗' <<<"$o" | head -2)"; }
  mut kendi-kopya-yok '"$HERE/gorev.sh" ' '' Y4
  mut env-kesin-degil '[ -n "${GUNLUK_PLAN_GOREV_SH:-}" ] && {' '[ -n "${GUNLUK_PLAN_GOREV_SH:-}" ] && [ -f "$GUNLUK_PLAN_GOREV_SH" ] && {' Y1
  mut path-once '"$HERE/gorev.sh" "$(command -v gorev.sh 2>/dev/null)"' '"$(command -v gorev.sh 2>/dev/null)" "$HERE/gorev.sh"' Y4
fi
echo "== $G geçti · $K düştü =="; [ "$K" -eq 0 ]
