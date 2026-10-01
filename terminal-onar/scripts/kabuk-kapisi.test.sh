#!/usr/bin/env bash
# Kabuk ön koşulu — tmux'un varsayılan kabuğu sahte ise onarım DURMALI.
#
# Niçin (SEDİR/RAHVAN önerisi + REVAK vakası, 2026-09-29): LSIO imajında `abc`'nin kabuğu
# `/bin/false`. Kutuda `.tmux.conf`'ta `default-shell` yoksa oturumlar doğar doğmaz ölür;
# tmux rc=0 döner, soket oluşur, hata yalnız ayrıntılı günlükte görünür. Onarım bunu
# "oturum yok" diye okuyup merdiveni tırmanır ve her tırmanış yeni bir Claude süreci demektir.
#
# 🔴 Sınav GERÇEK bir tmux sunucusu kurar (taklit yok) ve kendi soketinde koşar.
set -u
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gecen=0; kalan=0
kapi(){ if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }
command -v tmux >/dev/null || { echo "ÖLÇÜLEMEDİ: tmux yok"; exit 3; }

T=$(mktemp -d); S="$T/sok"
kos() { # $1 = default-shell değeri → onar.sh rc'si + günlük
  tmux -S "$S" kill-server 2>/dev/null
  tmux -S "$S" -f /dev/null new-session -d -s x "sleep 30" 2>/dev/null
  tmux -S "$S" set -g default-shell "$1" 2>/dev/null
  env TO_KUTU=sinav TO_PROJE="$T/proje" TO_DURUM_DIZ="$T/durum" \
      TMUX_TMPDIR="$T" tmux_soket="$S" \
      bash -c 'tmux() { command tmux -S "'"$S"'" "$@"; }; export -f tmux; timeout 25 bash "'"$KOK"'/scripts/onar.sh" >/dev/null 2>&1'
  echo $?
}
mkdir -p "$T/proje" "$T/durum"

echo "── sahte kabukta DURMALI"
kapi "S1 /bin/false ile onarım durur (rc=3)" "3" "$(kos /bin/false)"
kapi "S2 günlükte sebep yazılı" "1" "$(grep -c 'çalıştırılabilir DEĞİL' "$T/durum/gunluk.log" 2>/dev/null || echo 0)"
kapi "S3 günlükte ÇARE satırı var" "1" "$(grep -c 'default-shell /bin/bash' "$T/durum/gunluk.log" 2>/dev/null || echo 0)"

echo "── gerçek kabukta DURMAMALI (kapı süs olmasın)"
rc=$(kos /bin/bash)
kapi "S4 /bin/bash ile kabuk kapısına TAKILMAZ" "e" "$([ "$rc" != 3 ] && echo e || echo h)"

echo "── hemen ÇIKAN sahte kabuk da sahtedir (bağımsız göz, tur 1)"
# 🔴 Eski ölçüt yalnız adı false/nologin ile biten yolları eliyordu ve çalıştırılabilirlik
#    bitine bakıyordu. /bin/true adı masum, biti var, çıkış kodu 0 — ama kabuk DEĞİL:
#    oturum yine doğar doğmaz ölür. Kapı adı değil DAVRANIŞI ölçmeli.
kapi "S5 /bin/true ile de onarım durur (çıkış kodu yetmez, çıktı ölçülür)" "3" "$(kos /bin/true)"

echo "── tmux SUNUCUSU YOKKEN hesabın kabuğu okunur (asıl vaka: yeni doğmuş kutu)"
# 🔴 BULGUNUN ÖZÜ: eski kod sunucu yokken $SHELL'e düşüyordu. $SHELL ÇAĞIRANIN ortamıdır;
#    onarımı geçerli bir kabuktan çalıştırmak kapıyı açıyordu — yani kapı tam da yazıldığı
#    vakada (yeni kutu, hesabın kabuğu sahte) sessiz kalıyordu.
#    Burada gövdeyi doğrudan ölçüyoruz: tmux hiç yokmuş gibi davran, $SHELL GEÇERLİ olsun,
#    hesabın kabuğu SAHTE olsun → kapı DURDURMALI.
govde_olc() { # $1 = sahte hesap kabuğu → kabuk_gecerli_mi rc
  env SHELL=/bin/bash bash -c '
    tmux() { return 1; }                       # sunucu YOK
    _hesap_kabugu() { printf "%s" "'"$1"'"; }  # hesabın kabuğu (parola dosyası yerine)
    '"$(sed -n "/^kabuk_gecerli_mi()/,/^}/p" "$KOK/scripts/onar.sh")"'
    kabuk_gecerli_mi; echo $?'
}
kapi "S6 sunucu yok + hesabın kabuğu /bin/false → kapı DURDURUR (\$SHELL geçerli olsa bile)" \
     "1" "$(govde_olc /bin/false | tail -1)"
kapi "S7 sunucu yok + hesabın kabuğu /bin/bash → kapı GEÇİRİR (S6 tautoloji değil)" \
     "0" "$(govde_olc /bin/bash | tail -1)"

tmux -S "$S" kill-server 2>/dev/null; rm -r -- "$T" 2>/dev/null
echo
echo "SONUÇ: $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ]
