#!/usr/bin/env bash
# ekip-onizleme.test.sh — golden testler. GERÇEK tmux kullanır ama İZOLE bir tmux sunucusunda
# (kendi socket'i: -L) → çalışan ekiplerin oturumlarına ASLA dokunmaz.
# Koş: bash ekip/scripts/ekip-onizleme.test.sh ; echo exit=$?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$HERE/ekip-onizleme.sh"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); echo "PASS  $1"; }
no(){ FAIL=$((FAIL+1)); echo "FAIL  $1"; echo "      $2"; }
esit(){ [ "$2" = "$3" ] && ok "$1" || no "$1" "beklenen=[$2] gelen=[$3]"; }

command -v tmux >/dev/null 2>&1 || { echo "ATLA: tmux yok — bu ortamda test koşulamaz (dürüst-atlama)"; exit 0; }

TMP="$(mktemp -d)"; SOCK="ekiptest$$"
temizle(){ tmux -L "$SOCK" kill-server >/dev/null 2>&1 || true; rm -rf "$TMP"; }
trap temizle EXIT

# İZOLASYON: SUT'un çağırdığı tmux, testin özel socket'ine bağlansın.
# ⚠️ MUTLAK yol şart: sarmalayıcı `env tmux` deseydi PATH önce $TMP/bin'i bulur → SONSUZ ÖZYİNELEME
# (ilk yazımda bu tuzağa düşüldü: test 3dk timeout'a çarptı, tmux sunucuları sızdı).
REAL_TMUX="$(command -v tmux)"
mkdir -p "$TMP/bin"
printf '#!/usr/bin/env bash\nexec %s -L %s "$@"\n' "$REAL_TMUX" "$SOCK" > "$TMP/bin/tmux"
chmod +x "$TMP/bin/tmux"

mkdir -p "$TMP/repo/_agents/handoff" "$TMP/repo/scripts"
cat > "$TMP/repo/_agents/handoff/ekip-registry.yaml" <<'YAML'
meta:
  ekip: "test-ekibi"
uyeler:
  - id: t-yon
    tmux: "t-yon:0"
    rol: "yonetici"
  - id: t-uye
    tmux: "t-uye:0"
    rol: "uye"
YAML
# Sahte başlatıcı: GERÇEK claude'un ps-imzasını taklit eder — tespit `claude … --name <masa>`
# desenine bakar (firsthand: canlı ps çıktısı). `exec -a` ile argv[0] o imzayı taşır.
cat > "$TMP/repo/scripts/baslat-claude.sh" <<'SH'
#!/usr/bin/env bash
exec -a "claude --session-id 00000000-0000-0000-0000-000000000000 --name $1 --permission-mode default" sleep 300
SH
chmod +x "$TMP/repo/scripts/baslat-claude.sh"

E=(EKIP_REPO_ROOT="$TMP/repo" EKIP_REGISTRY="$TMP/repo/_agents/handoff/ekip-registry.yaml")

# ── T1: SALT-OKUR mod hiçbir oturum AÇMAZ (yıkıcı-değil kanıtı) ──────────────
out="$(env "${E[@]}" PATH="$TMP/bin:$PATH" bash "$SUT" --kontrol --porcelain 2>&1)"; rc=$?
n_oturum="$(tmux -L "$SOCK" ls 2>/dev/null | wc -l | tr -d ' ')"
esit "T1 kontrol modu oturum açmaz" "0" "$n_oturum"
esit "T1 eksik varken exit=1 (sahte-yeşil yok)" "1" "$rc"
printf '%s' "$out" | grep -q 'oturum-yok' \
  && ok "T1 durum 'oturum-yok' raporlanıyor" || no "T1 durum satırı yok" "$out"

# ── T2: ONAR modu eksik oturumları AÇAR ve başlatıcıyı koşturur ──────────────
out="$(env "${E[@]}" PATH="$TMP/bin:$PATH" bash "$SUT" --porcelain 2>&1)"; rc=$?
sess="$(tmux -L "$SOCK" ls -F '#{session_name}' 2>/dev/null | sort | tr '\n' ' ')"
esit "T2 iki oturum da açıldı" "t-uye t-yon " "$sess"
printf '%s' "$out" | grep -q '#ONARIM' \
  && ok "T2 onarım raporlanıyor (ne yapıldığı görünür)" || no "T2 onarım raporu yok" "$out"

