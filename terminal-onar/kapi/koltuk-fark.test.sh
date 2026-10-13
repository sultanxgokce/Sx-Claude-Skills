#!/usr/bin/env bash
# koltuk-fark.test.sh — fark ölçerinin her hükmü (G-BANI-0007). Hermetik: sahte tmux (PATH), gerçek koltuk-bagla.sh/koltuklar.mjs.
set -u
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; T="$(mktemp -d)"
trap 'kill $(jobs -p) 2>/dev/null; find "$T" -mindepth 1 -delete; rmdir "$T"' EXIT
g=0; k=0; kapi() { if [ "$2" = "$3" ]; then g=$((g+1)); echo "  ✓ $1"; else k=$((k+1)); echo "  ✗ $1 → beklenen [$2] olan [$3]"; fi; }
mkdir -p "$T/bin"
cat > "$T/bin/tmux" <<'S'
#!/usr/bin/env bash
case "$*" in
  *list-sessions*) [ -f "$KF/hata" ] && { echo "beklenmedik tmux hatası" >&2; exit 1; }
    case "$*" in *session_activity*) awk '{print $0"\t0"}' "$KF/oturumlar" ;; *) cat "$KF/oturumlar" ;; esac ;;
  *list-clients*) cat "$KF/istemciler" 2>/dev/null ;;
  *) exit 0 ;;
