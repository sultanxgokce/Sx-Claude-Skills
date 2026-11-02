#!/usr/bin/env bash
# usta.test.sh — usta.sh sınavı (gerçek tmux, kendi soketinde; sahte claude) + MUTANTLAR
# kabuk-testleri: sure=300
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
command -v tmux >/dev/null || { echo "ÖLÇÜLEMEDİ: tmux yok"; exit 3; }
G=0; K=0; ok() { if [ "$2" = 1 ]; then G=$((G+1)); echo "  ✓ $1"; else K=$((K+1)); echo "  ✗ $1  → ${3:-}"; fi; }
kos() { # <usta.sh yolu> ... ortamı kurar, SINAV bloğunu koşar; sonuç K sayısı
  local U="$1"; T="$(mktemp -d)"; SOK="usta-test-$$-$RANDOM"
  printf '#!/usr/bin/env bash\nexec tmux -L %s "$@"\n' "$SOK" > "$T/tm"; chmod +x "$T/tm"
  printf '#!/usr/bin/env bash\necho "pwd=$PWD args=$*" >> "%s/claude.log"\nsleep 600\n' "$T" > "$T/claude"; chmod +x "$T/claude"
  mkdir -p "$T/p/ustalar/PERGEL" "$T/p/ustalar/KUKLACI" "$T/p/ustalar/ORTA" "$T/p/_agents/handoff" "$T/cfg/projects"
  local P; P="$(cd "$T/p" && pwd -P)"
  for a in PERGEL KUKLACI ORTA; do mkdir -p "$T/cfg/projects/$(printf '%s' "$P/ustalar/$a" | sed 's#[/._]#-#g')"; : > "$T/cfg/projects/$(printf '%s' "$P/ustalar/$a" | sed 's#[/._]#-#g')/sid-$a.jsonl"; done
  cat > "$T/p/_agents/handoff/ekip-registry.yaml" <<Y
uyeler:
  - {ad: PERGEL, klasor: ustalar/PERGEL, sohbet: sid-PERGEL, koltuk: yok}
  - {ad: KUKLACI, klasor: ustalar/KUKLACI, sohbet: sid-KUKLACI, koltuk: yok}
  - {ad: ORTA, klasor: ustalar/ORTA, sohbet: sid-ORTA, koltuk: yok}
  - {ad: BASSIZ, klasor: ustalar/BASSIZ, koltuk: yok}
  - {ad: MUDUR, koltuk: var}
  - {ad: KLASORLU, klasor: ustalar/KLASORLU, sohbet: sid-K, koltuk: var}
Y
  export USTA_TMUX="$T/tm" USTA_CLAUDE="$T/claude" USTA_CONFIG="$T/cfg" USTA_PROJE="$P" UYUT_BEKLE_SN=3 UYUT_SAKIN_SN=1
  mkdir -p "$P/ustalar/BASSIZ"
  local O r
  O="$(bash "$U" liste 2>&1)"
  ok "U1 liste: yalnız koltuk:yok + klasor alanlı üyeler (MUDUR ve koltuklu KLASORLU yok, BASSIZ kayit-eksik)" "$([ "$(printf '%s' "$O" | grep -c .)" = 4 ] && printf '%s' "$O" | grep -q $'BASSIZ\tkayit-eksik' && ! printf '%s' "$O" | grep -q 'MUDUR\|KLASORLU' && echo 1 || echo 0)" "$O"
  O="$(TO_KUTU=sinav TO_PROJE="$P" bash "$(dirname "$U")/koltuk-ac.sh" durum PERGEL 2>&1)"
  ok "U10 koltuk-ac: usta koltuğu yol=usta olarak tanınır (kayıtsız koltuk gibi reddedilmez)" "$(printf '%s' "$O" | grep -q '"yol":"usta"' && echo 1 || echo 0)" "$O"
  # prova: PERGEL'in sohbeti YANLIŞ klasörün proje dizinine konur
  local YK; YK="$T/cfg/projects/$(printf '%s' "$P/ustalar/KUKLACI" | sed 's#[/._]#-#g')"
  mv "$T/cfg/projects/$(printf '%s' "$P/ustalar/PERGEL" | sed 's#[/._]#-#g')/sid-PERGEL.jsonl" "$YK/sid-PERGEL.jsonl"
  O="$(bash "$U" uyandir PERGEL 2>&1)"; r=$?
  ok "U2 YANLIŞ KLASÖR KİLİDİ: sohbet başka klasörün dizininde → rc 4, oturum AÇILMADI" "$([ "$r" = 4 ] && ! "$T/tm" has-session -t =PERGEL 2>/dev/null && echo 1 || echo 0)" "rc=$r $O"
  mv "$YK/sid-PERGEL.jsonl" "$T/cfg/projects/$(printf '%s' "$P/ustalar/PERGEL" | sed 's#[/._]#-#g')/sid-PERGEL.jsonl"
  O="$(bash "$U" uyandir BASSIZ 2>&1)"; r=$?
  ok "U3 sohbet kimliği yok → rc 5, kimliksiz Claude açılmaz" "$([ "$r" = 5 ] && echo 1 || echo 0)" "rc=$r $O"
  O="$(bash "$U" uyandir PERGEL --kuru 2>&1)"; r=$?
  ok "U4 kuru koşu: plan basar, oturum AÇMAZ" "$([ "$r" = 0 ] && printf '%s' "$O" | grep -q 'KURU' && ! "$T/tm" has-session -t =PERGEL 2>/dev/null && echo 1 || echo 0)" "rc=$r $O"
  O="$(bash "$U" uyandir PERGEL 2>&1)"; r=$?; sleep 1
  ok "U5 uyandır: oturum açıldı, claude ustanın KENDİ klasöründe --resume <sohbet> ile koştu" "$([ "$r" = 0 ] && grep -q "pwd=$P/ustalar/PERGEL args=--resume sid-PERGEL" "$T/claude.log" && echo 1 || echo 0)" "rc=$r $O $(cat "$T/claude.log" 2>/dev/null)"
  # tavan 2: PERGEL uyanık; KUKLACI uyandır → 2; ORTA uyandır → en boşta (PERGEL) uyur
  export UST_TAVAN=2
  sleep 1; bash "$U" uyandir KUKLACI >/dev/null 2>&1; sleep 2
  O="$(bash "$U" uyandir ORTA --kuru 2>&1)"
  ok "U6 tavan dolu (2/2): kuru koşu EN BOŞTAKİNİ (PERGEL) uyutacağını söyler" "$(printf '%s' "$O" | grep -q 'en boştaki uyutulur: PERGEL' && echo 1 || echo 0)" "$O"
  bash "$U" uyandir ORTA >/dev/null 2>&1; sleep 1
  ok "U7 tavan: gerçek koşuda PERGEL uyutuldu, ORTA uyandı, uyanık sayısı 2" "$(! "$T/tm" has-session -t =PERGEL 2>/dev/null && "$T/tm" has-session -t =ORTA 2>/dev/null && [ "$(bash "$U" liste | grep -c $'\tuyanik\t')" = 2 ] && echo 1 || echo 0)" "$(bash "$U" liste)"
  ok "U8 kapanış kancası: uyutulan ustanın DURUM.md dosyasına uyutma damgası düştü" "$(grep -q 'uyutuldu' "$P/ustalar/PERGEL/DURUM.md" 2>/dev/null && echo 1 || echo 0)" "$(cat "$P/ustalar/PERGEL/DURUM.md" 2>&1)"
  # başarısızlık: DURUM.md yazılamıyorsa (salt-okur klasör) uyut REDDEDER, oturum açık kalır
  bash "$U" uyandir KUKLACI >/dev/null 2>&1; sleep 1; chmod a-w "$P/ustalar/KUKLACI"; rm -f "$P/ustalar/KUKLACI/DURUM.md" 2>/dev/null
  O="$(bash "$U" uyut KUKLACI 2>&1)"; r=$?
  ok "U11 DURUM.md yazılamazsa uyut rc 3 ve oturum AÇIK kalır (sessiz başarı yok)" "$([ "$r" = 3 ] && "$T/tm" has-session -t =KUKLACI 2>/dev/null && echo 1 || echo 0)" "rc=$r $O"
  # tavan + uyutulamayan en boştaki → yeni usta AÇILMAZ (fail-closed)
  export UST_TAVAN=2; chmod a-w "$P/ustalar/ORTA"; rm -f "$P/ustalar/ORTA/DURUM.md" 2>/dev/null
  O="$(bash "$U" uyandir PERGEL 2>&1)"; r=$?
  ok "U12 tavan dolu + en boştaki uyutulamıyor → rc 3, yeni usta AÇILMADI" "$([ "$r" = 0 ] && echo 0 || { [ "$r" = 3 ] && echo 1 || echo 0; })" "rc=$r $O"
  chmod u+w "$P/ustalar/KUKLACI" "$P/ustalar/ORTA"; unset UST_TAVAN
  bash "$U" uyut KUKLACI >/dev/null 2>&1
  ok "U9 uyut: oturum kapandı + DURUM.md damgası" "$(! "$T/tm" has-session -t =KUKLACI 2>/dev/null && grep -q uyutuldu "$P/ustalar/KUKLACI/DURUM.md" && echo 1 || echo 0)"
  "$T/tm" kill-server 2>/dev/null; find "$T" -delete 2>/dev/null; unset UST_TAVAN
}
echo "── usta.sh"
kos "$HERE/usta.sh"
echo "SONUÇ: geçti=$G kaldı=$K"; [ "$K" -eq 0 ] || exit 1
[ "${USTA_MUTANT:-1}" = 0 ] && exit 0
echo "── mutantlar (her biri sınavı KIRMALI)"
M="$(mktemp -d)"; MK=0; cp "$HERE/koltuk-ac.sh" "$HERE/ortak.sh" "$HERE/koltuk-adi.sh" "$HERE/koltuk-bagla.sh" "$M/" 2>/dev/null
mut() { cp "$HERE/usta.sh" "$M/usta.sh"
  python3 -I -c "import sys;p=sys.argv[1];s=open(p,encoding='utf-8').read();a,b=sys.argv[2],sys.argv[3];assert s.count(a)==1,'çapa '+str(s.count(a));open(p,'w',encoding='utf-8').write(s.replace(a,b))" "$M/usta.sh" "$2" "$3" || { echo "  ✗ $1: MUTASYON ÜRETİLEMEDİ"; MK=$((MK+1)); return; }
  local g=$G k=$K; G=0; K=0; kos "$M/usta.sh" >"$M/o.txt" 2>&1; local kk=$K; G=$g; K=$k
  if [ "$kk" -gt 0 ]; then echo "  ✓ $1: yakalandı ($kk kapı kırmızı)"; else echo "  ✗ $1: sınav YEŞİL kaldı"; MK=$((MK+1)); fi; }
