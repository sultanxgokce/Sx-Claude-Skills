#!/usr/bin/env bash
# on-goz.test.sh — ön göz mekanik kapılarının (on-goz.py A1-A5) sınavı. Görev W42-E1 …W7H1EBA · tasarım Nexus on-goz-adimi-DESIGN.md S1-S8, S11.
#   Hermetik: geçici çıplak uzak depo + iş alanı klonu, kanıt GERÇEK kanit.sh ile alınır, gh sahte (PATH başında). Model çağrısı yok.
#   ON_GOZ verilirse o kopya sınanır (önce/mutant ölçümü için).
set -u
export KANIT_SIRA=0 DENETCI_SIRA=0
HERE="$(cd "$(dirname "$0")" && pwd)"; OG="${ON_GOZ:-$HERE/on-goz.py}"; K="$HERE/kanit.sh"
gecen=0; kalan=0
g() { if [ "$1" -eq 0 ]; then gecen=$((gecen+1)); echo "  ✓ $2"; else kalan=$((kalan+1)); echo "  ✗ $2"; fi; }
T="$(mktemp -d)"; trap 'find "$T" -depth -delete 2>/dev/null' EXIT
mkdir -p "$T/bin"; cat > "$T/bin/gh" <<'EOF'
#!/usr/bin/env bash
[ -n "${FAKE_GH_RC:-}" ] && exit "$FAKE_GH_RC"
echo "${FAKE_PR_BAS:-}"
EOF
chmod +x "$T/bin/gh"; export PATH="$T/bin:$PATH" IS_ALANI_KOK="$T/alanlar"
export GIT_AUTHOR_NAME=s GIT_AUTHOR_EMAIL=s@s GIT_COMMITTER_NAME=s GIT_COMMITTER_EMAIL=s@s
W=""
kur() {  # kur <ad> [kart cümlesi] → $W: iş alanı (dal 'is1' itilmiş, kanıt HEAD'de alınmış, mutant hedef kapılı)
  local d="$T/$1"; mkdir -p "$d"; git init -q --bare -b main "$d/R.git"; git clone -q "$d/R.git" "$d/W" 2>/dev/null; W="$d/W"
  ( cd "$W" && printf 'a\nb\nc\n' > kod.txt && mkdir -p _agents/fabrika && printf 'satir\n' > _agents/fabrika/tavan-defteri.log && git add -A && git commit -qm taban && git push -q origin main 2>/dev/null
    git checkout -qb is1; mkdir -p _agents/fabrika/kartlar
    python3 -c "import json,sys;json.dump({'is':'is1','cumle':sys.argv[1]},open('_agents/fabrika/kartlar/is1.json','w'),ensure_ascii=False)" "${2:-Kod satırı değişir}"
    printf 'a\nB\nc\n' > kod.txt; printf 'echo "  ✓ X1 geçti"; exit 0\n' > s.sh; printf 'echo "  ✗ X1 düştü"; exit 1\n' > m.sh
    git add -A && git commit -qm is )
  ( cd "$W" && KANIT_DEPO="$W" bash "$K" olcum is1 sinav --asama sonra -- bash s.sh >/dev/null 2>&1
    KANIT_DEPO="$W" bash "$K" olcum is1 mut --asama sonra --mutasyon sinav --kapi X1 -- bash m.sh >/dev/null 2>&1
    git add -A && git commit -qm kanit && git push -q -u origin is1 2>/dev/null )
}
og() { (cd "$W" && python3 "$OG" is1 "$@" 2>&1); }
ogj() { (cd "$W" && python3 "$OG" is1 --json "$@" 2>/dev/null); }
kd() { python3 -c "import json,sys;d=json.loads(sys.argv[1]);print([k['durum'] for k in d['kapilar'] if k['ad'].startswith(sys.argv[2])][0])" "$1" "$2" 2>/dev/null; }

