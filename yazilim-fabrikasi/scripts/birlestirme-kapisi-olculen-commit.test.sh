#!/usr/bin/env bash
# birlestirme-kapisi-olculen-commit.test.sh — kapı puanın verildiği commit (DENETIM.bas) ile birleşen ucu karşılaştırır (kart kanit-kaydi-olculen-commit).
# Davranışsal: gerçek git geçmişi kurulur, kapı gerçekten koşar. Negatif kontrol: KAPI=<öncesi kopyası> verilirse aynı vakalar GEÇER (= açık buydu); olc.sh eski kipi bunu yapar.
set -uo pipefail
export KANIT_SIRA=0 DENETCI_SIRA=0
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G="${KAPI:-$HERE/birlestirme-kapisi.sh}"; K="$HERE/kanit.sh"; KT="$HERE/kart.sh"
export HERE
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
TETIK="$(mktemp)"; printf '#!/usr/bin/env bash\nexit 0\n' > "$TETIK"; chmod +x "$TETIK"
export FABRIKA_TETIK="$TETIK"
kur() { # kur → yeni depo (T), iş is-oc, kanıt var, bir kod dosyası commit'li
  T="$(mktemp -d)"; export KANIT_DEPO="$T"
  export FABRIKA_GOLGE_DEFTER="$T/golge.jsonl" FABRIKA_GOREV_SH="$T/yok-gorev.sh" FABRIKA_AILE_NOTIFY=-
  ( cd "$T" && git init -q -b main && git config user.email t@t && git config user.name t && echo kod1 > uygulama.sh && git add -A && git commit -q -m "chore: ilk" ) >/dev/null 2>&1
  bash "$KT" ac is-oc --is x --istedi S --aldi M --geri-alinamaz h --para h --dis-yuzey h --yetki h --oda o >/dev/null 2>&1
  ( cd "$T" && bash "$K" olcum is-oc olc --asama tek -- echo 1 ) >/dev/null 2>&1
  ( cd "$T" && git add -A && git commit -q -m "chore: kanit" ) >/dev/null 2>&1
}
den() { # den <bas|-> : DENETIM-1 5/E, bas verilirse yazılır
  mkdir -p "$T/_agents/fabrika/kanit/is-oc"
  python3 - "$T/_agents/fabrika/kanit/is-oc/DENETIM-1.json" "$1" <<'PY'
import json,sys,datetime
p,bas=sys.argv[1:]
d={"tur":1,"is":"is-oc","pr":"7","yazan":"claude","denetci":"codex","zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
 "kanit_durumu":"sağlam","sonuc":{"kod_puani":5,"dogru_sey":"E","ozet":"o","bulgular":[],"kanit_gorusu":"k"}}
if bas!="-": d["bas"]=bas
json.dump(d,open(p,"w"))
PY
}
kapi() { bash "$G" is-oc 2>&1; }
bas_al() { git -C "$T" rev-parse HEAD; }

echo "════ O1 · bas = birleşen uç → GEÇER ════"
kur; B="$(bas_al)"; den "$B"; C="$(kapi)"; RC=$?
[ "$RC" -eq 0 ]; g $? "rc=0 (bas = uç)"; grep -q "puan birleşen uca verilmiş" <<<"$C"; g $? "✓ satırı basıldı"

echo "════ O2 · göz sonrası yalnız DENETİM kaydı commit'lendi → GEÇER ════"
kur; B="$(bas_al)"; den "$B"; ( cd "$T" && git add -A && git commit -q -m "docs: goz kaydi" ) >/dev/null 2>&1
C="$(kapi)"; RC=$?; [ "$RC" -eq 0 ]; g $? "rc=0 (arada yalnız kanıt dizini)"; grep -q "aradaki fark yalnız kanıt kaydı" <<<"$C"; g $? "açıklaması basıldı"

echo "════ O3 · puandan SONRA kod değişti → ENGELLER ════"
kur; B="$(bas_al)"; den "$B"; ( cd "$T" && git checkout -q -b is-dal && echo kod2 > uygulama.sh && git add -A && git commit -q -m "fix: gozden sonra kod" ) >/dev/null 2>&1   # ana hat (main) eski kalır: kod yalnız dalda
C="$(kapi)"; RC=$?; [ "$RC" -eq 1 ]; g $? "rc=1"; grep -q "puan verildikten sonra kod değişmiş" <<<"$C" && grep -q "uygulama.sh" <<<"$C"; g $? "değişen dosya adıyla söylendi"

echo "════ O4 · bas başka bir dalın commit'i (uçun atası değil) → ENGELLER ════"
kur; ( cd "$T" && git checkout -q -b yan && echo y > yan.txt && git add -A && git commit -q -m "chore: yan" && git checkout -q main ) >/dev/null 2>&1
B="$(git -C "$T" rev-parse yan)"; den "$B"; C="$(kapi)"; RC=$?
[ "$RC" -eq 1 ]; g $? "rc=1"; grep -q "puan başka bir commit'e verilmiş" <<<"$C"; g $? "sebep yazıldı"

