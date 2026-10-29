#!/usr/bin/env bash
# mesveret.test.sh — hermetik sınav: sahte bulgu.sh + sahte gorev.sh, geçici kök. Gerçek deftere DOKUNMAZ.
# Kullanım: bash mesveret.test.sh [--mutant sayac]   (mutant: madde sayacı bozulur → özet kapısı KIRMIZI beklenir)
set -uo pipefail
H="$(cd "$(dirname "$0")" && pwd)"; BET="$H/mesveret.sh"
MUT="${2:-}"; [ "${1:-}" = "--mutant" ] || MUT=""
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export MESVERET_KOK="$T/kok" MESVERET_SAAT="2026-10-30T01:00:00+03:00" AGENT_NAME=SERDAR
# sahte bulgu.sh: argümanları kaydeder, görev kimliği basar
cat > "$T/bulgu.sh" <<'F'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$MESVERET_SAHTE_LOG/bulgu.args"
n=$(( $(cat "$MESVERET_SAHTE_LOG/sayac" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$MESVERET_SAHTE_LOG/sayac"
echo "kayıt yazıldı: gorev_01TEST$n"
F
cat > "$T/gorev.sh" <<'F'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MESVERET_SAHTE_LOG/gorev.args"; echo "adım eklendi"
F
chmod +x "$T/bulgu.sh" "$T/gorev.sh"; mkdir -p "$T/log"; export MESVERET_SAHTE_LOG="$T/log"
export MESVERET_BULGU="$T/bulgu.sh" MESVERET_GOREV="$T/gorev.sh"
G=0; K=0
kapi() { local ad="$1" ok="$2"; if [ "$ok" = 1 ]; then echo "✓ $ad"; G=$((G+1)); else echo "✗ $ad"; K=$((K+1)); fi; }

BET_KOS="$BET"
if [ "$MUT" = "sayac" ]; then
  cp "$BET" "$T/mutant.sh"; sed -i 's/print(len(json.load(open(sys.argv\[1\]))\["maddeler"\])+1)/print(1)/' "$T/mutant.sh"
  grep -q 'print(1)' "$T/mutant.sh" || { echo "MUTASYON uygulanamadı (çapa yok)"; exit 2; }
  BET_KOS="$T/mutant.sh"; echo "MUTASYON: madde sayacı hep 1"
fi

# M1 seans açılır
S=$(bash "$BET_KOS" basla --oda agentic-os --konu "deneme" 2>"$T/e1"); rc=$?
kapi "M1 seans açılır (rc 0, kimlik mes_…)" $([ $rc = 0 ] && [[ "$S" == mes_2026-10-30-* ]] && echo 1 || echo 0)
kapi "M1b şablon basıldı (Madde 1 · A/B/C)" $(grep -q "Madde 1'i çalışıyoruz" "$T/e1" && grep -q "A) Sen anlat" "$T/e1" && echo 1 || echo 0)
# M2 madde kaydı havuza gider + seans dosyasına işlenir + oda taşınır
out=$(bash "$BET_KOS" madde "$S" "Görev kartında yazılar çok büyük" --kim SERDAR --etiket bug --not "kapalı kart iç içe" 2>"$T/e2"); rc=$?
kapi "M2 madde kaydedildi rc 0 + görev kimliği" $([ $rc = 0 ] && grep -q "gorev_01TEST1" <<<"$out" && echo 1 || echo 0)
kapi "M2b bulgu.sh --oda seanstan alındı + not seans kimliğini taşır" $(grep -q "^agentic-os$" "$T/log/bulgu.args" && grep -q "Meşveret Seansı $S · madde 1" "$T/log/bulgu.args" && echo 1 || echo 0)
kapi "M2c önem sorusu basıldı" $(grep -q "Bu maddenin önemi" "$T/e2" && echo 1 || echo 0)
# M3 önem sözsüz REDDEDİLİR (A06)
bash "$BET_KOS" onem "$S" 1 --onem 3 >/dev/null 2>"$T/e3"; rc=$?
kapi "M3 A06: söz/oturum yok → rc 2, adım yazılmadı" $([ $rc = 2 ] && [ ! -f "$T/log/gorev.args" ] && echo 1 || echo 0)
# M4 önem sözle D1 adımı yazar
bash "$BET_KOS" onem "$S" 1 --onem 3 --soz "bu çok önemli" --oturum session_TEST >/dev/null 2>&1; rc=$?
kapi "M4 önem D1 adımı gorev.sh'a gitti" $([ $rc = 0 ] && grep -q 'adim gorev_01TEST1 D1 2026-10-30 Sultan: önem 3 (sohbet · session_TEST · "bu çok önemli" · beyan:SERDAR)' "$T/log/gorev.args" && echo 1 || echo 0)
# M5 ikinci madde + bitir özeti
bash "$BET_KOS" madde "$S" "Yaş rozeti kademeleri belirsiz" --kim SERDAR --etiket ozellik >/dev/null 2>&1
oz=$(bash "$BET_KOS" bitir "$S" 2>/dev/null)
kapi "M5 özet: 2 madde · önemi sorulmayan 1" $(grep -q "2 madde kaydedildi" <<<"$oz" && grep -q "önemi sorulmayan: 1" <<<"$oz" && echo 1 || echo 0)
kapi "M5c durum 2. maddeyi 2 numarayla listeler (sayaç)" $(bash "$BET_KOS" durum "$S" | grep -q "^  2\. Yaş rozeti" && echo 1 || echo 0)
kapi "M5b durum bitti, liste gösterir" $(bash "$BET_KOS" liste | grep -q "$S	bitti	2 madde" && echo 1 || echo 0)
# M6 defter kurulu değilse yazılmaz
MESVERET_BULGU="$T/yok.sh" bash "$BET_KOS" madde "$S" "Hiç yazılmamalı bu madde" --kim SERDAR --etiket bug >/dev/null 2>&1; rc=$?
kapi "M6 bulgu.sh yoksa rc 3 ve seansa madde eklenmez" $([ $rc = 3 ] && [ "$(bash "$BET_KOS" durum "$S" | grep -c '^  ')" = 2 ] && echo 1 || echo 0)
# M7 seans yok
bash "$BET_KOS" durum mes_yok >/dev/null 2>&1; kapi "M7 bilinmeyen seans rc 3" $([ $? = 3 ] && echo 1 || echo 0)

echo "== $G geçti · $K kaldı"
[ $K = 0 ]