echo "── S1 · temiz iş"
kur s1; O="$(og)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "ÖN GÖZ (mekanik): UYUMLU" <<<"$O"; g $? "S1 kanıt HEAD'de, dal itilmiş, tabanın üstünde, ağaç temiz → UYUMLU rc 0 [rc=$RC]"
echo "── A1 · kanıt başı"
(cd "$W" && printf 'a\nB\nC\n' > kod.txt && git commit -qam sonra-degisti && git push -q 2>/dev/null)
O="$(og)"; RC=$?; J="$(ogj)"
[ "$RC" -eq 1 ] && [ "$(kd "$J" A1)" = uyumsuz ] && grep -qE "'sinav' .*[0-9a-f]{8}'de ölçülmüş, HEAD [0-9a-f]{8}.*kod.txt" <<<"$O"; g $? "S2 kanıttan sonra kod commit'i → A1 UYUMSUZ, iki sha ve dosya adı yazılır, rc 1"
kur s3; (cd "$W" && echo ek > _agents/fabrika/kanit/is1/ek.txt && git add -A && git commit -qm yalniz-kanit && git push -q 2>/dev/null)
[ "$(kd "$(ogj)" A1)" = uyumlu ]; g $? "S3 HEAD ile ölçülen commit arasında YALNIZ kanıt dosyası → A1 uyumlu (kapının istisnası)"
kur s3b; (cd "$W" && KANIT_DEPO="$W" bash "$K" olcum is1 sinav --asama once -- bash s.sh >/dev/null 2>&1; git add -A; git commit -qm once-kaydi
  printf 'x\n' > kod2.txt && git add -A && git commit -qm duzeltme
  KANIT_DEPO="$W" bash "$K" olcum is1 sinav --asama sonra -- bash s.sh >/dev/null 2>&1; KANIT_DEPO="$W" bash "$K" olcum is1 mut --asama sonra --mutasyon sinav --kapi X1 -- bash m.sh >/dev/null 2>&1
  git add -A && git commit -qm kanit2 && git push -q 2>/dev/null)