echo "════ O5 · bas yok (eski kayıt) → GEÇER ama söylenir ════"
kur; den "-"; C="$(kapi)"; RC=$?
[ "$RC" -eq 0 ]; g $? "rc=0 (geriye uyum)"; grep -q "KARŞILAŞTIRILAMADI" <<<"$C"; g $? "karşılaştırılamadığı söylendi"

echo "════ O6 · ana hatta zaten olan dosya dala girmiş (master birleştirme) → engellemez ════"
kur; B="$(bas_al)"; den "$B"
( cd "$T" && git checkout -q -b is-dal && git checkout -q main && echo baskasi > baska.txt && git add -A && git commit -q -m "chore: baskasinin isi" && git checkout -q is-dal && git merge -q --no-edit main ) >/dev/null 2>&1
( cd "$T" && git add -A && git commit -q -m "docs: goz kaydi" ) >/dev/null 2>&1
git -C "$T" branch -q -f main HEAD 2>/dev/null; git -C "$T" checkout -q is-dal 2>/dev/null
C="$(kapi)"; RC=$?; [ "$RC" -eq 0 ]; g $? "rc=0 (baska.txt ana hatta aynı)"

echo "════ O13-O14 · PUANDAN SONRA ANA DAL BİRLEŞTİ (SERDAR 1 Kas, Sx #629): aynı dosyada iki ayrı iş → PR farkı aynıysa GEÇER, PR kodu değiştiyse ENGELLER ════"
ana_birlesim() { # ana_birlesim → kur + main'de liste.txt, dalda a→A, puan; sonra main'de c→C ve dala birleştirme
  kur
  ( cd "$T" && printf 'a\nb\nc\n' > liste.txt && git add -A && git commit -q -m "chore: liste" && git checkout -q -b is-dal && printf 'A\nb\nc\n' > liste.txt && git add -A && git commit -q -m "feat: pr degisikligi" ) >/dev/null 2>&1
  B="$(bas_al)"; den "$B"
  ( cd "$T" && git checkout -q main && printf 'a\nb\nC\n' > liste.txt && git add -A && git commit -q -m "chore: baskasinin isi" && git checkout -q is-dal && git merge -q --no-edit main ) >/dev/null 2>&1
}
ana_birlesim
C="$(kapi)"; RC=$?; [ "$RC" -eq 0 ] && grep -q "PR'ın ana dala göre farkı aynı" <<<"$C"; g $? "O13 · puandan sonra ana dal aynı dosyaya girdi, PR farkı aynı → rc=0 (kanıt: $(grep -c 'PR.ın ana dala' <<<"$C") satır)"
ana_birlesim
( cd "$T" && echo yeni-kod >> uygulama.sh && git add -A && git commit -q -m "fix: puandan sonra kod" ) >/dev/null 2>&1
C="$(kapi)"; RC=$?; [ "$RC" -eq 1 ] && grep -q "puan verildikten sonra kod değişmiş" <<<"$C" && grep -q "uygulama.sh" <<<"$C"; g $? "O14 · aynı kurulum + PR'a puandan sonra kod girdi → rc=1, uygulama.sh adıyla"

echo "════ O7 · bas bu depoda yok → ÖLÇÜLEMEDİ (rc=3), engel değil geçti de değil ════"
kur; den "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"; C="$(kapi)"; RC=$?
[ "$RC" -eq 3 ]; g $? "rc=3"; grep -q "bu depoda yok" <<<"$C"; g $? "sebep yazıldı"

echo "════ O8 · kirli ağaçta ölçülmüş KANIT kaydı → engellemez ama söylenir ════"
kur; ( cd "$T" && echo kirli > uygulama.sh && bash "$K" olcum is-oc kirli --asama tek -- echo 2 ) >/dev/null 2>&1
( cd "$T" && git add -A && git commit -q -m "chore: kanit2" ) >/dev/null 2>&1
B="$(bas_al)"; den "$B"; C="$(kapi)"; RC=$?
[ "$RC" -eq 0 ]; g $? "rc=0 (uyarı, engel değil)"; grep -q "commit'lenmemiş değişiklikli ağaçta ölçülmüş" <<<"$C" && grep -q "kirli/tek" <<<"$C"; g $? "kirli kayıt adıyla söylendi"

