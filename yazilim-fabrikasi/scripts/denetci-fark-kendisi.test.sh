#!/usr/bin/env bash
# denetci-fark-kendisi.test.sh — "denetçi farkı kendisi alır" kapıları (gorev_01M54B2Y4QT7VWTJX10AFR7M76).
#
# NİÇİN AYRI DOSYA: denetci.test.sh'in kurulumu origin'siz tek depo; bu kapılar gerçek bir çıplak origin, iki klon ve
# ana hattın ilerlemesini ister. denetci.test.sh bu dosyayı ÇAĞIRIR ("test yazmak onu koşturmaz").
# HERMETİK: denetçi DENETCI_KOMUT ile sahte betik (istemi diske bırakır); `gh` PATH'te sahte betik (FAKE_* ortamından basar).
# Mutant kipi: MUTANT_D=<bozuk denetci.sh> ile koşunca kapılar o dosyayı sınar.
set -uo pipefail
export DALGIC_KAPALI=1   # ön-göz (ZP640T) sınavda KAPALI: gerçek model çağrısı yok; kendi sınavı denetci.test.sh T-ONGOZ
export KANIT_SIRA=0 DENETCI_SIRA=0   # ağır sıra sarması (489VP8) sınavda KAPALI: gerçek sıra kütüğüne/yüküne dokunma; sarma kendi sınavında (agir-sira-sarma.test.sh)
export FABRIKA_AILE_NOTIFY=-   # denetçi bitiş zili sınavda KAPALI (gerçek koltuklara çalmasın); zil kapısı kendi sahtesini verir
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="${MUTANT_D:-$HERE/denetci.sh}"; K="$HERE/kanit.sh"
GECEN=0; DUSEN=0
kapi() { local ad="$1" bek="$2"; shift 2
  "$@" >"$KOK/son.out" 2>&1; local rc=$?
  if [[ $rc -eq $bek ]]; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad (rc=$rc, beklenen=$bek)"; fi; }
iceren() { local ad="$1" ara="$2" dosya="$3"
  if grep -qF -- "$ara" "$dosya" 2>/dev/null; then GECEN=$((GECEN+1)); echo "  ✓ $ad"
  else DUSEN=$((DUSEN+1)); echo "  ✗ $ad ('$ara' $dosya içinde yok)"; fi; }
icermeyen() { local ad="$1" ara="$2" dosya="$3"
  if grep -qF -- "$ara" "$dosya" 2>/dev/null; then DUSEN=$((DUSEN+1)); echo "  ✗ $ad ('$ara' var, olmamalı)"
  else GECEN=$((GECEN+1)); echo "  ✓ $ad"; fi; }

KOK="$(mktemp -d)"; trap 'rm -r -f "$KOK" 2>/dev/null' EXIT
git init -q --bare -b main "$KOK/o.git"
git clone -q "$KOK/o.git" "$KOK/w" 2>/dev/null; git clone -q "$KOK/o.git" "$KOK/baska" 2>/dev/null
for r in w baska; do git -C "$KOK/$r" config user.email t@t; git -C "$KOK/$r" config user.name t; done
echo taban > "$KOK/w/a.txt"; git -C "$KOK/w" add a.txt; git -C "$KOK/w" commit -q -m taban; git -C "$KOK/w" push -q origin main 2>/dev/null
git -C "$KOK/w" remote set-head origin main >/dev/null 2>&1
git -C "$KOK/w" checkout -q -b is-dal
echo benim > "$KOK/w/benim-isim.txt"; git -C "$KOK/w" add benim-isim.txt; git -C "$KOK/w" commit -q -m benim
printf 'İŞ: fark kendisi\nSINIF: yok\n' > "$KOK/kart.md"

SAHTE="$KOK/sahte.sh"; printf '#!/usr/bin/env bash\ncp "$1" "$SAHTE_ISTEM_KOPYA"; printf %%s "$SAHTE_JSON"\n' > "$SAHTE"; chmod +x "$SAHTE"
export DENETCI_KOMUT="$SAHTE" SAHTE_ISTEM_KOPYA="$KOK/istem.md"
export SAHTE_JSON='{"kod_puani":5,"dogru_sey":"E","ozet":"o","bulgular":[],"kanit_gorusu":"k"}'
SAHTEGH="$KOK/bin"; mkdir -p "$SAHTEGH"
# sahte gh: FAKE_GH_ESC=1 → gerçek gh 2.98 gibi davranır: bayraksız `pr diff` kaçış dizisi var diye düşer, bayrakla ESC baytlı farkı basar;
#   FAKE_GH_FAIL=1 → `pr diff` her hâlde düşer (git yolu sınanır). ESC baytı printf ile üretilir (metin olarak kaçış kalıbı YAZILMAZ — gh onu da reddeder).
cat > "$SAHTEGH/gh" <<'GH'
#!/usr/bin/env bash
E="$(printf '\033')"
case "$1 $2" in
 "pr view") printf "%s\n" "$FAKE_PR_VIEW";;
 "pr diff") [ -n "${FAKE_GH_FAIL:-}" ] && { echo "sahte gh: pr diff düştü" >&2; exit 1; }
    if [ -n "${FAKE_GH_ESC:-}" ]; then
      [[ " $* " == *" --allow-escape-sequences "* ]] || { echo "the diff contains terminal escape sequences; pass --allow-escape-sequences" >&2; exit 1; }
      printf 'diff --git a/gh.txt b/gh.txt\n+esc-farki %s[2mrenkli%s[22m son\n' "$E" "$E"
    else printf 'diff --git a/gh.txt b/gh.txt\n+gh-farki\n'; fi;;
 *) exit 9;;
