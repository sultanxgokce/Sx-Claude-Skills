#!/usr/bin/env bash
# tmux-bekcisi.sh + ortak.sh tmux_bekcisi_kur — sınav (hermetik; canlı /config/.local/bin'e ve kutunun tmux'una DOKUNMAZ).
# A: sahte "gerçek tmux" ile karar (ret/geçiş, argüman ve çıkış kodu birebir) · G: GERÇEK tmux ile K43HN vakasının yeniden
# üretimi (yalıtılmış sunucu "kutu" rolünde) · K: kurulum kuralları · M: bozmalar geçici kopyada, her biri kırmızı olmalı.
# İç koşum: TB_KAYNAK=<bekçi kopyası> TB_IC=1 → yalnız A+G (mutant turu kendini yeniden çağırmaz — fork bombası dersi).
set -u
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
B="${TB_KAYNAK:-$KOK/scripts/tmux-bekcisi.sh}"
gecen=0; kalan=0
kapi() { if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
T="$(mktemp -d)"; trap 'for s in "$T"/kutu.sok "$T"/ayri/*; do [ -S "$s" ] && /usr/bin/tmux -S "$s" kill-server 2>/dev/null; done; rm -r -f -- "$T"' EXIT
unset TMUX TMUX_PANE TMUX_KILL_SERVER_IZIN TMUX_TMPDIR

# sahte gerçek tmux: argümanları satır satır yazar, TB_RC ile döner
cat > "$T/sahte" <<'EOF'
#!/usr/bin/env bash
: > "$TB_IZ"; for a in "$@"; do printf '%s\n' "$a" >> "$TB_IZ"; done; exit "${TB_RC:-0}"
EOF
chmod +x "$T/sahte"; export TB_IZ="$T/iz" TO_DURUM_DIZ="$T/durum"; mkdir -p "$T/durum"
kos() {  # $1 = TMUX değeri ("" = yok) · sonra tmux argümanları → "rc|çağrıldı(e/h)"
  local tm="$1"; shift; rm -f "$TB_IZ"
  if [ -n "$tm" ]; then TMUX="$tm" TO_GERCEK_TMUX="$T/sahte" bash "$B" "$@" 2>"$T/err"; else TO_GERCEK_TMUX="$T/sahte" bash "$B" "$@" 2>"$T/err"; fi
  local rc=$?; printf '%s|%s' "$rc" "$([ -f "$TB_IZ" ] && echo e || echo h)"
}
I="/tmp/tmux-1000/default,123,0"

echo "── A · karar (sahte gerçek tmux)"
kapi "A1 \$TMUX dolu + çıplak kill-server → RET, gerçek tmux çağrılmaz" "1|h" "$(kos "$I" kill-server)"
kapi "A1b ret iletisi sebebi ve çıkışı söyler" "2" "$(grep -cE "REDDEDİLDİ|TMUX_KILL_SERVER_IZIN" "$T/err")"
kapi "A2 \$TMUX dolu + -L ad kill-server → geçer" "0|e" "$(kos "$I" -L olcum kill-server)"
kapi "A3 \$TMUX dolu + -S yol kill-server → geçer" "0|e" "$(kos "$I" -S "$T/x.sok" kill-server)"
kapi "A3b bitişik -Lad → geçer" "0|e" "$(kos "$I" -Lolcum kill-server)"
kapi "A3c kümelenmiş -2L ad → geçer" "0|e" "$(kos "$I" -2L olcum kill-server)"
kapi "A3d -f dosya ARGÜMANI soket sanılmaz (-f -L kill-server → -L dosya adıdır, RET)" "1|h" "$(kos "$I" -f -L kill-server)"
kapi "A4 \$TMUX yok + kill-server → geçer (cron/docker exec söküm yolu)" "0|e" "$(kos "" kill-server)"
kapi "A5 tek anlamlı kısaltma kill-ser → RET" "1|h" "$(kos "$I" kill-ser)"
kapi "A5b kill-serv / kill-serve → RET" "1|h|1|h" "$(kos "$I" kill-serv)|$(kos "$I" kill-serve)"
kapi "A6 ';' sonrası ikinci komut kill-server → RET" "1|h" "$(kos "$I" new -d ';' kill-server)"
kapi "A6b -f ayarlı ve -c'li çağrıda da RET" "1|h" "$(kos "$I" -f /dev/null -c bash kill-server)"
kapi "A7 kill-session -t x → geçer" "0|e" "$(kos "$I" kill-session -t x)"
kapi "A7b komut konumunda OLMAYAN 'kill-server' (oturum adı) → geçer" "0|e" "$(kos "$I" new -d -s kill-server)"
kapi "A7c kabuk komutu metni içindeki kill-server → geçer" "0|e" "$(kos "$I" new -d 'echo kill-server')"
r="$(TMUX="$I" TMUX_KILL_SERVER_IZIN=1 TO_GERCEK_TMUX="$T/sahte" bash "$B" kill-server 2>/dev/null; echo "$?|$([ -f "$TB_IZ" ] && echo e || echo h)")"
kapi "A8 TMUX_KILL_SERVER_IZIN=1 → kasıtlı kapatma geçer" "0|e" "$r"
kos "$I" new -d -s 'a b' 'printf "%s\n" x;y' >/dev/null
kapi "A9 argümanlar bayt bayt iletilir (boşluk, ; ve tırnak)" "new|-d|-s|a b|printf \"%s\n\" x;y" "$(paste -sd'|' "$TB_IZ")"
r="$(TB_RC=7 kos "$I" ls)"; kapi "A10 gerçek tmux'un çıkış kodu aynen döner" "7|e" "$r"
r="$(TMUX="$I" TO_GERCEK_TMUX="$T/yok-boyle" bash "$B" ls 2>/dev/null; echo $?)"; kapi "A11 gerçek tmux yoksa 127" "127" "$r"
rm -f "$T/durum/tmux-bekcisi.log"; kos "$I" kill-server >/dev/null
kapi "A12 ret iz defterine yazılır (kim çağırdı)" "1" "$(grep -c 'RED kill-server · çağıran pid=' "$T/durum/tmux-bekcisi.log" 2>/dev/null)"

echo "── G · GERÇEK tmux: K43HN vakası (yalıtılmış sunucu = kutu)"
if command -v /usr/bin/tmux >/dev/null && [ -x /usr/bin/tmux ]; then
  K="$T/kutu.sok"; /usr/bin/tmux -S "$K" -f /dev/null new-session -d -s koltuk "sleep 300"
  kp="$(/usr/bin/tmux -S "$K" display -p '#{pid}')"; KT="$K,$kp,0"   # kutunun içindeki bir Claude'un gördüğü $TMUX
  kapi "G0 pozitif kontrol: kutu sunucusu canlı" "0" "$(/usr/bin/tmux -S "$K" has-session -t koltuk 2>/dev/null; echo $?)"
  mkdir -p "$T/ayri"
  # vaka birebir: betik TMUX_TMPDIR ile 'kendi' sunucusunu kurduğunu sanır, çıkışta çıplak kill-server koşar
  TMUX="$KT" TMUX_TMPDIR="$T/ayri" TO_GERCEK_TMUX=/usr/bin/tmux bash "$B" kill-server 2>/dev/null; r=$?
  kapi "G1 vakadaki komut RET alır" "1" "$r"
  kapi "G2 kutunun sunucusu ve koltuğu YERİNDE" "0|$kp" "$(/usr/bin/tmux -S "$K" has-session -t koltuk 2>/dev/null; echo "$?|$(/usr/bin/tmux -S "$K" display -p '#{pid}' 2>/dev/null)")"
  TMUX="$KT" TMUX_TMPDIR="$T/ayri" /usr/bin/tmux new-session -d -s ayri "sleep 300" 2>/dev/null
  kapi "G3 (bekçisiz gerçek tmux) aynı ortamda yeni oturum KUTUYA düşer — vakanın mekanizması" "0" "$(/usr/bin/tmux -S "$K" has-session -t ayri 2>/dev/null; echo $?)"
  ( unset TMUX; TMUX_TMPDIR="$T/ayri" TO_GERCEK_TMUX=/usr/bin/tmux bash "$B" -f /dev/null new-session -d -s yal "sleep 300" )
  ( unset TMUX; TMUX_TMPDIR="$T/ayri" TO_GERCEK_TMUX=/usr/bin/tmux bash "$B" kill-server )
  kapi "G4 'unset TMUX' ile yalıtılmış sunucu kapanır, kutu kalır" "0" "$(/usr/bin/tmux -S "$K" has-session -t koltuk 2>/dev/null; echo $?)"
  TMUX="$KT" TO_GERCEK_TMUX=/usr/bin/tmux bash "$B" -S "$K" kill-server 2>/dev/null
  kapi "G5 açık soketle kasıtlı kapatma GEÇER (kutu gerçekten kapanır)" "1" "$(/usr/bin/tmux -S "$K" has-session 2>/dev/null; echo $?)"
else
  echo "  ÖLÇÜLEMEDİ: /usr/bin/tmux yok — G kapıları koşmadı"; kalan=$((kalan+1))
fi

if [ -z "${TB_IC:-}" ]; then
  echo "── K · kurulum (ortak.sh tmux_bekcisi_kur)"
  kur() {  # $1 = TO_PROJE · $2 = TO_TMUX_BEKCI_BIN ("" = verme) → stdout
    ( export TO_KUTU=sinav TO_PROJE="$1" TO_DURUM_DIZ="$T/durum" TO_BECERI_KOK="$KOK" TO_TMUX_BEKCI_VARSAYILAN="$T/canli/tmux"
      [ -n "$2" ] && export TO_TMUX_BEKCI_BIN="$2" || unset TO_TMUX_BEKCI_BIN
      . "$KOK/scripts/ortak.sh" >/dev/null 2>&1 || exit 9; tmux_bekcisi_kur; echo "rc=$?" )
  }
  H="$T/bin/tmux"
  canli_once="$(stat -c '%Y %s' /config/.local/bin/tmux 2>/dev/null || echo yok)"
  r="$(kur "$T/proje" "")"; kapi "K1 deneme yolunda hedef verilmezse canlı yola DOKUNMAZ" "1" "$(printf '%s' "$r" | grep -c '^DOKUNULMADI (deneme yolu')"
  kapi "K1a … varsayılan (canlı rolündeki) hedefe hiçbir şey yazmaz" "yok" "$([ -e "$T/canli/tmux" ] && echo var || echo yok)"
  kapi "K1b … ve gerçek /config/.local/bin/tmux da değişmez (önce=sonra)" "$canli_once" "$(stat -c '%Y %s' /config/.local/bin/tmux 2>/dev/null || echo yok)"
  r="$(kur "/config/projects/sinav" "")"
  kapi "K1d gerçek kutu yolunda (PROJE=/config/projects/<kutu>) varsayılan hedefe KURAR" "kuruldu|e" "$(printf '%s' "$r" | head -1)|$([ -x "$T/canli/tmux" ] && echo e || echo h)"
  r="$( export TO_TMUX_BEKCI_BIN=; kur "$T/proje" "" )"
  kapi "K1c boş TO_TMUX_BEKCI_BIN de 'verilmedi' sayılır" "1" "$(printf '%s' "$r" | grep -c '^DOKUNULMADI (deneme yolu')"
  r="$(kur "$T/proje" "$H")"; kapi "K2 ilk kurulum: kuruldu, kaynakla bayt bayt aynı, çalıştırılabilir" "kuruldu|rc=0|e|e" "$(printf '%s' "$r" | paste -sd'|')|$(cmp -s "$KOK/scripts/tmux-bekcisi.sh" "$H" && echo e || echo h)|$([ -x "$H" ] && echo e || echo h)"
  r="$(kur "$T/proje" "$H")"; kapi "K3 ikinci koşu: güncel (dokunmaz)" "güncel|rc=0" "$(printf '%s' "$r" | paste -sd'|')"
  printf '\n# eski sürüm tmux-bekcisi.sh\n' >> "$H"
  exec 7<"$H"; ino_once="$(stat -c %i "$H")"   # açık tutulan eski kopya = o an onu koşturan süreç
  r="$(kur "$T/proje" "$H")"
  kapi "K4a güncelleme YERİNDE yazmaz, yenisini mv ile koyar (inode değişir; koşan eski kopya bozulmaz, yarım dosya görünmez)" "farkli|1" "$([ "$(stat -c %i "$H")" != "$ino_once" ] && echo farkli || echo ayni)|$(grep -c '# eski sürüm' <&7)"
  exec 7<&-
  kapi "K4 eski bekçi kopyası güncellenir" "güncellendi|rc=0|e" "$(printf '%s' "$r" | paste -sd'|')|$(cmp -s "$KOK/scripts/tmux-bekcisi.sh" "$H" && echo e || echo h)"
  printf '#!/bin/sh\necho elle-kurulmus\n' > "$H"
  r="$(kur "$T/proje" "$H")"; kapi "K5 bekçi olmayan yabancı dosyaya DOKUNMAZ" "1|rc=1|elle-kurulmus" "$(printf '%s' "$r" | grep -c '^DOKUNULMADI (hedefte')|$(printf '%s' "$r" | tail -1)|$(sh "$H")"
  rm -f "$H"
  r="$( export TO_GERCEK_TMUX="$T/yok-boyle"; PATH="$T/bosyol" kur "$T/proje" "$H" 2>/dev/null )"
  kapi "K6 yeni kopya gerçek tmux'a ulaşamazsa KURULMAZ (bozuk tmux asla yerleşmez)" "rc=1|yok|0" "$(printf '%s' "$r" | tail -1)|$([ -e "$H" ] && echo var || echo yok)|$(ls "$T/bin" | grep -c yeni)"
  kapi "K7 onar.sh adım 0 kurucuyu çağırır" "1" "$(grep -c '^_tb="$(tmux_bekcisi_kur)"' "$KOK/scripts/onar.sh")"

  echo "── B · dakikalık bekçi her turda kurar (onar yalnız arızada koşuyordu → 2.19.0 sağlıklı kutulara inmiyordu)"
  # Beceri ağacının geçici kopyası; durum/kademe/compact/dava sahte → bekci.sh gerçek onarım yapamaz, canlıya dokunamaz.
  BK="$T/bk"; mkdir -p "$BK"; cp -r "$KOK/scripts" "$BK/"
  for s in compact dava-gunluk; do printf '#!/usr/bin/env bash\nexit 0\n' > "$BK/scripts/$s.sh"; done
  printf '#!/usr/bin/env bash\nexit "${TB_DURUM_RC:-0}"\n' > "$BK/scripts/durum.sh"
  printf '#!/usr/bin/env bash\necho kademe >> "$TO_DURUM_DIZ/kademe.iz"\n' > "$BK/scripts/kademe.sh"
  bekci() {  # $1 = TB_DURUM_RC → rc
    ( export TO_KUTU=sinav TO_PROJE=/config/projects/sinav TO_DURUM_DIZ="$T/bd" TO_BECERI_KOK="$BK" TO_TMUX_BEKCI_VARSAYILAN="$T/bcanli/tmux" TB_DURUM_RC="$1" TO_KABUK_YOK=1
      unset TO_TMUX_BEKCI_BIN; bash "$BK/scripts/bekci.sh" >/dev/null 2>&1 ); echo "$?"
  }
  BH="$T/bcanli/tmux"; mkdir -p "$T/bd" "$T/bcanli"
  satir() { cat "$T/bd/gunluk.log" 2>/dev/null | grep -c 'tmux bekçisi'; }
  r="$(bekci 0)"
  kapi "B1 sağlıklı kutu (durum 0): bekçi turu bekçiyi KURAR, günlüğe bir satır" "0|e|e|1" "$r|$([ -x "$BH" ] && echo e || echo h)|$(cmp -s "$KOK/scripts/tmux-bekcisi.sh" "$BH" && echo e || echo h)|$(satir)"
  r="$(bekci 0)"; kapi "B2 ikinci tur: güncel → günlüğe yazmaz (dakikada bir satır olmaz)" "0|1" "$r|$(satir)"
  printf '\n# eski sürüm tmux-bekcisi.sh\n' >> "$BH"
  r="$(bekci 0)"; kapi "B3 eski kopya bir sonraki turda güncellenir" "0|e|2" "$r|$(cmp -s "$KOK/scripts/tmux-bekcisi.sh" "$BH" && echo e || echo h)|$(satir)"
  printf '#!/bin/sh\necho elle-kurulmus\n' > "$BH"; rm -f "$T/bd/kademe.iz"
  r="$(bekci 1)"; kapi "B4 kurulamasa da (yabancı dosya) bekçi işine devam eder: dosya yerinde, merdiven başlar" "elle-kurulmus|1" "$(sh "$BH")|$(cat "$T/bd/kademe.iz" 2>/dev/null | grep -c kademe)"
  kapi "B4b kurulamama günlüğe BİR satır yazar" "3" "$(satir)"
  bekci 1 >/dev/null; bekci 1 >/dev/null
  kapi "B4c aynı kurulamama sonraki turlarda tekrar yazılmaz (dakikada bir satır olmaz)" "3" "$(satir)"
  rm -f "$BH"; : > "$T/bd/duraklat"
  r="$(bekci 0)"; kapi "B5 duraklatılmış bekçi kurmaz (duraklat = hiçbir şey yapma)" "0|yok" "$r|$([ -e "$BH" ] && echo var || echo yok)"
  rm -f "$T/bd/duraklat"
fi

if [ -z "${TB_IC:-}" ] && [ -z "${TB_KIC:-}" ]; then
  echo "── M · bozmalar (geçici kopyada; her biri en az bir kapıyı kırmalı)"
  kurmutant() {  # kurucu bozması: beceri ağacının geçici kopyasında ortak.sh bozulur, kopyanın sınavı K'ye kadar koşar
    local d="$T/km-$1"; mkdir -p "$d"; cp -r "$KOK/scripts" "$d/"
    python3 -c 'import sys; p=sys.argv[1]; s=open(p).read(); assert sys.argv[2] in s, "desen yok"; open(p,"w").write(s.replace(sys.argv[2],sys.argv[3],1))' \
      "$d/scripts/ortak.sh" "$2" "$3" || { kapi "M $1 deseni bulundu" "e" "h"; return; }
    if TB_KIC=1 timeout 60 bash "$d/scripts/tmux-bekcisi.test.sh" >/dev/null 2>&1; then kapi "M $1 kırmızı" "kirmizi" "yesil"; else kapi "M $1 kırmızı" "kirmizi" "kirmizi"; fi
  }
  kurmutant deneme-kilidi-yok '[ -z "${TO_TMUX_BEKCI_BIN:-}" ] && [ "$PROJE" != "/config/projects/$KUTU" ]' 'false'
  kurmutant yabanci-ezilir    '[ -e "$hedef" ] && ! grep -q' 'false && ! grep -q'
  kurmutant dogrulamasiz      '&& "$yeni" -V >/dev/null 2>&1 &&' '&&'
  kurmutant yerinde-yazar     'mv -f "$yeni" "$hedef"' 'cat "$yeni" > "$hedef" && rm -f "$yeni"'
  bekmutant() {  # bekci.sh bozması, aynı yöntem: kopyada bozulur, kopyanın sınavı K+B'ye kadar koşar. "" = bozmasız pozitif kontrol
    local d="$T/bm-$1"; mkdir -p "$d"; cp -r "$KOK/scripts" "$d/"
    if [ -n "$2" ]; then
      python3 -c 'import sys; p=sys.argv[1]; s=open(p).read(); assert sys.argv[2] in s, "desen yok"; open(p,"w").write(s.replace(sys.argv[2],sys.argv[3],1))' \
        "$d/scripts/bekci.sh" "$2" "$3" || { kapi "M $1 deseni bulundu" "e" "h"; return; }
    fi
    if TB_KIC=1 timeout 60 bash "$d/scripts/tmux-bekcisi.test.sh" >/dev/null 2>&1; then r=yesil; else r=kirmizi; fi
    if [ -n "$2" ]; then kapi "M $1 kırmızı" "kirmizi" "$r"; else kapi "M $1 (bozmasız kopya) yeşil" "yesil" "$r"; fi
  }
  bekmutant bekci-pozitif-kontrol '' ''
  bekmutant bekci-kurmaz          '_tb="$(tmux_bekcisi_kur)"
' '_tb=güncel
'
  bekmutant bekci-hep-yazar       '[ "$_tb" != güncel ] && [' 'true || ['
  bekmutant bekci-durakta-kurar   '[ -f "$DURUM_DIZ/duraklat" ] && exit 0
' '_tb="$(tmux_bekcisi_kur)"; [ -f "$DURUM_DIZ/duraklat" ] && exit 0
'
  bekmutant bekci-hatada-durur    'then gunluk "bekçi: tmux bekçisi: $_tb"; fi' 'then gunluk "bekçi: tmux bekçisi: $_tb"; exit 1; fi'
  bekmutant bekci-tekrar-yazar '&& [ "$_tb" != "$(cat "$DURUM_DIZ/tmux-bekcisi.son" 2>/dev/null)" ]' ''
  mutant() {  # $1 ad · $2 python değiştirme (eski) · $3 (yeni)
    local m="$T/m-$1.sh"
    python3 -c 'import sys; s=open(sys.argv[1]).read(); assert sys.argv[2] in s, "desen yok"; open(sys.argv[4],"w").write(s.replace(sys.argv[2],sys.argv[3],1))' \
      "$KOK/scripts/tmux-bekcisi.sh" "$2" "$3" "$m" || { kapi "M $1 deseni bulundu" "e" "h"; return; }
    if TB_KAYNAK="$m" TB_IC=1 timeout 60 bash "${BASH_SOURCE[0]}" >/dev/null 2>&1; then kapi "M $1 kırmızı" "kirmizi" "yesil"; else kapi "M $1 kırmızı" "kirmizi" "kirmizi"; fi
  }
  mutant tmux-sartsiz      'if [ -n "${TMUX:-}" ] && [' 'if true || [ -n "${TMUX:-}" ] && ['
  mutant soket-yok-sayilir 'case "$h" in L|S) soket=1 ;; esac' ':'
  mutant ayirac-yok        'konum=0; [ "$a" = ";" ] && konum=1' 'konum=0'
  mutant kisaltma-yok      '^kill-ser(v(e(r)?)?)?$' '^kill-server$'
  mutant arguman-atlanmaz  '[ "$j" -eq $(( ${#a} - 1 )) ] && i=$((i+1))' ':'
  mutant izin-yok          '[ "${TMUX_KILL_SERVER_IZIN:-}" != 1 ]' 'true'
  mutant hep-gecir         'exit 1
      fi' 'true
      fi'
fi

echo; echo "SONUÇ: $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ]