[ "$(kd "$(ogj)" A1)" = uyumlu ]; g $? "S3b 'once' kaydı eski commit'te ölçülmüş olsa da muaf → A1 uyumlu"
kur s4; (cd "$W" && echo ek > _agents/fabrika/kanit/is1/ek.txt && git add -A && git commit -qm itilmedi)
O="$(og)"; grep -q "itilmiş dal [0-9a-f]\{8\} ≠ HEAD [0-9a-f]\{8\} — önce it" <<<"$O"; g $? "S4 itilmemiş commit → A1 'önce it'"
kur s4p; H="$(git -C "$W" rev-parse HEAD)"
[ "$(kd "$(FAKE_PR_BAS="$H" ogj --pr 7)" A1)" = uyumlu ]; g $? "S4p PR başı = HEAD → A1 uyumlu"
O="$(FAKE_PR_BAS=0123456789abcdef0123 og --pr 7)"; grep -q "PR #7 başı 01234567 ≠ HEAD" <<<"$O"; g $? "S4q PR başı ≠ HEAD → A1 uyumsuz 'önce it'"
O="$(FAKE_GH_RC=255 og --pr 7)"; RC=$?; J="$(FAKE_GH_RC=255 ogj --pr 7)"
[ "$RC" -eq 3 ] && [ "$(kd "$J" A1)" = olculemedi ] && grep -q "ÖLÇÜLEMEDİ" <<<"$O"; g $? "S11 PR başı okunamıyor (gh 255) → A1 ölçülemedi, hüküm ÖLÇÜLEMEDİ rc 3 (uyumlu sayılmaz) [rc=$RC]"
echo "── A2 · kanıt eksik"
kur s5; O="$(cd "$W" && python3 "$OG" baska-is 2>&1)"; grep -q "A2 kanıt eksik: kanıt yok" <<<"$O"; g $? "S5 kanıt dizini yok → A2 'kanıt yok'"
kur s6; GO="$(cd "$W" && KANIT_DEPO="$W" bash "$K" gecersiz is1 olcum-sinav-sonra.txt --neden "sınavda geçersiz ilan edilen tek gerçek ölçüm" --kim S 2>&1)"; (cd "$W" && git add -A && git commit -qm gecersiz >/dev/null && git push -q 2>/dev/null)
O="$(og)"; grep -q "geçerli gerçek ölçüm kaydı yok" <<<"$O"; g $? "S6 tek gerçek ölçüm geçersiz ilan edildi → A2 uyumsuz (mutant gerçek ölçüm sayılmaz) [$(tail -1 <<<"$GO" | cut -c1-90)]"
kur s7; (cd "$W" && printf 'echo "  ✗ Y1 düştü"; exit 1\n' > m2.sh && git add m2.sh && git commit -qm m2 && KANIT_DEPO="$W" bash "$K" olcum is1 sinav --asama sonra -- bash s.sh >/dev/null 2>&1 && KANIT_DEPO="$W" bash "$K" olcum is1 mut2 --asama sonra --mutasyon sinav --kapi X1 -- bash m2.sh >/dev/null 2>&1; git add -A; git commit -qm yanlis-kapi; git push -q 2>/dev/null)
O="$(og)"; grep -q "mutant kaydı 'mut2' hedef kapısı (X1) DÜŞMEDİ" <<<"$O"; g $? "S7 mutant başka kapıyı düşürdü, hedef kapı (X1) düşmedi → A2 uyumsuz (kanit.sh hedefsiz mutantı zaten kaydetmez)"
echo "── A3 · taban"
kur s8; (cd "$W" && git checkout -q main && printf 'a\nZ\nc\n' > kod.txt && git commit -qam main-cakisan && git push -q origin main 2>/dev/null && git checkout -q is1 && git fetch -q)
O="$(og)"; grep -q "A3 taban: origin/main 1 commit ileride ve birleştirme ÇAKIŞIYOR (kod.txt)" <<<"$O"; g $? "S8 taban ileride ve çakışıyor → A3 uyumsuz, dosya adıyla"
kur s8b; (cd "$W" && git checkout -q main && echo yeni > baska.txt && git add baska.txt && git commit -qm main-cakismayan && git push -q origin main 2>/dev/null && git checkout -q is1 && git fetch -q)
J="$(ogj)"; [ "$(kd "$J" A3)" = uyumlu ] && grep -q "bilgi: origin/main 1 commit ileride, çakışma yok" <<<"$(og)"; g $? "S8b taban ileride ama çakışma yok → A3 uyumlu (bilgi satırı)"
echo "── A4 · ağaç"
kur s9; (cd "$W" && echo kirli >> kod.txt)
O="$(og)"; grep -q "commit'lenmemiş izlenen dosya: kod.txt" <<<"$O"; g $? "S9 izlenen dosya commit'lenmemiş → A4 uyumsuz"
kur s9b; (cd "$W" && echo kirli >> _agents/fabrika/kanit/is1/KANIT.json)
[ "$(kd "$(ogj)" A4)" = uyumlu ]; g $? "S9b yalnız kanıt dizini kirli → A4 uyumlu"
echo "── A5 · kapsam"
kur s10 "Kod satırı değişir; tavan-defteri.log dokunulmaz (ayrı kart)"; (cd "$W" && echo ek >> _agents/fabrika/tavan-defteri.log && git commit -qam tavan && KANIT_DEPO="$W" bash "$K" olcum is1 sinav --asama sonra -- bash s.sh >/dev/null 2>&1 && KANIT_DEPO="$W" bash "$K" olcum is1 mut --asama sonra --mutasyon sinav --kapi X1 -- bash m.sh >/dev/null 2>&1; git add -A; git commit -qm kanit3; git push -q 2>/dev/null)
O="$(og)"; grep -q "kart cümlesinde kapsam dışı denen yol farkta: _agents/fabrika/tavan-defteri.log ← 'tavan-defteri.log'" <<<"$O"; g $? "S10 kart 'dokunulmaz' dediği dosya farkta → A5 uyumsuz"
kur s10b "Kod satırı değişir; tavan-defteri.log dokunulmaz (ayrı kart)"
[ "$(kd "$(ogj)" A5)" = uyumlu ]; g $? "S10b aynı cümle, dosya farkta yok → A5 uyumlu"
kur s12; rm -f "$W/_agents/fabrika/kartlar/is1.json"; (cd "$W" && git commit -qam kartsiz && git push -q 2>/dev/null)
[ "$(kd "$(ogj)" A5)" = olculemedi ]; g $? "S12 kart yok → A5 ölçülemedi"
echo "── SONUÇ: $gecen geçti · $kalan kaldı ──"; exit $((kalan > 0))