esac
GH
chmod +x "$SAHTEGH/gh"
kanitla() { KANIT_DEPO="$KOK/w" bash "$K" olcum "$1" o --asama tek -- true >/dev/null 2>&1; }
den() { local is="$1"; shift; ( cd "$KOK/w" && KANIT_DEPO="$KOK/w" bash "$D" "$is" --kart "$KOK/kart.md" "$@" < /dev/null ); }

echo "════ F1 · yerel kip: --pr/--diff yok → denetçi farkı kendisi alır (üç-nokta, ana hat güncel) ════"
kanitla f1; : > "$KOK/istem.md"
kapi "F1a yerel kip GEÇTİ (rc=0) — kanıt dizini kayıtsız olsa bile (kanıt/kart dışı kir sayılır)" 0 den f1
iceren "F1b ekranda fark kaynağı söyleniyor" "fark: yerel üç-nokta" "$KOK/son.out"
iceren "F1c istemde dalın kendi değişikliği var" "benim-isim.txt" "$KOK/istem.md"

echo "════ F2 · ana hat ilerledi (başkası itti), dal geride → DUR rc=3, denetim yazılmaz ════"
git -C "$KOK/baska" pull -q origin main 2>/dev/null; echo baskasi > "$KOK/baska/baskasinin.txt"
git -C "$KOK/baska" add baskasinin.txt; git -C "$KOK/baska" commit -q -m baska; git -C "$KOK/baska" push -q origin main 2>/dev/null
kanitla f2; : > "$KOK/istem.md"
kapi "F2a dal 1 commit geride → rc=3 (iki-nokta tuzağı kapalı)" 3 den f2
iceren "F2b neden söyleniyor: GERİSİNDE" "GERİSİNDE" "$KOK/son.out"
[ ! -s "$KOK/istem.md" ] && GECEN=$((GECEN+1)) && echo "  ✓ F2c denetçiye istem GİTMEDİ (tur yanmadı)" || { DUSEN=$((DUSEN+1)); echo "  ✗ F2c istem gitti"; }

echo "════ F3 · ana hat dala birleştirildi → geçer; başkasının dosyası farkta 'silinmiş' görünmez ════"
git -C "$KOK/w" merge -q --no-edit origin/main 2>/dev/null
kanitla f3; : > "$KOK/istem.md"
kapi "F3a birleştirmeden sonra yerel kip GEÇTİ" 0 den f3
iceren "F3b istemde dalın değişikliği var" "benim-isim.txt" "$KOK/istem.md"
icermeyen "F3c başkasının dosyası farka girmedi (üç-nokta)" "baskasinin.txt" "$KOK/istem.md"