echo "════ O9 · git diff düşerse kapı geçti SAYMAZ (fail-closed, rc=3) ════"
kur; B="$(bas_al)"; den "$B"; ( cd "$T" && git add -A && git commit -q -m "docs: goz kaydi" ) >/dev/null 2>&1
SH="$(mktemp -d)"; GERCEK="$(command -v git)"
printf '#!/usr/bin/env bash\ncase " $* " in *" diff "*"--name-only"*) exit 128 ;; esac\nexec "%s" "$@"\n' "$GERCEK" > "$SH/git"; chmod +x "$SH/git"
C="$(PATH="$SH:$PATH" bash "$G" is-oc 2>&1)"; RC=$?
[ "$RC" -eq 3 ]; g $? "rc=3 (fark alınamadı)"; grep -q "fark alınamadı" <<<"$C" && ! grep -q "aradaki fark yalnız kanıt kaydı" <<<"$C"; g $? "yeşil ✓ basılmadı"

echo "════ O10-O11 · PR KİPİ (prbas): çıplak origin + birincil klon + iş alanı; PR başı refs/pull/<N>/head ════"
R="$(mktemp -d)"; ( cd "$R" && git init -q --bare uzak.git && git clone -q uzak.git ana && cd ana && git config user.email t@t && git config user.name T \
  && echo x > f && git add f && git commit -qm "chore: ilk" && git push -q origin HEAD:main ) >/dev/null 2>&1
P="$R/ana"
( cd "$P" && KANIT_DEPO="$P" bash "$KT" ac is-pr --is "örnek iş cümlesi burada" --istedi S --aldi M --geri-alinamaz h --para h --dis-yuzey h --yetki h --canli h >/dev/null 2>&1 )
git -C "$P" worktree add -q -b is-pr "$R/alan" >/dev/null 2>&1; A="$R/alan"; ( cd "$A" && git config user.email t@t && git config user.name T )
( cd "$A" && KANIT_DEPO="$A" bash "$K" olcum is-pr olc --asama tek -- echo 1 >/dev/null 2>&1 )
BAS="$(git -C "$A" rev-parse HEAD)"
python3 -c '
import json,sys,datetime
p,bas=sys.argv[1:]
json.dump({"tur":1,"is":"is-pr","pr":"7","yazan":"claude","denetci":"codex","bas":bas,"zaman":datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
 "kanit_durumu":"sağlam","sonuc":{"kod_puani":5,"dogru_sey":"E","ozet":"o","bulgular":[],"kanit_gorusu":"k"}},open(p,"w"))' "$A/_agents/fabrika/kanit/is-pr/DENETIM-1.json" "$BAS"
( cd "$A" && git add -A _agents && git commit -qm "docs: kanıt" && git push -q -f origin "HEAD:refs/pull/7/head" ) >/dev/null 2>&1
C="$( cd "$P" && env -u KANIT_DEPO bash "$G" is-pr --pr 7 2>&1 )"; RC=$?
[ "$RC" -eq 0 ] && grep -q "aradaki fark yalnız kanıt kaydı" <<<"$C"; g $? "O10 · PR başı = bas + yalnız kanıt kaydı → rc=0 (prbas yolu koştu)"
( cd "$A" && echo yeni > kod.sh && git add kod.sh && git commit -qm "fix: gozden sonra" && git push -q -f origin "HEAD:refs/pull/7/head" ) >/dev/null 2>&1
C="$( cd "$P" && env -u KANIT_DEPO bash "$G" is-pr --pr 7 2>&1 )"; RC=$?
[ "$RC" -eq 1 ] && grep -q "puan verildikten sonra kod değişmiş" <<<"$C" && grep -q "kod.sh" <<<"$C"; g $? "O11 · PR başına puandan sonra kod girdi → rc=1, dosya adıyla"
find "$R" -delete 2>/dev/null

echo "════ O12 · KANIT kaydı uçun soyundan OLMAYAN commit'te ölçülmüş → engellemez, söylenir ════"
kur; ( cd "$T" && git checkout -q -b yan2 && echo y > y.txt && git add -A && git commit -q -m "chore: yan" ) >/dev/null 2>&1
YC="$(git -C "$T" rev-parse yan2)"; ( cd "$T" && git checkout -q main ) >/dev/null 2>&1
python3 -c '
import json,sys,os,importlib.util
p,yc,here=sys.argv[1:]; m=json.load(open(p)); m["kayitlar"][-1]["olculen_commit"]=yc; m["kayitlar"][-1]["olculen_kirli"]=False
spec=importlib.util.spec_from_file_location("kanit",here+"/kanit.py"); k=importlib.util.module_from_spec(spec); spec.loader.exec_module(k)
m["imza"]=k.imza(m["kayitlar"]); json.dump(m,open(p,"w"))' "$T/_agents/fabrika/kanit/is-oc/KANIT.json" "$YC" "$HERE"
( cd "$T" && git add -A && git commit -q -m "chore: kanit yan" ) >/dev/null 2>&1
B="$(bas_al)"; den "$B"; C="$(kapi)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "soyundan olmayan commit'te ölçülmüş" <<<"$C"; g $? "yabancı commit'te ölçülmüş kayıt adıyla uyarıldı, engellenmedi"

echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"
[ "$kalan" -eq 0 ]
