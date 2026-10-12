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

echo "── onar.sh'ın bekçi satırı (gerçek değişkenlerle üretilip okunur; tam onar.sh tmux/ttyd ister, burada koşmaz)"
satir=$(env -u TO_KUTU TO_PROJE="$PROJE" TO_DURUM_DIZ="$T/durum" HOME="$T" bash -c '
  set +u; . "$1/scripts/ortak.sh" >/dev/null 2>&1; eval "$(grep "^BEKCI_SATIR=" "$1/scripts/onar.sh")"; printf "%s" "$BEKCI_SATIR"' _ "$KOK" 2>/dev/null)
kapi "B11 onar.sh bekçi satırı PROJE yolunu taşır" "e" "$(case "$satir" in *"$BAG/scripts/bekci.sh"*) echo e;; *) echo "h ($satir)";; esac)"
kapi "B12 onar.sh bekçi satırı ortak dizini taşımaz" "e" "$(case "$satir" in */config/.claude/skills/*) echo h;; *) echo e;; esac)"

rm -r -- "$T" 2>/dev/null
echo
echo "SONUÇ: $gecen geçti · $kalan kaldı"
[ "$kalan" -eq 0 ]
