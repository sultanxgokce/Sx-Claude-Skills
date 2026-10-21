#!/usr/bin/env bash
# muhur-olcer.sh <tescil/scripts dizini> — G8: mühürdar akışı var mı? Aynı teslim (kendi işi + öznel G + 👤 satır) iki kez sunulur.
#   1 · yazan = mühürdar iken ret var mı  2 · 👤 Sultan denemesi satırı kabul ediliyor ve SULTANDA mı
#   3 · öznel G kendiliğinden kör yargıca gidiyor mu (yoksa elle --katman2 bekliyor mu)  4 · yargıca inşacının raporu sızıyor mu
set -uo pipefail
S="$(cd "$1" && pwd)"; T="$(mktemp -d)"; trap 'find "$T" -mindepth 1 -delete 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
W="$T/is"; mkdir -p "$W/g" "$T/bin"; git -C "$W" init -q -b main; echo merhaba > "$W/c.txt"; echo "kural: merhaba geçmeli" > "$W/g/r.md"
echo "RAPOR-SIZINTI geçti" > "$W/RAPOR.md"; git -C "$W" add -A; git -C "$W" -c user.email=a@b -c user.name=a commit -qm x
printf 'KART: k1\nGOAL: selam\nTIP: docs\nVITES: TAM\nG1: selam var\n  tur: cmd\n  komut: grep -q merhaba c.txt\n  davranis: evet\nG2: ton\n  tur: llm-yargi\n  rubrik: r.md\n  hedef: c.txt\nG3: Sultan bakar\n  tur: sultan-denemesi\n  tarif: c.txt aç bak\n' > "$W/g/GEREKLILIK.md"
printf '#!/usr/bin/env bash\ncat > %s/istem.md; printf "%%s" "{\\"structured_output\\":{\\"karar\\":\\"GECTI\\",\\"not\\":\\"ok\\"}}"\n' "$T" > "$T/bin/claude"; chmod +x "$T/bin/claude"
P="$T/bin:$(dirname "$(command -v node)"):$(dirname "$(command -v python3)"):/usr/bin:/bin"
if [ -f "$S/muhurdar.sh" ]; then
  env PATH="$P" AGENT_NAME=HENDESE MUHURDAR_MODEL=claude bash "$S/muhurdar.sh" k1 --gereklilik "$W/g/GEREKLILIK.md" --worktree "$W" --out "$T/o1" --yazan hendese >/dev/null 2>&1; r1=$?
  env PATH="$P" AGENT_NAME=MUHURDAR1 MUHURDAR_MODEL=claude bash "$S/muhurdar.sh" k1 --gereklilik "$W/g/GEREKLILIK.md" --worktree "$W" --out "$T/o2" --yazan HENDESE >/dev/null 2>&1; r2=$?
else
  r1=yok; env PATH="$P" bash "$S/tescil-run.sh" k1 --gereklilik "$W/g/GEREKLILIK.md" --worktree "$W" --out "$T/o2" >/dev/null 2>&1; r2=$?
fi
v="$(grep -m1 '^verdikt:' "$T/o2/MUHUR.md" 2>/dev/null | cut -d' ' -f2)"; red="$(grep -m1 -oE 'gereklilik-[a-z]+|kendi-isi' "$T/o2/MUHUR.md" 2>/dev/null)"
k1=0; [ "$r1" = 4 ] && k1=1
k2=0; grep -q 'SULTANDA' "$T/o2/MUHUR.md" 2>/dev/null && k2=1
k3=0; [ "$v" = GECTI ] && grep -q '^yargic: G2=claude' "$T/o2/MUHUR.md" && k3=1
k4=1; [ -f "$T/istem.md" ] && grep -q RAPOR-SIZINTI "$T/istem.md" && k4=0
echo "── 1 · kendi işi (yazan=mühürdar): $([ $k1 = 1 ] && echo "RET (rc 4)" || echo "ret yok (rc $r1 — mühürdar akışı $( [ "$r1" = yok ] && echo YOK || echo var))")"
echo "── 2 · 👤 Sultan denemesi satırı: $([ $k2 = 1 ] && echo 'kabul, MUHUR'"'"'da SULTANDA' || echo "tanınmıyor (verdikt ${v:-—} ${red:-})")"
echo "── 3 · öznel G2: $([ $k3 = 1 ] && echo 'kendiliğinden kör yargıca gitti (claude), verdikt GECTI' || echo "yargıca gitmedi (verdikt ${v:-—}, rc $r2)")"
echo "── 4 · yargıç isteminde inşacı raporu: $([ $k4 = 1 ] && echo yok || echo VAR)"
echo "── SONUÇ: kendi-işi $([ $k1 = 1 ] && echo ✓ || echo ✗) · 👤 $([ $k2 = 1 ] && echo ✓ || echo ✗) · kör yargıç $([ $k3 = 1 ] && echo ✓ || echo ✗) · rapor sızmaz $([ $k4 = 1 ] && echo ✓ || echo ✗)"
[ $k1 = 1 ] && [ $k2 = 1 ] && [ $k3 = 1 ] && [ $k4 = 1 ] && exit 0
exit 1
