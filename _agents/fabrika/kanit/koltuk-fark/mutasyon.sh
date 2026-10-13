#!/usr/bin/env bash
# Mutasyon kapısı (koltuk-fark): her korumayı boz → koltuk-fark.test.sh KIRMIZI olmalı. Pozitif kontrol + desen-eksik kapısı.
set -u
KOK="${1:?depo kökü}"; g=0; k=0; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete; rmdir "$T"' EXIT
kos() { local ad="$1" dosya="$2" eski="$3" yeni="$4" d="$T/$1"; mkdir -p "$d"; cp -r "$KOK/terminal-onar" "$d/"
  if ! ESKI="$eski" YENI="$yeni" python3 -c 'import os,sys;p=sys.argv[1];s=open(p).read();e=os.environ["ESKI"]
if e not in s: sys.exit(3)
open(p,"w").write(s.replace(e,os.environ["YENI"],1))' "$d/terminal-onar/$dosya"; then echo "  ✗ $ad: DESEN YOK — uygulanmadı"; k=$((k+1)); return 1; fi
  if bash "$d/terminal-onar/kapi/koltuk-fark.test.sh" >"$d/c.txt" 2>&1; then echo "  ✗ $ad: sınav YEŞİL kaldı"; k=$((k+1)); else echo "  ✓ $ad: kırmızı ($(grep -c '✗' "$d/c.txt") kapı)"; g=$((g+1)); fi; }
mkdir -p "$T/p"; cp -r "$KOK/terminal-onar" "$T/p/"; if bash "$T/p/terminal-onar/kapi/koltuk-fark.test.sh" >/dev/null 2>&1; then echo "  ✓ P0 pozitif kontrol yeşil"; g=$((g+1)); else echo "  ✗ P0 mutasyonsuz kırmızı"; k=$((k+1)); fi
kos M1-dusen-gorunur-sayilir kapi/koltuk-fark.mjs "return { ad, hukum: 'DUSEN'" "return { ad, hukum: 'gorunur'"
kos M2-hayalet-yok-sayilir kapi/koltuk-fark.mjs "process.exit(ozet.dusen || ozet.hayalet ? 1 : 0);" "process.exit(ozet.dusen ? 1 : 0);"
kos M3-tmux-hatasi-temiz kapi/koltuk-fark.mjs "else if (!/no server running|No such file or directory/.test(t.err)) olculemedi(" "else if (false) olculemedi("
kos M4-gizli-betik-sorulmaz kapi/koltuk-fark.mjs "if (g.rc !== 0) olculemedi(" "if (false) olculemedi("
kos M5-altyapi-gerekcesiz scripts/koltuk-bagla.sh 'gizli "$s" && printf' 'false && printf'
kos M6-kapi-kendi-kopyasi kapi/sunucu.mjs "import { KOLTUK_AD_DESEN, koltukSatirlari } from './koltuklar.mjs';" "const KOLTUK_AD_DESEN = /x/; const koltukSatirlari = () => [];"
kos M7-sekme-hedefi-kayboldu kapi/koltuk-fark.mjs "if (hedef && hedef !== oturum" "if (false && hedef !== oturum"
before=$k; kos M9-desen-eksik kapi/koltuk-fark.mjs 'BU_DESEN_YOK_42' x >/dev/null
if [ "$k" -eq $((before+1)) ]; then k=$before; g=$((g+1)); echo "  ✓ M9 desen-eksik kapısı: uygulanmayan mutasyon düştü"; else echo "  ✗ M9 desen-eksik kapısı çalışmıyor"; k=$((k+1)); fi
echo "== mutasyon: $g geçti / $k kaldı =="; [ "$k" -eq 0 ]
