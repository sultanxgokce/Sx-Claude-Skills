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

rm -r "$KOK/../kardes-$$" 2>/dev/null || true
python3 "$A" "$DIS" >/dev/null 2>&1 || true
rmdir "$KOK" 2>/dev/null || true
echo
echo "toplam=$((GECEN+DUSEN)) geçen=$GECEN düşen=$DUSEN"
[[ $DUSEN -eq 0 ]]
