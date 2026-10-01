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
# 🔴 Temizlik ÇIKIŞA bağlı (bağımsız göz, tur 2 rötuşu): eski hâlde yalnız son satırda
#    temizleniyordu; sınav yarıda kesilirse tmux sunucusu ve geçici dizin ARTIK kalıyordu.
temizle() { for k in "$T"/sok*; do [ -S "$k" ] && tmux -S "$k" kill-server 2>/dev/null; done; rm -r -- "$T" 2>/dev/null; }
trap temizle EXIT INT TERM
_sok_no=0
kos() { # $1 = default-shell değeri → onar.sh rc'si + günlük
  # 🔴 HER KOŞUM KENDİ SOKETİNDE. Eskiden tek soket paylaşılıyor ve her çağrıda
  #    kill-server + new-session yapılıyordu; kill-server ASENKRONDUR, ölen sunucu
  #    hâlâ ayaktayken açılan oturum eski sunucuya düşüyor ve ayar tutmuyordu.
  #    Yarış sessizdi: ayar tutmayınca kapı hesabın (geçerli) kabuğunu okuyup onarımı
  #    sonuna kadar koşturuyor, 124 dönüyordu — ve eski S4 onu YEŞİL sayıyordu.
  _sok_no=$((_sok_no+1)); S="$T/sok$_sok_no"
  tmux -S "$S" -f /dev/null new-session -d -s x "sleep 30" 2>/dev/null
  tmux -S "$S" set -g default-shell "$1" 2>/dev/null
  # 🔴 FİKSTÜRÜN KENDİSİ ÖLÇÜLÜR (pozitif kontrol). Ayar tutmadıysa sınav hüküm VERMEZ:
  #    CI'da tam bu oldu — ayar uygulanmadı, kapı hesabın (geçerli) kabuğunu okudu, onarım
  #    sonuna kadar koştu ve 124 (zaman aşımı) döndü. O sırada S4 "3 değil" diye YEŞİL
  #    basıyordu: zaman aşımını başarı sayan bir kapı sahte yeşildir.
  local okunan; okunan=$(tmux -S "$S" show -gv default-shell 2>/dev/null)
  [ "$okunan" = "$1" ] || { echo "FIKSTUR-TUTMADI"; return 0; }
  env TO_KUTU=sinav TO_PROJE="$T/proje" TO_DURUM_DIZ="$T/durum" \
      TMUX_TMPDIR="$T" tmux_soket="$S" TTYD_BEKLE=2 KAPI_BEKLE=2 TO_BEKLE_ADIM=0 \
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
# 🔴 "3 DEĞİL" YETMEZ: zaman aşımı (124) da 3 değildir ve eski hâli onu YEŞİL sayıyordu.
#    Kapı artık hem durmamayı hem ASILMAMAYI ölçer; fikstür tutmadıysa açıkça söyler.
kapi "S4 /bin/bash ile kabuk kapısına TAKILMAZ (ve asılmaz)" "e" \
     "$(case "$rc" in 3) echo h ;; 124) echo "asildi" ;; FIKSTUR-TUTMADI) echo "olculemedi" ;; *) echo e ;; esac)"

echo "── hemen ÇIKAN sahte kabuk da sahtedir (bağımsız göz, tur 1)"
# 🔴 Eski ölçüt yalnız adı false/nologin ile biten yolları eliyordu ve çalıştırılabilirlik
#    bitine bakıyordu. /bin/true adı masum, biti var, çıkış kodu 0 — ama kabuk DEĞİL:
#    oturum yine doğar doğmaz ölür. Kapı adı değil DAVRANIŞI ölçmeli.
kapi "S5 /bin/true ile de onarım durur (çıkış kodu yetmez, çıktı ölçülür)" "3" "$(kos /bin/true)"
kapi "S5b /bin/true ile onarım ASILMADI (124 başarı sayılmaz)" "e" \
     "$([ "$(kos /bin/true)" = "124" ] && echo "asildi" || echo e)"

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

echo
echo "SONUÇ: $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ]