mut "kilit yok (her klasörde resume)" '[ -f "$DOSYA" ] || {' 'false || {'
mut "tavan yok sayılır" '[ "${#uyanikler[@]}" -ge "$TAVAN" ]' 'false'
mut "en boştaki yerine listedeki son usta uyutulur" '[ "$e" -lt "$ens" ] &&' 'true &&'
mut "DURUM.md damgası yok" "printf '\\n- uyutuldu" "true '\\n- uyutuldu"
mut "claude ustanın klasöründe açılmaz" '-c "$MK"' '-c "$PROJE"'
mut "koltuklu üye de usta sayılır" "u.get('koltuk', '').lower() == 'yok'" "True"
mut "tavanda uyutulamayan olsa da yeni usta açılır" 'uyutulamadı — yeni usta AÇILMADI" >&2; exit 3; }' 'uyutulamadı — yeni usta AÇILMADI" >&2; }'
mut "DURUM.md yazılamasa da oturum kapatılır" 'yazılamadı (oturum açık bırakıldı)" >&2; return 3; }' 'yazılamadı (oturum açık bırakıldı)" >&2; }'
mut "sohbetsiz usta açılır" '[ -n "$S" ] || {' 'false || {'
# koltuk-ac mutantı: usta yolu tanınmaz
cp "$HERE/usta.sh" "$M/usta.sh"; cp "$HERE/koltuk-ac.sh" "$M/koltuk-ac.sh"
python3 -I -c "import sys;p=sys.argv[1];s=open(p,encoding='utf-8').read();a='if usta_mi \"\$1\"; then YOL=usta';assert s.count(a)==1,'çapa';open(p,'w',encoding='utf-8').write(s.replace(a,'if false; then YOL=usta'))" "$M/koltuk-ac.sh" || MK=$((MK+1))
g=$G; k=$K; G=0; K=0; kos "$M/usta.sh" >"$M/o.txt" 2>&1; kk=$K; G=$g; K=$k
if [ "$kk" -gt 0 ]; then echo "  ✓ koltuk-ac usta yolunu tanımaz: yakalandı ($kk kapı kırmızı)"; else echo "  ✗ koltuk-ac usta yolunu tanımaz: sınav YEŞİL kaldı"; MK=$((MK+1)); fi
find "$M" -delete 2>/dev/null
[ "$MK" -eq 0 ] && echo "MUTANT: 10/10 yakalandı" || { echo "MUTANT: $MK kaçtı"; exit 1; }
