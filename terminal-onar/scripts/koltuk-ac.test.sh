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
# doğuran sürüm (merkez): argüman çözücüsü --resume-if-known ve --dry-run kollarını taşır (gerçek merkez betiğiyle aynı yapı)
rol="\$1"; shift; for a in "\$@"; do case "\$a" in
  --resume-if-known) : ;;
  --dry-run) exit 0 ;;
esac; done; ad="\$(printf '%s' "\$rol" | tr 'A-Z' 'a-z')"
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
    rolz)   if [ -f "$T/rolz-claude" ]; then printf '%s\t%s\t1\tajan\tcalisiyor\n' "\$s" "\$(date +%s)"; else printf '%s\t0\t0\tdiger\tbilinmiyor\n' "\$s"; fi ;;
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
KA() { HOME="$T/ev" TO_KUTU=sinav TO_PROJE="${KP:-$T/proje}" TO_BASLAT_BEKLE="${KBEK:-0.5}" TO_DURUM_DIZ="$T/durum" TO_KOLTUK_BETIK="${KB_OVERRIDE:-$T/kb.sh}" TO_ANA_TMUX=sinav-ana TO_BECERI_KOK="$T/beceri" \
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
echo "── Z · ANA koltuk aynı kapıdan geçer (yedek göz tur 4: --zorla onar dalında yok sayılıyor, onar.sh rc 0 → yanlış 'Açıldı')"
# ana oturum var ve liste onu TAKILI gösteriyor (Claude var, 2000 sn'dir ekran değişmedi)
tmux -L "$L" new-session -d -s sinav-ana "sleep 300"
printf '#!/usr/bin/env bash\n[ "$1" = --liste ] || exit 2\nprintf "sinav-ana\\t%%s\\t1\\tajan\\tcalisiyor\\n" "$(( $(date +%%s) - 2000 ))"\n' > "$T/kb-ana-takili.sh"; chmod +x "$T/kb-ana-takili.sh"
printf '#!/usr/bin/env bash\n[ "$1" = --liste ] || exit 2\nprintf "sinav-ana\\t%%s\\t1\\tajan\\tcalisiyor\\n" "$(date +%%s)"\n' > "$T/kb-ana-canli.sh"; chmod +x "$T/kb-ana-canli.sh"
: > "$T/defter"; out="$(KB_OVERRIDE="$T/kb-ana-takili.sh" KA ac sinav-ana 2>&1)"; rc=$?
kapi "Z1 takılı ANA koltuğa zorlasız 'ac' → rc 5, oturum yaşıyor, onar.sh ÇAĞRILMAZ" "5|1|0" "$rc|$(tmux -L "$L" has-session -t =sinav-ana 2>/dev/null && echo 1 || echo 0)|$(grep -c '^onar$' "$T/defter")"
: > "$T/defter"; out="$(KB_OVERRIDE="$T/kb-ana-takili.sh" KA ac sinav-ana --zorla 2>&1)"; rc=$?
kapi "Z2 takılı ANA koltuk --zorla → oturum KAPATILDI, onar.sh K0 çağrıldı, rc 0 (eski hâl: dokunmadan 'açıldı')" "0|0|1" "$rc|$(tmux -L "$L" has-session -t =sinav-ana 2>/dev/null && echo 1 || echo 0)|$(grep -c '^onar$' "$T/defter")"
tmux -L "$L" new-session -d -s sinav-ana "sleep 300"
: > "$T/defter"; out="$(KB_OVERRIDE="$T/kb-ana-canli.sh" KA ac sinav-ana 2>&1)"; rc=$?
kapi "Z3 canlı ANA koltuğa 'ac' → 'zaten canlı' rc 0, onar.sh çağrılmaz, oturum durur" "0|1|1|0" "$rc|$(echo "$out" | grep -c 'zaten canlı')|$(tmux -L "$L" has-session -t =sinav-ana 2>/dev/null && echo 1 || echo 0)|$(grep -c '^onar$' "$T/defter")"
tmux -L "$L" kill-session -t =sinav-ana 2>/dev/null
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
echo "── I · İSKÂN kutusu: açıcı baslat-claude.sh, kayıt iskan-registry.yaml (13 Eki canlı: enis'te kayıtlı koltuk 'kayıtsız' görünüyordu)"
# Bu kutuda ÜÇ kayıt da var (huzur/nazir/sedir/tez'deki gibi) ve ekip-ac.sh GRID sürümü (oturum doğurmaz, rol almaz).
# Doğru seçim: açıcı = baslat-claude.sh, kayıt = onun okuduğu iskan-registry.yaml. aile-registry'deki ROLZ başka tmux'a bağlı.
IK="$T/iskan"; mkdir -p "$IK/scripts" "$IK/_agents/handoff" "$IK/calis"
cat > "$IK/iskan-registry.yaml" <<Y
uyeler:
  - id: ROLZ
    tmux: "rolz:0"
    cwd: $IK/calis
    session_id: 99999999-2222-4333-8444-555555555555
  - id: ROLW
    tmux: "rolw:0"
    session_id: 88888888-2222-4333-8444-555555555555
Y
printf 'uyeler:\n  - id: AILEZ\n    tmux: "rolz:0"\n' > "$IK/_agents/handoff/aile-registry.yaml"
printf 'uyeler:\n  - id: EKIPZ\n    tmux: "rolz:0"\n' > "$IK/_agents/handoff/ekip-registry.yaml"
cat > "$IK/scripts/baslat-claude.sh" <<S
#!/usr/bin/env bash
echo "baslat \$1 \$(pwd)" >> "$T/defter"
[ -f "$T/baslat-dus" ] && exit 1
exec sleep 300
S
cat > "$IK/scripts/ekip-ac.sh" <<S
#!/usr/bin/env bash
# GRID sürümü (İSKÂN): EKIP_REGISTRY okur, var olanı tek pencerede toplar, oturum DOĞURMAZ
echo "grid \$*" >> "$T/defter"
S
chmod +x "$IK/scripts/"*.sh
: > "$T/ev/.claude/projects/p/99999999-2222-4333-8444-555555555555.jsonl"
KI() { KP="$IK" KA "$@"; }
: > "$T/defter"
kapi "I1 İSKÂN koltuğu → yol=baslat, rol iskan kaydından (AILEZ/EKIPZ DEĞİL), konuşma var → resume" "yok|baslat|ROLZ|true" "$(KI durum rolz | j '"|".join([j["durum"],j["yol"],j["rol"],str(j["resume"]).lower()])')"
kapi "I2 konuşması olmayan rol → resume=false" "baslat|false" "$(KI durum rolw | j 'j["yol"]+"|"+str(j["resume"]).lower()')"
out="$(KI ac rolz 2>&1)"; rc=$?
kapi "I3 ölü İSKÂN koltuğu tek komutla geri geldi: rc 0, oturum var, baslat-claude.sh ROLZ kayıttaki cwd'de" "0|1|baslat ROLZ $IK/calis" "$rc|$(tmux -L "$L" has-session -t =rolz 2>/dev/null && echo 1 || echo 0)|$(grep '^baslat' "$T/defter" | tail -1)"
kapi "I4 GRID ekip-ac.sh hiç çağrılmadı" "0" "$(grep -c '^grid' "$T/defter")"
: > "$T/rolz-claude"; out="$(KI ac rolz 2>&1)"
kapi "I5 canlıyken yeniden 'aç' → ikinci kopya AÇILMAZ, baslat ikinci kez çağrılmaz" "1|1|1" "$(tmux -L "$L" list-sessions -F '#{session_name}' | grep -c '^rolz$')|$(echo "$out" | grep -c 'zaten canlı')|$(grep -c '^baslat' "$T/defter")"
rm -f "$T/rolz-claude"; out="$(KI ac rolz 2>&1)"; rc=$?
kapi "I6 Claude'suz İSKÂN oturumu kapatılıp baslat ile yeniden doğar (rc 0, tek oturum, baslat 2. kez)" "0|1|2" "$rc|$(tmux -L "$L" list-sessions -F '#{session_name}' | grep -c '^rolz$')|$(grep -c '^baslat' "$T/defter")"
tmux -L "$L" kill-session -t =rolz; : > "$T/baslat-dus"
out="$(KI ac rolz 2>&1)"; rc=$?
kapi "I7 baslat-claude.sh düşerse 'açıldı' DENMEZ: rc 1, sebep söylenir, oturum kalmaz" "1|1|0" "$rc|$(echo "$out" | grep -c 'düştü')|$(tmux -L "$L" has-session -t =rolz 2>/dev/null && echo 1 || echo 0)"
rm -f "$T/baslat-dus"
echo "── V · DAVA kolu (Dava Rafı B10): rol: dava → claude --resume <session_id>, baslat-claude.sh ÇAĞRILMAZ"
# 16 Eki ölçüldü (2.1.301): baslat-claude.sh'nin koştuğu `claude --session-id <id>` konuşması VAR olan kimlikte "already in use" deyip çıkar.
cat >> "$IK/iskan-registry.yaml" <<Y
  - id: 2025/42
    rol: dava
    tmux: "veli-dava:0"
    arz_adi: "İşçilik alacağı"
    session_id: 77777777-2222-4333-8444-555555555555
    cwd: $IK/calis
    bagla_ile: true
  - id: 2025/43
    rol: dava
    tmux: "yeni-dava:0"
    session_id: 66666666-2222-4333-8444-555555555555
Y
: > "$T/ev/.claude/projects/p/77777777-2222-4333-8444-555555555555.jsonl"
printf '#!/usr/bin/env bash\necho "claude $* $(pwd)" >> "%s"\nexec sleep 300\n' "$T/defter" > "$T/claude"; chmod +x "$T/claude"
kapi "V1 dava satırı → yol=dava, rol = dosya no, konuşma var → resume" "yok|dava|2025/42|true" "$(KI durum veli-dava | j '"|".join([j["durum"],j["yol"],j["rol"],str(j["resume"]).lower()])')"
: > "$T/defter"; out="$(TO_CLAUDE="$T/claude" KI ac veli-dava --eski 2>&1)"; rc=$?; sleep 0.3
kapi "V2 aç → rc 0, oturum var, claude --resume <kayıttaki session_id> kayıttaki cwd'de; baslat-claude.sh ÇAĞRILMADI" "0|1|claude --resume 77777777-2222-4333-8444-555555555555 $IK/calis|0" "$rc|$(tmux -L "$L" has-session -t =veli-dava 2>/dev/null && echo 1 || echo 0)|$(grep '^claude' "$T/defter" | tail -1)|$(grep -c '^baslat' "$T/defter")"
out="$(TO_CLAUDE="$T/claude" KI ac yeni-dava --eski 2>&1)"; rc=$?
kapi "V3 konuşması olmayan dava AÇILMAZ (kimliksiz Claude yok): rc 1, sebep söylenir, oturum doğmaz" "1|1|0" "$rc|$(echo "$out" | grep -c 'eski sohbeti bulunamadı')|$(tmux -L "$L" has-session -t =yeni-dava 2>/dev/null && echo 1 || echo 0)"
tmux -L "$L" kill-session -t =veli-dava 2>/dev/null
out="$(TO_CLAUDE="$T/yok-claude" KI ac veli-dava --eski 2>&1)"; rc=$?
kapi "V4 claude bulunamazsa 'açıldı' DENMEZ: rc 1, oturum doğmaz" "1|1|0" "$rc|$(echo "$out" | grep -c 'claude bu kutuda bulunamadı')|$(tmux -L "$L" has-session -t =veli-dava 2>/dev/null && echo 1 || echo 0)"
kapi "V5 dava olmayan İSKÂN koltuğu yine baslat yolunda (dava kolu onu ele geçirmez)" "baslat" "$(KI durum rolw | j 'j["yol"]')"
echo "── G · GRID ekip-ac.sh açıcı sayılmaz (İSKÂN öncesi yarım kutu: baslat yok, aile kaydında rol var)"
GK="$T/grid"; mkdir -p "$GK/scripts" "$GK/_agents/handoff"
printf 'uyeler:\n  - id: ROLG\n    tmux: "rolg:0"\n' > "$GK/_agents/handoff/aile-registry.yaml"
cp "$IK/scripts/ekip-ac.sh" "$GK/scripts/ekip-ac.sh"; : > "$T/defter"
kapi "G1 yalnız GRID ekip-ac varken kayıtlı rol bile yol=yok (koltuğu kapatıp geri getirmeyen yola düşmez)" "yok|ROLG" "$(KP="$GK" KA durum rolg | j 'j["yol"]+"|"+j["rol"]')"
tmux -L "$L" new-session -d -s rolg "sleep 300"; out="$(KP="$GK" KA ac rolg 2>&1)"; rc=$?
kapi "G2 'ac' rc 4, oturum KAPATILMADI, grid çağrılmadı" "4|1|0" "$rc|$(tmux -L "$L" has-session -t =rolg 2>/dev/null && echo 1 || echo 0)|$(grep -c '^grid' "$T/defter")"
echo "── Y · yorumda geçen bayrak açıcı yapmaz; betik rc 0 dese de oturum yoksa 'açıldı' denmez (yedek göz tur 2)"
YK="$T/yorum"; mkdir -p "$YK/scripts" "$YK/_agents/handoff"
printf 'uyeler:\n  - id: ROLY2\n    tmux: "roly2:0"\n' > "$YK/_agents/handoff/aile-registry.yaml"
printf '#!/usr/bin/env bash\n# not: merkez sürümü --resume-if-known ve --dry-run bilir, bu grid sürümü bilmez\necho "grid $*" >> "%s"\n' "$T/defter" > "$YK/scripts/ekip-ac.sh"; chmod +x "$YK/scripts/ekip-ac.sh"; : > "$T/defter"
kapi "Y1 bayrak yalnız YORUMDA geçen ekip-ac.sh açıcı sayılmaz (yol=yok)" "yok" "$(KP="$YK" KA durum roly2 | j 'j["yol"]')"
tmux -L "$L" new-session -d -s roly2 "sleep 300"; out="$(KP="$YK" KA ac roly2 2>&1)"; rc=$?
kapi "Y2 o koltukta 'ac' rc 4, oturum KAPATILMADI, betik çağrılmadı" "4|1|0" "$rc|$(tmux -L "$L" has-session -t =roly2 2>/dev/null && echo 1 || echo 0)|$(grep -c '^grid' "$T/defter")"
YD="$T/yarim"; mkdir -p "$YD/scripts" "$YD/_agents/handoff"
printf 'uyeler:\n  - id: ROLV\n    tmux: "rolv:0"\n' > "$YD/_agents/handoff/aile-registry.yaml"
printf '#!/usr/bin/env bash\nfor a in "$@"; do case "$a" in\n  --resume-if-known) : ;;\n  --dry-run) exit 0 ;;\nesac; done\necho "yarim $*" >> "%s"; exit 0\n' "$T/defter" > "$YD/scripts/ekip-ac.sh"; chmod +x "$YD/scripts/ekip-ac.sh"
out="$(KP="$YD" KA ac rolv 2>&1)"; rc=$?
kapi "Y3 doğuran görünen betik rc 0 döner ama oturum doğmaz → 'açıldı' DENMEZ, rc 1, sebep söylenir" "1|1|1" "$rc|$(echo "$out" | grep -c "oturumu yok")|$(grep -c '^yarim ROLV' "$T/defter")"
# iki kol BİRLİKTE şart: biri çözücüde, öteki yalnız yorumdaysa açıcı DEĞİL (iki koşul birbirini örtmesin — mutasyon KO9 dersi)
YT="$T/tekkol"; mkdir -p "$YT/scripts" "$YT/_agents/handoff"
printf 'uyeler:\n  - id: ROLT\n    tmux: "rolt:0"\n' > "$YT/_agents/handoff/aile-registry.yaml"
printf '#!/usr/bin/env bash\n# --resume-if-known burada yalnız yorum\nfor a in "$@"; do case "$a" in\n  --dry-run) exit 0 ;;\nesac; done\n' > "$YT/scripts/ekip-ac.sh"; chmod +x "$YT/scripts/ekip-ac.sh"
kapi "Y4 --dry-run kolu var, --resume-if-known yalnız yorumda → açıcı değil (yol=yok)" "yok" "$(KP="$YT" KA durum rolt | j 'j["yol"]')"
printf '#!/usr/bin/env bash\n# --dry-run burada yalnız yorum\nfor a in "$@"; do case "$a" in\n  --resume-if-known) : ;;\nesac; done\n' > "$YT/scripts/ekip-ac.sh"
kapi "Y5 --resume-if-known kolu var, --dry-run yalnız yorumda → açıcı değil (yol=yok)" "yok" "$(KP="$YT" KA durum rolt | j 'j["yol"]')"
echo; echo "GEÇEN: $gecen · KALAN: $kalan"; [ "$kalan" = 0 ]
