#!/usr/bin/env bash
# Sınav: kanit-pr-kontrol.sh kapsamı — yalnız _agents/ değişen PR denetlenir, kodlu PR atlanır, bozuk JSON yakalanır.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; K="$HERE/kanit-pr-kontrol.sh"
T="$(mktemp -d)"; trap 'find "$T" -delete 2>/dev/null' EXIT
pass=0; fail=0
check() { if [ "$3" = "$2" ]; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1 (beklenen=$2 gelen=$3)"; fail=$((fail+1)); fi; }
mk() {  # temiz depo: main'de bir dosya, pr dalı main'den ayrılır
  cd "$T" || exit 1
  find "$T/r" -delete 2>/dev/null
  mkdir -p "$T/r"; cd "$T/r" || exit 1
  git init -q -b main . && git config user.email t@t && git config user.name t
  echo x > a.txt && git add -A && git commit -q -m i && git checkout -q -b pr
}
mk; mkdir -p _agents/is/kanit; echo '{"a":1}' > _agents/is/kanit/K.json; git add -A; git commit -q -m k
bash "$K" main >/dev/null 2>&1; check "K1 yalnız geçerli kanıt JSON → 0" 0 $?
mk; mkdir -p _agents/is/kanit; echo '{bozuk' > _agents/is/kanit/K.json; git add -A; git commit -q -m k
bash "$K" main >/dev/null 2>&1; check "K2 yalnız _agents, bozuk JSON → 1 (yakalanır)" 1 $?
mk; mkdir -p _agents/is/kanit; echo '{bozuk' > _agents/is/kanit/K.json; echo y > kod.sh; git add -A; git commit -q -m k
bash "$K" main 2>&1 | grep -q '^atlandı'; check "K3 kodla karışık PR → 'atlandı' (denetlemez)" 0 $?
bash "$K" main >/dev/null 2>&1; check "K4 kodla karışık PR → rc 0" 0 $?
bash "$K" >/dev/null 2>&1; check "K5 taban verilmezse kullanım hatası → 2" 2 $?
# mutant: karışık-PR atlaması sökülünce K4 düşmeli (kodlu PR'da bozuk JSON denetlenir → rc 1)
sed 's/if grep -qv .\^_agents\/. "\$d"/if false/' "$K" > "$T/mut.sh"
bash "$T/mut.sh" main >/dev/null 2>&1; check "K6 atlama mutantında kodlu PR denetlenir (rc 1) → K4 yakalar" 1 $?
echo "── SONUÇ: PASS=$pass FAIL=$fail ──"; [ "$fail" -eq 0 ]
