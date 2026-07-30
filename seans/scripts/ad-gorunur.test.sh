#!/usr/bin/env bash
# ad-gorunur.test.sh — "verdiğim ad gerçekten görünüyor mu" kapısı.
#
# NİÇİN VAR: `yenisession` adı SORUYOR ama kullanmıyordu; "şunu çalıştır" diye bir satır basıp
# devrediyordu ve o satır Claude açılınca ekrandan kayboluyordu. Kullanıcı adını yazıyor,
# hiçbir yere gitmiyordu (firsthand 2026-07-30). Bu test o yolun geri kırılmasını engeller.
#
# Yöntem: gerçek tmux/claude çağırmıyoruz — PATH'e sahte tmux koyup argümanları YAKALIYORUZ.
# Böylece "hangi pencere adıyla açılıyor" iddiası ölçülebilir hâle geliyor.
set -uo pipefail
BURASI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CS="$BURASI/cs.sh"
YENI="$BURASI/yenisession"
gecici="$(mktemp -d -t adtest-XXXXXX)"
temizle() { [ -d "$gecici" ] && find "$gecici" -mindepth 1 -delete 2>/dev/null; rmdir "$gecici" 2>/dev/null; }
trap temizle EXIT

gecen=0; kalan=0
g() { if [ "$1" = 0 ]; then echo "  ✓ $2"; gecen=$((gecen+1)); else echo "  ✗ $2"; kalan=$((kalan+1)); fi; }

# Sahte tmux: çağrıldığı argümanları dosyaya yazar, hiçbir şey açmaz.
mkdir -p "$gecici/bin" "$gecici/proje"
cat > "$gecici/bin/tmux" <<'T'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TMUX_LOG"
case "${1:-}" in
  has-session) exit 1 ;;   # dışarıdan arama: oturum yok say
  *) exit 0 ;;
esac
T
cat > "$gecici/bin/claude" <<'C'
#!/usr/bin/env bash
printf 'CLAUDE %s\n' "$*" >> "$TMUX_LOG"
C
chmod +x "$gecici/bin/tmux" "$gecici/bin/claude"

kos() { # log-dosyasi, argümanlar...
  local log="$1"; shift
  : > "$log"
  TMUX_LOG="$log" PATH="$gecici/bin:$PATH" TMUX="" \
    bash "$CS" "$@" >/dev/null 2>&1
}

echo "── cs new --ad: pencere adı VERİLEN ad olmalı ──"
L1="$gecici/l1.txt"; kos "$L1" new --ad "sultan" "$gecici/proje"
grep -q 'new-session .*-n sultan' "$L1"; g $? "pencere adı 'sultan' (verilen ad)"
grep -q 'new-session -s cc-' "$L1"; g $? "oturum adı cc-<id> KALDI (attach tutamağı bozulmadı)"
! grep -q -- '-n proje' "$L1"; g $? "proje adı pencereye yazılmadı"

echo "── ad verilmezse davranış ESKİSİ gibi (regresyon yok) ──"
L2="$gecici/l2.txt"; kos "$L2" new "$gecici/proje"
grep -q -- '-n proje' "$L2"; g $? "ad yoksa pencere adı proje adı"

echo "── yenisession ad'ı motora GEÇİRİYOR mu ──"
# cs.sh yerine argümanları yazan bir sahte motor koy.
cat > "$gecici/bin/fake-cs" <<'F'
#!/usr/bin/env bash
printf 'CS %s\n' "$*" >> "$TMUX_LOG"
F
chmod +x "$gecici/bin/fake-cs"
L3="$gecici/l3.txt"; : > "$L3"
TMUX_LOG="$L3" SEANS_CS="$gecici/bin/fake-cs" PATH="$gecici/bin:$PATH" \
  bash "$YENI" "randevu ekrani" >/dev/null 2>&1
grep -q 'CS new --ad randevu ekrani' "$L3"; g $? "yenisession '--ad <isim>' ile çağırıyor"
! grep -q 'cs rename current' "$L3"; g $? "artık kullanıcıya iş yükleyen satır BASILMIYOR"
L4="$gecici/l4.txt"; : > "$L4"
TMUX_LOG="$L4" SEANS_CS="$gecici/bin/fake-cs" PATH="$gecici/bin:$PATH" \
  bash "$YENI" >/dev/null 2>&1 </dev/null
grep -q 'CS new$' "$L4"; g $? "ad yoksa sade 'new' (eski yol)"

echo "── cs rename alt çubuğu da etiketliyor mu ──"
grep -q '_tmux_pencere_adlandir "\$sid" "\$name"' "$CS"; g $? "rename, pencere-etiketleyiciyi çağırıyor"
grep -q 'rename-window -t "\$hedef" "\$name"' "$CS"; g $? "etiketleyici tmux rename-window kullanıyor"
grep -q 'alt çubuk etiketlenemedi' "$CS"; g $? "yapamazsa SESSİZ geçmiyor (ölçemedim ≠ yaptım)"
! grep -q 'rename-session' "$CS"; g $? "oturum adına DOKUNMUYOR (attach tutamağı korunur)"

echo "── çalıştırma bitleri: her senkron 'cs'i kırmasın ──"
eksik=0
for f in basla cs.sh ekip-durum.sh gruba seans-kur.sh sessiongetir yardim yenisession; do
  m="$(git -C "$BURASI" ls-files -s "$f" 2>/dev/null | awk '{print $1}')"
  [ "$m" = "100755" ] || { echo "    ✗ $f git kipi=$m (755 olmalı)"; eksik=1; }
done
[ "$eksik" = 0 ]; g $? "sekiz betik de git'te çalıştırılabilir (100755)"

echo ""
echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" = 0 ] || exit 1
