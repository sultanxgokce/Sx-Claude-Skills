#!/usr/bin/env bash
# kur-bag.test.sh — kur.sh'ın proje-yolu bağı ve bekçi cron satırları ÇALIŞTIRILARAK ölçülür (hermetik).
#
# Niçin (bağımsız göz, tur 1 · 12 Ekim 2026): eski K8/K9 kapıları kaynak dosyada metin sayıyordu; var olan
# yanlış hedefli bağ ve üretilen GERÇEK cron satırı hiç ölçülmüyordu. Burada kur.sh gerçekten koşar:
# ttyd/onar/durum sahte (ağ, tmux yok), parola ortamdan; bağ ve cron dosyası diskten okunur.
# KUR_BAG_KOK: sınanan beceri kökü (mutasyon kanıtı için eski sürüm verilebilir; varsayılan bu depo).
set -u
KOK="${KUR_BAG_KOK:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
gecen=0; kalan=0
kapi() { if [ "$2" = "$3" ]; then gecen=$((gecen+1)); echo "  ✓ $1"; else kalan=$((kalan+1)); echo "  ✗ $1 — beklenen=$2 gerçek=$3"; fi; }

T=$(mktemp -d)
ORTAK="$T/ortak/skills/terminal-onar"          # "ortak dizin" (filo kopyası)
PROJE="$T/projects/sinav"
BAG="$PROJE/.claude/skills/terminal-onar"
mkdir -p "$ORTAK" "$PROJE" "$T/bin"
# 🔴 GERÇEK crontab'a KALKAN: ortak.sh PATH'i sistem dizinleriyle ÖNE alır, PATH'teki sahte crontab yenilir (15 Eki: eski kodla
#    koşan mutasyon turu canlı crontab'ı /tmp yoluna çevirdi — S-10'un ta kendisi). Dışa aktarılmış kabuk fonksiyonu PATH'ten
#    önce çözülür; TO_CRONTAB verilmeyen her çağrı buraya düşer, kaydedilir, gerçek crontab'a ULAŞMAZ. Son kapı sayıyı 0 ister.
GERCEK_CRONTAB_IZ="$T/gercek-crontab-cagri"; export GERCEK_CRONTAB_IZ
crontab() { printf 'CAGRILDI %s\n' "$*" >> "$GERCEK_CRONTAB_IZ"; [ "${!#}" = "-l" ] && return 0; cat >/dev/null; return 0; }
export -f crontab
cp -r "$KOK/scripts" "$ORTAK/"
# 🔴 TO_BECERI_KOK kum havuzuna SABİTLENİR: ortak.sh proje yolu yokken /config/.claude/skills'e düşer ve sınav
#    GERÇEK onar.sh'ı koşturur (ilk yazımda oldu: makinede sinav-ana/sinav-kurtarici doğdu, crontab'a satır girdi).
# sahteler: ağ/tmux yok — onar.sh ve durum.sh yalnız "koştum" der; ttyd sürüm basar
printf '#!/usr/bin/env bash\necho onar-sahte-kostu >> "%s/iz"; exit 0\n' "$T" > "$ORTAK/scripts/onar.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$ORTAK/scripts/durum.sh"
printf '#!/usr/bin/env bash\necho "ttyd sahte 1.7.7"\n' > "$T/bin/ttyd"
chmod +x "$ORTAK"/scripts/*.sh "$T/bin/ttyd"

kur() { # kur.sh'ı verilen yoldan koş; çıktı $T/son'a, rc döner
  env -u TO_KUTU TO_PROJE="$PROJE" TO_BECERI_KOK="$ORTAK" TO_TTYD_BIN="$T/bin/ttyd" TO_DURUM_DIZ="$T/durum" HOME="$T" \
      CORTEX_ACCESS_ENV="$T/yok.env" SINAV__TERMINAL_SIFRE=sinav-parola TERMINAL_KUR_ONAY=sultan-verdi \
      bash "$1" > "$T/son" 2>&1; echo $?
}
hedef() { readlink -f "$BAG" 2>/dev/null || echo "?"; }
cron_proje() { local n; n=$(grep -c "bash $BAG/scripts/[a-z]*\.sh" "$PROJE/.oda/cron" 2>/dev/null); echo "${n:-0}"; }
cron_ortak() { local n; n=$(grep -c "$ORTAK/scripts" "$PROJE/.oda/cron" 2>/dev/null); echo "${n:-0}"; }

echo "── sıfırdan: bağ yok"
rc=$(kur "$ORTAK/scripts/kur.sh")
kapi "B1 kur.sh ortak dizinden koşunca bağ kurulur → ortak kopyaya" "$ORTAK" "$(hedef)"
kapi "B2 kurulum rc=0" "0" "$rc"
kapi "B3 cron satırları (bekçi + açılış) PROJE yolunu kullanır" "2" "$(cron_proje)"
kapi "B4 cron'da ORTAK yol yok" "0" "$(cron_ortak)"
kapi "B5 onar.sh (kum havuzundaki) gerçekten çağrıldı" "1" "$(n=$(grep -c onar-sahte-kostu "$T/iz" 2>/dev/null); echo "${n:-0}")"

echo "── ikinci koşum, bu kez PROJE yolundan (bağ üzerinden)"
rc=$(kur "$BAG/scripts/kur.sh")
kapi "B6 bağ değişmedi (idempotent)" "$ORTAK" "$(hedef)"
kapi "B7 cron satırları çoğalmadı" "2" "$(cron_proje)"
kapi "B7b rc=0" "0" "$rc"

echo "── var olan bağ YANLIŞ hedefte (eski kurulum başka yere bağlamış)"
mkdir -p "$T/yanlis/scripts"; cp "$ORTAK/scripts/kur.sh" "$T/yanlis/scripts/"; chmod +x "$T/yanlis/scripts/kur.sh"
rm -f "$BAG"; ln -s "$T/yanlis" "$BAG"
rc=$(kur "$ORTAK/scripts/kur.sh")
kapi "B8 yanlış hedefli bağ (çalışır görünse de) doğru hedefe çevrilir" "$ORTAK" "$(hedef)"
kapi "B8b rc=0" "0" "$rc"

echo "── var olan bağ KIRIK"
rm -f "$BAG"; ln -s "$T/yok-boyle-bir-yer" "$BAG"
rc=$(kur "$ORTAK/scripts/kur.sh")
kapi "B9 kırık bağ onarılır (hata verip durmaz)" "$ORTAK" "$(hedef)"
kapi "B9b rc=0" "0" "$rc"

echo "── proje yolunda GERÇEK eski kopya (dizin)"
rm -f "$BAG"; mkdir -p "$BAG/scripts"; echo eski > "$BAG/scripts/eski.txt"
rc=$(kur "$ORTAK/scripts/kur.sh")
kapi "B10 eski kopya kenara alınır, bağ kurulur" "$ORTAK" "$(hedef)"
kapi "B10b eski kopya silinmedi (.eski-* altında)" "1" "$(ls -d "$BAG".eski-* 2>/dev/null | wc -l | tr -d ' ')"
kapi "B10c rc=0" "0" "$rc"
eski1="$(ls -d "$BAG".eski-* | head -1)"
rm -f "$BAG"; mkdir -p "$BAG/scripts"; echo eski2 > "$BAG/scripts/eski2.txt"      # AYNI GÜN ikinci eski kopya
rc=$(kur "$ORTAK/scripts/kur.sh")
kapi "B10d aynı gün ikinci eski kopya AYRI yedeğe alınır (iki .eski-*, iç içe değil)" "2" "$(ls -d "$BAG".eski-* 2>/dev/null | wc -l | tr -d ' ')"
kapi "B10e ilk yedeğin içine taşınmadı (ilk yedek yalnız kendi dosyasını taşır)" "1" "$(find "$eski1" -type f | wc -l | tr -d ' ')"
kapi "B10f ikinci yedeğin içeriği kendi dosyası" "1" "$(n=$(find "$BAG".eski-* -name eski2.txt | wc -l | tr -d ' '); echo "$n")"
kapi "B10g bağ yine doğru hedefte, rc=0" "$ORTAK:0" "$(hedef):$rc"

echo "── proje yolunda beklenmedik DÜZ DOSYA: silinmez, kurulum durur (fail-closed)"
rm -f "$BAG"; echo "beklenmedik" > "$BAG"
rc=$(kur "$ORTAK/scripts/kur.sh")
kapi "B16 düz dosya SİLİNMEDİ (içeriği yerinde)" "beklenmedik" "$(cat "$BAG" 2>/dev/null)"
kapi "B16b kurulum durdu rc=4 ve sebebi söylendi" "4:e" "$rc:$(grep -q 'ne bağ ne dizin' "$T/son" && echo e || echo h)"
rm -f "$BAG"

echo "── YÜKSELTME: canlıdaki eski ortak-yollu cron satırları (12 Eki, 15 kutu) proje yoluna ÇEVRİLİR"
rm -f "$BAG"; rm -r -- "$PROJE/.oda" 2>/dev/null; mkdir -p "$PROJE/.oda"
cat > "$PROJE/.oda/cron" <<CR
TZ=Europe/Istanbul
0 3 * * * bash /config/projects/sinav/scripts/baska-is.sh  # baska-is
* * * * * bash /config/.claude/skills/terminal-onar/scripts/bekci.sh  # terminal-onar-bekci
@reboot sleep 15; bash /config/.claude/skills/terminal-onar/scripts/komut.sh onar  # terminal-onar-acilis
CR
rc=$(kur "$ORTAK/scripts/kur.sh")
kapi "B13 eski ortak-yollu bekçi+açılış satırları proje yoluna çevrildi" "2" "$(cron_proje)"
kapi "B13b eski ÇIPLAK ortak-yollu satır kalmadı (ortak yol yalnız TO_KUTU'lu yedek dalda)" "0" "$(n=$(grep -c 'bash /config/.claude/skills/terminal-onar/scripts/bekci.sh  #' "$PROJE/.oda/cron"); echo "${n:-0}")"
kapi "B13c başka iş satırı ve TZ olduğu gibi (4 satır, çoğalma yok)" "4" "$(wc -l < "$PROJE/.oda/cron" | tr -d ' ')"
kapi "B13d rc=0" "0" "$rc"

echo "── canlı crontab göçü (onar.sh'ın kullandığı bekci_kur … canli; crontab sahte, gerçek crontab'a DOKUNULMAZ)"
CT="$T/ct.txt"; printf '%s\n' "MAILTO=x" "* * * * * bash /config/.claude/skills/terminal-onar/scripts/bekci.sh # terminal-onar-bekci" "5 * * * * echo baska" > "$CT"
printf '#!/usr/bin/env bash\nif [ "$1" = -l ]; then cat "%s"; else cat > "%s"; fi\n' "$CT" "$CT" > "$T/bin/crontab"; chmod +x "$T/bin/crontab"
cikti=$(env -u TO_KUTU TO_PROJE="$PROJE" TO_BECERI_KOK="$ORTAK" TO_DURUM_DIZ="$T/durum" TO_CRONTAB="$T/bin/crontab" HOME="$T" bash -c '
  set +u; . "$1/scripts/ortak.sh" >/dev/null 2>&1; bekci_kur "$ODA_CRON" canli' _ "$ORTAK" 2>/dev/null)
kapi "B14 canlı crontab'daki eski ortak-yollu bekçi satırı proje yoluna çevrildi" "1" "$(n=$(grep -c "bash $BAG/scripts/bekci.sh" "$CT"); echo "${n:-0}")"
kapi "B14b crontab'da çıplak ortak-yollu satır kalmadı (ortak yol yalnız TO_KUTU'lu yedek dalda)" "0" "$(n=$(grep -c 'bash /config/.claude/skills/terminal-onar/scripts/bekci.sh  #' "$CT"); echo "${n:-0}")"
kapi "B14c crontab'daki öteki satırlar korundu (3 satır)" "3" "$(wc -l < "$CT" | tr -d ' ')"
kapi "B14d bekci_kur 'canlı crontab düzeltildi' dedi" "e" "$(case "$cikti" in *"canlı crontab düzeltildi"*) echo e;; *) echo "h ($cikti)";; esac)"
cikti2=$(env -u TO_KUTU TO_PROJE="$PROJE" TO_BECERI_KOK="$ORTAK" TO_DURUM_DIZ="$T/durum" TO_CRONTAB="$T/bin/crontab" HOME="$T" bash -c '
  set +u; . "$1/scripts/ortak.sh" >/dev/null 2>&1; bekci_kur "$ODA_CRON" canli' _ "$ORTAK" 2>/dev/null)
kapi "B14e ikinci çağrı: değişiklik yok, crontab'a yazılmaz (idempotent)" "zaten var" "$cikti2"
kapi "B15 onar.sh canlı crontab için aynı bekci_kur'u çağırır (tam onar.sh tmux/ttyd ister)" "1" "$(n=$(grep -c 'bekci_kur "\$ODA_CRON" canli' "$KOK/scripts/onar.sh"); echo "${n:-0}")"

echo "── bekçi satırının kendisi"
satir=$(env -u TO_KUTU TO_PROJE="$PROJE" TO_DURUM_DIZ="$T/durum" HOME="$T" bash -c '
  set +u; . "$1/scripts/ortak.sh" >/dev/null 2>&1; printf "%s" "$BEKCI_SATIR"' _ "$KOK" 2>/dev/null)
kapi "B11 bekçi satırı (ortak.sh tek kaynak) PROJE yolunu taşır" "e" "$(case "$satir" in *"$BAG/scripts/bekci.sh"*) echo e;; *) echo "h ($satir)";; esac)"
kapi "B12 ortak yol yalnız YEDEK dalda ve kutu AÇIK BEYANLA (TO_KUTU=sinav) — makine-kimliği tuzağı yok" "e" "$(case "$satir" in *"else TO_KUTU=sinav bash /config/.claude/skills/terminal-onar/scripts/bekci.sh; fi"*) echo e;; *) echo "h ($satir)";; esac)"
kapi "B12b proje yolu ÖNCE sınanır, varsa o kazanır (if [ -x <proje>/bekci.sh ])" "e" "$(case "$satir" in "* * * * * if [ -x $BAG/scripts/bekci.sh ]; then bash $BAG/scripts/bekci.sh; else"*) echo e;; *) echo "h ($satir)";; esac)"

echo "── S-9 · bağ YOKKEN satır ölür mü? (maiset 13 Eki: her dakika rc 127) — cron'un koşturacağı komut sh ile BİREBİR koşulur"
# Hermetik ortak kopya: TO_ORTAK_BECERI sınav dizinine çekilir; iki bekci.sh de yalnız iz bırakır.
YDK="$T/yedek-ortak"; mkdir -p "$YDK/scripts"
printf '#!/usr/bin/env bash\necho "ORTAK kutu=${TO_KUTU:-yok}" >> "%s/s9-iz"\n' "$T" > "$YDK/scripts/bekci.sh"; chmod +x "$YDK/scripts/bekci.sh"
komut=$(env -u TO_KUTU TO_PROJE="$PROJE" TO_DURUM_DIZ="$T/durum" TO_ORTAK_BECERI="$YDK" HOME="$T" bash -c '
  set +u; . "$1/scripts/ortak.sh" >/dev/null 2>&1; printf "%s" "${BEKCI_SATIR#\* \* \* \* \* }"' _ "$KOK" 2>/dev/null)
komut="${komut%%  # terminal-onar-bekci}"
rm -r -- "$BAG" 2>/dev/null; rm -f "$BAG" 2>/dev/null; : > "$T/s9-iz"
sh -c "$komut"; rc=$?
kapi "S9a bağ YOKKEN satır rc 0 (eski hâl: rc 127, bekçi sessiz ölü)" "0" "$rc"
kapi "S9b yedek dal koştu ve kutuyu AÇIK BEYANLA aldı" "ORTAK kutu=sinav" "$(cat "$T/s9-iz")"
mkdir -p "$BAG/scripts"; printf '#!/usr/bin/env bash\necho "PROJE" >> "%s/s9-iz"\n' "$T" > "$BAG/scripts/bekci.sh"; chmod +x "$BAG/scripts/bekci.sh"
: > "$T/s9-iz"; sh -c "$komut"
kapi "S9c bağ VARKEN proje yolu kazanır, yedek dal KOŞMAZ (tek satır iz)" "PROJE" "$(cat "$T/s9-iz")"

echo "── S-10 · deneme kopyası canlı crontab'a DOKUNAMAZ (13 Eki: sınav bekçi satırını /tmp yoluna çevirdi, iki kez)"
# Kalkan fonksiyonu (sınav başı) her çıplak `crontab` çağrısını kaydeder; TO_CRONTAB VERİLMEZ, PROJE geçici → hiç çağrılmamalı.
: > "$GERCEK_CRONTAB_IZ"
cikti=$(env -u TO_KUTU -u TO_CRONTAB TO_PROJE="$PROJE" TO_BECERI_KOK="$ORTAK" TO_DURUM_DIZ="$T/durum" HOME="$T" bash -c '
  set +u; . "$1/scripts/ortak.sh" >/dev/null 2>&1; bekci_kur "$ODA_CRON" canli' _ "$ORTAK" 2>/dev/null)
kapi "S10a TO_CRONTAB yokken geçici PROJE ile crontab komutu HİÇ çağrılmadı" "0" "$(n=$(grep -c CAGRILDI "$GERCEK_CRONTAB_IZ"); echo "${n:-0}")"
: > "$GERCEK_CRONTAB_IZ"
kapi "S10b ve bunu SÖYLEDİ (sessiz atlama yok)" "e" "$(case "$cikti" in *"canlı crontab'a DOKUNULMADI"*) echo e;; *) echo "h ($cikti)";; esac)"
kapi "S10c kalıcı kopya (.oda/cron) yine yazıldı — kilit yalnız canlı crontab içindir" "1" "$(n=$(grep -c '# terminal-onar-bekci' "$PROJE/.oda/cron"); echo "${n:-0}")"
# pozitif kontrol: aynı çağrı TO_CRONTAB ile → crontab çağrılır (kilit süs değil)
printf '#!/usr/bin/env bash\necho "CAGRILDI $*" >> "%s/s10-iz"; exit 0\n' "$T" > "$T/bin/crontab-iz"; chmod +x "$T/bin/crontab-iz"; : > "$T/s10-iz"
env -u TO_KUTU TO_PROJE="$PROJE" TO_BECERI_KOK="$ORTAK" TO_DURUM_DIZ="$T/durum" TO_CRONTAB="$T/bin/crontab-iz" HOME="$T" bash -c '
  set +u; . "$1/scripts/ortak.sh" >/dev/null 2>&1; bekci_kur "$ODA_CRON" canli' _ "$ORTAK" >/dev/null 2>&1
kapi "S10d pozitif kontrol: TO_CRONTAB verilince crontab ÇAĞRILIR" "e" "$([ "$(grep -c CAGRILDI "$T/s10-iz")" -ge 1 ] && echo e || echo h)"

echo "── S-10b · çift bekçi satırı TEKİLLEŞİR (code kutusu 14 Eki: aynı işaretli satır iki kez)"
CT2="$T/ct2.txt"; printf '%s\n' "MAILTO=x" "* * * * * bash /tmp/tmp.X/proje/.claude/skills/terminal-onar/scripts/bekci.sh  # terminal-onar-bekci" "* * * * * bash /tmp/tmp.Y/proje/.claude/skills/terminal-onar/scripts/bekci.sh  # terminal-onar-bekci" "5 * * * * echo baska" > "$CT2"
printf '#!/usr/bin/env bash\nif [ "$1" = -l ]; then cat "%s"; else cat > "%s"; fi\n' "$CT2" "$CT2" > "$T/bin/crontab2"; chmod +x "$T/bin/crontab2"
env -u TO_KUTU TO_PROJE="$PROJE" TO_BECERI_KOK="$ORTAK" TO_DURUM_DIZ="$T/durum" TO_CRONTAB="$T/bin/crontab2" HOME="$T" bash -c '
  set +u; . "$1/scripts/ortak.sh" >/dev/null 2>&1; bekci_kur "$ODA_CRON" canli' _ "$ORTAK" >/dev/null 2>&1
kapi "S10e iki işaretli satır → TEK kanonik satır" "1" "$(n=$(grep -c '# terminal-onar-bekci' "$CT2"); echo "${n:-0}")"
kapi "S10f eski /tmp.X ve /tmp.Y yolları kalmadı, öteki satırlar korundu (3 satır)" "0|3" "$(n=$(grep -cE '/tmp/tmp\.(X|Y)/' "$CT2"); echo "${n:-0}")|$(wc -l < "$CT2" | tr -d ' ')"

echo "── kalkan: sınav boyunca GERÇEK crontab'a tek çağrı bile gitmedi mi?"
kapi "K0 çıplak crontab çağrısı 0 (kalkan izi boş) — sınav canlı crontab'a dokunamaz" "0" "$(n=$(grep -c CAGRILDI "$GERCEK_CRONTAB_IZ" 2>/dev/null); echo "${n:-0}")"

rm -r -- "$T" 2>/dev/null
echo
echo "SONUÇ: $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ]
