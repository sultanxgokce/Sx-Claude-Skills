#!/usr/bin/env bash
# sync-skills.test.sh — dağıtımın "kullanılabilir mi" kapıları (2026-08-04).
# Gerçek /config/.claude'a DOKUNMAZ: her kapı kendi sahte kaynak+hedef ağacıyla koşar.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$HERE/sync-skills.mjs"
gecen=0; kalan=0
kapi(){ if [ "$2" = 0 ]; then printf '  ✓ %s\n' "$1"; gecen=$((gecen+1)); else printf '  ✗ %s\n' "$1"; kalan=$((kalan+1)); fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# Sahte repo: sync-skills.mjs + kendi sync-targets.json + tek skill
_kur() { # $1=kaynak-script-kipi (755/644) $2=sozdizimi(ok/bozuk)
  R="$T/repo$RANDOM"; mkdir -p "$R/deneme-skill/scripts" "$R/hedef"
  cp "$SUT" "$R/"
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


printf '\n%s geçti · %s kaldı\n' "$gecen" "$kalan"
[ "$kalan" -eq 0 ]