esac
S
chmod +x "$T/bin/tmux"; export KF="$T" PATH="$T/bin:$PATH"
OLC() { node "$D/koltuk-fark.mjs" "$@"; }
J() { node "$D/koltuk-fark.mjs" --json | python3 -c "import json,sys;d=json.load(sys.stdin);o=d.get('ozet',{});print($1)"; }
printf '%s\n' ana ttyd-x kapi-x x-kurtarici imglistener '2026/85' > "$T/oturumlar"; : > "$T/istemciler"
OLC >/dev/null; rc=$?
kapi "F1 temiz kutu: rc 0 · görünür 2 (ana, 2026/85) · gizli 4 (altyapı) · düşen 0" "0|2|4|0" "$rc|$(J 'o["gorunur"],o["gizli"],o["dusen"],sep="|"')"
kapi "F1b gizlenen her oturumun gerekçesi var" "4" "$(node "$D/koltuk-fark.mjs" --json | python3 -c 'import json,sys;print(sum(1 for x in json.load(sys.stdin)["oturumlar"] if x["hukum"]=="gizli" and x.get("neden","").startswith("altyapı")))')"
# F2 DÜŞEN: listeyi kesen bozuk betik (gizli listesinde de yok) → gerekçesiz düşüş yakalanır
cat > "$T/betik-dusuren.sh" <<'S'
#!/usr/bin/env bash
case "$1" in --liste) printf 'ana\t0\t0\tdiger\tbilinmiyor\n' ;; --gizli) : ;; esac
S
printf '%s\n' ana kayip > "$T/oturumlar"
KAPI_KOLTUK_BETIK="$T/betik-dusuren.sh" OLC >/dev/null; rc=$?
kapi "F2 gerekçesiz düşen oturum → rc 1, DÜŞEN=kayip" "1|['kayip']" "$rc|$(KAPI_KOLTUK_BETIK="$T/betik-dusuren.sh" node "$D/koltuk-fark.mjs" --json | python3 -c 'import json,sys;print([x["ad"] for x in json.load(sys.stdin)["oturumlar"] if x["hukum"]=="DUSEN"])')"
# F3 ad süzgeci: betik listeler, kapı kuralı (koltuklar.mjs) düşürür → gerekçeli gizli, rc 0
printf '%s\n' ana 'a.b' > "$T/oturumlar"
OLC >/dev/null; rc=$?
kapi "F3 kapı ad kuralına takılan oturum gerekçeli gizli (ad süzgeci), rc 0" "0|ad süzgeci" "$rc|$(node "$D/koltuk-fark.mjs" --json | python3 -c 'import json,sys;print([x["neden"][:10] for x in json.load(sys.stdin)["oturumlar"] if x["ad"]=="a.b"][0])')"
# F4 HAYALET: listede olup tmux'ta olmayan
cat > "$T/betik-hayalet.sh" <<'S'
#!/usr/bin/env bash
case "$1" in --liste) printf 'ana\t0\t0\tdiger\tbilinmiyor\nhayal\t0\t0\tdiger\tbilinmiyor\n' ;; --gizli) : ;; esac
S
printf '%s\n' ana > "$T/oturumlar"
KAPI_KOLTUK_BETIK="$T/betik-hayalet.sh" OLC >/dev/null; rc=$?
kapi "F4 listede var tmux'ta yok → rc 1, hayalet=hayal" "1|['hayal']" "$rc|$(KAPI_KOLTUK_BETIK="$T/betik-hayalet.sh" node "$D/koltuk-fark.mjs" --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["hayalet"])')"
# F5 başka adla bağlı istemci (YargiYenileme vakası): 'attach -t yenileme' ile açılmış istemci bugün '2026/85'de
printf '%s\n' ana '2026/85' > "$T/oturumlar"
python3 -c 'import time; time.sleep(60)' attach -t yenileme & ip=$!; sleep 0.3
printf '%s\t%s\n' "$ip" '2026/85' > "$T/istemciler"
OLC >/dev/null; rc=$?
kapi "F5 sekme adı ≠ oturum adı bilgi olarak raporlanır, kırmızı DEĞİL" "0|yenileme>2026/85" "$rc|$(node "$D/koltuk-fark.mjs" --json | python3 -c 'import json,sys;s=json.load(sys.stdin)["sekme"][0];print(s["acilis_adi"]+">"+s["oturum"])')"
kill $ip 2>/dev/null; : > "$T/istemciler"
# F6 terminalsiz: tmux yok → rc 3 (temiz SAYILMAZ, kirli de değil)
KOLTUK_FARK_TMUX="$T/yok/tmux" OLC >/dev/null; kapi "F6 tmux kurulu değil → rc 3 terminalsiz" "3" "$?"
# F7 ölçülemedi: tmux beklenmedik hata → rc 2 (boş liste 'temiz' sayılmaz)
: > "$T/hata"; OLC >/dev/null; rc=$?; rm "$T/hata"
kapi "F7 tmux hatası → rc 2 ölçülemedi" "2" "$rc"
# F7b ölçerin KENDİ denetimi: betik sağlam cevap verse de (sahte) tmux listesi alınamıyorsa ölçülemedi — boş liste 'temiz' sayılmaz
cat > "$T/betik-saglam.sh" <<'S'
#!/usr/bin/env bash
case "$1" in --liste) printf 'ana\t0\t0\tdiger\tbilinmiyor\n' ;; --gizli) : ;; esac
S
: > "$T/hata"; KAPI_KOLTUK_BETIK="$T/betik-saglam.sh" OLC >/dev/null; rc=$?; rm "$T/hata"
kapi "F7b betik sağlamken tmux hatası → yine rc 2 (ölçerin kendi kapısı)" "2" "$rc"
# F8 eski betik (--gizli bilmez) → rc 2: gizli liste yokken düşen/gizli ayrımı yapılamaz
cat > "$T/betik-eski.sh" <<'S'
#!/usr/bin/env bash
case "$1" in --liste) printf 'ana\t0\t0\n' ;; *) exit 2 ;; esac
S
KAPI_KOLTUK_BETIK="$T/betik-eski.sh" OLC >/dev/null; kapi "F8 --gizli bilmeyen eski betik → rc 2 (sessiz yeşil yok)" "2" "$?"
# F9 tek kaynak: ölçer ve /api/koltuklar aynı modülü kullanır
grep -q "from './koltuklar.mjs'" "$D/koltuk-fark.mjs" && grep -q "from './koltuklar.mjs'" "$D/sunucu.mjs"
kapi "F9 ölçer ile kapı aynı liste modülünü içe alır" "0" "$?"
echo "GEÇEN: $g · KALAN: $k"; [ "$k" -eq 0 ]
