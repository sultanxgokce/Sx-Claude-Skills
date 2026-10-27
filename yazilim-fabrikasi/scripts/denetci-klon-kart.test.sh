#!/usr/bin/env bash
# denetci-klon-kart.test.sh — KLON ≠ İŞ ALANI (görev …D4R78T · SERDAR 26 Eki ölçümü).
#
# VAKA: munavebe-dogum PR #957 `gh repo clone` ile açılan kopyadan koşuldu; denetci.sh KART_DEPO'yu git-common-dir'den türetir,
#   klonda git-dir == git-common-dir → kart klonda aranır, yok, kart_yolu SESSİZCE boş → sultan-dedi 'devam' kararı görünmedi,
#   tur 4 rc 1 "kapı açılmadı". KART_DEPO=/config/projects/cloudtop verilince düzeldi.
# ÖLÇÜLEN: (1) klonda kart yokken birincil kopya (aynı uzak depo adı + aynı origin URL, BIRINCIL_KOK altında) bulunur, kart oradan
#   okunur ve çıktıda SÖYLENİR; sultan-dedi kararı görünür. (2) Aday yoksa/uymuyorsa uyarı AÇIK yazılır (sessiz değil), denetim
#   kartsız sürer. (3) Adı aynı ama origin'i farklı depo kart kaynağı SAYILMAZ. (4) KART_DEPO verildiyse arama yapılmaz.
#   (5) Uzak depo olmayan yerel sınav deposu: davranış değişmez (uyarı yok). + mutant: arama kaldırılınca (1) düşer.
# HERMETİK: sahte denetçi (DENETCI_KOMUT), sahte zil, geçici çıplak uzak; gerçek /config/projects'e dokunmaz.
# kabuk-testleri: sure=300
set -uo pipefail
export DALGIC_KAPALI=1 KANIT_SIRA=0 DENETCI_SIRA=0 FABRIKA_AILE_NOTIFY=-
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="${MUTANT_D:-$HERE/denetci.sh}"; K="$HERE/kanit.sh"; KT="$HERE/kart.sh"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
T="$(mktemp -d)"; trap 'python3 -c "import shutil,sys;shutil.rmtree(sys.argv[1],ignore_errors=True)" "$T"' EXIT
ZB="$T/.zil"; mkdir -p "$ZB"; printf '#!/usr/bin/env bash\nexit 0\n' > "$ZB/aile-notify.sh"; chmod +x "$ZB/aile-notify.sh"; export PATH="$ZB:$PATH"
TETIK_SAHTE="$T/tetik.sh"; printf '#!/usr/bin/env bash\nexit 0\n' > "$TETIK_SAHTE"; chmod +x "$TETIK_SAHTE"; export FABRIKA_TETIK="$TETIK_SAHTE"
SAHTE="$T/sahte.sh"; printf '#!/usr/bin/env bash\nprintf "%%s" "$SAHTE_JSON"\n' > "$SAHTE"; chmod +x "$SAHTE"; export DENETCI_KOMUT="$SAHTE"
export SAHTE_JSON='{"kod_puani":5,"dogru_sey":"E","ozet":"o","bulgular":[],"kanit_gorusu":"k"}'
GIT="git -c user.email=t@t -c user.name=t"
# çıplak uzak + birincil kopya (projects/depo-x) + klon (başka yerde)
mkdir -p "$T/uzak" "$T/projects"; $GIT init -q --bare "$T/uzak/depo-x.git"
$GIT clone -q "$T/uzak/depo-x.git" "$T/projects/depo-x" 2>/dev/null
( cd "$T/projects/depo-x" && printf 'x\n' > x && $GIT add x && $GIT commit -qm ilk && $GIT push -q origin HEAD:main 2>/dev/null && $GIT branch -q -M main 2>/dev/null || true )
$GIT clone -q "$T/uzak/depo-x.git" "$T/klon" 2>/dev/null
printf 'diff --git a/x b/x\n+satir\n' > "$T/d.patch"
IS=is-klon
# kart BİRİNCİLE yazılır (kart.sh git-common-dir'e yazar → projects/depo-x), Sultan 'devam' kararı da oraya
( cd "$T/projects/depo-x" && bash "$KT" ac $IS --is x --istedi SULTAN --aldi MUAVIN --geri-alinamaz h --para h --dis-yuzey h --yetki e --oda sinav-oda >/dev/null 2>&1 \
  && bash "$KT" sultan-dedi $IS --karar devam --oturum sinav-1 --soz "devam et" --beyan MUAVIN --gerekce "sınav: klon kapısı ölçümü için karar" >/dev/null 2>&1 )
[ -f "$T/projects/depo-x/_agents/fabrika/kartlar/$IS.json" ]; g $? "K0 kart birincilde (projects/depo-x) yazıldı"
# klonda kanıt (kanıt depo = klon)
( cd "$T/klon" && KANIT_DEPO="$T/klon" bash "$K" olcum $IS olc --asama tek -- echo 1 >/dev/null 2>&1 )

