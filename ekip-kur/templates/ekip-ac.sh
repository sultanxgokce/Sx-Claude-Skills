#!/usr/bin/env bash
# ekip-ac.sh — TEK KOMUTLA tüm ekip üyelerini tek terminalde geri-getir (sekme-kapanma-kurtarma).
#
# NEDEN: code-server / terminal sekmeleri kapanınca üyelerin tmux-oturumları arka planda CANLI kalır
#   (iş kaybolmaz). Bu script tek terminalde hepsini PAYLAŞIMLI-pencere olarak geri-getirir —
#   N sekme elle açmaya gerek yok. Oto-açılış BİLİNÇLİ YOK (oto-açılış sürtünme çıkarır).
#
# KULLANIM: YENİ bir terminal aç → `bash scripts/ekip-ac.sh` (ya da `ekip` alias).
#   'ekip' adlı tmux-oturumunda üyeler pencere olarak canlı görünür. Ctrl-b w = üye-seç · Ctrl-b d = çık.
# DEĞİŞMEZ: üye-oturumlarını YARATMAZ/ÖLDÜRMEZ — yalnız var-olanlara link-window (salt-görünüm/etkileşim).
#   YÖNETİCİ (meta.yonetici) hariç (o zaten kendi sekmesinde). Registry tek-kaynak.
#   ⚠️ DERS (baked-in): nested-attach ÇALIŞMAZ (tmux iç-içe attach reddeder) → link-window kullanılır (paylaşımlı-pencere).
# ENV: EKIP_NO_ATTACH=1 → oturumu kur ama attach etme (test/scripting). EKIP_GRID_SESSION → oturum-adı (default 'ekip').
#      EKIP_REGISTRY → registry yolu (default _agents/handoff/ekip-registry.yaml).
# REGISTRY-AGNOSTİK: hiçbir ekip-adı/üye-adı hardcode DEĞİL → her ekibin registry'siyle çalışır (global-uyumlu).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || dirname "$SCRIPT_DIR")"
REGISTRY="${EKIP_REGISTRY:-$REPO_ROOT/_agents/handoff/ekip-registry.yaml}"
SESSION="${EKIP_GRID_SESSION:-ekip}"

command -v tmux    >/dev/null 2>&1 || { echo "HATA: tmux kurulu değil" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "HATA: python3 yok (registry-parse)" >&2; exit 1; }
[ -f "$REGISTRY" ] || { echo "HATA: registry yok: $REGISTRY" >&2; exit 1; }

# üye tmux-oturum adlarını registry'den al (YÖNETİCİ=meta.yonetici hariç — o zaten kendi sekmesinde).
mapfile -t ALL < <(python3 - "$REGISTRY" <<'PY'
import re,sys
txt=open(sys.argv[1],encoding="utf-8").read()
m=re.search(r'^\s*yonetici:\s*"?([^"\s#]+)"?', txt, re.M)
mgr=m.group(1) if m else ""
cur=None
for line in txt.splitlines():
    m=re.match(r"\s*-\s*id:\s*(\S+)",line)
    if m: cur=m.group(1); continue
    m=re.match(r'\s*tmux:\s*"?([^"\s]+)"?',line)
    if m and cur and cur!=mgr: print(m.group(1).split(":")[0])
PY
)
TARGETS=(); MISSING=()
for t in "${ALL[@]}"; do
  if tmux has-session -t "$t" 2>/dev/null; then TARGETS+=("$t"); else MISSING+=("$t"); fi
done
[ "${#MISSING[@]}" -gt 0 ] && echo "⚠️ canlı-değil (atlandı): ${MISSING[*]} — bu üye(ler) yeniden başlatılmalı." >&2
[ "${#TARGETS[@]}" -gt 0 ] || { echo "HATA: canlı üye-oturumu yok. Üyeleri yeniden başlatman gerekebilir." >&2; exit 1; }

# idempotent: grid-oturum zaten varsa YENİDEN-KURMA → doğrudan bağlan (indeks-karışıklığı önlenir)
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "🔗 '$SESSION' zaten var → bağlanıyorum."
  [ "${EKIP_NO_ATTACH:-0}" = "1" ] && exit 0
  exec tmux attach -t "$SESSION"
fi
# hub-penceresi (yardım) + üyeleri PAYLAŞIMLI-pencere (link-window; nested-attach DEĞİL) olarak ardışık-indekse ekle
tmux new-session -d -s "$SESSION" -n hub \
  "clear; echo '$SESSION — üyeler pencere olarak bağlı.'; echo 'Ctrl-b w = üye-seç · Ctrl-b n/p = sonraki/önceki · Ctrl-b <sayı> = doğrudan · Ctrl-b d = çık'; exec bash"
hub_idx="$(tmux list-windows -t "$SESSION" -F '#{window_index}' 2>/dev/null | sort -n | head -1)"; hub_idx="${hub_idx:-0}"
idx=$((hub_idx + 1)); linked=0
for t in "${TARGETS[@]}"; do
  if tmux link-window -d -s "$t:0" -t "$SESSION:$idx" 2>/dev/null; then
    tmux rename-window -t "$SESSION:$idx" "$t" 2>/dev/null || true
    idx=$((idx + 1)); linked=$((linked + 1))
  fi
done
echo "✅ '$SESSION' hazır → $linked üye pencere-olarak bağlı: ${TARGETS[*]} (Ctrl-b w ile seç)"
[ "${EKIP_NO_ATTACH:-0}" = "1" ] && exit 0
exec tmux attach -t "$SESSION"
