#!/usr/bin/env bash
# denetci-fark-kendisi.test.sh — "denetçi farkı kendisi alır" kapıları (gorev_01M54B2Y4QT7VWTJX10AFR7M76).
#
# NİÇİN AYRI DOSYA: denetci.test.sh'in kurulumu origin'siz tek depo; bu kapılar gerçek bir çıplak origin, iki klon ve
# ana hattın ilerlemesini ister. denetci.test.sh bu dosyayı ÇAĞIRIR ("test yazmak onu koşturmaz").
# HERMETİK: denetçi DENETCI_KOMUT ile sahte betik (istemi diske bırakır); `gh` PATH'te sahte betik (FAKE_* ortamından basar).
# Mutant kipi: MUTANT_D=<bozuk denetci.sh> ile koşunca kapılar o dosyayı sınar.
set -uo pipefail
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
printf '#!/usr/bin/env bash\ncase "$1 $2" in\n "pr view") printf "%%s\\n" "$FAKE_PR_VIEW";;\n "pr diff") printf "diff --git a/gh.txt b/gh.txt\\n+gh-farki\\n";;\n *) exit 9;;\nesac\n' > "$SAHTEGH/gh"; chmod +x "$SAHTEGH/gh"
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

echo "════ F5 · --pr: yerel dal PR dalıysa ve baş farklıysa DUR (itilmemiş commit) ════"
BAS="$(git -C "$KOK/w" rev-parse HEAD)"
kanitla f5; FAKE_PR_VIEW="0000000000000000000000000000000000000000 is-dal" PATH="$SAHTEGH:$PATH" kapi "F5a yerel baş ≠ PR başı (aynı dal) → rc=3" 3 den f5 --pr 7
iceren "F5b neden söyleniyor: FARKLI" "FARKLI" "$KOK/son.out"
kanitla f5b; : > "$KOK/istem.md"; FAKE_PR_VIEW="$BAS is-dal" PATH="$SAHTEGH:$PATH" kapi "F5c yerel baş = PR başı → GEÇTİ, GitHub farkı kullanıldı" 0 den f5b --pr 7
iceren "F5d istemde gh farkı var" "gh-farki" "$KOK/istem.md"
kanitla f5c; FAKE_PR_VIEW="1111111111111111111111111111111111111111 baska-dal" PATH="$SAHTEGH:$PATH" kapi "F5e başka dalın PR'ı (yerel dal farklı) → baş karşılaştırılmaz, GEÇTİ" 0 den f5c --pr 8

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
  mut bas '[ "$YEREL_BAS" != "${PR_BAS%% *}" ]; then' 'false; then' "F5a"
  mut kir '[ "$KIRLI" -eq 0 ] ||' 'true ||' "F4a"
  mut bos '[ -s "$TMP/diff.patch" ] ||' 'true ||' "F6a"
fi

echo ""; echo "── SONUÇ (fark-kendisi): $GECEN geçti · $DUSEN kaldı ──"
[ "$DUSEN" -eq 0 ]