echo "════ F4 · kayıtsız kod değişikliği → DUR rc=3 (farka girmezdi) ════"
echo yarim > "$KOK/w/kayitsiz.txt"; kanitla f4
kapi "F4a kanıt/kart dışı kayıtsız dosya → rc=3" 3 den f4
iceren "F4b neden söyleniyor: kayıtsız" "kayıtsız değişiklik" "$KOK/son.out"
mv "$KOK/w/kayitsiz.txt" "$KOK/kayitsiz.txt"
mkdir -p "$KOK/w/_agents/fabrika"; echo "TAVAN-ACILDI" > "$KOK/w/_agents/fabrika/tavan-defteri.log"; kanitla f4c; : > "$KOK/istem.md"
kapi "F4c (…VAHT3) tavan-defteri.log aracın kendi defteridir, kayıtsız değişiklik SAYILMAZ → GEÇTİ (devam yolu kendi kapısına takılmaz)" 0 den f4c
mv "$KOK/w/_agents/fabrika/tavan-defteri.log" "$KOK/tavan-defteri.log"

echo "════ F5 · --pr: PR dalının yerel kopyası varsa ve başı PR başından farklıysa DUR (itilmemiş commit) — hangi dalda durulursa dursun ════"
BAS="$(git -C "$KOK/w" rev-parse HEAD)"
kanitla f5; FAKE_PR_VIEW="0000000000000000000000000000000000000000 is-dal" PATH="$SAHTEGH:$PATH" kapi "F5a yerel baş ≠ PR başı (aynı dal) → rc=3" 3 den f5 --pr 7
iceren "F5b neden söyleniyor: FARKLI" "FARKLI" "$KOK/son.out"
kanitla f5b; : > "$KOK/istem.md"; FAKE_PR_VIEW="$BAS is-dal" PATH="$SAHTEGH:$PATH" kapi "F5c yerel baş = PR başı → GEÇTİ, GitHub farkı kullanıldı" 0 den f5b --pr 7
iceren "F5d istemde gh farkı var" "gh-farki" "$KOK/istem.md"
kanitla f5c; FAKE_PR_VIEW="1111111111111111111111111111111111111111 hic-cekilmemis-dal" PATH="$SAHTEGH:$PATH" kapi "F5e PR dalının yerel kopyası YOK (başkasının, çekilmemiş) → itilmemiş commit olamaz, GEÇTİ" 0 den f5c --pr 8
git -C "$KOK/w" checkout -q -b denetleyen-dal; kanitla f5f
FAKE_PR_VIEW="0000000000000000000000000000000000000000 is-dal" PATH="$SAHTEGH:$PATH" kapi "F5f BAŞKA dalda durulurken bile PR dalının (is-dal) yerel başı ≠ PR başı → rc=3 (göz tur 1)" 3 den f5f --pr 7
git -C "$KOK/w" checkout -q is-dal; git -C "$KOK/w" branch -q -D denetleyen-dal

echo "════ F8 · kaçış kodlu fark (Z9SZF3): gh bayraksız reddeder → bayrakla alınır ve ESC süzülür; gh hep düşerse git yolu; o da yoksa rc=3 ════"
kanitla f8; : > "$KOK/istem.md"; FAKE_GH_ESC=1 FAKE_PR_VIEW="$BAS is-dal" PATH="$SAHTEGH:$PATH" kapi "F8a farkta ESC baytı var → gh bayrakla alındı, denetim GEÇTİ (rc 3 değil)" 0 den f8 --pr 7
iceren "F8b istemde gh farkı var (esc-farki)" "esc-farki" "$KOK/istem.md"
icermeyen "F8c isteme giden farkta ESC baytı YOK (süzüldü)" "$(printf '\033')" "$KOK/istem.md"
iceren "F8d fark kaynağı 'kaçış dizileri süzüldü' der" "kaçış dizileri süzüldü" "$KOK/son.out"
git -C "$KOK/w" push -q origin is-dal 2>/dev/null; git -C "$KOK/o.git" update-ref refs/pull/9/head "$BAS"
kanitla f8e; : > "$KOK/istem.md"; FAKE_GH_FAIL=1 FAKE_PR_VIEW="$BAS is-dal" PATH="$SAHTEGH:$PATH" kapi "F8e gh pr diff hep düşer, origin pull/9/head var → git yolu, GEÇTİ" 0 den f8e --pr 9
iceren "F8f istemde git farkı var (benim-isim)" "benim-isim" "$KOK/istem.md"
iceren "F8g fark kaynağı git yolunu söyler" "→ git origin/main" "$KOK/son.out"
kanitla f8h; FAKE_GH_FAIL=1 FAKE_PR_VIEW="$BAS is-dal" PATH="$SAHTEGH:$PATH" kapi "F8h gh düşer ve pull/10/head yok → rc=3" 3 den f8h --pr 10
iceren "F8i iki sebep birden söyleniyor" "git yolu da alınamadı" "$KOK/son.out"

