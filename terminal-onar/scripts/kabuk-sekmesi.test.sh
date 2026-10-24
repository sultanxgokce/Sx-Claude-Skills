#!/usr/bin/env bash
# El kabuğu sekmesi (gorev_…GT5BTK · Sultan 22 Eki): her kutuda Claude'suz, sabit, BOŞ kabuk — <kutu>-kabuk.
#   kabuk_kur (ortak.sh) yalnız YOKSA kurar · var olanı öldürmez/içine yazmaz · kurulamazsa günlüğe yalnız DEĞİŞİNCE yazar.
#   Çağıranlar: onar.sh (1b) + bekci.sh (her tur; sağlık ölçüsüne GİRMEZ — merdiven tırmanıp Claude açtırmasın).
#   Görünürlük: koltuk listesinde gizli DEĞİL; kadroda altyapı (kapatılamaz).
# 🔴 GERÇEK tmux, KENDİ soketinde (PATH'teki sarmalayıcı -S ile yönlendirir) — kutunun oturumlarına dokunmaz.
set -u
export KOLTUK_TUZ="$(mktemp -d)/tuz"   # 2.24.0: kimlik tuzu geçici yolda (gerçek $HOME'a dokunulmaz)
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gecen=0; kalan=0
kapi(){ if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
command -v tmux >/dev/null || { echo "ÖLÇÜLEMEDİ: tmux yok"; exit 3; }
GERCEK_TMUX="$(command -v tmux)"
T=$(mktemp -d); S="$T/sok"; mkdir -p "$T/bin" "$T/proje" "$T/durum"
trap 'TMUX= "$GERCEK_TMUX" -S "$S" kill-server 2>/dev/null; python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], True)" "$T"' EXIT
cat > "$T/bin/tmux" <<EOF
#!/usr/bin/env bash
[ -f "$T/bozuk" ] && [ "\$1" = new-session ] && exit 1     # K3: kurulamayan kabuk taklidi
exec env TMUX= "$GERCEK_TMUX" -S "$S" "\$@"
EOF
chmod +x "$T/bin/tmux"
export PATH="$T/bin:$PATH" TO_KUTU=sinav TO_DURUM_DIZ="$T/durum" TO_PROJE="$T/proje"
# shellcheck disable=SC1091
. "$KOK/scripts/ortak.sh" || { echo "ortak.sh source edilemedi"; exit 2; }
# 🔴 ortak.sh PATH'in BAŞINA /config/.local/bin koyar → sahte tmux kaybolur ve sınav kutunun GERÇEK sunucusunda oturum açar
#    (22 Eki ilk koşuda ölçüldü: gerçek sunucuda sinav-kabuk doğdu). Sarmalayıcı yeniden başa alınır ve pozitif kontrolle sınanır.
export PATH="$T/bin:$PATH"
GERCEK_ONCE=$(TMUX= "$GERCEK_TMUX" ls 2>/dev/null | grep -c '^sinav-kabuk:')
satir() { grep -c "el kabuğu" "$GUNLUK" 2>/dev/null || echo 0; }

echo "── K · kabuk_kur"
kapi "K0 ad türetimi: <kutu>-kabuk" "sinav-kabuk" "$KABUK_TMUX"
kabuk_kur; rc=$?
kapi "K1 yoksa KURULUR (rc 0, oturum var)" "0 e" "$rc $(tmux has-session -t "=sinav-kabuk" 2>/dev/null && echo e || echo h)"
kapi "K1b proje dizininde açılır" "$T/proje" "$(tmux display-message -p -t "=sinav-kabuk:" '#{pane_current_path}')"
kapi "K1c Claude BAŞLATILMAZ (pane'de kabuk koşar)" "h" "$(tmux display-message -p -t "=sinav-kabuk:" '#{pane_current_command}' | grep -qi claude && echo e || echo h)"
kapi "K1d günlükte tek kuruldu satırı" "1" "$(satir)"
id1=$(tmux display-message -p -t "=sinav-kabuk:" '#{session_id}')
tmux send-keys -t "=sinav-kabuk:" "echo yarim-komut"   # Enter YOK: Sultan'ın yarım komutu
sleep 0.3
kabuk_kur; rc=$?
kapi "K2a oturum kimliği okunabildi (boş = boş yanlış eşitliği olmasın)" "e" "$([ -n "$id1" ] && echo e || echo h)"
kapi "K2 varsa DOKUNULMAZ (aynı oturum kimliği)" "0 $id1" "$rc $(tmux display-message -p -t "=sinav-kabuk:" '#{session_id}')"
kapi "K2b yarım komut kaybolmaz" "1" "$(tmux capture-pane -p -t "=sinav-kabuk:" | grep -c 'yarim-komut')"
kapi "K2c var olana ikinci kuruldu satırı YAZILMAZ" "1" "$(satir)"
tmux kill-session -t "=sinav-kabuk"; touch "$T/bozuk"
kabuk_kur; rc1=$?; kabuk_kur; rc2=$?; kabuk_kur
kapi "K3 kurulamazsa rc 1 (her denemede)" "1 1" "$rc1 $rc2"
kapi "K3b kurulamama günlüğe YALNIZ BİR KEZ (değişince) yazılır" "1" "$(grep -c 'el kabuğu sinav-kabuk kurulamadı' "$GUNLUK")"
python3 -c "import os,sys; os.remove(sys.argv[1])" "$T/bozuk"
kabuk_kur; rc=$?
kapi "K3c düzelince yeniden kurulur ve durum ok olur" "0 ok" "$rc $(cat "$DURUM_DIZ/kabuk.son")"

# K5 yarış (göz #415): kabuk 'yok' görüldükten SONRA başkası kurar → new-session düşer ama oturum vardır → hata DEĞİL
tmux kill-session -t "=sinav-kabuk"; h0=$(grep -c 'kurulamadı' "$GUNLUK")
tmux_var() { [ "$1" = sinav-kabuk ] && [ -z "${_yaris_bir:-}" ] && { _yaris_bir=1; command tmux new-session -d -s sinav-kabuk -c "$PROJE"; return 1; }; command tmux has-session -t "=$1" 2>/dev/null; }
kabuk_kur; rc=$?; unset -f tmux_var; tmux_var() { tmux has-session -t "=$1" 2>/dev/null; }
kapi "K5 yarışta (biri kurdu, öbürünün new-session'ı düştü) rc 0, durum ok" "0 ok" "$rc $(cat "$DURUM_DIZ/kabuk.son")"
kapi "K5b yarışta yanıltıcı 'kurulamadı' satırı YAZILMAZ" "$h0" "$(grep -c 'kurulamadı' "$GUNLUK")"
tmux kill-session -t "=sinav-kabuk"
TO_KABUK_YOK=1 kabuk_kur; rc=$?
kapi "K4 TO_KABUK_YOK=1 → hiçbir şey kurulmaz (gerçek tmux koşturan sınavların kalkanı)" "0 h" "$rc $(tmux has-session -t "=sinav-kabuk" 2>/dev/null && echo e || echo h)"
kapi "K4b tmux-bekcisi sınavı bekçiyi kalkanla çağırır" "1" "$(grep -c 'TO_KABUK_YOK=1' "$KOK/scripts/tmux-bekcisi.test.sh")"

echo "── Ç · çağıranlar (kapı yerinde mi)"
kapi "Ç1 onar.sh kabuk_kur'u çağırır" "1" "$(grep -c '^kabuk_kur || true' "$KOK/scripts/onar.sh")"
kapi "Ç2 bekci.sh her tur, sağlık ölçüsünden ÖNCE çağırır" "e" \
  "$(awk '/^kabuk_kur /{k=NR} /durum.sh" >\/dev\/null/{d=NR} END{print (k && d && k<d) ? "e" : "h"}' "$KOK/scripts/bekci.sh")"
kapi "Ç3 sağlık ölçüsü (durum.sh) kabuğu SAYMAZ (merdiveni tırmandırmaz)" "0" "$(grep -c 'KABUK\|kabuk' "$KOK/scripts/durum.sh")"
kapi "Ç4 --web-yenile kabuğu öldürmez (yalnız ttyd-*/kapi-*)" "0" "$(grep -n 'kill-session' "$KOK/scripts/onar.sh" | grep -c 'KABUK\|kabuk')"

echo "── G · görünürlük"
gizli_mi=$(bash -c '. <(sed -n "/^gizli()/p" "$1"); gizli sinav-kabuk && echo e || echo h' _ "$KOK/scripts/koltuk-bagla.sh")
kapi "G1 koltuk listesinde GİZLİ DEĞİL (Sultan görür)" "h" "$gizli_mi"
kapi "G2 kadroda altyapı: 'el kabuğu' (kapatılamaz)" "el kabuğu" \
  "$(node -e 'import(process.argv[1]).then((m)=>console.log(m.altyapiNeden("sinav-kabuk","sinav-ana")))' "$KOK/kapi/kadro.mjs")"

kapi "Y1 sarmalayıcı kullanıldı (tmux = sınav soketi)" "$T/bin/tmux" "$(command -v tmux)"
kapi "Y2 kutunun GERÇEK tmux sunucusuna oturum SIZMADI" "$GERCEK_ONCE" "$(TMUX= "$GERCEK_TMUX" ls 2>/dev/null | grep -c '^sinav-kabuk:')"
echo "── SONUÇ: $gecen geçti · $kalan kaldı"
[ "$kalan" = 0 ]