# ── T3: ikinci koşu IDEMPOTENT — çalışanı yeniden başlatmaz ─────────────────
pid_once="$(tmux -L "$SOCK" list-panes -a -F '#{pane_pid}' 2>/dev/null | sort | tr '\n' ' ')"
out="$(env "${E[@]}" PATH="$TMP/bin:$PATH" bash "$SUT" --porcelain 2>&1)"
pid_sonra="$(tmux -L "$SOCK" list-panes -a -F '#{pane_pid}' 2>/dev/null | sort | tr '\n' ' ')"
esit "T3 idempotent: pane süreçleri AYNI (yeniden başlatılmadı)" "$pid_once" "$pid_sonra"
printf '%s' "$out" | grep -q '#ONARIM' \
  && no "T3 gereksiz onarım yapıldı" "$out" || ok "T3 ikinci koşuda onarım YOK (dokunulmadı)"

# ── T4: kayıtta-olmayan oturum RAPORLANIR ama SİLİNMEZ (yıkıcı-değil) ───────
tmux -L "$SOCK" new-session -d -s yabanci "sleep 300" 2>/dev/null
out="$(env "${E[@]}" PATH="$TMP/bin:$PATH" bash "$SUT" --porcelain 2>&1)"
printf '%s' "$out" | grep -q 'fazla=.*yabanci' \
  && ok "T4 kayıt-dışı oturum raporlanıyor" || no "T4 kayıt-dışı oturum raporlanmadı" "$out"
tmux -L "$SOCK" has-session -t yabanci 2>/dev/null \
  && ok "T4 kayıt-dışı oturum SİLİNMEDİ (yıkıcı-değil)" || no "T4 oturum silindi — yıkıcı davranış" ""

# ── T5: masada BAŞKA iş koşuyorsa DOKUNULMAZ (iş kesilmez) ─────────────────
tmux -L "$SOCK" kill-session -t t-uye 2>/dev/null
tmux -L "$SOCK" new-session -d -s t-uye "sleep 400" 2>/dev/null
pid_mesgul="$(tmux -L "$SOCK" list-panes -t t-uye -F '#{pane_pid}' 2>/dev/null)"
env "${E[@]}" PATH="$TMP/bin:$PATH" bash "$SUT" --porcelain >/dev/null 2>&1
pid_sonra2="$(tmux -L "$SOCK" list-panes -t t-uye -F '#{pane_pid}' 2>/dev/null)"
esit "T5 meşgul masaya dokunulmadı (pane süreci aynı)" "$pid_mesgul" "$pid_sonra2"

# ── T6: fail-closed — kayıt yoksa exit=2, uydurma tablo YOK ────────────────
out="$(EKIP_REPO_ROOT="$TMP/bos" EKIP_REGISTRY="$TMP/yok.yaml" PATH="$TMP/bin:$PATH" bash "$SUT" --kontrol 2>&1)"; rc=$?
esit "T6 kayıt-yok exit=2" "2" "$rc"
printf '%s' "$out" | grep -q 'AJAN\|çalışıyor' \
  && no "T6 kayıt yokken tablo basıldı (uydurma)" "$out" || ok "T6 kayıt yokken tablo basılmadı"

# ── T7: boş roster fail-closed (0 üye → 'hepsi ayakta' DEME) ───────────────
printf 'meta:\n  ekip: bos\nuyeler:\n' > "$TMP/bos.yaml"
EKIP_REPO_ROOT="$TMP/repo" EKIP_REGISTRY="$TMP/bos.yaml" PATH="$TMP/bin:$PATH" bash "$SUT" --kontrol >/dev/null 2>&1; rc=$?
esit "T7 boş roster exit=2 (sahte-yeşil yok)" "2" "$rc"

echo "─────────────────────────────"
echo "TOPLAM: $PASS PASS · $FAIL FAIL"
[ "$FAIL" -eq 0 ] || exit 1
