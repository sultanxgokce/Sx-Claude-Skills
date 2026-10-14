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
  *list-panes*) [ -f "$KF/bolme-hata" ] && { echo "bölme listesi hatası" >&2; exit 1; }
    # bölmeler: ad · pencere-etkin · bölme-etkin · %kimlik · pid · komut. Dosya yoksa: her oturum Claude'lu (eski sınavların varsayımı)
    if [ -f "$KF/bolmeler" ]; then cat "$KF/bolmeler"; else while IFS= read -r n; do printf '%s\t1\t1\t%%1\t1\tclaude\n' "$n"; done < "$KF/oturumlar"; fi ;;
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
# F5b '=ad' kesin-eşleşme biçimi de yakalanır (bağımsız göz tur 1: önek yüzünden dışlanıyordu)
python3 -c 'import time; time.sleep(60)' attach -t =yenileme & ip2=$!; sleep 0.3
printf '%s\t%s\n' "$ip2" '2026/85' > "$T/istemciler"
kapi "F5b '=yenileme' ile açılmış istemci → 'yenileme' > 2026/85" "yenileme>2026/85" "$(node "$D/koltuk-fark.mjs" --json | python3 -c 'import json,sys;s=json.load(sys.stdin)["sekme"];print(s[0]["acilis_adi"]+">"+s[0]["oturum"] if s else "YOK")')"
kill $ip2 2>/dev/null
# F5c komut satırı okunamayan istemci (ölmüş pid) SAYILIR, sessizce atlanmaz
printf '%s\t%s\n' 999999 '2026/85' > "$T/istemciler"
kapi "F5c okunamayan istemci sayılır (sekme_okunamayan=1)" "1" "$(J 'o["sekme_okunamayan"]')"
# F5d istemci listesi alınamazsa 'sekme_olculemedi' görünür (sessiz boş liste değil)
mv "$T/istemciler" "$T/istemciler.x"; printf '#!/usr/bin/env bash\ncase "$*" in *list-clients*) echo "istemci hatası" >&2; exit 1 ;; *) exec %s "$@" ;; esac\n' "$T/bin/tmux" > "$T/tmux2"; chmod +x "$T/tmux2"
kapi "F5d list-clients hatası → sekme_olculemedi dolu" "1" "$(KOLTUK_FARK_TMUX="$T/tmux2" node "$D/koltuk-fark.mjs" --json | python3 -c 'import json,sys;print(int(bool(json.load(sys.stdin)["ozet"].get("sekme_olculemedi"))))')"
mv "$T/istemciler.x" "$T/istemciler"
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
# ── F10-F13 · BOŞ koltuk (2.5.0 · SERDAR 14 Eki: 15 koltuk "görünür = temiz" sayılıyordu) ──────────────────────────────
# Gerçek süreç ağaçları kurulur: 'claude' adlı bir bekleme süreci (sleep'e bağ) — komut satırı …/claude ile biter.
ln -sf "$(command -v sleep)" "$T/bin/claude"
bash -c "exec sleep 60" & KABUK=$!                                   # içinde hiçbir şey yok
bash -c "bash -c '\"$T/bin/claude\" 60; true'; true" & TORUN=$!; sleep 0.4    # bölme → betik → claude (TORUN; '; true' kabuğun exec ile kendini claude'a çevirmesini önler — gerçek başlatma betiği gibi)
bash -c "exec sleep 60" & GECICI=$!
bash -c "sleep 60; true" & SUNUCU=$!; sleep 0.3                     # Claude'suz ama altında süreç koşan oturum (web sunucusu gibi)
bash -c "exec sleep 60" & EXE=$!                                     # bölme komutu claude.exe, ALTINDA hiçbir şey yok (pid 1 KULLANILMAZ: altında
                                                                     # kutunun bütün süreçleri — gerçek Claude'lar dahil — vardır, kapıyı kör eder)
