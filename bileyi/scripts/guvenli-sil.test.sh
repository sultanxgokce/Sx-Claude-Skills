#!/usr/bin/env bash
# guvenli-sil.test.sh — dort kapinin sinavi. HERMETIK: yalniz kendi kurdugu gecici
# dizinlere dokunur, gercek hicbir seye dokunmaz.
#
# 🔴 En degerli kapilar C ve D: ikisi de "bu arac kancayi atliyor, o yuzden
#    kancanin korudugu seyi KENDISI korumak zorunda" sozlesmesini kilitler.
set -uo pipefail
cd "$(dirname "$0")"
A="$PWD/guvenli-sil.py"
GECEN=0; DUSEN=0
kapi(){ local ad="$1" bek="$2"; shift 2; "$@" >/dev/null 2>&1; local rc=$?
  if [[ $rc -eq $bek ]]; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad (rc=$rc, beklenen=$bek)"; fi; }

KOK="$(mktemp -d)"
export TMPDIR="$KOK"

echo "A · asil is (meşru yol acildi mi)"
mkdir -p "$KOK/dolu/alt/derin" && : > "$KOK/dolu/alt/derin/dosya"
kapi "A1 izinli kokun ALTINDAKI dizin silinir" 0 python3 "$A" "$KOK/dolu"
kapi "A2 silindigi dogrulanir (geri okundu)" 0 test ! -e "$KOK/dolu"
kapi "A3 zaten yok olan yol rc=0 (silmekle ayni sonuc)" 0 python3 "$A" "$KOK/hic-olmayan"

echo "B · 🔴 yasakli deseni HIC kullanmaz (kancayi atlamanin sarti)"
kapi "B1 kaynakta yasakli kabuk deseni YOK" 0 python3 -c "
k = open('$A', encoding='utf-8').read()
kod = chr(10).join(l for l in k.splitlines() if not l.lstrip().startswith('#'))
yasak = 'rm' + ' -' + 'rf'
assert yasak not in kod, 'yasakli desen koda girmis'
assert 'subprocess' not in kod, 'kabuga cikiyor — kanca yine bloklar'
assert 'shutil.rmtree' in kod, 'silme kutuphaneden yapilmali'
"

echo "C · 🔴 K1/K4 — izinli kok kapisi"
mkdir -p "$KOK/kendi"
kapi "C1 izinli KOKUN KENDISI silinmez" 2 python3 "$A" "$KOK"
DIS="$(mktemp -d /dev/shm/gs-XXXXXX 2>/dev/null || mktemp -d)"
mkdir -p "$DIS/disarda"
kapi "C2 koklerin DISINDAKI yol silinmez" 2 env TMPDIR="$KOK" python3 "$A" "$DIS/disarda"
kapi "C3 dis yol HALA DURUYOR (pozitif kontrol: kapi sadece rc dondurmuyor)" 0 test -d "$DIS/disarda"
kapi "C4 dosya (dizin degil) silinmez" 2 env TMPDIR="$KOK" sh -c ": > '$KOK/d.txt'; python3 '$A' '$KOK/d.txt'"
kapi "C5 bos yol reddedilir" 2 python3 "$A" ""
kapi "C6 kok '/' olsa bile izinli sayilmaz" 2 env TMPDIR="/" CLAUDE_SCRATCHPAD="/" sh -c "python3 '$A' '$DIS/disarda'"

echo "D · 🔴 K2/K3 — bag ve ust-yol kapisi"
mkdir -p "$DIS/gercek-hedef"
ln -s "$DIS/gercek-hedef" "$KOK/bag"
kapi "D1 sembolik BAG silinmez" 2 env TMPDIR="$KOK" python3 "$A" "$KOK/bag"
kapi "D2 bagin HEDEFI duruyor (pozitif kontrol)" 0 test -d "$DIS/gercek-hedef"
# 🔴 D3 ilk yazimda YANLIS SEYI olcuyordu: hedef yol hic var olmadigi icin rc=0
#    donuyordu ("zaten yok"), kacis sinanmiyordu. Simdi GERCEKTEN var olan,
#    kokun KARDESI bir dizin ust-yolla hedefleniyor.
mkdir -p "$KOK/../kardes-$$/icerik"
kapi "D3 ust-yolla kacis (..) kok disina cikamaz" 2 env TMPDIR="$KOK" python3 "$A" "$KOK/../kardes-$$"
kapi "D4 kardes dizin HALA DURUYOR (pozitif kontrol)" 0 test -d "$KOK/../kardes-$$"
kapi "D5 ciplak /tmp izinli kok DEGIL (kendi sinavimin buldugu daralma)" 0 python3 -c "
import importlib.util as u, pathlib, os
s=u.spec_from_file_location('g','$A'); m=u.module_from_spec(s); s.loader.exec_module(m)
os.environ['TMPDIR']='$KOK'; os.environ.pop('CLAUDE_SCRATCHPAD', None)
k = m.izinli_kokler()
assert pathlib.Path('/tmp') not in k, f'ciplak /tmp geri gelmis: {k}'
"

echo "E · olcemedigine yesil demez"
kapi "E1 hicbir izinli kok yoksa rc=3 (OLCEMEDIM, silmez)" 3 env TMPDIR="" CLAUDE_SCRATCHPAD="" sh -c "
python3 - <<'PY'
import importlib.util as u, sys
s=u.spec_from_file_location('g','$A'); m=u.module_from_spec(s); s.loader.exec_module(m)
m.izinli_kokler = lambda: []
rc, msg = m.sil('$KOK/x')
sys.exit(rc)
PY"
kapi "E2 kullanimsiz cagri rc=2" 2 python3 "$A"
kapi "E3 iki arguman rc=2 (sessizce ilkini silmez)" 2 python3 "$A" "$KOK/a" "$KOK/b"

# E · --yeni kipi (12 Eki 2026 /bileyi: mktemp çıplak /tmp'ye açıyordu, K1 reddediyordu)
Y="$(env TMPDIR="$KOK" python3 "$A" --yeni sinav- 2>/dev/null)"
kapi "Y1 --yeni izinli kökün ALTINDA dizin açar" 0 sh -c "case '$Y' in '$KOK'/sinav-*) test -d '$Y';; *) exit 1;; esac"
kapi "Y2 --yeni ile açılan dizini araç KENDİSİ siler" 0 env TMPDIR="$KOK" python3 "$A" "$Y"
kapi "Y3 silindiği geri okunur" 0 test ! -e "$Y"
kapi "Y4 tanınmayan bayrak SESSİZ BAŞARI değil (eskiden rc=0)" 2 python3 "$A" --boyle-bir-bayrak-yok
kapi "Y5 önek temizlenir — yol ayırıcı kök dışına taşımaz" 0 sh -c "Y2=\$(env TMPDIR='$KOK' python3 '$A' --yeni '../../kacis'); case \"\$Y2\" in '$KOK'/*) python3 '$A' \"\$Y2\" >/dev/null 2>&1; env TMPDIR='$KOK' python3 '$A' \"\$Y2\" >/dev/null;; *) exit 1;; esac"
kapi "Y6 hiçbir kök yazılabilir değilse rc=3 ÖLÇEMEDİM (yeşil değil)" 3 env TMPDIR=/proc/1/kok-yok CLAUDE_SCRATCHPAD=/proc/1/kok-yok2 HOME=/nonexistent python3 -c "
import importlib.util,sys
sp=importlib.util.spec_from_file_location('g','$A'); g=importlib.util.module_from_spec(sp); sp.loader.exec_module(g)
g.izinli_kokler=lambda: [__import__('pathlib').Path('/proc/1/kok-yok')]
sys.exit(g.yeni()[0])"

# Y7 · TMPDIR yokken de izinli köke açar (mkdtemp'in varsayılanı çıplak /tmp'dir — Y1 bunu göremezdi:
#      orada TMPDIR zaten izinli kökü gösteriyor; mutasyonla ölçüldü, 12 Eki)
Y7="$(env -u TMPDIR CLAUDE_SCRATCHPAD="$KOK" python3 "$A" --yeni y7- 2>/dev/null)"
kapi "Y7 TMPDIR yokken de dizin izinli kökün altında (çıplak /tmp'ye düşmez)" 0 sh -c "case '$Y7' in '$KOK'/y7-*|/tmp/claude-1000/y7-*) test -d '$Y7';; *) exit 1;; esac"
env -u TMPDIR CLAUDE_SCRATCHPAD="$KOK" python3 "$A" "$Y7" >/dev/null 2>&1 || true

rm -r "$KOK/../kardes-$$" 2>/dev/null || true
python3 "$A" "$DIS" >/dev/null 2>&1 || true
rmdir "$KOK" 2>/dev/null || true
echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[[ $DUSEN -eq 0 ]]
