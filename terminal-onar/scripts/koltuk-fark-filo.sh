#!/usr/bin/env bash
# koltuk-fark-filo.sh — 18 kutu × koltuk-fark.mjs (G-BANI-0007): her kutuda tmux oturumları ⟷ terminal sayfası listesi.
# SALT-OKUR: ssh <host> docker exec … ; kutuda kalıcı hiçbir şey yazılmaz.
#   --kaynak <terminal-onar dizini>  kurulmamış sürümü ölçmek için: dört dosya stdin'den kutuda GEÇİCİ dizine açılır, koşulur, silinir
#   (verilmezse kutunun kurulu kopyası: /config/.claude/skills/terminal-onar)
#   [kutu…]  verilmezse host'taki bütün cloudtop-* kutuları (altyapı hariç)
# rc: 0 hepsi temiz · 1 en az bir kutuda DÜŞEN/hayalet · 2 en az bir kutu ölçülemedi (temiz sayılmaz)
set -uo pipefail
HOST="${KOLTUK_FARK_HOST:-hostsrv}"; KAYNAK=""; KUTULAR=()
while [ $# -gt 0 ]; do case "$1" in --kaynak) KAYNAK="$2"; shift 2 ;; *) KUTULAR+=("$1"); shift ;; esac; done
ALTYAPI='^cloudtop-(kapi|ntfy|defter|terminal-merkez|kokpit)$'
# node her kutuda PATH'te değil (vekatip: rc 127 ölçüldü) → code-server'ın kendi node'una düşülür
ssh_() { timeout 60 ssh -o BatchMode=yes -o ConnectTimeout=5 "$HOST" "$@"; }
if [ "${#KUTULAR[@]}" -eq 0 ]; then
  l="$(ssh_ "docker ps --format '{{.Names}}'")" || { echo "ÖLÇÜLEMEDİ: kutu listesi alınamadı ($HOST)"; exit 2; }
  mapfile -t KUTULAR < <(printf '%s\n' "$l" | grep -E '^cloudtop(-|$)' | grep -vE "$ALTYAPI" | sort)
fi
temiz=0; kirli=0; olcmedi=0
for k in "${KUTULAR[@]}"; do
  [[ "$k" =~ ^[a-z0-9-]+$ ]] || { echo "✗ $k: geçersiz kutu adı"; olcmedi=$((olcmedi+1)); continue; }
  if [ -n "$KAYNAK" ]; then
    out="$(tar -C "$KAYNAK" -cf - kapi/koltuk-fark.mjs kapi/koltuklar.mjs scripts/koltuk-bagla.sh scripts/koltuk-adi.sh \
      | ssh_ "docker exec -i -u 1000 $k sh -c 'n=\$(command -v node || echo /app/code-server/lib/node); d=\$(mktemp -d) && tar -x -C \$d && \$n \$d/kapi/koltuk-fark.mjs --json; r=\$?; rm -r \$d; exit \$r'" 2>&1)"; rc=$?
  else
    out="$(ssh_ "docker exec -u 1000 $k sh -c 'n=\$(command -v node || echo /app/code-server/lib/node); \$n /config/.claude/skills/terminal-onar/kapi/koltuk-fark.mjs --json'" 2>&1)"; rc=$?
  fi
  ozet="$(printf '%s\n' "$out" | tail -n 1 | python3 -c 'import json,sys
try: d=json.loads(sys.stdin.read())
except Exception: print("?"); sys.exit()
if "olculemedi" in d: print("ÖLÇÜLEMEDİ: "+d["olculemedi"]); sys.exit()
o=d["ozet"]; print("%d oturum · görünür %d · gizli %d · DÜŞEN %d · hayalet %d · başka adla bağlı %d" % (o["toplam"],o["gorunur"],o["gizli"],o["dusen"],o["hayalet"],o["sekme"]))
for x in d["oturumlar"]:
    if x["hukum"]=="DUSEN": print("      ✗ DÜŞEN: "+x["ad"])
for h in d["hayalet"]: print("      ✗ HAYALET: "+h)
for s in d["sekme"]: print("      ⓘ \x27%s\x27 adıyla açılmış istemci → bugün \x27%s\x27" % (s["acilis_adi"], s["oturum"]))')"
  case "$rc:$ozet" in
    0:[0-9]*) echo "✓ $k: $ozet"; temiz=$((temiz+1)) ;;
    1:[0-9]*) echo "✗ $k: $ozet"; kirli=$((kirli+1)) ;;
    *) echo "? $k: ölçülemedi (rc=$rc) ${ozet:-$(printf '%s' "$out" | tail -n 1 | cut -c1-120)}"; olcmedi=$((olcmedi+1)) ;;
  esac
done
echo "== ${#KUTULAR[@]} kutu · temiz $temiz · DÜŞEN/hayalet olan $kirli · ölçülemedi $olcmedi =="
[ "$olcmedi" -gt 0 ] && exit 2
[ "$kirli" -gt 0 ] && exit 1
exit 0