printf '%s\n' ana kabuk torun cc-9 sunucu exe > "$T/oturumlar"
printf 'ana\t1\t1\t%%1\t1\tclaude\nkabuk\t1\t1\t%%2\t%s\tbash\ntorun\t1\t1\t%%3\t%s\tbash\ncc-9\t1\t1\t%%4\t%s\tbash\nsunucu\t1\t1\t%%5\t%s\tbash\nexe\t1\t1\t%%6\t%s\tclaude.exe\n' "$KABUK" "$TORUN" "$GECICI" "$SUNUCU" "$EXE" > "$T/bolmeler"
OLC >/dev/null; rc=$?
H() { node "$D/koltuk-fark.mjs" --json | python3 -c "import json,sys;d=json.load(sys.stdin);print({x['ad']:x['hukum'] for x in d['oturumlar']}.get('$1'))"; }
kapi "F10 görünür ama içinde Claude yok → BOS, rc 1" "1|BOS|1" "$rc|$(H kabuk)|$(J 'o["bos"]')"
kapi "F11 Claude TORUN süreçte (başlatma betiği altında) → görünür, BOŞ değil" "gorunur" "$(H torun)"
kapi "F12 geçici ad (cc-*) Claude'suz da muaf → görünür" "gorunur" "$(H cc-9)"
kapi "F13 Claude doğrudan bölmede → görünür (F10 tautoloji değil)" "gorunur" "$(H ana)"
kapi "F14 Claude'suz ama altında süreç koşan oturum (sunucu) BOŞ DEĞİL → görünür" "gorunur" "$(H sunucu)"
kapi "F15 'claude.exe' (yerel kurucu ikilisi) Claude sayılır → görünür (medigate/SAYMAN vakası)" "gorunur" "$(H exe)"
kapi "F16 BOŞ sayısı yalnız gerçek boş kabuk: 1 (kabuk)" "1" "$(J 'o["bos"]')"
# F17/F18 koltuk listesindeki ajan işareti (tür·hâl buna bağlı): Claude TORUN süreçte ve 'claude.exe' adıyla da tanınır
L() { bash "$D/../scripts/koltuk-bagla.sh" --liste | awk -F'\t' -v a="$1" '$1==a {print $3}'; }
kapi "F17 başlatma betiği altındaki (torun) Claude listede ajan işaretli (claude=1)" "1" "$(L torun)"
kapi "F18 'claude.exe' listede ajan işaretli (claude=1)" "1" "$(L exe)"
# F19 derinlik sınırı YOK (bağımsız göz tur 1): Claude 8 kat aşağıda da bulunur
d="\"$T/bin/claude\" 60"; for i in 1 2 3 4 5 6 7; do d="bash -c '$(printf '%s' "$d" | sed "s/'/'\\\\''/g"); true'"; done
bash -c "$d; true" & DERIN=$!; sleep 0.6
printf '%s\n' derin > "$T/oturumlar"; printf 'derin\t1\t1\t%%7\t%s\tbash\n' "$DERIN" > "$T/bolmeler"
kat=$(python3 -c "
import os
def cocuk(p): return [int(x) for x in open(f'/proc/{p}/task/{p}/children').read().split()]
def ara(p,d):
    for c in cocuk(p):
        a=open(f'/proc/{c}/cmdline','rb').read().split(b'\\0')[0]
        if a.endswith(b'/claude'): return d+1
        r=ara(c,d+1)
        if r: return r
    return 0
print(ara($DERIN,0))")
kapi "F19 Claude $kat kat aşağıda (≥7) → listede ajan işaretli, BOŞ değil" "1|gorunur|1" "$([ "$kat" -ge 7 ] && echo 1 || echo 0)|$(H derin)|$(L derin)"
pkill -P $DERIN 2>/dev/null; kill $DERIN 2>/dev/null
# F21 argümanında "…/claude" geçen ama Claude ÇALIŞTIRMAYAN başlatıcı → ajan DEĞİL (bağımsız göz tur 2: yanlış-pozitif)
bash -c "bash -c 'echo $T/bin/claude --resume x >/dev/null; sleep 60; true'; true" & SAHTE=$!; sleep 0.4
printf '%s\n' sahte > "$T/oturumlar"; printf 'sahte\t1\t1\t%%8\t%s\tbash\n' "$SAHTE" > "$T/bolmeler"
kapi "F21 argümanda /claude geçen başlatıcı (Claude yok) → listede ajan DEĞİL (claude=0)" "0" "$(L sahte)"
pkill -P $SAHTE 2>/dev/null; kill $SAHTE 2>/dev/null
# F20 bölme listesi alınamazsa ölçüm YOK: --bos rc 3, ölçer rc 2 (boş liste 'temiz' sayılmaz)
printf '%s\n' ana > "$T/oturumlar"; : > "$T/bolme-hata"
bash "$D/../scripts/koltuk-bagla.sh" --bos >/dev/null 2>&1; rb=$?; OLC >/dev/null 2>&1; ro=$?; rm -f "$T/bolme-hata"
kapi "F20 bölme listesi hatası → --bos rc 3 · ölçer rc 2 (ÖLÇÜLEMEDİ)" "3|2" "$rb|$ro"
kill $KABUK $TORUN $GECICI $SUNUCU $EXE 2>/dev/null; pkill -P $TORUN 2>/dev/null; pkill -P $SUNUCU 2>/dev/null; rm -f "$T/bolmeler"
echo "GEÇEN: $g · KALAN: $k"; [ "$k" -eq 0 ]
