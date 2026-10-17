#!/usr/bin/env bash
# dava-resume-olc.sh — Dava Rafı B10 ölçümü GERÇEK claude ikilisiyle (sahte yok): eski sohbete dönüş hangi yolla çalışır?
#   1) gerçek bir konuşma doğurur (claude -p --session-id <yeni>) — içinde ayırt edici bir söz
#   2) İSKÂN açıcısının yolu: aynı kimlikle `claude --session-id` → beklenen: "already in use" (baslat-claude.sh bunu koşar)
#   3) koltuk-ac.sh (BU kopya) ile İSKÂN düzenli sahte proje: dava satırı `ac --eski` → gerçek tmux'ta (yalıtılmış soket) gerçek
#      claude --resume açılır; ekranda eski sohbetin sözü görünmeli; baslat-claude.sh ÇAĞRILMAMALI
# OLCUM_CWD: konuşmanın dizini — Claude'un GÜVENDİĞİ bir dizin olmalı (kutuda dava proje kökünde açılır; güvenilmeyen dizinde
#   etkileşimli Claude önce güven sorusu sorar → ölçüm onu "ÖLÇÜLEMEDİ" diye söyler, tuşa basmaz).
# Yan etki: iki küçük model çağrısı (haiku) + geçici dizin; kendi tmux soketi (TMUX_TMPDIR), kutunun oturumlarına dokunmaz.
# rc: 0 hepsi tuttu · 1 biri tutmadı · 3 ÖLÇÜLEMEDİ (claude/tmux yok ya da güven sorusu)
set -uo pipefail
D0="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v claude >/dev/null && command -v tmux >/dev/null || { echo "ÖLÇÜLEMEDİ: claude ya da tmux yok"; exit 3; }
T="$(mktemp -d)"; export TMUX_TMPDIR="$T/sok"; mkdir -p "$TMUX_TMPDIR" "$T/proje/scripts" "$T/durum"
# 🔴 $TMUX varken tmux istemcisi TMUX_TMPDIR'ı DEĞİL $TMUX soketini kullanır → aşağıdaki kill-server KUTUNUN sunucusunu
#    öldürüyordu (17 Eki 2026: 4 kez tüm aile oturumları gitti). Ölçüm kendi soketinde kalsın: $TMUX sökülür.
unset TMUX   # bundan sonra betiğin ve çağırdığı koltuk-ac.sh'nin her tmux çağrısı TMUX_TMPDIR'daki yalıtılmış sunucuya gider
CW="${OLCUM_CWD:-$PWD}"
trap 'tmux kill-server 2>/dev/null; python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], True)" "$T"' EXIT
g=0; k=0; kapi() { if [ "$2" = 1 ]; then g=$((g+1)); echo "  ✓ $1"; else k=$((k+1)); echo "  ✗ $1 — $3"; fi; }
echo "claude: $(claude --version 2>&1 | head -1) · dizin: $CW"
# OLCUM_SID: mevcut (eski kutu) oturumu — yeni konuşma doğurulmaz; transkript + ayırt edici söz (OLCUM_SOZ) denetlenir
if [ -n "${OLCUM_SID:-}" ]; then
  SID="$OLCUM_SID"; SOZ="${OLCUM_SOZ:?OLCUM_SOZ gerekli (eski oturumda geçen ayırt edici kelime)}"
  TR="$(ls "$HOME"/.claude/projects/*/"$SID".jsonl 2>/dev/null | head -1)"
  kapi "1 eski oturum transkripti var ve ayırt edici söz içinde ('$SOZ')" "$([ -n "$TR" ] && grep -q "$SOZ" "$TR" && echo 1)" "transkript: ${TR:-YOK}"
else
SID="$(python3 -c 'import uuid;print(uuid.uuid4())')"; SOZ="mor-zeytin-$$"
o1="$(cd "$CW" && timeout 120 claude -p --model haiku --session-id "$SID" "Yalnız şunu yaz: $SOZ" < /dev/null 2>&1)"
kapi "1 gerçek konuşma doğdu (cevapta söz var)" "$(echo "$o1" | grep -q "$SOZ" && echo 1)" "$o1"
fi
o2="$(cd "$CW" && timeout 120 claude -p --model haiku --session-id "$SID" "x" < /dev/null 2>&1)"
kapi "2 aynı kimlikle --session-id (baslat-claude.sh yolu) → 'already in use', eski sohbete DÖNMEZ" "$(echo "$o2" | grep -qi 'already in use' && echo 1)" "$o2"
cat > "$T/proje/iskan-registry.yaml" <<Y
dava_kurali: {tavan: 4, gun: 14}
uyeler:
  - id: 2025/42
    rol: dava
    tmux: "olcum-dava:0"
    arz_adi: "Ölçüm"
    session_id: $SID
    cwd: $CW
    bagla_ile: true
Y
printf '#!/usr/bin/env bash\necho "baslat $*" >> "%s/baslat-iz"\nexec sleep 60\n' "$T" > "$T/proje/scripts/baslat-claude.sh"; chmod +x "$T/proje/scripts/baslat-claude.sh"
o3="$(TO_KUTU=olcum TO_PROJE="$T/proje" TO_DURUM_DIZ="$T/durum" TO_ANA_TMUX=olcum-ana TO_BASLAT_BEKLE=4 bash "$D0/koltuk-ac.sh" ac olcum-dava --eski 2>&1)"; rc=$?
kapi "3 koltuk-ac ac --eski → rc 0, 'claude --resume' kolu" "$([ $rc = 0 ] && echo "$o3" | grep -q 'claude --resume' && echo 1)" "rc=$rc $o3"
ekran=""; for _ in $(seq 1 40); do
  ekran="$(tmux capture-pane -p -t =olcum-dava -S -200 2>/dev/null)"
  echo "$ekran" | grep -q "$SOZ" && break
  echo "$ekran" | grep -qi 'trust' && { echo "ÖLÇÜLEMEDİ: dizin güvenilir değil (güven sorusu çıktı) — OLCUM_CWD'yi güvenilen bir dizin ver"; echo "$ekran" | tail -8; exit 3; }
  python3 -c 'import time; time.sleep(1)'
done
kapi "4 açılan oturumda gerçek Claude ESKİ SOHBETİ gösteriyor (ekranda '$SOZ')" "$(echo "$ekran" | grep -q "$SOZ" && echo 1)" "$(echo "$ekran" | tail -15)"
kapi "5 baslat-claude.sh ÇAĞRILMADI" "$([ ! -s "$T/baslat-iz" ] && echo 1)" "$(cat "$T/baslat-iz" 2>/dev/null)"
echo; echo "SONUÇ: $g tuttu · $k tutmadı"; [ "$k" = 0 ]
