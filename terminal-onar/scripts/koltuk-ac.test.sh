#!/usr/bin/env bash
# koltuk-ac.test.sh — GERÇEK tmux (ayrı sunucu -L), sahte ekip-ac.sh + sahte aile kaydı. Sultan'ın kurgusu birebir:
# oturumu öldür → tek komutla geri gelsin · eski sohbete dönebilsin (--resume-if-known) · ikinci kopya AÇILMASIN ·
# kayıtsız koltuk dürüstçe reddedilsin · üç durum ayrı. tmux yoksa rc=3 ÖLÇÜLEMEDİ (yeşil değil).
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v tmux >/dev/null || { echo "ÖLÇÜLEMEDİ: tmux yok"; exit 3; }
T="$(mktemp -d)"; L="ka-sinav-$$"; trap 'tmux -L "$L" kill-server 2>/dev/null; rm -r "$T"' EXIT
gecen=0; kalan=0
kapi() { if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 → beklenen [$2] olan [$3]"; fi; }
# sahte proje: aile kaydı (rol X → tmux x) + ekip-ac.sh stub (canlıysa attach basar rc0; yoksa oturum AÇAR; --resume-if-known'ı deftere yazar)
mkdir -p "$T/proje/scripts" "$T/proje/_agents/handoff" "$T/durum"
cat > "$T/proje/_agents/handoff/aile-registry.yaml" <<Y
uyeler:
  - id: ROLX
    tmux: "rolx:0"
    session_id: "11111111-2222-4333-8444-555555555555"
  - id: ROLY
    tmux: "roly:0"
    session_id: ""
Y
cat > "$T/proje/scripts/ekip-ac.sh" <<S
#!/usr/bin/env bash
rol="\$1"; shift; ad="\$(printf '%s' "\$rol" | tr 'A-Z' 'a-z')"
echo "\$rol \$*" >> "$T/defter"
if tmux -L "$L" has-session -t "=\$ad" 2>/dev/null; then echo "canlı: tmux attach -t \$ad"; exit 0; fi
tmux -L "$L" new-session -d -s "\$ad" "sleep 300"; echo "doğdu: \$ad"
S
chmod +x "$T/proje/scripts/ekip-ac.sh"
# koltuk-bagla stub: liste (ad son claude tur hal) — claude=1 yalnız 'rolx' için (sahte), gerisi 0
cat > "$T/kb.sh" <<S
#!/usr/bin/env bash
[ "\$1" = --liste ] || exit 2
tmux -L "$L" list-sessions -F '#{session_name}' 2>/dev/null | while read -r s; do
  if [ "\$s" = rolx ]; then printf '%s\t0\t1\tajan\tcalisiyor\n' "\$s"; else printf '%s\t0\t0\tdiger\tbilinmiyor\n' "\$s"; fi
done; exit 0
S
chmod +x "$T/kb.sh"
mkdir -p "$T/ev/.claude/projects/p" && : > "$T/ev/.claude/projects/p/11111111-2222-4333-8444-555555555555.jsonl"
KA() { HOME="$T/ev" TO_KUTU=sinav TO_PROJE="$T/proje" TO_DURUM_DIZ="$T/durum" TO_KOLTUK_BETIK="$T/kb.sh" TO_ANA_TMUX=sinav-ana \
       TMUX= bash -c "tmux() { command tmux -L '$L' \"\$@\"; }; export -f tmux; bash '$D/koltuk-ac.sh' \"\$@\"" _ "$@"; }
j() { python3 -c "import json,sys;j=json.load(sys.stdin);print($1)"; }
echo "── D · durum üç ayrı"
kapi "D1 oturum yok → durum=yok, yol=ekip-ac, rol çözüldü, resume mümkün" "yok|ekip-ac|ROLX|true" "$(KA durum rolx | j '"|".join([j["durum"],j["yol"],j["rol"],str(j["resume"]).lower()])')"
tmux -L "$L" new-session -d -s roly "sleep 300"
kapi "D2 oturum var, Claude yok → durum=claude-yok; sid boş → resume yok" "claude-yok|false" "$(KA durum roly | j 'j["durum"]+"|"+str(j["resume"]).lower()')"
kapi "D3 kayıtsız koltuk → yol=yok (açılmaz), rol boş" "yok|" "$(KA durum kayitsiz | j 'j["yol"]+"|"+j["rol"]')"
kapi "D4 ana koltuk kayıtsız olsa da yol=onar, ana=true" "onar|true" "$(KA durum sinav-ana | j 'j["yol"]+"|"+str(j["ana"]).lower()')"
echo "── A · aç / yeniden aç / eski sohbet"
KA ac rolx >/dev/null; kapi "A1 ölü koltuk tek komutla geri geldi (tmux oturumu var)" "1" "$(tmux -L "$L" has-session -t =rolx 2>/dev/null && echo 1 || echo 0)"
kapi "A2 ekip-ac.sh ROL ile çağrıldı, --resume-if-known YOK (taze aç)" "ROLX " "$(tail -1 "$T/defter")"
out="$(KA ac rolx)"; kapi "A3 canlıyken yeniden 'aç' → ikinci kopya AÇILMAZ ('zaten canlı')" "1|1" "$(tmux -L "$L" list-sessions -F '#{session_name}' | grep -c '^rolx$')|$(echo "$out" | grep -c 'zaten canlı')"
tmux -L "$L" kill-session -t =rolx
KA ac rolx --eski >/dev/null; kapi "A4 'eski sohbete dön' → ekip-ac.sh --resume-if-known ile çağrıldı" "ROLX --resume-if-known" "$(tail -1 "$T/defter")"
out="$(KA ac roly 2>&1)"; rc=$?; kapi "A5 Claude'suz oturum önce kapatılır sonra doğar (rc 0, tek oturum)" "0|1" "$rc|$(tmux -L "$L" list-sessions -F '#{session_name}' | grep -c '^roly$')"
out="$(KA ac kayitsiz 2>&1)"; rc=$?; kapi "A6 kayıtsız koltuk AÇILMAZ (rc 4) ve sebebi söylenir" "4|1" "$rc|$(echo "$out" | grep -c 'kayıtlı bir koltuk değil')"
kapi "A7 kayıtsız denemede tmux'ta oturum doğmadı" "0" "$(tmux -L "$L" list-sessions -F '#{session_name}' 2>/dev/null | grep -c '^kayitsiz$')"
echo "── N · olumsuz kontrol: ekip-ac.sh yoksa kayıtlı rol de açılmaz"
mv "$T/proje/scripts/ekip-ac.sh" "$T/proje/scripts/ekip-ac.sh.kapali"
kapi "N1 betik yokken yol=yok (sessizce başka yola düşmez)" "yok" "$(KA durum rolx | j 'j["yol"]')"
mv "$T/proje/scripts/ekip-ac.sh.kapali" "$T/proje/scripts/ekip-ac.sh"
echo; echo "GEÇEN: $gecen · KALAN: $kalan"; [ "$kalan" = 0 ]
