#!/usr/bin/env bash
# baglam-olc sınavı — AĞSIZ, sentetik transkript + sentetik kanon. Ölçmediğine yeşil demediğini de sınar.
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=0; K=0
kapi(){ if [ "$2" = "$3" ]; then G=$((G+1)); printf '  ✓ %s\n' "$1";
        else K=$((K+1)); printf '  ✗ %s\n     beklenen: %s\n     görülen : %s\n' "$1" "$2" "$3"; fi; }
TMP="$(mktemp -d)"; trap 'find "$TMP" -type f -delete 2>/dev/null; find "$TMP" -depth -type d -empty -delete 2>/dev/null' EXIT

cat > "$TMP/kanon.md" <<'MD'
## Model sozlugu (tek kaynak)

| model | kademe | pencere | harness | dogrulama |
|---|---|---|---|---|
| `claude-fable-5` | 5 | 1,000,000 | `fable` | x |
| `claude-opus-5` | 4 | 500,000 | `opus` | x |
| `claude-haiku-4-5` | 2 | 200,000 | `haiku` | x |

Pencere-ezici (ilk-eslesen kazanir): `[1m]` → 1,000,000
MD
usage(){ # usage <dosya> <model> <input> <cache_read> <cache_create>
  printf '{"type":"assistant","message":{"model":"%s","usage":{"input_tokens":%s,"cache_read_input_tokens":%s,"cache_creation_input_tokens":%s}}}\n' "$2" "$3" "$4" "$5" >> "$1"; }
kimlik(){ printf '{"type":"attachment","attachment":{"type":"model","identity":{"modelId":"%s"}}}\n' "$2" >> "$1"; }
cagir(){ ( export BAGLAM_KANON="$TMP/kanon.md"; python3 "$KOK/baglam-olc.py" "$1" | tr -d "\n"; printf " rc=%s" "${PIPESTATUS[0]}" ); }

# T1 düz ölçüm: opus-5 bare → kanon 500k; 100k kullanım → %20
: > "$TMP/t1"; kimlik "$TMP/t1" claude-opus-5; usage "$TMP/t1" claude-opus-5 1000 90000 9000
kapi "T1 kanon penceresi 500k, 100k → %20 rc=0" "pct=20 kullanilan=100000 pencere=500000 kaynak=kanon model=claude-opus-5 rc=0" "$(cagir "$TMP/t1")"

# T2 [1m] kimliği → ezici 1M (transkript usage.model'de [1m] YOK, attachment'ta VAR)
: > "$TMP/t2"; kimlik "$TMP/t2" 'claude-opus-5[1m]'; usage "$TMP/t2" claude-opus-5 0 200000 0
kapi "T2 [1m] yalnız attachment'ta — ezici 1M kazanır → %20" "pct=20 kullanilan=200000 pencere=1000000 kaynak=ezici model=claude-opus-5[1m] rc=0" "$(cagir "$TMP/t2")"

# T3 %70 eşiği rc=1 · T4 %80 eşiği rc=2 (kanon 500k)
: > "$TMP/t3"; kimlik "$TMP/t3" claude-opus-5; usage "$TMP/t3" claude-opus-5 0 350000 0
kapi "T3 %70 → rc=1" "pct=70 kullanilan=350000 pencere=500000 kaynak=kanon model=claude-opus-5 rc=1" "$(cagir "$TMP/t3")"
: > "$TMP/t4"; kimlik "$TMP/t4" claude-opus-5; usage "$TMP/t4" claude-opus-5 0 400000 0
kapi "T4 %80 → rc=2" "pct=80 kullanilan=400000 pencere=500000 kaynak=kanon model=claude-opus-5 rc=2" "$(cagir "$TMP/t4")"

# T5 bilinmeyen model → rc=3, pct YOK (sessiz 200k varsayımı YASAK)
: > "$TMP/t5"; kimlik "$TMP/t5" gpt-5.6-terra; usage "$TMP/t5" gpt-5.6-terra 0 150000 0
kapi "T5 kanonda olmayan model → rc=3 pencere-bilinmiyor (pct basılmaz)" "kullanilan=150000 model=gpt-5.6-terra sebep=pencere-bilinmiyor kanon=$TMP/kanon.md rc=3" "$(cagir "$TMP/t5")"

