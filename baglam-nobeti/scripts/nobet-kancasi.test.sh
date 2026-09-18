#!/usr/bin/env bash
# nobet-kancasi sınavı — AĞSIZ. Eşik satırları, oran sınırı, susturma, ölçülemedi dürüstlüğü.
set -uo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=0; K=0
kapi(){ if [ "$2" = "$3" ]; then G=$((G+1)); printf '  ✓ %s\n' "$1";
        else K=$((K+1)); printf '  ✗ %s\n     beklenen: %s\n     görülen : %s\n' "$1" "$2" "$3"; fi; }
TMP="$(mktemp -d)"; trap 'find "$TMP" -type f -delete 2>/dev/null; find "$TMP" -depth -type d -empty -delete 2>/dev/null' EXIT
cat > "$TMP/kanon.md" <<'MD'
| `claude-opus-5` | 4 | 500,000 | `opus` | x |
Pencere-ezici: `[1m]` → 1,000,000
MD
tr_yaz(){ # tr_yaz <dosya> <model-kimlik> <ctx>
  printf '{"type":"attachment","attachment":{"type":"model","identity":{"modelId":"%s"}}}\n{"type":"assistant","message":{"model":"x","usage":{"input_tokens":%s,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}\n' "$2" "$3" > "$1"; }
kos(){ # kos <transkript> [stamp-dizini]
  printf '{"transcript_path":"%s","session_id":"s"}' "$1" | BAGLAM_KANON="$TMP/kanon.md" BAGLAM_NOBETI_STAMP="${2:-$TMP/stamp-$RANDOM$RANDOM}" bash "$KOK/nobet-kancasi.sh"; printf ' rc=%s' $?; }
ozet(){ python3 -c 'import sys,json
s=sys.stdin.read().strip()
if not s: print("SESSİZ"); sys.exit()
m=json.loads(s)["hookSpecificOutput"]["additionalContext"]
print(m.split(" (baglam-nobeti")[0])'; }

tr_yaz "$TMP/a" claude-opus-5 100000
kapi "K1 %20 → sessiz, rc=0" "SESSİZ rc=0" "$(kos "$TMP/a" | sed 's/ rc=.*//' | ozet | tr -d '\n'; printf ' rc=%s' 0)"

tr_yaz "$TMP/b" claude-opus-5 360000
kapi "K2 %72 → Sultan'ın %70 satırı" "⚠️ BAĞLAM %72 DOLU — yakında compact gerekecek; çıpalar tazeleniyor." "$(kos "$TMP/b" | sed 's/ rc=.*//' | ozet)"

tr_yaz "$TMP/c" claude-opus-5 420000
kapi "K3 %84 → Sultan'ın kalın compact satırı" "🔴 BAĞLAM %84 DOLU — COMPACT ÖNERİYORUM." "$(kos "$TMP/c" | sed 's/ rc=.*//' | ozet)"
kapi "K3b %84 satırı 'HER cevapta tekrarla' der ve çıpasız 'tazelendi' demeyi yasaklar" "2" \
  "$(kos "$TMP/c" | grep -o "HER cevapta tekrarla\|yazılmadan 'tazelendi' deme" | wc -l | tr -d ' ')"

tr_yaz "$TMP/d" claude-opus-5 460000
kapi "K4 %92 → 'yeni büyük iş almıyorum' eki" "1" "$(kos "$TMP/d" | grep -c 'yeni büyük iş almıyorum')"
kapi "K4b %84'te o ek YOK" "0" "$(kos "$TMP/c" | grep -c 'yeni büyük iş almıyorum')"

# oran sınırı: aynı damga diziniyle ikinci çağrı sessiz (koşum 60 sn)
S="$TMP/stamp-oran"; mkdir -p "$S"
kos "$TMP/c" "$S" >/dev/null
kapi "K5 aynı oturumda 60 sn içinde ikinci çağrı sessiz (oran sınırı)" "SESSİZ" "$(kos "$TMP/c" "$S" | sed 's/ rc=.*//' | ozet)"
# damgayı eskit → tekrar konuşur
for f in "$S"/*; do echo 0 > "$f"; done
kapi "K5b damga eskiyince yeniden konuşur" "🔴 BAĞLAM %84 DOLU — COMPACT ÖNERİYORUM." "$(kos "$TMP/c" "$S" | sed 's/ rc=.*//' | ozet)"

kapi "K6 BAGLAM_NOBETI_KAPALI=1 susturur" "SESSİZ" "$(printf '{"transcript_path":"%s"}' "$TMP/c" | BAGLAM_NOBETI_KAPALI=1 BAGLAM_KANON="$TMP/kanon.md" BAGLAM_NOBETI_STAMP="$TMP/s6" bash "$KOK/nobet-kancasi.sh" | ozet)"

tr_yaz "$TMP/e" gpt-5.6-terra 400000
kapi "K7 pencere bilinmiyor → 'ÖLÇÜLEMEDİ' der, temiz DEMEZ" "1" "$(kos "$TMP/e" | grep -c 'ÖLÇÜLEMEDİ')"
kapi "K7b ölçülemedi satırı yanlış-yeşil vermez (%NN basmaz)" "0" "$(kos "$TMP/e" | grep -c 'BAĞLAM %')"

kapi "K8 transkript yolu yok → sessiz rc=0" "SESSİZ rc=0" "$(printf '{"transcript_path":"/yok/x"}' | BAGLAM_NOBETI_STAMP="$TMP/s8" bash "$KOK/nobet-kancasi.sh" | ozet | tr -d '\n'; printf ' rc=%s' "${PIPESTATUS[1]}")"
kapi "K9 bozuk stdin → sessiz rc=0" "SESSİZ rc=0" "$(printf 'bozuk' | BAGLAM_NOBETI_STAMP="$TMP/s9" bash "$KOK/nobet-kancasi.sh" | ozet | tr -d '\n'; printf ' rc=%s' "${PIPESTATUS[1]}")"
kapi "K10 çıktı geçerli hook-JSON (PostToolUse)" "PostToolUse" "$(kos "$TMP/c" | sed 's/ rc=.*//' | python3 -c 'import sys,json;print(json.load(sys.stdin)["hookSpecificOutput"]["hookEventName"])')"

printf '\ngeçti=%s · kaldı=%s\n' "$G" "$K"
[ "$K" -eq 0 ]
