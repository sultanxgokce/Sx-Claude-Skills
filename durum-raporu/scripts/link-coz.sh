#!/usr/bin/env bash
# link-coz.sh — mmepanel://<kutu>/<tur>/<hedef> → https URL. Şablonlar link-taban.yaml'dan (filo geneli tek dosya).
# Şablon yoksa girdiyi olduğu gibi basar (uydurmaz). MUAVİN: gerçek panel/kod-sunucu URL şablonlarını doldur.
set -uo pipefail
L="$1"; TABAN="${LINK_TABAN:-$(dirname "$0")/../link-taban.yaml}"
case "$L" in https://*|http://*) printf '%s' "$L"; exit 0;; mmepanel://*) ;; *) printf '%s' "$L"; exit 0;; esac
rest="${L#mmepanel://}"; kutu="${rest%%/*}"; rest="${rest#*/}"; tur="${rest%%/*}"; hedef="${rest#*/}"
[ -f "$TABAN" ] || { printf '%s' "$L"; exit 0; }
# Önce KUTUYA ÖZEL şablon (`<tur>_<kutu>:`), yoksa filo geneli (`<tur>:`).
# Niçin: bazı türler kutu başına farklı (akar'ın canlı adresi mukarnas.net, ötekiler başka);
# tek şablon zorlamak ya yanlış URL üretir ya da türü büsbütün boş bırakırdı.
_oku() { grep -E "^[[:space:]]*$1:[[:space:]]*" "$TABAN" | head -1 | sed 's/^[^:]*:[[:space:]]*"\{0,1\}//; s/"\{0,1\}[[:space:]]*\(#.*\)\{0,1\}$//'; }
sab="$(_oku "${tur}_${kutu}")"
[ -n "$sab" ] || sab="$(_oku "$tur")"
[ -n "$sab" ] || { printf '%s' "$L"; exit 0; }
printf '%s' "$sab" | sed "s|{kutu}|$kutu|g; s|{hedef}|$hedef|g"