# T6 kanon dosyası yok → rc=3 (gömülü tablo YOK — kopya yasağı)
: > "$TMP/t6"; kimlik "$TMP/t6" claude-opus-5; usage "$TMP/t6" claude-opus-5 0 100 0
kapi "T6 kanon okunamıyor → rc=3 kanon=okunamadi" "kullanilan=100 model=claude-opus-5 sebep=pencere-bilinmiyor kanon=okunamadi rc=3" \
  "$( export BAGLAM_KANON="$TMP/yok.md"; python3 "$KOK/baglam-olc.py" "$TMP/t6" | tr -d "\n"; printf " rc=%s" "${PIPESTATUS[0]}" )"

# T7 env ezer
kapi "T7 BAGLAM_PENCERE env her şeyi ezer" "pct=50 kullanilan=100000 pencere=200000 kaynak=env model=claude-opus-5 rc=0" \
  "$( export BAGLAM_KANON="$TMP/kanon.md" BAGLAM_PENCERE=200000; python3 "$KOK/baglam-olc.py" "$TMP/t1" | tr -d "\n"; printf " rc=%s" "${PIPESTATUS[0]}" )"

# T8 transkript yok / usage yok
kapi "T8 transkript yok → rc=3" "sebep=transkript-yok transkript=$TMP/yok rc=3" "$(cagir "$TMP/yok")"
: > "$TMP/t8"; kimlik "$TMP/t8" claude-opus-5
kapi "T8b usage satırı yok → rc=3" "sebep=usage-yok transkript=$TMP/t8 rc=3" "$(cagir "$TMP/t8")"

# T9 SON usage geçerli olan (araya bozuk satır ve eski usage girse de son geçerli kazanır)
: > "$TMP/t9"; kimlik "$TMP/t9" claude-opus-5; usage "$TMP/t9" claude-opus-5 0 400000 0; printf '{"usage": bozuk\n' >> "$TMP/t9"; usage "$TMP/t9" claude-opus-5 0 50000 0
kapi "T9 son geçerli usage kazanır; bozuk satır yutulur" "pct=10 kullanilan=50000 pencere=500000 kaynak=kanon model=claude-opus-5 rc=0" "$(cagir "$TMP/t9")"

# T10 model kimliği 256KB kuyruğun DIŞINDA (uzun araç dizisi) → geriye tarama bulur
: > "$TMP/t10"; kimlik "$TMP/t10" 'claude-opus-5[1m]'
python3 - "$TMP/t10" <<'PY'
import sys
with open(sys.argv[1],'a') as f:
    for i in range(3000):
        f.write('{"type":"user","message":{"role":"user","content":"' + 'x'*200 + '"}}\n')
PY
usage "$TMP/t10" claude-opus-5 0 100000 0
kapi "T10 kimlik kuyruk dışında — geriye tarama 1M bulur" "pct=10 kullanilan=100000 pencere=1000000 kaynak=ezici model=claude-opus-5[1m] rc=0" "$(cagir "$TMP/t10")"

# T11 model değişti (oturum içi /model): SON kimlik kazanır
: > "$TMP/t11"; kimlik "$TMP/t11" 'claude-opus-5[1m]'; usage "$TMP/t11" claude-opus-5 0 1 0; kimlik "$TMP/t11" claude-haiku-4-5; usage "$TMP/t11" claude-haiku-4-5 0 100000 0
kapi "T11 oturum içi model değişimi — son kimlik (haiku 200k) kazanır → %50" "pct=50 kullanilan=100000 pencere=200000 kaynak=kanon model=claude-haiku-4-5 rc=0" "$(cagir "$TMP/t11")"

# T12 canlı kanon dosyası (varsa) gerçekten parse ediliyor mu — kopya yok, kaynak şart
if [ -f /config/.claude/ORTAK-MIMARI.md ]; then
  kapi "T12 canlı kanon tablosu okunuyor (opus-5 satırı var)" "500000 kaynak=kanon" \
    "$( export BAGLAM_KANON=/config/.claude/ORTAK-MIMARI.md; python3 "$KOK/baglam-olc.py" "$TMP/t1" | sed -n 's/.*pencere=\([0-9]*\) \(kaynak=[a-z]*\).*/\1 \2/p' )"
else
  printf '  – T12 atlandı: canlı kanon dosyası bu kutuda yok\n'
fi

printf '\ngeçti=%s · kaldı=%s\n' "$G" "$K"
[ "$K" -eq 0 ]