echo "════ K1 · klondan koşum: kart birincilden okunur ve söylenir, sultan-devam kapısı AÇILIR ════"
C1="$(cd "$T/klon" && KANIT_DEPO="$T/klon" BIRINCIL_KOK="$T/projects" bash "$D" $IS --diff "$T/d.patch" --sultan-devam 2>&1)"; R1=$?
grep -q "klon depodasın" <<<"$C1" && grep -q "kart birincil kopyadan okunuyor — $T/projects/depo-x" <<<"$C1"; g $? "K1a klon tespiti ve kaynak SÖYLENDİ"
KJ="$T/klon/_agents/fabrika/kanit/$IS/KART.json"
[ "$R1" -eq 0 ] && [ -f "$KJ" ] && cmp -s "$KJ" "$T/projects/depo-x/_agents/fabrika/kartlar/$IS.json"; g $? "K1b kart OKUNDU: kanıt dizinine KART.json kopyası birincil kartla bayt-eş, rc 0 · rc=$R1"
grep -q "kapı açılmadı\|karar YOK" <<<"$C1" && g 1 "K1c 'kapı açılmadı' basılmadı" || g 0 "K1c 'kapı açılmadı' basılmadı"
rm -f "$KJ"

echo "════ K2 · birincil aday YOK → uyarı AÇIK, denetim kartsız sürer ════"
C2="$(cd "$T/klon" && KANIT_DEPO="$T/klon" BIRINCIL_KOK="$T/olmayan" bash "$D" $IS --diff "$T/d.patch" 2>&1)"; R2=$?
grep -q "⚠ kart yok ($IS) ve bu kopya bir KLON olabilir" <<<"$C2" && grep -q "KART_DEPO=/config/projects/<depo>" <<<"$C2"; g $? "K2a uyarı + KART_DEPO önerisi yazıldı"
[ "$R2" -eq 0 ]; g $? "K2b kartsız denetim sürdü (5/E → rc 0) · rc=$R2"

echo "════ K3 · adı aynı, origin'i FARKLI depo kart kaynağı SAYILMAZ ════"
mkdir -p "$T/projects2"; $GIT init -q --bare "$T/uzak/baska.git"; $GIT clone -q "$T/uzak/baska.git" "$T/projects2/depo-x" 2>/dev/null
mkdir -p "$T/projects2/depo-x/_agents/fabrika/kartlar"; cp "$T/projects/depo-x/_agents/fabrika/kartlar/$IS.json" "$T/projects2/depo-x/_agents/fabrika/kartlar/"
C3="$(cd "$T/klon" && KANIT_DEPO="$T/klon" BIRINCIL_KOK="$T/projects2" bash "$D" $IS --diff "$T/d.patch" --sultan-devam 2>&1)"; R3=$?
grep -q "kart birincil kopyadan okunuyor" <<<"$C3" && g 1 "K3a farklı origin'li aynı ad kart kaynağı yapılmadı" || g 0 "K3a farklı origin'li aynı ad kart kaynağı yapılmadı"
grep -q "⚠ kart yok" <<<"$C3" && [ ! -f "$KJ" ]; g $? "K3b uyarı var, kart OKUNMADI (KART.json yok) · rc=$R3"

echo "════ K4 · KART_DEPO verildiyse arama yok, verilen kullanılır ════"
C4="$(cd "$T/klon" && KANIT_DEPO="$T/klon" KART_DEPO="$T/projects/depo-x" BIRINCIL_KOK="$T/olmayan" bash "$D" $IS --diff "$T/d.patch" --sultan-devam 2>&1)"; R4=$?
[ "$R4" -eq 0 ] && [ -f "$KJ" ] && ! grep -q "klon depodasın\|⚠ kart yok" <<<"$C4"; g $? "K4 verilen KART_DEPO ile kart okundu (KART.json var), arama/uyarı yok · rc=$R4"
rm -f "$KJ"

echo "════ K5 · uzak deposu olmayan yerel sınav deposu: davranış DEĞİŞMEZ (uyarı yok) ════"
mkdir -p "$T/yerel"; ( cd "$T/yerel" && $GIT init -q -b main && KANIT_DEPO="$T/yerel" bash "$K" olcum is-y olc --asama tek -- echo 1 >/dev/null 2>&1 )
C5="$(cd "$T/yerel" && KANIT_DEPO="$T/yerel" bash "$D" is-y --diff "$T/d.patch" 2>&1)"; R5=$?
[ "$R5" -eq 0 ] && ! grep -q "KLON\|klon depodasın" <<<"$C5"; g $? "K5 uzak yok → klon uyarısı yok, rc 0 · rc=$R5"

echo "════ K6 · mutant: birincil arama kaldırılınca K1 düşer ════"
M="$T/m.sh"; python3 - "$D" "$M" <<'PY'
import sys; s=open(sys.argv[1],encoding='utf-8').read()
a='KART_DEPO="$_aday"; KART_DEPO_KAYNAK="klon→birincil"'
assert s.count(a)==1, 'çapa bayat'
open(sys.argv[2],'w',encoding='utf-8').write(s.replace(a,': # mutant: arama sonucu kullanılmıyor'))
PY
C6="$(cd "$T/klon" && KANIT_DEPO="$T/klon" BIRINCIL_KOK="$T/projects" bash "$M" $IS --diff "$T/d.patch" --sultan-devam 2>&1)"; R6=$?
grep -qiE "syntax error|unbound variable" <<<"$C6" && g 1 "K6a mutant çökmedi (sahte yakalama değil)" || g 0 "K6a mutant çökmedi (sahte yakalama değil)"
[ ! -f "$KJ" ]; g $? "K6b MUTASYON: birincil kullanılmazsa kart OKUNMAZ (KART.json yok) → K1b bu mutantta düşerdi · rc=$R6"

echo; echo "SONUÇ: $gecen geçti · $kalan kaldı"; [ "$kalan" -eq 0 ]
