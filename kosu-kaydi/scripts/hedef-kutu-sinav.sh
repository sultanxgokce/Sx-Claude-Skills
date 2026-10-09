#!/usr/bin/env bash
# hedef-kutu-sinav.sh — becerinin sınavını HEDEF kutuda koşturur (kurulum olmadan: dosyalar o kutunun /tmp'sine tar ile
# taşınır, sınav orada koşar, iz silinir). Taşınan her dosyanın md5'i iki uçta basılır: kaynak ≟ hedef.
# Kullanım: hedef-kutu-sinav.sh <konteyner> [<ssh-host>]   (varsayılan host: hostsrv; host "-" ise yerel docker)
# Niçin: "bu kutuda çalışır" iddiası kurulumdan ÖNCE de ölçülebilir olsun (A290: nazir'de croniter yok, cloudtop deposu görünmez).
set -uo pipefail
KUTU="${1:-}"; HOST="${2:-hostsrv}"
[ -n "$KUTU" ] || { echo "kullanım: hedef-kutu-sinav.sh <konteyner> [<ssh-host>|-]" >&2; exit 2; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # beceri kökü
AD="$(basename "$HERE")"; H="/tmp/$AD-sinav-$$"
if [ "$HOST" = "-" ]; then UZAK() { "$@"; }; else UZAK() { ssh -o BatchMode=yes -o ConnectTimeout=15 "$HOST" "$*"; }; fi
echo "kutu: $KUTU · host: $HOST · hedef: $H · kaynak: $HERE"
echo "── kaynak md5:"; (cd "$HERE/.." && find "$AD" -type f | sort | xargs md5sum | sed 's/^/  /')
tar -C "$HERE/.." -cf - "$AD" | UZAK "docker exec -i -u abc $KUTU sh -c 'mkdir -p $H && tar -C $H -xf -'" || { echo "✗ taşıma düştü"; exit 3; }
UZAK "docker exec -u abc $KUTU bash -c '
  echo \"── hedef md5:\"; (cd $H && find $AD -type f | sort | xargs md5sum | sed \"s/^/  /\")
  echo \"── hedef ortam: bash \$BASH_VERSION · \$(python3 --version 2>&1) · croniter: \$(python3 -c \"import croniter\" 2>&1 | tail -1 | cut -c1-40)\"
  bash $H/$AD/scripts/kosu-sar.test.sh; rc=\$?
  find $H -depth -delete; echo \"temizlik: \$(test -e $H && echo KALDI || echo silindi)\"; exit \$rc'"
rc=$?; echo "hedef kutu sınav rc=$rc"; exit $rc
