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
  case "\$s" in
    rolx)   printf '%s\t%s\t1\tajan\tcalisiyor\n' "\$s" "\$(date +%s)" ;;
    takili) printf '%s\t%s\t1\tajan\tcalisiyor\n' "\$s" "\$(( \$(date +%s) - 2000 ))" ;;   # Claude var, 2000 sn'dir ekran değişmedi
    sorulu) printf '%s\t%s\t1\tajan\tsoru\n' "\$s" "\$(( \$(date +%s) - 2000 ))" ;;        # eski ama SORU bekliyor → takılı değil
    *)      printf '%s\t0\t0\tdiger\tbilinmiyor\n' "\$s" ;;
  esac
done; exit 0
S
chmod +x "$T/kb.sh"
mkdir -p "$T/beceri/scripts"; cp "$D/ortak.sh" "$T/beceri/scripts/"; cp "$D/koltuk-ac.sh" "$T/beceri/scripts/"
printf '#!/usr/bin/env bash\necho onar >> "%s"; exit "${ONAR_RC:-0}"\n' "$T/defter" > "$T/beceri/scripts/onar.sh"
printf '#!/usr/bin/env bash\necho "kademe $*" >> "%s"\n' "$T/defter" > "$T/beceri/scripts/kademe.sh"; chmod +x "$T/beceri/scripts/"*.sh
mkdir -p "$T/ev/.claude/projects/p" && : > "$T/ev/.claude/projects/p/11111111-2222-4333-8444-555555555555.jsonl"
KA() { HOME="$T/ev" TO_KUTU=sinav TO_PROJE="$T/proje" TO_DURUM_DIZ="$T/durum" TO_KOLTUK_BETIK="${KB_OVERRIDE:-$T/kb.sh}" TO_ANA_TMUX=sinav-ana TO_BECERI_KOK="$T/beceri" \
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
echo "── T · takılı durumu (üçüncü hâl) ve ana koltuk yolu"
tmux -L "$L" new-session -d -s takili "sleep 300"; tmux -L "$L" new-session -d -s sorulu "sleep 300"
kapi "T1 Claude var + 2000 sn ekran değişmedi + soru/girdi beklemiyor → durum=takili" "takili" "$(KA durum takili | j 'j["durum"]')"
kapi "T2 aynı eskilik ama SORU bekliyor → takılı DEĞİL (canli)" "canli" "$(KA durum sorulu | j 'j["durum"]')"
kapi "T3 TO_TAKILI_SN=5000 → aynı koltuk canli (eşik ortamdan)" "canli" "$(TO_TAKILI_SN=5000 KA durum takili | j 'j["durum"]')"
: > "$T/defter"; out="$(KA ac sinav-ana 2>&1)"; rc=$?
kapi "T4 ana koltuk 'ac' → onar.sh (K0) çağrılır, rc 0 'açıldı'" "0|1|1" "$rc|$(grep -c '^onar$' "$T/defter")|$(echo "$out" | grep -c 'K0')"
: > "$T/defter"; out="$(ONAR_RC=1 KA ac sinav-ana 2>&1)"; rc=$?; sleep 0.5
kapi "T5 onar.sh düşerse merdiven (kademe.sh --kaynak dugme) başlar, rc 3" "3|1" "$rc|$(grep -c '^kademe --kaynak dugme' "$T/defter")"
sed -i 's/^  - id: ROLY/  - id: TAKILI\n    tmux: "takili:0"\n    session_id: ""\n  - id: ROLY/' "$T/proje/_agents/handoff/aile-registry.yaml"
out="$(KA ac takili 2>&1)"; rc=$?
kapi "T7 takılı koltuğa zorlasız 'ac' → DOKUNMAZ (rc 5, oturum yaşıyor, 'çalışıyor olabilir')" "5|1|1" "$rc|$(tmux -L "$L" has-session -t =takili 2>/dev/null && echo 1 || echo 0)|$(echo "$out" | grep -c 'çalışıyor olabilir')"
: > "$T/defter"
out="$(KA ac takili --zorla 2>&1)"; rc=$?
kapi "T8 --zorla ile takılı oturum kapatılıp ekip-ac ile yeniden doğar (rc 0, tek oturum)" "0|1|1" "$rc|$(tmux -L "$L" list-sessions -F '#{session_name}' | grep -c '^takili$')|$(grep -c '^TAKILI' "$T/defter")"
kapi "T6 tek argümanla çağrı → kullanım mesajı (bilinmeyen-argüman DEĞİL), rc 2" "1|2" "$(KA durum 2>&1 | grep -c 'kullanım:')|$(KA durum >/dev/null 2>&1; echo $?)"
echo "── F · ölçüm düşerse FAIL-CLOSED (yedek göz tur 3: eski hâl yaşayan Claude'u kapatırdı)"
printf '#!/usr/bin/env bash\nexit 3\n' > "$T/kb-bozuk.sh"; chmod +x "$T/kb-bozuk.sh"
KAB() { KB_OVERRIDE="$T/kb-bozuk.sh" KA "$@"; }
KA ac rolx >/dev/null 2>&1   # rolx canlı olsun
kapi "F1 liste betiği düşerse durum=olculemedi (claude-yok DEĞİL)" "olculemedi" "$(KAB durum rolx | j 'j["durum"]')"
out="$(KAB ac rolx 2>&1)"; rc=$?
kapi "F2 ölçülemeyen koltuğa zorlasız 'ac' DOKUNMAZ (rc 5, oturum yaşıyor)" "5|1" "$rc|$(tmux -L "$L" has-session -t =rolx 2>/dev/null && echo 1 || echo 0)"
printf '#!/usr/bin/env bash\n[ "$1" = --liste ] || exit 2\nprintf "baska\\t0\\t1\\tajan\\tcalisiyor\\n"\n' > "$T/kb-eksik.sh"; chmod +x "$T/kb-eksik.sh"
kapi "F3 liste gelir ama satır yoksa da olculemedi" "olculemedi" "$(KB_OVERRIDE="$T/kb-eksik.sh" KA durum rolx | j 'j["durum"]')"
echo "── N · olumsuz kontrol: ekip-ac.sh yoksa kayıtlı rol de açılmaz"
mv "$T/proje/scripts/ekip-ac.sh" "$T/proje/scripts/ekip-ac.sh.kapali"
kapi "N1 betik yokken yol=yok (sessizce başka yola düşmez)" "yok" "$(KA durum rolx | j 'j["yol"]')"
mv "$T/proje/scripts/ekip-ac.sh.kapali" "$T/proje/scripts/ekip-ac.sh"
echo; echo "GEÇEN: $gecen · KALAN: $kalan"; [ "$kalan" = 0 ]