echo "════ F6 · boş fark → DUR rc=3 ════"
git -C "$KOK/w" checkout -q -b bos-dal origin/main 2>/dev/null; kanitla f6
kapi "F6a dal = ana hat → fark boş, rc=3" 3 den f6
git -C "$KOK/w" checkout -q is-dal

echo "════ F7 · MUTASYON: her kapı kaldırılınca bir F kapısı düşer (mutant ana dosyanın kopyasıdır) ════"
if [ -z "${MUTANT_D:-}" ]; then
  # Mutant, betik dizininin TAM KOPYASINDA oluşturulur (kardeşler — kanit.sh, şema, kart.sh — yanında olmalı; yoksa denetçi
  # erken bir hata koduyla döner ve kapılar TESADÜFEN geçer: mutasyon kanıtı yanıltır). Geçerli mutant şartı ikili:
  # hedef kapı DÜŞER ve kontrol kapısı F1a (mutasyonun dokunmadığı yol) GEÇER.
  mut() { local ad="$1" eski="$2" yeni="$3" kapi_adi="$4"; local P="$KOK/mutpkg-$ad"; mkdir -p "$P"; cp -p "$HERE"/* "$P/" 2>/dev/null
    python3 - "$HERE/denetci.sh" "$P/denetci.sh" "$eski" "$yeni" <<'PY'
import sys; s,d,e,y=sys.argv[1:]; t=open(s,encoding='utf-8').read(); assert e in t, "desen yok: "+e; open(d,'w',encoding='utf-8').write(t.replace(e,y,1))
PY
    local O; O="$(MUTANT_D="$P/denetci.sh" bash "$HERE/denetci-fark-kendisi.test.sh" 2>/dev/null)"
    if grep -q "✗ $kapi_adi" <<<"$O" && grep -q "✓ F1a" <<<"$O"; then
      GECEN=$((GECEN+1)); echo "  ✓ mutant '$ad' → $kapi_adi düştü, kontrol F1a geçti (kapı gerçekten ölçüyor)"
    else DUSEN=$((DUSEN+1)); echo "  ✗ mutant '$ad' → $kapi_adi düşmedi ya da kontrol F1a da düştü (geçersiz mutant)"; fi; }
  mut geride '[ "$GERIDE" -eq 0 ] ||' 'true ||' "F2a"
  mut bas '[ "$YEREL_BAS" != "$PR_SHA" ]; then' 'false; then' "F5a"
  mut bas-dal 'YEREL_BAS="$(git -C "$DEPO" rev-parse -q --verify "refs/heads/$PR_DAL" 2>/dev/null)"' 'YEREL_BAS="$( [ "$(git -C "$DEPO" rev-parse --abbrev-ref HEAD)" = "$PR_DAL" ] && git -C "$DEPO" rev-parse HEAD)"' "F5f"
  mut kir '[ "$KIRLI" -eq 0 ] ||' 'true ||' "F4a"
  mut bos '[ -s "$TMP/diff.patch" ] ||' 'true ||' "F6a"
  mut tavan-defteri '|tavan-defteri\.log$)' ')' "F4c"
  mut esc-bayragi 'gh pr diff "$PR" --allow-escape-sequences >' 'gh pr diff "$PR" >' "F8a"
  mut esc-suzgeci "b = re.sub(ESC + rb'\\[[0-9;?]*[ -/]*[@-~]', b'', b); b = b.replace(ESC, b'')" "pass" "F8c"
  mut git-yolu 'git -C "$DEPO" fetch -q origin "pull/$PR/head" 2>/dev/null &&' 'false &&' "F8e"
fi

echo ""; echo "── SONUÇ (fark-kendisi): $GECEN geçti · $DUSEN kaldı ──"
[ "$DUSEN" -eq 0 ]
