#!/usr/bin/env bash
# dersler-brif.test.sh — ders ayırıcısının hermetik sınavı. Gerçek deftere DOKUNMAZ.
# Ağırlık merkezi: çürük ders AYRI başlıkta görünmeli (brif onu ayakta sananla karıştırmasın)
# ve blok ORTADAN KESİLMEMELİ (tail -n 60 tam bunu yapıyordu, ölçüldü 14 Ekim).
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; A="$REPO/scripts/dersler-brif.py"
GS="/config/.claude/skills/bileyi/scripts/guvenli-sil.sh"
if [ -r "$GS" ]; then T="$(bash "$GS" --yeni dersbrif-sinav)"; trap 'bash "$GS" "$T" >/dev/null 2>&1' EXIT
else T="$(mktemp -d)"; trap 'rm -r "$T" 2>/dev/null' EXIT; fi
GEC=0; DUS=0
kapi(){ local ad="$1" bek="$2"; shift 2; local rc; "$@" >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq "$bek" ]; then echo "✅ $ad"; GEC=$((GEC+1)); else echo "❌ $ad: beklenen rc=$bek, gelen rc=$rc"; DUS=$((DUS+1)); fi; }
var(){ local ad="$1" desen="$2"; if printf '%s' "$CIKTI" | grep -q -- "$desen"; then echo "✅ $ad"; GEC=$((GEC+1)); else echo "❌ $ad: '$desen' yok"; DUS=$((DUS+1)); fi; }
bolumde(){ # ad · bölüm başlığı · aranan ders · beklenen(var/yok)
  local ad="$1" bas="$2" ders="$3" bek="$4"
  local kes; kes="$(printf '%s' "$CIKTI" | awk -v b="$bas" 'index($0,b){f=1;next} /^### (AYAKTA|🔴 ÇÜRÜT|ÖLÇÜLEMEDİ)/{f=0} f')"
  if printf '%s' "$kes" | grep -q "^### $ders"; then
    [ "$bek" = var ] && { echo "✅ $ad"; GEC=$((GEC+1)); } || { echo "❌ $ad: $ders '$bas' bölümünde OLMAMALIYDI"; DUS=$((DUS+1)); }
  else
    [ "$bek" = yok ] && { echo "✅ $ad"; GEC=$((GEC+1)); } || { echo "❌ $ad: $ders '$bas' bölümünde YOK"; DUS=$((DUS+1)); }
  fi; }

D="$T/DERSLER.md"
cat > "$D" <<'EOF'
# DERSLER
### D-001 · Ayakta kalan ilk iddia
- **Kanıt:** kaynak (birincil)
- **Ne olursa çürür:** şu olursa
- **Son doğrulama:** 2026-01-01 · **atıf:** 0
- **İkinci göz:** ayakta (çürütülemedi) · 2026-01-02 — kanıt iddiayı taşıyor
### D-002 · Çürütülen iddia
- **Kanıt:** kaynak (satıcı fiyat sayfası)
- **Ne olursa çürür:** bu olursa
- **Son doğrulama:** 2026-01-01 · **atıf:** 0
- **İkinci göz:** 🔴 ÇÜRÜDÜ · 2026-01-02 — satıcı sayfası ödemeyi göstermez
### D-003 · Ölçülemeyen iddia
- **Kanıt:** kaynak (ikincil)
- **Ne olursa çürür:** o olursa
- **Son doğrulama:** 2026-01-01 · **atıf:** 0
- **İkinci göz:** ölçülemedi · 2026-01-02 — metinden ayırt edilemiyor
### D-004 · Henüz göz görmemiş iddia
- **Kanıt:** kaynak (birincil)
- **Ne olursa çürür:** başka bir şey
- **Son doğrulama:** 2026-01-03 · **atıf:** 0
EOF
CIKTI="$(python3 "$A" "$D" --son 8 2>&1)"
var "üç başlık · AYAKTA" "### AYAKTA"
var "üç başlık · ÇÜRÜTÜLDÜ" "ÇÜRÜTÜLDÜ"
var "üç başlık · ÖLÇÜLEMEDİ" "### ÖLÇÜLEMEDİ"
var "ayakta uyarısı (doğru demek değil)" "doğru\* demek DEĞİL"
var "çürük uyarısı (üstüne inşa etme)" "ÜSTÜNE İNŞA ETME"
bolumde "çürük ders ÇÜRÜTÜLDÜ'de" "ÇÜRÜTÜLDÜ" "D-002" var
bolumde "çürük ders AYAKTA'da DEĞİL" "### AYAKTA" "D-002" yok
bolumde "ölçülemedi ayrı bölümde" "### ÖLÇÜLEMEDİ" "D-003" var
bolumde "damgasız ders AYAKTA sayılır" "### AYAKTA" "D-004" var
# blok bütünlüğü: her ders kendi başlığı + kanıt satırıyla tam gelmeli
n="$(printf '%s' "$CIKTI" | grep -c '^### D-')"; m="$(printf '%s' "$CIKTI" | grep -c '^- \*\*Kanıt:\*\*')"
if [ "$n" = "4" ] && [ "$m" = "4" ]; then echo "✅ blok bütünlüğü (4 ders · 4 kanıt satırı)"; GEC=$((GEC+1));
else echo "❌ blok bütünlüğü: $n ders / $m kanıt satırı"; DUS=$((DUS+1)); fi
# --son N gerçekten kesiyor mu (en YENİ dersler kalmalı)
CIKTI="$(python3 "$A" "$D" --son 2 2>&1)"
var "--son 2 · en yeni ders var (D-004)" "^### D-004"
if printf '%s' "$CIKTI" | grep -q "^### D-001"; then echo "❌ --son 2: eski ders (D-001) düşmeliydi"; DUS=$((DUS+1)); else echo "✅ --son 2 eski dersi düşürdü"; GEC=$((GEC+1)); fi
# fail-closed
kapi "dosya yok rc=3" 3 python3 "$A" "$T/yok.md"
kapi "kullanım rc=3" 3 python3 "$A"
printf '# DERSLER\nblok yok\n' > "$T/bos.md"
kapi "bloksuz defter rc=3" 3 python3 "$A" "$T/bos.md"
# MUTASYON: ayırma sökülünce çürük ders AYAKTA'ya düşmeli (kapı ısırıyor mu)
K="$T/mut.py"; cp "$A" "$K"
python3 - "$K" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p,encoding="utf-8").read()
a='    if re.search(r"İkinci göz:\\*\\* 🔴 ÇÜRÜDÜ", b): return "curuk"\n'
assert a in s, "mutasyon deseni yok"
open(p,"w",encoding="utf-8").write(s.replace(a,"",1))
PY
CIKTI="$(python3 "$K" "$D" --son 8 2>&1)"
bolumde "MUT: ayırma sökülünce çürük AYAKTA'ya düştü" "### AYAKTA" "D-002" var
echo
echo "— $GEC geçti · $DUS düştü"
[ "$DUS" -eq 0 ]
