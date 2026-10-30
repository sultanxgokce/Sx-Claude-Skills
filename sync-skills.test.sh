#!/usr/bin/env bash
# sync-skills.test.sh — dağıtımın "kullanılabilir mi" kapıları (2026-08-04).
# Gerçek /config/.claude'a DOKUNMAZ: her kapı kendi sahte kaynak+hedef ağacıyla koşar.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="${SYNC_SKILLS_SUT:-$HERE/sync-skills.mjs}"   # SYNC_SKILLS_SUT: mutant koşusu için
gecen=0; kalan=0
kapi(){ if [ "$2" = 0 ]; then printf '  ✓ %s\n' "$1"; gecen=$((gecen+1)); else printf '  ✗ %s\n' "$1"; kalan=$((kalan+1)); fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# Sahte repo: sync-skills.mjs + kendi sync-targets.json + tek skill
_kur() { # $1=kaynak-script-kipi (755/644) $2=sozdizimi(ok/bozuk)
  R="$T/repo$RANDOM"; mkdir -p "$R/deneme-skill/scripts" "$R/hedef"
  cp "$SUT" "$R/sync-skills.mjs"
  printf -- '---\nname: deneme-skill\nversion: 1.0.0\n---\ngövde\n' > "$R/deneme-skill/SKILL.md"
  if [ "$2" = ok ]; then printf '#!/usr/bin/env bash\necho merhaba\n' > "$R/deneme-skill/scripts/calis.sh"
  else printf '#!/usr/bin/env bash\nif [ 1 = 1 ]; then\necho eksik-fi\n' > "$R/deneme-skill/scripts/calis.sh"; fi
  chmod "$1" "$R/deneme-skill/scripts/calis.sh"
  printf '{"targets":{"_t":"%s/hedef"},"install":{"deneme-skill":["_t"]}}\n' "$R" > "$R/sync-targets.json"
  printf '%s' "$R"
}

echo "── dağıtım duman kapıları ──"

# G1 · ÇALIŞTIRMA İZNİ KORUNUR (bugünkü canlı vaka: kapimda dağıtıldı, "Permission denied")
R="$(_kur 755 ok)"
(cd "$R" && node sync-skills.mjs --apply >/dev/null 2>&1)
[ -x "$R/hedef/deneme-skill/scripts/calis.sh" ]
kapi "G1 kaynak çalıştırılabilirse hedef de çalıştırılabilir" $?

# G2 · duman testi TEMİZ dağıtımda sessiz + exit 0
R="$(_kur 755 ok)"
out="$(cd "$R" && node sync-skills.mjs --apply 2>&1)"; rc=$?
[ "$rc" = 0 ] && ! printf '%s' "$out" | grep -q 'DUMAN TESTİ DÜŞTÜ'
kapi "G2 sağlam dağıtımda duman testi sessiz, exit 0" $?

# G3 · İZİNSİZ dosya → duman DÜŞER ve dağıtım YEŞİL DEMEZ
R="$(_kur 644 ok)"
out="$(cd "$R" && node sync-skills.mjs --apply 2>&1)"; rc=$?
printf '%s' "$out" | grep -q 'ÇALIŞTIRILAMAZ' && [ "$rc" != 0 ]
kapi "G3 çalıştırılamaz dosya → duman düşer, exit≠0" $?

# G4 · BOZUK SÖZDİZİMİ → duman DÜŞER
R="$(_kur 755 bozuk)"
out="$(cd "$R" && node sync-skills.mjs --apply 2>&1)"; rc=$?
printf '%s' "$out" | grep -q 'SÖZDİZİMİ BOZUK' && [ "$rc" != 0 ]
kapi "G4 bozuk sözdizimi → duman düşer, exit≠0" $?

# G5 · ÖZET SATIRI duman sayısını GÖSTERİR (sessiz yutulmaz)
printf '%s' "$out" | grep -q 'duman-düştü'
kapi "G5 özet satırında duman sayacı görünür" $?

# G6 · scripts/ OLMAYAN skill hata DEĞİL (yanlış-alarm yok)
R="$(_kur 755 ok)"; rm -r "$R/deneme-skill/scripts"
out="$(cd "$R" && node sync-skills.mjs --apply 2>&1)"; rc=$?
[ "$rc" = 0 ] && ! printf '%s' "$out" | grep -q 'DUMAN TESTİ DÜŞTÜ'
kapi "G6 scripts'siz skill duman-düşmez (yanlış alarm yok)" $?

# G7 · duman testi ZARARSIZ: dağıtılan script KOŞULMAZ (yan-etki üretmez)
R="$(_kur 755 ok)"
printf '#!/usr/bin/env bash\ntouch "%s/YAN-ETKI"\n' "$T" > "$R/deneme-skill/scripts/calis.sh"
chmod 755 "$R/deneme-skill/scripts/calis.sh"
(cd "$R" && node sync-skills.mjs --apply >/dev/null 2>&1)
[ ! -e "$T/YAN-ETKI" ]
kapi "G7 duman testi script'i KOŞMAZ (yan-etki yok)" $?

# G8 · "GÜNCEL" DALINDA DA DENETLENİR — bu dal eskiden HİÇ bakılmıyordu
#   (canlı ölçüm 2026-08-05: rafta 35 çalıştırılamaz script, hepsine "güncel" deniyordu)
R="$(_kur 755 ok)"
(cd "$R" && node sync-skills.mjs --apply >/dev/null 2>&1)      # 1. tur: kurulur
chmod 644 "$R/hedef/deneme-skill/scripts/calis.sh"             # kurulu kopya bozulur
out="$(cd "$R" && node sync-skills.mjs 2>&1)"                  # 2. tur: DRY-RUN, içerik aynı
printf '%s' "$out" | grep -q 'DUMAN TESTİ DÜŞTÜ'
kapi "G8 içerik aynıyken bile bozuk kurulu kopya yakalanır" $?

# G9 · --apply KİPİ ONARIR (içeriğe dokunmadan)
R="$(_kur 755 ok)"
(cd "$R" && node sync-skills.mjs --apply >/dev/null 2>&1)
onceki="$(md5sum < "$R/hedef/deneme-skill/scripts/calis.sh")"
chmod 644 "$R/hedef/deneme-skill/scripts/calis.sh"
out="$(cd "$R" && node sync-skills.mjs --apply 2>&1)"; rc=$?
sonraki="$(md5sum < "$R/hedef/deneme-skill/scripts/calis.sh")"
[ -x "$R/hedef/deneme-skill/scripts/calis.sh" ] && [ "$rc" = 0 ] \
  && printf '%s' "$out" | grep -q 'ONARILDI' && [ "$onceki" = "$sonraki" ]
kapi "G9 --apply izni onarır, içeriği DEĞİŞTİRMEZ" $?

# G10 · DRY-RUN ONARMAZ (ölçüm aracı sessizce yazamaz)
R="$(_kur 755 ok)"
(cd "$R" && node sync-skills.mjs --apply >/dev/null 2>&1)
chmod 644 "$R/hedef/deneme-skill/scripts/calis.sh"
(cd "$R" && node sync-skills.mjs >/dev/null 2>&1)
[ ! -x "$R/hedef/deneme-skill/scripts/calis.sh" ]
kapi "G10 dry-run onarmaz (yalnız --apply yazar)" $?


echo "── kaynak dal ilanı + bayat kaynak koruması (BHJS8W) ──"
# Git'li sahte kaynak: uzak (bare) + çalışma kopyası; ikinci klon uzağı ilerletir, kopya fetch eder → origin/main'in gerisinde.
_git_kur() {  # → $R (git'li kaynak), $UZ (bare uzak)
  UZ="$T/uzak$RANDOM"; git init -q --bare -b main "$UZ" 2>/dev/null
  R="$T/gkaynak$RANDOM"; mkdir -p "$R"; cp "$SUT" "$R/sync-skills.mjs"
  mkdir -p "$R/deneme-skill/scripts" "$R/hedef"
  printf -- '---\nname: deneme-skill\nversion: 1.0.0\n---\ngövde\n' > "$R/deneme-skill/SKILL.md"
  printf '#!/usr/bin/env bash\necho merhaba\n' > "$R/deneme-skill/scripts/calis.sh"; chmod 755 "$R/deneme-skill/scripts/calis.sh"
  printf '{"targets":{"_t":"%s/hedef"},"install":{"deneme-skill":["_t"]}}\n' "$R" > "$R/sync-targets.json"
  printf 'hedef/\n' > "$R/.gitignore"
  ( cd "$R" && git init -q -b main && git config user.email t@t && git config user.name T && git add -A && git commit -qm "chore: ilk" && git remote add origin "$UZ" && git push -q origin main ) >/dev/null 2>&1
}
_uzagi_ilerlet() {  # uzak main'e bir commit ekle, $R'ye fetch ettir (R yerel main'i geride kalır)
  local K="$T/klon$RANDOM"; git clone -q "$UZ" "$K" 2>/dev/null
  ( cd "$K" && git config user.email t@t && git config user.name T && echo yeni > yeni.txt && git add -A && git commit -qm "chore: uzak ilerledi" && git push -q origin main ) >/dev/null 2>&1
  ( cd "$R" && git fetch -q origin ) >/dev/null 2>&1
}

# B1 · güncel kaynak: ilan basılır, uyarı YOK, --apply çalışır
_git_kur
O="$(cd "$R" && node sync-skills.mjs --apply 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "kaynak: main@" <<<"$O" && grep -q "0 commit geride" <<<"$O" && ! grep -q "KAYNAK BAYAT" <<<"$O" && [ -f "$R/hedef/deneme-skill/SKILL.md" ]
kapi "B1 güncel kaynakta dal@sha ilan edilir, uyarı yok, --apply kurar" $?

# B2 · bayat kaynak + --apply → RED rc 3, hiçbir şey kopyalanmaz
_git_kur; _uzagi_ilerlet
O="$(cd "$R" && node sync-skills.mjs --apply 2>&1)"; RC=$?
[ "$RC" -eq 3 ] && grep -q "KAYNAK BAYAT" <<<"$O" && grep -q "1 commit geride" <<<"$O" && grep -q "REDDEDİLDİ" <<<"$O" && [ ! -e "$R/hedef/deneme-skill" ]
kapi "B2 origin/main'in gerisindeki kaynaktan --apply REDDEDİLİR (rc 3, hedefe dosya düşmez)" $?

# B3 · bayat kaynak + kuru-koşu → uyarı basılır, hedefe yazmaz, RED yok
O="$(cd "$R" && node sync-skills.mjs 2>&1)"; RC=$?
grep -q "KAYNAK BAYAT" <<<"$O" && ! grep -q "REDDEDİLDİ" <<<"$O" && [ "$RC" -ne 3 ] && [ ! -e "$R/hedef/deneme-skill" ]
kapi "B3 bayat kaynakta kuru-koşu UYARIR (sessiz 'güncel' yok) ama reddetmez" $?

# B4 · bayat kaynak + SYNC_BAYAT_KABUL=1 → uyarı var, kurulum geçer
O="$(cd "$R" && SYNC_BAYAT_KABUL=1 node sync-skills.mjs --apply 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "KAYNAK BAYAT" <<<"$O" && [ -f "$R/hedef/deneme-skill/SKILL.md" ]
kapi "B4 SYNC_BAYAT_KABUL=1 ile bayat kaynak BİLEREK geçilir (uyarı yine basılır)" $?

# B5 · çözülmemiş çakışma → bayat sayılır
_git_kur
( cd "$R" && git checkout -q -b yan && echo a > cak.txt && git add -A && git commit -qm "chore: yan a" && git checkout -q main && echo b > cak.txt && git add -A && git commit -qm "chore: main b" && git merge yan >/dev/null 2>&1 ) >/dev/null 2>&1
O="$(cd "$R" && node sync-skills.mjs --apply 2>&1)"; RC=$?
[ "$RC" -eq 3 ] && grep -q "ÇÖZÜLMEMİŞ ÇAKIŞMA" <<<"$O" && [ ! -e "$R/hedef/deneme-skill" ]
kapi "B5 çözülmemiş çakışması olan kaynaktan --apply REDDEDİLİR" $?

# B6 · git olmayan ağaç (mevcut sahte sınav ağaçları): ölçülemedi denir, davranış eskisi gibi
R="$(_kur 755 ok)"
O="$(cd "$R" && node sync-skills.mjs --apply 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && grep -q "git deposu olarak ölçülemedi" <<<"$O" && [ -f "$R/hedef/deneme-skill/SKILL.md" ]
kapi "B6 git deposu olmayan kaynakta 'ölçülemedi' ilan edilir, kurulum eskisi gibi çalışır" $?

# mutant: bayat kaynak koruması söküldü → B2 düşmeli
MUT="$T/sync-mutant.mjs"; python3 - "$SUT" "$MUT" <<'PYM'
import sys; s=open(sys.argv[1]).read(); a="if (APPLY && process.env.SYNC_BAYAT_KABUL !== '1') {"; assert s.count(a)==1
open(sys.argv[2],"w").write(s.replace(a,"if (false) {"))
PYM
_git_kur; _uzagi_ilerlet; cp "$MUT" "$R/sync-skills.mjs"
(cd "$R" && node sync-skills.mjs --apply >/dev/null 2>&1)
[ -e "$R/hedef/deneme-skill/SKILL.md" ]
kapi "mutant (RED söküldü): bayat kaynaktan kurulum YAPILIR → B2 bu mutantta düşerdi" $?


echo "── çalışma verisi kapıları (görev …ZM36SHM) ──"
# Kurulu kopyaya ÇALIŞMA VERİSİ konur: kök metrikler.jsonl, alt dizinde metrikler.jsonl, .olcum/ defteri.
_veri_koy() { # $1=beceri hedef dizini
  mkdir -p "$1/.olcum" "$1/demo"
  printf '{"n":1}\n' > "$1/metrikler.jsonl"; printf '{"d":1}\n' > "$1/demo/metrikler.jsonl"
  printf '{"iddia":"x"}\n' > "$1/.olcum/negatifler.jsonl"
}
_veri_ayni() { # $1=beceri hedef dizini → üç veri dosyası içerikleriyle yerinde mi
  [ "$(cat "$1/metrikler.jsonl" 2>/dev/null)" = '{"n":1}' ] && [ "$(cat "$1/demo/metrikler.jsonl" 2>/dev/null)" = '{"d":1}' ] \
    && [ "$(cat "$1/.olcum/negatifler.jsonl" 2>/dev/null)" = '{"iddia":"x"}' ]
}

# V1 · (a) yalnız veri farkı → İÇERİK-DRIFT YOK, kuru koşu güncel, rc 0
R="$(_kur 755 ok)"; (cd "$R" && node sync-skills.mjs --apply >/dev/null 2>&1)
_veri_koy "$R/hedef/deneme-skill"
out="$(cd "$R" && node sync-skills.mjs 2>&1)"; rc=$?
[ "$rc" = 0 ] && ! printf '%s' "$out" | grep -q 'İÇERİK-DRIFT' && printf '%s' "$out" | grep -q 'deneme-skill → _t: güncel'
kapi "V1 kurulu kopyada yalnız çalışma verisi var → fark YOK (güncel, rc 0)" $?

# V2 · (b) kurulumda veri SİLİNMEZ: sürüm artar, --apply → kod güncellenir, üç veri dosyası içeriğiyle yerinde
sed -i 's/^version: 1.0.0/version: 1.1.0/' "$R/deneme-skill/SKILL.md"; printf '#!/usr/bin/env bash\necho yeni\n' > "$R/deneme-skill/scripts/calis.sh"
(cd "$R" && node sync-skills.mjs --apply >/dev/null 2>&1)
_veri_ayni "$R/hedef/deneme-skill" && grep -q 'echo yeni' "$R/hedef/deneme-skill/scripts/calis.sh"
kapi "V2 --apply kodu günceller, çalışma verisi (kök · alt dizin · .olcum) yerinde kalır" $?

# V3 · (c) gerçek kod farkı (veriyle birlikte) hâlâ İÇERİK-DRIFT, rc 1
printf '#!/usr/bin/env bash\necho elle-duzenlendi\n' > "$R/hedef/deneme-skill/scripts/calis.sh"
out="$(cd "$R" && node sync-skills.mjs 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'deneme-skill → _t: İÇERİK-DRIFT'
kapi "V3 kurulu kopyada gerçek kod farkı → İÇERİK-DRIFT, rc 1 (veri onu gizlemez)" $?

# V4 · --force ezmesi de veriyi korur; kaynaktan kalkmış eski kod dosyası ise silinir (temizlik sürer)
printf 'eski\n' > "$R/hedef/deneme-skill/scripts/kaldirilmis.sh"
(cd "$R" && node sync-skills.mjs --apply --force >/dev/null 2>&1)
_veri_ayni "$R/hedef/deneme-skill" && [ ! -e "$R/hedef/deneme-skill/scripts/kaldirilmis.sh" ] && grep -q 'echo yeni' "$R/hedef/deneme-skill/scripts/calis.sh"
kapi "V4 --force veriyi korur, kaynakta olmayan kod dosyasını siler, kodu kaynaktan yazar" $?

# V5 · kaynakta aynı adla veri dosyası olsa bile kurulu veri ÜSTÜNE yazılmaz
printf '{"kaynak":1}\n' > "$R/deneme-skill/metrikler.jsonl"; sed -i 's/^version: 1.1.0/version: 1.2.0/' "$R/deneme-skill/SKILL.md"
(cd "$R" && node sync-skills.mjs --apply >/dev/null 2>&1)
_veri_ayni "$R/hedef/deneme-skill"
kapi "V5 kaynaktaki veri adı kurulu verinin üstüne yazılmaz" $?


printf '\n%s geçti · %s kaldı\n' "$gecen" "$kalan"
[ "$kalan" -eq 0 ]
